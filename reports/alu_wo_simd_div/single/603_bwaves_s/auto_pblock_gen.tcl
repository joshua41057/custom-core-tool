if {[llength [get_pblocks -quiet {pblock_u_603_bwaves_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_603_bwaves_s}] }
create_pblock pblock_u_603_bwaves_s
set pblk [get_pblocks -quiet {pblock_u_603_bwaves_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X142Y840:SLICE_X159Y899}
set hc [get_cells -quiet top_bench__603_bwaves_s/u_603_bwaves_s]
if {![llength $hc]} { set tail [lindex [split "top_bench__603_bwaves_s/u_603_bwaves_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_603_bwaves_s"; exit 1 }
