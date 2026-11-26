// ============================================================================
// ERV26 - Operand Build
//   Arma los operandos de la ALU:
//     A = rs1 | PC (AUIPC) | 0 (LUI)
//     B = rs2 | imm
//   En el pipeline aca entran tambien los datos de forwarding.
// ============================================================================
`include "erv26_defs.vh"

module erv26_operand_build (
    input  wire [1:0]  alu_src_a,
    input  wire        use_imm,
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    input  wire [31:0] pc,
    input  wire [31:0] imm,
    output reg  [31:0] op_a,
    output wire [31:0] op_b
);
    always @(*) begin
        case (alu_src_a)
            `SRCA_PC  : op_a = pc;
            `SRCA_ZERO: op_a = 32'd0;
            default   : op_a = rs1_data;
        endcase
    end

    assign op_b = use_imm ? imm : rs2_data;
endmodule
