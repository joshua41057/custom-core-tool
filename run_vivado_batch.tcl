# ================================================================
# run_vivado_batch.tcl  –  Multi-benchmark non-interactive Vivado flow
# Creates pblocks *after synthesis* using actual utilization, then implements.
#
# Usage examples:
#   vivado -mode batch -source run_vivado_batch.tcl
#   vivado -mode batch -source run_vivado_batch.tcl -tclargs 527.cam4_r 525.x264_r
#
# Env knobs:
#   NPBLOCKS     : number of pblocks per compile (default 8)
#   TARGET_FILL  : target fill ratio inside each pblock (default 0.80)
#   PART         : override FPGA part (default xcu200-fsgd2104-2-e)
#   KEEP_TMP     : set to 1 to keep vivado_tmp_* folders (default delete)
#
# Outputs (per bench):
#   reports/<bench>/{post_route_{util,timing,power}.rpt, post_synth_util_hier.rpt, pblock_*.rpt}
#   reports/all_runs.csv (appended summary)
#
# Tested with Vivado 2022.2 / 2024.1
# ================================================================

# ---- Defaults ----
if { [info exists ::env(PART)] } {
  set PART $::env(PART)
} else {
  set PART "xcu200-fsgd2104-2-e"
}

set TOP_MODULE  "top_multi_len"
set RPT_DIR     "reports"
set RTL_DIR     [file join [pwd] rtl]
set EX_DIR      [file join [pwd] example]
set CONS_DIR    [file join [pwd] constraints]
set TOOLS_DIR   [file join [pwd] tools]
file mkdir $RPT_DIR

# Number of pblocks
if { [info exists ::env(NPBLOCKS)] } {
  set NPBLOCKS $::env(NPBLOCKS)
} else {
  set NPBLOCKS 8
}

# Target fill ratio
if { [info exists ::env(TARGET_FILL)] } {
  set TARGET_FILL $::env(TARGET_FILL)
} else {
  set TARGET_FILL 0.80
}

# Selected benches from -tclargs or from env BENCHES, or default: all under example/*
set sel_benches {}
if { $argc > 0 } {
  for {set i 0} {$i < $argc} {incr i} {
    lappend sel_benches [lindex $argv $i]
  }
} elseif { [info exists ::env(BENCHES)] } {
  foreach b $::env(BENCHES) { lappend sel_benches $b }
} else {
  # discover all leaf dirs under example/
  set dlist [glob -nocomplain -types d [file join $EX_DIR *]]
  foreach d $dlist { lappend sel_benches [file tail $d] }
}

if { [llength $sel_benches] == 0 } {
  puts "ERROR: No benchmarks selected."
  exit 1
}

proc read_rtl_excluding_len_table {rtl_dir} {
  # Read all .sv from rtl/ except len_table_pkg.sv
  set files [glob -nocomplain -directory $rtl_dir *.sv]
  set add {}
  foreach f $files {
    if {[file tail $f] == "len_table_pkg.sv"} { continue }
    lappend add $f
  }
  if {[llength $add] == 0} { puts "ERROR: No RTL files in $rtl_dir"; exit 1 }
  read_verilog -sv $add
  set_property file_type SystemVerilog [get_files *.sv]
  update_compile_order -fileset sources_1
}

proc add_bench_len_table {bench_dir} {
  set f [file join $bench_dir "len_table_pkg.sv"]
  if {![file exists $f]} {
    puts "ERROR: Missing $f"
    exit 1
  }
  read_verilog -sv $f
  set_property file_type SystemVerilog [get_files [file tail $f]]
}

proc try_source {f} {
  if {[file exists $f]} {
    puts "Info: source $f"
    source $f
    return 1
  }
  return 0
}

# Helper: run Python auto pblock generator
proc run_auto_pblock {bench bench_dir rpt_dir npblocks target_fill} {
  set util_hier [file join $rpt_dir "post_synth_util_hier.rpt"]
  set out_tcl   [file join $rpt_dir "auto_pblock.tcl"]
  set grid_txt  [file join [pwd] "constraints" "grid_ranges.txt"]
  set py        [file join [pwd] "tools" "auto_pblock_gen.py"]

  if {![file exists $py]} {
    puts "ERROR: tools/auto_pblock_gen.py not found."
    exit 1
  }
  if {![file exists $grid_txt]} {
    puts "ERROR: constraints/grid_ranges.txt not found."
    exit 1
  }
  # Generate TCL
  set cmd [list python3 $py \
    "--util" $util_hier "--grid" $grid_txt \
    "--npblocks" $npblocks "--target-fill" $target_fill \
    "--bench" $bench "--out" $out_tcl]
  puts "Info: EXEC: $cmd"
  set rc [catch {exec {*}$cmd} emsg]
  if {$rc} {
    puts "ERROR running auto_pblock_gen.py: $emsg"
    exit 1
  }
  if {![file exists $out_tcl]} {
    puts "ERROR: auto_pblock_gen.py did not produce $out_tcl"
    exit 1
  }
  source $out_tcl
}

proc add_constraint_file {f} {
  if {![file exists $f]} { return 0 }
  set ext [string tolower [file extension $f]]
  if {$ext eq ".xdc"} {
    puts "Info: add XDC $f"
    add_files -fileset constrs_1 -norecurse $f
  } else {
    puts "Info: source $f"
    source $f
  }
  return 1
}

proc ensure_ip_products {} {
  set ips [get_ips]
  if {[llength $ips] == 0} { return }

  upgrade_ip -quiet $ips

  catch { generate_target all $ips }

  export_ip_user_files -of_objects $ips -no_script -sync -force -quiet

  puts "Info: synth_ip to ensure synthesis products exist"
  catch { synth_ip $ips }

  set missing {}
  foreach ip $ips {
    set syn_files [get_files -quiet -of_objects $ip -filter {IS_GENERATED == 1 && (FILE_TYPE =~ "*Synthesis*" || NAME =~ "*.dcp")}]
    if {[llength $syn_files] == 0} {
      lappend missing $ip
    }
  }
  if {[llength $missing]} {
    puts "Info: forcing reset_target/generate_target for: $missing"
    reset_target all $missing
    generate_target all $missing
    export_ip_user_files -of_objects $missing -no_script -sync -force -quiet
  }
}

# ---- Per-benchmark loop ----
foreach bench $sel_benches {
  set bench_dir [file join $EX_DIR $bench]
  if {![file isdirectory $bench_dir]} {
    puts "WARN: Skip unknown bench $bench"
    continue
  }
  set bench_rpt_dir [file join $RPT_DIR $bench]
  file mkdir $bench_rpt_dir

  set proj "vivado_tmp_${bench}"
  if {[file exists $proj]} { file delete -force $proj }
  create_project -force $proj ./$proj -part $PART

  # IP gen (optional)
  set IP_REPO_DIR  [file join [pwd] "ip_repo"]
  file mkdir $IP_REPO_DIR
  set_property ip_repo_paths $IP_REPO_DIR [current_project]

  if {[llength [glob -nocomplain "$IP_REPO_DIR/*/*.xci"]] == 0} {
      puts "Info: No local XCI found – running core_ip.tcl to generate IPs"
      if {[file exists "core_ip.tcl"]} { source [file join [pwd] "core_ip.tcl"] }
  }
  update_ip_catalog
  set ip_xci [glob -nocomplain "$IP_REPO_DIR/*/*.xci"]
  if {[llength $ip_xci] > 0} {
    add_files -fileset sources_1 -norecurse $ip_xci
  }

  set ips [get_ips]
  if {[llength $ips] > 0} {
    upgrade_ip -quiet $ips

    catch { set_property GENERATE_SYNTH_CHECKPOINT true $ips }

    set xci_files [get_files -quiet -of_objects $ips -filter {NAME =~ "*.xci"}]
    if {[llength $xci_files] > 0} {
      catch { set_property generate_synth_checkpoint true $xci_files }
    }

    catch { generate_target {Synthesis} $ips }

    set missing {}
    foreach ip $ips {
      set syn_files [get_files -quiet -of_objects $ip -filter {IS_GENERATED == 1 && (FILE_TYPE =~ "*Synthesis*" || NAME =~ "*.dcp")}]
      if {[llength $syn_files] == 0} { lappend missing $ip }
    }
    if {[llength $missing]} {
      puts "Info: forcing reset_target/generate_target for: $missing"
      catch { reset_target all $missing }
      catch { generate_target {Synthesis} $missing }
    }

    export_ip_user_files -of_objects $ips -no_script -sync -force -quiet
  }
  update_compile_order -fileset sources_1

  # RTL
  read_rtl_excluding_len_table $RTL_DIR
  add_bench_len_table $bench_dir
  update_compile_order -fileset sources_1

  # Constraints
  add_constraint_file [file join $CONS_DIR "clocks.xdc"]

  # Synthesis
  synth_design -top $TOP_MODULE -part $PART -flatten_hierarchy none

  if {[file exists [file join $CONS_DIR "pipe_stages.tcl"]]} {
  puts "Info: post-synth source $CONS_DIR/pipe_stages.tcl"
  source [file join $CONS_DIR "pipe_stages.tcl"]
  }
  if {[file exists [file join $bench_dir "pipe_stages.tcl"]]} {
    puts "Info: post-synth source $bench_dir/pipe_stages.tcl"
    source [file join $bench_dir "pipe_stages.tcl"]
  }
  update_timing

  # Pre-place reports
  report_utilization -hierarchical -file [file join $bench_rpt_dir "post_synth_util_hier.rpt"]

  # Build pblocks based on post-synth utilization
  run_auto_pblock $bench $bench_dir $bench_rpt_dir $NPBLOCKS $TARGET_FILL

  

  # Implementation
  opt_design
  place_design
  phys_opt_design
  route_design
  write_checkpoint -force [file join $bench_rpt_dir "post_route.dcp"]

  # Reports
  report_utilization    -file [file join $bench_rpt_dir "post_route_util.rpt"]
  report_timing_summary -file [file join $bench_rpt_dir "post_route_timing.rpt"]
  report_power          -file [file join $bench_rpt_dir "post_route_power.rpt"]

  # Per-pblock util
  set SAFE_BENCH [regsub -all {[^A-Za-z0-9_]} $bench _]
  set pb_list [get_pblocks pblock_${SAFE_BENCH}_*]
  foreach pb $pb_list {
      set short [regsub -all {[:/]} $pb _]
      set rpt_name [format "%s/utilization_%s.rpt" $bench_rpt_dir $short]
      report_utilization -quiet -pblocks $pb -file $rpt_name
  }

  # Optional: append summary CSV (best-effort)
  set summary_csv [file join $RPT_DIR "all_runs.csv"]
  set bench_name $bench
  # Extract WNS/TNS/Fmax from timing summary (best-effort regex on returned string)
  set tstr [report_timing_summary -no_header -return_string]
  set WNS ""
  set TNS ""
  set FMAX ""
  if {[regexp -line {WNS.*?:\s*([-0-9\.]+)} $tstr -> WNS]} {}
  if {[regexp -line {TNS.*?:\s*([-0-9\.]+)} $tstr -> TNS]} {}
  if {[regexp -line {Fmax.*?:\s*([0-9\.]+)} $tstr -> FMAX]} {}

  # Extract Dynamic power
  set pstr [report_power -return_string]
  set PDYN ""
  if {[regexp -line {Dynamic\s+\|\s+([0-9\.]+)} $pstr -> PDYN]} {}
  if {$PDYN eq ""} {
    if {[regexp -line {Dynamic Power\s*:\s*([0-9\.]+)} $pstr -> PDYN]} {}
  }

  # Write CSV header if new
  if {![file exists $summary_csv]} {
    set fp [open $summary_csv "w"]
    puts $fp "bench,wns_ns,tns_ns,fmax_mhz,dynamic_w"
    close $fp
  }
  set fp [open $summary_csv "a"]
  puts $fp "$bench_name,$WNS,$TNS,$FMAX,$PDYN"
  close $fp

  close_project
  if {![info exists ::env(KEEP_TMP)] || $::env(KEEP_TMP) == 0} {
    file delete -force $proj
  }
}

exit
