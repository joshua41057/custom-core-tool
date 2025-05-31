# speeds.tcl  - report WNS / Fmax for every generated Pblock
set period_ps 3333      ;# ⇒ 300 MHz 

set pb_list [get_pblocks pblock_*]
if {[llength $pb_list] == 0} {
    puts "No pblocks found → nothing to report"
    return
}

foreach pb $pb_list {
    set cells   [get_cells -hier -filter "PBLOCK == $pb"]
    set tpaths  [get_timing_paths -from $cells -to $cells -max_paths 1]
    if {[llength $tpaths]} {
        set wns  [get_property SLACK $tpaths]
        set fmax [expr {1000.0 / ($period_ps/1000.0 - $wns)}]
        puts "$pb  WNS=${wns} ns   Fmax=[format %.1f $fmax] MHz"
    } else {
        puts "$pb  No timing paths found."
    }

    report_utilization -quiet -pblocks $pb \
        -file [format "utilization_%s.rpt" $pb]
}