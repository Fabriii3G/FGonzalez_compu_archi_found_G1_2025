transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE/sensor_capture.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE/synchronizer.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE/shift_register_tx.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE/shift_register_rx.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE/edge_detector.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE/bit_counter.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU/sumadorCompletoN.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU/sumadorCompleto1bit.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU/shl_in.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU/restadorCompletoN.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU/restadorCompleto1bit.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU/mux2.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU/hex7seg_struct.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU/alu.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/PWM {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/PWM/registroN.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/PWM {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/PWM/pwm16_struct.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/PWM {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/PWM/dff1.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/PWM {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/PWM/contadorUpN.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/PWM {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/PWM/cmp_lt_strict.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU/multiplicadorCompletoN.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/SLAVE/spi_alu_top.sv}
vlog -sv -work work +incdir+C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU {C:/repositorios_quartus/FGonzalez_compu_archi_found_G1_2025/ProyectoFAC/ALU/divisorCompletoN.sv}

