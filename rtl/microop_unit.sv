(* keep_hierarchy = "yes" *)
module microop_unit #(
    parameter uop_pkg::op_t OP    = uop_pkg::OP_NOP,
    parameter int           W     = 128
)(
    input  logic                   clk,
    input  logic [W-1:0]           a,
    input  logic [W-1:0]           b,
    input  logic [W-1:0]           c,
    input  logic [$clog2(W)-1:0]   shamt,
    output logic [W-1:0]           y
);
    import uop_pkg::*;

    // -----------------------------
    // helpers
    // -----------------------------
    function automatic logic [W-1:0] lshift(input logic [W-1:0] d, input logic [$clog2(W)-1:0] s);
      return d << s;
    endfunction
    function automatic logic [W-1:0] rshift(input logic [W-1:0] d, input logic [$clog2(W)-1:0] s);
      return d >> s;
    endfunction
    function automatic int unsigned tzcount(input logic [W-1:0] d);
      automatic int i; for (i=0;i<W;i++) if (d[i]) return i; return W;
    endfunction

    localparam int LANES64  = (W>=64 ) ? (W/64 ) : 0;
    localparam int LANES32  = (W>=32 ) ? (W/32 ) : 0;
    localparam int LANES16  = (W>=16 ) ? (W/16 ) : 0;
    localparam int LANES8   = (W>=8  ) ? (W/8  ) : 0;
    localparam int LANES128 = (W>=128) ? (W/128) : 0;
    localparam int LANES256 = (W>=256) ? (W/256) : 0;

    // vector lane helpers
    function automatic logic [W-1:0] lane_add64(input logic [W-1:0] A,B);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES64;i++) R[i*64 +:64] = A[i*64 +:64] + B[i*64 +:64]; return R;
    endfunction
    function automatic logic [W-1:0] lane_sub64(input logic [W-1:0] A,B);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES64;i++) R[i*64 +:64] = A[i*64 +:64] - B[i*64 +:64]; return R;
    endfunction
    function automatic logic [W-1:0] lane_add32(input logic [W-1:0] A,B);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES32;i++) R[i*32 +:32] = A[i*32 +:32] + B[i*32 +:32]; return R;
    endfunction
    function automatic logic [W-1:0] lane_sub32(input logic [W-1:0] A,B);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES32;i++) R[i*32 +:32] = A[i*32 +:32] - B[i*32 +:32]; return R;
    endfunction
    function automatic logic [W-1:0] lane_add16(input logic [W-1:0] A,B);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES16;i++) R[i*16 +:16] = A[i*16 +:16] + B[i*16 +:16]; return R;
    endfunction
    function automatic logic [W-1:0] lane_sub16(input logic [W-1:0] A,B);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES16;i++) R[i*16 +:16] = A[i*16 +:16] - B[i*16 +:16]; return R;
    endfunction
    function automatic logic [W-1:0] lane_mul32_lo(input logic [W-1:0] A,B);
      automatic logic [W-1:0] R = '0; 
      for (int i=0;i<LANES32;i++) begin
        logic signed [31:0] x=A[i*32 +:32], yv=B[i*32 +:32];
        logic signed [63:0] p = x * yv;
        R[i*32 +:32] = p[31:0];
      end
      return R;
    endfunction
    function automatic logic [W-1:0] lane_shl64(input logic [W-1:0] A, input logic [5:0] s);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES64;i++) R[i*64 +:64] = A[i*64 +:64] << s; return R;
    endfunction
    function automatic logic [W-1:0] lane_shr64(input logic [W-1:0] A, input logic [5:0] s);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES64;i++) R[i*64 +:64] = A[i*64 +:64] >> s; return R;
    endfunction
    function automatic logic [W-1:0] lane_shl32(input logic [W-1:0] A, input logic [4:0] s);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES32;i++) R[i*32 +:32] = A[i*32 +:32] << s; return R;
    endfunction
    function automatic logic [W-1:0] lane_shr32(input logic [W-1:0] A, input logic [4:0] s);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES32;i++) R[i*32 +:32] = A[i*32 +:32] >> s; return R;
    endfunction
    function automatic logic [W-1:0] lane_sar32(input logic [W-1:0] A, input logic [4:0] s);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES32;i++) R[i*32 +:32] = $signed(A[i*32 +:32]) >>> s; return R;
    endfunction
    function automatic logic [W-1:0] lane_shl16(input logic [W-1:0] A, input logic [3:0] s);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES16;i++) R[i*16 +:16] = A[i*16 +:16] << s; return R;
    endfunction
    function automatic logic [W-1:0] lane_shr16(input logic [W-1:0] A, input logic [3:0] s);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES16;i++) R[i*16 +:16] = A[i*16 +:16] >> s; return R;
    endfunction
    function automatic logic [W-1:0] lane_sar16(input logic [W-1:0] A, input logic [3:0] s);
      automatic logic [W-1:0] R = '0; for (int i=0;i<LANES16;i++) R[i*16 +:16] = $signed(A[i*16 +:16]) >>> s; return R;
    endfunction
    function automatic logic [W-1:0] lane_avgb8(input logic [W-1:0] A,B);
      automatic logic [W-1:0] R = '0; 
      for (int i=0;i<LANES8;i++) begin
        logic [8:0] t = {1'b0,A[i*8 +:8]} + {1'b0,B[i*8 +:8]} + 9'd1;
        R[i*8 +:8] = t[8:1];
      end
      return R;
    endfunction

    function automatic logic [W-1:0] vbroadcast_elem(input logic [W-1:0] src, input int elem_bits);
      logic [W-1:0] ret = '0; int i;
      case (elem_bits)
        64: for (i=0;i<LANES64;i++) ret[i*64 +:64] = src[63:0];
        32: for (i=0;i<LANES32;i++) ret[i*32 +:32] = src[31:0];
        16: for (i=0;i<LANES16;i++) ret[i*16 +:16] = src[15:0];
         8: for (i=0;i<LANES8 ;i++) ret[i*8  +:8 ] = src[7:0];
        default: ret = src;
      endcase
      return ret;
    endfunction

    // byte-shuffle per 128-bit block (VPSHUFB semantics)
    function automatic logic [127:0] vpshufb_128(input logic [127:0] data, input logic [127:0] ctl);
      logic [127:0] r; logic [7:0] c8;
      for (int i=0;i<16;i++) begin
        c8 = ctl[i*8 +:8];
        r[i*8 +:8] = c8[7] ? 8'h00 : data[(c8[3:0])*8 +:8];
      end
      return r;
    endfunction

    // VPERMQ/PD per 256-bit block
    function automatic logic [255:0] vpermq256_imm
      (
        input logic [255:0] x,
        input logic [7:0]   imm
      );
        logic [63:0]   q [0:3];
        logic [255:0]  r;
        int unsigned   i;
        int unsigned   idx0, idx1, idx2, idx3;

        for (i = 0; i < 4; i++) begin
          q[i] = x[i*64 +: 64];
        end

        idx0 = imm[1:0];
        idx1 = imm[3:2];
        idx2 = imm[5:4];
        idx3 = imm[7:6];

        r[ 63:  0] = q[idx0];
        r[127: 64] = q[idx1];
        r[191:128] = q[idx2];
        r[255:192] = q[idx3];

        return r;
    endfunction

    // flags for cmov/setcc : assume c[0]=ZF, c[1]=CF, c[2]=SF, c[3]=OF, c[4]=PF
    typedef struct packed {logic ZF, CF, SF, OF, PF;} flags_t;
    function automatic flags_t decode_flags(input logic [W-1:0] f);
      return '{ZF:f[0], CF:f[1], SF:f[2], OF:f[3], PF:f[4]};
    endfunction
    function automatic logic cc_true(input uop_pkg::op_t op, input flags_t F);
      logic t;
      unique case (op)
        OP_CMOVZ,  OP_SETZ   : t =  F.ZF;
        OP_CMOVNZ, OP_SETNZ  : t = ~F.ZF;

        OP_CMOVB,  OP_SETB   : t =  F.CF;
        OP_CMOVNB, OP_SETNB  : t = ~F.CF;

        OP_CMOVBE, OP_SETBE  : t = (F.CF | F.ZF);
        OP_CMOVNBE,OP_SETNBE : t = ~(F.CF | F.ZF);

        OP_CMOVL,  OP_SETL   : t = (F.SF ^ F.OF);
        OP_CMOVNL, OP_SETNL  : t = ~(F.SF ^ F.OF);

        OP_CMOVLE, OP_SETLE  : t = ((F.SF ^ F.OF) | F.ZF);
        OP_CMOVNLE,OP_SETNLE : t = ~((F.SF ^ F.OF) | F.ZF);

        OP_CMOVS             : t = F.SF;      // NOTE: CMOVS는 SF, SETP는 PF
        OP_SETP              : t = F.PF;
        OP_SETNP             : t = ~F.PF;

        default              : t = 1'b0;
      endcase
      return t;
    endfunction

    localparam bit IS_POW2 = ((W & (W-1)) == 0);
    wire [$clog2(W)-1:0] sh = IS_POW2 ? shamt : (shamt % W);

    // -----------------------------
    // main body
    // -----------------------------
    generate
      // NOP / MOV family
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

      // MOVD/Q/SD/SS + VMOVH/LH/LP*
      else if (OP==OP_MOVD || OP==OP_VMOVD) begin
        if (W>=32) always_ff @(posedge clk) begin y <= '0; y[31:0] <= a[31:0]; end
        else       always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_MOVQ || OP==OP_VMOVQ) begin
        if (W>=64) always_ff @(posedge clk) begin y <= '0; y[63:0] <= a[63:0]; end
        else       always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_MOVSD || OP==OP_VMOVSD) begin
        if (W>=64) always_ff @(posedge clk) begin y <= a; y[63:0] <= b[63:0]; end
        else       always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_MOVSS || OP==OP_VMOVSS) begin
        if (W>=32) always_ff @(posedge clk) begin y <= a; y[31:0] <= b[31:0]; end
        else       always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VMOVHPS || OP==OP_VMOVHPD) begin
        if (W>=128) always_ff @(posedge clk) begin y <= a; y[127:64] <= b[63:0]; end
        else        always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VMOVLPS || OP==OP_VMOVLPD) begin
        if (W>=64)  always_ff @(posedge clk) begin y <= a; y[63:0] <= b[63:0]; end
        else        always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VMOVLHPS) begin
        if (W>=128) always_ff @(posedge clk) begin y <= a; y[127:64] <= b[63:0]; end
        else        always_ff @(posedge clk) y <= a;
      end

      // unpack (punpcklqdq)
      else if (OP==OP_PUNPCKLQDQ) begin
        always_ff @(posedge clk) begin
          y <= a;
          for (int blk=0; blk<(W/128); blk++)
            y[blk*128 +:128] <= { b[blk*128 +:64], a[blk*128 +:64] };
        end
      end

      // integer add/sub/inc/dec/neg/cmp
      else if (OP==OP_ADD || OP==OP_SUB || OP==OP_INC || OP==OP_DEC || OP==OP_NEG || OP==OP_CMP) begin : g_iadd
        logic [W-1:0] ain, bin; logic addn;
        logic [W-1:0] s_ip;
        always_comb begin
          ain=a; bin=b; addn=1'b1;
          unique case (OP)
            OP_SUB, OP_CMP: addn = 1'b0;
            OP_INC: begin bin='d1; addn=1'b1; end
            OP_DEC: begin bin='d1; addn=1'b0; end
            OP_NEG: begin ain='0; bin=a;  addn=1'b0; end
            default: ;
          endcase
        end
        if (W==64) begin : use_ip
          (* use_dsp="yes" *)
          integer_addsub u_addsub (.CLK(clk), .CE(1'b1), .A(ain), .B(bin), .ADD(addn), .C_IN(1'b0), .S(s_ip));
        end else begin : use_fabric
          always_comb s_ip = addn ? (ain + bin) : (ain - bin);
        end
        always_ff @(posedge clk) y <= s_ip;
      end

      // ADC / SBB (carry/borrow in = c[0])
      else if (OP==OP_ADC || OP==OP_SBB) begin : g_adc_sbb
        logic [W-1:0] s; logic cin; assign cin = c[1];
        always_comb begin
          if (OP==OP_ADC) s = a + b + cin;
          else            s = a - b - cin;
        end
        always_ff @(posedge clk) y <= s;
      end

      // integer mul/div
      else if (OP==OP_MUL || OP==OP_IMUL) begin : g_imul
        if (W==64) begin : mul64_ip
          logic [127:0] p128;
          (* use_dsp="yes" *)
          integer_mul mul_i (.CLK(clk), .CE(1'b1), .A(a[63:0]), .B(b[63:0]), .P(p128));
          localparam int OUTW = (W < 128) ? W : 128;
          always_ff @(posedge clk) y <= {{(W-OUTW){1'b0}}, p128[OUTW-1:0]};
        end else begin
          logic [2*W-1:0] p;
          always_comb p = (OP==OP_IMUL) ? ($signed(a) * $signed(b)) : (a * b);
          always_ff @(posedge clk) y <= p[W-1:0];
        end
      end
      else if (OP==OP_DIV || OP==OP_IDIV) begin : g_idiv
        if (W==64) begin
          logic [63:0] dividend_u, divisor_u; logic sgn_q;
          always_comb begin
            if (OP==OP_IDIV) begin
              logic sa=a[63], sb=b[63];
              dividend_u = sa ? (~a + 64'd1) : a[63:0];
              divisor_u  = sb ? (~b + 64'd1) : b[63:0];
              sgn_q      = sa ^ sb;
            end else begin
              dividend_u = a[63:0]; divisor_u=b[63:0]; sgn_q=1'b0;
            end
          end
          wire [127:0] div_do;
          integer_div u_div (
            .aclk(clk),
            .s_axis_dividend_tvalid(1'b1), .s_axis_dividend_tready(), .s_axis_dividend_tdata(dividend_u),
            .s_axis_divisor_tvalid (1'b1), .s_axis_divisor_tready (), .s_axis_divisor_tdata (divisor_u),
            .m_axis_dout_tvalid    (),     .m_axis_dout_tready    (1'b1), .m_axis_dout_tdata(div_do)
          );
          wire [63:0] q_unsigned = div_do[127:64];
          wire [63:0] q_signed   = sgn_q ? (~q_unsigned + 64'd1) : q_unsigned;
          always_ff @(posedge clk) y <= {{(W-64){1'b0}}, q_signed};
        end else begin
          logic [W-1:0] q; always_comb q = (OP==OP_IDIV) ? $signed(a) / $signed(b) : a / b;
          always_ff @(posedge clk) y <= q;
        end
      end

      // CMOVxx (조건이면 b, 아니면 a)
      else if (OP==OP_CMOVZ  || OP==OP_CMOVNZ ||
               OP==OP_CMOVB  || OP==OP_CMOVNB ||
               OP==OP_CMOVBE || OP==OP_CMOVNBE ||
               OP==OP_CMOVL  || OP==OP_CMOVNL  ||
               OP==OP_CMOVLE || OP==OP_CMOVNLE ||
               OP==OP_CMOVS) begin : g_cmov
        flags_t F; logic take;
        always_comb begin
          F    = decode_flags(c);
          take = cc_true(OP, F);
        end
        always_ff @(posedge clk) y <= take ? b : a;
      end

      // SETcc (하위 8비트만 0xFF/0x00)
      else if (OP==OP_SETZ  || OP==OP_SETNZ ||
               OP==OP_SETB  || OP==OP_SETNB ||
               OP==OP_SETBE || OP==OP_SETNBE ||
               OP==OP_SETL  || OP==OP_SETNL  ||
               OP==OP_SETLE || OP==OP_SETNLE ||
               OP==OP_SETP  || OP==OP_SETNP) begin : g_setcc
        flags_t F; logic t;
        logic [W-1:0] next;
        always_comb begin
          F    = decode_flags(c);
          t    = cc_true(OP, F);
          next = '0;
          next[7:0] = t ? 8'hFF : 8'h00;
        end
        always_ff @(posedge clk) y <= next;
      end

      // scalar FP add/mul/fma/div/compare/minmax (Double)
      else if (OP==OP_VADDSD || OP==OP_VSUBSD) begin
        if (W>=64) begin
          localparam logic [7:0] OP_ADD8=8'h00, OP_SUB8=8'h01;
          logic [63:0] r0;
          floating_point_addsub fp_addsub_sd (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[63:0]), .s_axis_a_tlast(1'b1),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[63:0]),
            .s_axis_operation_tvalid(1'b1), .s_axis_operation_tdata(OP==OP_VSUBSD ? OP_SUB8 : OP_ADD8),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0), .m_axis_result_tlast()
          );
          always_ff @(posedge clk) begin y <= '0; y[63:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VMULSD) begin
        if (W>=64) begin
          logic [63:0] r0;
          floating_point_mul fp_mul_sd (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[63:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[63:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0)
          );
          always_ff @(posedge clk) begin y <= '0; y[63:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VFMADD132SD || OP==OP_VFMADD213SD || OP==OP_VFMADD231SD ||
               OP==OP_VFMSUB132SD || OP==OP_VFMSUB213SD || OP==OP_VFMSUB231SD ||
               OP==OP_VFNMADD132SD|| OP==OP_VFNMADD213SD|| OP==OP_VFNMADD231SD) begin
        if (W>=64) begin
          logic [7:0] op8; always_comb begin
            op8=8'h00; // FMA
            if (OP == OP_VFMSUB132SD || OP == OP_VFMSUB213SD || OP == OP_VFMSUB231SD) op8=8'h01;
            if (OP == OP_VFNMADD132SD || OP == OP_VFNMADD213SD || OP == OP_VFNMADD231SD) op8=8'h02;
          end
          logic [63:0] r0;
          floating_point_fma fp_fma_sd (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[63:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[63:0]),
            .s_axis_c_tvalid(1'b1), .s_axis_c_tdata(c[63:0]),
            .s_axis_operation_tvalid(1'b1), .s_axis_operation_tdata(op8),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0)
          );
          always_ff @(posedge clk) begin y <= '0; y[63:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VCOMISD || OP==OP_UCOMISD || OP==OP_VUCOMISD) begin
        if (W>=64) begin
          logic [3:0] cmp_st;
          floating_point_compare fp_cmp (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[63:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[63:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(cmp_st)
          );
          always_ff @(posedge clk) y <= {{(W-2){1'b0}}, cmp_st[2], cmp_st[1]}; // (EQ,LT) 형태
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VMINSD || OP==OP_VMAXSD) begin
        if (W>=64) begin
          logic [3:0] cmp_st;
          floating_point_compare fp_cmp (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[63:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[63:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(cmp_st)
          );
          wire lt = cmp_st[0]; wire gt = cmp_st[2];
          logic [63:0] sel;
          always_ff @(posedge clk) begin
            y <= '0;
            if (OP==OP_VMAXSD) sel = gt ? a[63:0] : b[63:0];
            else               sel = lt ? a[63:0] : b[63:0];
            y[63:0] <= sel;
          end
        end else always_ff @(posedge clk) y <= a;
      end

      // vector FP add/mul/div (PD)
      else if (OP==OP_VADDPD || OP==OP_VSUBPD) begin
        if (LANES64>0) begin
          localparam logic [7:0] OP_ADD8=8'h00, OP_SUB8=8'h01;
          logic [63:0] lr[0:LANES64-1];
          for (genvar gi=0; gi<LANES64; gi++) begin
            floating_point_addsub fp_addsub_pd (
              .aclk(clk),
              .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[gi*64 +:64]), .s_axis_a_tlast(1'b1),
              .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[gi*64 +:64]),
              .s_axis_operation_tvalid(1'b1), .s_axis_operation_tdata(OP==OP_VSUBPD ? OP_SUB8 : OP_ADD8),
              .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(lr[gi]), .m_axis_result_tlast()
            );
          end
          always_ff @(posedge clk) begin y <= '0; for (int i=0;i<LANES64;i++) y[i*64 +:64] <= lr[i]; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VMULPD) begin
        if (LANES64>0) begin
          logic [63:0] lr[0:LANES64-1];
          for (genvar gi=0; gi<LANES64; gi++) begin
            floating_point_mul fp_mul_pd (
              .aclk(clk),
              .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[gi*64 +:64]),
              .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[gi*64 +:64]),
              .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(lr[gi])
            );
          end
          always_ff @(posedge clk) begin y <= '0; for (int i=0;i<LANES64;i++) y[i*64 +:64] <= lr[i]; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VDIVPD) begin
        if (LANES64>0) begin
          logic [63:0] lr[0:LANES64-1];
          for (genvar gi=0; gi<LANES64; gi++) begin
            (* keep_hierarchy="yes", dont_touch="true" *)
            floating_point_div fp_div_pd (
              .aclk(clk),
              .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[gi*64 +:64]),
              .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[gi*64 +:64]),
              .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(lr[gi])
            );
          end
          always_ff @(posedge clk) begin y <= '0; for (int i=0;i<LANES64;i++) y[i*64 +:64] <= lr[i]; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VDIVSD) begin
        if (W>=64) begin
          logic [63:0] r0;
          (* keep_hierarchy="yes", dont_touch="true" *)
          floating_point_div fp_div_sd (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[63:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[63:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0)
          );
          always_ff @(posedge clk) begin y <= '0; y[63:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end

      // vector FMA (PD)
      else if (OP==OP_VFMADD132PD || OP==OP_VFMADD213PD || OP==OP_VFMADD231PD ||
               OP==OP_VFMSUB132PD || OP==OP_VFMSUB213PD || OP==OP_VFMSUB231PD ||
               OP==OP_VFNMADD132PD|| OP==OP_VFNMADD213PD|| OP==OP_VFNMADD231PD) begin
        if (LANES64>0) begin
          logic [7:0] op8; always_comb begin
            op8=8'h00;
            if (OP == OP_VFMSUB132PD || OP == OP_VFMSUB213PD || OP == OP_VFMSUB231PD) op8=8'h01;
            if (OP == OP_VFNMADD132PD || OP == OP_VFNMADD213PD || OP == OP_VFNMADD231PD) op8=8'h02;
          end
          logic [63:0] lr[0:LANES64-1];
          for (genvar gi=0; gi<LANES64; gi++) begin
            floating_point_fma fp_fma_pd (
              .aclk(clk),
              .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[gi*64 +:64]),
              .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[gi*64 +:64]),
              .s_axis_c_tvalid(1'b1), .s_axis_c_tdata(c[gi*64 +:64]),
              .s_axis_operation_tvalid(1'b1), .s_axis_operation_tdata(op8),
              .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(lr[gi])
            );
          end
          always_ff @(posedge clk) begin y <= '0; for (int i=0;i<LANES64;i++) y[i*64 +:64] <= lr[i]; end
        end else always_ff @(posedge clk) y <= a;
      end

      // vector FP min/max (PD)
      else if (OP==OP_VMAXPD || OP==OP_VMINPD) begin
        if (LANES64>0) begin
          logic [3:0] cmp_st [0:LANES64-1];
          for (genvar gi=0; gi<LANES64; gi++) begin
            floating_point_compare fp_cmp_lane (
              .aclk(clk),
              .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[gi*64 +:64]),
              .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[gi*64 +:64]),
              .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(cmp_st[gi])
            );
          end
          always_ff @(posedge clk) begin
            y <= '0;
            for (int i=0;i<LANES64;i++) begin
              logic lt = cmp_st[i][0]; logic gt = cmp_st[i][2];
              y[i*64 +:64] <= (OP==OP_VMAXPD) ? (gt ? a[i*64 +:64] : b[i*64 +:64])
                                             : (lt ? a[i*64 +:64] : b[i*64 +:64]);
            end
          end
        end else always_ff @(posedge clk) y <= a;
      end

      // vector FP (PS) add/mul/div + FMA(PS)
      else if (OP==OP_VADDPS || OP==OP_VSUBPS) begin
        if (LANES32>0) begin
          localparam logic [7:0] OP_ADD8=8'h00, OP_SUB8=8'h01;
          logic [31:0] lr[0:LANES32-1];
          for (genvar gi=0; gi<LANES32; gi++) begin
            (* keep_hierarchy="yes", dont_touch="true" *)
            floating_point_addsub_sp fp_addsub_ps (
              .aclk(clk),
              .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[gi*32 +:32]), .s_axis_a_tlast(1'b1),
              .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[gi*32 +:32]),
              .s_axis_operation_tvalid(1'b1), .s_axis_operation_tdata(OP==OP_VSUBPS ? OP_SUB8 : OP_ADD8),
              .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(lr[gi]), .m_axis_result_tlast()
            );
          end
          always_ff @(posedge clk) begin y <= '0; for (int i=0;i<LANES32;i++) y[i*32 +:32] <= lr[i]; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VMULPS) begin
        if (LANES32>0) begin
          logic [31:0] lr[0:LANES32-1];
          for (genvar gi=0; gi<LANES32; gi++) begin
            (* keep_hierarchy="yes", dont_touch="true" *)
            floating_point_mul_sp fp_mul_ps (
              .aclk(clk),
              .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[gi*32 +:32]),
              .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[gi*32 +:32]),
              .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(lr[gi])
            );
          end
          always_ff @(posedge clk) begin y <= '0; for (int i=0;i<LANES32;i++) y[i*32 +:32] <= lr[i]; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VDIVSS) begin
        if (W>=32) begin
          logic [31:0] r0;
          (* keep_hierarchy="yes", dont_touch="true" *)
          floating_point_div_sp fp_div_ss (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[31:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[31:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0)
          );
          always_ff @(posedge clk) begin y <= '0; y[31:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VDIVPS) begin
        if (LANES32>0) begin
          logic [31:0] lr[0:LANES32-1];
          for (genvar gi=0; gi<LANES32; gi++) begin
            (* keep_hierarchy="yes", dont_touch="true" *)
            floating_point_div_sp fp_div_ps (
              .aclk(clk),
              .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[gi*32 +:32]),
              .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[gi*32 +:32]),
              .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(lr[gi])
            );
          end
          always_ff @(posedge clk) begin y <= '0; for (int i=0;i<LANES32;i++) y[i*32 +:32] <= lr[i]; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VFMADD132PS || OP==OP_VFMADD213PS || OP==OP_VFMADD231PS ||
               OP==OP_VFMSUB132PS || OP==OP_VFMSUB213PS || OP==OP_VFMSUB231PS ||
               OP==OP_VFNMADD132PS|| OP==OP_VFNMADD213PS|| OP==OP_VFNMADD231PS) begin
        if (LANES32>0) begin
          logic [7:0] op8; always_comb begin
            op8=8'h00;
            if (OP == OP_VFMSUB132PS || OP == OP_VFMSUB213PS || OP == OP_VFMSUB231PS) op8=8'h01;
            if (OP == OP_VFNMADD132PS || OP == OP_VFNMADD213PS || OP == OP_VFNMADD231PS) op8=8'h02;
          end
          logic [31:0] lr[0:LANES32-1];
          for (genvar gi=0; gi<LANES32; gi++) begin
            floating_point_fma_sp fp_fma_ps (
              .aclk(clk),
              .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[gi*32 +:32]),
              .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[gi*32 +:32]),
              .s_axis_c_tvalid(1'b1), .s_axis_c_tdata(c[gi*32 +:32]),
              .s_axis_operation_tvalid(1'b1), .s_axis_operation_tdata(op8),
              .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(lr[gi])
            );
          end
          always_ff @(posedge clk) begin y <= '0; for (int i=0;i<LANES32;i++) y[i*32 +:32] <= lr[i]; end
        end else always_ff @(posedge clk) y <= a;
      end

      // scalar FP (SS) add/mul + FMA(SS) + min/max(SS)
      else if (OP==OP_ADDSS || OP==OP_SUBSS || OP==OP_VADDSS || OP==OP_VSUBSS) begin
        if (W>=32) begin
          localparam logic [7:0] OP_ADD8=8'h00, OP_SUB8=8'h01;
          logic [31:0] r0;
          floating_point_addsub_sp fp_addsub_ss (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[31:0]), .s_axis_a_tlast(1'b1),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[31:0]),
            .s_axis_operation_tvalid(1'b1), .s_axis_operation_tdata((OP==OP_SUBSS || OP==OP_VSUBSS) ? OP_SUB8 : OP_ADD8),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0), .m_axis_result_tlast()
          );
          always_ff @(posedge clk) begin y <= '0; y[31:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_MULSS || OP==OP_VMULSS) begin
        if (W>=32) begin
          logic [31:0] r0;
          floating_point_mul_sp fp_mul_ss (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[31:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[31:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0)
          );
          always_ff @(posedge clk) begin y <= '0; y[31:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VFMADD132SS || OP==OP_VFMADD213SS || OP==OP_VFMADD231SS ||
               OP==OP_VFMSUB132SS || OP==OP_VFMSUB213SS || OP==OP_VFMSUB231SS ||
               OP==OP_VFNMADD132SS|| OP==OP_VFNMADD213SS|| OP==OP_VFNMADD231SS) begin
        if (W>=32) begin
          logic [7:0] op8; always_comb begin
            op8=8'h00;
            if (OP == OP_VFMSUB132SS || OP == OP_VFMSUB213SS || OP == OP_VFMSUB231SS) op8=8'h01;
            if (OP == OP_VFNMADD132SS || OP == OP_VFNMADD213SS || OP == OP_VFNMADD231SS) op8=8'h02;
          end
          logic [31:0] r0;
          floating_point_fma_sp fp_fma_ss (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[31:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[31:0]),
            .s_axis_c_tvalid(1'b1), .s_axis_c_tdata(c[31:0]),
            .s_axis_operation_tvalid(1'b1), .s_axis_operation_tdata(op8),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0)
          );
          always_ff @(posedge clk) begin y <= '0; y[31:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VMAXSS || OP==OP_VMINSS) begin
        if (W>=32) begin
          logic [3:0] cmp_st;
          floating_point_compare_sp fp_cmp_ss (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[31:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[31:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(cmp_st)
          );
          wire lt = cmp_st[0], gt = cmp_st[2];
          logic [31:0] sel;
          always_ff @(posedge clk) begin
            y <= '0;
            y[31:0] <= (OP==OP_VMAXSS) ? (gt ? a[31:0] : b[31:0])
                                       : (lt ? a[31:0] : b[31:0]);
          end
        end else always_ff @(posedge clk) y <= a;
      end

      // 128-bit extract/insert
      else if (OP==OP_VEXTRACTI128 || OP==OP_VEXTRACTF128) begin
        if (W>=256) begin
          always_ff @(posedge clk)
            y <= b[0] ? {{(W-128){1'b0}}, a[255:128]}
                      : {{(W-128){1'b0}}, a[127:0]};
        end else if (W>=128) begin
          always_ff @(posedge clk) y <= {{(W-128){1'b0}}, a[127:0]};
        end else begin
          always_ff @(posedge clk) y <= a;
        end
      end
      else if (OP==OP_VINSERTI128 || OP==OP_VINSERTF128) begin
        if (W>=256) begin
          always_ff @(posedge clk) begin
            y <= a;
            if (c[0]) y[255:128] <= b[127:0];
            else      y[127:0]   <= b[127:0];
          end
        end else if (W>=128) begin
          always_ff @(posedge clk) begin y <= a; y[127:0] <= b[127:0]; end
        end else begin
          always_ff @(posedge clk) y <= a;
        end
      end

      // --- AVX2: VPSHUFB / VPERM* / VPUNPCK* ---
      else if (OP==OP_VPSHUFB) begin
        if (W>=128) begin
          logic [W-1:0] r='0;
          always_comb begin
            for (int blk=0; blk<(W/128); blk++)
              r[blk*128 +:128] = vpshufb_128(a[blk*128 +:128], b[blk*128 +:128]);
          end
          always_ff @(posedge clk) y <= r;
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VPERMQ || OP==OP_VPERMPD) begin
        // imm8 = b[7:0]; permute per 256-bit block
        if (W>=256) begin
          logic [W-1:0] r='0; logic [7:0] imm=b[7:0];
          always_comb begin
            for (int blk=0; blk<LANES256; blk++)
              r[blk*256 +:256] = vpermq256_imm(a[blk*256 +:256], imm);
          end
          always_ff @(posedge clk) y <= r;
        end else begin
          always_ff @(posedge clk) y <= a;
        end
      end
      else if (OP==OP_VPERM2I128) begin
        if (W>=256) begin
          logic [7:0] imm=b[7:0];
          logic [127:0] a0=a[127:0], a1=a[255:128], c0=c[127:0], c1=c[255:128];
          logic [127:0] lo, hi;
          always_comb begin
            unique case (imm[1:0]) 2'd0: lo=a0; 2'd1: lo=a1; 2'd2: lo=c0; default: lo=c1; endcase
            unique case (imm[5:4]) 2'd0: hi=a0; 2'd1: hi=a1; 2'd2: hi=c0; default: hi=c1; endcase
            if (imm[3]) lo='0; if (imm[7]) hi='0;
          end
          always_ff @(posedge clk) y <= {hi, lo};
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VPUNPCKLWD) begin
        logic [W-1:0] r='0;
        always_comb begin
          for (int blk=0; blk<(W/128); blk++)
            for (int i=0;i<8;i++) begin
              r[blk*128 + i*32 +:16]      = a[blk*128 + i*16 +:16];
              r[blk*128 + i*32 +16 +:16] = b[blk*128 + i*16 +:16];
            end
        end
        always_ff @(posedge clk) y <= r;
      end
      else if (OP==OP_VPUNPCKLDQ) begin
        logic [W-1:0] r='0;
        always_comb begin
          for (int blk=0; blk<(W/128); blk++)
            for (int i=0;i<4;i++) begin
              r[blk*128 + i*64 +:32]      = a[blk*128 + i*32 +:32];
              r[blk*128 + i*64 +32 +:32] = b[blk*128 + i*32 +:32];
            end
        end
        always_ff @(posedge clk) y <= r;
      end
      else if (OP==OP_VPUNPCKHQDQ || OP==OP_VPUNPCKLQDQ) begin
        logic [W-1:0] r='0;
        always_comb begin
          for (int blk=0; blk<(W/128); blk++) begin
            logic [63:0] a_lo=a[blk*128 +:64], a_hi=a[blk*128 +64 +:64];
            logic [63:0] b_lo=b[blk*128 +:64], b_hi=b[blk*128 +64 +:64];
            r[blk*128 +:128] = (OP==OP_VPUNPCKLQDQ) ? { b_lo, a_lo }
                                                   : { b_hi, a_hi };
          end
        end
        always_ff @(posedge clk) y <= r;
      end

      // scalar/vec converts & round
      else if (OP==OP_VCVTSS2SD) begin
        if (W>=64) begin
          logic [63:0] r0;
          floating_point_convert_sp2dp u_cvt (.aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[31:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0));
          always_ff @(posedge clk) begin y <= '0; y[63:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VCVTSD2SS) begin
        if (W>=32) begin
          logic [31:0] r0;
          floating_point_convert_dp2sp u_cvt (.aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[63:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0));
          always_ff @(posedge clk) begin y <= '0; y[31:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VCVTSI2SS) begin
        if (W>=32) begin
          logic [63:0] d64; logic [31:0] r0;
          floating_point_convert u_i2d (.aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[31:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(d64));
          floating_point_convert_dp2sp u_d2s (.aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(d64),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0));
          always_ff @(posedge clk) begin y <= '0; y[31:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VCVTSI2SD) begin
        if (W>=64) begin
          logic [63:0] r0;
          floating_point_convert fp_i2d (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[31:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0)
          );
          always_ff @(posedge clk) begin y <= '0; y[63:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end
      else if (OP==OP_VCVTTSD2SI) begin
        logic [31:0] r0;
        floating_point_to_int32_sd u_d2i (.aclk(clk),
          .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[63:0]),
          .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0));
        always_ff @(posedge clk) begin y <= '0; y[31:0] <= r0; end
      end
      else if (OP==OP_VCVTTSS2SI) begin
        logic [31:0] r0;
        floating_point_to_int32_ss u_s2i (.aclk(clk),
          .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[31:0]),
          .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0));
        always_ff @(posedge clk) begin y <= '0; y[31:0] <= r0; end
      end
      else if (OP==OP_VROUNDSD) begin
        if (W>=64) begin
          logic [63:0] r0;
          floating_point_round_sd u_rnd (.aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[63:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(r0));
          always_ff @(posedge clk) begin y <= '0; y[63:0] <= r0; end
        end else always_ff @(posedge clk) y <= a;
      end

      else if (OP==OP_VSQRTPD) begin : g_vsqrtpd
        if (LANES64>0) begin
          logic [63:0] lr[0:LANES64-1];
          for (genvar gi=0; gi<LANES64; gi++) begin
            floating_point_sqrt fp_sqrt_pd (
              .aclk(clk),
              .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[gi*64 +:64]),
              .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(lr[gi])
            );
          end
          always_ff @(posedge clk) begin
            y <= '0;
            for (int i=0;i<LANES64;i++) y[i*64 +:64] <= lr[i];
          end
        end else begin
          always_ff @(posedge clk) y <= a;
        end
      end

      else if (OP==OP_VCMPSD) begin : g_vcmpsd
        if (W>=64) begin
          logic [3:0] cc; 
          floating_point_compare fp_cmp (
            .aclk(clk),
            .s_axis_a_tvalid(1'b1), .s_axis_a_tdata(a[63:0]),
            .s_axis_b_tvalid(1'b1), .s_axis_b_tdata(b[63:0]),
            .m_axis_result_tvalid(), .m_axis_result_tready(1'b1), .m_axis_result_tdata(cc)
          );
          wire lt = cc[0], eq = cc[1], gt = cc[2], un = cc[3];

          logic take;
          wire  [2:0] imm = c[2:0];
          always_comb begin
            unique case (imm)
              3'd0: take = eq;                 // EQ
              3'd1: take = lt;                 // LT
              3'd2: take = (lt|eq);            // LE
              3'd3: take = un;                 // UNORD
              3'd4: take = ~eq & ~un;          // NEQ(ordered and not equal)
              3'd5: take = ~lt & ~un;          // NLT
              3'd6: take = ~(lt|eq) & ~un;     // NLE
              3'd7: take = ~un;                // ORD
              default: take = 1'b0;
            endcase
          end
          always_ff @(posedge clk) begin
            y <= a;
            y[63:0] <= take ? 64'hFFFF_FFFF_FFFF_FFFF : 64'h0;
          end
        end else begin
          always_ff @(posedge clk) y <= a;
        end
      end

      // --- everything else in soft ---
      else begin : g_soft_only
        logic [W-1:0] y_comb;
        logic [7:0] sh_bytes;
        logic [2:0] lane;
        always_comb begin
          y_comb = '0;
          sh_bytes = '0;
          lane = '0;
          unique case (OP)
            // bitwise / basic
            OP_LEA   : y_comb = a + b;
            OP_TEST  : y_comb = a & b;
            OP_AND   : y_comb = a & b;
            OP_ANDN  : y_comb = a & ~b;
            OP_OR    : y_comb = a | b;
            OP_XOR   : y_comb = a ^ b;
            OP_NOT   : y_comb = ~a;

            OP_BLSI  : y_comb = a & (~a + 1);
            OP_BLSR  : y_comb = a & (a - 1);
            OP_BZHI  : begin int idx=b[$clog2(W)-1:0]; logic [W-1:0] m=(idx==0)?'0:(({W{1'b1}})>>(W-idx)); y_comb = a & m; end
            OP_BT    : y_comb = {{(W-1){1'b0}}, a[b[$clog2(W)-1:0]]};
            OP_TZCNT : y_comb = tzcount(a);

            OP_SHL, OP_SAL : y_comb = lshift(a, sh);
            OP_SHR         : y_comb = rshift(a, sh);
            OP_SAR         : y_comb = $signed(a) >>> sh;
            OP_SHRX        : y_comb = a >> sh;
            OP_SHLX        : y_comb = a << sh;
            OP_RORX        : y_comb = (sh=='0) ? a : ((a >> sh) | (a << (W - sh)));
            OP_SARX        : y_comb = $signed(a) >>> sh;

            // scalar extend helpers
            OP_MOVSX  : y_comb = {{(W-8){a[7]}},   a[7:0]};
            OP_MOVSXD : y_comb = {{(W-32){a[31]}}, a[31:0]};
            OP_MOVZX  : y_comb = {{(W-8){1'b0}},   a[7:0]};
            OP_CDQ    : y_comb = {{(W-32){a[31]}}, a[31:0]};
            OP_CDQE   : y_comb = {{(W-32){a[31]}}, a[31:0]};
            OP_CQO    : y_comb = {{(W-64){a[63]}}, a[63:0]};

            // soft single compare results (for *_ISS)
            OP_VCOMISS, OP_VUCOMISS: begin
              logic [1:0] bits;
              bits[0] = (a[31:0]==b[31:0]);
              bits[1] = ($bitstoshortreal(a[31:0]) < $bitstoshortreal(b[31:0]));
              y_comb = {{(W-2){1'b0}}, bits};
            end

            // simd logic
            OP_ANDPD, OP_ANDPS, OP_VANDPD, OP_VANDPS: y_comb = a & b;
            OP_VORPD, OP_VPOR                         : y_comb = a | b;
            OP_PXOR, OP_VPXOR, OP_VXORPD, OP_VXORPS  : y_comb = a ^ b;
            OP_VPAND                                  : y_comb = a & b;
            OP_VPANDN                                 : y_comb = (~a) & b;

            // simd add/sub/mul
            OP_VPADDD : y_comb = lane_add32(a,b);
            OP_VPADDQ : y_comb = lane_add64(a,b);
            OP_VPADDW : y_comb = lane_add16(a,b);
            OP_VPSUBD : y_comb = lane_sub32(a,b);
            OP_VPSUBW : y_comb = lane_sub16(a,b);
            OP_VPMULLD: y_comb = lane_mul32_lo(a,b);
            OP_VPAVGB : y_comb = lane_avgb8(a,b);

            // shifts
            OP_VPSLLD : y_comb = lane_shl32(a, sh[4:0]);
            OP_VPSLLQ : y_comb = lane_shl64(a, sh[5:0]);
            OP_VPSLLW : y_comb = lane_shl16(a, sh[3:0]);
            OP_VPSRLD : y_comb = lane_shr32(a, sh[4:0]);
            OP_VPSRLQ : y_comb = lane_shr64(a, sh[5:0]);
            OP_VPSRAD : y_comb = lane_sar32(a, sh[4:0]);
            OP_VPSRAW : y_comb = lane_sar16(a, sh[3:0]);

            // broadcast / blends (immediate mask via shamt)
            OP_VBROADCASTSD: y_comb = vbroadcast_elem(b, 64);
            OP_VBROADCASTSS: y_comb = vbroadcast_elem(b, 32);
            OP_VPBROADCASTB: y_comb = vbroadcast_elem(b, 8);
            OP_VPBROADCASTD: y_comb = vbroadcast_elem(b, 32);
            OP_VPBROADCASTW: y_comb = vbroadcast_elem(b, 16);

            OP_VPBLENDD: begin y_comb=a; for (int i=0;i<LANES32;i++) if (shamt[i]) y_comb[i*32 +:32] = b[i*32 +:32]; end
            OP_VPBLENDW: begin y_comb=a; for (int i=0;i<LANES16;i++) if (shamt[i]) y_comb[i*16 +:16] = b[i*16 +:16]; end
            OP_VBLENDPD: begin y_comb=a; for (int i=0;i<LANES64;i++) if (shamt[i]) y_comb[i*64 +:64] = b[i*64 +:64]; end

            // variable blend (mask from c MSB per 64b lane)
            OP_VBLENDVPD: begin
              for (int i=0;i<LANES64;i++) begin
                logic m = c[i*64 + 63];
                y_comb[i*64 +:64] = m ? b[i*64 +:64] : a[i*64 +:64];
              end
            end

            // insert/extract/misc
            OP_VPINSRB: begin y_comb=a; y_comb[{b[4:0],3'b0} +:8 ]  = c[7:0];  end
            OP_VPINSRD: begin y_comb=a; y_comb[{b[3:0],5'b0} +:32] = c[31:0]; end
            OP_VPINSRQ: begin y_comb=a; y_comb[{b[2:0],6'b0} +:64] = c[63:0]; end
            OP_VPEXTRD: y_comb = {{(W-32){1'b0}}, a[{b[3:0],5'b0} +:32]};
            OP_VPEXTRQ: y_comb = {{(W-64){1'b0}}, a[{b[2:0],6'b0} +:64]};
            OP_VINSERTPS: begin lane=c[1+:2]; y_comb=a; y_comb[lane*32 +:32] = b[31:0]; end

            // byte/word compares & masks
            OP_VPCMPEQB: for (int i=0;i<LANES8 ;i++) y_comb[i*8 +:8 ] = (a[i*8 +:8]==b[i*8 +:8]) ? 8'hFF : 8'h00;
            OP_VPCMPEQD: for (int i=0;i<LANES32;i++) y_comb[i*32+:32] = (a[i*32+:32]==b[i*32+:32]) ? 32'hFFFF_FFFF : 32'h0;
            OP_VPCMPGTD: for (int i=0;i<LANES32;i++) y_comb[i*32+:32] = ($signed(a[i*32+:32]) > $signed(b[i*32+:32])) ? 32'hFFFF_FFFF : 32'h0;
            OP_VPCMPGTW: for (int i=0;i<LANES16;i++) y_comb[i*16+:16] = ($signed(a[i*16+:16]) > $signed(b[i*16+:16])) ? 16'hFFFF : 16'h0;

            OP_VPMAXSD: for (int i=0;i<LANES32;i++) begin
              logic signed [31:0] x=a[i*32+:32], yv=b[i*32+:32];
              y_comb[i*32+:32] = (x>yv)?x:yv;
            end
            OP_VPMINUB: for (int i=0;i<LANES8;i++) begin
              logic [7:0] x=a[i*8+:8], yv=b[i*8+:8]; y_comb[i*8+:8] = (x<yv)?x:yv;
            end
            OP_VPMOVMSKB: for (int i=0;i<LANES8;i++) y_comb[i] = a[i*8+7];
            OP_VPTEST: begin logic zf=((a&b)=='0); logic cf=((a&~b)=='0); y_comb={{(W-2){1'b0}}, zf, cf}; end

            // data dup / shuffles
            OP_VMOVDDUP: begin
              y_comb = a;
              for (int blk=0; blk<(W/128); blk++) begin
                logic [63:0] lo = a[blk*128 +:64];
                y_comb[blk*128 +:64]      = lo;
                y_comb[blk*128 +64 +:64] = lo;
              end
            end
            OP_VMOVSHDUP: begin
              y_comb = a;
              for (int i=0;i<LANES64;i++) begin
                logic [31:0] hi = a[i*64 +32 +:32];
                y_comb[i*64 +:32]      = hi;
                y_comb[i*64 +32 +:32] = hi;
              end
            end
            OP_VMOVSLDUP: begin
              y_comb = a;
              for (int i=0;i<LANES64;i++) begin
                logic [31:0] lo = a[i*64 +:32];
                y_comb[i*64 +:32]      = lo;
                y_comb[i*64 +32 +:32] = lo;
              end
            end

            // 128b block ops
            OP_VPSADBW: begin
              y_comb = '0;
              for (int blk=0; blk<LANES128; blk++) begin
                logic [63:0] s0='0, s1='0;
                for (int j=0;j<8;j++) begin
                  logic [7:0] ax=a[blk*128 + j*8 +:8],  bx=b[blk*128 + j*8 +:8];
                  logic [7:0] ay=a[blk*128 +64 + j*8 +:8], by=b[blk*128 +64 + j*8 +:8];
                  s0 += (ax>bx)?(ax-bx):(bx-ax);
                  s1 += (ay>by)?(ay-by):(by-ay);
                end
                y_comb[blk*128       +:64] = s0;
                y_comb[blk*128 + 64 +:64] = s1;
              end
            end

            // mov mask ps (MSB of each 32b)
            OP_VMOVMSKPS: begin y_comb='0; for (int i=0;i<LANES32;i++) y_comb[i]=a[i*32+31]; end

            // zero/sign extend vectors
            OP_VPMOVZXBW: begin
              y_comb = a;
              for (int blk=0; blk<LANES128; blk++) begin
                logic [127:0] R='0;
                logic [127:0] X = a[blk*128 +:128];
                for (int i=0; i<(128/16); i++) begin
                  logic [7:0] v = X[i*8 +:8];
                  R[i*16 +:16] = {8'b0, v};
                end
                y_comb[blk*128 +:128] = R;
              end
            end
            OP_VPMOVZXWD: begin
              y_comb = a;
              for (int blk=0; blk<LANES128; blk++) begin
                logic [127:0] R='0;
                logic [127:0] X = a[blk*128 +:128];
                for (int i=0; i<(128/32); i++) begin
                  logic [15:0] v = X[i*16 +:16];
                  R[i*32 +:32] = {16'b0, v};
                end
                y_comb[blk*128 +:128] = R;
              end
            end
            OP_VPMOVSXWD: begin
              y_comb = a;
              for (int blk=0; blk<LANES128; blk++) begin
                logic [127:0] R='0;
                logic [127:0] X = a[blk*128 +:128];
                for (int i=0; i<(128/32); i++) begin
                  logic [15:0] v = X[i*16 +:16];
                  R[i*32 +:32] = {{16{v[15]}}, v};
                end
                y_comb[blk*128 +:128] = R;
              end
            end

            // dword shuffle (VPSHUFD)
            OP_VPSHUFD: begin
              if (W>=128) begin
                for (int blk=0; blk<(W/128); blk++) begin
                  logic [127:0] x = a[blk*128 +:128];
                  logic [7:0]   imm = b[7:0];
                  logic [31:0] s0, s1, s2, s3;
                  case (imm[1:0]) 2'd0: s0=x[ 31:  0]; 2'd1: s0=x[ 63: 32]; 2'd2: s0=x[ 95: 64]; default: s0=x[127: 96]; endcase
                  case (imm[3:2]) 2'd0: s1=x[ 31:  0]; 2'd1: s1=x[ 63: 32]; 2'd2: s1=x[ 95: 64]; default: s1=x[127: 96]; endcase
                  case (imm[5:4]) 2'd0: s2=x[ 31:  0]; 2'd1: s2=x[ 63: 32]; 2'd2: s2=x[ 95: 64]; default: s2=x[127: 96]; endcase
                  case (imm[7:6]) 2'd0: s3=x[ 31:  0]; 2'd1: s3=x[ 63: 32]; 2'd2: s3=x[ 95: 64]; default: s3=x[127: 96]; endcase
                  y_comb[blk*128 +:128] = {s3, s2, s1, s0};
                end
              end else y_comb = a;
            end

            // shift right logical by bytes per 128b
            OP_VPSRLDQ: begin
                if (W>=128) begin
                  y_comb = a; 
                  sh_bytes=b[7:0];
                  for (int blk=0; blk<(W/128); blk++) begin
                    logic [127:0] X=a[blk*128 +:128];
                    y_comb[blk*128 +:128] = (sh_bytes>=8'd16) ? '0 : (X >> (sh_bytes*8));
                  end
                end else y_comb = a;
            end

            // PD unpack-low
            OP_VUNPCKLPD: begin
              if (W>=128) begin
                for (int blk=0; blk<(W/128); blk++)
                  y_comb[blk*128 +:128] = { b[blk*128 +:64], a[blk*128 +:64] };
              end else y_comb = a;
            end

            OP_VSHUFPS: begin
              if (W>=128) begin
                logic [W-1:0] r='0; logic [7:0] imm = b[7:0];
                for (int blk=0; blk<(W/128); blk++) begin
                  logic [127:0] A = a[blk*128 +:128];
                  logic [127:0] C = c[blk*128 +:128];
                  logic [31:0] a0=A[ 31:  0], a1=A[ 63: 32], a2=A[ 95: 64], a3=A[127: 96];
                  logic [31:0] c0=C[ 31:  0], c1=C[ 63: 32], c2=C[ 95: 64], c3=C[127: 96];

                  logic [31:0] d0, d1, d2, d3;

                  case (imm[1:0])
                    2'd0: d0 = a0; 2'd1: d0 = a1; 2'd2: d0 = a2; default: d0 = a3;
                  endcase
                  case (imm[3:2])
                    2'd0: d1 = a0; 2'd1: d1 = a1; 2'd2: d1 = a2; default: d1 = a3;
                  endcase
                  case (imm[5:4])
                    2'd0: d2 = c0; 2'd1: d2 = c1; 2'd2: d2 = c2; default: d2 = c3;
                  endcase
                  case (imm[7:6])
                    2'd0: d3 = c0; 2'd1: d3 = c1; 2'd2: d3 = c2; default: d3 = c3;
                  endcase

                  r[blk*128 +:128] = {d3,d2,d1,d0};
                end
                y_comb = r;
              end else y_comb = a;
            end

            OP_VSHUFPD: begin
              if (W>=128) begin
                logic [W-1:0] r='0; logic [7:0] imm=b[7:0];
                for (int blk=0; blk<(W/128); blk++) begin
                  logic [63:0] a_lo=a[blk*128 +:64], a_hi=a[blk*128 +64 +:64];
                  logic [63:0] c_lo=c[blk*128 +:64], c_hi=c[blk*128 +64 +:64];
                  logic [63:0] lo = imm[0] ? a_hi : a_lo;
                  logic [63:0] hi = imm[1] ? c_hi : c_lo;
                  r[blk*128 +:128] = {hi, lo};
                end
                y_comb = r;
              end else y_comb = a;
            end

            OP_VUNPCKHPD: begin
              if (W>=128) begin
                for (int blk=0; blk<(W/128); blk++) begin
                  y_comb[blk*128 +:128] = { b[blk*128 +64 +:64], a[blk*128 +64 +:64] };
                end
              end else y_comb = a;
            end

            OP_VUNPCKLPS: begin
              if (W>=128) begin
                for (int blk=0; blk<(W/128); blk++) begin
                  logic [31:0] a0=a[blk*128 +  0 +:32];
                  logic [31:0] a1=a[blk*128 + 32 +:32];
                  logic [31:0] b0=b[blk*128 +  0 +:32];
                  logic [31:0] b1=b[blk*128 + 32 +:32];
                  // {b1, a1, b0, a0}
                  y_comb[blk*128 +:128] = { b1, a1, b0, a0 };
                end
              end else y_comb = a;
            end

            default: y_comb = a;
          endcase
        end
        always_ff @(posedge clk) y <= y_comb;
      end
    endgenerate
endmodule