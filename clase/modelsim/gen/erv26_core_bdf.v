module erv26_core (
    input  wire [0:0] clk,
    input  wire [0:0] rst_n,
    input  wire [0:0] en,
    input  wire [31:0] imem_rdata,
    input  wire [31:0] dmem_rdata,
    input  wire [0:0] dmem_ready,
    input  wire [4:0] dbg_reg_sel,
    output wire [31:0] imem_addr,
    output wire [0:0] dmem_req,
    output wire [0:0] dmem_we,
    output wire [3:0] dmem_be,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [31:0] dmem_addr_next,
    output wire [31:0] dbg_reg_data,
    output wire [0:0] dbg_commit,
    output wire [31:0] dbg_commit_pc,
    output wire [31:0] dbg_commit_instr,
    output wire [0:0] dbg_commit_we,
    output wire [4:0] dbg_commit_rd,
    output wire [31:0] dbg_commit_data
);
    wire [0:0] freeze;
    wire [0:0] load_use;
    wire [0:0] e_redirect;
    wire [31:0] e_target;
    wire [0:0] d_redirect;
    wire [31:0] d_target;
    wire [31:0] d_pc;
    wire [0:0] d_valid;
    wire [4:0] d_rd;
    wire [4:0] d_rs1;
    wire [4:0] d_rs2;
    wire [2:0] d_funct3;
    wire [2:0] d_fmt;
    wire [0:0] d_reg_write;
    wire [0:0] d_use_rs1;
    wire [0:0] d_use_rs2;
    wire [0:0] d_use_imm;
    wire [1:0] d_alu_src_a;
    wire [3:0] d_alu_op;
    wire [0:0] d_is_branch;
    wire [0:0] d_is_jal;
    wire [0:0] d_is_jalr;
    wire [0:0] d_mem_read;
    wire [0:0] d_mem_write;
    wire [1:0] d_wb_sel;
    wire [31:0] d_imm;
    wire [0:0] d_pred_taken;
    wire [0:0] rf_we;
    wire [4:0] w_rd;
    wire [31:0] w_data;
    wire [31:0] d_rs1_val;
    wire [31:0] d_rs2_val;
    wire [0:0] m_mem_op;
    wire [0:0] m_mem_ok;
    wire [0:0] e_valid;
    wire [0:0] e_load;
    wire [4:0] e_rd;
    wire [0:0] flush_id;
    wire [31:0] e_pc;
    wire [31:0] e_instr;
    wire [31:0] e_imm;
    wire [31:0] e_rs1_val;
    wire [31:0] e_rs2_val;
    wire [4:0] e_rs1;
    wire [4:0] e_rs2;
    wire [2:0] e_funct3;
    wire [3:0] e_alu_op;
    wire [1:0] e_alu_src_a;
    wire [1:0] e_wb_sel;
    wire [0:0] e_use_imm;
    wire [0:0] e_we;
    wire [0:0] e_store;
    wire [0:0] e_is_branch;
    wire [0:0] e_is_jalr;
    wire [0:0] e_pred_taken;
    wire [0:0] m_valid;
    wire [0:0] m_we;
    wire [0:0] m_load;
    wire [4:0] m_rd;
    wire [31:0] m_result;
    wire [0:0] w_valid;
    wire [0:0] w_we;
    wire [31:0] e_rs1_fwd;
    wire [31:0] e_rs2_fwd;
    wire [31:0] e_op_a;
    wire [31:0] e_op_b;
    wire [31:0] e_alu_y;
    wire [31:0] e_result;
    wire [31:0] m_pc;
    wire [31:0] m_instr;
    wire [0:0] m_store;
    wire [2:0] m_funct3;
    wire [31:0] m_store_data;
    wire [31:0] m_rdata;
    wire [31:0] m_load_data;
    wire [31:0] m_wb_data;
    wire [31:0] w_pc;
    wire [31:0] w_instr;
    erv26_pc_select u_pc_sel (
        .freeze(freeze),
        .load_use(load_use),
        .e_redirect(e_redirect),
        .e_target(e_target),
        .d_redirect(d_redirect),
        .d_target(d_target),
        .d_pc(d_pc),
        .f_pc(imem_addr)
    );
    erv26_if_id u_if_id (
        .clk(clk),
        .rst_n(rst_n),
        .freeze(freeze),
        .load_use(load_use),
        .f_pc(imem_addr),
        .d_pc(d_pc),
        .d_valid(d_valid)
    );
    erv26_decoder u_dec (
        .inst(imem_rdata),
        .opcode(),
        .rd(d_rd),
        .rs1(d_rs1),
        .rs2(d_rs2),
        .funct3(d_funct3),
        .funct7(),
        .fmt(d_fmt),
        .reg_write(d_reg_write),
        .use_rs1(d_use_rs1),
        .use_rs2(d_use_rs2),
        .use_imm(d_use_imm),
        .alu_src_a(d_alu_src_a),
        .alu_op(d_alu_op),
        .is_branch(d_is_branch),
        .is_jal(d_is_jal),
        .is_jalr(d_is_jalr),
        .mem_read(d_mem_read),
        .mem_write(d_mem_write),
        .wb_sel(d_wb_sel),
        .is_system(),
        .illegal()
    );
    erv26_imm_gen u_imm (
        .inst(imem_rdata),
        .fmt(d_fmt),
        .imm(d_imm)
    );
    erv26_id_predict u_predict (
        .d_valid(d_valid),
        .is_jal(d_is_jal),
        .is_branch(d_is_branch),
        .pc(d_pc),
        .imm(d_imm),
        .redirect(d_redirect),
        .target(d_target),
        .pred_taken(d_pred_taken)
    );
    erv26_regfile u_rf (
        .clk(clk),
        .we(rf_we),
        .rd_addr(w_rd),
        .rd_data(w_data),
        .rs1_addr(d_rs1),
        .rs2_addr(d_rs2),
        .dbg_addr(dbg_reg_sel),
        .rs1_data(d_rs1_val),
        .rs2_data(d_rs2_val),
        .dbg_data(dbg_reg_data)
    );
    erv26_hazard_unit u_hazard (
        .en(en),
        .mem_req(m_mem_op),
        .mem_ready(m_mem_ok),
        .d_valid(d_valid),
        .d_rs1(d_rs1),
        .d_rs2(d_rs2),
        .d_use_rs1(d_use_rs1),
        .d_use_rs2(d_use_rs2),
        .e_valid(e_valid),
        .e_load(e_load),
        .e_rd(e_rd),
        .e_redirect(e_redirect),
        .freeze(freeze),
        .load_use(load_use),
        .flush_id(flush_id)
    );
    erv26_id_ex u_id_ex (
        .clk(clk),
        .rst_n(rst_n),
        .freeze(freeze),
        .load_use(load_use),
        .flush_id(flush_id),
        .d_valid(d_valid),
        .d_pc(d_pc),
        .d_instr(imem_rdata),
        .d_imm(d_imm),
        .d_rs1_val(d_rs1_val),
        .d_rs2_val(d_rs2_val),
        .d_rd(d_rd),
        .d_rs1(d_rs1),
        .d_rs2(d_rs2),
        .d_funct3(d_funct3),
        .d_alu_op(d_alu_op),
        .d_alu_src_a(d_alu_src_a),
        .d_wb_sel(d_wb_sel),
        .d_use_imm(d_use_imm),
        .d_we(d_reg_write),
        .d_load(d_mem_read),
        .d_store(d_mem_write),
        .d_is_branch(d_is_branch),
        .d_is_jalr(d_is_jalr),
        .d_pred_taken(d_pred_taken),
        .e_valid(e_valid),
        .e_pc(e_pc),
        .e_instr(e_instr),
        .e_imm(e_imm),
        .e_rs1_val(e_rs1_val),
        .e_rs2_val(e_rs2_val),
        .e_rd(e_rd),
        .e_rs1(e_rs1),
        .e_rs2(e_rs2),
        .e_funct3(e_funct3),
        .e_alu_op(e_alu_op),
        .e_alu_src_a(e_alu_src_a),
        .e_wb_sel(e_wb_sel),
        .e_use_imm(e_use_imm),
        .e_we(e_we),
        .e_load(e_load),
        .e_store(e_store),
        .e_is_branch(e_is_branch),
        .e_is_jalr(e_is_jalr),
        .e_pred_taken(e_pred_taken)
    );
    erv26_forward_unit u_fwd (
        .rs1(e_rs1),
        .rs2(e_rs2),
        .rs1_id(e_rs1_val),
        .rs2_id(e_rs2_val),
        .m_valid(m_valid),
        .m_we(m_we),
        .m_load(m_load),
        .m_rd(m_rd),
        .m_result(m_result),
        .w_valid(w_valid),
        .w_we(w_we),
        .w_rd(w_rd),
        .w_data(w_data),
        .rs1_fwd(e_rs1_fwd),
        .rs2_fwd(e_rs2_fwd)
    );
    erv26_operand_build u_opb (
        .alu_src_a(e_alu_src_a),
        .use_imm(e_use_imm),
        .rs1_data(e_rs1_fwd),
        .rs2_data(e_rs2_fwd),
        .pc(e_pc),
        .imm(e_imm),
        .op_a(e_op_a),
        .op_b(e_op_b)
    );
    erv26_alu u_alu (
        .a(e_op_a),
        .b(e_op_b),
        .alu_op(e_alu_op),
        .y(e_alu_y)
    );
    erv26_branch_unit u_br (
        .valid(e_valid),
        .is_branch(e_is_branch),
        .is_jalr(e_is_jalr),
        .funct3(e_funct3),
        .rs1(e_rs1_fwd),
        .rs2(e_rs2_fwd),
        .pc(e_pc),
        .imm(e_imm),
        .pred_taken(e_pred_taken),
        .redirect(e_redirect),
        .target(e_target)
    );
    erv26_ex_result u_ex_res (
        .wb_sel(e_wb_sel),
        .pc(e_pc),
        .alu_y(e_alu_y),
        .result(e_result)
    );
    erv26_ex_mem u_ex_mem (
        .clk(clk),
        .rst_n(rst_n),
        .freeze(freeze),
        .e_valid(e_valid),
        .e_pc(e_pc),
        .e_instr(e_instr),
        .e_rd(e_rd),
        .e_we(e_we),
        .e_load(e_load),
        .e_store(e_store),
        .e_funct3(e_funct3),
        .e_result(e_result),
        .e_store_data(e_rs2_fwd),
        .m_valid(m_valid),
        .m_pc(m_pc),
        .m_instr(m_instr),
        .m_rd(m_rd),
        .m_we(m_we),
        .m_load(m_load),
        .m_store(m_store),
        .m_funct3(m_funct3),
        .m_result(m_result),
        .m_store_data(m_store_data)
    );
    erv26_mem_ctrl u_mem_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .freeze(freeze),
        .m_valid(m_valid),
        .m_load(m_load),
        .m_store(m_store),
        .m_result(m_result),
        .e_result(e_result),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        .dmem_req(dmem_req),
        .dmem_we(dmem_we),
        .dmem_addr(dmem_addr),
        .dmem_addr_next(dmem_addr_next),
        .m_mem_op(m_mem_op),
        .m_mem_ok(m_mem_ok),
        .m_rdata(m_rdata)
    );
    erv26_lsu u_lsu (
        .funct3(m_funct3),
        .addr_lo(m_result[1:0]),
        .store_data(m_store_data),
        .rdata(m_rdata),
        .be(dmem_be),
        .wdata(dmem_wdata),
        .load_data(m_load_data)
    );
    erv26_wb_select u_wb_sel (
        .m_load(m_load),
        .load_data(m_load_data),
        .result(m_result),
        .wb_data(m_wb_data)
    );
    erv26_mem_wb u_mem_wb (
        .clk(clk),
        .rst_n(rst_n),
        .freeze(freeze),
        .m_valid(m_valid),
        .m_pc(m_pc),
        .m_instr(m_instr),
        .m_rd(m_rd),
        .m_we(m_we),
        .m_wb_data(m_wb_data),
        .w_valid(w_valid),
        .w_pc(w_pc),
        .w_instr(w_instr),
        .w_rd(w_rd),
        .w_we(w_we),
        .w_data(w_data)
    );
    erv26_wb_commit u_wb_commit (
        .freeze(freeze),
        .w_valid(w_valid),
        .w_we(w_we),
        .w_rd(w_rd),
        .w_data(w_data),
        .w_pc(w_pc),
        .w_instr(w_instr),
        .rf_we(rf_we),
        .dbg_commit(dbg_commit),
        .dbg_commit_pc(dbg_commit_pc),
        .dbg_commit_instr(dbg_commit_instr),
        .dbg_commit_we(dbg_commit_we),
        .dbg_commit_rd(dbg_commit_rd),
        .dbg_commit_data(dbg_commit_data)
    );
endmodule
