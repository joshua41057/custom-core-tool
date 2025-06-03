`include "uop_pkg.sv"

module uop_block_wrap #(
    parameter int             LEN         = 1,
    parameter int             PIPE_STAGES = 1,
    parameter logic [31:0]    FF_MASK     = 32'h0,
    parameter bit             OUT_FF      = 1'b1,
    parameter uop_pkg::op_t   OPS   [LEN] ,
    parameter logic [31:0]    IMM   [LEN] = '{default:32'h0},   
    parameter logic           USE_IMM[LEN]= '{default:1'b0},    
    parameter int             W           = 64
)(
    input  logic                 clk,
    input  logic [W-1:0]         src_i,
    input  logic [$clog2(W)-1:0] shamt_i,
    output logic [W-1:0]         dst_o
);
    logic [W-1:0] src_q;
    logic [$clog2(W)-1:0] shamt_q;
    always_ff @(posedge clk) begin
        src_q   <= src_i;
        shamt_q <= shamt_i;
    end

    logic [W-1:0] dst_int;
    uop_block #(
        .LEN        (LEN),
        .PIPE_STAGES(PIPE_STAGES),
        .FF_MASK    (FF_MASK),
        .OPS        (OPS),
        .IMM        (IMM),        
        .USE_IMM    (USE_IMM),    
        .W          (W)
    ) core (
        .clk   (clk),
        .src   (src_q),
        .shamt (shamt_q),
        .dst   (dst_int)
    );
    if (OUT_FF) begin : g_out_ff
        always_ff @(posedge clk) dst_o <= dst_int;
    end else begin
        assign dst_o = dst_int;
    end
endmodule
