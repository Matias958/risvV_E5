// ============================================================================
// ERV26 - Banco de registros
//   31 registros de 32 bits (x1..x31), x0 = 0 constante.
//   2 puertos de lectura combinacionales (opcion 1 del enunciado),
//   1 puerto de escritura sincronico (flanco ascendente),
//   1 puerto de lectura extra para debug (LEDs / SignalTap).
//
//   WRITE_THROUGH = 1 (pipeline, valor por defecto): si en el mismo ciclo se escribe y se lee el
//   mismo registro, la lectura devuelve el dato nuevo (bypass WB -> ID).
//   Equivale a "escribir en la primera mitad del ciclo y leer en la segunda"
//   pero sin usar el flanco descendente.
//   WRITE_THROUGH = 0 (MVP-0 single-cycle): obligatorio, porque ahi rd_data
//   depende combinacionalmente de rs1_data y el bypass formaria un lazo.
// ============================================================================
module erv26_regfile #(
    parameter WRITE_THROUGH = 1
) (
    input  wire        clk,
    // Escritura (write-back)
    input  wire        we,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,
    // Lectura
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data,
    // Debug
    input  wire [4:0]  dbg_addr,
    output wire [31:0] dbg_data
);
    reg [31:0] regs [1:31];

    integer i;
    initial begin
        for (i = 1; i < 32; i = i + 1) regs[i] = 32'd0;
    end

    // Escritura: cualquier intento de escribir x0 se ignora
    always @(posedge clk) begin
        if (we && (rd_addr != 5'd0))
            regs[rd_addr] <= rd_data;
    end

    wire byp1 = (WRITE_THROUGH != 0) && we && (rd_addr == rs1_addr);
    wire byp2 = (WRITE_THROUGH != 0) && we && (rd_addr == rs2_addr);

    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : byp1 ? rd_data : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : byp2 ? rd_data : regs[rs2_addr];
    assign dbg_data = (dbg_addr == 5'd0) ? 32'd0 : regs[dbg_addr];

endmodule
