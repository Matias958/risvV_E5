// ============================================================================
// ERV26 - WB: habilitacion de escritura del banco y salida de debug
//   dbg_commit vale 1 un ciclo por cada instruccion retirada.
// ============================================================================
module erv26_wb_commit (
    input  wire        freeze,
    input  wire        w_valid,
    input  wire        w_we,
    input  wire [4:0]  w_rd,
    input  wire [31:0] w_data,
    input  wire [31:0] w_pc,
    input  wire [31:0] w_instr,
    output wire        rf_we,
    output wire        dbg_commit,
    output wire [31:0] dbg_commit_pc,
    output wire [31:0] dbg_commit_instr,
    output wire        dbg_commit_we,
    output wire [4:0]  dbg_commit_rd,
    output wire [31:0] dbg_commit_data
);
    assign rf_we            = w_valid & w_we;
    assign dbg_commit       = w_valid & ~freeze;
    assign dbg_commit_pc    = w_pc;
    assign dbg_commit_instr = w_instr;
    assign dbg_commit_we    = w_we & (w_rd != 5'd0);
    assign dbg_commit_rd    = w_rd;
    assign dbg_commit_data  = w_data;
endmodule
