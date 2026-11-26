# Generador de video HDMI 640x480@60: sincronismos, DE, pixeles y doble buffer.
# Simula 3 cuadros (unos 50 ms de simulacion; tarda alrededor de un minuto).
# Ademas guarda frame0.ppm y frame1.ppm (se abren con GIMP o IrfanView).
#   do video.do
do compilar.do
vsim -quiet -t 1ps -onfinish stop -voptargs=+acc work.tb_video
gui {
    onerror {resume}
    add wave -noupdate -divider {Contadores (1 pixel = 2 ciclos)}
    add wave -noupdate /tb_video/dut/ph
    add wave -noupdate -radix unsigned /tb_video/dut/hc
    add wave -noupdate -radix unsigned /tb_video/dut/vc
    add wave -noupdate -divider {Salida al ADV7513}
    add wave -noupdate /tb_video/hclk
    add wave -noupdate /tb_video/de
    add wave -noupdate /tb_video/hs
    add wave -noupdate /tb_video/vs
    add wave -noupdate -radix hexadecimal /tb_video/d
    add wave -noupdate -divider {Doble buffer}
    add wave -noupdate /tb_video/disp_page
    add wave -noupdate /tb_video/dut/page_l
    add wave -noupdate /tb_video/frame_tick
    add wave -noupdate /tb_video/vblank
    configure wave -namecolwidth 170 -valuecolwidth 90 -timelineunits us -signalnamewidth 1
}
run -all
# una linea completa (800 pixeles = 32 us) al principio del primer cuadro capturado
gui { view wave; wave zoom range 16795us 16835us }
