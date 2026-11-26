// ============================================================================
// ERV26 - ALU
//   Operaciones RV32I: ADD SUB SLL SLT SLTU XOR SRL SRA OR AND.
//   alu_op = {alt, funct3} (ver erv26_defs.vh).
//   Para shifts solo se usan b[4:0] (shamt), tal como pide la ISA.
//
//   Nota de diseno: la comparacion de saltos y el calculo de direcciones de
//   salto NO pasan por aca (van en un bloque aparte en el pipeline), asi la
//   ALU queda libre y el salto se puede resolver antes.
// ============================================================================
`include "erv26_defs.vh"

module erv26_alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_op,
    output reg  [31:0] y
);
    wire [4:0] shamt = b[4:0];

    always @(*) begin
        case (alu_op)
            `ALU_ADD : y = a + b;
            `ALU_SUB : y = a - b;
            `ALU_SLL : y = a << shamt;
            `ALU_SLT : y = {31'd0, ($signed(a) < $signed(b))};
            `ALU_SLTU: y = {31'd0, (a < b)};
            `ALU_XOR : y = a ^ b;
            `ALU_SRL : y = a >> shamt;
            `ALU_SRA : y = $signed(a) >>> shamt;
            `ALU_OR  : y = a | b;
            `ALU_AND : y = a & b;
            default  : y = a + b;          // alt=1 con funct3 sin variante
        endcase
    end
endmodule
