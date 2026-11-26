# Simulacion gate-level: el nucleo tal como lo sintetizo y ubico Quartus
# (gate_sim/simulation/questa/core_gl.vo), con los modelos de las celdas de la
# Cyclone V de tu Quartus. Compara cada instruccion contra el modelo de referencia.
#   do gate.do                      programa de demo, con ondas de los puertos
#   do gate.do regresion            los riscv-tests (condiciones lat0 y m10k)
#   do gate.do regresion todas      los riscv-tests en las 5 condiciones
source comun.tcl
quietly set SIMLIB C:/altera_lite/25.1std/quartus/eda/sim_lib
quietly set VO $ROOT/gate_sim/simulation/questa/core_gl.vo
if {![file exists $SIMLIB/cyclonev_atoms.v]} { echo "No encuentro $SIMLIB (editar SIMLIB en gate.do)"; abort }

# librerias de la Cyclone V: se compilan una sola vez (tarda un minuto)
if {![file exists cyclonev_lib]} {
    echo "Compilando las librerias de simulacion de la Cyclone V (una sola vez)..."
    vlib cyclonev_lib
    vlog -quiet -work cyclonev_lib $SIMLIB/altera_primitives.v $SIMLIB/cyclonev_atoms.v $ROOT/sim/gate_stubs.v
}
vmap cyclonev_lib cyclonev_lib
if {[file exists gate_lib]} { vdel -lib gate_lib -all }
vlib gate_lib
vmap gate_lib gate_lib
vlog -quiet -work gate_lib -timescale 1ns/1ps +define+GATE +incdir+$ROOT/rtl +incdir+$ROOT/sim \
    $VO $ROOT/rtl/erv26_dmem.v $ROOT/sim/tb_core.v

proc correr_gate {t c ondas} {
    set P programas/$t
    set th [pc_tohost $P.esperado]
    set acc [expr {$ondas ? "-voptargs=+acc" : ""}]
    vsim -quiet -t 1ps -onfinish stop {*}$acc -L cyclonev_lib gate_lib.tb_core \
        +IMEM=$P.imem.hex +DMEM=$P.dmem.hex +TRACE=gate.traza +TOHOST_PC=$th {*}[plusargs_cond $c]
}

if {$argc >= 1 && $1 eq "regresion"} {
    quietly set conds {lat0 m10k}
    if {$argc >= 2 && $2 eq "todas"} { quietly set conds {lat0 lat3 lat2+halt m10k m10k+halt} }
    quietly set fh [open programas/lista.txt r]
    quietly set tests [lsearch -all -inline [regexp -all -inline {\S+} [read $fh]] rv32ui-*]
    close $fh
    quietly set ok 0; quietly set fallas {}
    foreach t $tests {
        foreach c $conds {
            correr_gate $t $c 0
            run -all
            quit -sim
            quietly set r [comparar gate.traza programas/$t.esperado]
            if {$r eq ""} { incr ok } else { lappend fallas "$t ($c): $r" }
        }
    }
    echo ""
    foreach f $fallas { echo "FAIL $f" }
    echo "Gate-level: $ok/[expr {[llength $tests] * [llength $conds]}] corridas OK ($conds)"
} else {
    correr_gate asm-pipeline_demo m10k 1
gui {
        onerror {resume}
        add wave -noupdate -divider {Netlist: solo se ven los puertos del nucleo}
        add wave -noupdate /tb_core/clk
        add wave -noupdate /tb_core/rst_n
        add wave -noupdate -radix hexadecimal /tb_core/imem_addr
        add wave -noupdate -radix hexadecimal /tb_core/imem_rdata
        add wave -noupdate -divider {Instruccion que se retira}
        add wave -noupdate /tb_core/c_valid
        add wave -noupdate -radix hexadecimal /tb_core/c_pc
        add wave -noupdate -radix hexadecimal /tb_core/c_instr
        add wave -noupdate /tb_core/c_we
        add wave -noupdate -radix hexadecimal /tb_core/c_data
        add wave -noupdate -divider {Memoria de datos}
        add wave -noupdate /tb_core/dmem_req
        add wave -noupdate /tb_core/dmem_we
        add wave -noupdate /tb_core/dmem_ready
        add wave -noupdate -radix hexadecimal /tb_core/dmem_addr
        add wave -noupdate -radix hexadecimal /tb_core/dmem_wdata
        add wave -noupdate -radix hexadecimal /tb_core/dmem_rdata
        configure wave -namecolwidth 170 -valuecolwidth 110 -timelineunits ns -signalnamewidth 1
}
    run -all
    gui { view wave; wave zoom range 90ns 520ns }
    set r [comparar gate.traza programas/asm-pipeline_demo.esperado]
    if {$r eq ""} { echo "netlist post-fit: coincide con el modelo de referencia" } else { echo "netlist: ERROR $r" }
}
