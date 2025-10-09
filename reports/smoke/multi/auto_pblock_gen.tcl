if {[llength [get_pblocks -quiet {pblock_u_505_mcf_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_505_mcf_r}] }
create_pblock pblock_u_505_mcf_r
set pblk [get_pblocks -quiet {pblock_u_505_mcf_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X1Y0:SLICE_X2Y897}
resize_pblock $pblk -add {DSP48E2_X1Y0:DSP48E2_X2Y357}
resize_pblock $pblk -add {RAMB36_X1Y0:RAMB36_X2Y178}
resize_pblock $pblk -add {RAMB18_X1Y0:RAMB18_X2Y357}
resize_pblock $pblk -add {URAM288_X1Y0:URAM288_X2Y235}
set hc [get_cells -quiet top_multi_bench/u_505_mcf_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_505_mcf_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_505_mcf_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_605_mcf_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_605_mcf_s}] }
create_pblock pblock_u_605_mcf_s
set pblk [get_pblocks -quiet {pblock_u_605_mcf_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X4Y0:SLICE_X5Y897}
resize_pblock $pblk -add {DSP48E2_X4Y0:DSP48E2_X5Y357}
resize_pblock $pblk -add {RAMB36_X4Y0:RAMB36_X5Y178}
resize_pblock $pblk -add {RAMB18_X4Y0:RAMB18_X5Y357}
set hc [get_cells -quiet top_multi_bench/u_605_mcf_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_605_mcf_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_605_mcf_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_519_lbm_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_519_lbm_r}] }
create_pblock pblock_u_519_lbm_r
set pblk [get_pblocks -quiet {pblock_u_519_lbm_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X6Y0:SLICE_X7Y897}
resize_pblock $pblk -add {DSP48E2_X6Y0:DSP48E2_X7Y357}
resize_pblock $pblk -add {RAMB36_X6Y0:RAMB36_X7Y178}
resize_pblock $pblk -add {RAMB18_X6Y0:RAMB18_X7Y357}
set hc [get_cells -quiet top_multi_bench/u_519_lbm_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_519_lbm_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_519_lbm_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_548_exchange2_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_548_exchange2_r}] }
create_pblock pblock_u_548_exchange2_r
set pblk [get_pblocks -quiet {pblock_u_548_exchange2_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X11Y0:SLICE_X12Y897}
resize_pblock $pblk -add {DSP48E2_X11Y0:DSP48E2_X12Y357}
resize_pblock $pblk -add {RAMB36_X11Y0:RAMB36_X11Y178}
resize_pblock $pblk -add {RAMB18_X11Y0:RAMB18_X11Y357}
set hc [get_cells -quiet top_multi_bench/u_548_exchange2_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_548_exchange2_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_548_exchange2_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_531_deepsjeng_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_531_deepsjeng_r}] }
create_pblock pblock_u_531_deepsjeng_r
set pblk [get_pblocks -quiet {pblock_u_531_deepsjeng_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X13Y0:SLICE_X14Y897}
resize_pblock $pblk -add {DSP48E2_X13Y0:DSP48E2_X14Y357}
set hc [get_cells -quiet top_multi_bench/u_531_deepsjeng_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_531_deepsjeng_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_531_deepsjeng_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_538_imagick_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_538_imagick_r}] }
create_pblock pblock_u_538_imagick_r
set pblk [get_pblocks -quiet {pblock_u_538_imagick_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X16Y0:SLICE_X17Y897}
resize_pblock $pblk -add {DSP48E2_X16Y0:DSP48E2_X17Y357}
set hc [get_cells -quiet top_multi_bench/u_538_imagick_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_538_imagick_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_538_imagick_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_631_deepsjeng_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_631_deepsjeng_s}] }
create_pblock pblock_u_631_deepsjeng_s
set pblk [get_pblocks -quiet {pblock_u_631_deepsjeng_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X9Y0:SLICE_X10Y897}
resize_pblock $pblk -add {DSP48E2_X9Y0:DSP48E2_X10Y357}
resize_pblock $pblk -add {RAMB36_X9Y0:RAMB36_X10Y178}
resize_pblock $pblk -add {RAMB18_X9Y0:RAMB18_X10Y357}
resize_pblock $pblk -add {SLICE_X21Y0:SLICE_X22Y897}
set hc [get_cells -quiet top_multi_bench/u_631_deepsjeng_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_631_deepsjeng_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_631_deepsjeng_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_648_exchange2_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_648_exchange2_s}] }
create_pblock pblock_u_648_exchange2_s
set pblk [get_pblocks -quiet {pblock_u_648_exchange2_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X24Y0:SLICE_X25Y897}
set hc [get_cells -quiet top_multi_bench/u_648_exchange2_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_648_exchange2_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_648_exchange2_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_541_leela_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_541_leela_r}] }
create_pblock pblock_u_541_leela_r
set pblk [get_pblocks -quiet {pblock_u_541_leela_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X27Y0:SLICE_X28Y897}
set hc [get_cells -quiet top_multi_bench/u_541_leela_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_541_leela_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_541_leela_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_641_leela_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_641_leela_s}] }
create_pblock pblock_u_641_leela_s
set pblk [get_pblocks -quiet {pblock_u_641_leela_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X30Y0:SLICE_X31Y897}
set hc [get_cells -quiet top_multi_bench/u_641_leela_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_641_leela_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_641_leela_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_525_x264_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_525_x264_r}] }
create_pblock pblock_u_525_x264_r
set pblk [get_pblocks -quiet {pblock_u_525_x264_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X34Y0:SLICE_X35Y897}
set hc [get_cells -quiet top_multi_bench/u_525_x264_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_525_x264_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_525_x264_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_625_x264_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_625_x264_s}] }
create_pblock pblock_u_625_x264_s
set pblk [get_pblocks -quiet {pblock_u_625_x264_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X36Y0:SLICE_X37Y897}
set hc [get_cells -quiet top_multi_bench/u_625_x264_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_625_x264_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_625_x264_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_510_parest_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_510_parest_r}] }
create_pblock pblock_u_510_parest_r
set pblk [get_pblocks -quiet {pblock_u_510_parest_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X38Y0:SLICE_X39Y897}
set hc [get_cells -quiet top_multi_bench/u_510_parest_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_510_parest_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_510_parest_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_544_nab_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_544_nab_r}] }
create_pblock pblock_u_544_nab_r
set pblk [get_pblocks -quiet {pblock_u_544_nab_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X40Y0:SLICE_X41Y897}
set hc [get_cells -quiet top_multi_bench/u_544_nab_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_544_nab_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_544_nab_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_644_nab_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_644_nab_s}] }
create_pblock pblock_u_644_nab_s
set pblk [get_pblocks -quiet {pblock_u_644_nab_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X42Y0:SLICE_X43Y897}
set hc [get_cells -quiet top_multi_bench/u_644_nab_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_644_nab_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_644_nab_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_503_bwaves_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_503_bwaves_r}] }
create_pblock pblock_u_503_bwaves_r
set pblk [get_pblocks -quiet {pblock_u_503_bwaves_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X44Y0:SLICE_X45Y897}
set hc [get_cells -quiet top_multi_bench/u_503_bwaves_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_503_bwaves_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_503_bwaves_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_603_bwaves_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_603_bwaves_s}] }
create_pblock pblock_u_603_bwaves_s
set pblk [get_pblocks -quiet {pblock_u_603_bwaves_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X48Y0:SLICE_X49Y897}
set hc [get_cells -quiet top_multi_bench/u_603_bwaves_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_603_bwaves_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_603_bwaves_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_557_xz_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_557_xz_r}] }
create_pblock pblock_u_557_xz_r
set pblk [get_pblocks -quiet {pblock_u_557_xz_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X50Y0:SLICE_X51Y897}
set hc [get_cells -quiet top_multi_bench/u_557_xz_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_557_xz_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_557_xz_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_502_gcc_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_502_gcc_r}] }
create_pblock pblock_u_502_gcc_r
set pblk [get_pblocks -quiet {pblock_u_502_gcc_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X52Y0:SLICE_X53Y897}
set hc [get_cells -quiet top_multi_bench/u_502_gcc_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_502_gcc_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_502_gcc_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_549_fotonik3d_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_549_fotonik3d_r}] }
create_pblock pblock_u_549_fotonik3d_r
set pblk [get_pblocks -quiet {pblock_u_549_fotonik3d_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X54Y0:SLICE_X55Y897}
set hc [get_cells -quiet top_multi_bench/u_549_fotonik3d_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_549_fotonik3d_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_549_fotonik3d_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_657_xz_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_657_xz_s}] }
create_pblock pblock_u_657_xz_s
set pblk [get_pblocks -quiet {pblock_u_657_xz_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X56Y0:SLICE_X57Y897}
set hc [get_cells -quiet top_multi_bench/u_657_xz_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_657_xz_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_657_xz_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_649_fotonik3d_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_649_fotonik3d_s}] }
create_pblock pblock_u_649_fotonik3d_s
set pblk [get_pblocks -quiet {pblock_u_649_fotonik3d_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X58Y0:SLICE_X59Y897}
set hc [get_cells -quiet top_multi_bench/u_649_fotonik3d_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_649_fotonik3d_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_649_fotonik3d_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_602_gcc_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_602_gcc_s}] }
create_pblock pblock_u_602_gcc_s
set pblk [get_pblocks -quiet {pblock_u_602_gcc_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X60Y0:SLICE_X61Y897}
set hc [get_cells -quiet top_multi_bench/u_602_gcc_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_602_gcc_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_602_gcc_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_620_omnetpp_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_620_omnetpp_s}] }
create_pblock pblock_u_620_omnetpp_s
set pblk [get_pblocks -quiet {pblock_u_620_omnetpp_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X63Y0:SLICE_X64Y897}
set hc [get_cells -quiet top_multi_bench/u_620_omnetpp_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_620_omnetpp_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_620_omnetpp_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_520_omnetpp_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_520_omnetpp_r}] }
create_pblock pblock_u_520_omnetpp_r
set pblk [get_pblocks -quiet {pblock_u_520_omnetpp_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X65Y0:SLICE_X66Y897}
set hc [get_cells -quiet top_multi_bench/u_520_omnetpp_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_520_omnetpp_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_520_omnetpp_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_500_perlbench_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_500_perlbench_r}] }
create_pblock pblock_u_500_perlbench_r
set pblk [get_pblocks -quiet {pblock_u_500_perlbench_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X67Y0:SLICE_X68Y897}
set hc [get_cells -quiet top_multi_bench/u_500_perlbench_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_500_perlbench_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_500_perlbench_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_507_cactuBSSN_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_507_cactuBSSN_r}] }
create_pblock pblock_u_507_cactuBSSN_r
set pblk [get_pblocks -quiet {pblock_u_507_cactuBSSN_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X69Y0:SLICE_X70Y897}
set hc [get_cells -quiet top_multi_bench/u_507_cactuBSSN_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_507_cactuBSSN_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_507_cactuBSSN_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_508_namd_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_508_namd_r}] }
create_pblock pblock_u_508_namd_r
set pblk [get_pblocks -quiet {pblock_u_508_namd_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X71Y0:SLICE_X72Y897}
set hc [get_cells -quiet top_multi_bench/u_508_namd_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_508_namd_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_508_namd_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_511_povray_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_511_povray_r}] }
create_pblock pblock_u_511_povray_r
set pblk [get_pblocks -quiet {pblock_u_511_povray_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X73Y0:SLICE_X74Y897}
set hc [get_cells -quiet top_multi_bench/u_511_povray_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_511_povray_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_511_povray_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_521_wrf_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_521_wrf_r}] }
create_pblock pblock_u_521_wrf_r
set pblk [get_pblocks -quiet {pblock_u_521_wrf_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X75Y0:SLICE_X76Y897}
set hc [get_cells -quiet top_multi_bench/u_521_wrf_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_521_wrf_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_521_wrf_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_523_xalancbmk_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_523_xalancbmk_r}] }
create_pblock pblock_u_523_xalancbmk_r
set pblk [get_pblocks -quiet {pblock_u_523_xalancbmk_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X79Y0:SLICE_X80Y897}
set hc [get_cells -quiet top_multi_bench/u_523_xalancbmk_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_523_xalancbmk_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_523_xalancbmk_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_526_blender_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_526_blender_r}] }
create_pblock pblock_u_526_blender_r
set pblk [get_pblocks -quiet {pblock_u_526_blender_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X81Y0:SLICE_X82Y897}
set hc [get_cells -quiet top_multi_bench/u_526_blender_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_526_blender_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_526_blender_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_527_cam4_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_527_cam4_r}] }
create_pblock pblock_u_527_cam4_r
set pblk [get_pblocks -quiet {pblock_u_527_cam4_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X83Y0:SLICE_X84Y897}
set hc [get_cells -quiet top_multi_bench/u_527_cam4_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_527_cam4_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_527_cam4_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_554_roms_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_554_roms_r}] }
create_pblock pblock_u_554_roms_r
set pblk [get_pblocks -quiet {pblock_u_554_roms_r}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X85Y0:SLICE_X86Y897}
set hc [get_cells -quiet top_multi_bench/u_554_roms_r]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_554_roms_r" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_554_roms_r"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_600_perlbench_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_600_perlbench_s}] }
create_pblock pblock_u_600_perlbench_s
set pblk [get_pblocks -quiet {pblock_u_600_perlbench_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X87Y0:SLICE_X88Y897}
set hc [get_cells -quiet top_multi_bench/u_600_perlbench_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_600_perlbench_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_600_perlbench_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_607_cactuBSSN_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_607_cactuBSSN_s}] }
create_pblock pblock_u_607_cactuBSSN_s
set pblk [get_pblocks -quiet {pblock_u_607_cactuBSSN_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X91Y0:SLICE_X92Y897}
set hc [get_cells -quiet top_multi_bench/u_607_cactuBSSN_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_607_cactuBSSN_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_607_cactuBSSN_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_619_lbm_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_619_lbm_s}] }
create_pblock pblock_u_619_lbm_s
set pblk [get_pblocks -quiet {pblock_u_619_lbm_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X93Y0:SLICE_X94Y897}
set hc [get_cells -quiet top_multi_bench/u_619_lbm_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_619_lbm_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_619_lbm_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_621_wrf_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_621_wrf_s}] }
create_pblock pblock_u_621_wrf_s
set pblk [get_pblocks -quiet {pblock_u_621_wrf_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X95Y0:SLICE_X96Y897}
set hc [get_cells -quiet top_multi_bench/u_621_wrf_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_621_wrf_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_621_wrf_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_623_xalancbmk_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_623_xalancbmk_s}] }
create_pblock pblock_u_623_xalancbmk_s
set pblk [get_pblocks -quiet {pblock_u_623_xalancbmk_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X97Y0:SLICE_X98Y897}
set hc [get_cells -quiet top_multi_bench/u_623_xalancbmk_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_623_xalancbmk_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_623_xalancbmk_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_627_cam4_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_627_cam4_s}] }
create_pblock pblock_u_627_cam4_s
set pblk [get_pblocks -quiet {pblock_u_627_cam4_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X99Y0:SLICE_X100Y897}
set hc [get_cells -quiet top_multi_bench/u_627_cam4_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_627_cam4_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_627_cam4_s"; exit 1 }

if {[llength [get_pblocks -quiet {pblock_u_654_roms_s}]]} { delete_pblocks [get_pblocks -quiet {pblock_u_654_roms_s}] }
create_pblock pblock_u_654_roms_s
set pblk [get_pblocks -quiet {pblock_u_654_roms_s}]
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT true  $pblk
set_property CONTAIN_ROUTING   false $pblk
set_property SNAPPING_MODE     ROUTING $pblk
resize_pblock $pblk -add {SLICE_X101Y0:SLICE_X102Y897}
set hc [get_cells -quiet top_multi_bench/u_654_roms_s]
if {![llength $hc]} { set tail [lindex [split "top_multi_bench/u_654_roms_s" "/"] end]; set hc [get_cells -quiet -hier -regexp [format {(^|.*/)%s(/|$)} $tail]] }
if {[llength $hc]} { add_cells_to_pblock $pblk $hc -clear_locs }
if {![llength [get_cells -quiet -of_objects $pblk]]} { puts "ERROR: empty pblock u_654_roms_s"; exit 1 }
