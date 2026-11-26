// ============================================================================
// ERV26 - Opcode Decode
//   Extrae los campos de la instruccion y genera las senales de control
//   (instr_flags del diagrama de la catedra). Ya contempla el set RV32I
//   completo del ERV26 aunque el MVP-0 solo use reg_write/alu_*.
//
//   FENCE           -> NOP (sin efectos)
//   SYSTEM (ECALL,
//   EBREAK, CSR*)   -> NOP en el MVP-0. Se marca is_system para agregar
//                      CSRs/traps en la Parte III.
//   Opcode invalido -> NOP + illegal=1
// ============================================================================
`include "erv26_defs.vh"

module erv26_decoder (
    input  wire [31:0] inst,

    // Campos
    output wire [6:0]  opcode,
    output wire [4:0]  rd,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,

    // Control
    output reg  [2:0]  fmt,        // formato -> IMM builder
    output reg         reg_write,  // guardar en registro
    output reg         use_rs1,    // la instruccion lee rs1 (hazards)
    output reg         use_rs2,    // la instruccion lee rs2 (hazards)
    output reg         use_imm,    // operando B = imm (si 0: rs2)
    output reg  [1:0]  alu_src_a,  // RS1 / PC / ZERO
    output reg  [3:0]  alu_op,
    output reg         is_branch,
    output reg         is_jal,
    output reg         is_jalr,
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  wb_sel,     // ALU / MEM / PC+4
    output reg         is_system,
    output reg         illegal
);
    assign opcode = inst[6:0];
    assign rd     = inst[11:7];
    assign funct3 = inst[14:12];
    assign rs1    = inst[19:15];
    assign rs2    = inst[24:20];
    assign funct7 = inst[31:25];

    always @(*) begin
        // Valores por defecto: NOP
        fmt       = `FMT_R;
        reg_write = 1'b0;
        use_rs1   = 1'b0;
        use_rs2   = 1'b0;
        use_imm   = 1'b0;
        alu_src_a = `SRCA_RS1;
        alu_op    = `ALU_ADD;
        is_branch = 1'b0;
        is_jal    = 1'b0;
        is_jalr   = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        wb_sel    = `WB_ALU;
        is_system = 1'b0;
        illegal   = 1'b0;

        if (inst[1:0] != 2'b11) begin
            illegal = 1'b1;                 // solo instrucciones de 32 bits
        end else begin
            case (opcode)
            `OPC_LUI: begin
                fmt = `FMT_U; reg_write = 1'b1;
                use_imm = 1'b1; alu_src_a = `SRCA_ZERO;      // rd = 0 + imm
            end
            `OPC_AUIPC: begin
                fmt = `FMT_U; reg_write = 1'b1;
                use_imm = 1'b1; alu_src_a = `SRCA_PC;        // rd = pc + imm
            end
            `OPC_JAL: begin
                fmt = `FMT_J; reg_write = 1'b1; is_jal = 1'b1;
                wb_sel = `WB_PC4;
            end
            `OPC_JALR: begin
                fmt = `FMT_I; reg_write = 1'b1; is_jalr = 1'b1;
                use_rs1 = 1'b1; use_imm = 1'b1;              // destino = rs1 + imm
                wb_sel = `WB_PC4;
                illegal = (funct3 != 3'b000);
            end
            `OPC_BRANCH: begin
                fmt = `FMT_B; is_branch = 1'b1;
                use_rs1 = 1'b1; use_rs2 = 1'b1;
                illegal = (funct3 == 3'b010) || (funct3 == 3'b011);
            end
            `OPC_LOAD: begin
                fmt = `FMT_I; reg_write = 1'b1; mem_read = 1'b1;
                use_rs1 = 1'b1; use_imm = 1'b1;              // dir = rs1 + imm
                wb_sel = `WB_MEM;
                illegal = (funct3 == 3'b011) || (funct3[2:1] == 2'b11);
            end
            `OPC_STORE: begin
                fmt = `FMT_S; mem_write = 1'b1;
                use_rs1 = 1'b1; use_rs2 = 1'b1; use_imm = 1'b1;
                illegal = (funct3[2] == 1'b1) || (funct3 == 3'b011);
            end
            `OPC_OP_IMM: begin
                fmt = `FMT_I; reg_write = 1'b1;
                use_rs1 = 1'b1; use_imm = 1'b1;
                // Solo SRAI usa el bit alt; en ADDI inst[30] es parte del imm
                alu_op = {(funct3 == 3'b101) & inst[30], funct3};
                if (funct3 == 3'b001)       // SLLI
                    illegal = (funct7 != 7'b0000000);
                else if (funct3 == 3'b101)  // SRLI / SRAI
                    illegal = (funct7 != 7'b0000000) && (funct7 != 7'b0100000);
            end
            `OPC_OP: begin
                fmt = `FMT_R; reg_write = 1'b1;
                use_rs1 = 1'b1; use_rs2 = 1'b1;
                alu_op = {inst[30], funct3};
                // inst[30] solo valido en ADD/SUB y SRL/SRA
                illegal = !((funct7 == 7'b0000000) ||
                            (funct7 == 7'b0100000 && (funct3 == 3'b000 || funct3 == 3'b101)));
            end
            `OPC_MISC_MEM: begin
                // FENCE / FENCE.I = NOP
            end
            `OPC_SYSTEM: begin
                is_system = 1'b1;           // NOP hasta implementar CSR/traps
            end
            default: illegal = 1'b1;
            endcase

            // Una instruccion ilegal no debe tener efectos
            if (illegal) begin
                reg_write = 1'b0; mem_read = 1'b0; mem_write = 1'b0;
                is_branch = 1'b0; is_jal = 1'b0; is_jalr = 1'b0;
            end
        end
    end
endmodule
