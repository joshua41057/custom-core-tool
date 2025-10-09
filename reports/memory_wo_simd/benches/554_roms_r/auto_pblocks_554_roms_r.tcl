# pblock for 554.roms_r  CR: X0Y0 .. X0Y0  (sumSLICE=1740, sumSLICEM~870)
if {[llength [get_pblocks -quiet {pblock_554_roms_r}]]} { delete_pblocks [get_pblocks -quiet {pblock_554_roms_r}] }
create_pblock pblock_554_roms_r
set pblk [get_pblocks -quiet {pblock_554_roms_r}]
set_property SNAPPING_MODE ON $pblk
set_property IS_SOFT false $pblk
set_property EXCLUDE_PLACEMENT false $pblk
set_property CONTAIN_ROUTING   false $pblk
set _cr_list {X0Y0}
set _cr [get_clock_regions -quiet $_cr_list]
if {![llength $_cr]} { puts "ERROR: No matching CLOCK_REGION objects for requested CR box."; exit 1 }
set _sites [get_sites -quiet -of_objects $_cr   -filter { SITE_TYPE =~ SLIC* || SITE_TYPE =~ DSP* || NAME =~ RAMB18_* || NAME =~ RAMB36_* || SITE_TYPE =~ URAM* }]
resize_pblock $pblk -add $_sites
set inst_path {554.roms_r}
set tgt {}
set pats [list "$inst_path/*" "$inst_path"]
foreach pat $pats {
  set c [get_cells -quiet -hier * -filter "NAME =~ $pat"]
  if {[llength $c]} { set tgt $c; break }
}
if {![llength $tgt]} {
  set top [get_cells -quiet top_multi_len]
  if {[llength $top]} { set tgt $top }
}
set hc {}
if {[llength $tgt]} {
  set hc [get_cells -quiet -hier -of_objects $tgt -filter { IS_PRIMITIVE == 1 && PRIMITIVE_GROUP != "IO" && PRIMITIVE_GROUP != "CLOCK" }]
}
if {![llength $hc]} {
  puts "WARN: pattern $inst_path matched no cells. Falling back to whole design primitives."
  set hc [get_cells -quiet -hier * -filter { IS_PRIMITIVE == 1 && PRIMITIVE_GROUP != "IO" && PRIMITIVE_GROUP != "CLOCK" }]
}
puts "INFO: add [llength $hc] cells to $pblk"
if {[llength $hc] == 0} { puts "ERROR: No cells found to add into pblock"; exit 1 }
add_cells_to_pblock $pblk $hc -clear_locs
set NS  [llength [get_sites -quiet -of_objects $pblk -filter {SITE_TYPE =~ SLIC*}]]
set ND  [llength [get_sites -quiet -of_objects $pblk -filter {SITE_TYPE =~ DSP*}]]
set NB36 [llength [get_sites -quiet -of_objects $pblk -filter {NAME =~ RAMB36_*}]]
set NB18 [llength [get_sites -quiet -of_objects $pblk -filter {NAME =~ RAMB18_*}]]
set NU  [llength [get_sites -quiet -of_objects $pblk -filter {SITE_TYPE =~ URAM*}]]
puts "INFO: pblock coverage SLICE=$NS DSP=$ND RAMB36=$NB36 RAMB18=$NB18 URAM=$NU"
