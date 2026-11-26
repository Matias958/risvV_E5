// ============================================================================
// ERV26 - Control de placa (bloque para el top .bdf)
//   KEY[0] = reset: asincronico al presionar, sincronico al soltar.
//   KEY[1] mantenido = halt (en = 0), sincronizado con 2 FF.
//   dbg_reg_sel: registro que muestra dbg_reg_data del nucleo (x10 = a0),
//   util para mirarlo con SignalTap.
// ============================================================================
module erv26_board_ctrl (
    input  wire       clk,
    input  wire [1:0] key,          // pulsadores activos bajo
    output wire       rst_n,
    output wire       en,
    output wire [4:0] dbg_reg_sel
);
    reg [1:0] rst_sync = 2'b00;
    always @(posedge clk or negedge key[0])
        if (!key[0]) rst_sync <= 2'b00;
        else         rst_sync <= {rst_sync[0], 1'b1};
    assign rst_n = rst_sync[1];

    reg [1:0] halt_sync = 2'b00;
    always @(posedge clk) halt_sync <= {halt_sync[0], ~key[1]};
    assign en = ~halt_sync[1];

    assign dbg_reg_sel = 5'd10;
endmodule
