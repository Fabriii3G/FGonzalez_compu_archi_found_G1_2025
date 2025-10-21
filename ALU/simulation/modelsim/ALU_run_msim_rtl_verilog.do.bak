transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -sv -work work +incdir+C:/Users/snipe/Desktop/ALU {C:/Users/snipe/Desktop/ALU/sumadorCompletoN.sv}
vlog -sv -work work +incdir+C:/Users/snipe/Desktop/ALU {C:/Users/snipe/Desktop/ALU/sumadorCompleto1bit.sv}
vlog -sv -work work +incdir+C:/Users/snipe/Desktop/ALU {C:/Users/snipe/Desktop/ALU/restadorCompletoN.sv}
vlog -sv -work work +incdir+C:/Users/snipe/Desktop/ALU {C:/Users/snipe/Desktop/ALU/restadorCompleto1bit.sv}
vlog -sv -work work +incdir+C:/Users/snipe/Desktop/ALU {C:/Users/snipe/Desktop/ALU/mux2.sv}
vlog -sv -work work +incdir+C:/Users/snipe/Desktop/ALU {C:/Users/snipe/Desktop/ALU/multiplicadorCompletoN.sv}
vlog -sv -work work +incdir+C:/Users/snipe/Desktop/ALU {C:/Users/snipe/Desktop/ALU/alu.sv}
vlog -sv -work work +incdir+C:/Users/snipe/Desktop/ALU {C:/Users/snipe/Desktop/ALU/divisorCompletoN.sv}

vlog -sv -work work +incdir+C:/Users/snipe/Desktop/ALU {C:/Users/snipe/Desktop/ALU/alu_tb.sv}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  alu_tb

add wave *
view structure
view signals
run -all
