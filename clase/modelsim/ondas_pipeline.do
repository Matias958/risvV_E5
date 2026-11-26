# Vista de ondas del pipeline (la usan pipeline.do y test.do)
onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_core/clk
add wave -noupdate /tb_core/rst_n
add wave -noupdate -divider {Instruccion en cada etapa}
add wave -noupdate -radix hexadecimal -label IF_pc /tb_core/IF_pc
add wave -noupdate -radix ascii -label ID  /tb_core/ID_txt
add wave -noupdate -radix ascii -label EX  /tb_core/EX_txt
add wave -noupdate -radix ascii -label MEM /tb_core/MEM_txt
add wave -noupdate -radix ascii -label WB  /tb_core/WB_txt
add wave -noupdate -divider {Hazards y saltos}
add wave -noupdate /tb_core/stall_load_use
add wave -noupdate /tb_core/espera_memoria
add wave -noupdate /tb_core/salto_en_ID
add wave -noupdate /tb_core/corrige_en_EX
add wave -noupdate /tb_core/flush_ID
add wave -noupdate -divider {Forwarding hacia EX}
add wave -noupdate /tb_core/fwd_rs1_desde_MEM
add wave -noupdate /tb_core/fwd_rs1_desde_WB
add wave -noupdate /tb_core/fwd_rs2_desde_MEM
add wave -noupdate /tb_core/fwd_rs2_desde_WB
add wave -noupdate -divider {Memoria de datos}
add wave -noupdate /tb_core/dmem_req
add wave -noupdate /tb_core/dmem_we
add wave -noupdate /tb_core/dmem_ready
add wave -noupdate -radix hexadecimal /tb_core/dmem_addr
add wave -noupdate -radix hexadecimal /tb_core/dmem_addr_next
add wave -noupdate -radix hexadecimal /tb_core/dmem_wdata
add wave -noupdate -radix hexadecimal /tb_core/dmem_rdata
add wave -noupdate -divider {Registros}
foreach r {t0 t1 t2 a0 a1 a2 a3 a4 a5 a6 s0 s1 s2 t4} {
    add wave -noupdate -radix decimal /tb_core/$r
}
configure wave -namecolwidth 170 -valuecolwidth 150 -justifyvalue left -signalnamewidth 1
configure wave -timelineunits ns
update
