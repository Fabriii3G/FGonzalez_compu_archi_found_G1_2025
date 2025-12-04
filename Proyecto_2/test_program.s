#.text
#        .globl _start

_start:
        # ------------------------------
        # 1) RAW hazard simple (resuelto por forwarding)
        # ------------------------------
        addi x5, x0, 10           # x5 = 10
        add x6, x5, x5      # Usa x5 inmediatamente (debería usar forwarding)

        # ------------------------------
        # 2) RAW hazard más profundo
        # ------------------------------
        add x7, x6, x5      # Usa x6 recién escrito (forwarding EX/MEM o MEM/WB)
        add x8, x7, x6      # Encadena más dependencias

        # ------------------------------
        # 3) Load-use hazard: DEBE generar un stall
        # ------------------------------
        # la x9, data         # Cargar dirección (se resuelve en ensamblador)
        lw x10, 0(x9)       # Load: x10 <= MEM[data]
        add x11, x10, x5    # Dependencia inmediata: provoca stall en pipeline

        # ------------------------------
        # 4) Branch hazard
        # ------------------------------
        addi x12, x0, 1
        beq x12, x11, target  # Normalmente no se cumple → causa flush
        addi x13, x0, 99       # Esta instrucción OJO: debe ser flusheada

target:
        addi x14, x0, 42       # Instrucción final

loop:
        beq x0, x0, loop       # loop infinito para observar el pipeline



#        .data
#data:
#        .word 7