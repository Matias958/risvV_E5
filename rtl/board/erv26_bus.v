// ============================================================================
// ERV26 - Decodificador del bus de datos (bloque para el top .bdf)
//   addr[31]    = 1 -> E/S mapeada en memoria (0x8000_0000)
//   addr[31:30] = 01 -> framebuffer de video (0x4000_0000)
//   si no            -> memoria de datos (M10K)
//   Reparte req y multiplexa rdata/ready hacia el nucleo.
// ============================================================================
module erv26_bus (
    // Desde el nucleo
    input  wire        dmem_req,
    input  wire [31:0] dmem_addr,
    output wire [31:0] dmem_rdata,
    output wire        dmem_ready,
    // Memoria de datos
    output wire        ram_req,
    input  wire [31:0] ram_rdata,
    input  wire        ram_ready,
    // Framebuffer de video
    output wire        vram_req,
    input  wire [31:0] vram_rdata,
    input  wire        vram_ready,
    // E/S
    output wire        io_req,
    input  wire [31:0] io_rdata,
    input  wire        io_ready
);
    wire io_sel   =  dmem_addr[31];
    wire vram_sel = ~dmem_addr[31] & dmem_addr[30];

    assign io_req     = dmem_req &  io_sel;
    assign vram_req   = dmem_req &  vram_sel;
    assign ram_req    = dmem_req & ~io_sel & ~vram_sel;
    assign dmem_rdata = io_sel ? io_rdata  : vram_sel ? vram_rdata : ram_rdata;
    assign dmem_ready = io_sel ? io_ready  : vram_sel ? vram_ready : ram_ready;
endmodule
