// ============================================================================
// ERV26 - EX: resultado de la etapa
//   JAL/JALR guardan PC+4 (link); el resto, la salida de la ALU
//   (en load/store es la direccion).
// ============================================================================
`include "erv26_defs.vh"

module erv26_ex_result (
    input  wire [1:0]  wb_sel,
    input  wire [31:0] pc,
    input  wire [31:0] alu_y,
    output wire [31:0] result
);
    assign result = (wb_sel == `WB_PC4) ? (pc + 32'd4) : alu_y;
endmodule
