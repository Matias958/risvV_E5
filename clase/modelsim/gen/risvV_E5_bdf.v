module risvV_E5 (
    input  wire [0:0] FPGA_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [3:0] SW,
    input  wire [3:0] GPIO_0,
    output wire [7:0] LED,
    output wire [0:0] HDMI_TX_CLK,
    output wire [23:0] HDMI_TX_D,
    output wire [0:0] HDMI_TX_DE,
    output wire [0:0] HDMI_TX_HS,
    output wire [0:0] HDMI_TX_VS,
    output wire [0:0] HDMI_I2C_SCL,
    output wire [0:0] HDMI_I2C_SDA
);
    wire [0:0] rst_n;
    wire [0:0] en;
    wire [4:0] dbg_reg_sel;
    wire [31:0] imem_rdata;
    wire [31:0] dmem_rdata;
    wire [0:0] dmem_ready;
    wire [31:0] imem_addr;
    wire [0:0] dmem_req;
    wire [0:0] dmem_we;
    wire [3:0] dmem_be;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] dmem_addr_next;
    wire [31:0] ram_rdata;
    wire [0:0] ram_ready;
    wire [31:0] vram_rdata;
    wire [0:0] vram_ready;
    wire [31:0] io_rdata;
    wire [0:0] io_ready;
    wire [0:0] ram_req;
    wire [0:0] vram_req;
    wire [0:0] io_req;
    wire [0:0] frame_tick;
    wire [0:0] vblank;
    wire [0:0] disp_page;
    erv26_board_ctrl u_ctrl (
        .clk(FPGA_CLK1_50),
        .key(KEY),
        .rst_n(rst_n),
        .en(en),
        .dbg_reg_sel(dbg_reg_sel)
    );
    erv26_hdmi_init u_hdmi_init (
        .clk(FPGA_CLK1_50),
        .rst_n(rst_n),
        .i2c_scl(HDMI_I2C_SCL),
        .i2c_sda(HDMI_I2C_SDA),
        .busy()
    );
    erv26_core u_core (
        .clk(FPGA_CLK1_50),
        .rst_n(rst_n),
        .en(en),
        .imem_rdata(imem_rdata),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        .dbg_reg_sel(dbg_reg_sel),
        .imem_addr(imem_addr),
        .dmem_req(dmem_req),
        .dmem_we(dmem_we),
        .dmem_be(dmem_be),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_addr_next(dmem_addr_next),
        .dbg_reg_data(),
        .dbg_commit(),
        .dbg_commit_pc(),
        .dbg_commit_instr(),
        .dbg_commit_we(),
        .dbg_commit_rd(),
        .dbg_commit_data()
    );
    erv26_imem u_imem (
        .clk(FPGA_CLK1_50),
        .addr(imem_addr),
        .rdata(imem_rdata)
    );
    erv26_bus u_bus (
        .dmem_req(dmem_req),
        .dmem_addr(dmem_addr),
        .ram_rdata(ram_rdata),
        .ram_ready(ram_ready),
        .vram_rdata(vram_rdata),
        .vram_ready(vram_ready),
        .io_rdata(io_rdata),
        .io_ready(io_ready),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        .ram_req(ram_req),
        .vram_req(vram_req),
        .io_req(io_req)
    );
    erv26_dmem u_dmem (
        .clk(FPGA_CLK1_50),
        .rst_n(rst_n),
        .req(ram_req),
        .we(dmem_we),
        .be(dmem_be),
        .addr(dmem_addr),
        .wdata(dmem_wdata),
        .addr_next(dmem_addr_next),
        .rdata(ram_rdata),
        .ready(ram_ready)
    );
    erv26_io u_io (
        .clk(FPGA_CLK1_50),
        .rst_n(rst_n),
        .req(io_req),
        .we(dmem_we),
        .be(dmem_be),
        .addr(dmem_addr),
        .wdata(dmem_wdata),
        .sw(SW),
        .btn_n(GPIO_0),
        .frame_tick(frame_tick),
        .vblank(vblank),
        .rdata(io_rdata),
        .ready(io_ready),
        .leds(LED),
        .disp_page(disp_page)
    );
    erv26_video u_video (
        .clk(FPGA_CLK1_50),
        .rst_n(rst_n),
        .req(vram_req),
        .we(dmem_we),
        .be(dmem_be),
        .addr(dmem_addr),
        .wdata(dmem_wdata),
        .disp_page(disp_page),
        .rdata(vram_rdata),
        .ready(vram_ready),
        .frame_tick(frame_tick),
        .vblank(vblank),
        .hdmi_clk(HDMI_TX_CLK),
        .hdmi_d(HDMI_TX_D),
        .hdmi_de(HDMI_TX_DE),
        .hdmi_hs(HDMI_TX_HS),
        .hdmi_vs(HDMI_TX_VS)
    );
endmodule
