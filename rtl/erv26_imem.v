// ============================================================================
// ERV26 - Memoria de programa para el pipeline
//   Palabras de 32 bits, lectura SINCRONICA (se infiere en M10K).
//   addr es direccion de byte; se usan los bits [AW+1:2].
//   INIT_FILE: una palabra hexa por linea (erv26asm.py --words, o
//   tools/elf2hex.py para programas compilados con gcc).
// ============================================================================
module erv26_imem #(
    parameter AW        = 12,                // palabras = 2^AW (16 KB)
    parameter INIT_FILE = "imem.hex"
) (
    input  wire        clk,
    input  wire [31:0] addr,
    output reg  [31:0] rdata
);
    reg [31:0] mem [0:(1<<AW)-1];

    initial begin
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    always @(posedge clk)
        rdata <= mem[addr[AW+1:2]];
endmodule
