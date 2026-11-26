# Regresion en ModelSim: corre cada programa y compara instruccion por
# instruccion (y cada store) contra lo que retira el modelo de referencia (ISS).
#   do regresion.do            condiciones lat0 y m10k
#   do regresion.do todas      las 5 condiciones de memoria
do compilar.do
quietly set conds {lat0 m10k}
if {$argc >= 1 && $1 eq "todas"} { quietly set conds {lat0 lat3 lat2+halt m10k m10k+halt} }
quietly set fh [open programas/lista.txt r]
quietly set tests [regexp -all -inline {\S+} [read $fh]]
close $fh
quietly set ok 0
quietly set fallas {}
foreach t $tests {
    foreach c $conds {
        quietly set P programas/$t
        vsim -quiet -t 1ps -onfinish stop work.tb_core \
            +IMEM=$P.imem.hex +DMEM=$P.dmem.hex +TRACE=regresion.traza {*}[plusargs_cond $c]
        run -all
        quit -sim
        quietly set r [comparar regresion.traza $P.esperado]
        if {$r eq ""} { incr ok } else { lappend fallas "$t ($c): $r" }
    }
}
echo ""
foreach f $fallas { echo "FAIL $f" }
echo "Regresion: $ok/[expr {[llength $tests] * [llength $conds]}] corridas OK ([llength $tests] programas x [llength $conds] condiciones: $conds)"
