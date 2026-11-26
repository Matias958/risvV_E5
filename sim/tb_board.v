// ============================================================================
// Testbench del top de placa (nucleo + M10K + E/S) con la demo de LEDs.
//   Compilar la demo con -DSIM (esperas cortas). Verifica que:
//     - con SW=0 los LEDs cuenten 0,1,2,...
//     - con SW=1 aparezca el patron de "auto fantastico" (un solo bit)
//     - KEY[1] (halt) congele los LEDs
// ============================================================================
`ifndef TOP
`define TOP de10nano_erv26_top   // o risvV_E5 (el top .bdf convertido con bdf2v)
`endif
`timescale 1ns/1ps

module tb_board;
    reg        clk = 0;
    reg  [1:0] key = 2'b10;        // KEY[0]=0 -> reset
    reg  [3:0] sw  = 4'b0000;
    wire [7:0] led;
    always #10 clk = ~clk;

    `TOP dut (.FPGA_CLK1_50(clk), .KEY(key), .SW(sw), .GPIO_0(4'hF), .LED(led),
        .HDMI_TX_CLK(), .HDMI_TX_D(), .HDMI_TX_DE(), .HDMI_TX_HS(), .HDMI_TX_VS(),
        .HDMI_I2C_SCL(), .HDMI_I2C_SDA());

    integer errors = 0, changes = 0, k;
    reg [7:0] prev, expect_cnt;

    // Registrar cambios de LEDs
    always @(led) begin
        changes = changes + 1;
    end

    task wait_led_change;
        input integer max_cycles;
        integer c;
        begin
            prev = led; c = 0;
            while (led == prev && c < max_cycles) begin @(posedge clk); c = c + 1; end
            if (c >= max_cycles) begin $display("ERROR: los LEDs no cambian"); errors = errors + 1; end
        end
    endtask

    initial begin
        if ($test$plusargs("VCD")) begin $dumpfile("tb_board.vcd"); $dumpvars(0, tb_board); end
        repeat (5) @(posedge clk);
        key[0] = 1;

        // ---- Modo contador ----
        wait_led_change(20000);
        expect_cnt = led;
        for (k = 0; k < 6; k = k + 1) begin
            wait_led_change(20000);
            expect_cnt = expect_cnt + 1;
            if (led !== expect_cnt) begin
                $display("ERROR: contador LED=%0d esperado %0d", led, expect_cnt); errors = errors + 1;
            end
        end
        $display("modo contador OK (LED=%0d)", led);

        // ---- Modo auto fantastico: siempre un solo bit encendido ----
        sw = 4'b0001;
        wait_led_change(20000);
        for (k = 0; k < 16; k = k + 1) begin
            wait_led_change(20000);
            if (led == 0 || (led & (led - 1)) != 0) begin
                $display("ERROR: patron con mas de un bit: %b", led); errors = errors + 1;
            end
        end
        $display("modo auto fantastico OK");

        // ---- Halt con KEY[1] ----
        key[1] = 0;
        repeat (10) @(posedge clk);
        prev = led;
        repeat (5000) @(posedge clk);
        if (led !== prev) begin $display("ERROR: halt no congelo"); errors = errors + 1; end
        key[1] = 1;
        wait_led_change(20000);
        $display("halt OK");

        if (errors == 0) $display("PASS tb_board");
        else             $display("FAIL tb_board (%0d errores)", errors);
        $finish;
    end
endmodule
