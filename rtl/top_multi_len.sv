module top_multi_len #(
    parameter int W = 64,
    parameter int SPM_ADDR_W = 12
)(
    input  logic                   clk,
    input  logic                   rstn,
    input  logic [W-1:0]           src_val,
    input  logic [$clog2(W)-1:0]   shamt,
    output logic [W-1:0]           result,

    input  logic                   s_axis64_tvalid,
    output logic                   s_axis64_tready,
    input  logic [SPM_ADDR_W-1:0]  s_axis64_tuser_addr,
    input  logic [63:0]            s_axis64_tdata,

    input  logic                   s_axis32_tvalid,
    output logic                   s_axis32_tready,
    input  logic [SPM_ADDR_W-1:0]  s_axis32_tuser_addr,
    input  logic [31:0]            s_axis32_tdata
);
    import len_table_pkg::*;

`ifdef SPM_ADDR_W_OVERRIDE
    localparam int SPM_ADDR_W_EFF = `SPM_ADDR_W_OVERRIDE;
`else
    localparam int SPM_ADDR_W_EFF = SPM_ADDR_W;
`endif

    function logic [W-1:0] rotl(input logic [W-1:0] x, input int s_in);
      int s; logic [W-1:0] r;
      begin s = (W==0) ? 0 : (s_in % W); r = (s==0)? x : ((x<<s)|(x>>(W-s))); return r; end
    endfunction
    function logic [W-1:0] salt(input int idx);
      logic [W-1:0] r; logic [7:0] base; int bytes;
      begin
        base  = 8'hA5 ^ (byte'(idx) * 8'h1D);
        r     = '0; bytes = (W+7)/8;
        for (int k=0; k<bytes; k++) r[k*8 +: 8] = base ^ byte'(k);
        return r;
      end
    endfunction

    function automatic bit has_mem_case (int idx);
      int L; bit any;
      begin
        any = 1'b0; L = LEN_LUT[idx];
        for (int t = 0; t < L; t++) any |= (MEM_KIND_LUT[idx][t] != 2'd0);
        return any;
      end
    endfunction
    function automatic int count_mem_cases();
      int c; begin c=0; for (int i=0;i<N_CASE;i++) if (has_mem_case(i)) c++; return c; end
    endfunction
    function automatic int mem_index_of(input int idx);
      int c; begin c=0; for (int k=0;k<idx;k++) if (has_mem_case(k)) c++; return c; end
    endfunction

    localparam int N_MEM_RAW   = count_mem_cases();
    localparam bit HAS_ANY_MEM = (N_MEM_RAW > 0);

    localparam int SHW = (W>1) ? $clog2(W) : 1;
    wire [SHW-1:0] shamt_harden = shamt ^ src_val[SHW-1:0] ^ {{(SHW-1){1'b0}}, 1'b1};

    logic [W-1:0] y       [N_CASE];
    logic [W-1:0] y_mixed [N_CASE];

    if (!HAS_ANY_MEM) begin : g_no_mem
      assign s_axis64_tready = 1'b1;
      assign s_axis32_tready = 1'b1;

      for (genvar i = 0; i < N_CASE; i++) begin : glen_nomem
        localparam int  THIS_LEN  = LEN_LUT[i];
        localparam bit [THIS_LEN-1:0] THIS_MASK = FF_MASK_LUT[i][THIS_LEN-1:0];
        wire [W-1:0] c_per_case = rotl(src_val, i+1) ^ salt(i);

        uop_block_wrap #(
            .LEN        (THIS_LEN),
            .W          (W),
            .FF_MASK    (THIS_MASK),
            .OPS        (OPS_LUT     [i][0:THIS_LEN-1]),
            .IMM        (IMM_LUT     [i][0:THIS_LEN-1]),
            .USE_IMM    (USE_IMM_LUT [i][0:THIS_LEN-1]),
            .BW_ARR     (BW_LUT      [i][0:THIS_LEN-1]),
            .CONT_ARR   (CONT_W_LUT  [i][0:THIS_LEN-1]),
            .HAS_MEM    (1'b0),
            .ADDR_W     (SPM_ADDR_W_EFF),
            .MEM_KIND   (MEM_KIND_LUT[i][0:THIS_LEN-1])
        ) blk_i (
            .clk          (clk),
            .rstn         (rstn),
            .ce           (1'b1),
            .mb_ready_i   (1'b1),                
            .src_i        (src_val),
            .shamt_i      (shamt_harden),
            .c_i          (c_per_case),
            .dst_o        (y[i]),
            .mem_rdata_i  ('0),
            .mem_addr_o   (),
            .mem_wdata_o  (),
            .mem_we_o     (),
            .mem_req_now_o(),
            .mem_wsel_o   (),
            .store_v_o    (),
            .store_d_o    (),
            .take_store_i (1'b0)
        );

        localparam int MIX_SH = (W==0)?0:((i+1) % W);
        if (MIX_SH == 0) assign y_mixed[i] = y[i];
        else             assign y_mixed[i] = (y[i] << MIX_SH) | (y[i] >> (W - MIX_SH));
      end

    end else begin : g_has_mem
      localparam int TAGW_TAG = (N_MEM_RAW<=1)? 1 : $clog2(N_MEM_RAW);

      logic                        req_now_case [N_CASE];
      logic                        req_we_case  [N_CASE];
      logic                        req_wsel_case[N_CASE];
      logic [SPM_ADDR_W_EFF-1:0]   req_addr_case[N_CASE];
      logic                        store_v_case [N_CASE];
      logic [63:0]                 store_d_case [N_CASE];

      logic [N_MEM_RAW-1:0]                      req_now_m;
      logic [N_MEM_RAW-1:0]                      req_we_m;
      logic [N_MEM_RAW-1:0]                      req_wsel_m;
      logic [N_MEM_RAW-1:0][SPM_ADDR_W_EFF-1:0]  req_addr_m;
      logic [N_MEM_RAW-1:0][TAGW_TAG-1:0]        req_tag_m;
      logic [N_MEM_RAW-1:0]                      store_v_m;
      logic [N_MEM_RAW-1:0][63:0]                store_d_m;

      logic [N_MEM_RAW-1:0] mb_fire;
      logic [W-1:0]         mb_data [N_MEM_RAW];
      logic [N_MEM_RAW-1:0] mb_ready_vec;
      
      always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) mb_ready_vec <= '0;
        else       mb_ready_vec <= mb_fire;   
      end

      wire                         rd64A_vld, rd64B_vld;
      wire [TAGW_TAG-1:0]          rd64A_tag, rd64B_tag;
      wire [W-1:0]                 rd64A_data, rd64B_data;

      wire                         grant_vld;
      wire [TAGW_TAG-1:0]          grant_tag;
      wire                         store_take_vld;
      wire [TAGW_TAG-1:0]          store_take_tag;

      logic [N_CASE-1:0] ce_blk;

      for (genvar i = 0; i < N_CASE; i++) begin : glen_mem
        localparam int  THIS_LEN  = LEN_LUT[i];
        localparam bit [THIS_LEN-1:0] THIS_MASK = FF_MASK_LUT[i][THIS_LEN-1:0];
        localparam bit HAS_MEM_THIS = has_mem_case(i);
        localparam int MIDX2 = mem_index_of(i);

        wire [W-1:0] c_per_case = rotl(src_val, i+1) ^ salt(i);

        logic [W-1:0] membox_q;
        if (HAS_MEM_THIS) begin : g_mb
          always_ff @(posedge clk) begin
            if (mb_fire[MIDX2]) membox_q <= mb_data[MIDX2];
          end
        end else begin : g_mb_none
          always_comb membox_q = '0;
        end

        always_comb ce_blk[i] = (!HAS_MEM_THIS) ? 1'b1
                                 : ((!req_now_case[i]) ? 1'b1
                                    : (grant_vld && (grant_tag == TAGW_TAG'(MIDX2))));

        uop_block_wrap #(
            .LEN        (THIS_LEN),
            .W          (W),
            .FF_MASK    (THIS_MASK),
            .OPS        (OPS_LUT     [i][0:THIS_LEN-1]),
            .IMM        (IMM_LUT     [i][0:THIS_LEN-1]),
            .USE_IMM    (USE_IMM_LUT [i][0:THIS_LEN-1]),
            .BW_ARR     (BW_LUT      [i][0:THIS_LEN-1]),
            .CONT_ARR   (CONT_W_LUT  [i][0:THIS_LEN-1]),
            .HAS_MEM    (HAS_MEM_THIS),
            .ADDR_W     (SPM_ADDR_W_EFF),
            .MEM_KIND   (MEM_KIND_LUT[i][0:THIS_LEN-1])
        ) blk_i (
            .clk          (clk),
            .rstn         (rstn),
            .ce           (ce_blk[i]),
            .mb_ready_i   (HAS_MEM_THIS ? mb_ready_vec[MIDX2] : 1'b1),
            .src_i        (src_val),
            .shamt_i      (shamt_harden),
            .c_i          (c_per_case),
            .dst_o        (y[i]),

            .mem_rdata_i  (membox_q),
            .mem_addr_o   (req_addr_case[i]),
            .mem_wdata_o  (/* not used */),
            .mem_we_o     (req_we_case[i]),
            .mem_req_now_o(req_now_case[i]),
            .mem_wsel_o   (req_wsel_case[i]),

            .store_v_o    (store_v_case[i]),
            .store_d_o    (store_d_case[i]),
            .take_store_i (HAS_MEM_THIS ? (store_take_vld && (store_take_tag == TAGW_TAG'(MIDX2)))
                                        : 1'b0)
        );

        if (HAS_MEM_THIS) begin : g_pack
          assign req_now_m [MIDX2] = req_now_case [i];
          assign req_we_m  [MIDX2] = req_we_case  [i];
          assign req_wsel_m[MIDX2] = req_wsel_case[i];
          assign req_addr_m[MIDX2] = req_addr_case[i];
          assign req_tag_m [MIDX2] = TAGW_TAG'(MIDX2);
          assign store_v_m[MIDX2]  = store_v_case[i];
          assign store_d_m[MIDX2]  = store_d_case[i];
        end

        localparam int MIX_SH = (W==0)?0:((i+1) % W);
        if (MIX_SH == 0) assign y_mixed[i] = y[i];
        else             assign y_mixed[i] = (y[i] << MIX_SH) | (y[i] >> (W - MIX_SH));
      end

      spm_pool #(
          .N          (N_MEM_RAW),
          .ADDR_W     (SPM_ADDR_W_EFF),
          .W          (W),
          .USE_SPM64  (1'b1),
          .DMA_FIFO_DEPTH_64 (256),
          .DMA_FIFO_DEPTH_32 (256),
          .DMA_EN     (1'b0),
          .NBANKS     (8),
          .RLAT       (2),
          .TILE       (8),
          .TAGW       (TAGW_TAG)
      ) u_pool (
          .clk          (clk),
          .rstn         (rstn),
          .req_now      (req_now_m),
          .req_we       (req_we_m),
          .req_wsel     (req_wsel_m),
          .req_addr     (req_addr_m),
          .req_tag      (req_tag_m),
          .store_v      (store_v_m),
          .store_d      (store_d_m),
          .grant_vld      (grant_vld),
          .grant_tag      (grant_tag),
          .store_take_vld (store_take_vld),
          .store_take_tag (store_take_tag),
          .rd64A_vld(rd64A_vld), .rd64A_tag(rd64A_tag), .rd64A_data(rd64A_data),
          .rd64B_vld(rd64B_vld), .rd64B_tag(rd64B_tag), .rd64B_data(rd64B_data),
          .s_axis64_tvalid (s_axis64_tvalid),
          .s_axis64_tready (s_axis64_tready),
          .s_axis64_tuser_addr (s_axis64_tuser_addr),
          .s_axis64_tdata  (s_axis64_tdata),
          .s_axis32_tvalid (s_axis32_tvalid),
          .s_axis32_tready (s_axis32_tready),
          .s_axis32_tuser_addr (s_axis32_tuser_addr),
          .s_axis32_tdata  (s_axis32_tdata)
      );

      localparam int RET_GRP = 16;
      localparam int RET_NG  = (N_MEM_RAW + RET_GRP - 1) / RET_GRP;

      logic [N_MEM_RAW-1:0] a_hit_oh, b_hit_oh;
      for (genvar i2=0; i2<N_MEM_RAW; i2++) begin
        assign a_hit_oh[i2] = rd64A_vld && (rd64A_tag == TAGW_TAG'(i2));
        assign b_hit_oh[i2] = rd64B_vld && (rd64B_tag == TAGW_TAG'(i2));
      end

      logic [RET_NG-1:0] a_grp_sel, b_grp_sel;
      for (genvar g0=0; g0<RET_NG; g0++) begin : g_grp_sel
        localparam int BASE = g0*RET_GRP;
        always_comb begin
          a_grp_sel[g0] = 1'b0; b_grp_sel[g0] = 1'b0;
          for (int j=0; j<RET_GRP; j++) if (BASE+j < N_MEM_RAW) begin
            a_grp_sel[g0] |= a_hit_oh[BASE+j];
            b_grp_sel[g0] |= b_hit_oh[BASE+j];
          end
        end
      end

      logic [W-1:0] a_data_grp_q [RET_NG];
      logic [W-1:0] b_data_grp_q [RET_NG];
      always_ff @(posedge clk) begin
        for (int g1=0; g1<RET_NG; g1++) begin
          if (a_grp_sel[g1]) a_data_grp_q[g1] <= rd64A_data;
          if (b_grp_sel[g1]) b_data_grp_q[g1] <= rd64B_data;
        end
      end

      logic [N_MEM_RAW-1:0] a_hit_oh_q, b_hit_oh_q;
      always_ff @(posedge clk) begin
        a_hit_oh_q <= a_hit_oh;
        b_hit_oh_q <= b_hit_oh;
      end

      for (genvar i3=0; i3<N_MEM_RAW; i3++) begin : g_demux
        localparam int GID = i3 / RET_GRP;
        always_comb begin
          mb_fire[i3] = a_hit_oh_q[i3] | b_hit_oh_q[i3];
          mb_data[i3] = a_hit_oh_q[i3] ? a_data_grp_q[GID] : b_data_grp_q[GID];
        end
      end
    end

    localparam int GG  = 8;
    localparam int NGG = (N_CASE + GG - 1) / GG;

    logic [W-1:0] part[NGG];
    for (genvar g2 = 0; g2 < NGG; g2++) begin : g_grp
      logic [W-1:0] acc;
      always_comb begin
        acc = '0;
        for (int j=0; j<GG; j++) begin
          if ((g2*GG + j) < N_CASE) acc ^= y_mixed[g2*GG + j];
        end
        part[g2] = acc;
      end
    end

    logic [W-1:0] part_q[NGG];
    always_ff @(posedge clk) begin
      for (int gi=0; gi<NGG; gi++) part_q[gi] <= part[gi];
    end

    logic [W-1:0] result_r;
    always_comb begin
      result_r = '0;
      for (int k=0; k<NGG; k++) result_r ^= part_q[k];
    end
    assign result = result_r;
endmodule
