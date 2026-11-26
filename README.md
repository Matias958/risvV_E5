# risvV_E5 — Guía de uso

Procesador RISC-V (ERV26) con pipeline de 5 etapas para la placa DE10-Nano.

## Documentación

| Documento | Para qué |
|---|---|
| **`doc/guia_de_uso.pdf`** | **Guía completa paso a paso:** qué tiene el proyecto, cómo escribir y compilar un programa, cómo compilar en Quartus y cómo grabar la placa. Empezar por acá. |
| `doc/informe.pdf` | Informe técnico: cómo está diseñado el procesador, verificación, recursos y frecuencia máxima. |
| `doc/capturas_invaders/` | Imágenes y un GIF de cómo se ve el juego por HDMI. |
| `clase/LEEME.md` | Simulaciones con ondas en WSL (GTKWave). |
| `clase/modelsim/LEEME.md` | Simulaciones en ModelSim. |

Este README es un resumen rápido de la guía.

## Carpetas

| Carpeta / archivo | Qué hay |
|---|---|
| `risvV_E5.qpf` | Proyecto de Quartus (top: `risvV_E5.bdf`) |
| `rtl/` | Bloques Verilog y el núcleo `erv26_core.bdf` |
| `sw/` | Programas en C y assembler |
| `programas/` | Programas ya compilados (`leds`, `invaders`) |
| `output_files/risvV_E5.sof` | Archivo para grabar la placa |
| `clase/` | Simulaciones con ondas (GTKWave y ModelSim) |
| `electro5_instalar/` | Instalador del entorno de simulación en WSL |
| `doc/` | Guía de uso e informe |

## 1. Grabar la placa

1. Enchufar la fuente de 5 V de la placa (el USB no la alimenta).
2. Conectar el mini-USB **USB Blaster II** a la PC.
3. En Quartus: *Tools → Programmer*.
4. *Hardware Setup* → **DE-SoC**.
5. **Auto Detect** → elegir **5CSEBA6** → *Yes*.
6. Seleccionar la fila **5CSEBA6U23** → *Change File* → `output_files/risvV_E5.sof`.
7. Tildar **Program/Configure** y apretar **Start** (debe llegar a *100 % Successful*).

Se borra al apagar la placa: hay que volver a grabar cada vez.

Si el Programmer dice *No hardware*, instalar el driver desde el Administrador de dispositivos (*Actualizar controlador* → `C:\altera_lite\25.1std\quartus\drivers`).

## 2. Cambiar el programa

**Programas listos** (desde la carpeta del proyecto, en una terminal de Windows):

```
cambiar_programa.bat leds
cambiar_programa.bat invaders
```

**Programa propio en C** (desde WSL):

```
python3 sw/build.py mi_programa.c
```

Después, en los dos casos:

1. Quartus → *Processing → Start Compilation* (~12 min).
2. Grabar la placa (paso 1).

## 3. Usar la placa

| Control | Función |
|---|---|
| `KEY[0]` | Reset |
| `KEY[1]` (mantener) | Pausa el procesador |
| `SW[3:0]` | Demo de LEDs: patrón, velocidad y pausa |

**Juego (invaders):** conectar un monitor por HDMI. La imagen aparece ~1 s después del reset.

Botones en el header **GPIO 0 (JP1)**, cada uno entre su pin y GND:

| Pin de JP1 | Botón |
|---|---|
| 1 | Izquierda |
| 2 | Derecha |
| 3 | Disparo |
| 4 | Start |
| 12 o 30 | GND |

Los pines son de 3,3 V. No conectar nada a 5 V (pin 11).

## 4. Simular

### En WSL (Ubuntu)

Si no tenés WSL: abrir PowerShell como administrador, correr `wsl --install`, reiniciar y abrir **Ubuntu** desde el menú Inicio (pide crear usuario y clave). Detalle en `doc/guia_de_uso.pdf`.

Instalar el entorno una vez (borra y reemplaza `~/electro5`):

```
cd ~
bash /mnt/c/<ruta>/risvV_E5/electro5_instalar/instalar.sh
```

Usar:

```
cd ~/electro5
make                 # menú
make tests           # verificación completa
make pipeline        # ondas del pipeline en GTKWave
make placa           # demo de LEDs
make video           # salida HDMI
make juego           # cuadros del juego en PNG
```

### En ModelSim

1. *File → Change Directory* → `risvV_E5\clase\modelsim`.
2. En el *Transcript*:

```
do pipeline.do
do test.do rv32ui-beq
do regresion.do
do placa.do
do gate.do
```

Más detalle en `clase/LEEME.md` y `clase/modelsim/LEEME.md`.

## 5. Problemas comunes

| Problema | Qué hacer |
|---|---|
| Windows no detecta la placa | Revisar la fuente de 5 V y probar otro cable USB |
| *No hardware* en el Programmer | Instalar el driver (ver paso 1) |
| Pantalla negra | Esperar 1 s o apretar `KEY[0]` |
| Cambié el programa y no se nota | Recompilar en Quartus y volver a grabar |
