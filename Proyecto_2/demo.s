# Guardar 10 y 20 en memoria
addi x1, x0, 10        # x1 = 10
addi x2, x0, 20        # x2 = 20

sw   x1, 0(x0)         # mem[0] = 10
sw   x2, 4(x0)         # mem[4] = 20

# Cargar desde memoria y sumar
lw   x3, 0(x0)         # x3 = mem[0] = 10
lw   x4, 4(x0)         # x4 = mem[4] = 20
add  x3, x3, x4        # x3 = 30

loop:
    addi x3, x3, -1    # x3--
    sw   x3, 8(x0)     # mem[8] = x3 (se actualiza cada iteración)
    bne  x3, x0, loop  # mientras x3 != 0, seguir
