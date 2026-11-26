// ============================================================================
// ERV26 - Latch ID/EX
//   Se congela con freeze. Inserta una burbuja (e_valid = 0) si ID esta
//   vacio, si hay stall load-use o si un salto tomado en EX descarta ID.
// ============================================================================
module erv26_id_ex (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        freeze,
    input  wire        load_use,
    input  wire        flush_id,
    input  wire        d_valid,
    input  wire [31:0] d_pc,
    input  wire [31:0] d_instr,
    input  wire [31:0] d_imm,
    input  wire [31:0] d_rs1_val,
    input  wire [31:0] d_rs2_val,
    input  wire [4:0]  d_rd,
    input  wire [4:0]  d_rs1,
    input  wire [4:0]  d_rs2,
    input  wire [2:0]  d_funct3,
    input  wire [3:0]  d_alu_op,
    input  wire [1:0]  d_alu_src_a,
    input  wire [1:0]  d_wb_sel,
    input  wire        d_use_imm,
    input  wire        d_we,
    input  wire        d_load,
    input  wire        d_store,
    input  wire        d_is_branch,
    input  wire        d_is_jalr,
    input  wire        d_pred_taken,
    output reg         e_valid,
    output reg  [31:0] e_pc,
    output reg  [31:0] e_instr,
    output reg  [31:0] e_imm,
    output reg  [31:0] e_rs1_val,
    output reg  [31:0] e_rs2_val,
    output reg  [4:0]  e_rd,
    output reg  [4:0]  e_rs1,
    output reg  [4:0]  e_rs2,
    output reg  [2:0]  e_funct3,
    output reg  [3:0]  e_alu_op,
    output reg  [1:0]  e_alu_src_a,
    output reg  [1:0]  e_wb_sel,
    output reg         e_use_imm,
    output reg         e_we,
    output reg         e_load,
    output reg         e_store,
    output reg         e_is_branch,
    output reg         e_is_jalr,
    output reg         e_pred_taken
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            e_valid <= 1'b0;
        end else if (!freeze) begin
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
            e_we        <= d_we;
            e_load      <= d_load;
            e_store     <= d_store;
            e_is_branch <= d_is_branch;
            e_is_jalr   <= d_is_jalr;
            e_pred_taken <= d_pred_taken;
        end
    end
endmodule
