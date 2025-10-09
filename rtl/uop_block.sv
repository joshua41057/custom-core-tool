module uop_block #(
    parameter int                 LEN         = 4,
    parameter int                 W           = 32,
    parameter int                 MAX_LEN_P   = 64,
    parameter bit [MAX_LEN_P-1:0] FF_MASK     = '0,
    parameter uop_pkg::op_t       OPS[0:LEN-1]  = '{default:uop_pkg::OP_NOP},
    parameter logic [31:0]        IMM[LEN]      = '{default:32'h0},
    parameter logic               USE_IMM[LEN]  = '{default:1'b0},
    parameter int                 BW_ARR[LEN]   = '{default:W},
    parameter int                 CONT_ARR[LEN] = '{default:0},
    parameter bit                 HAS_MEM       = 1'b0,
    parameter int                 ADDR_W        = 8,
    parameter logic [1:0]         MEM_KIND [0:LEN-1] = '{default:2'd0}
)(
    input  logic                   clk,
    input  logic                   rstn, 
    input  logic                   ce,
    input  logic                   mb_ready_i,  
    input  logic [W-1:0]           src,
    input  logic [W-1:0]           c,
    input  logic [$clog2(W)-1:0]   shamt,
    output logic [W-1:0]           dst,

    input  logic [W-1:0]           mem_rdata_i,
    output logic [ADDR_W-1:0]      mem_addr_o,
    output logic [W-1:0]           mem_wdata_o,
    output logic                   mem_we_o,
    output logic                   mem_req_now_o,
    output logic                   mem_wsel_o
);
    import uop_pkg::*;

    logic [W-1:0] stage [LEN+1];
    assign stage[0] = src;

    logic [$clog2(LEN):0] stage_ptr;

    localparam int L = LEN;
    logic [L-1:0] sp_oh;
    always_comb begin sp_oh = '0; sp_oh[stage_ptr] = 1'b1; end

    logic stall_now;
    always_comb begin
      stall_now = 1'b0;
      if (HAS_MEM) begin
        for (int i = 0; i < L; i++) begin
          if (i>0) begin
            logic prev_was_load = (MEM_KIND[i-1] == 2'd1) || (MEM_KIND[i-1] == 2'd3);
            if (prev_was_load && sp_oh[i] && !mb_ready_i) stall_now = 1'b1;
          end
        end
      end
    end

    always_ff @(posedge clk or negedge rstn) begin
      if (!rstn) stage_ptr <= '0;
      else if (ce && !stall_now) begin
        if (LEN==1)                       stage_ptr <= '0;
        else if (stage_ptr >= (LEN-1))    stage_ptr <= '0;
        else                               stage_ptr <= stage_ptr + 1;
      end
    end

    generate
      for (genvar i = 0; i < LEN; i++) begin : g
        localparam int WI_RAW = (BW_ARR[i] > 0) ? BW_ARR[i] : W;
        localparam int WI     = (WI_RAW > W) ? W : WI_RAW;
        localparam int SHW    = (WI > 1) ? $clog2(WI) : 1;
        localparam bit ZEXT   = (CONT_ARR[i] == 0) && (WI == 32);

        localparam bit PREV_WAS_LOAD = (i==0) ? 1'b0 : (MEM_KIND[i-1] == 2'd1 || MEM_KIND[i-1] == 2'd3);

        logic [WI-1:0] a_eff;
        always_comb a_eff = (HAS_MEM && PREV_WAS_LOAD) ? mem_rdata_i[WI-1:0] : stage[i][WI-1:0];

        logic [WI-1:0] c_eff = (WI <= W) ? c[WI-1:0] : {{(WI-W){1'b0}}, c};

        logic [WI-1:0] b_eff;
        if (USE_IMM[i]) assign b_eff = (WI > 32) ? {{(WI-32){1'b0}}, IMM[i]} : IMM[i][WI-1:0];
        else            assign b_eff = c_eff;

        logic [WI-1:0] y_eff;
        localparam bit           THIS_USE_IMM = USE_IMM[i];
        localparam uop_pkg::op_t THIS_OP      = OPS[i];
        localparam bit IS_SHIFT_IMM =
            (THIS_OP==OP_SHL)  || (THIS_OP==OP_SAL) ||
            (THIS_OP==OP_SHR)  || (THIS_OP==OP_SAR) ||
            (THIS_OP==OP_SHRX) || (THIS_OP==OP_SHLX) ||
            (THIS_OP==OP_SARX) || (THIS_OP==OP_RORX);

        if (THIS_USE_IMM && IS_SHIFT_IMM) begin : g_shift_const
          localparam int S = IMM[i][SHW-1:0];
          always_comb unique case (THIS_OP)
            OP_SHL, OP_SAL, OP_SHLX: y_eff = a_eff <<  S;
            OP_SHR,         OP_SHRX: y_eff = a_eff >>  S;
            OP_SAR,         OP_SARX: y_eff = $signed(a_eff) >>> S;
            OP_RORX:                 y_eff = (S==0) ? a_eff : ((a_eff >> S) | (a_eff << (WI-S)));
            default:                  y_eff = a_eff;
          endcase
        end else begin : g_normal
          microop_unit #(.OP(THIS_OP), .W(WI)) alu_i (
            .clk(clk), .a(a_eff), .b(b_eff), .c(c_eff), .shamt(shamt[SHW-1:0]), .y(y_eff)
          );
        end

        logic [W-1:0] y_wide =
            (WI == W) ? y_eff :
            (ZEXT)    ? {{(W-WI){1'b0}}, y_eff} :
                        { stage[i][W-1:WI], y_eff };

        localparam bit [LEN-1:0] FF_MASK_L = FF_MASK;
        localparam bit USE_FF = (LEN > 1) ? FF_MASK_L[i] : 1'b1;

        if (USE_FF) begin : g_ff
          always_ff @(posedge clk) if (ce && !stall_now) stage[i+1] <= y_wide;
        end else begin : g_wire
          assign stage[i+1] = y_wide;
        end
      end
    endgenerate

    logic [L-1:0] is_load_m, is_store_m, is_w64_m;
    generate
      for (genvar gi = 0; gi < L; gi++) begin : g_mask
        localparam bit LOADi  = (MEM_KIND[gi]==2'd1 || MEM_KIND[gi]==2'd3);
        localparam bit STOREi = (MEM_KIND[gi]==2'd2 || MEM_KIND[gi]==2'd3);
        localparam bit W64i   = (BW_ARR[gi] > 32);
        assign is_load_m [gi] = LOADi;
        assign is_store_m[gi] = STOREi;
        assign is_w64_m  [gi] = W64i;
      end
    endgenerate

    assign mem_req_now_o = HAS_MEM && |(sp_oh & (is_load_m | is_store_m));
    assign mem_we_o      = HAS_MEM && |(sp_oh &  is_store_m);
    assign mem_wsel_o    = HAS_MEM && |(sp_oh & is_w64_m);

    logic [W-1:0] mem_wdata_sel;
    always_comb begin
      mem_wdata_sel = '0;
      for (int i=0; i<L; i++) if (is_store_m[i] && sp_oh[i]) mem_wdata_sel = stage[i];
    end
    assign mem_wdata_o = mem_wdata_sel;

    localparam int STAGE_PTR_W = (LEN <= 1) ? 1 : ($clog2(LEN) + 1);
    wire [ADDR_W-1:0] stage_idx_masked =
        (ADDR_W <= STAGE_PTR_W) ? stage_ptr[ADDR_W-1:0]
                                : {{(ADDR_W-STAGE_PTR_W){1'b0}}, stage_ptr[STAGE_PTR_W-1:0]};
    assign mem_addr_o = (c[ADDR_W-1:0]) ^ stage_idx_masked;

    assign dst = stage[LEN];
endmodule
