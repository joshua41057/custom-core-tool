# == auto_pblock_dsp_aware (SLICE-only; hardblocks bound later by TILE) ==
if {![llength [get_pblocks -quiet {pblock_u_548_exchange2_r}]]} { create_pblock pblock_u_548_exchange2_r }
set pblk [get_pblocks -quiet {pblock_u_548_exchange2_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X8Y0:SLICE_X12Y839}
set __inst_full "top_multi_bench/u_548_exchange2_r"
set __inst_tail "u_548_exchange2_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_505_mcf_r}]]} { create_pblock pblock_u_505_mcf_r }
set pblk [get_pblocks -quiet {pblock_u_505_mcf_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X0Y0:SLICE_X3Y839}
set __inst_full "top_multi_bench/u_505_mcf_r"
set __inst_tail "u_505_mcf_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_605_mcf_s}]]} { create_pblock pblock_u_605_mcf_s }
set pblk [get_pblocks -quiet {pblock_u_605_mcf_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X3Y0:SLICE_X7Y839}
set __inst_full "top_multi_bench/u_605_mcf_s"
set __inst_tail "u_605_mcf_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_525_x264_r}]]} { create_pblock pblock_u_525_x264_r }
set pblk [get_pblocks -quiet {pblock_u_525_x264_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X12Y0:SLICE_X17Y839}
set __inst_full "top_multi_bench/u_525_x264_r"
set __inst_tail "u_525_x264_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_625_x264_s}]]} { create_pblock pblock_u_625_x264_s }
set pblk [get_pblocks -quiet {pblock_u_625_x264_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X17Y0:SLICE_X19Y839}
resize_pblock $pblk -add {SLICE_X19Y0:SLICE_X22Y839}
set __inst_full "top_multi_bench/u_625_x264_s"
set __inst_tail "u_625_x264_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_538_imagick_r}]]} { create_pblock pblock_u_538_imagick_r }
set pblk [get_pblocks -quiet {pblock_u_538_imagick_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X22Y0:SLICE_X26Y839}
set __inst_full "top_multi_bench/u_538_imagick_r"
set __inst_tail "u_538_imagick_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_648_exchange2_s}]]} { create_pblock pblock_u_648_exchange2_s }
set pblk [get_pblocks -quiet {pblock_u_648_exchange2_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X26Y0:SLICE_X30Y839}
set __inst_full "top_multi_bench/u_648_exchange2_s"
set __inst_tail "u_648_exchange2_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_541_leela_r}]]} { create_pblock pblock_u_541_leela_r }
set pblk [get_pblocks -quiet {pblock_u_541_leela_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X30Y0:SLICE_X33Y839}
resize_pblock $pblk -add {SLICE_X33Y0:SLICE_X35Y839}
set __inst_full "top_multi_bench/u_541_leela_r"
set __inst_tail "u_541_leela_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_641_leela_s}]]} { create_pblock pblock_u_641_leela_s }
set pblk [get_pblocks -quiet {pblock_u_641_leela_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X35Y0:SLICE_X39Y839}
set __inst_full "top_multi_bench/u_641_leela_s"
set __inst_tail "u_641_leela_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_519_lbm_r}]]} { create_pblock pblock_u_519_lbm_r }
set pblk [get_pblocks -quiet {pblock_u_519_lbm_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X39Y0:SLICE_X43Y839}
set __inst_full "top_multi_bench/u_519_lbm_r"
set __inst_tail "u_519_lbm_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_531_deepsjeng_r}]]} { create_pblock pblock_u_531_deepsjeng_r }
set pblk [get_pblocks -quiet {pblock_u_531_deepsjeng_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X43Y0:SLICE_X47Y839}
set __inst_full "top_multi_bench/u_531_deepsjeng_r"
set __inst_tail "u_531_deepsjeng_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_631_deepsjeng_s}]]} { create_pblock pblock_u_631_deepsjeng_s }
set pblk [get_pblocks -quiet {pblock_u_631_deepsjeng_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X47Y0:SLICE_X51Y839}
set __inst_full "top_multi_bench/u_631_deepsjeng_s"
set __inst_tail "u_631_deepsjeng_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_510_parest_r}]]} { create_pblock pblock_u_510_parest_r }
set pblk [get_pblocks -quiet {pblock_u_510_parest_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X51Y0:SLICE_X55Y839}
set __inst_full "top_multi_bench/u_510_parest_r"
set __inst_tail "u_510_parest_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_544_nab_r}]]} { create_pblock pblock_u_544_nab_r }
set pblk [get_pblocks -quiet {pblock_u_544_nab_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X55Y0:SLICE_X59Y839}
set __inst_full "top_multi_bench/u_544_nab_r"
set __inst_tail "u_544_nab_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_644_nab_s}]]} { create_pblock pblock_u_644_nab_s }
set pblk [get_pblocks -quiet {pblock_u_644_nab_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X59Y0:SLICE_X62Y839}
resize_pblock $pblk -add {SLICE_X62Y0:SLICE_X64Y839}
set __inst_full "top_multi_bench/u_644_nab_s"
set __inst_tail "u_644_nab_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_503_bwaves_r}]]} { create_pblock pblock_u_503_bwaves_r }
set pblk [get_pblocks -quiet {pblock_u_503_bwaves_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X64Y0:SLICE_X68Y839}
set __inst_full "top_multi_bench/u_503_bwaves_r"
set __inst_tail "u_503_bwaves_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_557_xz_r}]]} { create_pblock pblock_u_557_xz_r }
set pblk [get_pblocks -quiet {pblock_u_557_xz_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X68Y0:SLICE_X72Y839}
set __inst_full "top_multi_bench/u_557_xz_r"
set __inst_tail "u_557_xz_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_603_bwaves_s}]]} { create_pblock pblock_u_603_bwaves_s }
set pblk [get_pblocks -quiet {pblock_u_603_bwaves_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X72Y0:SLICE_X76Y839}
set __inst_full "top_multi_bench/u_603_bwaves_s"
set __inst_tail "u_603_bwaves_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_657_xz_s}]]} { create_pblock pblock_u_657_xz_s }
set pblk [get_pblocks -quiet {pblock_u_657_xz_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X76Y0:SLICE_X78Y839}
resize_pblock $pblk -add {SLICE_X78Y0:SLICE_X81Y839}
set __inst_full "top_multi_bench/u_657_xz_s"
set __inst_tail "u_657_xz_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_502_gcc_r}]]} { create_pblock pblock_u_502_gcc_r }
set pblk [get_pblocks -quiet {pblock_u_502_gcc_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X81Y0:SLICE_X85Y839}
set __inst_full "top_multi_bench/u_502_gcc_r"
set __inst_tail "u_502_gcc_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_549_fotonik3d_r}]]} { create_pblock pblock_u_549_fotonik3d_r }
set pblk [get_pblocks -quiet {pblock_u_549_fotonik3d_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X85Y0:SLICE_X89Y839}
set __inst_full "top_multi_bench/u_549_fotonik3d_r"
set __inst_tail "u_549_fotonik3d_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_649_fotonik3d_s}]]} { create_pblock pblock_u_649_fotonik3d_s }
set pblk [get_pblocks -quiet {pblock_u_649_fotonik3d_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X90Y0:SLICE_X94Y839}
set __inst_full "top_multi_bench/u_649_fotonik3d_s"
set __inst_tail "u_649_fotonik3d_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_602_gcc_s}]]} { create_pblock pblock_u_602_gcc_s }
set pblk [get_pblocks -quiet {pblock_u_602_gcc_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X94Y0:SLICE_X98Y839}
set __inst_full "top_multi_bench/u_602_gcc_s"
set __inst_tail "u_602_gcc_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_600_perlbench_s}]]} { create_pblock pblock_u_600_perlbench_s }
set pblk [get_pblocks -quiet {pblock_u_600_perlbench_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X98Y0:SLICE_X102Y839}
set __inst_full "top_multi_bench/u_600_perlbench_s"
set __inst_tail "u_600_perlbench_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_500_perlbench_r}]]} { create_pblock pblock_u_500_perlbench_r }
set pblk [get_pblocks -quiet {pblock_u_500_perlbench_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X102Y0:SLICE_X104Y839}
resize_pblock $pblk -add {SLICE_X104Y0:SLICE_X107Y839}
set __inst_full "top_multi_bench/u_500_perlbench_r"
set __inst_tail "u_500_perlbench_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_620_omnetpp_s}]]} { create_pblock pblock_u_620_omnetpp_s }
set pblk [get_pblocks -quiet {pblock_u_620_omnetpp_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X107Y0:SLICE_X111Y839}
set __inst_full "top_multi_bench/u_620_omnetpp_s"
set __inst_tail "u_620_omnetpp_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_520_omnetpp_r}]]} { create_pblock pblock_u_520_omnetpp_r }
set pblk [get_pblocks -quiet {pblock_u_520_omnetpp_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X111Y0:SLICE_X115Y839}
set __inst_full "top_multi_bench/u_520_omnetpp_r"
set __inst_tail "u_520_omnetpp_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_523_xalancbmk_r}]]} { create_pblock pblock_u_523_xalancbmk_r }
set pblk [get_pblocks -quiet {pblock_u_523_xalancbmk_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X115Y0:SLICE_X119Y839}
set __inst_full "top_multi_bench/u_523_xalancbmk_r"
set __inst_tail "u_523_xalancbmk_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_623_xalancbmk_s}]]} { create_pblock pblock_u_623_xalancbmk_s }
set pblk [get_pblocks -quiet {pblock_u_623_xalancbmk_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X119Y0:SLICE_X123Y839}
set __inst_full "top_multi_bench/u_623_xalancbmk_s"
set __inst_tail "u_623_xalancbmk_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_526_blender_r}]]} { create_pblock pblock_u_526_blender_r }
set pblk [get_pblocks -quiet {pblock_u_526_blender_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X123Y0:SLICE_X127Y839}
set __inst_full "top_multi_bench/u_526_blender_r"
set __inst_tail "u_526_blender_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_511_povray_r}]]} { create_pblock pblock_u_511_povray_r }
set pblk [get_pblocks -quiet {pblock_u_511_povray_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X127Y0:SLICE_X131Y839}
set __inst_full "top_multi_bench/u_511_povray_r"
set __inst_tail "u_511_povray_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_619_lbm_s}]]} { create_pblock pblock_u_619_lbm_s }
set pblk [get_pblocks -quiet {pblock_u_619_lbm_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X131Y0:SLICE_X135Y839}
set __inst_full "top_multi_bench/u_619_lbm_s"
set __inst_tail "u_619_lbm_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_521_wrf_r}]]} { create_pblock pblock_u_521_wrf_r }
set pblk [get_pblocks -quiet {pblock_u_521_wrf_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X135Y0:SLICE_X139Y839}
set __inst_full "top_multi_bench/u_521_wrf_r"
set __inst_tail "u_521_wrf_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_627_cam4_s}]]} { create_pblock pblock_u_627_cam4_s }
set pblk [get_pblocks -quiet {pblock_u_627_cam4_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X139Y0:SLICE_X143Y839}
set __inst_full "top_multi_bench/u_627_cam4_s"
set __inst_tail "u_627_cam4_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_507_cactuBSSN_r}]]} { create_pblock pblock_u_507_cactuBSSN_r }
set pblk [get_pblocks -quiet {pblock_u_507_cactuBSSN_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X143Y0:SLICE_X147Y839}
set __inst_full "top_multi_bench/u_507_cactuBSSN_r"
set __inst_tail "u_507_cactuBSSN_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_621_wrf_s}]]} { create_pblock pblock_u_621_wrf_s }
set pblk [get_pblocks -quiet {pblock_u_621_wrf_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X147Y0:SLICE_X150Y839}
resize_pblock $pblk -add {SLICE_X150Y0:SLICE_X152Y839}
set __inst_full "top_multi_bench/u_621_wrf_s"
set __inst_tail "u_621_wrf_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_527_cam4_r}]]} { create_pblock pblock_u_527_cam4_r }
set pblk [get_pblocks -quiet {pblock_u_527_cam4_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X152Y0:SLICE_X156Y839}
set __inst_full "top_multi_bench/u_527_cam4_r"
set __inst_tail "u_527_cam4_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_508_namd_r}]]} { create_pblock pblock_u_508_namd_r }
set pblk [get_pblocks -quiet {pblock_u_508_namd_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X156Y0:SLICE_X160Y839}
set __inst_full "top_multi_bench/u_508_namd_r"
set __inst_tail "u_508_namd_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_607_cactuBSSN_s}]]} { create_pblock pblock_u_607_cactuBSSN_s }
set pblk [get_pblocks -quiet {pblock_u_607_cactuBSSN_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X161Y0:SLICE_X165Y839}
set __inst_full "top_multi_bench/u_607_cactuBSSN_s"
set __inst_tail "u_607_cactuBSSN_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_554_roms_r}]]} { create_pblock pblock_u_554_roms_r }
set pblk [get_pblocks -quiet {pblock_u_554_roms_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
resize_pblock $pblk -add {SLICE_X165Y0:SLICE_X168Y839}
set __inst_full "top_multi_bench/u_554_roms_r"
set __inst_tail "u_554_roms_r"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }

if {![llength [get_pblocks -quiet {pblock_u_654_roms_s}]]} { create_pblock pblock_u_654_roms_s }
set pblk [get_pblocks -quiet {pblock_u_654_roms_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true $pblk
set_property CONTAIN_ROUTING false $pblk
set_property SNAPPING_MODE ROUTING $pblk
set __inst_full "top_multi_bench/u_654_roms_s"
set __inst_tail "u_654_roms_s"
set hc [get_cells -quiet $__inst_full]
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $__inst_tail]] }
if {![llength $hc]} { set hc [get_cells -quiet -hier -regexp [format {.*%s.*} $__inst_tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: no cells for $__inst_full"; set ::APB_FAIL 1 }
