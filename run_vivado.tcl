# ================================================================
# run_vivado.tcl  –  Non-interactive Vivado flow

# Usage:
#   vivado -mode batch -source run_vivado.tcl | tee build.log

# Outputs:
#   reports/  : timing / utilization / power summaries
#   vivado_tmp/ : throw-away project folder (can be deleted)
# Tested with Vivado 2024.1; should work with 2022.2+

set PART        "xcu200-fsgd2104-2-e" 
set TOP_MODULE  "top_multi_len"
set PROJ_NAME   "custom_core_impl"
set RPT_DIR     "reports"


file mkdir $RPT_DIR
if {[file exists $PROJ_NAME]}    { file delete -force $PROJ_NAME }
if {[file exists vivado_tmp]}    { file delete -force vivado_tmp }

create_project -force $PROJ_NAME ./vivado_tmp -part $PART

# 0. SET IP
set IP_REPO_DIR  [file join [pwd] "ip_repo"]
file mkdir $IP_REPO_DIR
set_property ip_repo_paths $IP_REPO_DIR [current_project]

if {[llength [glob -nocomplain "$IP_REPO_DIR/*/*.xci"]] == 0} {
    puts "Info: No local XCI found – running core_ip.tcl to generate IPs"
    source [file join [pwd] "core_ip.tcl"]
}

update_ip_catalog
set ip_xci [glob -nocomplain "$IP_REPO_DIR/*/*.xci"]
add_files -fileset sources_1 -norecurse $ip_xci

upgrade_ip -quiet [get_ips]
set_property generate_synth_checkpoint true [get_ips]
generate_target all [get_ips]

update_compile_order -fileset sources_1

# 1. RTL sources
set RTL_DIR  [file join [pwd] rtl]
set rtl_files [glob -nocomplain "$RTL_DIR/*.sv"]
if {[llength $rtl_files] == 0} { puts "ERROR: no *.sv"; exit 1 }
read_verilog -sv $rtl_files
set_property file_type SystemVerilog [get_files *.sv]
update_compile_order -fileset sources_1

# 2. Constraints
if {[file exists constraints/clocks.xdc]} {
    read_xdc constraints/clocks.xdc
}

# 3. Synthesis 
synth_design -top $TOP_MODULE -part $PART -flatten_hierarchy none
update_timing  

# 4. design-time Tcl constraints
foreach s {pblock.tcl auto_pblock.tcl pipe_stages.tcl} {
    set f [file join constraints $s]
    if {[file exists $f]} {
        puts "Info: source $f"
        source $f
    }
}


# 5. Implementation (opt → place → phys_opt → route)
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force $RPT_DIR/post_route.dcp

# 6. Standard reports
report_utilization    -file $RPT_DIR/post_route_util.rpt
report_timing_summary -file $RPT_DIR/post_route_timing.rpt
report_power          -file $RPT_DIR/post_route_power.rpt

set pb_list [get_pblocks pblock_*]
foreach pb $pb_list {
    set rpt_name [format "$RPT_DIR/utilization_%s.rpt" $pb]
    report_utilization -quiet -pblocks $pb -file $rpt_name
}

foreach s {speeds.tcl usage.tcl} {
    set f [file join constraints $s]
    if {[file exists $f]} {
        puts "Info: source $f"
        source $f
    }
}

exit