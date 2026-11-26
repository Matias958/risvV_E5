// ============================================================================
// ERV26 - Control de pipeline y halt
//
//   Genera las senales de habilitacion (stage ena) y descarte (stage x) de
//   los latches de etapa:
//
//   freeze    : congela TODO el pipeline (PC y las 4 etapas).
//               - en = 0 (halt externo / paso a paso)
//               - acceso a memoria de datos en curso sin memory_ready
//   load_use  : RAW contra un LOAD que esta en EX. El dato recien existe al
//               final de MEM, asi que se detienen PC e IF/ID un ciclo y se
//               inserta una burbuja en ID/EX. Luego se resuelve por
//               forwarding desde WB.
//   flush_id  : una correccion en EX (branch mal predicho o JALR) descarta
//               la instruccion que esta en ID (ID/EX <- burbuja).
//
//   Las dependencias RAW contra instrucciones de ALU no detienen nada: se
//   resuelven con forwarding (erv26_forward_unit).
// ============================================================================
module erv26_hazard_unit (
    input  wire       en,
    // Memoria de datos
    input  wire       mem_req,
    input  wire       mem_ready,
    // Instruccion en ID
    input  wire       d_valid,
    input  wire [4:0] d_rs1,
    input  wire [4:0] d_rs2,
    input  wire       d_use_rs1,
    input  wire       d_use_rs2,
    // Instruccion en EX
    input  wire       e_valid,
    input  wire       e_load,
    input  wire [4:0] e_rd,
    input  wire       e_redirect,

    output wire       freeze,
    output wire       load_use,
    output wire       flush_id
);
    assign freeze = ~en | (mem_req & ~mem_ready);

    assign load_use = d_valid & e_valid & e_load & (e_rd != 5'd0) &
                      ((d_use_rs1 & (d_rs1 == e_rd)) |
                       (d_use_rs2 & (d_rs2 == e_rd)));

    assign flush_id = e_redirect;
endmodule
