// ============================================================================
// ERV26 - Perifericos de E/S mapeados en memoria (base 0x8000_0000)
//   +0x00  LEDs       (W/R)  8 bits
//   +0x04  switches   (R)    4 bits, sincronizados
//   +0x08  ciclos     (R)    contador libre de 32 bits a la frecuencia del clock
//   +0x0C  botones    (R)    4 bits, 1 = apretado (GPIO_0[3:0], activos en bajo)
//   +0x10  cuadros    (R)    cuenta los blanking verticales del video (60 Hz)
//   +0x14  video      (W)    bit 0: pagina del framebuffer que se muestra
//                    (R)    bit 0: pagina pedida, bit 1: en blanking vertical
//   Responde en el mismo ciclo (ready = req).
//
//   Se usa E/S mapeada en memoria en lugar de atar x28-x31 a puertos (como
//   sugiere el enunciado) porque gcc usa esos registros (t3-t6) libremente.
// ============================================================================
module erv26_io (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        req,
    input  wire        we,
    input  wire [3:0]  be,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output wire        ready,
    input  wire [3:0]  sw,
    output reg  [7:0]  leds,
    input  wire [3:0]  btn_n,         // botones del GPIO, activos en bajo
    input  wire        frame_tick,    // del controlador de video
    input  wire        vblank,
    output reg         disp_page      // pagina del framebuffer a mostrar
);
    reg [3:0]  sw_s1, sw_s2;
    reg [3:0]  bt_s1, bt_s2;
    reg [31:0] cycles;
    reg [31:0] frames;

    always @(posedge clk) begin
        sw_s1 <= sw;     sw_s2 <= sw_s1;
        bt_s1 <= ~btn_n; bt_s2 <= bt_s1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            leds      <= 8'd0;
            cycles    <= 32'd0;
            frames    <= 32'd0;
            disp_page <= 1'b0;
        end else begin
            cycles <= cycles + 32'd1;
            if (frame_tick) frames <= frames + 32'd1;
            if (req && we && addr[4:2] == 3'd0 && be[0]) leds      <= wdata[7:0];
            if (req && we && addr[4:2] == 3'd5 && be[0]) disp_page <= wdata[0];
        end
    end

    always @(*) begin
        case (addr[4:2])
            3'd0:    rdata = {24'd0, leds};
            3'd1:    rdata = {28'd0, sw_s2};
            3'd2:    rdata = cycles;
            3'd3:    rdata = {28'd0, bt_s2};
            3'd4:    rdata = frames;
            3'd5:    rdata = {30'd0, vblank, disp_page};
            default: rdata = 32'd0;
        endcase
    end

    assign ready = req;
endmodule
