// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2020.1 (lin64) Build 2902540 Wed May 27 19:54:35 MDT 2020
// Date        : Mon Sep 22 02:42:36 2025
// Host        : orthanc running 64-bit Ubuntu 22.04.4 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/jyoo/custom_v_2/custom-core-tool/.srcs/sources_1/ip/integer_mul/integer_mul_stub.v
// Design      : integer_mul
// Purpose     : Stub declaration of top-level module interface
// Device      : xcu200-fsgd2104-2-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "mult_gen_v12_0_16,Vivado 2020.1" *)
module integer_mul(CLK, A, B, CE, P)
/* synthesis syn_black_box black_box_pad_pin="CLK,A[63:0],B[63:0],CE,P[127:0]" */;
  input CLK;
  input [63:0]A;
  input [63:0]B;
  input CE;
  output [127:0]P;
endmodule
