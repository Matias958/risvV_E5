// ============================================================================
// Testbench del nucleo con pipeline
//
//   Plusargs:
//     +IMEM=<f>     programa, una palabra hexa por linea
//     +DMEM=<f>     datos iniciales (desde 0x10000), una palabra por linea
//     +TRACE=<f>    traza de instrucciones retiradas y stores
//     +HALT_PC=<h>  termina al retirar la instruccion en esa direccion
//     +MAXCYC=<n>   timeout en ciclos
//     +LAT_MAX=<n>  latencia aleatoria 0..n de memory_ready (0 = siempre listo)
//     +EN_RAND      en (halt) aleatorio
//     +SEED=<n>     semilla
//     +VCD          genera tb_core.vcd
//     +TOHOST_PC=<h> (solo con -DGATE) PC del store a TOHOST, lo da el ISS
//     +MEM_RTL      la RAM de datos es la de la placa (rtl/erv26_dmem.v, M10K
//                   con lectura anticipada) en vez del modelo con latencia
//                   aleatoria. La E/S (TOHOST, PUTCHAR) responde en el ciclo.
//
//   -DGATE: simula el netlist post-fit de Quartus (gate_sim/). Ahi no existen
//   las senales internas del nucleo, asi que se desactivan los asserts
//   internos y el conteo de stalls; la comparacion contra el ISS es la misma
//   (usa los puertos dbg_commit_*).
//
//   Mapa: imem 0x0, dmem 0x10000 (64 KB), TOHOST 0x80000000, PUTCHAR 0x80000004
// ============================================================================
`timescale 1ns/1ps

module tb_core;
    reg clk = 0, rst_n = 0, en = 1;
    always #10 clk = ~clk;

    // ---------------- Memoria de programa (lectura sincronica) -------------
    reg  [31:0] imem [0:16383];
    wire [31:0] imem_addr;
    reg  [31:0] imem_rdata;
    always @(posedge clk) imem_rdata <= imem[imem_addr[15:2]];

    // ---------------- Memoria de datos con latencia aleatoria --------------
    reg  [31:0] dmem [0:16383];          // 64 KB en palabras
    wire        dmem_req, dmem_we;
    wire [3:0]  dmem_be;
    wire [31:0] dmem_addr, dmem_wdata;
    wire [31:0] dmem_rdata;
    wire        dmem_ready;

    integer lat_max, lat, cnt, seed, mem_rtl;
    wire        is_io = dmem_addr[31];
    wire [31:0] dmem_addr_next;

    reg [31:0] garbage;
    always @(posedge clk) garbage <= $random(seed);

    // Modelo de comportamiento: latencia aleatoria de 0 a LAT_MAX ciclos
    wire        beh_ready = dmem_req && (cnt >= lat);
    wire [31:0] dword = dmem[dmem_addr[15:2]];

    // RAM de la placa (M10K con lectura anticipada); la E/S responde en el ciclo
    wire        ram_req = dmem_req & ~is_io;
    wire [31:0] ram_rdata;
    wire        ram_ready;
    erv26_dmem #(.AW(12), .INIT_B0(""), .INIT_B1(""), .INIT_B2(""), .INIT_B3("")) u_ram (
        .clk(clk), .rst_n(rst_n), .req(ram_req), .we(dmem_we), .be(dmem_be),
        .addr(dmem_addr), .wdata(dmem_wdata), .addr_next(dmem_addr_next),
        .rdata(ram_rdata), .ready(ram_ready)
    );
    // Si la M10K leyo y escribio la misma palabra en el mismo flanco, su dato
    // es indefinido: se reemplaza por DEADBEEF para que usarlo se detecte.
    wire [31:0] ram_q = u_ram.rd_ok ? ram_rdata : 32'hDEADBEEF;
    wire        rtl_ready = is_io ? dmem_req : ram_ready;

    assign dmem_ready = mem_rtl ? rtl_ready : beh_ready;
    // basura si no esta lista o es E/S: detecta uso prematuro del dato
    assign dmem_rdata = (!dmem_ready || dmem_we || is_io) ? garbage :
                        (mem_rtl ? ram_q : dword);

    reg [31:0] tohost;
    reg        tohost_valid;
    reg [31:0] tohost_pc;
    integer    k;

    always @(posedge clk) begin
        if (dmem_req && !dmem_ready) cnt <= cnt + 1;
        else begin
            cnt <= 0;
            if (dmem_req) lat <= (lat_max == 0) ? 0 : ($unsigned($random(seed)) % (lat_max + 1));
        end

        if (dmem_req && dmem_ready && dmem_we) begin
            $fdisplay(fd, "S %08h %h %08h", {dmem_addr[31:2], 2'b00}, dmem_be,
                      dmem_wdata & {{8{dmem_be[3]}}, {8{dmem_be[2]}}, {8{dmem_be[1]}}, {8{dmem_be[0]}}});
            if (is_io) begin
                if (dmem_addr[3:0] == 4'h0) begin tohost <= dmem_wdata; tohost_valid <= 1;
`ifndef GATE
                    tohost_pc <= dut.m_pc;
`endif
                end
                if (dmem_addr[3:0] == 4'h4) $write("%c", dmem_wdata[7:0]);
            end else begin
                for (k = 0; k < 4; k = k + 1)
                    if (dmem_be[k]) dmem[dmem_addr[15:2]][8*k +: 8] <= dmem_wdata[8*k +: 8];
            end
        end
    end

    // ---------------- DUT ----------------
    wire        c_valid, c_we;
    wire [31:0] c_pc, c_instr, c_data;
    wire [4:0]  c_rd;
    wire [31:0] dbg_reg;

    erv26_core dut (
        .clk(clk), .rst_n(rst_n), .en(en),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .dmem_req(dmem_req), .dmem_we(dmem_we), .dmem_be(dmem_be),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_addr_next(dmem_addr_next),
        .dmem_rdata(dmem_rdata), .dmem_ready(dmem_ready),
        .dbg_reg_sel(5'd0), .dbg_reg_data(dbg_reg),
        .dbg_commit(c_valid), .dbg_commit_pc(c_pc), .dbg_commit_instr(c_instr),
        .dbg_commit_we(c_we), .dbg_commit_rd(c_rd), .dbg_commit_data(c_data)
    );

    // ---------------- Control ----------------
    reg [8*256-1:0] f_imem, f_dmem, f_trace;
    integer fd, maxcyc, cycles, commits, en_rand, done, stalls_ld, flushes, mem_wait;
    reg [31:0] halt_pc;
    reg        has_halt;

`ifndef GATE
    // Chequeos internos (asserts)
`include "vista_pipeline.vh"

    always @(posedge clk) if (rst_n) begin
        // Un LOAD en MEM nunca deberia ser necesitado por la instruccion en EX
        if (dut.m_valid && dut.m_load && dut.m_rd != 0 && dut.e_valid && !dut.freeze &&
            ((dut.e_rs1 == dut.m_rd && dut.e_instr[6:0] != 7'b0110111 && dut.e_instr[6:0] != 7'b0010111 &&
              dut.e_instr[6:0] != 7'b1101111) ||
             (dut.e_rs2 == dut.m_rd && (dut.e_instr[6:0] == 7'b0110011 || dut.e_instr[6:0] == 7'b0100011 ||
                                        dut.e_instr[6:0] == 7'b1100011)))) begin
            $display("ASSERT: dependencia load->EX sin stall en pc=%08h", dut.e_pc); $finish;
        end
        if (^dut.imem_addr === 1'bx) begin $display("ASSERT: f_pc con X en ciclo %0d", cycles); $finish; end
        if (dut.w_valid && dut.w_we && (^dut.w_data === 1'bx)) begin
            $display("ASSERT: write-back con X en pc=%08h", dut.w_pc); $finish;
        end
    end
`else
    always @(posedge clk) if (rst_n) begin
        if (^imem_addr === 1'bx) begin $display("ASSERT: imem_addr con X en ciclo %0d", cycles); $finish; end
        if (c_valid && c_we && (^c_data === 1'bx)) begin
            $display("ASSERT: write-back con X en pc=%08h", c_pc); $finish;
        end
    end
`endif

    initial begin
        if (!$value$plusargs("IMEM=%s", f_imem)) f_imem = "imem.hex";
        if (!$value$plusargs("TRACE=%s", f_trace)) f_trace = "trace.out";
        if (!$value$plusargs("MAXCYC=%d", maxcyc)) maxcyc = 200000;
        if (!$value$plusargs("LAT_MAX=%d", lat_max)) lat_max = 0;
        if (!$value$plusargs("SEED=%d", seed)) seed = 1;
        has_halt = $value$plusargs("HALT_PC=%h", halt_pc);
        en_rand  = $test$plusargs("EN_RAND");
        mem_rtl  = $test$plusargs("MEM_RTL");
`ifdef GATE
        if (!$value$plusargs("TOHOST_PC=%h", tohost_pc)) tohost_pc = 32'hFFFFFFFF;
`endif
        if ($test$plusargs("VCD")) begin $dumpfile("tb_core.vcd"); $dumpvars(0, tb_core); end

        for (k = 0; k < 16384; k = k + 1) begin imem[k] = 32'h00000013; dmem[k] = 0; end
        $readmemh(f_imem, imem);
        if ($value$plusargs("DMEM=%s", f_dmem)) $readmemh(f_dmem, dmem);
        for (k = 0; k < 4096; k = k + 1) begin      // misma imagen en la RAM de la placa
            u_ram.b0[k] = dmem[k][7:0];   u_ram.b1[k] = dmem[k][15:8];
            u_ram.b2[k] = dmem[k][23:16]; u_ram.b3[k] = dmem[k][31:24];
        end

        fd = $fopen(f_trace, "w");
        cnt = 0; lat = 0; tohost_valid = 0; cycles = 0; commits = 0; done = 0; stalls_ld = 0; flushes = 0; mem_wait = 0;

        repeat (3) @(posedge clk);
        #1 rst_n = 1;

        while (!done) begin
            @(negedge clk);
            cycles = cycles + 1;
            if (en_rand) en = ($unsigned($random(seed)) % 8) != 0;
            #1;     // dejar que el nuevo 'en' se propague antes de muestrear
`ifndef GATE
            if (dut.load_use && !dut.freeze) stalls_ld = stalls_ld + 1;
            if (dut.e_redirect && !dut.freeze) flushes = flushes + 1;
`endif
            if (dmem_req && !dmem_ready && en) mem_wait = mem_wait + 1;
            if (c_valid) begin
                commits = commits + 1;
                if (c_we) $fdisplay(fd, "C %08h %08h %0d %08h", c_pc, c_instr, c_rd, c_data);
                else      $fdisplay(fd, "C %08h %08h - 0", c_pc, c_instr);
                if (has_halt && c_pc == halt_pc) done = 1;
                // terminar al retirar el store a TOHOST
                if (tohost_valid && c_pc == tohost_pc) done = 1;
            end
            if (cycles >= maxcyc) begin $display("TIMEOUT"); done = 1; end
        end
        $fdisplay(fd, "TOHOST %08h", tohost_valid ? tohost : 32'hFFFFFFFF);
        $fdisplay(fd, "STATS cycles=%0d commits=%0d load_use=%0d flush=%0d mem_wait=%0d", cycles, commits, stalls_ld, flushes, mem_wait);
        $fclose(fd);
        $display("FIN: %0d ciclos, %0d instrucciones, TOHOST=%08h%0s", cycles, commits,
                 tohost_valid ? tohost : 32'hFFFFFFFF, (tohost_valid && tohost == 1) ? " (PASS)" : "");
        $finish;
    end
endmodule
