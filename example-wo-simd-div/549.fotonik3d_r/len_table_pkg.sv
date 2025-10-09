package len_table_pkg;
  import uop_pkg::*;
  localparam int N_CASE = 13;
  localparam int MAX_LEN = 4;
  localparam int LEN_LUT [N_CASE] = '{
    2,
    3,
    2,
    3,
    2,
    4,
    3,
    2,
    3,
    2,
    4,
    3,
    2
  };
  localparam int STAGE_LUT [N_CASE] = '{
    2,
    1,
    1,
    2,
    1,
    2,
    2,
    1,
    2,
    1,
    2,
    2,
    2
  };
  /* FF boundaries bitmask per block */
  localparam logic [MAX_LEN-1:0] FF_MASK_LUT [N_CASE] = '{
    {2'h1},
    {3'h0},
    {2'h0},
    {3'h1},
    {2'h0},
    {4'h1},
    {3'h2},
    {2'h0},
    {3'h1},
    {2'h0},
    {4'h1},
    {3'h2},
    {2'h1}
  };
  localparam op_t OPS_LUT [N_CASE][MAX_LEN] = '{
    '{ OP_LEA, OP_MOVSXD, OP_NOP, OP_NOP },
    '{ OP_ADD, OP_MOVSXD, OP_ADD, OP_NOP },
    '{ OP_MOVSX, OP_MOV, OP_NOP, OP_NOP },
    '{ OP_LEA, OP_SHL, OP_ADD, OP_NOP },
    '{ OP_MOV, OP_SHL, OP_NOP, OP_NOP },
    '{ OP_LEA, OP_ADD, OP_SHL, OP_ADD },
    '{ OP_LEA, OP_SHL, OP_ADD, OP_NOP },
    '{ OP_XOR, OP_XOR, OP_NOP, OP_NOP },
    '{ OP_LEA, OP_SHL, OP_ADD, OP_NOP },
    '{ OP_MOV, OP_SHL, OP_NOP, OP_NOP },
    '{ OP_LEA, OP_ADD, OP_SHL, OP_ADD },
    '{ OP_LEA, OP_SHL, OP_ADD, OP_NOP },
    '{ OP_LEA, OP_ADD, OP_NOP, OP_NOP }
  };
  localparam logic [1:0] MEM_KIND_LUT [N_CASE][MAX_LEN] = '{
    '{ 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0 }
  };
  /* Element width per uop (8/16/32/64) */
  localparam int ELEM_W_LUT [N_CASE][MAX_LEN] = '{
    '{ 32, 32, 64, 64 },
    '{ 32, 32, 64, 64 },
    '{ 8, 32, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 32, 32, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 }
  };
  /* Data width per uop: scalar 8~64, vector 128/256/512 */
  localparam int BW_LUT [N_CASE][MAX_LEN] = '{
    '{ 32, 64, 64, 64 },
    '{ 32, 64, 64, 64 },
    '{ 32, 32, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 32, 32, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 },
    '{ 64, 64, 64, 64 }
  };
  localparam int BW_MAX_LUT [N_CASE] = '{
    64,
    64,
    32,
    64,
    64,
    64,
    64,
    32,
    64,
    64,
    64,
    64,
    64
  };
  /* Vector container width (XMM=128/YMM=256/ZMM=512), scalar=0 or 128 for ss/sd */
  localparam int CONT_W_LUT [N_CASE][MAX_LEN] = '{
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 }
  };
  /* Address path width: 64 when memory operand exists, else 0 */
  localparam int ADDR_W_LUT [N_CASE][MAX_LEN] = '{
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 },
    '{ 0, 0, 0, 0 }
  };
  localparam logic [31:0] IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000002, 32'h00000000, 32'h00000002, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000004, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000004, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000004, 32'h00000000 },
    '{ 32'h00000000, 32'h00000004, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000004, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000004, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000004, 32'h00000000 },
    '{ 32'h00000000, 32'h00000004, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 }
  };
  localparam logic USE_IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b1, 1'b0, 1'b1, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b1, 1'b0, 1'b0 },
    '{ 1'b0, 1'b1, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b1, 1'b0 },
    '{ 1'b0, 1'b1, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b1, 1'b0, 1'b0 },
    '{ 1'b0, 1'b1, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b1, 1'b0 },
    '{ 1'b0, 1'b1, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0 }
  };
endpackage
