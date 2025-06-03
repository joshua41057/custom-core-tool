`include "uop_pkg.sv"

module uop_block #(
    parameter int             LEN          = 4,
    parameter int             PIPE_STAGES  = 1,
    parameter logic [31:0]    FF_MASK      = 32'h0,
    parameter uop_pkg::op_t   OPS   [LEN]  = '{default:uop_pkg::OP_NOP},
    parameter logic [31:0]    IMM   [LEN]  = '{default:32'h0},
    parameter logic           USE_IMM[LEN] = '{default:1'b0},
    parameter int             W            = 32
)(
    input  logic                 clk,
    input  logic [W-1:0]         src,
    input  logic [$clog2(W)-1:0] shamt,
    output logic [W-1:0]         dst
);

    logic [W-1:0] stage [LEN+1];
    assign stage[0] = src;

    generate
        for (genvar i = 0; i < LEN; i++) begin : g
            logic [W-1:0] alu_out;

            microop_unit #(.OP(OPS[i]), .W(W)) alu_i (
                .a(stage[i]),
                .b(USE_IMM[i] ? IMM[i] : stage[i]),
                .shamt(shamt),
                .y(alu_out)
            );

            if (i < 32 && FF_MASK[i]) begin
                always_ff @(posedge clk) stage[i+1] <= alu_out;
            end else begin
                assign stage[i+1] = alu_out;
            end
        end
    endgenerate

    assign dst = stage[LEN];
endmodule