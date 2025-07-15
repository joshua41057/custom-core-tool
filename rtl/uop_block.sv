`include "uop_pkg.sv"

module uop_block #(
    parameter int             LEN          = 4,
    parameter int             PIPE_STAGES  = 1,
    parameter int             MAX_LEN_P = 64, 
    parameter bit [MAX_LEN_P-1:0] FF_MASK = '0,
    parameter uop_pkg::op_t   OPS   [0:LEN-1]  = '{default:uop_pkg::OP_NOP},
    parameter logic [31:0]    IMM   [LEN]  = '{default:32'h0},
    parameter logic           USE_IMM[LEN] = '{default:1'b0},
    parameter int             W            = 32
)(
    input  logic                 clk,
    input  logic [W-1:0]         src,
    input  logic [W-1:0]         c,
    input  logic [$clog2(W)-1:0] shamt,
    output logic [W-1:0]         dst
);

    logic [W-1:0] stage [LEN+1];
    assign stage[0] = src;

    generate
        for (genvar i = 0; i < LEN; i++) begin : g
            logic [W-1:0] alu_out;
            wire  [W-1:0] b_input = USE_IMM[i] ? IMM[i] : stage[i];
            
            microop_unit #(.OP(OPS[i]), .W(W)) alu_i (
                .clk  (clk),
                .a(stage[i]),
                .b   (b_input),
                .c (c),  
                .shamt(shamt),
                .y(alu_out)
            );
            
            localparam bit USE_FF = FF_MASK[i];
            
            if (USE_FF) begin : g_ff
                always_ff @(posedge clk) stage[i+1] <= alu_out;
            end
            else begin : g_wire
                assign stage[i+1] = alu_out;
            end
        end
    endgenerate

    assign dst = stage[LEN];
endmodule