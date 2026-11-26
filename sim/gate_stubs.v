// ============================================================================
// Modelos para simular con Icarus el netlist de Quartus (tb_core -DGATE).
//   cyclonev_atoms.v define cyclonev_clkena como envoltorio de un modelo
//   encriptado (solo Questa lo puede leer). En nuestro netlist el clkena es el
//   buffer de reloj global, con ena = vcc y ena_register_mode = "always
//   enabled": la salida es el reloj de entrada sin cambios.
// ============================================================================
module cyclonev_clkena_encrypted (inclk, ena, enaout, outclk);
    parameter clock_type            = "auto";
    parameter ena_register_mode     = "always enabled";
    parameter lpm_type              = "cyclonev_clkena";
    parameter ena_register_power_up = "high";
    parameter disable_mode          = "low";
    parameter test_syn              = "high";
    input  inclk, ena;
    output enaout, outclk;
    assign outclk = inclk;
    assign enaout = ena;
    initial if (ena_register_mode != "always enabled")
        $display("AVISO gate_stubs: clkena con ena_register_mode=%0s no modelado", ena_register_mode);
endmodule
