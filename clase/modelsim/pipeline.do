# Programa de demo del pipeline (sw/tests/pipeline_demo.S) con la RAM real de la placa.
#   do pipeline.do
do compilar.do
quietly set P programas/asm-pipeline_demo
vsim -quiet -t 1ps -onfinish stop -voptargs=+acc work.tb_core \
    +IMEM=$P.imem.hex +DMEM=$P.dmem.hex +TRACE=pipeline.traza +MEM_RTL
gui { do ondas_pipeline.do }
run -all

gui {
    # Cursores donde cada caso entra a ID (los mismos marcadores A-G que en GTKWave)
    foreach {t n} {130 A_sin_dependencias 190 B_forwarding 250 C_load_use 350 D_load_sin_stall
                   410 E_loop_BTFN 630 F_branch_adelante 670 G_llamada} {
        catch { wave cursor add -time ${t}ns -name $n -lock 1 }
    }
    view wave
    wave zoom range 90ns 330ns
}

set r [comparar pipeline.traza $P.esperado]
if {$r eq ""} { echo "pipeline_demo: coincide instruccion por instruccion con el modelo de referencia" } \
else          { echo "pipeline_demo: ERROR $r" }
