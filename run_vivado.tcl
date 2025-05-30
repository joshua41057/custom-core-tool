# ================================================================
# run_vivado.tcl  –  Non-interactive Vivado flow

# Usage:
#   vivado -mode batch -source run_vivado.tcl | tee build.log

# Outputs:
#   reports/  : timing / utilization / power summaries
#   vivado_tmp/ : throw-away project folder (can be deleted)
# Tested with Vivado 2024.1; should work with 2022.2+

# -------- user-editable parameters ------------------------------
set PART        "xcu200-fsgd2104-2-e" ;# FPGA device (Alveo U200)
set TOP_MODULE  "top_multi_len"       ;# Verilog top
set PROJ_NAME   "custom_core_impl"
set RPT_DIR     "reports"
# ----------------------------------------------------------------

file mkdir $RPT_DIR
if {[file exists $PROJ_NAME]} { file delete -force $PROJ_NAME }

create_project $PROJ_NAME ./vivado_tmp -part $PART

# ---- 1. RTL sources -------------------------------------------
set RTL_DIR [file join [pwd] rtl]
read_verilog [glob -nocomplain "$RTL_DIR/*.sv"]
set_property file_type SystemVerilog [get_files *.sv]

# ---- 2. Constraints -------------------------------------------
read_xdc constraints/clocks.xdc

# Optional TCL snippets (generated or hand-written)
foreach tcl_file {auto_pblock.tcl pipe_stages.tcl pblock.tcl} {
    if {[file exists constraints/$tcl_file]} {
        puts "Info: sourcing constraints/$tcl_file"
        source constraints/$tcl_file
    }
}

# ---- 3. Synthesis ---------------------------------------------
synth_design -top $TOP_MODULE
write_checkpoint -force $RPT_DIR/post_synth.dcp
report_utilization    -file $RPT_DIR/post_synth_util.rpt
report_timing_summary -file $RPT_DIR/post_synth_timing.rpt

# ---- 4. Implementation (opt → place → phys_opt → route) -------
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force $RPT_DIR/post_route.dcp

# ---- 5. Reports -----------------------------------------------
report_utilization    -file $RPT_DIR/post_route_util.rpt
report_timing_summary -file $RPT_DIR/post_route_timing.rpt
report_power          -file $RPT_DIR/post_route_power.rpt
exit
