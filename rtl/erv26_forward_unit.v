// ============================================================================
// ERV26 - Forwarding (etapa EX)
//   Para cada operando de la instruccion en EX elige el valor mas nuevo:
//     1. resultado en EX/MEM (instruccion anterior)       - prioridad
//     2. resultado en MEM/WB (dos instrucciones antes)
//     3. valor leido del banco en ID
//   Un LOAD en EX/MEM nunca es fuente: su dato no existe todavia, y el
//   control de hazards (load_use) garantiza que ese caso no se presente.
// ============================================================================
module erv26_forward_unit (
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [31:0] rs1_id,      // valor capturado en ID
    input  wire [31:0] rs2_id,
    // EX/MEM
    input  wire        m_valid,
    input  wire        m_we,
    input  wire        m_load,
    input  wire [4:0]  m_rd,
    input  wire [31:0] m_result,
    // MEM/WB
    input  wire        w_valid,
    input  wire        w_we,
    input  wire [4:0]  w_rd,
    input  wire [31:0] w_data,

    output wire [31:0] rs1_fwd,
    output wire [31:0] rs2_fwd
);
    wire m_src = m_valid & m_we & ~m_load & (m_rd != 5'd0);
    wire w_src = w_valid & w_we & (w_rd != 5'd0);

    assign rs1_fwd = (m_src && m_rd == rs1) ? m_result :
                     (w_src && w_rd == rs1) ? w_data   : rs1_id;

    assign rs2_fwd = (m_src && m_rd == rs2) ? m_result :
                     (w_src && w_rd == rs2) ? w_data   : rs2_id;
endmodule
