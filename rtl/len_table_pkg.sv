package len_table_pkg;
  import uop_pkg::*;
  localparam int N_CASE = 1;
  localparam int LEN_LUT [N_CASE] = '{
    4
  };
  localparam int STAGE_LUT [N_CASE] = '{
    3
  };
  localparam logic [31:0] FF_MASK_LUT [N_CASE] = '{
    32'h00000005
  };
  localparam int MAX_LEN = 4;
  localparam op_t OPS_LUT [N_CASE][MAX_LEN] = '{
    '{ OP_SHLD, OP_TEST, OP_RCL, OP_RCR }
  };
  localparam logic [31:0] IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 32'h00000000, 32'h00000005, 32'h00000000, 32'h00000000 }
  };
  localparam logic USE_IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 1'b0, 1'b1, 1'b0, 1'b0 }
  };
endpackage
