// ============================================================================
// ERV26 - Memoria de datos en BRAM con handshake memory_ready
//   32 bits, byte enables, lectura sincronica (M10K).
//   Se arma con 4 bancos de 8 bits (uno por byte enable) para que Quartus la
//   infiera en M10K con Verilog-2001.
//
//   Lectura anticipada: la M10K registra la direccion en el flanco y entrega
//   el dato despues. Para no perder un ciclo en cada load, el nucleo da en
//   addr_next la direccion que va a tener la instruccion de MEM en el ciclo
//   siguiente (la del load que esta en EX, o la misma de MEM si el pipeline
//   esta congelado). En el flanco en que el load pasa a MEM la memoria ya
//   registra su direccion, y durante MEM el dato esta listo.
//
//   Protocolo (igual para cualquier memoria/periferico del bus):
//     - El nucleo pone req=1 con addr/we/be/wdata y los mantiene estables
//       hasta ver ready=1.
//     - Escritura: ready=1 en el mismo ciclo (se escribe en el flanco).
//     - Lectura  : ready=1 si la direccion registrada coincide con addr y esa
//       lectura es valida. Si no (direccion anticipada distinta, o una
//       escritura a la misma palabra en el mismo flanco), ready=0 un ciclo:
//       como el pipeline se congela, addr_next pasa a ser addr y en el ciclo
//       siguiente el dato esta listo. Nunca se entrega un dato equivocado;
//       en el peor caso se pierde un ciclo.
//
//   INIT_B0..3: contenido inicial (seccion .data), un byte hexa por linea.
// ============================================================================
module erv26_dmem #(
    parameter AW      = 12,                  // palabras = 2^AW (16 KB)
    // Por defecto toma los archivos que deja sw/build.py, asi el bloque del
    // .bdf no necesita parametros.
    parameter INIT_B0 = "dmem_b0.hex",       // byte 0 de cada palabra
    parameter INIT_B1 = "dmem_b1.hex",
    parameter INIT_B2 = "dmem_b2.hex",
    parameter INIT_B3 = "dmem_b3.hex"
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        req,
    input  wire        we,
    input  wire [3:0]  be,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [31:0] addr_next,   // direccion de lectura anticipada (del nucleo)
    output wire [31:0] rdata,
    output wire        ready
);
    // no_rw_check: si se lee y escribe la misma palabra en el mismo flanco el
    // dato leido no importa (ready=0 en ese caso), asi que Quartus no agrega
    // logica de bypass alrededor de la M10K.
    (* ramstyle = "M10K, no_rw_check" *) reg [7:0] b0 [0:(1<<AW)-1];
    (* ramstyle = "M10K, no_rw_check" *) reg [7:0] b1 [0:(1<<AW)-1];
    (* ramstyle = "M10K, no_rw_check" *) reg [7:0] b2 [0:(1<<AW)-1];
    (* ramstyle = "M10K, no_rw_check" *) reg [7:0] b3 [0:(1<<AW)-1];

    // Un archivo por carril de byte (lo generan las herramientas), asi Quartus
    // inicializa cada M10K directamente.
    initial begin
        if (INIT_B0 != "") $readmemh(INIT_B0, b0);
        if (INIT_B1 != "") $readmemh(INIT_B1, b1);
        if (INIT_B2 != "") $readmemh(INIT_B2, b2);
        if (INIT_B3 != "") $readmemh(INIT_B3, b3);
    end

    wire [AW-1:0] wa = addr[AW+1:2];          // escritura y comparacion: MEM
    wire [AW-1:0] ra = addr_next[AW+1:2];     // lectura anticipada
    wire          wr = req & we;

    reg [7:0]    q0, q1, q2, q3;
    reg [AW-1:0] ra_q  = {AW{1'b0}};          // direccion de la lectura en curso
    reg          rd_ok = 1'b0;                // esa lectura no choco con una escritura
    always @(posedge clk) begin
        if (wr & be[0]) b0[wa] <= wdata[7:0];
        if (wr & be[1]) b1[wa] <= wdata[15:8];
        if (wr & be[2]) b2[wa] <= wdata[23:16];
        if (wr & be[3]) b3[wa] <= wdata[31:24];
        q0 <= b0[ra]; q1 <= b1[ra]; q2 <= b2[ra]; q3 <= b3[ra];
        ra_q  <= ra;
        rd_ok <= ~(wr & (wa == ra));
    end

    // Si rd_ok=0 (lectura y escritura de la misma palabra en el mismo flanco)
    // la M10K entrega un valor indefinido; ready=0 garantiza que no se use.
    // El testbench (tb_core, modo +MEM_RTL) lo reemplaza por DEADBEEF para
    // que un uso indebido aparezca en los tests.
    assign rdata = {q3, q2, q1, q0};

    assign ready = req & (we | (rd_ok & (ra_q == wa)));
endmodule
