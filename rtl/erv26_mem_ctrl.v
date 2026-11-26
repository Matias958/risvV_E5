// ============================================================================
// ERV26 - MEM: control del acceso a memoria de datos (handshake memory_ready)
//   Protocolo: req/addr/we se mantienen estables hasta ver ready.
//   Si ready llega en un ciclo en que el pipeline esta congelado por otro
//   motivo (en=0), se recuerda que el acceso ya se hizo (m_done) y se guarda
//   el dato leido. Asi un store nunca se ejecuta dos veces (importante con
//   perifericos, p.ej. una UART) y no se pierde el dato.
//
//   dmem_addr_next: direccion que va a tener la instruccion de MEM en el
//   ciclo siguiente. Si el pipeline avanza es la de la instruccion en EX
//   (e_result); si esta congelado, la misma de ahora. La memoria de datos
//   (M10K, lectura sincronica) la usa para leer por adelantado y tener el
//   dato del load listo apenas el load llega a MEM.
// ============================================================================
module erv26_mem_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        freeze,
    input  wire        m_valid,
    input  wire        m_load,
    input  wire        m_store,
    input  wire [31:0] m_result,      // direccion del load/store
    input  wire [31:0] e_result,      // direccion del load/store que esta en EX
    input  wire [31:0] dmem_rdata,
    input  wire        dmem_ready,
    output wire        dmem_req,
    output wire        dmem_we,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_addr_next,
    output wire        m_mem_op,      // hay un acceso en MEM -> hazard unit
    output wire        m_mem_ok,      // el acceso termino      -> hazard unit
    output wire [31:0] m_rdata        // palabra leida -> LSU
);
    reg        m_done;
    reg [31:0] m_rdata_hold;

    assign m_mem_op  = m_valid & (m_load | m_store);
    assign m_mem_ok  = m_done | dmem_ready;
    assign dmem_req  = m_mem_op & ~m_done;
    assign dmem_we   = m_store;
    assign dmem_addr      = m_result;
    assign dmem_addr_next = freeze ? m_result : e_result;
    assign m_rdata   = m_done ? m_rdata_hold : dmem_rdata;

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
endmodule
