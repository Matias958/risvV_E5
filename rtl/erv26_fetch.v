// ============================================================================
// ERV26 - Fetch / Program Counter
//   PC de 32 bits. En cada flanco con en=1 avanza a PC+4, o a jump_target
//   si jump_en=1. En el MVP-0 jump_en se ata a 0; los puertos quedan para el
//   control de saltos del pipeline.
//   en=0 congela el PC (stall / ejecucion paso a paso).
// ============================================================================
module erv26_fetch #(
    parameter RESET_PC = 32'h0000_0000
) (
    input  wire        clk,
    input  wire        rst_n,        // reset asincronico activo bajo
    input  wire        en,
    input  wire        jump_en,
    input  wire [31:0] jump_target,
    output reg  [31:0] pc,
    output wire [31:0] pc_plus4
);
    assign pc_plus4 = pc + 32'd4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= RESET_PC;
        else if (en)
            pc <= jump_en ? {jump_target[31:1], 1'b0} : pc_plus4;
    end
endmodule
