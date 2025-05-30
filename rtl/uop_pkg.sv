`ifndef __UOP_PKG_SV
`define __UOP_PKG_SV
package uop_pkg;
   typedef enum logic [5:0] {
      OP_NOP  =  6'd0,

      // arithmetic
      OP_ADD  , OP_ADC , OP_SUB , OP_SBB ,
      OP_INC  , OP_DEC , OP_NEG , OP_CMP ,

      // logic
      OP_AND  , OP_OR  , OP_XOR , OP_NOT , OP_TEST ,

      // shifts / rotates
      OP_SHL  , OP_SHR , OP_SAR ,
      OP_ROL  , OP_ROR , OP_RCL , OP_RCR ,
      OP_SHLD , OP_SHRD ,

      OP_MUL  ,          // unsigned   a * b
      OP_IMUL ,          //   signed   a * b
      OP_DIV  ,          
      OP_IDIV            
   } op_t;
   
   localparam op_t OP_SAL = OP_SHL;
endpackage
`endif
