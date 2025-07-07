package len_table_pkg;
  import uop_pkg::*;
  localparam int N_CASE = 8;
  localparam int MAX_LEN = 7;
  localparam int LEN_LUT [N_CASE] = '{
    7,
    7,
    6,
    7,
    7,
    7,
    7,
    7
  };
  localparam int STAGE_LUT [N_CASE] = '{
    4,
    4,
    4,
    4,
    4,
    4,
    4,
    4
  };

  /* variable-width FF mask */
  localparam logic [MAX_LEN-1:0] FF_MASK_LUT [N_CASE] = '{
    {7'h07},
    {7'h07},
    {6'h07},
    {7'h07},
    {7'h07},
    {7'h07},
    {7'h07},
    {7'h07}
  };
  localparam op_t OPS_LUT [N_CASE][MAX_LEN] = '{
    '{ OP_FSUB, OP_FSUB, OP_FSUB, OP_FMUL, OP_FMA, OP_FMA, OP_FCMP },
    '{ OP_FSUB, OP_FSUB, OP_FSUB, OP_FMUL, OP_FMA, OP_FMA, OP_FCMP },
    '{ OP_FSUB, OP_FSUB, OP_FSUB, OP_FMUL, OP_FMA, OP_FMA, OP_NOP },
    '{ OP_FSUB, OP_FSUB, OP_FSUB, OP_FMUL, OP_FMA, OP_FMA, OP_FCMP },
    '{ OP_FSUB, OP_FSUB, OP_FSUB, OP_FMUL, OP_FMA, OP_FMA, OP_FCMP },
    '{ OP_FSUB, OP_FSUB, OP_FSUB, OP_FMUL, OP_FMA, OP_FMA, OP_FCMP },
    '{ OP_FSUB, OP_FSUB, OP_FSUB, OP_FMUL, OP_FMA, OP_FMA, OP_FCMP },
    '{ OP_FSUB, OP_FSUB, OP_FSUB, OP_FMUL, OP_FMA, OP_FMA, OP_FCMP }
  };
  localparam logic [31:0] IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 },
    '{ 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000 }
  };
  localparam logic USE_IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 },
    '{ 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0 }
  };
endpackage
