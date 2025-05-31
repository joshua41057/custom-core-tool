package len_table_pkg;
  import uop_pkg::*;
  localparam int N_CASE = 6;
  localparam int LEN_LUT [N_CASE] = '{
    4,
    6,
    6,
    6,
    5,
    6
  };
  localparam int STAGE_LUT [N_CASE] = '{
    3,
    4,
    5,
    5,
    2,
    4
  };
  localparam logic [31:0] FF_MASK_LUT [N_CASE] = '{
    32'h00000005,
    32'h00000015,
    32'h0000001d,
    32'h00000017,
    32'h00000004,
    32'h0000001c
  };
  localparam int MAX_LEN = 6;
  localparam op_t OPS_LUT [N_CASE][MAX_LEN] = '{
    '{ OP_SHLD, OP_TEST, OP_RCL, OP_RCR, OP_NOP, OP_NOP },
    '{ OP_SAL, OP_SAR, OP_OR, OP_RCR, OP_SBB, OP_RCR },
    '{ OP_IMUL, OP_SHRD, OP_CMP, OP_RCL, OP_IDIV, OP_CMP },
    '{ OP_RCL, OP_DIV, OP_SAL, OP_TEST, OP_SHRD, OP_SAR },
    '{ OP_OR, OP_AND, OP_SHR, OP_DEC, OP_IMUL, OP_NOP },
    '{ OP_TEST, OP_ADD, OP_NOT, OP_DIV, OP_SHRD, OP_SHLD }
  };
  localparam logic [31:0] IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 32'h00000000, 32'h00000005, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000004, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h0000000c, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 }
  };
  localparam logic USE_IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 }
  };
endpackage
