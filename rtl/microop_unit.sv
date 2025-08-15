(* keep_hierarchy = "yes" *)
module microop_unit #(
    parameter uop_pkg::op_t OP   = uop_pkg::OP_NOP,
    parameter int           W    = 128,  
    parameter int           FP_LATENCY = 0
)(
    input  logic                 clk,
    input  logic [W-1:0]         a,
    input  logic [W-1:0]         b,
    input  logic [W-1:0]         c,      
    input  logic [$clog2(W)-1:0] shamt,  
    output logic [W-1:0]         y
);

    import uop_pkg::*;

    function automatic logic [W-1:0] lshift(input logic [W-1:0] d, input logic [$clog2(W)-1:0] s);
        return d << s;
    endfunction
    function automatic logic [W-1:0] rshift(input logic [W-1:0] d, input logic [$clog2(W)-1:0] s);
        return d >> s;
    endfunction

    function automatic int unsigned tzcount(input logic [W-1:0] d);
        automatic int i;
        for (i=0;i<W;i++) if (d[i]) return i;
        return W;
    endfunction

    localparam int LW       = (W < 64) ? 64 : W;
    localparam int LANES64  = LW/64;
    localparam int LANES32  = LW/32;
    localparam int LANES16  = LW/16;
    localparam int LANES8   = LW/8;

    // ---- lane-wise arithmetic ----
    function automatic logic [W-1:0] lane_add64(input logic [W-1:0] A,B);
        automatic logic [W-1:0] R;
        automatic int i;
        for (i=0;i<LANES64;i++) R[i*64 +:64] = A[i*64 +:64] + B[i*64 +:64];
        return R;
    endfunction
    function automatic logic [W-1:0] lane_sub64(input logic [W-1:0] A,B);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES64;i++) R[i*64 +:64] = A[i*64 +:64] - B[i*64 +:64];
        return R;
    endfunction

    function automatic logic [W-1:0] lane_add32(input logic [W-1:0] A,B);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES32;i++) R[i*32 +:32] = A[i*32 +:32] + B[i*32 +:32];
        return R;
    endfunction
    function automatic logic [W-1:0] lane_sub32(input logic [W-1:0] A,B);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES32;i++) R[i*32 +:32] = A[i*32 +:32] - B[i*32 +:32];
        return R;
    endfunction

    function automatic logic [W-1:0] lane_add16(input logic [W-1:0] A,B);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES16;i++) R[i*16 +:16] = A[i*16 +:16] + B[i*16 +:16];
        return R;
    endfunction
    function automatic logic [W-1:0] lane_sub16(input logic [W-1:0] A,B);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES16;i++) R[i*16 +:16] = A[i*16 +:16] - B[i*16 +:16];
        return R;
    endfunction

    function automatic logic [W-1:0] lane_mul32_lo(input logic [W-1:0] A,B);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES32;i++) begin
            automatic logic signed [31:0] x  = A[i*32 +:32];
            automatic logic signed [31:0] yv = B[i*32 +:32];
            automatic logic signed [63:0] p  = x * yv;
            R[i*32 +:32] = p[31:0]; // VPMULLD: lo-32
        end
        return R;
    endfunction

    // ---- lane-wise shifts ----
    function automatic logic [W-1:0] lane_shl64(input logic [W-1:0] A, input logic [5:0] s);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES64;i++) R[i*64 +:64] = A[i*64 +:64] << s; return R;
    endfunction
    function automatic logic [W-1:0] lane_shr64(input logic [W-1:0] A, input logic [5:0] s);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES64;i++) R[i*64 +:64] = A[i*64 +:64] >> s; return R;
    endfunction

    function automatic logic [W-1:0] lane_shl32(input logic [W-1:0] A, input logic [4:0] s);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES32;i++) R[i*32 +:32] = A[i*32 +:32] << s; return R;
    endfunction
    function automatic logic [W-1:0] lane_shr32(input logic [W-1:0] A, input logic [4:0] s);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES32;i++) R[i*32 +:32] = A[i*32 +:32] >> s; return R;
    endfunction
    function automatic logic [W-1:0] lane_sar32(input logic [W-1:0] A, input logic [4:0] s);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES32;i++) R[i*32 +:32] = $signed(A[i*32 +:32]) >>> s; return R;
    endfunction

    function automatic logic [W-1:0] lane_shl16(input logic [W-1:0] A, input logic [3:0] s);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES16;i++) R[i*16 +:16] = A[i*16 +:16] << s; return R;
    endfunction
    function automatic logic [W-1:0] lane_shr16(input logic [W-1:0] A, input logic [3:0] s);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES16;i++) R[i*16 +:16] = A[i*16 +:16] >> s; return R;
    endfunction
    function automatic logic [W-1:0] lane_sar16(input logic [W-1:0] A, input logic [3:0] s);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES16;i++) R[i*16 +:16] = $signed(A[i*16 +:16]) >>> s; return R;
    endfunction

    // ---- misc ----
    function automatic logic [W-1:0] lane_avgb8(input logic [W-1:0] A,B);
        automatic logic [W-1:0] R; automatic int i;
        for (i=0;i<LANES8;i++) begin
            automatic logic [8:0] t = {1'b0,A[i*8 +:8]} + {1'b0,B[i*8 +:8]} + 9'd1;
            R[i*8 +:8] = t[8:1]; // ceil((a+b)/2)
        end
        return R;
    endfunction

    function automatic logic [W-1:0] vbroadcast_elem(input logic [W-1:0] src, input int elem_bits);
        automatic logic [W-1:0] ret;
        automatic logic [63:0] val64; automatic logic [31:0] val32;
        automatic logic [15:0] val16; automatic logic [7:0]  val8;
        automatic int i;
        case (elem_bits)
            64: begin val64 = src[63:0];  for (i=0;i<LANES64;i++) ret[i*64 +:64] = val64; end
            32: begin val32 = src[31:0];  for (i=0;i<LANES32;i++) ret[i*32 +:32] = val32; end
            16: begin val16 = src[15:0];  for (i=0;i<LANES16;i++) ret[i*16 +:16] = val16; end
             8: begin val8  = src[7:0];   for (i=0;i<LANES8 ;i++) ret[i*8  +:8 ] = val8;  end
            default: ret = src;
        endcase
        return ret;
    endfunction

    wire [$clog2(W)-1:0] sh = shamt % W;

    generate
    if (OP==OP_NOP) begin : g_nop
        always_ff @(posedge clk) y <= a;
    end
    else if (OP==OP_MOV || OP==OP_MOVAPS || OP==OP_MOVAPD ||
             OP==OP_VMOVAPS || OP==OP_VMOVAPD ||
             OP==OP_VMOVUPS || OP==OP_VMOVUPD ||
             OP==OP_MOVDQA || OP==OP_MOVDQU ||
             OP==OP_VMOVDQA || OP==OP_VMOVDQU) begin : g_mov
        always_ff @(posedge clk) y <= a;
    end
    else if (OP==OP_MOVD || OP==OP_VMOVD) begin : g_movd
        always_ff @(posedge clk) begin y <= '0; y[31:0] <= a[31:0]; end
    end
    else if (OP==OP_MOVQ || OP==OP_VMOVQ) begin : g_movq
        always_ff @(posedge clk) begin y <= '0; y[63:0] <= a[63:0]; end
    end
    else if (OP==OP_MOVSD || OP==OP_VMOVSD) begin : g_movsd
        always_ff @(posedge clk) begin y <= a; y[63:0] <= b[63:0]; end
    end
    else if (OP==OP_MOVSS || OP==OP_VMOVSS) begin : g_movss
        always_ff @(posedge clk) begin y <= a; y[31:0] <= b[31:0]; end
    end
    else if (OP==OP_VMOVHPS || OP==OP_VMOVHPD) begin : g_vmovhps
        always_ff @(posedge clk) begin y <= a; if (W>=128) y[127:64] <= b[63:0]; end
    end
    else if (OP==OP_VMOVLPS || OP==OP_VMOVLPD) begin : g_vmovlps
        always_ff @(posedge clk) begin y <= a; y[63:0] <= b[63:0]; end
    end
    else if (OP==OP_VMOVLHPS) begin : g_vmovlhps
        always_ff @(posedge clk) begin y <= a; if (W>=128) y[127:64] <= b[63:0]; end
    end
    else if (OP==OP_PUNPCKLQDQ) begin : g_punpcklqdq
        always_ff @(posedge clk) begin
            y <= a;
            for (int blk=0; blk<(W/128); blk++) y[blk*128 +:128] <= { b[blk*64 +:64], a[blk*64 +:64] };
        end
    end

    else if (OP==OP_ADD || OP==OP_SUB || OP==OP_INC || OP==OP_DEC || OP==OP_NEG || OP==OP_CMP) begin : g_iadd_ip
        logic [W-1:0] ain, bin; logic addn;
        always_comb begin
            ain=a; bin=b; addn=1'b1;
            unique case (OP)
                OP_SUB, OP_CMP: addn = 1'b0;
                OP_INC: begin bin='d1; addn=1'b1; end
                OP_DEC: begin bin='d1; addn=1'b0; end
                OP_NEG: begin ain='0; bin=a; addn=1'b0; end
                default: ;
            endcase
        end
        logic [W-1:0] s_ip;
        (* use_dsp="yes" *)
        integer_addsub int_addsub_i (.CLK(clk), .CE(1'b1), .A(a), .B(bin), .ADD(addn), .C_IN(1'b0), .S(s_ip));
        always_ff @(posedge clk) y <= s_ip;
    end

    else if (OP==OP_MUL || OP==OP_IMUL) begin : g_imul_ip
        wire [63:0] a64 = a[63:0];
        wire [63:0] b64 = b[63:0];
        logic [127:0] p128;
        (* use_dsp="yes" *)
        integer_mul mul_i (.CLK(clk), .CE(1'b1), .A(a64), .B(b64), .P(p128));
        
        localparam int OUTW = (W < 128) ? W : 128;
        always_ff @(posedge clk) begin
          y <= {{(W-OUTW){1'b0}}, p128[OUTW-1:0]};
        end
    end

    else if (OP==OP_VADDSD || OP==OP_VSUBSD) begin : g_vaddsd_ip
        localparam logic [7:0] OP_ADD8=8'h00, OP_SUB8=8'h01;
        logic [63:0] r0;
        floating_point_addsub fp_addsub_sd (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tready(), .s_axis_a_tdata(a[63:0]), .s_axis_a_tlast(1'b1),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tready(), .s_axis_b_tdata(b[63:0]),
            .s_axis_operation_tvalid(1'b1), .s_axis_operation_tready(),
            .s_axis_operation_tdata(OP==OP_VSUBSD ? OP_SUB8 : OP_ADD8),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0), .m_axis_result_tlast()
        );
        logic [W-1:0] passthru [0:FP_LATENCY];
        assign passthru[0] = a;
        if (FP_LATENCY>0) begin : sd_pt
            for (genvar k=0;k<FP_LATENCY;k++) begin : pipe
                always_ff @(posedge clk) passthru[k+1] <= passthru[k];
            end
        end
        always_ff @(posedge clk) begin
            y <= (FP_LATENCY>0) ? passthru[FP_LATENCY] : a;
            y[63:0] <= r0;
        end
    end

    else if (OP==OP_VMULSD) begin : g_vmulsd_ip
        logic [63:0] r0;
        floating_point_mul fp_mul_sd (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tready(), .s_axis_a_tdata(a[63:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tready(), .s_axis_b_tdata(b[63:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0)
        );
        logic [W-1:0] passthru [0:FP_LATENCY];
        assign passthru[0] = a;
        if (FP_LATENCY>0) begin : sd_pt_mul
            for (genvar k=0;k<FP_LATENCY;k++) begin : pipe
                always_ff @(posedge clk) passthru[k+1] <= passthru[k];
            end
        end
        always_ff @(posedge clk) begin
            y <= (FP_LATENCY>0) ? passthru[FP_LATENCY] : a;
            y[63:0] <= r0;
        end
    end

    // ---- FP IP : SD FMA ----
    else if (OP==OP_VFMADD132SD || OP==OP_VFMADD213SD || OP==OP_VFMADD231SD ||
             OP==OP_VFMSUB132SD || OP==OP_VFMSUB213SD || OP==OP_VFMSUB231SD ||
             OP==OP_VFNMADD132SD|| OP==OP_VFNMADD213SD|| OP==OP_VFNMADD231SD) begin : g_fma_sd_ip
        logic [7:0] op8;
        always_comb begin
            op8 = 8'h00; // fmadd
            if (OP==OP_VFMSUB132SD || OP==OP_VFMSUB213SD || OP==OP_VFMSUB231SD) op8 = 8'h01;
            if (OP==OP_VFNMADD132SD|| OP==OP_VFNMADD213SD|| OP==OP_VFNMADD231SD) op8 = 8'h02;
        end
        logic [63:0] r0;
        floating_point_fma fp_fma_sd (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tready(), .s_axis_a_tdata(a[63:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tready(), .s_axis_b_tdata(b[63:0]),
            .s_axis_c_tvalid(1'b1), .s_axis_c_tready(), .s_axis_c_tdata(c[63:0]),
            .s_axis_operation_tvalid(1'b1), .s_axis_operation_tready(), .s_axis_operation_tdata(op8),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0)
        );
        logic [W-1:0] passthru [0:FP_LATENCY];
        assign passthru[0] = a;
        if (FP_LATENCY>0) begin : sd_pt_fma
            for (genvar k=0;k<FP_LATENCY;k++) begin : pipe
                always_ff @(posedge clk) passthru[k+1] <= passthru[k];
            end
        end
        always_ff @(posedge clk) begin
            y <= (FP_LATENCY>0) ? passthru[FP_LATENCY] : a;
            y[63:0] <= r0;
        end
    end

    // ---- FP IP : SD compare ----
    else if (OP==OP_VCOMISD || OP==OP_UCOMISD || OP==OP_VUCOMISD) begin : g_fcmp_sd_ip
        logic [3:0] cmp_st;
        floating_point_compare fp_cmp (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tready(), .s_axis_a_tdata(a[63:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tready(), .s_axis_b_tdata(b[63:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(cmp_st)
        );
        always_ff @(posedge clk) y <= {{(W-2){1'b0}}, cmp_st[2], cmp_st[1]};
    end

    // ---- FP IP : SD min/max ----
    else if (OP==OP_VMINSD || OP==OP_VMAXSD) begin : g_minmax_sd_ip
        logic [63:0] r0;
        floating_point_minmax fp_mm (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tready(), .s_axis_a_tdata(a[63:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tready(), .s_axis_b_tdata(b[63:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0)
        );
        logic [W-1:0] passthru [0:FP_LATENCY];
        assign passthru[0] = a;
        if (FP_LATENCY>0) begin : sd_pt_mm
            for (genvar k=0;k<FP_LATENCY;k++) begin : pipe
                always_ff @(posedge clk) passthru[k+1] <= passthru[k];
            end
        end
        always_ff @(posedge clk) begin
            y <= (FP_LATENCY>0) ? passthru[FP_LATENCY] : a;
            y[63:0] <= r0;
        end
    end

    // ---- FP IP : PD add/sub ----
    else if (OP==OP_VADDPD || OP==OP_VSUBPD) begin : g_vaddpd_ip
        localparam logic [7:0] OP_ADD8=8'h00, OP_SUB8=8'h01;
        logic [63:0] lr[0:LANES64-1];
        for (genvar gi=0;gi<LANES64;gi++) begin : lanes_pd_add
            floating_point_addsub fp_addsub_pd (
                .aclk(clk),
                .s_axis_a_tvalid(1'b1), .s_axis_a_tready(), .s_axis_a_tdata(a[gi*64 +:64]), .s_axis_a_tlast(1'b1),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tready(), .s_axis_b_tdata(b[gi*64 +:64]),
                .s_axis_operation_tvalid(1'b1), .s_axis_operation_tready(),
                .s_axis_operation_tdata(OP==OP_VSUBPD ? OP_SUB8 : OP_ADD8),
                .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(lr[gi]), .m_axis_result_tlast()
            );
        end
        always_ff @(posedge clk) begin
            automatic int i;
            for (i=0;i<LANES64;i++) y[i*64 +:64] <= lr[i];
        end
    end

    // ---- FP IP : PD mul ----
    else if (OP==OP_VMULPD) begin : g_vmulpd_ip
        logic [63:0] lr[0:LANES64-1];
        for (genvar gi=0;gi<LANES64;gi++) begin : lanes_pd_mul
            floating_point_mul fp_mul_pd (
                .aclk(clk),
                .s_axis_a_tvalid(1'b1), .s_axis_a_tready(), .s_axis_a_tdata(a[gi*64 +:64]),
                .s_axis_b_tvalid(1'b1), .s_axis_b_tready(), .s_axis_b_tdata(b[gi*64 +:64]),
                .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(lr[gi])
            );
        end
        always_ff @(posedge clk) begin
            automatic int i;
            for (i=0;i<LANES64;i++) y[i*64 +:64] <= lr[i];
        end
    end

    else begin : g_soft_only
        logic [W-1:0] y_comb;

        always_comb begin : MAIN_CASE_SOFT
            y_comb = '0;

            unique case (OP)
            OP_LEA    : y_comb = a + b;      
            OP_TEST   : y_comb = a & b;
            OP_AND    : y_comb = a & b;
            OP_ANDN   : y_comb = a & ~b;
            OP_OR     : y_comb = a | b;
            OP_XOR    : y_comb = a ^ b;
            OP_NOT    : y_comb = ~a;

            OP_BLSI   : y_comb = a & (~a + 1);
            OP_BLSR   : y_comb = a & (a - 1);
            OP_BZHI   : begin
                int idx;
                logic [W-1:0] m;
                idx = b[$clog2(W)-1:0];
                m   = (idx==0) ? '0 : (({W{1'b1}}) >> (W-idx));
                y_comb = a & m;
            end
            OP_BT     : y_comb = {{(W-1){1'b0}}, a[b[$clog2(W)-1:0]]};
            OP_TZCNT  : y_comb = tzcount(a);

            OP_SHL, OP_SAL : y_comb = lshift(a, sh);
            OP_SHR         : y_comb = rshift(a, sh);
            OP_SAR         : y_comb = $signed(a) >>> sh;
            OP_SHRX        : y_comb = a >> sh;
            OP_SHLX        : y_comb = a << sh;
            OP_RORX        : y_comb = (a >> sh) | (a << (W - sh));
            OP_SARX        : y_comb = $signed(a) >>> sh;

            OP_MOVSX       : y_comb = {{(W-8){a[7]}},   a[7:0]};
            OP_MOVSXD      : y_comb = {{(W-32){a[31]}}, a[31:0]};
            OP_MOVZX       : y_comb = {{(W-8){1'b0}},   a[7:0]};
            OP_CDQ         : y_comb = {{(W-32){a[31]}}, a[31:0]};
            OP_CDQE        : y_comb = {{(W-32){a[31]}}, a[31:0]};
            OP_CQO         : y_comb = {{(W-64){a[63]}}, a[63:0]};

            OP_VCOMISS, OP_VUCOMISS: begin
                logic [1:0] bits;
                bits[0] = (a[31:0]==b[31:0]);
                bits[1] = ($bitstoshortreal(a[31:0]) < $bitstoshortreal(b[31:0]));
                y_comb = {{(W-2){1'b0}}, bits};
            end

            OP_ANDPD, OP_ANDPS, OP_VANDPD, OP_VANDPS: y_comb = a & b;
            OP_VORPD, OP_VPOR                        : y_comb = a | b;
            OP_PXOR, OP_VPXOR, OP_VXORPD, OP_VXORPS  : y_comb = a ^ b;
            OP_VPAND                                 : y_comb = a & b;
            OP_VPANDN                                : y_comb = (~a) & b;

            // ---- packed FP (PS만 소프트), PD는 IP 처리 ----
            OP_VADDPS: begin
                automatic int i;
                for (i=0;i<LANES32;i++) begin
                    shortreal xa; shortreal xb;
                    xa = $bitstoshortreal(a[i*32 +:32]);
                    xb = $bitstoshortreal(b[i*32 +:32]);
                    y_comb[i*32 +:32] = $shortrealtobits(xa + xb);
                end
            end
            OP_VSUBPS: begin
                automatic int i;
                for (i=0;i<LANES32;i++) begin
                    shortreal xa; shortreal xb;
                    xa = $bitstoshortreal(a[i*32 +:32]);
                    xb = $bitstoshortreal(b[i*32 +:32]);
                    y_comb[i*32 +:32] = $shortrealtobits(xa - xb);
                end
            end
            OP_VMULPS: begin
                automatic int i;
                for (i=0;i<LANES32;i++) begin
                    shortreal xa; shortreal xb;
                    xa = $bitstoshortreal(a[i*32 +:32]);
                    xb = $bitstoshortreal(b[i*32 +:32]);
                    y_comb[i*32 +:32] = $shortrealtobits(xa * xb);
                end
            end

            // ---- packed integer add/sub/mul/avg ----
            OP_VPADDD : y_comb = lane_add32(a,b);
            OP_VPADDQ : y_comb = lane_add64(a,b);
            OP_VPADDW : y_comb = lane_add16(a,b);
            OP_VPSUBD : y_comb = lane_sub32(a,b);
            OP_VPSUBW : y_comb = lane_sub16(a,b);
            OP_VPMULLD: y_comb = lane_mul32_lo(a,b);
            OP_VPAVGB : y_comb = lane_avgb8(a,b);

            // ---- shifts (packed) ----
            OP_VPSLLD : y_comb = lane_shl32(a, sh[4:0]);
            OP_VPSLLQ : y_comb = lane_shl64(a, sh[5:0]);
            OP_VPSLLW : y_comb = lane_shl16(a, sh[3:0]);
            OP_VPSRLD : y_comb = lane_shr32(a, sh[4:0]);
            OP_VPSRLQ : y_comb = lane_shr64(a, sh[5:0]);
            OP_VPSRAD : y_comb = lane_sar32(a, sh[4:0]);
            OP_VPSRAW : y_comb = lane_sar16(a, sh[3:0]);

            // ---- broadcast ----
            OP_VBROADCASTSD: y_comb = vbroadcast_elem(b, 64);
            OP_VBROADCASTSS: y_comb = vbroadcast_elem(b, 32);
            OP_VPBROADCASTB: y_comb = vbroadcast_elem(b, 8);
            OP_VPBROADCASTD: y_comb = vbroadcast_elem(b, 32);
            OP_VPBROADCASTW: y_comb = vbroadcast_elem(b, 16);

            // ---- blends (imm-mask=shamt) ----
            OP_VPBLENDD: begin
                automatic int i;
                y_comb = a; for (i=0;i<LANES32;i++) if (shamt[i]) y_comb[i*32 +:32] = b[i*32 +:32];
            end
            OP_VPBLENDW: begin
                automatic int i;
                y_comb = a; for (i=0;i<LANES16;i++) if (shamt[i]) y_comb[i*16 +:16] = b[i*16 +:16];
            end
            OP_VBLENDPD: begin
                automatic int i;
                y_comb = a; for (i=0;i<LANES64;i++) if (shamt[i]) y_comb[i*64 +:64] = b[i*64 +:64];
            end

            // ---- insert / extract / mask / misc
            OP_VPINSRB: begin
                y_comb=a; y_comb[{b[4:0],3'b0} +:8 ]  = c[7:0];
            end
            OP_VPINSRD: begin
                y_comb=a; y_comb[{b[3:0],5'b0} +:32] = c[31:0];
            end
            OP_VPINSRQ: begin
                y_comb=a; y_comb[{b[2:0],6'b0} +:64] = c[63:0];
            end

            OP_VPEXTRD: y_comb = {{(W-32){1'b0}}, a[{b[3:0],5'b0} +:32]};
            OP_VPEXTRQ: y_comb = {{(W-64){1'b0}}, a[{b[2:0],6'b0} +:64]};

            OP_VINSERTPS: begin
                automatic int lane; lane = b[1+:2];
                y_comb = a; y_comb[lane*32 +:32] = b[31:0];
            end

            OP_VEXTRACTI128, OP_VEXTRACTF128: begin
                if (b[0]) y_comb = {{(W-128){1'b0}}, a[255:128]};
                else      y_comb = {{(W-128){1'b0}}, a[127:0]};
            end
            OP_VINSERTI128, OP_VINSERTF128: begin
                y_comb = a;
                if (b[0]) y_comb[255:128] = b[127:0];
                else      y_comb[127:0]   = b[127:0];
            end

            OP_VPCMPEQB: begin
                automatic int i;
                for (i=0;i<LANES8;i++)  y_comb[i*8  +:8 ] = (a[i*8 +:8]==b[i*8 +:8]) ? 8'hFF : 8'h00;
            end
            OP_VPCMPEQD: begin
                automatic int i;
                for (i=0;i<LANES32;i++) y_comb[i*32 +:32] = (a[i*32 +:32]==b[i*32 +:32]) ? 32'hFFFF_FFFF : 32'h0;
            end
            OP_VPCMPGTD: begin
                automatic int i;
                for (i=0;i<LANES32;i++) y_comb[i*32 +:32] = ($signed(a[i*32 +:32]) > $signed(b[i*32 +:32])) ? 32'hFFFF_FFFF : 32'h0;
            end
            OP_VPCMPGTW: begin
                automatic int i;
                for (i=0;i<LANES16;i++) y_comb[i*16 +:16] = ($signed(a[i*16 +:16]) > $signed(b[i*16 +:16])) ? 16'hFFFF : 16'h0;
            end

            OP_VPMAXSD: begin
                automatic int i;
                for (i=0;i<LANES32;i++) begin
                    automatic logic signed [31:0] x = a[i*32 +:32];
                    automatic logic signed [31:0] yv= b[i*32 +:32];
                    y_comb[i*32 +:32] = (x>yv)?x:yv;
                end
            end
            OP_VPMINUB: begin
                automatic int i;
                for (i=0;i<LANES8;i++) begin
                    automatic logic [7:0] x = a[i*8 +:8];
                    automatic logic [7:0] yv= b[i*8 +:8];
                    y_comb[i*8 +:8] = (x<yv)?x:yv;
                end
            end
            OP_VPMOVMSKB: begin
                automatic int i;
                for (i=0;i<LANES8;i++) y_comb[i] = a[i*8+7];
            end
            OP_VPTEST: begin
                automatic logic zf = ((a & b)  == '0);
                automatic logic cf = ((a & ~b) == '0);
                y_comb = { {(W-2){1'b0}}, zf, cf };
            end

            // ---- data dup / shuffles ----
            OP_VMOVDDUP: begin
                for (int blk=0; blk<(W/128); blk++) begin
                    automatic logic [63:0] lo = a[blk*128 +:64];
                    y_comb[blk*128 +:64]      = lo;
                    y_comb[blk*128 +64 +:64]  = lo;
                end
            end
            OP_VMOVSHDUP: begin
                automatic int i;
                for (i=0;i<LANES64;i++) begin
                    automatic logic [31:0] hi = a[i*64 + 32 +:32];
                    y_comb[i*64 +:32]     = hi;
                    y_comb[i*64 +32 +:32] = hi;
                end
            end
            OP_VMOVSLDUP: begin
                automatic int i;
                for (i=0;i<LANES64;i++) begin
                    automatic logic [31:0] lo = a[i*64 +:32];
                    y_comb[i*64 +:32]     = lo;
                    y_comb[i*64 +32 +:32] = lo;
                end
            end

            default: y_comb = a;
            endcase
        end

        always_ff @(posedge clk) y <= y_comb;
    end
    endgenerate

endmodule
