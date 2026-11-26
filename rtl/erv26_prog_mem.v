// ============================================================================
// ERV26 - Memoria de programa (MVP-0)
//   Memoria organizada en bytes (8 bits) con salida de 4 bytes / 32 bits,
//   little-endian, accedida "saltando de a 4". Lectura combinacional.
//
//   Se inicializa con $readmemh desde un archivo con UN BYTE POR LINEA
//   (lo genera tools/erv26asm.py). Quartus acepta $readmemh en initial.
//
//   Nota FPGA: la lectura asincronica no se infiere en M10K; con DEPTH chico
//   Quartus la arma con logica/MLAB, que alcanza para el MVP-0. En el
//   pipeline se reemplaza por una M10K de lectura sincronica.
// ============================================================================
module erv26_prog_mem #(
    parameter DEPTH    = 1024,               // bytes
    parameter AW       = 10,                 // log2(DEPTH)
    parameter INIT_FILE = "program.hex"
) (
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    reg [7:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) mem[i] = 8'h00;
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    // Direccion alineada a palabra
    wire [AW-1:0] a0 = {addr[AW-1:2], 2'b00};

    assign instr = { mem[a0 + 3], mem[a0 + 2], mem[a0 + 1], mem[a0] };
endmodule
