// ============================================================================
// ERV26 - IMM Builder
//   Arma el inmediato de 32 bits con extension de signo segun el formato.
//   inst[31] es siempre el bit de signo en todos los formatos (ISA 2.3).
// ============================================================================
`include "erv26_defs.vh"

module erv26_imm_gen (
    input  wire [31:0] inst,
    input  wire [2:0]  fmt,
    output reg  [31:0] imm
);
    always @(*) begin
        case (fmt)
            `FMT_I: imm = {{21{inst[31]}}, inst[30:20]};
            `FMT_S: imm = {{21{inst[31]}}, inst[30:25], inst[11:7]};
            `FMT_B: imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            `FMT_U: imm = {inst[31:12], 12'b0};
            `FMT_J: imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            default: imm = 32'd0;   // FMT_R: sin inmediato
        endcase
    end
endmodule
