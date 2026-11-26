// ============================================================================
// ERV26 - Branch unit (control de saltos, etapa EX)
//   Comparador y sumadores propios, separados de la ALU: el salto se resuelve
//   en EX en paralelo con la ALU, sin competir por ella.
//
//   BRANCH : taken si se cumple la condicion, destino = PC + imm
//   JALR   : siempre, destino = (rs1 + imm) & ~1
//   JAL    : se resuelve antes, en ID (no depende de registros)
//
//   Prediccion estatica BTFN (erv26_id_predict): los branches hacia atras se
//   predicen tomados desde ID; los hacia adelante, no tomados. Aca se compara
//   el resultado real con pred_taken. Si no coinciden (o es un JALR),
//   redirect=1: el fetch se reencamina a target y se descarta la instruccion
//   que estaba en ID (1 ciclo perdido).
//     predicho tomado, no se toma   -> target = PC + 4
//     predicho no tomado, se toma   -> target = PC + imm
// ============================================================================
module erv26_branch_unit (
    input  wire        valid,
    input  wire        is_branch,
    input  wire        is_jalr,
    input  wire [2:0]  funct3,
    input  wire [31:0] rs1,        // ya con forwarding
    input  wire [31:0] rs2,        // ya con forwarding
    input  wire [31:0] pc,
    input  wire [31:0] imm,
    input  wire        pred_taken, // el branch se predijo tomado en ID
    output wire        redirect,
    output wire [31:0] target
);
    wire eq  = (rs1 == rs2);
    wire lt  = ($signed(rs1) < $signed(rs2));
    wire ltu = (rs1 < rs2);

    reg cond;
    always @(*) begin
        case (funct3)
            3'b000:  cond = eq;     // BEQ
            3'b001:  cond = ~eq;    // BNE
            3'b100:  cond = lt;     // BLT
            3'b101:  cond = ~lt;    // BGE
            3'b110:  cond = ltu;    // BLTU
            3'b111:  cond = ~ltu;   // BGEU
            default: cond = 1'b0;
        endcase
    end

    wire [31:0] br_target   = pc + imm;
    wire [31:0] jalr_target = (rs1 + imm) & 32'hFFFF_FFFE;

    wire        mispredict  = is_branch & (cond != pred_taken);

    assign redirect = valid & (mispredict | is_jalr);
    assign target   = is_jalr ? jalr_target :
                      cond    ? br_target   : (pc + 32'd4);
endmodule
