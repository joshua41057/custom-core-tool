package len_table_pkg;
  import uop_pkg::*;
  localparam int N_CASE = 8;
  localparam int MAX_LEN = 4;
  localparam int LEN_LUT [N_CASE] = '{
    2,
    2,
    2,
    4,
    2,
    2,
    2,
    2
  };
  localparam int STAGE_LUT [N_CASE] = '{
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1
  };
  /* variable-width FF mask */
  localparam logic [MAX_LEN-1:0] FF_MASK_LUT [N_CASE] = '{
    {2'h0},
    {2'h0},
    {2'h0},
    {4'h0},
    {2'h0},
    {2'h0},
    {2'h0},
    {2'h0}
  };
  localparam op_t OPS_LUT [N_CASE][MAX_LEN] = '{
    '{ OP_MOV, OP_AND, OP_NOP, OP_NOP },
    '{ OP_NOT, OP_ADD, OP_NOP, OP_NOP },
    '{ OP_SUB, OP_SAR, OP_NOP, OP_NOP },
    '{ OP_MOV, OP_SUB, OP_SHR, OP_ADD },
    '{ OP_XOR, OP_MOV, OP_NOP, OP_NOP },
    '{ OP_XOR, OP_AND, OP_NOP, OP_NOP },
    '{ OP_SUB, OP_MOV, OP_NOP, OP_NOP },
    '{ OP_MOV, OP_MOV, OP_NOP, OP_NOP }
  };
  localparam logic [31:0] IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 }
  };
  localparam logic USE_IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0 }
  };
endpackage
