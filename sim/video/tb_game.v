// Simulacion de la placa completa corriendo el juego: maneja los botones del
// GPIO segun un guion por cuadro de video, captura la salida HDMI de algunos
// cuadros (PPM 640x480) y mide cuanto del cuadro usa el procesador.
`ifndef TOP
`define TOP de10nano_erv26_top   // o risvV_E5 (el top .bdf convertido con bdf2v)
`endif
`timescale 1ns/1ps
module tb_game;
    reg clk = 0; always #10 clk = ~clk;
    reg [1:0] key = 2'b10; reg [3:0] gpio_n = 4'hF;
    wire [7:0] led; wire hclk, de, hs, vs, scl, sda; wire [23:0] d;
    `TOP dut(.FPGA_CLK1_50(clk), .KEY(key), .SW(4'd0), .GPIO_0(gpio_n), .LED(led),
        .HDMI_TX_CLK(hclk), .HDMI_TX_D(d), .HDMI_TX_DE(de), .HDMI_TX_HS(hs), .HDMI_TX_VS(vs),
        .HDMI_I2C_SCL(scl), .HDMI_I2C_SDA(sda));
    integer vframe = 0, fd = 0, capturing = 0, nflips = 0, t_tick = 0, busy, busy_max = 0, f;
    integer maxf; reg [8*32-1:0] fname;
    initial begin
        if (!$value$plusargs("FRAMES=%d", maxf)) maxf = 12;
        repeat (5) @(posedge clk); key[0] = 1;
    end
    // botones (activos en bajo): 3 = start, 2 = fuego, 1 = derecha, 0 = izquierda
    always @(*) begin
        gpio_n = 4'hF;
        if (vframe == 3 || vframe == 4) gpio_n[3] = 0;
        if (vframe >= 6) begin gpio_n[2] = 0; gpio_n[1] = 0; end
    end
    // cuadros: en cada flanco de bajada del vsync
    always @(negedge vs) begin
        if (capturing) begin $fclose(fd); capturing = 0; end
        vframe = vframe + 1;
        if (vframe == 2 || vframe == 8 || vframe == maxf - 1) begin
            $sformat(fname, "game_%02d.ppm", vframe);
            fd = $fopen(fname, "wb"); $fwrite(fd, "P6\n640 480\n255\n"); capturing = 1;
        end
        $display("cuadro %0d: LEDs=%b paginas mostradas=%0d trabajo max=%0d%%", vframe, led, nflips,
                 busy_max * 100 / 840000);
        if (vframe == maxf) $finish;
    end
    always @(posedge hclk) if (capturing && de) $fwrite(fd, "%c%c%c", d[23:16], d[15:8], d[7:0]);
    // escritura de VIDEO_CTRL = fin del dibujo de un cuadro
    always @(posedge clk) begin
        if (dut.u_video.frame_tick) t_tick = $time;
        if (dut.u_io.req && dut.u_io.we && dut.u_io.addr[4:2] == 3'd5) begin
            nflips = nflips + 1;
            busy = ($time - t_tick) / 20;
            if (vframe > 6 && busy > busy_max) busy_max = busy;
        end
    end
endmodule
