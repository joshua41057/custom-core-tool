package len_table_pkg;
  import uop_pkg::*;
  localparam int N_CASE = 1;
  localparam int MAX_LEN = 2;
  localparam int LEN_LUT [N_CASE] = '{
    2
  };
  localparam int STAGE_LUT [N_CASE] = '{
    1
  };
  /* FF boundaries bitmask per block */
  localparam logic [MAX_LEN-1:0] FF_MASK_LUT [N_CASE] = '{
    {2'h0}
  };
  localparam op_t OPS_LUT [N_CASE][MAX_LEN] = '{
    '{ OP_VMOVD, OP_VPBROADCASTB }
  };
  localparam logic [1:0] MEM_KIND_LUT [N_CASE][MAX_LEN] = '{
    '{ 2'd0, 2'd0 }
  };
  /* Element width per uop (8/16/32/64) */
  localparam int ELEM_W_LUT [N_CASE][MAX_LEN] = '{
    '{ 32, 8 }
  };
  /* Data width per uop: scalar 8~64, vector 128/256/512 */
  localparam int BW_LUT [N_CASE][MAX_LEN] = '{
    '{ 32, 256 }
  };
  localparam int BW_MAX_LUT [N_CASE] = '{
    256
  };
  /* Vector container width (XMM=128/YMM=256/ZMM=512), scalar=0 or 128 for ss/sd */
  localparam int CONT_W_LUT [N_CASE][MAX_LEN] = '{
    '{ 128, 256 }
  };
  /* Address path width: 64 when memory operand exists, else 0 */
  localparam int ADDR_W_LUT [N_CASE][MAX_LEN] = '{
    '{ 0, 0 }
  };
  localparam logic [31:0] IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 32'h00000000, 32'h00000000 }
  };
  localparam logic USE_IMM_LUT [N_CASE][MAX_LEN] = '{
    '{ 1'b0, 1'b0 }
  };
endpackage
