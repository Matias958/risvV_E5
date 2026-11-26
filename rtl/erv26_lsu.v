// ============================================================================
// ERV26 - Load/Store unit (etapa MEM)
//   La memoria de datos es de 32 bits con byte enables; la direccion es de
//   byte. Este bloque:
//     STORE: arma byte enables y replica el dato en los carriles (SB/SH/SW)
//     LOAD : elige byte/halfword de la palabra leida y extiende signo/cero
//
//   Accesos desalineados (LH/SH en direccion impar, LW/SW no multiplo de 4)
//   no se soportan ni generan trap: se ignoran los bits bajos que sobran.
//   (posible mejora junto con traps de la Parte III)
// ============================================================================
module erv26_lsu (
    input  wire [2:0]  funct3,
    input  wire [1:0]  addr_lo,      // addr[1:0]
    // Store
    input  wire [31:0] store_data,   // rs2
    output reg  [3:0]  be,
    output reg  [31:0] wdata,
    // Load
    input  wire [31:0] rdata,        // palabra leida de memoria
    output reg  [31:0] load_data
);
    // ---- Store ----
    always @(*) begin
        case (funct3[1:0])
            2'b00: begin                                  // SB
                be    = 4'b0001 << addr_lo;
                wdata = {4{store_data[7:0]}};
            end
            2'b01: begin                                  // SH
                be    = addr_lo[1] ? 4'b1100 : 4'b0011;
                wdata = {2{store_data[15:0]}};
            end
            default: begin                                // SW
                be    = 4'b1111;
                wdata = store_data;
            end
        endcase
    end

    // ---- Load ----
    wire [7:0]  byte_sel = rdata >> {addr_lo, 3'b000};
    wire [15:0] half_sel = addr_lo[1] ? rdata[31:16] : rdata[15:0];

    always @(*) begin
        case (funct3)
            3'b000:  load_data = {{24{byte_sel[7]}}, byte_sel};   // LB
            3'b001:  load_data = {{16{half_sel[15]}}, half_sel};  // LH
            3'b100:  load_data = {24'd0, byte_sel};               // LBU
            3'b101:  load_data = {16'd0, half_sel};               // LHU
            default: load_data = rdata;                           // LW
        endcase
    end
endmodule
