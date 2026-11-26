# Capturas del juego "Invasores del espacio"

Así se ve el juego que trae cargado el `.sof` (`sw/games/invaders/invaders.c`), en la resolución del monitor (640×480).

| Archivo | Qué muestra |
|---|---|
| `01_pantalla_de_titulo.png` | Pantalla inicial, con el puntaje de cada invasor |
| `02_comienzo_de_partida.png` | Al apretar Start: 5×11 invasores, 4 escudos y el cañón |
| `03_disparando.png` | Primeros disparos y un invasor destruido |
| `04_escudos_danados.png` | Escudos rotos por los disparos |
| `05_platillo_misterio.png` | Platillo misterio (rojo) cruzando arriba |
| `06_invasores_avanzando.png` | Los invasores bajan y aceleran |
| `07_pierde_una_vida.png` | Explosión del cañón al recibir un disparo |
| `08_ultimos_invasores.png` | Quedan pocos invasores |
| `09_fin_del_juego.png` | Fin del juego |
| `partida_animada.gif` | 15 segundos de partida, en movimiento |

## Cómo se generaron

No son fotos del monitor. Son los cuadros de video que produce el mismo `invaders.c`, compilado para la PC con botones simulados (`sw/games/invaders/host_main.c`). En la simulación de la placa completa se verificó que la imagen HDMI que genera el ERV26 es idéntica píxel a píxel a esta.

Para volver a generarlas (en WSL, desde la carpeta del proyecto):

```
cd sw/games/invaders
gcc -O2 -DHOST -I. -o invaders_host invaders.c host_main.c
mkdir -p salida && ./invaders_host salida
```

Deja varios cuadros en `salida/` como `.ppm` (320×240), que se abren con GIMP o IrfanView.
