# Compila el RTL del ERV26 (nucleo y placa) y los testbenches en la libreria work.
# Lo llaman los demas scripts; no hace falta correrlo a mano.
source comun.tcl
if {![file exists work]} { vlib work }
vmap work work

quietly set rtl {}
foreach f [lsort [glob $ROOT/rtl/erv26_*.v]] {
    if {![regexp {mvp0|erv26_fetch|erv26_prog_mem} $f]} { lappend rtl $f }
}
foreach f [lsort [glob $ROOT/rtl/board/erv26_*.v]] { lappend rtl $f }

# gen/: los .bdf (nucleo y top) convertidos a Verilog con tools/bdf2v.py
vlog -quiet -timescale 1ns/1ps +incdir+$ROOT/rtl +incdir+$ROOT/sim +define+TOP=risvV_E5 \
    gen/erv26_core_bdf.v gen/risvV_E5_bdf.v {*}$rtl \
    $ROOT/sim/tb_core.v $ROOT/sim/tb_board.v $ROOT/sim/video/tb_video.v $ROOT/sim/video/tb_i2c.v
