package uop_pkg;

  typedef enum logic [9:0] {
    OP_NOP        = 10'd0,

    // ---- ALU / bit ----
    OP_ADD,              OP_SUB,              OP_AND,              OP_ANDN,
    OP_OR,               OP_XOR,              OP_NEG,              OP_NOT,
    OP_SAR,              OP_SHR,              OP_SHL,              OP_RORX,
    OP_SARX,             OP_SHRX,             OP_SHLX,
    OP_BLSI,             OP_BLSR,             OP_BZHI,             OP_TZCNT,
    OP_PXOR,             OP_CMP,              OP_TEST,             OP_UCOMISD,
    OP_VCOMISD,          OP_VCOMISS,          OP_VUCOMISD,         OP_VUCOMISS,
    OP_BT,               OP_INC,              OP_DEC,

    // ---- scalar sign/zero extend helpers ----
    OP_CDQ,              OP_CDQE,             OP_CQO,

    // ---- SIMD logic ----
    OP_ANDPD,            OP_ANDPS,            OP_VANDPD,           OP_VANDPS,
    OP_SUBSS,            OP_VORPD,            OP_VPOR,             OP_VPXOR,
    OP_VXORPD,           OP_VXORPS,           OP_VPAND,            OP_VPANDN,

    // ---- mul / add / sub (no flag consume) ----
    OP_MUL,              OP_IMUL,             OP_MULSS,
    OP_VMULPS,           OP_VMULPD,           OP_VMULSD,           OP_VMULSS,  OP_VPMULLD,
    OP_VPADDD,           OP_VPADDQ,           OP_VPADDW,           OP_VPSUBD,  OP_VPSUBW,  OP_VPAVGB,
    OP_ADDSS,            OP_VADDSS,           OP_VADDPS,           OP_VADDPD,  OP_VADDSD,
    OP_VSUBPS,           OP_VSUBPD,           OP_VSUBSS,           OP_VSUBSD,

    // ---- shifts (only) ----
    OP_VPSLLD,           OP_VPSLLQ,           OP_VPSLLW,
    OP_VPSRLD,           OP_VPSRLQ,           OP_VPSRAD,           OP_VPSRAW,

    // ---- broadcast / blends (immediate-mask only) ----
    OP_VBROADCASTSD,     OP_VBROADCASTSS,
    OP_VPBROADCASTB,     OP_VPBROADCASTD,     OP_VPBROADCASTW,
    OP_VPBLENDD,         OP_VPBLENDW,         OP_VBLENDPD,

    // ---- insert / extract / masks / misc ----
    OP_VPINSRB,          OP_VPINSRD,          OP_VPINSRQ,
    OP_VPEXTRD,          OP_VPEXTRQ,
    OP_VINSERTPS,        OP_VEXTRACTI128,     OP_VEXTRACTF128,     OP_VINSERTI128, OP_VINSERTF128,
    OP_VMOVMSKPS,        OP_VPSADBW,

    // ---- vector sign/zero extend (no flags) ----
    OP_VPMOVSXWD,        OP_VPMOVZXBW,        OP_VPMOVZXWD,

    // ---- MOV / loads & stores (regular) ----
    OP_MOV,              OP_MOVQ,             OP_MOVD,             OP_MOVDQA,  OP_MOVDQU,  OP_MOVSD,  OP_MOVSS,
    OP_MOVAPD,           OP_MOVAPS,           OP_MOVSX,            OP_MOVSXD,  OP_MOVZX,
    OP_VMOVQ,            OP_VMOVD,            OP_VMOVDQA,          OP_VMOVDQU,
    OP_VMOVAPS,          OP_VMOVAPD,          OP_VMOVSS,           OP_VMOVSD,  OP_VMOVUPS, OP_VMOVUPD,
    OP_VMOVHPS,          OP_VMOVHPD,          OP_VMOVLPS,          OP_VMOVLPD, OP_VMOVLHPS,
    OP_PUNPCKLQDQ,       OP_LEA,

    // ---- min/max ----
    OP_VMAXPD,           OP_VMAXPS,           OP_VMAXSD,           OP_VMAXSS,
    OP_VMINPD,           OP_VMINPS,           OP_VMINSD,           OP_VMINSS,

    // ---- FMA (no flags) ----
    OP_VFMADD132PS,      OP_VFMADD213PS,      OP_VFMADD231PS,
    OP_VFMADD132PD,      OP_VFMADD213PD,      OP_VFMADD231PD,
    OP_VFMADD132SS,      OP_VFMADD213SS,      OP_VFMADD231SS,
    OP_VFMADD132SD,      OP_VFMADD213SD,      OP_VFMADD231SD,
    OP_VFMSUB132PS,      OP_VFMSUB213PS,      OP_VFMSUB231PS,
    OP_VFMSUB132PD,      OP_VFMSUB213PD,      OP_VFMSUB231PD,
    OP_VFMSUB132SS,      OP_VFMSUB213SS,      OP_VFMSUB231SS,
    OP_VFMSUB132SD,      OP_VFMSUB213SD,      OP_VFMSUB231SD,
    OP_VFNMADD132PS,     OP_VFNMADD213PS,     OP_VFNMADD231PS,
    OP_VFNMADD132PD,     OP_VFNMADD213PD,     OP_VFNMADD231PD,
    OP_VFNMADD132SS,     OP_VFNMADD213SS,     OP_VFNMADD231SS,
    OP_VFNMADD132SD,     OP_VFNMADD213SD,     OP_VFNMADD231SD,
    OP_VFNMSUB132PD,     OP_VFNMSUB231SD,     OP_VFNMSUB132SD,

    // compares (no flag consume)
    OP_VCMPPD,           OP_VCMPSD,
    OP_VPCMPEQB,         OP_VPCMPEQD,         OP_VPCMPGTD,         OP_VPCMPGTW,
    OP_VPMAXSD,          OP_VPMINUB,          OP_VPMOVMSKB,        OP_VPTEST,

    //  data dup / shuffles
    OP_VMOVDDUP,         OP_VMOVSHDUP,        OP_VMOVSLDUP

  } op_t;

  // alias
  localparam op_t OP_SAL = OP_SHL;

endpackage
