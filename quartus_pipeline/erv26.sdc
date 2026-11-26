create_clock -name clk50 -period 20.000 [get_ports FPGA_CLK1_50]
derive_clock_uncertainty
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LED[*]}]

# Botones en GPIO: asincronicos, se sincronizan con 2 flip-flops en erv26_io.
set_false_path -from [get_ports {GPIO_0[*]}]

# I2C del ADV7513: ~100 kHz generado por contador, sin relacion de fase util con clk50.
set_false_path -to   [get_ports {HDMI_I2C_SCL HDMI_I2C_SDA}]

# Salida de video: datos, DE, HS, VS y HDMI_TX_CLK salen de registros en la celda de I/O
# (FAST_OUTPUT_REGISTER, 28 registros empacados), todos con clk50. Los datos cambian cada
# 2 ciclos (40 ns) y el flanco de subida de HDMI_TX_CLK cae 20 ns despues del cambio, con
# un skew entre pines de pocos cientos de ps: el margen frente al setup/hold del ADV7513
# (~1-2 ns) es de mas de 15 ns, asi que no se analiza como camino de timing.
set_false_path -to   [get_ports {HDMI_TX_D[*] HDMI_TX_DE HDMI_TX_HS HDMI_TX_VS HDMI_TX_CLK}]
