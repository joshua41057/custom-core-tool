proc get_util {rpt pattern} {
    set pattern [string trim $pattern]
    foreach line [split $rpt \n] {
        if {[regexp {^\|\s*([^|]+?)\s*\|} $line -> tag]} {
            set tag [string trim $tag]
            if {$tag eq $pattern} {
                set fields [split $line |]
                for {set i [expr {[llength $fields]-1}]} {$i>=0} {incr i -1} {
                    set tok [string trim [lindex $fields $i]]
                    if {$tok ne "" && [string is double -strict $tok]} {
                        return $tok
                    }
                }
            }
        }
    }
    return "NA"
}

# ---------- 메인 ----------
set pb pblock_1;
set rpt [report_utilization -pblocks $pb -return_string]

set clb_util [get_util $rpt "CLB"]
set dsp_util [get_util $rpt "DSPs"]

puts [format "%-10s  CLB%%=%6s   DSP%%=%6s" $pb $clb_util $dsp_util]