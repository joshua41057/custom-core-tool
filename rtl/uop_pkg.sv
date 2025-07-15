`ifndef __UOP_PKG_SV
`define __UOP_PKG_SV
package uop_pkg;
   typedef enum logic [7:0] {
      OP_NOP        = 8'd0,
      OP_ADD,  OP_ADC,  OP_SUB,  OP_SBB,
      OP_INC,  OP_DEC,  OP_NEG,  OP_CMP,
      OP_AND,  OP_OR,   OP_XOR,  OP_NOT,
      OP_TEST, OP_SHL,  OP_SHR,  OP_SAR,
      OP_ROL,  OP_ROR,  OP_RCL,  OP_RCR,
      OP_RORX, OP_SHRX,
      OP_SHLD, OP_SHRD, OP_MUL,  OP_IMUL,
      OP_DIV,  OP_IDIV, OP_MOV,  OP_MOVSX,
      OP_MOVSXD, OP_MOVZX, 
      
      OP_FADD, OP_FSUB, OP_FMUL, OP_FMA,  OP_FCMP, OP_ICONV,
      
      OP_SUBSS, OP_VADDSD, OP_VSUBSD, OP_VCOMISD,
      OP_VCVTSI2SD, OP_VDIVSD, OP_VFMADD132SD, OP_VFNMADD132SD,
      OP_VMAXSD, OP_VMINSD, OP_VMOVD, OP_VMOVQ,
      OP_VMOVSD, OP_VMOVSLDUP, OP_VMULSD, OP_VPBROADCASTB,
      OP_VPBROADCASTW, OP_VPSHUFD, OP_VXORPD, 
      
      OP_VADDSD256, OP_VSUBSD256, OP_VPBROADCASTB256, OP_VPBROADCASTW256
   } op_t;

   localparam op_t OP_SAL = OP_SHL;
endpackage
`endif
