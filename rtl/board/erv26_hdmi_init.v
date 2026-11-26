// ============================================================================
// ERV26 - Configuracion del transmisor HDMI ADV7513 por I2C
//
//   Escribe la lista de registros de abajo (direccion I2C 0x72) y la repite
//   cada ~0,7 s: si se desenchufa el cable (HPD bajo), el ADV7513 se apaga y
//   resetea registros, y al volver a enchufar queda configurado solo.
//
//   I2C a ~100 kHz, solo escritura, colector abierto (1 = alta impedancia;
//   la placa tiene pull-ups). No lee los ACK: es una secuencia fija.
//
//   Registros (ADV7513 Programming Guide, secciones 4.2 y 4.3):
//     0x41 = 0x10  encender (0x41[6] = 0)
//     0x98/9A/9C/9D/A2/A3/E0/F9: registros fijos obligatorios (tabla 14)
//     0x15 = 0x00  entrada RGB 4:4:4 de 24 bits con sincronismos separados
//     0x16 = 0x30  salida 4:4:4, 8 bits por color
//     0x17 = 0x00  relacion de aspecto 4:3
//     0x18 = 0x46  conversion de espacio de color desactivada
//     0x40 = 0x80  paquete de control general
//     0x55 = 0x10  AVI infoframe: RGB
//     0x56 = 0x08  AVI infoframe: aspecto activo = el de la imagen
//     0xAF = 0x06  modo HDMI
//     0xD6 = 0xC0  HPD siempre alto (enciende aunque el monitor tarde en HPD)
// ============================================================================
module erv26_hdmi_init #(
    parameter QDIV  = 125,            // 50 MHz / (4 * 125) = 100 kHz
    parameter WAITB = 25              // pausa entre configuraciones: 2^25 ciclos
) (
    input  wire clk,
    input  wire rst_n,
    output wire i2c_scl,              // colector abierto: 0 o z
    output wire i2c_sda,
    output reg  busy
);
    localparam N = 21;
    function [15:0] regval;           // {registro, valor}
        input [4:0] i;
        case (i)
            5'd0:  regval = 16'h4110;
            5'd1:  regval = 16'h9803;
            5'd2:  regval = 16'h9AE0;
            5'd3:  regval = 16'h9C30;
            5'd4:  regval = 16'h9D61;
            5'd5:  regval = 16'hA2A4;
            5'd6:  regval = 16'hA3A4;
            5'd7:  regval = 16'hE0D0;
            5'd8:  regval = 16'hF900;
            5'd9:  regval = 16'h1500;
            5'd10: regval = 16'h1630;
            5'd11: regval = 16'h1700;
            5'd12: regval = 16'h1846;
            5'd13: regval = 16'h4080;
            5'd14: regval = 16'h5510;
            5'd15: regval = 16'h5608;
            5'd16: regval = 16'hAF06;
            5'd17: regval = 16'hD6C0;
            5'd18: regval = 16'h4110;   // repetir encendido al final
            5'd19: regval = 16'h9803;
            default: regval = 16'h9AE0;
        endcase
    endfunction

    reg [7:0]       qcnt;             // divisor de cuarto de bit
    reg [WAITB-1:0] wcnt;             // pausa entre configuraciones
    reg [4:0]       idx;              // registro actual
    reg [1:0]       q;                // cuarto dentro del bit
    reg [4:0]       bitn;             // 0..26: 3 bytes x (8 bits + ACK)
    reg [1:0]       st;               // 0 espera, 1 START, 2 bits, 3 STOP
    reg             scl, sda;

    wire [15:0] rv    = regval(idx);
    wire [23:0] frame = {8'h72, rv};
    wire [4:0]  byten = (bitn >= 5'd18) ? 5'd2 : (bitn >= 5'd9) ? 5'd1 : 5'd0;
    wire [3:0]  pos   = bitn - byten * 5'd9;           // 0..8 (8 = ACK)
    wire [7:0]  cur   = (byten == 5'd0) ? frame[23:16] : (byten == 5'd1) ? frame[15:8] : frame[7:0];
    wire        dbit  = (pos == 4'd8) ? 1'b1 : cur[3'd7 - pos[2:0]];
    wire        tick  = (qcnt == QDIV - 1);

    assign i2c_scl = scl ? 1'bz : 1'b0;
    assign i2c_sda = sda ? 1'bz : 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qcnt <= 8'd0; wcnt <= {WAITB{1'b0}}; idx <= 5'd0; q <= 2'd0; bitn <= 5'd0;
            st <= 2'd0; scl <= 1'b1; sda <= 1'b1; busy <= 1'b0;
        end else begin
            qcnt <= tick ? 8'd0 : qcnt + 8'd1;
            case (st)
                2'd0: begin                                   // espera
                    scl <= 1'b1; sda <= 1'b1; busy <= 1'b0;
                    wcnt <= wcnt + 1'b1;
                    if (&wcnt) begin st <= 2'd1; idx <= 5'd0; q <= 2'd0; busy <= 1'b1; end
                end
                2'd1: if (tick) begin                         // START
                    case (q)
                        2'd0: begin scl <= 1'b1; sda <= 1'b1; end
                        2'd1: begin scl <= 1'b1; sda <= 1'b0; end
                        2'd2: begin scl <= 1'b0; sda <= 1'b0; end
                        2'd3: begin st <= 2'd2; bitn <= 5'd0; end
                    endcase
                    q <= q + 2'd1;
                end
                2'd2: if (tick) begin                         // bits
                    case (q)
                        2'd0: begin scl <= 1'b0; sda <= dbit; end
                        2'd1: scl <= 1'b1;
                        2'd2: scl <= 1'b1;
                        2'd3: begin
                            scl <= 1'b0;
                            if (bitn == 5'd26) st <= 2'd3;
                            else bitn <= bitn + 5'd1;
                        end
                    endcase
                    q <= q + 2'd1;
                end
                2'd3: if (tick) begin                         // STOP
                    case (q)
                        2'd0: begin scl <= 1'b0; sda <= 1'b0; end
                        2'd1: begin scl <= 1'b1; sda <= 1'b0; end
                        2'd2: begin scl <= 1'b1; sda <= 1'b1; end
                        2'd3: begin
                            if (idx == N - 1) st <= 2'd0;
                            else begin idx <= idx + 5'd1; st <= 2'd1; end
                        end
                    endcase
                    q <= q + 2'd1;
                end
            endcase
        end
    end
endmodule
