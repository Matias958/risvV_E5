// ============================================================================
// Antirrebote para pulsador activo bajo + pulso de un ciclo al presionar.
//   Con CNT_BITS=20 a 50 MHz el boton debe estar estable ~21 ms.
// ============================================================================
module erv26_debounce_pulse #(
    parameter CNT_BITS = 20
) (
    input  wire clk,
    input  wire btn_n,
    output wire pulse
);
    // Sincronizador de 2 FF (entrada asincronica)
    reg [1:0] sync;
    always @(posedge clk) sync <= {sync[0], ~btn_n};

    reg [CNT_BITS-1:0] cnt = 0;
    reg stable = 1'b0, stable_d = 1'b0;

    always @(posedge clk) begin
        if (sync[1] == stable) begin
            cnt <= 0;
        end else begin
            cnt <= cnt + 1'b1;
            if (&cnt) stable <= sync[1];
        end
        stable_d <= stable;
    end

    assign pulse = stable & ~stable_d;
endmodule
