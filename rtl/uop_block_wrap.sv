module uop_block_wrap #(
    parameter int               LEN         = 1,
    parameter int               W           = 64,
    parameter bit [LEN-1:0]     FF_MASK     = '{default:1'b0},
    parameter bit               OUT_FF      = 1'b1,
    parameter uop_pkg::op_t     OPS [0:LEN-1] = '{default:uop_pkg::OP_NOP},
    parameter logic [31:0]      IMM [LEN]     = '{default:32'h0},
    parameter logic             USE_IMM[LEN]  = '{default:1'b0},
    parameter int               BW_ARR[LEN]   = '{default:W},
    parameter int               CONT_ARR[LEN] = '{default:0},
    parameter bit               HAS_MEM       = 1'b1,
    parameter int               ADDR_W        = 12,
    parameter logic [1:0]       MEM_KIND [0:LEN-1] = '{default:2'd0}
)(
    input  logic                   clk,
    input  logic                   rstn,
    input  logic                   ce,
    input  logic                   mb_ready_i, 
    input  logic [W-1:0]           src_i,
    input  logic [$clog2(W)-1:0]   shamt_i,
    input  logic [W-1:0]           c_i,
    output logic [W-1:0]           dst_o,

    input  logic [W-1:0]           mem_rdata_i,
    output logic [ADDR_W-1:0]      mem_addr_o,
    output logic [W-1:0]           mem_wdata_o,
    output logic                   mem_we_o,
    output logic                   mem_req_now_o,
    output logic                   mem_wsel_o,

    output logic                   store_v_o,
    output logic [63:0]            store_d_o,
    input  logic                   take_store_i
);
  logic [W-1:0] src_q, c_q; 
  logic [$clog2(W)-1:0] shamt_q;
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      src_q <= '0; c_q <= '0; shamt_q <= '0;
    end else if (ce) begin
      src_q <= src_i; c_q <= c_i; shamt_q <= shamt_i;
    end
  end

  logic [W-1:0] dst_int;
  uop_block #(
      .LEN       (LEN), .W(W), .MAX_LEN_P(LEN), .FF_MASK(FF_MASK),
      .OPS(OPS), .IMM(IMM), .USE_IMM(USE_IMM),
      .BW_ARR(BW_ARR), .CONT_ARR(CONT_ARR),
      .HAS_MEM(HAS_MEM), .ADDR_W(ADDR_W), .MEM_KIND(MEM_KIND)
  ) core (
      .clk(clk), .rstn(rstn), .ce(ce), .mb_ready_i(mb_ready_i),
      .src(src_q), .c(c_q), .shamt(shamt_q), .dst(dst_int),
      .mem_rdata_i(mem_rdata_i),
      .mem_addr_o(mem_addr_o), .mem_wdata_o(mem_wdata_o), .mem_we_o(mem_we_o),
      .mem_req_now_o(mem_req_now_o), .mem_wsel_o(mem_wsel_o)
  );

  generate
    if (OUT_FF) begin
      always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) dst_o <= '0;
        else if (ce) dst_o <= dst_int;
      end
    end else begin
      assign dst_o = dst_int;
    end
  endgenerate

  logic        st_v;
  logic [63:0] st_d;
  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      st_v <= 1'b0; st_d <= '0;
    end else begin
      if (mem_we_o) begin
        st_v <= 1'b1;
        st_d <= (W >= 64) ? mem_wdata_o[63:0]
                          : {{(64-W){1'b0}}, mem_wdata_o};
      end
      if (take_store_i) st_v <= 1'b0;
    end
  end
  assign store_v_o = st_v;
  assign store_d_o = st_d;
endmodule
