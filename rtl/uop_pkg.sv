`ifndef __UOP_PKG_SV
`define __UOP_PKG_SV
package uop_pkg;

   typedef enum logic [9:0] {
      OP_NOP        = 10'd0,

      OP_ADC,              OP_ADD,              OP_ADDSS,
      OP_AND,              OP_ANDN,             OP_ANDPD,            OP_ANDPS,
      OP_BLSI,             OP_BLSR,             OP_BT,               OP_BZHI,
      OP_CDQ,              OP_CDQE,             OP_CMOVB,            OP_CMOVBE,
      OP_CMOVL,            OP_CMOVLE,           OP_CMOVNB,           OP_CMOVNBE,
      OP_CMOVNLE,          OP_CMOVNZ,           OP_CMOVS,            OP_CMOVZ,
      OP_CMP,              OP_CQO,              OP_DEC,              OP_DIV,
      OP_DIVSS,            OP_FADD,             OP_FMA,              OP_FMUL,
      OP_FSUB,             OP_ICONV,            OP_IDIV,             OP_IMUL,
      OP_INC,              OP_LEA,              OP_MOV,              OP_MOVAPD,
      OP_MOVAPS,           OP_MOVD,             OP_MOVDQA,           OP_MOVDQU,
      OP_MOVQ,             OP_MOVSD,            OP_MOVSS,            OP_MOVSX,
      OP_MOVSXD,           OP_MOVZX,            OP_MUL,              OP_MULSS,
      OP_NEG,              OP_NOT,              OP_OR,               OP_POP,
      OP_PUNPCKLQDQ,       OP_PUSH,             OP_PXOR,             OP_RCL,
      OP_RCR,              OP_ROR,              OP_RORX,             OP_SAR,
      OP_SARX,             OP_SBB,              OP_SETB,             OP_SETBE,
      OP_SETLE,            OP_SETNB,            OP_SETNBE,           OP_SETNL,
      OP_SETNLE,           OP_SETNP,            OP_SETNZ,            OP_SETP,
      OP_SETZ,             OP_SHL,              OP_SHLD,             OP_SHLX,
      OP_SHR,              OP_SHRD,             OP_SHRX,             OP_SAL,
      OP_SUB,              OP_SUBSS,            OP_TEST,             OP_TZCNT,
      OP_UCOMISD,

      OP_VADDPD,           OP_VADDPS,           OP_VADDSD,           OP_VADDSS,
      OP_VANDPD,           OP_VANDPS,           OP_VBLENDPD,         OP_VBLENDVPD,
      OP_VBROADCASTSD,     OP_VBROADCASTSS,     OP_VCMPPD,           OP_VCMPSD,
      OP_VCOMISD,          OP_VCOMISS,          OP_VCVTSD2SS,        OP_VCVTSI2SD,
      OP_VCVTSI2SS,        OP_VCVTSS2SD,        OP_VCVTTSI2SI,       OP_VCVTTSD2SI,
      OP_VCVTTSS2SI,       OP_VDIVPD,           OP_VDIVPS,           OP_VDIVSD,
      OP_VDIVSS,           OP_VEXTRACTF128,     OP_VEXTRACTI128,     OP_VFMADD132PD,
      OP_VFMADD132PS,      OP_VFMADD132SD,      OP_VFMADD132SS,      OP_VFMADD213PD,
      OP_VFMADD213SD,      OP_VFMADD213SS,      OP_VFMADD231PD,      OP_VFMADD231PS,
      OP_VFMADD231SD,      OP_VFMADD231SS,      OP_VFMSUB132PD,      OP_VFMSUB132PS,
      OP_VFMSUB132SD,      OP_VFMSUB132SS,      OP_VFMSUB213PD,      OP_VFMSUB213SS,
      OP_VFMSUB231PD,      OP_VFMSUB231SD,      OP_VFMSUB231SS,      OP_VFNMADD132PD,
      OP_VFNMADD132PS,     OP_VFNMADD132SD,     OP_VFNMADD213PD,     OP_VFNMADD213PS,
      OP_VFNMADD213SD,     OP_VFNMADD213SS,     OP_VFNMADD231PD,     OP_VFNMADD231SD,
      OP_VFNMADD231SS,     OP_VFNMSUB132PD,     OP_VFNMSUB132SD,     OP_VFNMSUB231SD,
      OP_VINSERTF128,      OP_VINSERTI128,      OP_VINSERTPS,        OP_VMASKMOVPD,
      OP_VMAXPD,           OP_VMAXSD,           OP_VMAXSS,           OP_VMINPD,
      OP_VMINSD,           OP_VMINSS,           OP_VMOVAPD,          OP_VMOVAPS,
      OP_VMOVD,            OP_VMOVDDUP,         OP_VMOVDQA,          OP_VMOVDQU,
      OP_VMOVHPD,          OP_VMOVHPS,          OP_VMOVLHPS,         OP_VMOVLPD,
      OP_VMOVLPS,          OP_VMOVMSKPS,        OP_VMOVNTDQ,         OP_VMOVQ,
      OP_VMOVSD,           OP_VMOVSHDUP,        OP_VMOVSLDUP,        OP_VMOVSS,
      OP_VMOVUPD,          OP_VMOVUPS,          OP_VMULPD,           OP_VMULPS,
      OP_VMULSD,           OP_VMULSS,           OP_VORPD,            OP_VPACKUSDW,
      OP_VPACKUSWB,        OP_VPADDD,           OP_VPADDQ,           OP_VPADDW,
      OP_VPAND,            OP_VPANDN,           OP_VPAVGB,           OP_VPBLENDD,
      OP_VPBLENDVB,        OP_VPBLENDW,         OP_VPBROADCASTB,     OP_VPBROADCASTB256,
      OP_VPBROADCASTD,     OP_VPBROADCASTW,     OP_VPBROADCASTW256,  OP_VPCMPEQB,
      OP_VPCMPEQD,         OP_VPCMPGTD,         OP_VPCMPGTW,         OP_VPEXTRD,
      OP_VPEXTRQ,          OP_VPINSRB,          OP_VPINSRD,          OP_VPINSRQ,
      OP_VPMAXSD,          OP_VPMINUB,          OP_VPMOVMSKB,        OP_VPMOVSXWD,
      OP_VPMOVZXBW,        OP_VPMOVZXWD,        OP_VPMULLD,          OP_VPOR,
      OP_VPSADBW,          OP_VPSHUFD,          OP_VPSLLD,           OP_VPSLLQ,
      OP_VPSLLW,           OP_VPSRAD,           OP_VPSRAW,           OP_VPSRLD,
      OP_VPSRLDQ,          OP_VPSRLQ,           OP_VPSUBD,           OP_VPSUBW,
      OP_VPTEST,           OP_VPXOR,            OP_VROUNDSD,         OP_VSQRTPD,
      OP_VSQRTSD,          OP_VSQRTSS,          OP_VSTMXCSR,         OP_VSUBPD,
      OP_VSUBPS,           OP_VSUBSD,           OP_VSUBSD256,        OP_VSUBSS,
      OP_VUCOMISD,         OP_VUCOMISS,         OP_VUNPCKHPD,        OP_VUNPCKLPD,
      OP_VUNPCKLPS,        OP_VXORPD,           OP_VXORPS,           OP_XCHG,
      OP_XOR

   } op_t;

   localparam op_t OP_SAL = OP_SHL;

endpackage
`endif
