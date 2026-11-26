// Testbench del controlador de video: llena las dos paginas con patrones,
// captura dos cuadros (PPM 640x480) y mide el timing de los sincronismos.
`timescale 1ns/1ps
module tb_video;
    reg clk = 0, rst_n = 0;
    always #10 clk = ~clk;                    // 50 MHz
    reg req = 0, we = 0; reg [3:0] be = 0; reg [31:0] addr = 0, wdata = 0;
    reg disp_page = 0;
    wire [31:0] rdata; wire ready, frame_tick, vblank;
    wire hclk, de, hs, vs; wire [23:0] d;
    erv26_video dut(.clk(clk), .rst_n(rst_n), .req(req), .we(we), .be(be), .addr(addr),
        .wdata(wdata), .rdata(rdata), .ready(ready), .disp_page(disp_page),
        .frame_tick(frame_tick), .vblank(vblank), .hdmi_clk(hclk), .hdmi_d(d),
        .hdmi_de(de), .hdmi_hs(hs), .hdmi_vs(vs));

    // patron: pagina 0 -> byte = (x ^ y) ; pagina 1 -> byte = x + 2*y
    function [7:0] pat; input p; input [8:0] x; input [7:0] y;
        pat = p ? (x[7:0] + {y[6:0], 1'b0}) : (x[7:0] ^ y);
    endfunction
    integer x, y, p, i, fd, f, nf;
    // medidas
    integer clk_in_line, hs_low, de_cnt, lines, vs_low_lines, frames_seen;
    reg hs_d, vs_d, de_d;
    initial begin
        repeat (3) @(posedge clk); rst_n = 1;
        for (p = 0; p < 2; p = p + 1)
            for (y = 0; y < 240; y = y + 1)
                for (x = 0; x < 320; x = x + 4) begin
                    @(negedge clk);
                    req = 1; we = 1; be = 4'hF;
                    addr = 32'h4000_0000 + p * 76800 + y * 320 + x;
                    wdata = {pat(p, x + 3, y), pat(p, x + 2, y), pat(p, x + 1, y), pat(p, x, y)};
                end
        @(negedge clk); req = 0; we = 0;
    end
    // captura: en el flanco ascendente de hdmi_clk, con DE=1
    reg [9:0] cx, cy; reg capturing; integer frame_no;
    initial begin
        frame_no = 0; capturing = 0; cx = 0; cy = 0;
        fd = 0;
    end
    always @(posedge hclk) begin
        if (frame_tick === 1'bx) ;
        if (de) begin
            if (capturing) $fwrite(fd, "%c%c%c", d[23:16], d[15:8], d[7:0]);
        end
    end
    // contador de vsync para arrancar/terminar capturas
    always @(negedge vs) begin
        if (capturing) begin $fclose(fd); capturing = 0; frame_no = frame_no + 1; end
        if (frame_no == 0 && $time > 2_000_000) begin       // despues de llenar la VRAM
            fd = $fopen("frame0.ppm", "wb"); $fwrite(fd, "P6\n640 480\n255\n"); capturing = 1;
            disp_page = 1;      // pedido a mitad de cuadro: debe verse en el siguiente
        end else if (frame_no == 1) begin
            fd = $fopen("frame1.ppm", "wb"); $fwrite(fd, "P6\n640 480\n255\n"); capturing = 1;
        end else if (frame_no == 2) begin
            $display("frames capturados"); $finish;
        end
    end
    // timing medido en ciclos de pixel (flancos de hdmi_clk)
    integer px_cnt, hs_start, hs_w, h_per, de_line, line_cnt, vs_w, v_per, last_hs;
    initial begin px_cnt = 0; hs_d = 1; de_d = 0; de_line = 0; line_cnt = 0; vs_w = 0; last_hs = -1; end
    always @(posedge hclk) begin
        px_cnt = px_cnt + 1;
        if (hs_d && !hs) begin
            if (last_hs >= 0 && $time > 2_000_000) begin h_per = px_cnt - last_hs; end
            last_hs = px_cnt; hs_start = px_cnt;
        end
        if (!hs_d && hs && $time > 2_000_000) hs_w = px_cnt - hs_start;
        if (de) de_line = de_line + 1;
        if (de_d && !de) begin
            if ($time > 2_000_000 && de_line != 640) $display("ERROR: linea con %0d pixeles", de_line);
            de_line = 0; line_cnt = line_cnt + 1;
        end
        hs_d = hs; de_d = de;
    end
    // periodo y ancho del vsync en pixeles, lineas activas por cuadro
    integer vs_fall, vs_rise, vs_per, vs_wid, lines_at_vs;
    reg vs_d0 = 1;
    initial begin vs_fall = -1; lines_at_vs = 0; end
    always @(posedge hclk) begin
        if (vs_d0 && !vs) begin
            if (vs_fall >= 0 && $time > 2_000_000)
                $display("cuadro: hsync periodo=%0d ancho=%0d | vsync periodo=%0d px (%0d lineas) ancho=%0d px | lineas con DE=%0d",
                         h_per, hs_w, px_cnt - vs_fall, (px_cnt - vs_fall) / 800, vs_wid, line_cnt - lines_at_vs);
            vs_fall = px_cnt; lines_at_vs = line_cnt;
        end
        if (!vs_d0 && vs) vs_wid = px_cnt - vs_fall;
        vs_d0 = vs;
    end
    initial begin #70_000_000; $display("TIMEOUT"); $finish; end
    // Ondas para GTKWave (+VCD): un cuadro completo pesaria cientos de MB, asi que
    // se guardan solo dos ventanas del primer cuadro capturado: las 3 primeras
    // lineas (pixeles, DE y hsync) y las lineas 476..495 (fin de la imagen,
    // cambio de pagina, porches y vsync).
    wire [9:0] hc = dut.hc, vc = dut.vc;
    wire       ph = dut.ph, page_l = dut.page_l;
    reg vcd_en = 0, vcd_on = 0, vcd_top = 0;
    initial if ($test$plusargs("VCD")) begin
        $dumpfile("tb_video.vcd"); $dumpvars(1, tb_video); $dumpoff; vcd_en = 1;
    end
    always @(posedge clk) if (vcd_en) begin
        if (capturing && frame_no == 0 && vc == 0) vcd_top = 1;
        if (capturing && frame_no == 0 && (vc < 3 || (vcd_top && vc >= 476 && vc <= 495))) begin
            if (!vcd_on) begin $dumpon; vcd_on = 1; end
        end else if (vcd_on) begin $dumpoff; vcd_on = 0; end
    end
endmodule
