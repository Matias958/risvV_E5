// ============================================================================
// ERV26 - Latch IF/ID
//   Guarda el PC de la instruccion que esta en ID. La instruccion en si es
//   la salida registrada de la M10K (imem_rdata), no pasa por este bloque.
//   Se detiene con freeze o load_use.
// ============================================================================
module erv26_if_id #(
    parameter RESET_PC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        freeze,
    input  wire        load_use,
    input  wire [31:0] f_pc,
    output reg  [31:0] d_pc,
    output reg         d_valid
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            d_pc    <= RESET_PC - 32'd4;     // asi el primer f_pc = RESET_PC
            d_valid <= 1'b0;
        end else if (!freeze && !load_use) begin
            d_pc    <= f_pc;
            d_valid <= 1'b1;
        end
    end
endmodule
