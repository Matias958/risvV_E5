# ERV26 (risvV_E5) — simulaciones para mostrar en clase

Todo se corre desde la carpeta `~/electro5` con `make`. Las ondas se abren en GTKWave (en WSL aparece como una ventana de Windows). Los archivos generados quedan en `risvV_E5/clase/salida/`.

```
cd ~/electro5
make            # menú
make entorno    # verifica herramientas
```

| Comando | Qué muestra | Tiempo |
|---|---|---|
| `make tests` | Regresión completa: 145 programas (riscv-tests oficiales, C, asm y aleatorios) × 5 condiciones de memoria, comparados instrucción por instrucción contra el modelo de referencia (ISS) | ~30 s |
| `make tests-rapido` | Lo mismo sin los 100 programas aleatorios | ~10 s |
| `make pipeline` | Programa de demo con un caso por bloque y las ondas del pipeline, con las instrucciones desensambladas en cada etapa | ~2 s |
| `make test T=rv32ui-beq` | Ondas de cualquier test (`T=c-sort_crc`, `T=asm-branch_pred`, ...) y condición (`COND=lat3`, ...) | ~2 s |
| `make placa` | Placa completa (top `.bdf`) con la demo de LEDs: switches, LEDs y halt | ~20 s |
| `make video` | Generador HDMI 640×480: hsync, vsync, DE, píxeles y doble buffer; guarda 2 cuadros en PNG | ~1 min |
| `make i2c` | Configuración del ADV7513 por I2C, con los bytes decodificados | ~1 s |
| `make juego` | Placa completa corriendo el Space Invaders; guarda cuadros HDMI en PNG (`FRAMES=12`) | ~5 min |
| `make gate` | riscv-tests oficiales sobre el netlist post-fit de Quartus, en las 5 condiciones (usa las librerías de Quartus desde Windows) | 5–25 min según los núcleos de la PC |
| `make gate-completo` | Además los programas C y asm sobre el netlist | más de 30 min |
| `make gate-pipeline` | Ondas del programa de demo en el netlist post-fit | ~10 s |

`VER=0` genera todo sin abrir GTKWave.

## `make pipeline`: qué mirar

Programa: `risvV_E5/sw/tests/pipeline_demo.S`. Corre con la RAM real de la placa (condición `m10k`). Las filas `ID_instr` … `WB_instr` muestran la instrucción que hay en cada etapa; `-- burbuja --` es una etapa vacía.

GTKWave abre con los marcadores **A–G** puestos donde cada caso entra a ID:

| Marcador | Caso | Qué se ve |
|---|---|---|
| A | Sin dependencias | Una instrucción nueva por ciclo en cada etapa (CPI = 1) |
| B | Forwarding | `fwd_rs1_desde_MEM` en `addi a1,a0,1`; en `add a2,a0,a1` llegan `a0` desde WB y `a1` desde MEM |
| C | Load-use | `stall_load_use` 1 ciclo: `addi a4,a3,1` espera en ID y entra una burbuja a EX. Además `espera_memoria` 1 ciclo: el `lw` lee la palabra que el `sw` anterior está escribiendo en la M10K, y la memoria tarda un ciclo más para no entregar un dato indefinido. Con otra dirección ese ciclo no aparece |
| D | Load sin stall | Con una instrucción en el medio, el dato del `lw` llega por forwarding desde WB |
| E | Loop con BTFN | `salto_en_ID` en cada `bnez` hacia atrás: se predice tomado y el destino entra a ID en el ciclo siguiente, sin burbujas. A la salida del loop la predicción falla: `corrige_en_EX` y `flush_ID` anulan la instrucción que estaba en ID (1 ciclo perdido) |
| F | Branch hacia adelante tomado | Predicho no tomado: se corrige en EX, `addi s1,s1,100` se anula y se pierde 1 ciclo |
| G | Llamada y retorno | `jal` salta desde ID sin perder ciclos (la memoria de programa recibe la dirección siguiente en el mismo ciclo); `ret` (jalr) se resuelve en EX y pierde 1 ciclo |

Otros detalles:
- `dmem_rdata` cambia todos los ciclos: mientras la memoria no da `ready`, el testbench le pone basura a propósito, para detectar si el núcleo usa un dato antes de tiempo.
- `dmem_addr_next` va un ciclo adelante de `dmem_addr`: es la lectura anticipada de la RAM.
- Los registros se ven en decimal al final de la lista.

## Usar GTKWave

- **Zoom:** rueda del mouse con Ctrl, o los botones de lupa. *Zoom Fit* muestra toda la simulación.
- **Marcadores:** clic en la regla de tiempo pone el cursor; los marcadores A–G se ven como líneas punteadas con la letra arriba.
- **Agregar señales:** abrir el panel *SST* (flecha arriba a la izquierda), elegir el módulo y arrastrar la señal a la lista.
- **Formato:** clic derecho sobre una señal → *Data Format* (hex, decimal, binario).
- Las vistas se pueden guardar con *File → Write Save File*.

## Estructura

```
electro5/
  Makefile                 llama a risvV_E5/clase/Makefile
  instalar_dependencias.sh iverilog, gtkwave, gcc RISC-V
  risvV_E5/                proyecto (el mismo que el de Quartus)
    rtl/                   bloques Verilog y erv26_core.bdf
    risvV_E5.bdf           top de placa por bloques
    sim/                   testbenches y runner de la regresión
    sw/                    programas (tests, demo de LEDs, juego)
    tools/                 bdf2v (BDF → Verilog), ISS, elf2hex
    clase/                 este Makefile, vistas de GTKWave y scripts
  riscv-tests/             tests oficiales rv32ui (solo isa/)
```

Las simulaciones usan los `.bdf` del proyecto: `tools/bdf2v.py` los convierte a Verilog antes de compilar, así que se simula exactamente lo que se sintetiza en Quartus.

## Gate-level

`make gate` y `make gate-completo` usan el netlist `risvV_E5/gate_sim/simulation/questa/core_gl.vo` (generado por Quartus) y las librerías de simulación de Quartus, que se leen desde Windows:

```
make gate SIMLIB=/mnt/c/altera_lite/25.1std/quartus/eda/sim_lib
```

Ese es el valor por defecto. Si Quartus está en otra carpeta, hay que pasarla con `SIMLIB=`.
