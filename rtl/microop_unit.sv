`include "uop_pkg.sv"
(* keep_hierarchy = "yes" *)
module microop_unit #(
    parameter uop_pkg::op_t OP = uop_pkg::OP_NOP,
    parameter int W  = 64                 
)(
    input  logic clk,
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
    generate if (OP inside {uop_pkg::OP_MUL, uop_pkg::OP_IMUL}) begin : g_mul
        (* use_dsp = "yes" *)
        localparam int LANE = 18;
        logic signed [LANE-1:0] A_s;
        logic signed [LANE-1:0] B_s;
        logic        [LANE-1:0] A_u;
        logic        [LANE-1:0] B_u;
        assign {A_s,B_s,A_u,B_u} = {a[LANE-1:0],b[LANE-1:0],
                                    a[LANE-1:0],b[LANE-1:0]};
        logic [47:0] P [0:2];   // 3-stage cascade

        for (genvar i=0;i<3;i++) begin : g_dsp
            DSP48E2 #(
                .AREG(1), .BREG(1), .MREG(1), .PREG(1),
                .USE_MULT("MULTIPLY")
            ) mult_i (
                .CLK(clk),
                .A (OP==uop_pkg::OP_IMUL ? A_s : A_u),
                .B (OP==uop_pkg::OP_IMUL ? B_s : B_u),
                .C (48'd0),
                .PCIN(i==0 ? 48'd0 : P[i-1]),
                .OPMODE  (9'b000_000_101),
                .ALUMODE (4'b0000),
                .INMODE  (5'b00000),
                .CARRYIN (1'b0), .CARRYINSEL(3'b000),
                .P       (P[i])
            );
        end
        assign y = {{(W-48){P[2][47]}}, P[2]};
    end

    else if (OP inside {uop_pkg::OP_ADD, uop_pkg::OP_SUB}) begin : g_add
        (* use_dsp = "no" *)
        always_comb begin
            if (OP==uop_pkg::OP_SUB)
                y = a - b;
            else
                y = a + b;
        end
    end

    else if (OP inside {uop_pkg::OP_FADD, uop_pkg::OP_FSUB,
                        uop_pkg::OP_FMUL}) begin : g_fp
        (* use_dsp = "yes" *)
        logic [W-1:0] pipe [0:4];
        assign pipe[0] = (OP==uop_pkg::OP_FMUL) ? (a ^ b) :
                         (OP==uop_pkg::OP_FSUB) ? (a - b) : (a + b);
        always_ff @(posedge clk) begin
            pipe[1] <= pipe[0]; pipe[2] <= pipe[1];
            pipe[3] <= pipe[2]; pipe[4] <= pipe[3];
        end
        assign y = pipe[4];   // 4-cycle latency
    end

    else if (OP == uop_pkg::OP_FMA) begin : g_fma
        (* use_dsp = "yes" *)
        logic [W-1:0] p [0:5];
        assign p[0] = a * b + a; // dummy
        always_ff @(posedge clk) begin
            p[1] <= p[0]; p[2] <= p[1];
            p[3] <= p[2]; p[4] <= p[3]; p[5] <= p[4];
        end
        assign y = p[5];      // 5-cycle latency
    end

    else if (OP == uop_pkg::OP_FCMP) begin : g_fcmp
        logic [2:0] flg [0:3];
        assign flg[0] = {a < b, a == b, 1'b0}; // CF,ZF,dummy
        always_ff @(posedge clk) begin
            flg[1] <= flg[0]; flg[2] <= flg[1]; flg[3] <= flg[2];
        end
        assign y = {{(W-3){1'b0}}, flg[3]};
    end
    
    else if (OP == uop_pkg::OP_ICONV) begin : g_iconv
        logic [W-1:0] p [0:4];
        assign p[0] = a;
        always_ff @(posedge clk) begin
            p[1] <= p[0]; p[2] <= p[1];
            p[3] <= p[2]; p[4] <= p[3];
        end
        assign y = p[4];
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
    endgenerate
endmodule
