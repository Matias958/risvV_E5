// ============================================================================
// ERV26 - Latch EX/MEM (se congela con freeze)
// ============================================================================
module erv26_ex_mem (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        freeze,
    input  wire        e_valid,
    input  wire [31:0] e_pc,
    input  wire [31:0] e_instr,
    input  wire [4:0]  e_rd,
    input  wire        e_we,
    input  wire        e_load,
    input  wire        e_store,
    input  wire [2:0]  e_funct3,
    input  wire [31:0] e_result,
    input  wire [31:0] e_store_data,
    output reg         m_valid,
    output reg  [31:0] m_pc,
    output reg  [31:0] m_instr,
    output reg  [4:0]  m_rd,
    output reg         m_we,
    output reg         m_load,
    output reg         m_store,
    output reg  [2:0]  m_funct3,
    output reg  [31:0] m_result,
    output reg  [31:0] m_store_data
);
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
            m_result     <= e_result;
            m_store_data <= e_store_data;
        end
    end
endmodule
