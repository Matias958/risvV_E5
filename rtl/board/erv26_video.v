// ============================================================================
// ERV26 - Controlador de video para el ADV7513 (HDMI) de la DE10-Nano
//
//   Salida 640x480 a 60 Hz (pixel de 25 MHz = 50 MHz / 2). Todo corre con el
//   mismo reloj de 50 MHz que el procesador: no hay cruce de dominios.
//
//   Framebuffer doble en M10K: 2 paginas de 320x240 pixeles, 1 byte por
//   pixel en formato RGB332 (RRRGGGBB). Cada pixel se muestra como 2x2.
//     pagina 0: VRAM + 0x00000 .. 0x12BFF   (76 800 bytes)
//     pagina 1: VRAM + 0x12C00 .. 0x257FF
//   El procesador solo escribe (las lecturas devuelven 0). Escrituras de
//   byte, media palabra o palabra, sin espera (ready = req).
//
//   disp_page elige la pagina que se muestra; se toma al empezar el blanking
//   vertical (frame_tick), asi el cambio de pagina nunca corta una imagen.
//
//   Timing VESA 640x480@60: H 640+16+96+48 = 800, V 480+10+2+33 = 525,
//   sincronismos activos en bajo. El ADV7513 toma los datos en el flanco
//   ascendente de hdmi_clk; los datos cambian en el descendente.
// ============================================================================
module erv26_video (
    input  wire        clk,
    input  wire        rst_n,
    // Bus de datos (region VRAM)
    input  wire        req,
    input  wire        we,
    input  wire [3:0]  be,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata,
    output wire        ready,
    // Control
    input  wire        disp_page,     // pagina a mostrar (desde erv26_io)
    output reg         frame_tick,    // 1 ciclo al empezar cada blanking vertical
    output wire        vblank,
    // ADV7513
    output reg         hdmi_clk,
    output reg  [23:0] hdmi_d,        // R[23:16] G[15:8] B[7:0]
    output reg         hdmi_de,
    output reg         hdmi_hs,
    output reg         hdmi_vs
);
    localparam NW = 2 * 19200;        // palabras de 32 bits (2 paginas)

    // ---------------- VRAM: 4 bancos de 8 bits ----------------
    (* ramstyle = "M10K, no_rw_check" *) reg [7:0] v0 [0:NW-1];
    (* ramstyle = "M10K, no_rw_check" *) reg [7:0] v1 [0:NW-1];
    (* ramstyle = "M10K, no_rw_check" *) reg [7:0] v2 [0:NW-1];
    (* ramstyle = "M10K, no_rw_check" *) reg [7:0] v3 [0:NW-1];

    wire [15:0] wa = addr[17:2];
    wire        wr = req & we & (wa < NW);

    // ---------------- Contadores de video ----------------
    reg        ph;                    // 0/1: dos ciclos de 50 MHz por pixel
    reg [9:0]  hc, vc;                // 0..799, 0..524
    reg        page_l;                // pagina que se esta mostrando

    wire [8:0]  sx = hc[9:1];         // pixel fuente 0..319 (hc < 640)
    wire [7:0]  sy = vc[8:1];         // linea fuente 0..239 (vc < 480)
    wire [15:0] ra = (page_l ? 16'd19200 : 16'd0)
                   + {2'b00, sy, 6'b0} + {4'b00, sy, 4'b0}   // sy * 80
                   + {9'd0, sx[8:2]};

    reg [7:0] q0, q1, q2, q3;
    always @(posedge clk) begin
        if (wr & be[0]) v0[wa] <= wdata[7:0];
        if (wr & be[1]) v1[wa] <= wdata[15:8];
        if (wr & be[2]) v2[wa] <= wdata[23:16];
        if (wr & be[3]) v3[wa] <= wdata[31:24];
        q0 <= v0[ra]; q1 <= v1[ra]; q2 <= v2[ra]; q3 <= v3[ra];
    end

    assign rdata = 32'd0;
    assign ready = req;

    // Byte del pixel actual y expansion RGB332 -> RGB888
    reg [7:0] px;
    always @(*) begin
        case (sx[1:0])
            2'd0: px = q0;
            2'd1: px = q1;
            2'd2: px = q2;
            default: px = q3;
        endcase
    end
    wire [23:0] rgb = {px[7:5], px[7:5], px[7:6],
                       px[4:2], px[4:2], px[4:3],
                       px[1:0], px[1:0], px[1:0], px[1:0]};

    wire active = (hc < 10'd640) && (vc < 10'd480);
    assign vblank = (vc >= 10'd480);

    // Los contadores cambian cada 2 ciclos; la M10K se lee en el primero
    // (ph=0) y en el segundo (ph=1) el dato ya esta: se registra la salida
    // y se avanza al pixel siguiente.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ph <= 1'b0; hc <= 10'd0; vc <= 10'd0; page_l <= 1'b0;
            frame_tick <= 1'b0; hdmi_clk <= 1'b0;
            hdmi_d <= 24'd0; hdmi_de <= 1'b0; hdmi_hs <= 1'b1; hdmi_vs <= 1'b1;
        end else begin
            ph         <= ~ph;
            hdmi_clk   <= ~ph;            // baja cuando cambian los datos
            frame_tick <= 1'b0;
            if (ph) begin
                hdmi_d  <= active ? rgb : 24'd0;
                hdmi_de <= active;
                hdmi_hs <= ~((hc >= 10'd656) && (hc < 10'd752));
                hdmi_vs <= ~((vc >= 10'd490) && (vc < 10'd492));
                if (hc == 10'd799) begin
                    hc <= 10'd0;
                    if (vc == 10'd524) vc <= 10'd0;
                    else               vc <= vc + 10'd1;
                    if (vc == 10'd479) begin        // empieza el blanking
                        page_l     <= disp_page;
                        frame_tick <= 1'b1;
                    end
                end else
                    hc <= hc + 10'd1;
            end
        end
    end
endmodule
