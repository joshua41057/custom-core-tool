# auto_pblock.tcl (generated)
resize_pblock [get_pblocks pblock_1] -add {SLICE_X50Y840:SLICE_X54Y899}
resize_pblock [get_pblocks pblock_1] -add {DSP48E2_X7Y336:DSP48E2_X7Y359}

set inst [get_cells -hier {glen[0].blk_i}]
foreach pb [get_pblocks -of_objects $inst] { remove_cells_from_pblock $pb $inst }
add_cells_to_pblock [get_pblocks pblock_1] $inst -clear_locs
