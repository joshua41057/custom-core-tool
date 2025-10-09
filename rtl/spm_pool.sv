(* keep_hierarchy = "yes" *)
module rr_arbiter #(
  parameter int N = 8
)(
  input  logic         clk,
  input  logic         rstn,
  input  logic [N-1:0] req,
  input  logic [N-1:0] mask_off,
  output logic [N-1:0] grant
);
  if (N == 1) begin : g_n1
    always_ff @(posedge clk or negedge rstn) begin
      if (!rstn) grant <= 1'b0;
      else       grant <= req & ~mask_off;
    end
  end else begin : g_n

    logic [N-1:0] ptr_oh_q, ptr_oh_s1;
    logic [N-1:0] req_eff_s0;
    assign req_eff_s0 = req & ~mask_off;

    logic [N-1:0] rol_tbl [0:N-1];
    genvar k;
    for (k=0; k<N; k++) begin : g_rol
      if (k == 0) begin
        assign rol_tbl[k] = req_eff_s0;
      end else begin
        assign rol_tbl[k] = {req_eff_s0[N-1-k:0], req_eff_s0[N-1 -: k]};
      end
    end

    logic [N-1:0] req_rot_s0;
    always_comb begin
      req_rot_s0 = '0;
      for (int i=0; i<N; i++) begin
        req_rot_s0 |= ({N{ptr_oh_q[i]}} & rol_tbl[i]);
      end
    end

    localparam logic [N-1:0] ONE_N = {{(N-1){1'b0}},1'b1};
    logic [N-1:0] pick_rot_s0, pick_rot_s1;
    logic [N:0] tmp_add;
    assign tmp_add    = {1'b0, ~req_rot_s0} + {1'b0, ONE_N};
    assign pick_rot_s0= req_rot_s0 & tmp_add[N-1:0];

    always_ff @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        pick_rot_s1 <= '0;
        ptr_oh_s1   <= 'b1;   // bit0=1
      end else begin
        pick_rot_s1 <= pick_rot_s0;
        ptr_oh_s1   <= ptr_oh_q;
      end
    end

    logic [N-1:0] ror_tbl [0:N-1];
    for (k=0; k<N; k++) begin : g_ror
      if (k == 0) begin
        assign ror_tbl[k] = pick_rot_s1;
      end else begin
        assign ror_tbl[k] = {pick_rot_s1[k-1:0], pick_rot_s1[N-1:k]};
      end
    end

    logic [N-1:0] grant_w;
    always_comb begin
      grant_w = '0;
      for (int i=0; i<N; i++) begin
        grant_w |= ({N{ptr_oh_s1[i]}} & ror_tbl[i]);
      end
    end
    assign grant = grant_w;

    always_ff @(posedge clk or negedge rstn) begin
      if (!rstn) begin
        ptr_oh_q <= 'b1; 
      end else if (|grant_w) begin
        ptr_oh_q <= {grant_w[N-2:0], grant_w[N-1]};
      end
    end
  end
endmodule



module bram_fifo_sync #(
  parameter int WIDTH = 128,
  parameter int DEPTH = 512
)(
  input  logic             clk,
  input  logic             rstn,
  input  logic             wr_en,
  input  logic [WIDTH-1:0] din,
  output logic             full,
  input  logic             rd_en,
  output logic [WIDTH-1:0] dout,
  output logic             empty
);
  xpm_fifo_sync #(
    .FIFO_MEMORY_TYPE     ("block"),
    .FIFO_READ_LATENCY    (0),
    .ECC_MODE             ("no_ecc"),
    .DOUT_RESET_VALUE     ("0"),
    .USE_ADV_FEATURES     ("1707"),
    .READ_DATA_WIDTH      (WIDTH),
    .WRITE_DATA_WIDTH     (WIDTH),
    .FIFO_WRITE_DEPTH     (DEPTH)
  ) xpm_fifo_i (
    .sleep          (1'b0),
    .rst            (~rstn),
    .wr_clk         (clk),
    .wr_en          (wr_en),
    .din            (din),
    .full           (full),
    .wr_rst_busy    (),
    .rd_en          (rd_en),
    .dout           (dout),
    .empty          (empty),
    .data_valid     (),
    .rd_rst_busy    (),
    .prog_full      (),
    .prog_empty     (),
    .overflow       (),
    .underflow      (),
    .wr_data_count  (),
    .rd_data_count  (),
    .almost_full    (),
    .almost_empty   ()
  );
endmodule


(* keep_hierarchy = "yes" *)
module spm_bank #(
  parameter int ADDR_W = 10,
  parameter int W      = 64,
  parameter int RLAT   = 2
)(
  input  logic               clk,
  input  logic               rstn,
  input  logic               we,
  input  logic [ADDR_W-1:0]  waddr,
  input  logic [(W/8)-1:0]   wbe,
  input  logic [W-1:0]       wdata,
  input  logic               re,
  input  logic [ADDR_W-1:0]  raddr,
  output logic               rvalid,
  output logic [W-1:0]       rdata
);
  logic [(W/8)-1:0] wea_bus;
  always_comb begin
    wea_bus = '0;
    for (int i = 0; i < (W/8); i++) wea_bus[i] = we & wbe[i];
  end

  generate
    if (RLAT > 0) begin : g_lat
      logic [RLAT-1:0] vpipe;
      always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) vpipe <= '0;
        else begin
          vpipe[0] <= re;
          for (int i=1;i<RLAT;i++) vpipe[i] <= vpipe[i-1];
        end
      end
      assign rvalid = vpipe[RLAT-1];
    end else begin : g_lat0
      assign rvalid = re;
    end
  endgenerate

  xpm_memory_sdpram #(
    .MEMORY_PRIMITIVE   ("block"),
    .CLOCKING_MODE      ("common_clock"),
    .MEMORY_SIZE        ((1<<ADDR_W)*W),
    .ADDR_WIDTH_A       (ADDR_W),
    .ADDR_WIDTH_B       (ADDR_W),
    .READ_DATA_WIDTH_B  (W),
    .WRITE_DATA_WIDTH_A (W),
    .BYTE_WRITE_WIDTH_A (8),
    .READ_LATENCY_B     (RLAT),
    .ECC_MODE           ("no_ecc"),
    .WRITE_MODE_B       ("no_change")
  ) u_mem (
    .clka   (clk), .ena(1'b1), .wea(wea_bus), .addra(waddr), .dina(wdata),
    .clkb   (clk), .enb(1'b1), .addrb(raddr), .doutb(rdata),
    .rstb   (1'b0), .regceb(1'b1),
    .sleep  (1'b0),
    .injectsbiterra(1'b0), .injectdbiterra(1'b0),
    .sbiterrb(),
    .dbiterrb()
  );
endmodule


(* keep_hierarchy = "yes" *)
module spm_pool #(
    parameter int N       = 1,
    parameter int ADDR_W  = 12,
    parameter int W       = 64,

    parameter bit USE_SPM64 = 1'b1,

    parameter int DMA_FIFO_DEPTH_64 = 256,
    parameter int DMA_FIFO_DEPTH_32 = 256,
    parameter bit DMA_EN  = 1'b0,

    parameter int NBANKS  = 8,
    parameter int RLAT    = 2,
    parameter int TILE    = 8,

    parameter int TAGW    = 8
)(
    input  logic                        clk,
    input  logic                        rstn,

    input  logic [N-1:0]                req_now,
    input  logic [N-1:0]                req_we,
    input  logic [N-1:0]                req_wsel,
    input  logic [N-1:0][ADDR_W-1:0]    req_addr,
    input  logic [N-1:0][TAGW-1:0]      req_tag,

    input  logic [N-1:0]                store_v,
    input  logic [N-1:0][63:0]          store_d,

    output logic                        grant_vld,
    output logic [TAGW-1:0]             grant_tag,
    output logic                        store_take_vld,
    output logic [TAGW-1:0]             store_take_tag,

    output logic                        rd64A_vld,
    output logic [TAGW-1:0]             rd64A_tag,
    output logic [W-1:0]                rd64A_data,
    output logic                        rd64B_vld,
    output logic [TAGW-1:0]             rd64B_tag,
    output logic [W-1:0]                rd64B_data,

    input  logic                        s_axis64_tvalid,
    output logic                        s_axis64_tready,
    input  logic [ADDR_W-1:0]           s_axis64_tuser_addr,
    input  logic [63:0]                 s_axis64_tdata,

    input  logic                        s_axis32_tvalid,
    output logic                        s_axis32_tready,
    input  logic [ADDR_W-1:0]           s_axis32_tuser_addr,
    input  logic [31:0]                 s_axis32_tdata
);

  localparam int BK_BITS  = (NBANKS<=1)? 0 : $clog2(NBANKS);
  localparam int ADDR_W_B = (ADDR_W>BK_BITS) ? (ADDR_W-BK_BITS) : 1;
  localparam int ROW_W64   = (ADDR_W_B>1) ? (ADDR_W_B-1) : 1;

  function automatic logic [BK_BITS-1:0] bank_of(input logic [ADDR_W-1:0] a);
    if (BK_BITS==0)               return '0;
    else if (ADDR_W >= BK_BITS)   return a[BK_BITS-1:0];
    else                          return {{(BK_BITS-ADDR_W){1'b0}}, a};
  endfunction
  function automatic logic [ADDR_W_B-1:0] row_full_of(input logic [ADDR_W-1:0] a);
    if (ADDR_W > BK_BITS) return a[ADDR_W-1:BK_BITS];
    else                   return '0; 
  endfunction
  function automatic logic [ROW_W64-1:0] row64_of(input logic [ADDR_W_B-1:0] rf);
    if (ADDR_W_B==1) return '0; else return rf[ADDR_W_B-1:1];
  endfunction
  function automatic logic half_of32(input logic [ADDR_W_B-1:0] rf);
    return rf[0];
  endfunction

  localparam int FIFO64_W = ADDR_W + 64;
  localparam int FIFO32_W = ADDR_W + 32;
  logic                    fifo64_full, fifo64_empty, fifo64_rd, fifo64_wr;
  logic [FIFO64_W-1:0]     fifo64_dout, fifo64_din;
  logic                    fifo32_full, fifo32_empty, fifo32_rd, fifo32_wr;
  logic [FIFO32_W-1:0]     fifo32_dout, fifo32_din;

  generate
    if (DMA_EN) begin : g_dma
      assign fifo64_din      = {s_axis64_tuser_addr, s_axis64_tdata};
      assign fifo64_wr       = s_axis64_tvalid & s_axis64_tready;
      assign s_axis64_tready = ~fifo64_full;

      assign fifo32_din      = {s_axis32_tuser_addr, s_axis32_tdata};
      assign fifo32_wr       = s_axis32_tvalid & s_axis32_tready;
      assign s_axis32_tready = ~fifo32_full;

      bram_fifo_sync #(.WIDTH(FIFO64_W), .DEPTH(DMA_FIFO_DEPTH_64)) u_fifo64 (
        .clk(clk), .rstn(rstn), .wr_en(fifo64_wr), .din(fifo64_din), .full(fifo64_full),
        .rd_en(fifo64_rd), .dout(fifo64_dout), .empty(fifo64_empty)
      );
      bram_fifo_sync #(.WIDTH(FIFO32_W), .DEPTH(DMA_FIFO_DEPTH_32)) u_fifo32 (
        .clk(clk), .rstn(rstn), .wr_en(fifo32_wr), .din(fifo32_din), .full(fifo32_full),
        .rd_en(fifo32_rd), .dout(fifo32_dout), .empty(fifo32_empty)
      );
    end else begin : g_no_dma
      assign s_axis64_tready = 1'b1; assign s_axis32_tready = 1'b1;
      assign fifo64_empty    = 1'b1; assign fifo64_full     = 1'b0;
      assign fifo32_empty    = 1'b1; assign fifo32_full     = 1'b0;
      assign fifo64_dout     = '0;   assign fifo32_dout     = '0;
      assign fifo64_rd       = 1'b0; assign fifo32_rd       = 1'b0;
    end
  endgenerate

  typedef struct packed { logic vld; logic [ROW_W64-1:0] addr; logic [7:0] be; logic [63:0] wdata; } wr64_t;
  typedef struct packed { logic vld; logic [ROW_W64-1:0] addr; logic [TAGW-1:0] tag; logic is32; logic half32; } rd_t;

  wr64_t wr_q [NBANKS];
  rd_t   rd_q [NBANKS];

  logic            pend_v   [NBANKS];
  logic [TAGW-1:0] pend_tag [NBANKS];
  logic            pend_is32[NBANKS];
  logic            pend_half[NBANKS];

  logic            b_rvalid [NBANKS];
  logic [63:0]     b_rdata  [NBANKS];

  logic            st_v     [NBANKS];
  logic [63:0]     st_d     [NBANKS];
  logic [TAGW-1:0] st_t     [NBANKS];
  logic            st_is32  [NBANKS];
  logic            st_half  [NBANKS];

  logic [NBANKS-1:0] gA, gB;
  logic [NBANKS-1:0] gA_q;

  generate
    if (USE_SPM64) begin : g_banks
      for (genvar b=0; b<NBANKS; b++) begin : gb
        spm_bank #(.ADDR_W(ROW_W64), .W(64), .RLAT(RLAT)) u_bank64 (
          .clk(clk), .rstn(rstn),
          .we    (wr_q[b].vld), .waddr(wr_q[b].addr), .wbe(wr_q[b].be), .wdata(wr_q[b].wdata),
          .re    (rd_q[b].vld), .raddr(rd_q[b].addr),
          .rvalid(b_rvalid[b]), .rdata(b_rdata[b])
        );
        always_ff @(posedge clk or negedge rstn) begin
          if (!rstn) begin
            st_v[b] <= 1'b0;
          end else begin
            if (b_rvalid[b]) begin
              st_d[b]    <= b_rdata[b];
              st_t[b]    <= pend_tag [b];
              st_is32[b] <= pend_is32[b];
              st_half[b] <= pend_half[b];
              st_v  [b]  <= 1'b1;
            end
            if (gA[b] || gB[b]) st_v[b] <= 1'b0;
          end
        end
      end
    end
  endgenerate

  localparam int GPW   = (N<=1)?1:$clog2(N);
  localparam int TPW   = (TILE<=1)?1:$clog2(TILE);
  localparam int NG    = (N + TILE - 1) / TILE;
  localparam int GPW_G = (NG<=1)?1:$clog2(NG);

  logic [GPW-1:0] grp_ptr;

  logic [TPW-1:0]   loc;
  logic [GPW_G-1:0] gidx;
  generate
    if (TPW > GPW) begin : g_ptr_tpwgpw
      always_comb begin
        loc  = '0;
        loc[GPW-1:0] = grp_ptr;
        gidx = '0;
      end
    end else if (TPW == GPW) begin : g_ptr_eq
      always_comb begin
        loc  = grp_ptr;
        gidx = '0;
      end
    end else begin : g_ptr_lt
      always_comb begin
        loc  = grp_ptr[TPW-1:0];
        gidx = grp_ptr[GPW-1:TPW];
      end
    end
  endgenerate

  logic [TILE-1:0]  loc_oh;
  logic [NG-1:0]    gidx_oh;
  always_comb begin
    for (int j=0; j<TILE; j++)    loc_oh [j] = (loc  == TPW'(j));
    for (int g=0; g<NG;   g++)    gidx_oh[g] = (gidx == GPW_G'(g));
  end

  typedef struct packed {
    logic now, we, sel64;
    logic [ADDR_W-1:0] addr;
    logic              stv;
    logic [63:0]       std;
    logic [TAGW-1:0]   tag;
  } cur_t;

  cur_t group_pick [NG];

  generate
    for (genvar g=0; g<NG; g++) begin : g_pick
      localparam int BASE = g*TILE;
      always_comb begin
        group_pick[g] = '0;
        for (int j=0; j<TILE; j++) begin
          if (BASE + j < N && loc_oh[j]) begin
            group_pick[g].now   = req_now [BASE + j];
            group_pick[g].we    = req_we  [BASE + j];
            group_pick[g].sel64 = req_wsel[BASE + j];
            group_pick[g].addr  = req_addr[BASE + j];
            group_pick[g].stv   = store_v [BASE + j];
            group_pick[g].std   = store_d [BASE + j];
            group_pick[g].tag   = req_tag [BASE + j];
          end
        end
      end
    end
  endgenerate

  cur_t cur_comb, cur_q;
  always_comb begin
    cur_comb = '0;
    for (int g=0; g<NG; g++) if (gidx_oh[g]) cur_comb = group_pick[g];
  end


  logic [NBANKS-1:0] bank_ready;
  generate
    for (genvar b=0;b<NBANKS;b++) begin
      assign bank_ready[b] = ~pend_v[b] & ~st_v[b];
    end
  endgenerate

  logic [NBANKS-1:0] rreq_pre;
  always_comb begin
    for (int b=0;b<NBANKS;b++) rreq_pre[b] = st_v[b];
  end

  logic [NBANKS-1:0] rreq_q, rreq_q_d1;
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      rreq_q     <= '0;
      rreq_q_d1  <= '0;
    end else begin
      rreq_q     <= rreq_pre; 
      rreq_q_d1  <= rreq_q;  
    end
  end

  rr_arbiter #(.N(NBANKS)) u_rrA(.clk(clk), .rstn(rstn), .req(rreq_q),    .mask_off('0),  .grant(gA));
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) gA_q <= '0; else gA_q <= gA;
  end
  rr_arbiter #(.N(NBANKS)) u_rrB(.clk(clk), .rstn(rstn), .req(rreq_q_d1), .mask_off(gA_q), .grant(gB));

  function automatic int unsigned enc1h(input logic [NBANKS-1:0] oh);
    int j; begin enc1h = 0; for (j=0;j<NBANKS;j++) if (oh[j]) enc1h = j; end
  endfunction

  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      grp_ptr <= '0;
      grant_vld <= 1'b0; grant_tag <= '0;
      store_take_vld <= 1'b0; store_take_tag <= '0;
      fifo64_rd <= 1'b0; fifo32_rd <= 1'b0;
      for (int b=0;b<NBANKS;b++) begin
        wr_q[b] <= '{default:'0}; rd_q[b] <= '{default:'0};
        pend_v[b] <= 1'b0; pend_tag[b] <= '0; pend_is32[b] <= 1'b0; pend_half[b] <= 1'b0;
      end
      cur_q <= '0;
    end else begin
      grp_ptr <= (grp_ptr == GPW'(N-1)) ? '0 : (grp_ptr + GPW'(1));
      cur_q   <= cur_comb;

      grant_vld <= 1'b0; store_take_vld <= 1'b0;
      fifo64_rd <= 1'b0; fifo32_rd <= 1'b0;
      for (int b=0;b<NBANKS;b++) begin
        wr_q[b].vld <= 1'b0; rd_q[b].vld <= 1'b0;
      end

      if (DMA_EN && USE_SPM64 && !fifo64_empty) begin
        logic [ADDR_W-1:0]     a   = fifo64_dout[FIFO64_W-1 -: ADDR_W];
        logic [BK_BITS-1:0]    bk  = bank_of(a);
        logic [ADDR_W_B-1:0]   rf  = row_full_of(a);
        logic [ROW_W64-1:0]    r64 = row64_of(rf);
        if (!wr_q[bk].vld) begin
          wr_q[bk] <= '{vld:1'b1, addr:r64, be:8'hFF, wdata:fifo64_dout[63:0]};
          fifo64_rd <= 1'b1;
        end
      end
      if (DMA_EN && USE_SPM64 && !fifo32_empty) begin
        logic [ADDR_W-1:0]     a   = fifo32_dout[FIFO32_W-1 -: ADDR_W];
        logic [BK_BITS-1:0]    bk  = bank_of(a);
        logic [ADDR_W_B-1:0]   rf  = row_full_of(a);
        logic [ROW_W64-1:0]    r64 = row64_of(rf);
        logic                  hf  = half_of32(rf);
        if (!wr_q[bk].vld) begin
          wr_q[bk].vld  <= 1'b1;
          wr_q[bk].addr <= r64;
          wr_q[bk].be   <= hf ? 8'hF0 : 8'h0F;
          wr_q[bk].wdata<= {2{fifo32_dout[31:0]}};
          fifo32_rd     <= 1'b1;
        end
      end

      if (cur_q.now) begin
        logic [BK_BITS-1:0]    bk;
        logic [ADDR_W_B-1:0]   rf;
        logic [ROW_W64-1:0]    r64;
        logic                  hf;

        bk  = bank_of    (cur_q.addr);
        rf  = row_full_of(cur_q.addr);
        r64 = row64_of   (rf);
        hf  = half_of32  (rf);

        if (cur_q.sel64) begin
          if (cur_q.we) begin
            if (cur_q.stv && !wr_q[bk].vld) begin
              wr_q[bk]      <= '{vld:1'b1, addr:r64, be:8'hFF, wdata:cur_q.std};
              grant_vld      <= 1'b1; grant_tag <= cur_q.tag;
              store_take_vld <= 1'b1; store_take_tag <= cur_q.tag;
            end
          end else begin
            if (bank_ready[bk] && !rd_q[bk].vld) begin
              rd_q[bk]     <= '{vld:1'b1, addr:r64, tag:cur_q.tag, is32:1'b0, half32:1'b0};
              pend_v[bk]   <= 1'b1; pend_tag[bk] <= cur_q.tag; pend_is32[bk] <= 1'b0; pend_half[bk] <= 1'b0;
              grant_vld    <= 1'b1; grant_tag    <= cur_q.tag;
            end
          end
        end else begin
          if (cur_q.we) begin
            if (cur_q.stv && !wr_q[bk].vld) begin
              wr_q[bk].vld   <= 1'b1;
              wr_q[bk].addr  <= r64;
              wr_q[bk].be    <= hf ? 8'hF0 : 8'h0F;
              wr_q[bk].wdata <= {2{cur_q.std[31:0]}};
              grant_vld      <= 1'b1; grant_tag <= cur_q.tag;
              store_take_vld <= 1'b1; store_take_tag <= cur_q.tag;
            end
          end else begin
            if (bank_ready[bk] && !rd_q[bk].vld) begin
              rd_q[bk]     <= '{vld:1'b1, addr:r64, tag:cur_q.tag, is32:1'b1, half32:hf};
              pend_v[bk]   <= 1'b1; pend_tag[bk] <= cur_q.tag; pend_is32[bk] <= 1'b1; pend_half[bk] <= hf;
              grant_vld    <= 1'b1; grant_tag    <= cur_q.tag;
            end
          end
        end
      end

      for (int b=0;b<NBANKS;b++) begin
        if (b_rvalid[b]) pend_v[b] <= 1'b0;
      end
    end
  end


  // A
  logic [NBANKS-1:0]           a_sel_oh, b_sel_oh;
  assign a_sel_oh = gA;
  assign b_sel_oh = gB;

  localparam int CL = (NBANKS < 4) ? NBANKS : 4;
  localparam int NC = (NBANKS + CL - 1) / CL;

  logic [NC-1:0]   a_sel_c,  b_sel_c;
  logic [TAGW-1:0] tagA_c [NC], tagB_c [NC];
  logic [63:0]     dataA_c[NC], dataB_c[NC];
  logic            is32A_c[NC], is32B_c[NC];
  logic            halfA_c[NC], halfB_c[NC];

  genvar c;
  for (c=0; c<NC; c++) begin : g_cluster
    localparam int BASE = c*CL;
    always_comb begin
      a_sel_c[c] = 1'b0;  b_sel_c[c] = 1'b0;

      tagA_c[c]  = '0;    dataA_c[c]  = '0;    is32A_c[c] = 1'b0; halfA_c[c] = 1'b0;
      tagB_c[c]  = '0;    dataB_c[c]  = '0;    is32B_c[c] = 1'b0; halfB_c[c] = 1'b0;

      for (int k=0; k<CL; k++) if (BASE+k < NBANKS) begin
        if (a_sel_oh[BASE+k]) begin
          a_sel_c[c] = 1'b1;
          tagA_c[c]  = st_t   [BASE+k];
          dataA_c[c] = st_d   [BASE+k];
          is32A_c[c] = st_is32[BASE+k];
          halfA_c[c] = st_half[BASE+k];
        end
        if (b_sel_oh[BASE+k]) begin
          b_sel_c[c] = 1'b1;
          tagB_c[c]  = st_t   [BASE+k];
          dataB_c[c] = st_d   [BASE+k];
          is32B_c[c] = st_is32[BASE+k];
          halfB_c[c] = st_half[BASE+k];
        end
      end
    end
  end

  logic [TAGW-1:0] tagA_or, tagB_or;
  logic [63:0]     dataA_or, dataB_or;
  logic            is32A_or, is32B_or;
  logic            halfA_or, halfB_or;

  always_comb begin
    tagA_or='0; dataA_or='0; is32A_or=1'b0; halfA_or=1'b0;
    tagB_or='0; dataB_or='0; is32B_or=1'b0; halfB_or=1'b0;

    for (int i=0; i<NC; i++) begin
      if (a_sel_c[i]) begin
        tagA_or  = tagA_c [i];
        dataA_or = dataA_c[i];
        is32A_or = is32A_c[i];
        halfA_or = halfA_c[i];
      end
      if (b_sel_c[i]) begin
        tagB_or  = tagB_c [i];
        dataB_or = dataB_c[i];
        is32B_or = is32B_c[i];
        halfB_or = halfB_c[i];
      end
    end
  end

  function automatic logic [W-1:0] pack_to_W(input logic is32, input logic half, input logic [63:0] d);
    logic [31:0] d32;
    begin
      d32 = half ? d[63:32] : d[31:0];
      if (W >= 64) pack_to_W = is32 ? {{(W-32){1'b0}}, d32} : {{(W-64){1'b0}}, d};
      else         pack_to_W = is32 ? d32[W-1:0]             : d[W-1:0];
    end
  endfunction

  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      rd64A_vld  <= 1'b0; rd64A_tag <= '0; rd64A_data <= '0;
      rd64B_vld  <= 1'b0; rd64B_tag <= '0; rd64B_data <= '0;
    end else begin
      rd64A_vld  <= |a_sel_oh;
      rd64A_tag  <= tagA_or;
      rd64A_data <= pack_to_W(is32A_or, halfA_or, dataA_or);

      rd64B_vld  <= |b_sel_oh; 
      rd64B_tag  <= tagB_or;
      rd64B_data <= pack_to_W(is32B_or, halfB_or, dataB_or);
    end
  end
endmodule
