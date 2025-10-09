# ==== Metrics per pblock (AREA-ONLY, no membership, works with PR regions) ====
# Outputs: pblock,bench,wns_ns,achieved_period_ns,fmax_mhz,dynamic_w_watts,
#          lut,ff,dsp,ramb18,ramb36,uram,slices_used,in_area_prims
# Notes:
#  - WNS: worst setup slack of any path that *passes through* the pblock area
#  - Util/Power: only placed primitives (LOC!="") inside pblock sites
# Usage:
#  vivado -mode batch -source pblock_metrics_areaonly.tcl -tclargs <post_place.dcp> \
#         [--out <csv>] [--clocks <clocks.xdc>] [--default-toggle 12.5]

proc __to_double {x {def {}}} {
  if {![info exists x] || $x eq ""} { return $def }
  if {[catch {expr {double($x)}} v]} { return $def }
  return $v
}
proc __call_report {cmdList} {
  set txt ""
  if {![catch { eval $cmdList } txt]} { return $txt }
  set tmp [file normalize "__tmp_[pid]_[clock clicks].rpt"]
  set cmd2 $cmdList; lappend cmd2 -file $tmp
  if {[catch { eval $cmd2 } emsg]} { return "" }
  set fp [open $tmp r]; set txt [read $fp]; close $fp
  catch { file delete -force $tmp }
  return $txt
}
proc __bench_tail {pb} {
  set n [get_property NAME $pb]
  if {[string first "pblock_" $n] == 0} { return [string range $n 7 end] }
  return $n
}
proc __min_period {} {
  set minT {}
  foreach c [get_clocks] {
    set p [get_property PERIOD $c]
    if {$p eq ""} { continue }
    if {$minT eq {} || $p < $minT} { set minT $p }
  }
  if {$minT eq {}} { set minT 10.0 }
  return $minT
}

# ---- area selections ----
proc __sites {pb} { get_sites -quiet -of_objects $pb }
proc __cells_in_area {pb} {
  set s [__sites $pb]
  if {![llength $s]} { return {} }
  # only placed primitives
  return [get_cells -quiet -of_objects $s -filter {IS_PRIMITIVE==1 && LOC != ""}]
}
proc __pins_in_area {pb} {
  set c [get_cells -quiet -of_objects [__sites $pb]]
  if {![llength $c]} { return {} }
  return [get_pins -quiet -of_objects $c]
}

# ---- util in area ----
proc __util_area {pb} {
  set placed [__cells_in_area $pb]
  if {![llength $placed]} { return [list 0 0 0 0 0 0 0] }
  set lut  [llength [filter $placed {REF_NAME =~ LUT*}]]
  set ffL  [filter $placed {PRIMITIVE_GROUP == REGISTERS}]
  set ff   [llength $ffL]
  if {$ff == 0} { set ff [llength [filter $placed {REF_NAME =~ FD* || REF_NAME =~ LD* || REF_NAME =~ *REG*}]] }
  set dsp  [llength [filter $placed {REF_NAME =~ DSP48*}]]
  set b18  [llength [filter $placed {REF_NAME =~ RAMB18*}]]
  set b36  [llength [filter $placed {REF_NAME =~ RAMB36*}]]
  set uram [llength [filter $placed {REF_NAME =~ URAM*}]]
  return [list $lut $ff $dsp $b18 $b36 $uram [llength $placed]]
}

# ---- slices used in area ----
proc __slices_used {pb} {
  set sites [get_sites -quiet -of_objects $pb -filter {SITE_TYPE =~ SLICE*}]
  if {![llength $sites]} { return 0 }
  set placed [get_cells -quiet -of_objects $sites -filter {LOC != ""}]
  if {![llength $placed]} { return 0 }
  set used {}
  foreach c $placed {
    set loc [get_property LOC $c]
    if {$loc ne ""} { lappend used $loc }
  }
  set uniq [lsort -unique $used]
  return [llength $uniq]
}

# ---- WNS: try reg->reg inside area, then fallback to through-pins inside area ----
proc __wns_area {pb} {
  # 1) reg->reg confined
  set regs [get_cells -quiet -of_objects [__sites $pb] -filter {PRIMITIVE_GROUP == REGISTERS && LOC != ""}]
  if {[llength $regs] >= 2} {
    set p [get_timing_paths -quiet -unique_pins -from $regs -to $regs -nworst 1 -max_paths 1]
    if {[llength $p]} {
      set v [get_property SLACK [lindex $p 0]]
      set d [__to_double $v]
      if {$d ne {}} { return $d }
    }
  }
  # 2) through-pins (robust for PR pblocks)
  set pins [__pins_in_area $pb]
  if {[llength $pins]} {
    # limit pin list to avoid blow-up
    set pins [lrange $pins 0 20000]
    set p2 [get_timing_paths -quiet -unique_pins -through $pins -nworst 1 -max_paths 1]
    if {[llength $p2]} {
      set v2 [get_property SLACK [lindex $p2 0]]
      set d2 [__to_double $v2]
      if {$d2 ne {}} { return $d2 }
    }
  }
  # 3) give up
  return {}
}

# ---- Power over area (no -pblocks): select cells in area; one call if possible ----
proc __power_area_watts {pb} {
  if {![llength [info commands report_power]]} { return {} }
  catch { update_power -quiet }
  set cells [__cells_in_area $pb]
  if {![llength $cells]} { return {} }

  set t [__call_report [list report_power -quiet -cells $cells -return_string]]
  if {$t ne ""} {
    foreach ln [split $t "\n"] {
      if {[regexp {On-?Chip Dynamic Power[^0-9]*([0-9.]+)\s*(m?W)} $ln -> v u]} { return [expr {$u eq "mW" ? double($v)/1000.0 : double($v)}] }
      if {[regexp {Dynamic Power[^0-9]*([0-9.]+)\s*(m?W)}        $ln -> v u]} { return [expr {$u eq "mW" ? double($v)/1000.0 : double($v)}] }
      if {[regexp {^\s*\|\s*Total\b.*\|\s*([0-9.]+)\s*(m?W)\s*\|} $ln -> v u]} { return [expr {$u eq "mW" ? double($v)/1000.0 : double($v)}] }
    }
  }

  set total 0.0
  set N 2000
  set n [llength $cells]
  for {set i 0} {$i < $n} {incr i $N} {
    set chunk [lrange $cells $i [expr {$i+$N-1}]]
    set t2 [__call_report [list report_power -quiet -cells $chunk -return_string]]
    if {$t2 eq ""} { continue }
    foreach ln [split $t2 "\n"] {
      if {[regexp {On-?Chip Dynamic Power[^0-9]*([0-9.]+)\s*(m?W)} $ln -> v u]} { set total [expr {$total + ($u eq "mW" ? double($v)/1000.0 : double($v))}] }
      if {[regexp {Dynamic Power[^0-9]*([0-9.]+)\s*(m?W)}        $ln -> v u]} { set total [expr {$total + ($u eq "mW" ? double($v)/1000.0 : double($v))}] }
      if {[regexp {^\s*\|\s*Total\b.*\|\s*([0-9.]+)\s*(m?W)\s*\|} $ln -> v u]} { set total [expr {$total + ($u eq "mW" ? double($v)/1000.0 : double($v))}] }
    }
  }
  return $total
}

# ---------------- Main ----------------
if {$argc < 1} {
  puts "USAGE: -tclargs <post_place.dcp> [--out <csv>] [--clocks <clocks.xdc>] [--default-toggle <pct>]"; exit 1
}
set DCP [file normalize [lindex $argv 0]]
set OUT ""; set CLKS ""; set TOGGLE 12.5
for {set i 1} {$i < $argc} {incr i} {
  set a [lindex $argv $i]
  if {$a eq "--out"}            { incr i; set OUT   [file normalize [lindex $argv $i]]; continue }
  if {$a eq "--clocks"}         { incr i; set CLKS  [file normalize [lindex $argv $i]]; continue }
  if {$a eq "--default-toggle"} { incr i; set TOGGLE [lindex $argv $i]; continue }
}

if {![file exists $DCP]} { puts "ERROR: DCP not found: $DCP"; exit 1 }
open_checkpoint $DCP

if {[llength [get_clocks]] == 0 && $CLKS ne "" && [file exists $CLKS]} {
  puts "Info: No clocks in DCP; reading $CLKS"
  read_xdc $CLKS
}
catch { set_switching_activity -default_toggle_rate $TOGGLE -propagate -all }

set pbs [lsort -dict [get_pblocks -quiet pblock_*]]
if {![llength $pbs]} { puts "ERROR: no pblock_* in design"; exit 1 }

set minT [__min_period]
if {$OUT eq ""} { set OUT [file join [file dirname $DCP] "pblock_metrics.csv"] }
set fp [open $OUT w]
puts $fp "pblock,bench,wns_ns,achieved_period_ns,fmax_mhz,dynamic_w_watts,lut,ff,dsp,ramb18,ramb36,uram,slices_used,in_area_prims"

foreach pb $pbs {
  set name  [get_property NAME $pb]
  set bench [__bench_tail $pb]

  # Util + slices + in_area
  lassign [__util_area $pb] LUT FF DSP B18 B36 URAM INAREA
  set SLICES [__slices_used $pb]

  # WNS/Fmax
  set wns [__wns_area $pb]
  if {$wns eq {}} {
    set W "NA"; set T "NA"; set F "NA"
  } else {
    set W [format "%.3f" $wns]
    set achT [expr {double($minT) - double($wns)}]
    if {$achT <= 0.001} { set achT 0.001 }
    set T [format "%.3f" $achT]
    set F [format "%.2f" [expr {1000.0 / $achT}]]
  }

  # Power
  set P {}
  if {![catch { set P [__power_area_watts $pb] }]} {}
  set P [expr {$P eq {} ? "NA" : [format "%.6f" $P]}]

  puts $fp [format "%s,%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d" \
    $name $bench $W $T $F $P \
    $LUT $FF $DSP $B18 $B36 $URAM $SLICES $INAREA]
}
close $fp
puts "CSV written: [file normalize $OUT]"
exit
