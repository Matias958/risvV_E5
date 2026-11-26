// ============================================================================
// ERV26 - Latch MEM/WB (se congela con freeze)
// ============================================================================
module erv26_mem_wb (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        freeze,
    input  wire        m_valid,
    input  wire [31:0] m_pc,
    input  wire [31:0] m_instr,
    input  wire [4:0]  m_rd,
    input  wire        m_we,
    input  wire [31:0] m_wb_data,
    output reg         w_valid,
    output reg  [31:0] w_pc,
    output reg  [31:0] w_instr,
    output reg  [4:0]  w_rd,
    output reg         w_we,
    output reg  [31:0] w_data
);
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
endmodule
