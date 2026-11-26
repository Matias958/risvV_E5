// ============================================================================
// ERV26 - MEM: dato a escribir en el banco (load o resultado de EX)
// ============================================================================
module erv26_wb_select (
    input  wire        m_load,
    input  wire [31:0] load_data,
    input  wire [31:0] result,
    output wire [31:0] wb_data
);
    assign wb_data = m_load ? load_data : result;
endmodule
