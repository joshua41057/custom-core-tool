# speeds.tcl  - report WNS / Fmax for every generated Pblock
set period_ps 3333      ;# ⇒ 300 MHz
set n_case   1         ;# update if N_CASE changes

set pb_list {}
for {set i 1} {$i <= $n_case} {incr i} {
    lappend pb_list [format "pblock_%d" $i]
}

foreach pb $pb_list {
    set cells_in_pb [get_cells -hierarchical -filter "PBLOCK == $pb"]
    set timing_paths [get_timing_paths -from $cells_in_pb -to $cells_in_pb -max_paths 1]
    if {[llength $timing_paths]} {
        set wns  [get_property SLACK $timing_paths]
        set fmax [expr {1000.0 / ($period_ps/1000.0 - $wns)}]
        puts "$pb  WNS=$wns ns   Fmax=[format %.1f $fmax] MHz"
    } else {
        puts "$pb  No timing paths found."
    }
    report_utilization -pblocks $pb -file [format "utilization_%s.rpt" $pb]
}
