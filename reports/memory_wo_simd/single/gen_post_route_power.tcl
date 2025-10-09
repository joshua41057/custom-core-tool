# gen_post_route_power.tcl
# Usage:
#   vivado -mode batch -source gen_post_route_power.tcl -tclargs <root_or_single_dir>
# Example:
#   vivado -mode batch -source gen_post_route_power.tcl -tclargs ./reports/memory_wo_simd/single

proc gen_power_for_dcp {dcp_path rpt_path} {
  puts "INFO: Opening checkpoint: $dcp_path"
  catch { close_design }
  if {[catch { open_checkpoint $dcp_path } err]} {
    puts "WARN: open_checkpoint failed: $err"
    return 1
  }

  if {[file exists $rpt_path]} {
    file delete -force -- $rpt_path
  }

  if {[catch { report_power -file $rpt_path } err2]} {
    puts "ERROR: report_power failed: $err2"
    catch { close_design }
    return 1
  }

  puts "INFO: Wrote power report: $rpt_path"
  catch { close_design }
  return 0
}

set root_dir [lindex $argv 0]
if {$root_dir eq ""} {
  set root_dir [pwd]
}
set root_dir [file normalize $root_dir]

set search_dirs {}
if {[file tail $root_dir] eq "single"} {
  set search_dirs [glob -nocomplain -types d -directory $root_dir *]
} elseif {[file isdirectory [file join $root_dir "single"]]} {
  set search_dirs [glob -nocomplain -types d -directory [file join $root_dir "single"] *]
} else {
  set search_dirs [glob -nocomplain -types d -directory $root_dir *]
}

set benches [lsort $search_dirs]
if {[llength $benches] == 0} {
  puts "ERROR: No benchmark subdirectories found under: $root_dir"
  exit 2
}

set n_ok 0
set n_fail 0
foreach b $benches {
  set dcp [file join $b "post_route.dcp"]
  if {![file exists $dcp]} {
    continue
  }
  set rpt [file join $b "post_route_power.rpt"]
  set rc [gen_power_for_dcp $dcp $rpt]
  if {$rc == 0} {
    incr n_ok
  } else {
    incr n_fail
  }
}

puts "INFO: Power report generation done. OK=$n_ok, FAIL=$n_fail"
if {$n_fail > 0} { exit 1 } else { exit 0 }
