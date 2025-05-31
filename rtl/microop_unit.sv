`include "uop_pkg.sv"
(* keep_hierarchy = "yes" *)
module microop_unit #(
    parameter uop_pkg::op_t OP = uop_pkg::OP_NOP,
    parameter int W  = 64                 
)(
    input  logic [W-1:0] a ,           // operand A
    input  logic [W-1:0] b ,           // operand B / immediate
    input  logic [$clog2(W)-1:0] shamt, // shift amount : 0‥63
    output logic [W-1:0] y             // result
);

    function automatic logic [W-1:0] lshift (input logic[W-1:0] d,
                                             input logic[$clog2(W)-1:0] s);
        lshift = d << s;
    endfunction

    function automatic logic [W-1:0] rshift (input logic[W-1:0] d,
                                             input logic[$clog2(W)-1:0] s);
        rshift = d >> s;
    endfunction

    // ---------- main ALU mux --------------------------------------
    generate
        //  DSP path for MUL / IMUL
        if (OP == uop_pkg::OP_MUL || OP == uop_pkg::OP_IMUL) begin : g_dsp
            (* use_dsp = "yes" *)
            logic [W-1:0] dsp_res;
            assign dsp_res = (OP == uop_pkg::OP_MUL)
                             ? (a * b)                       // unsigned
                             : ($signed(a) * $signed(b));    // signed
            assign y = dsp_res;
        end
        //  default LUT path 
        else begin : g_lut
            (* use_dsp = "no" *)
            always_comb unique case (OP)
                // arithmetic
                uop_pkg::OP_ADD  : y = a + b;
                uop_pkg::OP_ADC  : y = a + b + 1'b1;
                uop_pkg::OP_SUB  : y = a - b;
                uop_pkg::OP_SBB  : y = a - b - 1'b1;
                uop_pkg::OP_INC  : y = a + 1;
                uop_pkg::OP_DEC  : y = a - 1;
                uop_pkg::OP_NEG  : y = ~a + 1;
                uop_pkg::OP_CMP  : y = a - b;
                // bit-logic 
                uop_pkg::OP_AND  : y = a & b;
                uop_pkg::OP_OR   : y = a | b;
                uop_pkg::OP_XOR  : y = a ^ b;
                uop_pkg::OP_NOT  : y = ~a;
                uop_pkg::OP_TEST : y = a & b;
                // shifts / rotates
                uop_pkg::OP_SHL,  uop_pkg::OP_SAL : y = lshift(a, shamt);
                uop_pkg::OP_SHR                 : y = rshift(a, shamt);
                uop_pkg::OP_SAR                 : y = $signed(a) >>> shamt;
                uop_pkg::OP_ROL                 : y = (a << shamt) | (a >> (W-shamt));
                uop_pkg::OP_ROR                 : y = (a >> shamt) | (a << (W-shamt));
                uop_pkg::OP_RCL                 : y = lshift({b[0], a}, shamt);
                uop_pkg::OP_RCR                 : y = rshift({a, b[0]}, shamt);
                uop_pkg::OP_SHLD                : y = (b << (W-shamt)) | (a << shamt);
                uop_pkg::OP_SHRD                : y = (b >> (W-shamt)) | (a >> shamt);
                // divide 
                uop_pkg::OP_DIV  : y = (b==0) ? '0 : a / b;
                uop_pkg::OP_IDIV : y = (b==0) ? '0 : $signed(a)/$signed(b);
                // default 
                default          : y = a;
            endcase
        end
    endgenerate
endmodule
