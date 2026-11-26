// ============================================================================
// ERV26 - Definiciones comunes (opcodes, codigos de ALU, formatos)
// 25.30 Electronica V - ITBA
// ============================================================================
`ifndef ERV26_DEFS_VH
`define ERV26_DEFS_VH

// ---- Opcodes RV32I (inst[6:0]) ---------------------------------------------
`define OPC_LOAD     7'b0000011
`define OPC_MISC_MEM 7'b0001111   // FENCE -> NOP
`define OPC_OP_IMM   7'b0010011
`define OPC_AUIPC    7'b0010111
`define OPC_STORE    7'b0100011
`define OPC_OP       7'b0110011
`define OPC_LUI      7'b0110111
`define OPC_BRANCH   7'b1100011
`define OPC_JALR     7'b1100111
`define OPC_JAL      7'b1101111
`define OPC_SYSTEM   7'b1110011

// ---- Formatos de instruccion (para el IMM builder) -------------------------
`define FMT_R 3'd0
`define FMT_I 3'd1
`define FMT_S 3'd2
`define FMT_B 3'd3
`define FMT_U 3'd4
`define FMT_J 3'd5

// ---- Operaciones de la ALU: {alt, funct3} ----------------------------------
// Se reutiliza la codificacion de la ISA: funct3 elige la operacion y el
// bit "alt" (inst[30]) distingue ADD/SUB y SRL/SRA. Asi el decode es casi
// cablear campos de la instruccion.
`define ALU_ADD  4'b0000
`define ALU_SUB  4'b1000
`define ALU_SLL  4'b0001
`define ALU_SLT  4'b0010
`define ALU_SLTU 4'b0011
`define ALU_XOR  4'b0100
`define ALU_SRL  4'b0101
`define ALU_SRA  4'b1101
`define ALU_OR   4'b0110
`define ALU_AND  4'b0111

// ---- Seleccion del operando A de la ALU ------------------------------------
`define SRCA_RS1  2'd0
`define SRCA_PC   2'd1   // AUIPC
`define SRCA_ZERO 2'd2   // LUI

// ---- Seleccion del dato de write-back --------------------------------------
`define WB_ALU 2'd0
`define WB_MEM 2'd1
`define WB_PC4 2'd2      // JAL / JALR (link)

`endif
