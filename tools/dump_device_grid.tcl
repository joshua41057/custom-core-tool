proc __arg {name default} {
  upvar 1 argv argv
  set idx [lsearch -exact $argv $name]
  if {$idx >= 0 && ($idx+1) < [llength $argv]} { return [lindex $argv [expr {$idx+1}]] }
  return $default
}

proc __merge_runs {sorted_list} {
  if {[llength $sorted_list] == 0} { return {} }
  set a [lindex $sorted_list 0]; set b $a
  set out {}
  foreach v [lrange $sorted_list 1 end] {
    if {$v == $b+1} { set b $v } else { lappend out [list $a $b]; set a $v; set b $v }
  }
  lappend out [list $a $b]
  return $out
}

proc __rects_from_sites {sites} {
  if {![llength $sites]} { return {} }
  set x2ys {}
  foreach s $sites {
    if {![regexp {^([A-Z0-9_]+)_X([0-9]+)Y([0-9]+)$} $s -> kind x y]} { continue }
    dict lappend x2ys $x $y
    set last_kind $kind
  }
  set triples {}
  foreach x [lsort -integer [dict keys $x2ys]] {
    set ys [lsort -integer [dict get $x2ys $x]]
    foreach seg [__merge_runs $ys] {
      lassign $seg y0 y1
      lappend triples [list $x $y0 $y1]
    }
  }
  set key2xs {}
  foreach t $triples {
    lassign $t x y0 y1
    set key "$y0,$y1"
    dict lappend key2xs $key $x
  }
  set rects {}
  foreach key [dict keys $key2xs] {
    lassign [split $key ,] y0 y1
    set xs [lsort -integer [dict get $key2xs $key]]
    foreach xr [__merge_runs $xs] {
      lassign $xr x0 x1
      lappend rects [list $x0 $y0 $x1 $y1]
    }
  }
  return $rects
}

proc __rects_by_filter {site_filter} {
  set sites [get_sites -quiet -filter $site_filter]
  if {![llength $sites]} { return [list {} {}] }
  set bykind {}
  foreach s $sites {
    if {![regexp {^([A-Z0-9_]+)_X([0-9]+)Y([0-9]+)$} $s -> kind x y]} { continue }
    dict lappend bykind $kind $s
  }
  set kinds [lsort -unique [dict keys $bykind]]
  set out {}
  foreach k $kinds {
    set rects [__rects_from_sites [dict get $bykind $k]]
    foreach r $rects {
      lassign $r x0 y0 x1 y1
      lappend out [list $k $x0 $y0 $x1 $y1]
    }
  }
  return [list $out $kinds]
}

proc __slicem_cols {} {
  set xs {}
  foreach s [get_sites -quiet -filter {SITE_TYPE == SLICEM}] {
    if {[regexp {^SLICE_X([0-9]+)Y} $s -> x]} { lappend xs $x }
  }
  return [lsort -integer -unique $xs]
}

proc __clock_region_slice_box {} {
  set out {}
  foreach cr [lsort -dict [get_clock_regions -quiet]] {
    set sl [get_sites -quiet -of_objects $cr -filter {SITE_TYPE =~ SLICE*}]
    if {![llength $sl]} { continue }
    set minx {}; set maxx {}; set miny {}; set maxy {}
    foreach s $sl {
      if {![regexp {SLICE_X([0-9]+)Y([0-9]+)} $s -> x y]} { continue }
      if {$minx eq {} || $x < $minx} { set minx $x }
      if {$maxx eq {} || $x > $maxx} { set maxx $x }
      if {$miny eq {} || $y < $miny} { set miny $y }
      if {$maxy eq {} || $y > $maxy} { set maxy $y }
    }
    if {$minx ne {} && $miny ne {}} {
      lappend out [list $cr $minx $miny $maxx $maxy]
    }
  }
  return $out
}

proc __cr_rects_for_kind {cr kind_glob} {
  set sites [get_sites -quiet -of_objects [get_clock_regions -quiet $cr] -filter "SITE_TYPE =~ $kind_glob"]
  return [__rects_from_sites $sites]
}

proc dump_device_grid {outfile} {
  if {![llength [get_projects -quiet]]} {
    set part [__arg -part ""]
    if {$part eq ""} { puts "ERROR: no project open and -part not provided."; exit 1 }
    create_project -in_memory -part $part
    set close_after 1
  } else {
    set close_after 0
  }
  set part [get_property PART [current_project]]

  set rects_all {}
  foreach filt { {SITE_TYPE =~ SLICE*} {SITE_TYPE =~ DSP*} {SITE_TYPE =~ RAMB18*} {SITE_TYPE =~ RAMB36*} {SITE_TYPE =~ URAM*} } {
    lassign [__rects_by_filter $filt] rects kinds
    foreach r $rects { lappend rects_all $r }
  }

  set sm_cols [__slicem_cols]
  set cr_boxes [__clock_region_slice_box]

  set fp [open $outfile w]
  puts $fp "# DEVICE GRID (auto-generated)"
  puts $fp "# PART: $part"
  puts $fp "# Vivado: [version]"
  puts $fp "#"

  set toks {}
  foreach r [lsort -command {apply {{a b} {
      lassign $a ka xa ya xa2 ya2
      lassign $b kb xb yb xb2 yb2
      set c [string compare $ka $kb]
      if {$c != 0} { return $c }
      if {$xa != $xb} { return [expr {$xa < $xb ? -1 : 1}] }
      if {$ya != $yb} { return [expr {$ya < $yb ? -1 : 1}] }
      return 0
  }}} $rects_all] {
    lassign $r kind x0 y0 x1 y1
    puts -nonewline $fp ""
    lappend toks "${kind}_X${x0}Y${y0}:${kind}_X${x1}Y${y1}"
  }
  puts $fp "GRID_RANGES [join $toks {; }]"

  if {[llength $sm_cols]} {
    set ranges {}
    foreach ab [__merge_runs $sm_cols] {
      lassign $ab a b
      if {$a == $b} { lappend ranges $a } else { lappend ranges "$a-$b" }
    }
    puts $fp "SLICEM_COLS: [join $ranges ,]"
  } else {
    puts $fp "SLICEM_COLS: "
  }

  foreach it [lsort -dict $cr_boxes] {
    lassign $it cr x0 y0 x1 y1
    puts $fp "CLOCK_REGION $cr SLICE_X${x0}Y${y0}:SLICE_X${x1}Y${y1}"
  }

  foreach it [lsort -dict $cr_boxes] {
    lassign $it cr x0 y0 x1 y1
    foreach {kg label} { {DSP*} DSP48E2 {RAMB18*} RAMB18E2 {RAMB36*} RAMB36E2 {URAM*} URAM288E2 } {
      set rects [__cr_rects_for_kind $cr $kg]
      if {[llength $rects]} {
        set toks {}
        foreach r $rects {
          lassign $r rx0 ry0 rx1 ry1
          lappend toks "${label}_X${rx0}Y${ry0}:${label}_X${rx1}Y${ry1}"
        }
        puts $fp "CR_RANGES $cr $label [join $toks {; }]"
      }
    }
  }

  close $fp
  puts "Info: Wrote device grid -> $outfile"
  if {$close_after} { close_project }
}

if {[info exists ::argv0] && $::argv0 eq [info script]} {
  set out [__arg -out ""]
  if {$out eq ""} { puts "ERROR: -out <file> required"; exit 1 }
  dump_device_grid $out
}
