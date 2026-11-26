# ============================================================================
# ERV26 (risvV_E5) - simulaciones para mostrar en clase
#
#   make            menu de opciones
#   make pipeline   programa de demo + ondas del pipeline en GTKWave
#   make tests      regresion completa contra el modelo de referencia (ISS)
#   ...
# Los resultados quedan en clase/salida/. VER=0 genera las ondas sin abrir GTKWave.
# ============================================================================
SHELL   := /bin/bash
ROOT    := $(abspath ..)
CLASE   := $(abspath .)
OUT     := $(CLASE)/salida
RTL     := $(ROOT)/rtl
SIM     := $(ROOT)/sim
PY      := python3
GTKWAVE ?= gtkwave
VER     ?= 1
JOBS    ?= $(shell nproc 2>/dev/null || echo 2)
T       ?= rv32ui-add
COND    ?= m10k
FRAMES  ?= 12
# Simulacion gate-level: netlist post-fit de Quartus y sus librerias (desde Windows)
SIMLIB  ?= /mnt/c/altera_lite/25.1std/quartus/eda/sim_lib
NETLIST ?= $(ROOT)/gate_sim/simulation/questa/core_gl.vo

BLOQUES := $(filter-out %mvp0.v %erv26_fetch.v %erv26_prog_mem.v,$(wildcard $(RTL)/*.v))
PLACA   := $(filter-out %mvp0_top.v %de10nano_erv26_top.v,$(wildcard $(RTL)/board/*.v))
CORE_V  := $(OUT)/erv26_core_bdf.v
TOP_V   := $(OUT)/risvV_E5_bdf.v
IVERILOG := iverilog -g2012 -I $(RTL) -I $(RTL)/board -I $(SIM)

define abrir
	@if [ "$(VER)" = "1" ]; then \
	  echo "Abriendo GTKWave..."; \
	  ( cd $(OUT) && $(GTKWAVE) $(1) $(2) >/dev/null 2>&1 & ); \
	else echo "Ondas: $(1)  (vista: $(2))"; fi
endef

.PHONY: modelsim ayuda entorno tests tests-rapido pipeline test placa video i2c juego gate gate-completo gate-pipeline limpiar

ayuda:
	@echo ""
	@echo "  ERV26 - simulaciones para clase (resultados en clase/salida/)"
	@echo ""
	@echo "  make entorno        verifica que esten las herramientas"
	@echo "  make tests          regresion completa: 145 programas x 5 condiciones de memoria,"
	@echo "                      comparados instruccion por instruccion contra el ISS"
	@echo "  make tests-rapido   solo riscv-tests oficiales + programas C + asm (sin aleatorios)"
	@echo "  make pipeline       programa de demo (forwarding, load-use, BTFN, saltos)"
	@echo "                      y ondas del pipeline con las instrucciones desensambladas"
	@echo "  make test T=<nombre> [COND=lat0|lat3|lat2+halt|m10k|m10k+halt]"
	@echo "                      ondas de un test cualquiera (ej: T=rv32ui-beq, T=c-sort_crc)"
	@echo "  make placa          placa completa con la demo de LEDs (switches, LEDs, halt)"
	@echo "  make video          generador HDMI 640x480: sincronismos + 2 cuadros en PNG"
	@echo "  make i2c            configuracion del ADV7513 por I2C"
	@echo "  make juego          placa completa corriendo el Space Invaders (unos minutos):"
	@echo "                      guarda cuadros HDMI en PNG [FRAMES=$(FRAMES)]"
	@echo "  make gate           riscv-tests sobre el netlist post-fit de Quartus"
	@echo "  make gate-completo  ademas programas C y asm (lento: mas de 30 min)"
	@echo "  make gate-pipeline  ondas del programa de demo en el netlist post-fit"
	@echo "  make modelsim       regenera clase/modelsim (BDF a Verilog, programas y esperados)"
	@echo "  make limpiar        borra clase/salida y las compilaciones"
	@echo ""
	@echo "  VER=0 genera los archivos sin abrir GTKWave."
	@echo ""

entorno:
	@ok=1; for h in iverilog vvp python3 riscv64-unknown-elf-gcc $(GTKWAVE); do \
	  if command -v $$h >/dev/null; then printf "  %-26s OK\n" $$h; \
	  else printf "  %-26s FALTA\n" $$h; ok=0; fi; done; \
	  iverilog -V 2>&1 | head -1 | sed 's/^/  /'; \
	  lg=$$(riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -print-libgcc-file-name 2>/dev/null); \
	  if [ -f "$$lg" ]; then echo "  libgcc rv32i/ilp32         OK"; \
	  else echo "  libgcc rv32i/ilp32         FALTA (el gcc no trae multilib rv32i)"; ok=0; fi; \
	  if [ -n "$$DISPLAY$$WAYLAND_DISPLAY" ]; then echo "  pantalla grafica (WSLg)    OK"; \
	  else echo "  pantalla grafica           no detectada (GTKWave no va a abrir)"; fi; \
	  if [ -f $(SIMLIB)/cyclonev_atoms.v ]; then echo "  librerias de Quartus       OK ($(SIMLIB))"; \
	  else echo "  librerias de Quartus       no encontradas (solo hacen falta para make gate)"; fi; \
	  [ $$ok = 1 ] || { echo; echo "  Instalar con:  ./instalar_dependencias.sh"; exit 1; }

$(OUT):
	@mkdir -p $(OUT)

$(CORE_V): $(RTL)/erv26_core.bdf | $(OUT)
	@$(PY) $(ROOT)/tools/bdf2v.py $< erv26_core $@ >/dev/null

$(TOP_V): $(ROOT)/risvV_E5.bdf | $(OUT)
	@$(PY) $(ROOT)/tools/bdf2v.py $< risvV_E5 $@ >/dev/null

# ---------------------------------------------------------------- nucleo
tests:
	$(PY) $(SIM)/run_core_tests.py -j $(JOBS)

tests-rapido:
	$(PY) $(SIM)/run_core_tests.py -j $(JOBS) --random 0

pipeline: | $(OUT)
	@$(PY) $(SIM)/run_core_tests.py --only asm-pipeline_demo --cond m10k --vcd
	@cp $(SIM)/build_core/tb_core.vcd $(OUT)/pipeline.vcd
	@echo ""
	@echo "  Programa: sw/tests/pipeline_demo.S  (listado: salida/pipeline_demo.lst)"
	@riscv64-unknown-elf-objdump -d $(SIM)/build_core/asm-pipeline_demo.elf > $(OUT)/pipeline_demo.lst
	@$(PY) $(CLASE)/marcadores.py ondas/pipeline.gtkw.in $(OUT)/pipeline.gtkw $(OUT)/pipeline.vcd \
	    $(SIM)/build_core/asm-pipeline_demo.elf
	@echo ""
	$(call abrir,pipeline.vcd,pipeline.gtkw)

test: | $(OUT)
	@$(PY) $(SIM)/run_core_tests.py --only '$(T)' --cond '$(COND)' --vcd
	@cp $(SIM)/build_core/tb_core.vcd $(OUT)/test.vcd
	@$(PY) $(CLASE)/marcadores.py ondas/pipeline.gtkw.in $(OUT)/test.gtkw $(OUT)/test.vcd
	$(call abrir,test.vcd,test.gtkw)

# ---------------------------------------------------------------- placa
$(OUT)/placa/imem.hex: $(ROOT)/sw/demo/leds.c | $(OUT)
	@$(PY) $(ROOT)/sw/build.py $< -DSIM -o $(OUT)/placa >/dev/null

placa: $(CORE_V) $(TOP_V) $(OUT)/placa/imem.hex
	@$(IVERILOG) -DTOP=risvV_E5 -s tb_board -o $(OUT)/placa/tb_board.vvp \
	    $(SIM)/tb_board.v $(TOP_V) $(CORE_V) $(BLOQUES) $(PLACA)
	@cd $(OUT)/placa && vvp -n tb_board.vvp +VCD | grep -v WARNING
	@mv $(OUT)/placa/tb_board.vcd $(OUT)/placa.vcd
	@$(PY) $(CLASE)/marcadores.py ondas/placa.gtkw.in $(OUT)/placa.gtkw $(OUT)/placa.vcd
	$(call abrir,placa.vcd,placa.gtkw)

video: | $(OUT)
	@mkdir -p $(OUT)/video
	@$(IVERILOG) -s tb_video -o $(OUT)/video/tb_video.vvp $(SIM)/video/tb_video.v $(RTL)/board/erv26_video.v
	@cd $(OUT)/video && vvp -n tb_video.vvp +VCD | grep -v WARNING
	@mv $(OUT)/video/tb_video.vcd $(OUT)/video.vcd
	@$(PY) $(CLASE)/ppm2png.py $(OUT)/video/frame0.ppm $(OUT)/video/frame1.ppm
	@$(PY) $(CLASE)/marcadores.py ondas/video.gtkw.in $(OUT)/video.gtkw $(OUT)/video.vcd
	$(call abrir,video.vcd,video.gtkw)

i2c: | $(OUT)
	@mkdir -p $(OUT)/i2c
	@$(IVERILOG) -s tb_i2c -o $(OUT)/i2c/tb_i2c.vvp $(SIM)/video/tb_i2c.v $(RTL)/board/erv26_hdmi_init.v
	@cd $(OUT)/i2c && vvp -n tb_i2c.vvp +VCD | grep -v WARNING
	@mv $(OUT)/i2c/tb_i2c.vcd $(OUT)/i2c.vcd
	@$(PY) $(CLASE)/marcadores.py ondas/i2c.gtkw.in $(OUT)/i2c.gtkw $(OUT)/i2c.vcd
	$(call abrir,i2c.vcd,i2c.gtkw)

juego: $(CORE_V) $(TOP_V)
	@mkdir -p $(OUT)/juego
	@cp $(ROOT)/programas/invaders/*.hex $(OUT)/juego/
	@$(IVERILOG) -DTOP=risvV_E5 -s tb_game -o $(OUT)/juego/tb_game.vvp \
	    $(SIM)/video/tb_game.v $(TOP_V) $(CORE_V) $(BLOQUES) $(PLACA)
	@echo "Simulando $(FRAMES) cuadros de video (unos 25 s por cuadro)..."
	@cd $(OUT)/juego && vvp -n tb_game.vvp +FRAMES=$(FRAMES) | grep -v WARNING
	@$(PY) $(CLASE)/ppm2png.py $(OUT)/juego/game_*.ppm
	@echo "Imagenes en salida/juego/ (abrir con: explorer.exe \$$(wslpath -w $(OUT)/juego))"

# ---------------------------------------------------------------- gate-level
gate:
	@[ -f $(NETLIST) ] || { echo "Falta el netlist: $(NETLIST)"; exit 1; }
	@[ -f $(SIMLIB)/cyclonev_atoms.v ] || { echo "Faltan las librerias de Quartus en $(SIMLIB)"; \
	   echo "(pasar la carpeta con: make gate SIMLIB=/mnt/c/.../quartus/eda/sim_lib)"; exit 1; }
	$(PY) $(SIM)/run_core_tests.py --gate $(NETLIST) --simlib $(SIMLIB) --suite riscv-tests -j $(JOBS)

gate-completo:
	$(PY) $(SIM)/run_core_tests.py --gate $(NETLIST) --simlib $(SIMLIB) --random 0 -j $(JOBS)

gate-pipeline: | $(OUT)
	@$(PY) $(SIM)/run_core_tests.py --gate $(NETLIST) --simlib $(SIMLIB) \
	    --only asm-pipeline_demo --cond m10k --vcd
	@cp $(SIM)/build_core/tb_core.vcd $(OUT)/gate.vcd
	@$(PY) $(CLASE)/marcadores.py ondas/gate.gtkw.in $(OUT)/gate.gtkw $(OUT)/gate.vcd
	$(call abrir,gate.vcd,gate.gtkw)

modelsim:
	$(PY) $(CLASE)/modelsim/exportar.py

limpiar:
	rm -rf $(OUT) $(SIM)/build_core
