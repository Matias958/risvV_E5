# Placa completa (top risvV_E5.bdf) con la demo de LEDs: contador, auto fantastico y halt.
#   do placa.do
do compilar.do
# erv26_imem / erv26_dmem leen imem.hex y dmem_b*.hex de la carpeta actual
foreach f {imem.hex dmem_b0.hex dmem_b1.hex dmem_b2.hex dmem_b3.hex} {
    file copy -force programas/leds_sim/$f $f
}
vsim -quiet -t 1ps -onfinish stop -voptargs=+acc work.tb_board
gui {
    onerror {resume}
    add wave -noupdate -divider {Entradas de la placa}
    add wave -noupdate -radix binary /tb_board/key
    add wave -noupdate -radix binary /tb_board/sw
    add wave -noupdate -divider {LEDs}
    add wave -noupdate -radix hexadecimal -label LED_hex /tb_board/led
    add wave -noupdate -radix binary -label LED_bin /tb_board/led
    add wave -noupdate -divider {Procesador}
    add wave -noupdate /tb_board/dut/rst_n
    add wave -noupdate /tb_board/dut/en
    add wave -noupdate -radix hexadecimal -label PC /tb_board/dut/imem_addr
    add wave -noupdate -divider {Bus de datos (LEDs = 0x80000000)}
    add wave -noupdate /tb_board/dut/io_req
    add wave -noupdate /tb_board/dut/dmem_we
    add wave -noupdate -radix hexadecimal /tb_board/dut/dmem_addr
    add wave -noupdate -radix hexadecimal /tb_board/dut/dmem_wdata
    configure wave -namecolwidth 170 -valuecolwidth 110 -timelineunits us -signalnamewidth 1
}
run -all
gui { view wave; wave zoom full }
