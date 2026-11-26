// ===== VERSION ANTERIOR (solo referencia, no se compila ni se simula) =====
// El nucleo ahora es rtl/erv26_core.bdf. Modulo renombrado a erv26_core_v1
// para que no choque con el .bdf. Es anterior a la prediccion BTFN: usa la
// interfaz vieja de erv26_branch_unit (sin pred_taken) y erv26_jal_unit.
// ============================================================================
// ERV26 - Nucleo con pipeline de 5 etapas
//
//   IF  : PC siguiente -> memoria de programa (lectura sincronica, M10K)
//   ID  : decode, IMM builder, lectura del banco, JAL, deteccion load-use
//   EX  : forwarding, ALU, branch unit (branch / JALR)
//   MEM : load/store con handshake memory_ready
//   WB  : escritura en el banco de registros
//
//   Memoria de programa: el nucleo entrega la direccion de la PROXIMA
//   instruccion (imem_addr) y la memoria la registra en el flanco; la salida
//   de la memoria (imem_rdata) ES la instruccion del latch IF/ID. Asi la M10K
//   no agrega un ciclo extra. Para mantener la instruccion en ID durante un
//   stall, simplemente se vuelve a pedir la misma direccion.
//
//   Penalidades:
//     JAL                  : 0 ciclos (se resuelve en ID antes del fetch)
//     branch tomado / JALR : 1 ciclo (se resuelve en EX)
//     load seguido de uso  : 1 ciclo
//     load/store           : lo que tarde memory_ready
//
//   Convencion de nombres: prefijo d_ = latch IF/ID, e_ = ID/EX,
//   m_ = EX/MEM, w_ = MEM/WB. *_valid = 0 indica burbuja.
// ============================================================================
`include "erv26_defs.vh"

module erv26_core_v1 #(
    parameter RESET_PC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,            // 0 = halt (congela el pipeline)

    // Memoria de programa (lectura sincronica de 1 ciclo)
    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    // Memoria de datos (direccion de byte, 32 bits + byte enables)
    output wire        dmem_req,
    output wire        dmem_we,
    output wire [3:0]  dmem_be,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input  wire [31:0] dmem_rdata,
    input  wire        dmem_ready,    // memory_ready del enunciado

    // Debug
    input  wire [4:0]  dbg_reg_sel,
    output wire [31:0] dbg_reg_data,
    output wire        dbg_commit,    // 1 ciclo por instruccion retirada
    output wire [31:0] dbg_commit_pc,
    output wire [31:0] dbg_commit_instr,
    output wire        dbg_commit_we,
    output wire [4:0]  dbg_commit_rd,
    output wire [31:0] dbg_commit_data
);
    // ========================================================================
    // Senales de control globales (definidas mas abajo)
    // ========================================================================
    wire freeze, load_use, flush_id;
    wire e_redirect;
    wire [31:0] e_target;

    // ========================================================================
    // IF - Fetch
    // ========================================================================
    reg  [31:0] d_pc;
    reg         d_valid;
    wire [31:0] d_instr = imem_rdata;

    wire        d_redirect;          // JAL en ID
    wire [31:0] d_target;
    reg  [31:0] f_pc;                // direccion pedida este ciclo

    always @(*) begin
        if (freeze)          f_pc = d_pc;           // repetir: ID se mantiene
        else if (e_redirect) f_pc = e_target;       // branch/JALR tomado
        else if (load_use)   f_pc = d_pc;           // stall de ID
        else if (d_redirect) f_pc = d_target;       // JAL
        else                 f_pc = d_pc + 32'd4;
    end
    assign imem_addr = f_pc;

    // Latch IF/ID
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_pc    <= RESET_PC - 32'd4;            // asi f_pc = RESET_PC
            d_valid <= 1'b0;
        end else if (!freeze && !load_use) begin
            d_pc    <= f_pc;
            d_valid <= 1'b1;
        end
    end

    // ========================================================================
    // ID - Decode
    // ========================================================================
    wire [6:0] d_opcode, d_funct7;
    wire [4:0] d_rd, d_rs1, d_rs2;
    wire [2:0] d_funct3, d_fmt;
    wire       d_reg_write, d_use_rs1, d_use_rs2, d_use_imm;
    wire [1:0] d_alu_src_a, d_wb_sel;
    wire [3:0] d_alu_op;
    wire       d_is_branch, d_is_jal, d_is_jalr, d_mem_read, d_mem_write;
    wire       d_is_system, d_illegal;

    erv26_decoder u_dec (
        .inst(d_instr),
        .opcode(d_opcode), .rd(d_rd), .rs1(d_rs1), .rs2(d_rs2),
        .funct3(d_funct3), .funct7(d_funct7),
        .fmt(d_fmt), .reg_write(d_reg_write), .use_rs1(d_use_rs1),
        .use_rs2(d_use_rs2), .use_imm(d_use_imm), .alu_src_a(d_alu_src_a),
        .alu_op(d_alu_op), .is_branch(d_is_branch), .is_jal(d_is_jal),
        .is_jalr(d_is_jalr), .mem_read(d_mem_read), .mem_write(d_mem_write),
        .wb_sel(d_wb_sel), .is_system(d_is_system), .illegal(d_illegal)
    );

    wire [31:0] d_imm;
    erv26_imm_gen u_imm (.inst(d_instr), .fmt(d_fmt), .imm(d_imm));

    // JAL: destino conocido en ID -> sin penalidad
    assign d_redirect = d_valid & d_is_jal;
    assign d_target   = d_pc + d_imm;

    // Banco de registros (lectura en ID, escritura en WB, con bypass WB->ID)
    reg         w_valid, w_we;
    reg  [4:0]  w_rd;
    reg  [31:0] w_data;
    wire [31:0] d_rs1_val, d_rs2_val;

    erv26_regfile #(.WRITE_THROUGH(1)) u_rf (
        .clk(clk),
        .we(w_valid & w_we), .rd_addr(w_rd), .rd_data(w_data),
        .rs1_addr(d_rs1), .rs2_addr(d_rs2),
        .rs1_data(d_rs1_val), .rs2_data(d_rs2_val),
        .dbg_addr(dbg_reg_sel), .dbg_data(dbg_reg_data)
    );

    // Latch ID/EX
    reg         e_valid;
    reg  [31:0] e_pc, e_instr, e_imm, e_rs1_val, e_rs2_val;
    reg  [4:0]  e_rd, e_rs1, e_rs2;
    reg  [2:0]  e_funct3;
    reg  [3:0]  e_alu_op;
    reg  [1:0]  e_alu_src_a, e_wb_sel;
    reg         e_use_imm, e_we, e_load, e_store, e_is_branch, e_is_jalr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            e_valid <= 1'b0;
        end else if (!freeze) begin
            // Burbuja si: ID vacio, stall load-use, o salto tomado en EX
            e_valid     <= d_valid & ~load_use & ~flush_id;
            e_pc        <= d_pc;
            e_instr     <= d_instr;
            e_imm       <= d_imm;
            e_rs1_val   <= d_rs1_val;
            e_rs2_val   <= d_rs2_val;
            e_rd        <= d_rd;
            e_rs1       <= d_rs1;
            e_rs2       <= d_rs2;
            e_funct3    <= d_funct3;
            e_alu_op    <= d_alu_op;
            e_alu_src_a <= d_alu_src_a;
            e_wb_sel    <= d_wb_sel;
            e_use_imm   <= d_use_imm;
            e_we        <= d_reg_write;
            e_load      <= d_mem_read;
            e_store     <= d_mem_write;
            e_is_branch <= d_is_branch;
            e_is_jalr   <= d_is_jalr;
        end
    end

    // ========================================================================
    // EX - Execute
    // ========================================================================
    reg         m_valid, m_we, m_load, m_store;
    reg  [4:0]  m_rd;
    reg  [31:0] m_result;
    wire [31:0] e_rs1_fwd, e_rs2_fwd;

    erv26_forward_unit u_fwd (
        .rs1(e_rs1), .rs2(e_rs2), .rs1_id(e_rs1_val), .rs2_id(e_rs2_val),
        .m_valid(m_valid), .m_we(m_we), .m_load(m_load), .m_rd(m_rd), .m_result(m_result),
        .w_valid(w_valid), .w_we(w_we), .w_rd(w_rd), .w_data(w_data),
        .rs1_fwd(e_rs1_fwd), .rs2_fwd(e_rs2_fwd)
    );

    wire [31:0] e_op_a, e_op_b, e_alu_y;
    erv26_operand_build u_opb (
        .alu_src_a(e_alu_src_a), .use_imm(e_use_imm),
        .rs1_data(e_rs1_fwd), .rs2_data(e_rs2_fwd), .pc(e_pc), .imm(e_imm),
        .op_a(e_op_a), .op_b(e_op_b)
    );

    erv26_alu u_alu (.a(e_op_a), .b(e_op_b), .alu_op(e_alu_op), .y(e_alu_y));

    erv26_branch_unit u_br (
        .valid(e_valid), .is_branch(e_is_branch), .is_jalr(e_is_jalr),
        .funct3(e_funct3), .rs1(e_rs1_fwd), .rs2(e_rs2_fwd),
        .pc(e_pc), .imm(e_imm), .redirect(e_redirect), .target(e_target)
    );

    // JAL/JALR guardan PC+4 (link)
    wire [31:0] e_result = (e_wb_sel == `WB_PC4) ? (e_pc + 32'd4) : e_alu_y;

    // Latch EX/MEM
    reg  [31:0] m_pc, m_instr, m_store_data;
    reg  [2:0]  m_funct3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
        end else if (!freeze) begin
            m_valid      <= e_valid;
            m_pc         <= e_pc;
            m_instr      <= e_instr;
            m_rd         <= e_rd;
            m_we         <= e_we;
            m_load       <= e_load;
            m_store      <= e_store;
            m_funct3     <= e_funct3;
            m_result     <= e_result;      // direccion en load/store
            m_store_data <= e_rs2_fwd;
        end
    end

    // ========================================================================
    // MEM - Memoria de datos
    // ========================================================================
    // Si la memoria termina (ready) en un ciclo en que el pipeline esta
    // congelado por otro motivo (en=0), se recuerda que el acceso ya se hizo
    // y se guarda el dato leido. Asi un store nunca se ejecuta dos veces
    // (importante con perifericos, p.ej. una UART) y no se pierde el dato.
    wire        m_mem_op = m_valid & (m_load | m_store);
    reg         m_done;
    reg  [31:0] m_rdata_hold;
    wire        m_mem_ok = m_done | dmem_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            m_done <= 1'b0;
        else if (!freeze)
            m_done <= 1'b0;                     // la instruccion avanza
        else if (dmem_req && dmem_ready) begin
            m_done       <= 1'b1;
            m_rdata_hold <= dmem_rdata;
        end
    end

    wire [31:0] m_rdata = m_done ? m_rdata_hold : dmem_rdata;
    wire [31:0] m_load_data;

    erv26_lsu u_lsu (
        .funct3(m_funct3), .addr_lo(m_result[1:0]),
        .store_data(m_store_data), .be(dmem_be), .wdata(dmem_wdata),
        .rdata(m_rdata), .load_data(m_load_data)
    );

    assign dmem_req  = m_mem_op & ~m_done;
    assign dmem_we   = m_store;
    assign dmem_addr = m_result;

    wire [31:0] m_wb_data = m_load ? m_load_data : m_result;

    // Latch MEM/WB
    reg [31:0] w_pc, w_instr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_valid <= 1'b0;
        end else if (!freeze) begin
            w_valid <= m_valid;
            w_pc    <= m_pc;
            w_instr <= m_instr;
            w_rd    <= m_rd;
            w_we    <= m_we;
            w_data  <= m_wb_data;
        end
    end

    // ========================================================================
    // Control de pipeline y halt
    // ========================================================================
    erv26_hazard_unit u_hz (
        .en(en), .mem_req(m_mem_op), .mem_ready(m_mem_ok),
        .d_valid(d_valid), .d_rs1(d_rs1), .d_rs2(d_rs2),
        .d_use_rs1(d_use_rs1), .d_use_rs2(d_use_rs2),
        .e_valid(e_valid), .e_load(e_load), .e_rd(e_rd), .e_redirect(e_redirect),
        .freeze(freeze), .load_use(load_use), .flush_id(flush_id)
    );

    // ========================================================================
    // Debug: instruccion retirada (sale de WB este ciclo)
    // ========================================================================
    assign dbg_commit       = w_valid & ~freeze;
    assign dbg_commit_pc    = w_pc;
    assign dbg_commit_instr = w_instr;
    assign dbg_commit_we    = w_we & (w_rd != 5'd0);
    assign dbg_commit_rd    = w_rd;
    assign dbg_commit_data  = w_data;

endmodule
