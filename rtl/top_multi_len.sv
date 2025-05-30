`include "uop_pkg.sv"

module top_multi_len #(
    parameter int W = 64
)(
    input  logic                     clk,
    input  logic [W-1:0]             src_val,
    input  logic [$clog2(W)-1:0]     shamt,
    output logic [W-1:0]             result
);
    import len_table_pkg::*;

    logic [W-1:0] y [N_CASE];

    generate
      for (genvar i = 0; i < N_CASE; i++) begin : glen
          localparam int             THIS_LEN   = LEN_LUT[i];
          localparam int             THIS_STAGE = STAGE_LUT[i];
          localparam logic [31:0]    THIS_MASK  = FF_MASK_LUT[i];
    
          uop_block_wrap #(
              .LEN         (THIS_LEN),
              .PIPE_STAGES (THIS_STAGE),
              .FF_MASK     (THIS_MASK),
              .OPS         (OPS_LUT[i]),
              .IMM         (IMM_LUT[i]),
              .USE_IMM     (USE_IMM_LUT[i]),
              .W           (W)
          ) blk_i (		
            .clk (clk),		
            .src_i (src_val),		
            .shamt_i(shamt),		
            .dst_o (y[i])		
            );  
        end
    endgenerate

    logic [W-1:0] res_r;
    always_comb begin
        res_r = '0;
        for (int i = 0; i < N_CASE; i++) res_r ^= y[i];
    end
    assign result = res_r;
endmodule
