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

    function automatic logic [W-1:0] lshift (logic [W-1:0] d,
                                             logic [$clog2(W)-1:0] s);
        return d << s;
    endfunction

    function automatic logic [W-1:0] rshift (logic [W-1:0] d,
                                             logic [$clog2(W)-1:0] s);
        return d >> s;
    endfunction

    // ---------- main ALU mux --------------------------------------
    if (OP inside {uop_pkg::OP_MUL, uop_pkg::OP_IMUL}) begin : g_mul
        (* use_dsp = "yes" *)          
        localparam int AW = 18;
        localparam int BW = 18;

        logic [AW-1:0]      dsp_a_u;
        logic [BW-1:0]      dsp_b_u;
        logic signed [AW-1:0] dsp_a_s;
        logic signed [BW-1:0] dsp_b_s;

        assign {dsp_a_u, dsp_b_u} = {a[AW-1:0], b[BW-1:0]};
        assign {dsp_a_s, dsp_b_s} = {a[AW-1:0], b[BW-1:0]};

        logic [47:0] dsp_p /* synthesis keep */;

        DSP48E2 #(
            .AREG      (1), .BREG(1), .MREG(1), .PREG(1),
            .USE_MULT ("MULTIPLY")
        ) u_mul (
            .CLK      (clk),
            .A        (OP==uop_pkg::OP_IMUL ? dsp_a_s : dsp_a_u),
            .B        (OP==uop_pkg::OP_IMUL ? dsp_b_s : dsp_b_u),
            .C        (48'd0),
            .PCIN     (48'd0),           
            .OPMODE   (9'b000_000_101), 
            .ALUMODE  (4'b0000),
            .INMODE   (5'b00000),
            .CARRYIN  (1'b0), .CARRYINSEL (3'b000),
            .P        (dsp_p)
        );

        assign y = {{(W-48){dsp_p[47]}}, dsp_p};
    end
else if (OP inside {uop_pkg::OP_ADD, uop_pkg::OP_SUB}) begin : g_addsub
        (* use_dsp = "yes" *)
        localparam int AW = 30;
        localparam int BW = 18;

        logic [AW-1:0] dsp_a = a[AW-1:0];
        logic [BW-1:0] dsp_b = b[BW-1:0];
        logic [47:0]   dsp_p /* synthesis keep */;

        DSP48E2 #(
            .AREG(1), .BREG(1), .CREG(1), .PREG(1),
            .USE_MULT("NONE")            
        ) u_addsub (
            .CLK      (clk),
            .A        (dsp_a),
            .B        (dsp_b),
            .C        (48'd0),
            .PCIN     (48'd0),            
            .OPMODE   (9'b000_000_010),
            .ALUMODE  (OP==uop_pkg::OP_SUB ? 4'b0011 : 4'b0000),
            .INMODE   (5'b00000),
            .CARRYIN  (1'b0), .CARRYINSEL(3'b000),
            .P        (dsp_p)
        );
        assign y = {{(W-48){dsp_p[47]}}, dsp_p};
    end
    /* ---------- LUT/Carry path ---------- */
    else begin : g_lut
        (* use_dsp = "no" *)
        always_comb unique case (OP)
            // arithmetic (LUT/carry)
            uop_pkg::OP_ADC  : y = a + b + 1'b1;
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
            uop_pkg::OP_SHL,
            uop_pkg::OP_SAL  : y = lshift(a, shamt);
            uop_pkg::OP_SHR  : y = rshift(a, shamt);
            uop_pkg::OP_SAR  : y = $signed(a) >>> shamt;
            uop_pkg::OP_ROL  : y = (a << shamt) | (a >> (W-shamt));
            uop_pkg::OP_ROR  : y = (a >> shamt) | (a << (W-shamt));
            uop_pkg::OP_RCL  : y = lshift({b[0], a}, shamt);
            uop_pkg::OP_RCR  : y = rshift({a, b[0]}, shamt);
            uop_pkg::OP_SHLD : y = (b << (W-shamt)) | (a << shamt);
            uop_pkg::OP_SHRD : y = (b >> (W-shamt)) | (a >> shamt);
            // divide (slow, rare)
            uop_pkg::OP_DIV  : y = (b==0) ? '0 : a / b;
            uop_pkg::OP_IDIV : y = (b==0) ? '0 : $signed(a)/$signed(b);
            // default / NOP
            default          : y = a;
        endcase
    end
endmodule
