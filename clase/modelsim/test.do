# Un test cualquiera, con ondas:   do test.do <test> [condicion]
#   test:      ver programas/lista.txt (ej: rv32ui-beq, c-sort_crc, asm-branch_pred)
#   condicion: lat0 lat3 lat2+halt m10k m10k+halt   (por defecto m10k)
do compilar.do
quietly set T rv32ui-add
quietly set C m10k
if {$argc >= 1} { quietly set T $1 }
if {$argc >= 2} { quietly set C $2 }
quietly set P programas/$T
if {![file exists $P.imem.hex]} { echo "No existe el test $T (ver programas/lista.txt)"; abort }
vsim -quiet -t 1ps -onfinish stop -voptargs=+acc work.tb_core \
    +IMEM=$P.imem.hex +DMEM=$P.dmem.hex +TRACE=test.traza {*}[plusargs_cond $C]
gui { do ondas_pipeline.do }
run -all
gui { view wave; wave zoom full }
set r [comparar test.traza $P.esperado]
if {$r eq ""} { echo "$T ($C): PASS, coincide con el modelo de referencia" } \
else          { echo "$T ($C): FAIL $r" }
