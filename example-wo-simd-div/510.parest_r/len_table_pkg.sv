package len_table_pkg;
  import uop_pkg::*;
  localparam int N_CASE = 11;
  localparam int MAX_LEN = 5;
  localparam int LEN_LUT [N_CASE] = '{
    3,
    2,
    3,
    4,
    2,
    2,
    2,
    2,
    5,
    3,
    4
  };
  localparam int STAGE_LUT [N_CASE] = '{
    1,
    1,
    2,
    2,
    1,
    1,
    1,
    1,
    3,
    1,
    2
  };
  /* FF boundaries bitmask per block */
  localparam logic [MAX_LEN-1:0] FF_MASK_LUT [N_CASE] = '{
    {3'h0},
    {2'h0},
    {3'h2},
    {4'h2},
    {2'h0},
    {2'h0},
    {2'h0},
    {2'h0},
    {5'h03},
    {3'h0},
    {4'h4}
  };
  localparam op_t OPS_LUT [N_CASE][MAX_LEN] = '{
    '{ OP_MOV, OP_SHR, OP_SUB, OP_NOP, OP_NOP },
    '{ OP_MOV, OP_AND, OP_NOP, OP_NOP, OP_NOP },
    '{ OP_IMUL, OP_ADD, OP_MOV, OP_NOP, OP_NOP },
    '{ OP_MOV, OP_IMUL, OP_ADD, OP_MOV, OP_NOP },
    '{ OP_DEC, OP_SUB, OP_NOP, OP_NOP, OP_NOP },
    '{ OP_MOV, OP_SAR, OP_NOP, OP_NOP, OP_NOP },
    '{ OP_SUB, OP_SAR, OP_NOP, OP_NOP, OP_NOP },
    '{ OP_MOV, OP_MOV, OP_NOP, OP_NOP, OP_NOP },
    '{ OP_LEA, OP_LEA, OP_MOV, OP_SUB, OP_SAR },
    '{ OP_MOV, OP_SHR, OP_MOV, OP_NOP, OP_NOP },
    '{ OP_MOV, OP_SUB, OP_ADD, OP_SHR, OP_NOP }
  };
  localparam logic [1:0] MEM_KIND_LUT [N_CASE][MAX_LEN] = '{
    '{ 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 },
    '{ 2'd0, 2'd0, 2'd0, 2'd0, 2'd0 }
  };
  /* Element width per uop (8/16/32/64) */
  localparam int ELEM_W_LUT [N_CASE][MAX_LEN] = '{
    '{ 32, 32, 32, 64, 64 },
    '{ 64, 64, 64, 64, 64 },
    '{ 32, 32, 32, 64, 64 },
    '{ 32, 32, 32, 32, 64 },
    '{ 32, 32, 64, 64, 64 },
    '{ 64, 64, 64, 64, 64 },
    '{ 64, 64, 64, 64, 64 },
    '{ 32, 32, 64, 64, 64 },
    '{ 64, 64, 64, 64, 64 },
    '{ 32, 32, 32, 64, 64 },
    '{ 64, 64, 64, 64, 64 }
  };
  /* Data width per uop: scalar 8~64, vector 128/256/512 */
  localparam int BW_LUT [N_CASE][MAX_LEN] = '{
    '{ 32, 32, 32, 64, 64 },
    '{ 64, 64, 64, 64, 64 },
    '{ 32, 32, 32, 64, 64 },
    '{ 32, 32, 32, 32, 64 },
    '{ 32, 32, 64, 64, 64 },
    '{ 64, 64, 64, 64, 64 },
    '{ 64, 64, 64, 64, 64 },
    '{ 32, 32, 64, 64, 64 },
    '{ 64, 64, 64, 64, 64 },
    '{ 32, 32, 32, 64, 64 },
    '{ 64, 64, 64, 64, 64 }
  };
  localparam int BW_MAX_LUT [N_CASE] = '{
    32,
    64,
    32,
    32,
    32,
    64,
    64,
    32,
    64,
    32,
    64
  };
  /* Vector container width (XMM=128/YMM=256/ZMM=512), scalar=0 or 128 for ss/sd */
  localparam int CONT_W_LUT [N_CASE][MAX_LEN] = '{
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 }
  };
  /* Address path width: 64 when memory operand exists, else 0 */
  localparam int ADDR_W_LUT [N_CASE][MAX_LEN] = '{
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 },
    '{ 0, 0, 0, 0, 0 }
  };
  localparam logic [31:0] IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 32'h00000000, 32'h00000004, 32'h00000002, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'hfffffff8, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000001, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000002, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000002 },
    '{ 32'h00000000, 32'h00000001, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000003, 32'h00000000 }
  };
  localparam logic USE_IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 1'b0, 1'b1, 1'b1, 1'b0, 1'b0 },
    '{ 1'b0, 1'b1, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b1, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b1, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b1 },
    '{ 1'b0, 1'b1, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b1, 1'b0 }
  };
endpackage
