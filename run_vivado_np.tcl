foreach e {
  TCL_MEM_DEBUG TCL_TRACE_DEBUG PYTHONDUMPREFS PYTHONMALLOC
  G_DEBUG G_SLICE GOBJECT_DEBUG MALLOC_CHECK_ MALLOC_PERTURB_
  PYTHONHOME PYTHONPATH PYTHONUSERBASE PYTHONEXECUTABLE PYTHONCASEOK
  PYTHONNOUSERSITE
} {
  if {[info exists ::env($e)]} { unset ::env($e) }
}
if {[llength [info commands memory]]} {
  catch { memory trace off }
  catch { memory validate off }
}

if { [info exists ::env(PART)] } {
  set PART $::env(PART)
} else {
  set PART "xcu200-fsgd2104-2-e"
}

set ROOT       [pwd]
set BENCH_ROOT [expr {[info exists ::env(BENCH_ROOT)] ? $::env(BENCH_ROOT) : [file join $ROOT example]}]
set RTL_DIR    [file join $ROOT rtl]
set CONS_DIR   [file join $ROOT constraints]
set XCI_ROOT   [file join $ROOT .srcs sources_1 ip]

set GRID_FILE ""
puts "INFO: GRID_FILE not required for CR-based pblocks (skipping grid lookup)."

set_param general.maxThreads 1

proc __parse_cli {} {
  set av {}; if {[info exists ::argv]} { set av $::argv }

  set exp    ""
  set stage  "all"
  set limit  "full"
  set benches {}

  set n [llength $av]
  for {set i 0} {$i < $n} {incr i} {
    set a [lindex $av $i]

    if {$a eq "-exp"} {
      incr i
      if {$i < $n} { set exp   [lindex $av $i] }
      continue
    }

    if {$a eq "-stage"} {
      incr i
      if {$i < $n} { set stage [string tolower [lindex $av $i]] }
      continue
    }

    if {$a eq "-limit"} {
      incr i
      if {$i < $n} { set limit [lindex $av $i] }
      continue
    }

    lappend benches $a
  }

  return [list $exp $stage $limit $benches]
}

lassign [__parse_cli] EXP_NAME STAGE LIMIT_NAME BENCHES_CLI
if {$STAGE ni {"synth" "impl" "all"}} {
  set STAGE "all"
}

if {$EXP_NAME ne ""} {
  set RPT_DIR [file join $ROOT reports $EXP_NAME]
} else {
  set RPT_DIR [file join $ROOT reports]
}
file mkdir $RPT_DIR
file mkdir [file join $RPT_DIR benches]
file mkdir [file join $RPT_DIR single]

puts "INFO: ROOT        = $ROOT"
puts "INFO: BENCH_ROOT  = $BENCH_ROOT"
puts "INFO: LIMIT_NAME  = $LIMIT_NAME"
puts "INFO: STAGE       = $STAGE"
puts "INFO: RPT_DIR     = $RPT_DIR"

proc __rglob {dir pattern {visitedName __rglob_seen}} {
  upvar 1 $visitedName seen
  if {![file exists $dir] || ![file isdirectory $dir]} { return {} }
  set ndir [file normalize $dir]
  if {[info exists seen($ndir)]} { return {} }
  set seen($ndir) 1
  set out {}
  foreach f [glob -nocomplain -directory $ndir -types f $pattern] {
    lappend out $f
  }
  foreach d [glob -nocomplain -directory $ndir -types d *] {
    if {[string match "*/.git*" $d]} { continue }
    set out [concat $out [__rglob $d $pattern $visitedName]]
  }
  return $out
}

proc __safe {s} {
  return [regsub -all {[^A-Za-z0-9_]} $s "_"]
}

proc __benchdir {bench} {
  set SAFE [__safe $bench]
  set bdir [file join $::BENCH_ROOT $bench]
  if {![file isdirectory $bdir]} {
    set alt1 [file join $::BENCH_ROOT $SAFE]
    set tmp $SAFE
    regsub {_} $tmp "." tmp
    set alt2 [file join $::BENCH_ROOT $tmp]
    if {[file isdirectory $alt1]} {
      return $alt1
    } elseif {[file isdirectory $alt2]} {
      return $alt2
    } else {
      return ""
    }
  }
  return $bdir
}

proc __read_or_make_ip {} {
  if {![info exists ::XCI_ROOT]} { return }
  set ip_xci [__rglob $::XCI_ROOT *.xci]
  if {[llength $ip_xci]} {
    foreach x [lsort -dict $ip_xci] {
      catch {read_ip $x}
    }
    catch { update_ip_catalog }
    catch { upgrade_ip [get_ips -quiet *] }
    catch { generate_target {synthesis} [get_ips -quiet *] }
  }
}

proc __bench_has_limit {bench limitname} {
  set bdir [__benchdir $bench]
  if {$bdir eq ""} { return 0 }

  if {$limitname eq "full"} {
    return [file exists [file join $bdir "len_table_pkg.sv"]]
  }

  set fname [format "len_table_pkg_%s.sv" $limitname]
  return [file exists [file join $bdir $fname]]
}

proc __pick_lenpkg {bdir limitname} {
  if {$limitname eq "full"} {
    set cand [file join $bdir "len_table_pkg.sv"]
    if {[file exists $cand]} { return $cand }
    return ""
  }

  set cand [file join $bdir [format "len_table_pkg_%s.sv" $limitname]]
  if {[file exists $cand]} { return $cand }
  return ""
}

proc __synth_one {benchid} {
  set SAFE       [__safe $benchid]
  set OUT_BENCH  [file join $::RPT_DIR benches $SAFE]
  file mkdir $OUT_BENCH
  set bench_dcp  [file join $OUT_BENCH post_synth.dcp]

  if {[file exists $bench_dcp]} {
    puts "== SKIP synth (exists): $benchid (limit=$::LIMIT_NAME) =="
    return
  }

  if {[llength [get_projects -quiet]]} { close_project }
  create_project -in_memory -part $::PART
  set_property target_language Verilog [current_project]
  set_property simulator_language Mixed [current_project]
  __read_or_make_ip

  set UOP [file join $::RTL_DIR uop_pkg.sv]
  if {![file exists $UOP]} {
    puts "ERROR: missing $UOP"
    exit 1
  }
  read_verilog -sv $UOP

  set TOP_RTL [file join $::RTL_DIR top_multi_len.sv]

  foreach f [lsort -dict [__rglob $::RTL_DIR *.sv]] {
    set tail [file tail $f]
    if {$tail in {"uop_pkg.sv" "len_table_pkg.sv" "top_multi_len.sv"}} {
      continue
    }
    if {[string match "len_table_pkg*" $tail]} {
      continue
    }
    read_verilog -sv $f
  }

  foreach f [lsort -dict [__rglob $::RTL_DIR *.v]] {
    read_verilog $f
  }

  set bdir [__benchdir $benchid]
  if {$bdir eq ""} {
    puts "ERROR: bench dir not found for $benchid"
    exit 1
  }

  set lenpkg [__pick_lenpkg $bdir $::LIMIT_NAME]
  if {$lenpkg eq ""} {
    puts "ERROR: no matching len_table_pkg for $benchid at limit=$::LIMIT_NAME"
    exit 1
  }
  puts "INFO: [$benchid] using len_table_pkg = $lenpkg"
  read_verilog -sv $lenpkg

  foreach f [lsort -dict [glob -nocomplain -directory $bdir *.sv]] {
    if {$f eq $lenpkg} {
      continue
    }
    set tail [file tail $f]
    if {[string match "len_table_pkg*" $tail]} {
      continue
    }
    read_verilog -sv $f
  }

  if {[file exists $TOP_RTL]} {
    read_verilog -sv $TOP_RTL
  } else {
    puts "ERROR: missing $TOP_RTL"
    exit 1
  }

  catch { update_compile_order -fileset sources_1 }

  set BENCH_TOP "top_multi_len"

  set XDC [file join $::CONS_DIR clocks.xdc]
  if {[file exists $XDC]} {
    read_xdc $XDC
  }

  synth_design -top $BENCH_TOP -part $::PART -flatten_hierarchy rebuilt

  report_utilization               -file [file join $OUT_BENCH pre_impl_util.rpt]
  report_utilization -hierarchical -file [file join $OUT_BENCH pre_impl_util_hier.rpt]
  report_timing_summary            -file [file join $OUT_BENCH pre_impl_timing.rpt]

  write_checkpoint -force $bench_dcp
  close_project

  puts "== DONE synth(limit=$::LIMIT_NAME): $benchid =="
}

proc __impl_one {benchid} {
  set SAFE        [__safe $benchid]
  set OUT_BENCH  [file join $::RPT_DIR benches $SAFE]
  set OUT_SINGLE [file join $::RPT_DIR single  $SAFE]
  file mkdir $OUT_SINGLE

  set bench_dcp      [file join $OUT_BENCH  post_synth.dcp]
  set post_place_dcp [file join $OUT_SINGLE post_place.dcp]
  set post_route_dcp [file join $OUT_SINGLE post_route.dcp]

  if {![file exists $bench_dcp]} {
    puts "INFO: synth DCP missing. Running synth for $benchid..."
    __synth_one $benchid
    if {![file exists $bench_dcp]} {
      puts "ERROR: failed to create $bench_dcp"
      exit 1
    }
  }

  if {[llength [get_projects -quiet]]} { close_project }
  create_project -in_memory -part $::PART
  set_property target_language Verilog [current_project]
  set_property simulator_language Mixed [current_project]
  __read_or_make_ip

  open_checkpoint $bench_dcp

  set pbfile [file join $OUT_BENCH auto_pblocks_${SAFE}.tcl]
  file delete -force $pbfile

  set blist [open [file join $OUT_BENCH benches.txt] w]
  puts $blist $benchid
  close $blist

  set py [file join $::ROOT tools auto_pblock_gen.py]
  if {![file exists $py]} { set py [file join $::ROOT auto_pblock_gen.py] }
  if {![file exists $py]} {
    puts "ERROR: missing auto_pblock_gen.py under $::ROOT/tools or $::ROOT"
    exit 1
  }

  set CR_CSV [file join [file dirname $py] u200_cr_summary.csv]
  if {![file exists $CR_CSV]} { set CR_CSV [file join $::ROOT u200_cr_summary.csv] }
  if {![file exists $CR_CSV]} { set CR_CSV [file join $::CONS_DIR u200_cr_summary.csv] }
  if {![file exists $CR_CSV]} {
    puts "ERROR: u200_cr_summary.csv not found near $py, project root, or constraints/"
    exit 1
  }

  puts "INFO: regenerating pblock tcl via $py"

  set _LANG   [expr {[info exists ::env(LANG)]   ? $::env(LANG)   : "C.UTF-8"}]
  set _LC_ALL [expr {[info exists ::env(LC_ALL)] ? $::env(LC_ALL) : "C.UTF-8"}]

  exec /usr/bin/env -i \
      PATH=$::env(PATH) HOME=$::env(HOME) LANG=$_LANG LC_ALL=$_LC_ALL \
      python3 $py --bench-list [file join $OUT_BENCH benches.txt] \
                  --bench-rpt-root [file join $::RPT_DIR benches] \
                  --cr-summary $CR_CSV \
                  --out $pbfile \
                  --origin-crx 0 --origin-cry 0 \
                  --target-aspect 0.90 --aspect-tol 0.25

  if {![file exists $pbfile]} {
    puts "ERROR: pblock file not found after generation: $pbfile"
    exit 1
  }

  set fh [open $pbfile r]
  set s [read $fh]
  close $fh
  if {[regexp -nocase {SNAPPING_MODE\s+TILE} $s]} {
    regsub -all -nocase {SNAPPING_MODE\s+TILE} $s {SNAPPING_MODE ON} s
    set fh [open $pbfile w]
    puts -nonewline $fh $s
    close $fh
    puts "INFO: normalized SNAPPING_MODE TILE -> ON in $pbfile"
  }

  source $pbfile

  set pbname pblock_${SAFE}
  if {![llength [get_pblocks -quiet $pbname]]} {
    puts "ERROR: expected pblock $pbname not found after source"
    exit 1
  }

  set snap [get_property SNAPPING_MODE [get_pblocks -quiet $pbname]]
  puts "INFO: $pbname SNAPPING_MODE=$snap"
  set ns [llength [get_sites -of_objects [get_pblocks -quiet $pbname]]]
  puts "INFO: $pbname site count = $ns"
  if {$ns == 0} {
    puts "ERROR: $pbname has 0 sites (check CR rectangle/csv)"
    exit 1
  }

  report_utilization -pblock $pbname -file [file join $OUT_SINGLE pblock_util_pre_place.rpt]

  place_design
  write_checkpoint -force $post_place_dcp
  route_design
  write_checkpoint -force $post_route_dcp

  report_utilization    -file [file join $OUT_SINGLE post_route_util.rpt]
  report_timing_summary -file [file join $OUT_SINGLE post_route_timing.rpt]
  report_clocks         -file [file join $OUT_SINGLE post_route_clocks.rpt]

  if {[llength [get_pblocks -quiet $pbname]]} {
    report_utilization -pblock $pbname -file [file join $OUT_SINGLE pblock_util.rpt]
  }

  close_project
  puts "== DONE impl(limit=$::LIMIT_NAME): $benchid =="
}

set sel_benches {}
if {[llength $::BENCHES_CLI] > 0} {
  foreach b $::BENCHES_CLI {
    if {[__bench_has_limit $b $::LIMIT_NAME]} {
      lappend sel_benches $b
    } else {
      puts "INFO: SKIP explicit bench $b (no len_table_pkg_$::LIMIT_NAME.sv)"
    }
  }
} else {
  foreach d [glob -nocomplain -types d [file join $BENCH_ROOT *]] {
    set b [file tail $d]
    if {[__bench_has_limit $b $::LIMIT_NAME]} {
      lappend sel_benches $b
    } else {
      puts "INFO: SKIP auto bench $b (no len_table_pkg_$::LIMIT_NAME.sv)"
    }
  }
}

if {[llength $sel_benches] == 0} {
  puts "ERROR: No benches selected for limit=$::LIMIT_NAME."
  exit 1
}
set sel_benches [lsort -dict $sel_benches]
puts "INFO: Final bench list for limit=$::LIMIT_NAME -> $sel_benches"

if {$STAGE in {"synth" "all"}} {
  foreach b $sel_benches {
    __synth_one $b
  }
  puts "== ALL DONE (synth, limit=$::LIMIT_NAME) =="
}
if {$STAGE in {"impl" "all"}} {
  foreach b $sel_benches {
    __impl_one $b
  }
  puts "== ALL DONE (impl, limit=$::LIMIT_NAME) =="
}

catch { close_project }
quit -f
