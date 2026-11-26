// ============================================================================
// ERV26 - IF: seleccion de la proxima direccion de fetch (combinacional)
//   La M10K registra esta direccion en el flanco; su salida es la
//   instruccion del latch IF/ID. Prioridad:
//     freeze     -> repetir d_pc (ID se mantiene)
//     e_redirect -> correccion de EX (branch mal predicho o JALR)
//     load_use   -> repetir d_pc (stall de ID)
//     d_redirect -> destino desde ID (JAL o branch hacia atras predicho tomado)
//     si no      -> d_pc + 4
// ============================================================================
module erv26_pc_select (
    input  wire        freeze,
    input  wire        load_use,
    input  wire        e_redirect,
    input  wire [31:0] e_target,
    input  wire        d_redirect,
    input  wire [31:0] d_target,
    input  wire [31:0] d_pc,
    output reg  [31:0] f_pc
);
    always @(*) begin
        if (freeze)          f_pc = d_pc;
        else if (e_redirect) f_pc = e_target;
        else if (load_use)   f_pc = d_pc;
        else if (d_redirect) f_pc = d_target;
        else                 f_pc = d_pc + 32'd4;
    end
endmodule
