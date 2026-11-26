// ============================================================================
// ERV26 MVP-0 en DE10-Nano - top de referencia
//
//   Equivalente en Verilog de lo que se dibuja en el .bdf de la placa.
//   Pines (nombres del System Builder / pin assignments de Terasic):
//     FPGA_CLK1_50 : clock 50 MHz
//     KEY[0]       : reset (activo bajo)
//     KEY[1]       : paso a paso (una instruccion por pulsacion)
//     SW[3]        : 1 = run continuo a ~4 Hz, 0 = paso a paso con KEY[1]
//     SW[2:0]      : registro a mostrar = x10 + SW (a0..a7)
//     LED[7:0]     : byte bajo del registro elegido
//
//   Todo corre con el clock de 50 MHz y un clock-enable: no se generan
//   clocks derivados desde logica (evita problemas de timing en la FPGA).
// ============================================================================
module de10nano_mvp0_top (
    input  wire       FPGA_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [3:0] SW,
    output wire [7:0] LED
);
    wire clk   = FPGA_CLK1_50;
    wire rst_n = KEY[0];

    // ---- Paso a paso: antirrebote + detector de flanco de KEY[1] ----
    wire step_pulse;
    erv26_debounce_pulse #(.CNT_BITS(20)) u_db (
        .clk(clk), .btn_n(KEY[1]), .pulse(step_pulse)
    );

    // ---- Run continuo: tick de ~4 Hz (50e6 / 2^24 ~ 3 Hz) ----
    reg [23:0] div = 24'd0;
    always @(posedge clk) div <= div + 24'd1;
    wire run_tick = (div == 24'd0);

    wire core_en = SW[3] ? run_tick : step_pulse;

    wire [31:0] reg_data, pc, instr;
    wire        illegal;

    erv26_mvp0 #(.PROG_FILE("program.hex")) u_core (
        .clk(clk), .rst_n(rst_n), .en(core_en),
        .dbg_reg_sel(5'd10 + {2'b00, SW[2:0]}),
        .dbg_reg_data(reg_data),
        .dbg_pc(pc), .dbg_instr(instr), .dbg_illegal(illegal)
    );

    assign LED = reg_data[7:0];
endmodule
