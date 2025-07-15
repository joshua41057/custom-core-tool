##################################################################
# CHECK VIVADO VERSION
##################################################################

#set scripts_vivado_version 2024.1
set current_vivado_version [version -short]

#if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
#  catch {common::send_msg_id "IPS_TCL-100" "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in #<$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado #<$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_ip_tcl to create an #updated script."}
#  return 1
#}

##################################################################
# START
##################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source core_ip.tcl
# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
  # create_project custom_core custom_core -part xcu200-fsgd2104-2-e
  set_property target_language Verilog [current_project]
  set_property simulator_language Mixed [current_project]
}

##################################################################
# CHECK IPs
##################################################################

set bCheckIPs 1
set bCheckIPsPassed 1
if { $bCheckIPs == 1 } {
  set list_check_ips { xilinx.com:ip:floating_point:7.1 xilinx.com:ip:c_addsub:12.0 xilinx.com:ip:div_gen:5.1 xilinx.com:ip:mult_gen:12.0 }
  set list_ips_missing ""
  common::send_msg_id "IPS_TCL-1001" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

  foreach ip_vlnv $list_check_ips {
  set ip_obj [get_ipdefs -all $ip_vlnv]
  if { $ip_obj eq "" } {
    lappend list_ips_missing $ip_vlnv
    }
  }

  if { $list_ips_missing ne "" } {
    catch {common::send_msg_id "IPS_TCL-105" "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
    set bCheckIPsPassed 0
  }
}

if { $bCheckIPsPassed != 1 } {
  common::send_msg_id "IPS_TCL-102" "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 1
}

##################################################################
# CREATE IP floating_point_0
##################################################################

set floating_point_0 [create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_0]

# User Parameters
set_property -dict [list \
  CONFIG.A_Precision_Type {Double} \
  CONFIG.C_A_Exponent_Width {11} \
  CONFIG.C_A_Fraction_Width {53} \
  CONFIG.C_Accum_Input_Msb {32} \
  CONFIG.C_Accum_Lsb {-31} \
  CONFIG.C_Accum_Msb {32} \
  CONFIG.C_Latency {13} \
  CONFIG.C_Mult_Usage {Medium_Usage} \
  CONFIG.C_Rate {1} \
  CONFIG.C_Result_Exponent_Width {11} \
  CONFIG.C_Result_Fraction_Width {53} \
  CONFIG.Operation_Type {Multiply} \
  CONFIG.Result_Precision_Type {Double} \
] [get_ips floating_point_0]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $floating_point_0

##################################################################

##################################################################
# CREATE IP floating_point_addsub
##################################################################

set floating_point_addsub [create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_addsub]

# User Parameters
set_property -dict [list \
  CONFIG.A_Precision_Type {Double} \
  CONFIG.C_A_Exponent_Width {11} \
  CONFIG.C_A_Fraction_Width {53} \
  CONFIG.C_Accum_Input_Msb {32} \
  CONFIG.C_Accum_Lsb {-31} \
  CONFIG.C_Accum_Msb {32} \
  CONFIG.C_Latency {15} \
  CONFIG.C_Mult_Usage {Full_Usage} \
  CONFIG.C_Rate {1} \
  CONFIG.C_Result_Exponent_Width {11} \
  CONFIG.C_Result_Fraction_Width {53} \
  CONFIG.Has_A_TLAST {true} \
  CONFIG.Operation_Type {Add_Subtract} \
  CONFIG.RESULT_TLAST_Behv {Pass_A_TLAST} \
  CONFIG.Result_Precision_Type {Double} \
] [get_ips floating_point_addsub]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $floating_point_addsub

##################################################################

##################################################################
# CREATE IP floating_point_compare
##################################################################

set floating_point_compare [create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_compare]

# User Parameters
set_property -dict [list \
  CONFIG.A_Precision_Type {Double} \
  CONFIG.C_A_Exponent_Width {11} \
  CONFIG.C_A_Fraction_Width {53} \
  CONFIG.C_Accum_Input_Msb {32} \
  CONFIG.C_Accum_Lsb {-31} \
  CONFIG.C_Accum_Msb {32} \
  CONFIG.C_Compare_Operation {Condition_Code} \
  CONFIG.C_Latency {3} \
  CONFIG.C_Mult_Usage {No_Usage} \
  CONFIG.C_Rate {1} \
  CONFIG.C_Result_Exponent_Width {4} \
  CONFIG.C_Result_Fraction_Width {0} \
  CONFIG.Operation_Type {Compare} \
  CONFIG.Result_Precision_Type {Custom} \
] [get_ips floating_point_compare]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $floating_point_compare

##################################################################

##################################################################
# CREATE IP floating_point_convert
##################################################################

set floating_point_convert [create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_convert]

# User Parameters
set_property -dict [list \
  CONFIG.A_Precision_Type {Int32} \
  CONFIG.C_A_Exponent_Width {32} \
  CONFIG.C_A_Fraction_Width {0} \
  CONFIG.C_Accum_Input_Msb {32} \
  CONFIG.C_Accum_Lsb {-31} \
  CONFIG.C_Accum_Msb {32} \
  CONFIG.C_Latency {7} \
  CONFIG.C_Mult_Usage {No_Usage} \
  CONFIG.C_Rate {1} \
  CONFIG.C_Result_Exponent_Width {11} \
  CONFIG.C_Result_Fraction_Width {53} \
  CONFIG.Operation_Type {Fixed_to_float} \
  CONFIG.Result_Precision_Type {Double} \
] [get_ips floating_point_convert]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $floating_point_convert

##################################################################

##################################################################
# CREATE IP floating_point_div
##################################################################

set floating_point_div [create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_div]

# User Parameters
set_property -dict [list \
  CONFIG.A_Precision_Type {Double} \
  CONFIG.C_A_Exponent_Width {11} \
  CONFIG.C_A_Fraction_Width {53} \
  CONFIG.C_Accum_Input_Msb {32} \
  CONFIG.C_Accum_Lsb {-31} \
  CONFIG.C_Accum_Msb {32} \
  CONFIG.C_Latency {58} \
  CONFIG.C_Mult_Usage {No_Usage} \
  CONFIG.C_Rate {1} \
  CONFIG.C_Result_Exponent_Width {11} \
  CONFIG.C_Result_Fraction_Width {53} \
  CONFIG.Operation_Type {Divide} \
  CONFIG.Result_Precision_Type {Double} \
] [get_ips floating_point_div]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $floating_point_div

##################################################################

##################################################################
# CREATE IP floating_point_fma
##################################################################

set floating_point_fma [create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_fma]

# User Parameters
set_property -dict [list \
  CONFIG.A_Precision_Type {Double} \
  CONFIG.C_A_Exponent_Width {11} \
  CONFIG.C_A_Fraction_Width {53} \
  CONFIG.C_Accum_Input_Msb {32} \
  CONFIG.C_Accum_Lsb {-31} \
  CONFIG.C_Accum_Msb {32} \
  CONFIG.C_Latency {27} \
  CONFIG.C_Mult_Usage {Medium_Usage} \
  CONFIG.C_Rate {1} \
  CONFIG.C_Result_Exponent_Width {11} \
  CONFIG.C_Result_Fraction_Width {53} \
  CONFIG.Operation_Type {FMA} \
  CONFIG.Result_Precision_Type {Double} \
] [get_ips floating_point_fma]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $floating_point_fma

##################################################################

##################################################################
# CREATE IP floating_point_minmax
##################################################################

set floating_point_minmax [create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_minmax]

# User Parameters
set_property -dict [list \
  CONFIG.A_Precision_Type {Double} \
  CONFIG.C_A_Exponent_Width {11} \
  CONFIG.C_A_Fraction_Width {53} \
  CONFIG.C_Accum_Input_Msb {32} \
  CONFIG.C_Accum_Lsb {-31} \
  CONFIG.C_Accum_Msb {32} \
  CONFIG.C_Latency {3} \
  CONFIG.C_Mult_Usage {No_Usage} \
  CONFIG.C_Rate {1} \
  CONFIG.C_Result_Exponent_Width {11} \
  CONFIG.C_Result_Fraction_Width {53} \
  CONFIG.Operation_Type {Float_to_float} \
  CONFIG.Result_Precision_Type {Double} \
] [get_ips floating_point_minmax]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $floating_point_minmax

##################################################################

##################################################################
# CREATE IP floating_point_mul
##################################################################

set floating_point_mul [create_ip -name floating_point -vendor xilinx.com -library ip -version 7.1 -module_name floating_point_mul]

# User Parameters
set_property -dict [list \
  CONFIG.A_Precision_Type {Double} \
  CONFIG.C_A_Exponent_Width {11} \
  CONFIG.C_A_Fraction_Width {53} \
  CONFIG.C_Accum_Input_Msb {32} \
  CONFIG.C_Accum_Lsb {-31} \
  CONFIG.C_Accum_Msb {32} \
  CONFIG.C_Latency {13} \
  CONFIG.C_Mult_Usage {Medium_Usage} \
  CONFIG.C_Rate {1} \
  CONFIG.C_Result_Exponent_Width {11} \
  CONFIG.C_Result_Fraction_Width {53} \
  CONFIG.Operation_Type {Multiply} \
  CONFIG.Result_Precision_Type {Double} \
] [get_ips floating_point_mul]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $floating_point_mul

##################################################################

##################################################################
# CREATE IP integer_addsub
##################################################################

set integer_addsub [create_ip -name c_addsub -vendor xilinx.com -library ip -version 12.0 -module_name integer_addsub]

# User Parameters
set_property -dict [list \
  CONFIG.A_Width {64} \
  CONFIG.Add_Mode {Add_Subtract} \
  CONFIG.B_Value {0000000000000000000000000000000000000000000000000000000000000000} \
  CONFIG.B_Width {64} \
  CONFIG.C_In {true} \
  CONFIG.Implementation {Fabric} \
  CONFIG.Latency {1} \
  CONFIG.Out_Width {64} \
] [get_ips integer_addsub]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $integer_addsub

##################################################################

##################################################################
# CREATE IP integer_div
##################################################################

set integer_div [create_ip -name div_gen -vendor xilinx.com -library ip -version 5.1 -module_name integer_div]

# User Parameters
set_property -dict [list \
  CONFIG.algorithm_type {Radix2} \
  CONFIG.dividend_and_quotient_width {64} \
  CONFIG.divisor_width {64} \
  CONFIG.fractional_width {64} \
  CONFIG.latency {68} \
  CONFIG.remainder_type {Remainder} \
] [get_ips integer_div]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $integer_div

##################################################################

##################################################################
# CREATE IP integer_mul
##################################################################

set integer_mul [create_ip -name mult_gen -vendor xilinx.com -library ip -version 12.0 -module_name integer_mul]

# User Parameters
set_property -dict [list \
  CONFIG.ClockEnable {true} \
  CONFIG.Multiplier_Construction {Use_Mults} \
  CONFIG.OptGoal {Speed} \
  CONFIG.PipeStages {18} \
  CONFIG.PortAWidth {64} \
  CONFIG.PortBWidth {64} \
] [get_ips integer_mul]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {0}
} $integer_mul

##################################################################

