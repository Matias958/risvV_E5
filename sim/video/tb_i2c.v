// Testbench de erv26_hdmi_init: decodifica el bus I2C (con pull-ups) y
// lista las escrituras {direccion, registro, valor}.
`timescale 1ns/1ps
module tb_i2c;
    reg clk = 0, rst_n = 0;
    always #10 clk = ~clk;
    wire scl, sda, busy;
    pullup(scl); pullup(sda);
    erv26_hdmi_init #(.QDIV(4), .WAITB(6)) dut(.clk(clk), .rst_n(rst_n),
        .i2c_scl(scl), .i2c_sda(sda), .busy(busy));
    integer nb, nbytes; reg [8:0] sh; reg in_frame;
    reg [7:0] byte_rx = 8'h00;           // ultimo byte decodificado (para ver en GTKWave)
    initial if ($test$plusargs("VCD")) begin
        $dumpfile("tb_i2c.vcd"); $dumpvars(0, tb_i2c.scl, tb_i2c.sda, tb_i2c.busy, tb_i2c.byte_rx, tb_i2c.in_frame, tb_i2c.rst_n);
    end
    initial begin nb = 0; in_frame = 0; nbytes = 0; repeat(3) @(posedge clk); rst_n = 1; end
    always @(negedge sda) if (scl === 1'b1) begin in_frame = 1; nb = 0; sh = 0; $write("START "); end
    always @(posedge sda) if (scl === 1'b1 && in_frame) begin in_frame = 0; $write("STOP\n"); end
    always @(posedge scl) if (in_frame) begin
        sh = {sh[7:0], sda}; nb = nb + 1;
        if (nb == 9) begin $write("%02x%s ", sh[8:1], sh[0] ? "(nack)" : ""); byte_rx = sh[8:1]; nb = 0; end
    end
    always @(negedge busy) if ($time > 100) begin $display("FIN"); $finish; end
    initial begin #20_000_000; $display("TIMEOUT"); $finish; end
endmodule
