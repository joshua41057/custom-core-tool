if {[llength [get_pblocks -quiet {pblock_u_521_wrf_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_521_wrf_r}] }
create_pblock pblock_u_521_wrf_r
set pblk [get_pblocks -quiet {pblock_u_521_wrf_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X142Y840:SLICE_X152Y899}
set hc [get_cells -quiet top_bench__521_wrf_r/u_521_wrf_r]
if {![llength $hc]} { set tail [lindex [split "top_bench__521_wrf_r/u_521_wrf_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_521_wrf_r"; exit 1 }
