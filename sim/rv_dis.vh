// Desensamblador RV32I en Verilog (solo para simulacion).
// rv_dis(instruccion) devuelve un texto de hasta 28 caracteres, para ver en
// las ondas con radix ASCII (ModelSim) o formato ASCII (GTKWave).
// Es el mismo formato que clase/rv_dis.py.

function [8*5-1:0] rv_reg;
    input [4:0] r;
    case (r)
        0: rv_reg = "zero"; 1: rv_reg = "ra";  2: rv_reg = "sp";  3: rv_reg = "gp";
        4: rv_reg = "tp";   5: rv_reg = "t0";  6: rv_reg = "t1";  7: rv_reg = "t2";
        8: rv_reg = "s0";   9: rv_reg = "s1";  10: rv_reg = "a0"; 11: rv_reg = "a1";
        12: rv_reg = "a2";  13: rv_reg = "a3"; 14: rv_reg = "a4"; 15: rv_reg = "a5";
        16: rv_reg = "a6";  17: rv_reg = "a7"; 18: rv_reg = "s2"; 19: rv_reg = "s3";
        20: rv_reg = "s4";  21: rv_reg = "s5"; 22: rv_reg = "s6"; 23: rv_reg = "s7";
        24: rv_reg = "s8";  25: rv_reg = "s9"; 26: rv_reg = "s10"; 27: rv_reg = "s11";
        28: rv_reg = "t3";  29: rv_reg = "t4"; 30: rv_reg = "t5"; default: rv_reg = "t6";
    endcase
endfunction

function [8*28-1:0] rv_dis;
    input [31:0] w;
    reg [8*28-1:0] s;
    reg [8*6-1:0] n;
    reg [6:0] op; reg [4:0] rd, rs1, rs2; reg [2:0] f3; reg [6:0] f7;
    integer ii, si, bi, ji;
    begin
        op = w[6:0]; rd = w[11:7]; f3 = w[14:12]; rs1 = w[19:15]; rs2 = w[24:20]; f7 = w[31:25];
        ii = {{20{w[31]}}, w[31:20]};
        si = {{20{w[31]}}, w[31:25], w[11:7]};
        bi = {{19{w[31]}}, w[31], w[7], w[30:25], w[11:8], 1'b0};
        ji = {{11{w[31]}}, w[31], w[19:12], w[20], w[30:21], 1'b0};
        s = "?";
        if (w === 32'h0) s = "-- burbuja --";
        else if (^w === 1'bx) s = "x";
        else if (w == 32'h00000013) s = "nop";
        else case (op)
            7'h37: $sformat(s, "lui %0s,0x%0h", rv_reg(rd), w[31:12]);
            7'h17: $sformat(s, "auipc %0s,0x%0h", rv_reg(rd), w[31:12]);
            7'h6F: if (rd == 0) $sformat(s, "j %0s%0d", ji < 0 ? "-" : "+", ji < 0 ? -ji : ji);
                   else         $sformat(s, "jal %0s,%0s%0d", rv_reg(rd), ji < 0 ? "-" : "+", ji < 0 ? -ji : ji);
            7'h67: if (rd == 0 && rs1 == 1 && ii == 0) s = "ret";
                   else $sformat(s, "jalr %0s,%0d(%0s)", rv_reg(rd), ii, rv_reg(rs1));
            7'h63: begin
                case (f3) 0: n = "beq"; 1: n = "bne"; 4: n = "blt"; 5: n = "bge";
                          6: n = "bltu"; 7: n = "bgeu"; default: n = "?b"; endcase
                if (rs2 == 0 && (f3 == 0 || f3 == 1))
                    $sformat(s, "%0sz %0s,%0s%0d", n, rv_reg(rs1), bi < 0 ? "-" : "+", bi < 0 ? -bi : bi);
                else
                    $sformat(s, "%0s %0s,%0s,%0s%0d", n, rv_reg(rs1), rv_reg(rs2), bi < 0 ? "-" : "+", bi < 0 ? -bi : bi);
            end
            7'h03: begin
                case (f3) 0: n = "lb"; 1: n = "lh"; 2: n = "lw"; 4: n = "lbu"; 5: n = "lhu";
                          default: n = "?l"; endcase
                $sformat(s, "%0s %0s,%0d(%0s)", n, rv_reg(rd), ii, rv_reg(rs1));
            end
            7'h23: begin
                case (f3) 0: n = "sb"; 1: n = "sh"; 2: n = "sw"; default: n = "?s"; endcase
                $sformat(s, "%0s %0s,%0d(%0s)", n, rv_reg(rs2), si, rv_reg(rs1));
            end
            7'h13: begin
                if (f3 == 0 && rs1 == 0) $sformat(s, "li %0s,%0d", rv_reg(rd), ii);
                else if (f3 == 1) $sformat(s, "slli %0s,%0s,%0d", rv_reg(rd), rv_reg(rs1), rs2);
                else if (f3 == 5) $sformat(s, "%0s %0s,%0s,%0d", f7[5] ? "srai" : "srli", rv_reg(rd), rv_reg(rs1), rs2);
                else begin
                    case (f3) 0: n = "addi"; 2: n = "slti"; 3: n = "sltiu"; 4: n = "xori";
                              6: n = "ori"; default: n = "andi"; endcase
                    $sformat(s, "%0s %0s,%0s,%0d", n, rv_reg(rd), rv_reg(rs1), ii);
                end
            end
            7'h33: begin
                case ({f3, f7[5]})
                    4'b0000: n = "add"; 4'b0001: n = "sub"; 4'b0010: n = "sll"; 4'b0100: n = "slt";
                    4'b0110: n = "sltu"; 4'b1000: n = "xor"; 4'b1010: n = "srl"; 4'b1011: n = "sra";
                    4'b1100: n = "or"; 4'b1110: n = "and"; default: n = "?r";
                endcase
                $sformat(s, "%0s %0s,%0s,%0s", n, rv_reg(rd), rv_reg(rs1), rv_reg(rs2));
            end
            7'h0F: s = "fence";
            7'h73: s = (w == 32'h00000073) ? "ecall" : (w == 32'h00100073) ? "ebreak" : "system";
            default: $sformat(s, "?? %08h", w);
        endcase
        rv_dis = s;
    end
endfunction
