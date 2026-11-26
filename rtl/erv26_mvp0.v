// ============================================================================
// ERV26 - MVP-0 (proto-procesador, checkpoint 1)
//
//   Single-cycle, sin pipeline: Fetch -> Decode -> Regfile -> Operand Build
//   -> ALU es combinacional en cascada y el write-back ocurre en el flanco
//   ascendente siguiente (opcion 1 del enunciado para el banco de registros).
//
//   Soporta: OP (R-type), OP-IMM, LUI, AUIPC.
//   Saltos, LOAD y STORE se decodifican pero no tienen efecto (no hay
//   memoria de datos ni control de saltos en el MVP-0): no escriben rd y el
//   PC sigue en PC+4.
//
//   Este modulo es la REFERENCIA de conexionado: en Quartus el top-level se
//   arma como diagrama de bloques (.bdf) creando un simbolo de cada modulo
//   (File > Create/Update > Create Symbol Files for Current File) y
//   cableandolos igual que aca.
// ============================================================================
`include "erv26_defs.vh"

module erv26_mvp0 #(
    parameter PROG_DEPTH = 1024,
    parameter PROG_AW    = 10,
    parameter PROG_FILE  = "program.hex"
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,          // 1 = ejecutar una instruccion por flanco

    // Debug / observacion
    input  wire [4:0]  dbg_reg_sel,
    output wire [31:0] dbg_reg_data,
    output wire [31:0] dbg_pc,
    output wire [31:0] dbg_instr,
    output wire        dbg_illegal
);
    // ---------------- Fetch ----------------
    wire [31:0] pc, pc_plus4, instr;

    erv26_fetch u_fetch (
        .clk(clk), .rst_n(rst_n), .en(en),
        .jump_en(1'b0), .jump_target(32'd0),
        .pc(pc), .pc_plus4(pc_plus4)
    );

    erv26_prog_mem #(.DEPTH(PROG_DEPTH), .AW(PROG_AW), .INIT_FILE(PROG_FILE)) u_pmem (
        .addr(pc), .instr(instr)
    );

    // ---------------- Decode ----------------
    wire [6:0] opcode, funct7;
    wire [4:0] rd, rs1, rs2;
    wire [2:0] funct3, fmt;
    wire       reg_write, use_rs1, use_rs2, use_imm;
    wire [1:0] alu_src_a, wb_sel;
    wire [3:0] alu_op;
    wire       is_branch, is_jal, is_jalr, mem_read, mem_write, is_system, illegal;

    erv26_decoder u_dec (
        .inst(instr),
        .opcode(opcode), .rd(rd), .rs1(rs1), .rs2(rs2), .funct3(funct3), .funct7(funct7),
        .fmt(fmt), .reg_write(reg_write), .use_rs1(use_rs1), .use_rs2(use_rs2),
        .use_imm(use_imm), .alu_src_a(alu_src_a), .alu_op(alu_op),
        .is_branch(is_branch), .is_jal(is_jal), .is_jalr(is_jalr),
        .mem_read(mem_read), .mem_write(mem_write), .wb_sel(wb_sel),
        .is_system(is_system), .illegal(illegal)
    );

    wire [31:0] imm;
    erv26_imm_gen u_imm (.inst(instr), .fmt(fmt), .imm(imm));

    // ---------------- Register bank ----------------
    wire [31:0] rs1_data, rs2_data, wb_data;

    // MVP-0: solo escriben las instrucciones cuyo resultado sale de la ALU
    wire wb_en = en & reg_write & (wb_sel == `WB_ALU);

    erv26_regfile #(.WRITE_THROUGH(0)) u_rf (
        .clk(clk),
        .we(wb_en), .rd_addr(rd), .rd_data(wb_data),
        .rs1_addr(rs1), .rs2_addr(rs2),
        .rs1_data(rs1_data), .rs2_data(rs2_data),
        .dbg_addr(dbg_reg_sel), .dbg_data(dbg_reg_data)
    );

    // ---------------- Execute ----------------
    wire [31:0] op_a, op_b, alu_y;

    erv26_operand_build u_opb (
        .alu_src_a(alu_src_a), .use_imm(use_imm),
        .rs1_data(rs1_data), .rs2_data(rs2_data), .pc(pc), .imm(imm),
        .op_a(op_a), .op_b(op_b)
    );

    erv26_alu u_alu (.a(op_a), .b(op_b), .alu_op(alu_op), .y(alu_y));

    assign wb_data = alu_y;

    // ---------------- Debug ----------------
    assign dbg_pc      = pc;
    assign dbg_instr   = instr;
    assign dbg_illegal = illegal;

endmodule
