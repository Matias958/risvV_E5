// Señales extra para mirar el pipeline en GTKWave (make pipeline).
// Solo se leen señales del núcleo; no cambian la simulación.
// Una instrucción 0 significa "burbuja": la etapa no tiene instrucción válida.
wire [31:0] IF_pc     = dut.imem_addr;                          // dirección que se busca
wire [31:0] ID_pc     = dut.d_pc;
wire [31:0] ID_instr  = dut.d_valid ? imem_rdata  : 32'h0;
wire [31:0] EX_instr  = dut.e_valid ? dut.e_instr : 32'h0;
wire [31:0] MEM_instr = dut.m_valid ? dut.m_instr : 32'h0;
wire [31:0] WB_instr  = dut.w_valid ? dut.w_instr : 32'h0;

// Las mismas instrucciones como texto (radix ASCII en ModelSim)
`include "rv_dis.vh"
reg [8*28-1:0] ID_txt, EX_txt, MEM_txt, WB_txt;
always @(*) begin
    ID_txt = rv_dis(ID_instr);   EX_txt = rv_dis(EX_instr);
    MEM_txt = rv_dis(MEM_instr); WB_txt = rv_dis(WB_instr);
end

// Control de hazards
wire stall_load_use = dut.load_use;        // ID espera un ciclo al load que está en EX
wire espera_memoria = dut.freeze;          // todo el pipeline congelado (memoria sin ready)
wire flush_ID       = dut.flush_id;
wire salto_en_ID    = dut.d_redirect;      // jal o branch hacia atrás (predicho tomado)
wire corrige_en_EX  = dut.e_redirect;      // branch mal predicho o jalr

// Forwarding hacia EX (misma lógica que erv26_forward_unit)
wire m_src = dut.m_valid & dut.m_we & ~dut.m_load & (dut.m_rd != 5'd0);
wire w_src = dut.w_valid & dut.w_we & (dut.w_rd != 5'd0);
wire fwd_rs1_desde_MEM = dut.e_valid & m_src & (dut.m_rd == dut.e_rs1);
wire fwd_rs1_desde_WB  = dut.e_valid & ~fwd_rs1_desde_MEM & w_src & (dut.w_rd == dut.e_rs1);
wire fwd_rs2_desde_MEM = dut.e_valid & m_src & (dut.m_rd == dut.e_rs2);
wire fwd_rs2_desde_WB  = dut.e_valid & ~fwd_rs2_desde_MEM & w_src & (dut.w_rd == dut.e_rs2);

// Algunos registros por nombre ABI
wire [31:0] ra = dut.u_rf.regs[1],  sp = dut.u_rf.regs[2];
wire [31:0] t0 = dut.u_rf.regs[5],  t1 = dut.u_rf.regs[6],  t2 = dut.u_rf.regs[7];
wire [31:0] s0 = dut.u_rf.regs[8],  s1 = dut.u_rf.regs[9];
wire [31:0] a0 = dut.u_rf.regs[10], a1 = dut.u_rf.regs[11], a2 = dut.u_rf.regs[12];
wire [31:0] a3 = dut.u_rf.regs[13], a4 = dut.u_rf.regs[14], a5 = dut.u_rf.regs[15];
wire [31:0] a6 = dut.u_rf.regs[16], s2 = dut.u_rf.regs[18];
wire [31:0] t3 = dut.u_rf.regs[28], t4 = dut.u_rf.regs[29];
