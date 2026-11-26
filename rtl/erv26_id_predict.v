// ============================================================================
// ERV26 - ID: JAL y prediccion de saltos "hacia atras tomado, hacia adelante
// no tomado" (BTFN)
//   El destino PC + imm no depende de registros, asi que se calcula en ID.
//   - JAL: siempre se toma -> el fetch salta al destino sin perder ciclos.
//   - Branch con offset negativo (cierre de loop): se predice tomado y el
//     fetch salta al destino ya desde ID. Si en EX resulta no tomado,
//     erv26_branch_unit corrige a PC+4 (1 ciclo perdido).
//   - Branch con offset positivo: se predice no tomado (sigue en PC+4).
//   pred_taken viaja con el branch por ID/EX para que EX sepa que se predijo.
// ============================================================================
module erv26_id_predict (
    input  wire        d_valid,
    input  wire        is_jal,
    input  wire        is_branch,
    input  wire [31:0] pc,
    input  wire [31:0] imm,
    output wire        redirect,
    output wire [31:0] target,
    output wire        pred_taken
);
    wire backward = imm[31];                 // offset negativo

    assign pred_taken = d_valid & is_branch & backward;
    assign redirect   = (d_valid & is_jal) | pred_taken;
    assign target     = pc + imm;
endmodule
