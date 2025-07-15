# auto_pblock.tcl (generated)
if {![llength [get_pblocks pblock_1]]} {
    create_pblock pblock_1
}
resize_pblock [get_pblocks pblock_1] -add {SLICE_X34Y780:SLICE_X54Y899}
resize_pblock [get_pblocks pblock_1] -add {DSP48E2_X5Y312:DSP48E2_X7Y359}

set inst [get_cells -hier -filter {NAME =~ "glen[*].blk_i"}]
foreach pb [get_pblocks -of_objects $inst] {
    remove_cells_from_pblock $pb $inst
}
add_cells_to_pblock [get_pblocks pblock_1] $inst -clear_locs
set_property CONTAIN_ROUTING true [get_pblocks pblock_1]
