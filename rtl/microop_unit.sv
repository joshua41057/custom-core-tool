`include "uop_pkg.sv"


(* keep_hierarchy = "yes" *)
module microop_unit #(
    parameter uop_pkg::op_t OP = uop_pkg::OP_NOP,
    parameter int W  = 64                 
)(
    input  logic clk,
    input  logic [W-1:0] a,           // operand A
    input  logic [W-1:0] b,           // operand B / immediate
    input  logic [W-1:0] c,           // FMA third operand
    input  logic [$clog2(W)-1:0] shamt,// shift amount : 0‥W-1
    output logic [W-1:0] y            // result
);

    // left/right shift helpers
    function automatic logic [W-1:0] lshift(input logic [W-1:0] d, input logic [$clog2(W)-1:0] s);
        return d << s;
    endfunction
    function automatic logic [W-1:0] rshift(input logic [W-1:0] d, input logic [$clog2(W)-1:0] s);
        return d >> s;
    endfunction

    localparam int LW    = (W < 64 ? 64 : W);
    localparam int LANES = LW/64;

    generate
    wire [$clog2(W)-1:0] sh = shamt % W;
    // ---------------------- INTEGER MUL/IMUL ----------------------
    if (OP == uop_pkg::OP_MUL || OP == uop_pkg::OP_IMUL) begin : g_mul_ip
        logic [63:0] a64   = a[63:0];
        logic [63:0] b64   = b[63:0];
    
        logic [127:0] p128;
    
        integer_mul mul_i (
            .CLK (clk),
            .CE  (1'b1),
            .A   (a64),
            .B   (b64),
            .P   (p128)
        );
    
        assign y = p128[W-1:0];
    end
    
    else if (OP == uop_pkg::OP_DIV || OP == uop_pkg::OP_IDIV) begin : g_idiv
        logic        s_valid = 1'b1;
        logic [63:0] dividend, divisor;
    
        assign dividend = a;
        assign divisor = (b==0) ? 64'd1 : b;
    
        logic [63:0] qout;
        logic        q_valid;
    
        integer_div div_i (
            .aclk        (clk),
            .s_axis_dividend_tvalid (s_valid),
            .s_axis_dividend_tdata  (dividend),
            .s_axis_divisor_tvalid  (s_valid),
            .s_axis_divisor_tdata   (divisor),
            .m_axis_dout_tvalid     (q_valid),
            .m_axis_dout_tdata      (qout)
        );
    
        always_ff @(posedge clk)
            if (q_valid)             
                y <= qout;
    end

    // ------------------------ INTEGER ADD/SUB ------------------------
    else if ( OP==uop_pkg::OP_ADD  || OP==uop_pkg::OP_SUB  || OP==uop_pkg::OP_INC  || OP==uop_pkg::OP_DEC ||
              OP==uop_pkg::OP_NEG  || OP==uop_pkg::OP_CMP  || OP==uop_pkg::OP_ADC  || OP==uop_pkg::OP_SBB ) begin : g_iadd

        logic [W-1:0] bin;     
        logic         addn;    
        logic         cin; 
    
        always_comb begin
            bin  = b;
            addn = 1'b1;  
            cin  = 1'b0;
    
            unique case (OP)
                uop_pkg::OP_SUB ,
                uop_pkg::OP_CMP : addn = 1'b0;          
    
                uop_pkg::OP_SBB : begin
                                   addn = 1'b0;
                                   cin  = 1'b1;
                                 end
    
                uop_pkg::OP_INC : begin
                                   bin  = 'd1;
                                   addn = 1'b1;
                                 end
    
                uop_pkg::OP_DEC : begin
                                   bin  = 'd1;
                                   addn = 1'b0;
                                 end

                uop_pkg::OP_NEG : begin
                                   bin  = a;
                                   addn = 1'b0;
                                 end
    
                uop_pkg::OP_ADC : cin  = 1'b1;
    
                default : ;
            endcase
        end
    
        logic [W-1:0] ip_y;
    
        integer_addsub int_addsub_i (
            .CLK (clk),
            .CE  (1'b1),   
            .A   (a),
            .B   (bin),
            .ADD (addn),   
            .C_IN(cin),
            .S   (ip_y)
        );
    
        always_ff @(posedge clk)
            y <= ip_y;
    end
    
    else if (OP == uop_pkg::OP_VMOVSD) begin : g_vmovsd
        always_comb begin
            y        = a;          
            y[63:0]  = b[63:0];    
        end
    end

    // ------------------------ FLOAT ADD/SUB ------------------------
    else if (OP == uop_pkg::OP_SUBSS  || OP == uop_pkg::OP_FADD  || OP == uop_pkg::OP_FSUB  ||
             OP == uop_pkg::OP_VADDSD || OP == uop_pkg::OP_VSUBSD ||
             OP == uop_pkg::OP_VADDSD256 || OP == uop_pkg::OP_VSUBSD256) begin : g_fadd
        logic [63:0] la[0:LANES-1], lb[0:LANES-1], lr[0:LANES-1];
        // split into 64-bit lanes
        for (genvar i = 0; i < LANES; i++) begin
            assign la[i] = a[i*64 +: 64];
            assign lb[i] = b[i*64 +: 64];
        end
        localparam logic [7:0] OP_ADD  = 8'h00;
        localparam logic [7:0] OP_SUB  = 8'h01;
        // instantiate IP
        for (genvar i = 0; i < LANES; i++) begin : lanes
            floating_point_addsub fp_addsub_inst (
                .aclk                     (clk),

                .s_axis_a_tvalid          (1'b1),
                .s_axis_a_tready          (),            // unused
                .s_axis_a_tdata           (la[i]),
                .s_axis_a_tlast           (1'b1),

                .s_axis_b_tvalid          (1'b1),
                .s_axis_b_tready          (),            // unused
                .s_axis_b_tdata           (lb[i]),

                .s_axis_operation_tvalid  (1'b1),
                .s_axis_operation_tready  (),            // unused
                .s_axis_operation_tdata   (OP==uop_pkg::OP_FSUB ? OP_SUB : OP_ADD),

                .m_axis_result_tvalid     (),            // unused
                .m_axis_result_tready     (1'b1),
                .m_axis_result_tdata      (lr[i]),
                .m_axis_result_tlast      () 
            );
            assign y[i*64 +:64] = lr[i];
        end
    end

    // ------------------------ FLOAT MUL ------------------------
    else if (OP == uop_pkg::OP_FMUL || OP == uop_pkg::OP_VMULSD) begin : g_fmul
        logic [63:0] la[0:LANES-1], lb[0:LANES-1], lr[0:LANES-1];
        for (genvar i = 0; i < LANES; i++) begin
            assign la[i] = a[i*64 +:64];
            assign lb[i] = b[i*64 +:64];
        end
        for (genvar i = 0; i < LANES; i++) begin : lanes_mul
            floating_point_mul fp_mul_inst (
                .aclk                     (clk),

                .s_axis_a_tvalid          (1'b1),
                .s_axis_a_tready          (),        // unused
                .s_axis_a_tdata           (la[i]),

                .s_axis_b_tvalid          (1'b1),
                .s_axis_b_tready          (),        // unused
                .s_axis_b_tdata           (lb[i]),

                .m_axis_result_tvalid     (),        // unused
                .m_axis_result_tready     (1'b1),
                .m_axis_result_tdata      (lr[i])
            );
            assign y[i*64 +:64] = lr[i];
        end
    end

    // ------------------------ FMA ------------------------
    else if (OP == uop_pkg::OP_VFMADD132SD || OP == uop_pkg::OP_VFNMADD132SD) begin : g_fma
        logic [63:0] la[0:LANES-1], lb[0:LANES-1], lc[0:LANES-1], lr[0:LANES-1];
        for (genvar i = 0; i < LANES; i++) begin
            assign la[i] = a[i*64 +:64];
            assign lb[i] = b[i*64 +:64];
            assign lc[i] = c[i*64 +:64];
        end
        for (genvar i = 0; i < LANES; i++) begin : lanes_fma
            floating_point_fma fp_fma_inst (
                .aclk                   (clk),

                .s_axis_a_tvalid        (1'b1),
                .s_axis_a_tready        (),          // unused
                .s_axis_a_tdata         (la[i]),

                .s_axis_b_tvalid        (1'b1),
                .s_axis_b_tready        (),          // unused
                .s_axis_b_tdata         (lb[i]),

                .s_axis_c_tvalid        (1'b1),
                .s_axis_c_tready        (),          // unused
                .s_axis_c_tdata         (lc[i]),

                .s_axis_operation_tvalid(1'b1),      // unused
                .s_axis_operation_tready(),          // unused
                .s_axis_operation_tdata(OP==uop_pkg::OP_VFNMADD132SD ? 8'h02 : 8'h00),       // unused

                .m_axis_result_tvalid   (),          // unused
                .m_axis_result_tready   (1'b1),
                .m_axis_result_tdata    (lr[i])
            );
            assign y[i*64 +:64] = lr[i];
        end
    end

    // ------------------------ COMPARISON ------------------------
    else if (OP == uop_pkg::OP_VCOMISD) begin : g_vcomisd
        logic [3:0] cmp_st;
        floating_point_compare fp_cmp (
            .aclk                   (clk),

            .s_axis_a_tvalid        (1'b1),
            .s_axis_a_tready        (),        // unused
            .s_axis_a_tdata         (a[63:0]),

            .s_axis_b_tvalid        (1'b1),
            .s_axis_b_tready        (),        // unused
            .s_axis_b_tdata         (b[63:0]),

            .m_axis_result_tvalid   (),        // unused
            .m_axis_result_tready   (1'b1),
            .m_axis_result_tdata    (cmp_st)
        );
        // CF/ZF latched one cycle
        always_ff @(posedge clk)
            y <= {{(W-2){1'b0}}, cmp_st[2], cmp_st[1]};
    end

    // -------------------- CONVERT INT→FP --------------------
    else if (OP == uop_pkg::OP_VCVTSI2SD) begin : g_vcvtsi2sd
        floating_point_convert fp_cnv (
            .aclk                    (clk),

            .s_axis_a_tvalid         (1'b1),
            .s_axis_a_tready         (),          // unused
            .s_axis_a_tdata          (a[31:0]),

            .m_axis_result_tvalid    (),          // unused
            .m_axis_result_tready    (1'b1),
            .m_axis_result_tdata     (y[63:0])
        );
        if (W > 64) begin : pad_vcvt
           assign y[W-1:64] = '0;
        end
    end

    // -------------------- MIN/MAX --------------------
    else if (OP==uop_pkg::OP_VMINSD || OP==uop_pkg::OP_VMAXSD) begin : g_minmax
        floating_point_minmax fp_mm (
            .aclk                (clk),
    
            .s_axis_a_tvalid     (1'b1),
            .s_axis_a_tready     (),          // unused
            .s_axis_a_tdata      (a[63:0]),
    
            .m_axis_result_tvalid(),          // unused
            .m_axis_result_tready(1'b1),
            .m_axis_result_tdata (y[63:0])
        );
    
        if (W>64) begin : pad_minmax
            assign y[W-1:64] = '0;
        end
    end

    // -------------------- DIV --------------------
    else if (OP == uop_pkg::OP_VDIVSD) begin : g_fdiv
        floating_point_div fp_div (
            .aclk                    (clk),

            .s_axis_a_tvalid         (1'b1),
            .s_axis_a_tready         (),        // unused
            .s_axis_a_tdata          (a[63:0]),

            .s_axis_b_tvalid         (1'b1),
            .s_axis_b_tready         (),        // unused
            .s_axis_b_tdata          (b[63:0]),

            .m_axis_result_tvalid    (),        // unused
            .m_axis_result_tready    (1'b1),
            .m_axis_result_tdata     (y[63:0])
        );
        if (W > 64) begin : pad_div
           assign y[W-1:64] = '0;
        end
    end

    else if (OP == uop_pkg::OP_FCMP) begin : g_fcmp
        logic [2:0] flg [0:3];
        // combinational compare
        assign flg[0] = {a < b, a == b, 1'b0};
        always_ff @(posedge clk) begin
            flg[1] <= flg[0];
            flg[2] <= flg[1];
            flg[3] <= flg[2];
        end
        assign y = {{(W-3){1'b0}}, flg[3]};
    end

    // -------------------- ICONV (delay pipeline) --------------------
    else if (OP == uop_pkg::OP_ICONV) begin : g_iconv
        logic [W-1:0] p [0:4];
        assign p[0] = a;
        always_ff @(posedge clk) begin
            p[1] <= p[0];
            p[2] <= p[1];
            p[3] <= p[2];
            p[4] <= p[3];
        end
        assign y = p[4];
    end

    // ---------------- SIMD integer ops & MOV variants --------------
    else begin : g_lut
        (* use_dsp="no" *)
        always_comb unique case (OP)
            // arithmetic
            uop_pkg::OP_MOV    : y = a;
            uop_pkg::OP_MOVSX  : y = {{(W-8){a[7]}},  a[7:0]};
            uop_pkg::OP_MOVSXD : y = {{(W-32){a[31]}}, a[31:0]};
            uop_pkg::OP_MOVZX  : y = {{(W-8){1'b0}},    a[7:0]};
            // logic
            uop_pkg::OP_AND    : y = a & b;
            uop_pkg::OP_OR     : y = a | b;
            uop_pkg::OP_XOR    : y = a ^ b;
            uop_pkg::OP_NOT    : y = ~a;
            uop_pkg::OP_TEST   : y = a & b;
            // shifts/rotates
            uop_pkg::OP_SHL,   uop_pkg::OP_SAL  : y = lshift(a, sh);
            uop_pkg::OP_SHR                         : y = rshift(a, sh);
            uop_pkg::OP_SAR                         : y = $signed(a) >>> sh;
            uop_pkg::OP_ROL                         : y = (a << sh) | (a >> (W-sh));
            uop_pkg::OP_ROR,   uop_pkg::OP_RORX : y = (a >> sh) | (a << (W-sh));
            uop_pkg::OP_SHRX                        : y = a >> sh;
            uop_pkg::OP_RCL                         : y = lshift({b[0],a}[W-1:0], sh);
            uop_pkg::OP_RCR                         : y = rshift({a,b[0]}[W:1], sh);
            uop_pkg::OP_SHLD                        : y = (b << (W-sh)) | (a << sh);
            uop_pkg::OP_SHRD                        : y = (b >> (W-sh)) | (a >> sh);

            // default NOP
            default            : y = a;
        endcase
    end
    endgenerate


endmodule
