# ERV26 en ModelSim

Scripts para simular el ERV26 en ModelSim (Intel FPGA Starter Edition) con las mismas vistas que en GTKWave.

## Uso

1. Abrir ModelSim.
2. *File → Change Directory…* → `Escritorio\risvV_E5\clase\modelsim`.
3. En la consola de abajo (*Transcript*) escribir uno de estos comandos:

| Comando | Qué hace |
|---|---|
| `do pipeline.do` | Programa de demo del pipeline, con la instrucción de cada etapa como texto y cursores A–G en cada caso |
| `do test.do rv32ui-beq` | Cualquier test con ondas (lista en `programas/lista.txt`); opcional la condición: `do test.do c-sort_crc lat3` |
| `do regresion.do` | Corre los 45 programas y compara cada instrucción y cada store contra el modelo de referencia (condiciones `lat0` y `m10k`); `do regresion.do todas` usa las 5 condiciones |
| `do placa.do` | Placa completa (top `.bdf`) con la demo de LEDs |
| `do video.do` | Generador HDMI (tarda ~1 min); guarda `frame0.ppm` y `frame1.ppm` |
| `do i2c.do` | Configuración del ADV7513 por I2C |
| `do gate.do` | Netlist post-fit de Quartus con el programa de demo; `do gate.do regresion` corre los riscv-tests sobre el netlist (~30 min: el netlist supera la capacidad de la edición Starter y cada corrida tarda entre 10 s y 1 min) |

Cada script compila todo de nuevo, así que siempre simula la versión actual de los `.v`.

Para proyectar en clase conviene sacar las ondas a una ventana propia y maximizarla: botón *Dock/Undock* arriba a la derecha del panel *Wave*, o `view -undock wave` en el Transcript. Para moverse: `wave zoom range 300ns 500ns`, *Zoom Full* (F en el panel de ondas) y los cursores A–G de la lista de abajo (doble clic en uno lo centra).

## Qué hay en esta carpeta

- `gen/`: el núcleo (`erv26_core.bdf`) y el top (`risvV_E5.bdf`) convertidos a Verilog, porque ModelSim no lee `.bdf`.
- `programas/`: los programas ya compilados (`.hex`) y lo que debe retirar el núcleo según el modelo de referencia (`.esperado`).

Las dos carpetas se generan desde WSL. Si cambiás un `.bdf` o un programa, hay que regenerarlas:

```
cd ~/electro5 && make modelsim
```

(o `python3 clase/modelsim/exportar.py` en el proyecto). En WSL esto actualiza la copia de `~/electro5`; para la del Escritorio, correrlo en `/mnt/c/Users/matia/Desktop/risvV_E5`.

## Gate-level

`gate.do` usa las librerías de simulación de Quartus 25.1 (`C:/altera_lite/25.1std/quartus/eda/sim_lib`), no las que trae ModelSim 20.1. Así coinciden con la versión que generó el netlist. La primera vez las compila (~1 min) en `cyclonev_lib/`.
