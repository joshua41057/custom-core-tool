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
synth_design -top $TOP_MODULE
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

foreach s {speeds.tcl usage.tcl} {
    set f [file join constraints $s]
    if {[file exists $f]} {
        puts "Info: source $f"
        source $f
    }
}

exit
