// ============================================================================
// Testbench MVP-0
//   +PROG=<archivo.hex>  programa (un byte por linea)
//   +N=<ciclos>          instrucciones a ejecutar
//   +OUT=<archivo>       volcado final de x0..x31 y PC (para comparar con ISS)
//   +VCD                 genera tb_mvp0.vcd para GTKWave
//
//   Ademas chequea: x0 siempre 0, que en=0 congele PC y registros, y que el
//   puerto de debug lea lo mismo que el banco.
// ============================================================================
`timescale 1ns/1ps

module tb_mvp0;
    reg clk = 0, rst_n = 0, en = 0;
    reg [4:0] dbg_sel = 0;
    wire [31:0] dbg_data, pc, instr;
    wire illegal;

    always #10 clk = ~clk;   // 50 MHz

    erv26_mvp0 #(.PROG_DEPTH(4096), .PROG_AW(12), .PROG_FILE("")) dut (
        .clk(clk), .rst_n(rst_n), .en(en),
        .dbg_reg_sel(dbg_sel), .dbg_reg_data(dbg_data),
        .dbg_pc(pc), .dbg_instr(instr), .dbg_illegal(illegal)
    );

    reg [8*256-1:0] prog, out;
    integer n, k, fd, errors;
    reg [31:0] pc_hold, r_hold;

    initial begin
        errors = 0;
        if (!$value$plusargs("PROG=%s", prog)) prog = "program.hex";
        if (!$value$plusargs("N=%d", n)) n = 100;
        if (!$value$plusargs("OUT=%s", out)) out = "regs.out";
        if ($test$plusargs("VCD")) begin
            $dumpfile("tb_mvp0.vcd");
            $dumpvars(0, tb_mvp0);
        end
        $readmemh(prog, dut.u_pmem.mem);

        // Reset
        repeat (3) @(posedge clk);
        #1 rst_n = 1;
        if (pc !== 32'd0) begin $display("ERROR: PC tras reset = %h", pc); errors = errors + 1; end

        // Ejecutar n instrucciones (mitad, pausa con en=0, resto)
        @(negedge clk) en = 1;
        for (k = 0; k < n; k = k + 1) begin
            if (k == n/2) begin
                // --- chequeo de stall: en=0 congela todo ---
                en = 0;
                pc_hold = pc; dbg_sel = 5'd1; #1 r_hold = dbg_data;
                repeat (5) @(negedge clk);
                if (pc !== pc_hold || dbg_data !== r_hold) begin
                    $display("ERROR: en=0 no congelo el procesador"); errors = errors + 1;
                end
                en = 1;
            end
            @(negedge clk);
            if (dut.u_rf.rs1_data === 32'hx) begin
                $display("ERROR: X en rs1 en pc=%h", pc); errors = errors + 1;
            end
        end
        en = 0;

        // Chequeo del puerto de debug contra el banco
        for (k = 0; k < 32; k = k + 1) begin
            dbg_sel = k; #1;
            if (dbg_data !== ((k == 0) ? 32'd0 : dut.u_rf.regs[k])) begin
                $display("ERROR: dbg x%0d", k); errors = errors + 1;
            end
        end

        // Volcado
        fd = $fopen(out, "w");
        $fdisplay(fd, "pc %h", pc);
        $fdisplay(fd, "x0 %h", 32'd0);
        for (k = 1; k < 32; k = k + 1) $fdisplay(fd, "x%0d %h", k, dut.u_rf.regs[k]);
        $fdisplay(fd, "tb_errors %0d", errors);
        $fclose(fd);
        $finish;
    end
endmodule
