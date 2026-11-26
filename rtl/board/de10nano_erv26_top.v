// ============================================================================
// ERV26 con pipeline en DE10-Nano - top de referencia
//
//   Equivalente en Verilog de risvV_E5.bdf (mismos bloques):
//     erv26_board_ctrl + erv26_hdmi_init + erv26_core + erv26_imem (M10K)
//     + erv26_bus + erv26_dmem (M10K) + erv26_io + erv26_video (M10K)
//
//   Mapa de memoria:
//     0x0000_0000  memoria de programa (imem.hex)
//     0x0001_0000  memoria de datos    (dmem_b0..b3.hex)
//     0x4000_0000  framebuffer de video, 2 paginas de 320x240 RGB332 (W)
//     0x8000_0000  E/S: LEDs, switches, ciclos, botones, cuadros, video
//
//   KEY[0] = reset. KEY[1] mantenido = halt (en=0).
//   GPIO_0[3:0] = botones (activos en bajo, con pull-up interno).
// ============================================================================
module de10nano_erv26_top (
    input  wire        FPGA_CLK1_50,
    input  wire [1:0]  KEY,
    input  wire [3:0]  SW,
    input  wire [3:0]  GPIO_0,
    output wire [7:0]  LED,
    output wire        HDMI_TX_CLK,
    output wire [23:0] HDMI_TX_D,
    output wire        HDMI_TX_DE,
    output wire        HDMI_TX_HS,
    output wire        HDMI_TX_VS,
    output wire        HDMI_I2C_SCL,
    output wire        HDMI_I2C_SDA
);
    wire clk = FPGA_CLK1_50;

    // Reset (KEY[0]) y halt (KEY[1]) sincronizados
    wire rst_n, en;
    wire [4:0] dbg_reg_sel;
    erv26_board_ctrl u_ctrl (.clk(clk), .key(KEY), .rst_n(rst_n), .en(en),
                             .dbg_reg_sel(dbg_reg_sel));

    // Configuracion del ADV7513
    erv26_hdmi_init u_hdmi_init (.clk(clk), .rst_n(rst_n), .i2c_scl(HDMI_I2C_SCL),
                                 .i2c_sda(HDMI_I2C_SDA), .busy());

    // ---------------- Nucleo ----------------
    wire [31:0] imem_addr, imem_rdata;
    wire        dmem_req, dmem_we, dmem_ready;
    wire [3:0]  dmem_be;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata, dmem_addr_next;

    erv26_core u_core (
        .clk(clk), .rst_n(rst_n), .en(en),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_req(dmem_req), .dmem_we(dmem_we), .dmem_be(dmem_be),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_addr_next(dmem_addr_next),
        .dmem_rdata(dmem_rdata), .dmem_ready(dmem_ready),
        .dbg_reg_sel(dbg_reg_sel), .dbg_reg_data(),
        .dbg_commit(), .dbg_commit_pc(), .dbg_commit_instr(),
        .dbg_commit_we(), .dbg_commit_rd(), .dbg_commit_data()
    );

    erv26_imem u_imem (.clk(clk), .addr(imem_addr), .rdata(imem_rdata));

    // ---------------- Bus de datos ----------------
    wire [31:0] ram_rdata, vram_rdata, io_rdata;
    wire        ram_req, ram_ready, vram_req, vram_ready, io_req, io_ready;

    erv26_bus u_bus (
        .dmem_req(dmem_req), .dmem_addr(dmem_addr),
        .dmem_rdata(dmem_rdata), .dmem_ready(dmem_ready),
        .ram_req(ram_req), .ram_rdata(ram_rdata), .ram_ready(ram_ready),
        .vram_req(vram_req), .vram_rdata(vram_rdata), .vram_ready(vram_ready),
        .io_req(io_req), .io_rdata(io_rdata), .io_ready(io_ready)
    );

    erv26_dmem u_dmem (
        .clk(clk), .rst_n(rst_n),
        .req(ram_req), .we(dmem_we), .be(dmem_be),
        .addr(dmem_addr), .wdata(dmem_wdata), .addr_next(dmem_addr_next),
        .rdata(ram_rdata), .ready(ram_ready)
    );

    wire frame_tick, vblank, disp_page;

    erv26_io u_io (
        .clk(clk), .rst_n(rst_n),
        .req(io_req), .we(dmem_we), .be(dmem_be),
        .addr(dmem_addr), .wdata(dmem_wdata),
        .rdata(io_rdata), .ready(io_ready),
        .sw(SW), .leds(LED), .btn_n(GPIO_0),
        .frame_tick(frame_tick), .vblank(vblank), .disp_page(disp_page)
    );

    erv26_video u_video (
        .clk(clk), .rst_n(rst_n),
        .req(vram_req), .we(dmem_we), .be(dmem_be),
        .addr(dmem_addr), .wdata(dmem_wdata),
        .rdata(vram_rdata), .ready(vram_ready),
        .disp_page(disp_page), .frame_tick(frame_tick), .vblank(vblank),
        .hdmi_clk(HDMI_TX_CLK), .hdmi_d(HDMI_TX_D), .hdmi_de(HDMI_TX_DE),
        .hdmi_hs(HDMI_TX_HS), .hdmi_vs(HDMI_TX_VS)
    );
endmodule
