package len_table_pkg;
  import uop_pkg::*;
  localparam int N_CASE = 6;
  localparam int MAX_LEN = 6;
  localparam int LEN_LUT [N_CASE] = '{
    2,
    2,
    2,
    2,
    6,
    3
  };
  localparam int STAGE_LUT [N_CASE] = '{
    1,
    1,
    1,
    1,
    4,
    1
  };
  /* variable-width FF mask */
  localparam logic [MAX_LEN-1:0] FF_MASK_LUT [N_CASE] = '{
    {2'h0},
    {2'h0},
    {2'h0},
    {2'h0},
    {6'h07},
    {3'h0}
  };
  localparam op_t OPS_LUT [N_CASE][MAX_LEN] = '{
    '{ OP_IMUL, OP_ADD, OP_NOP, OP_NOP, OP_NOP, OP_NOP },
    '{ OP_AND, OP_AND, OP_NOP, OP_NOP, OP_NOP, OP_NOP },
    '{ OP_DEC, OP_SUB, OP_NOP, OP_NOP, OP_NOP, OP_NOP },
    '{ OP_INC, OP_SHL, OP_NOP, OP_NOP, OP_NOP, OP_NOP },
    '{ OP_IMUL, OP_IMUL, OP_IMUL, OP_ADD, OP_ADD, OP_ADD },
    '{ OP_ADD, OP_ADD, OP_ADD, OP_NOP, OP_NOP, OP_NOP }
  };
  localparam logic [31:0] IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 }
  };
  localparam logic USE_IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 }
  };
endpackage
