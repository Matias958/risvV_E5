# Configuracion del ADV7513 por I2C. En el Transcript quedan los bytes
# decodificados (START 72 98 03 STOP ...). Sin un esclavo conectado todos
# los ACK salen como nack: es lo esperado, el controlador los ignora.
#   do i2c.do
do compilar.do
vsim -quiet -t 1ps -onfinish stop -voptargs=+acc work.tb_i2c
gui {
    onerror {resume}
    add wave -noupdate /tb_i2c/scl
    add wave -noupdate /tb_i2c/sda
    add wave -noupdate /tb_i2c/in_frame
    add wave -noupdate -radix hexadecimal /tb_i2c/byte_rx
    add wave -noupdate /tb_i2c/busy
    configure wave -namecolwidth 120 -valuecolwidth 60 -timelineunits us -signalnamewidth 1
}
run -all
gui { view wave; wave zoom range 0us 45us }
