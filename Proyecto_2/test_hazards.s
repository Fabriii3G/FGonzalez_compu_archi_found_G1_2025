# Programa de prueba para comparar políticas de riesgos
# Este programa tiene:
# - Dependencias de datos (load-use hazards)
# - Branches condicionales (control hazards)
# - Operaciones aritméticas

# Inicializar valores
addi x1, x0, 10        # x1 = 10 (contador)
addi x2, x0, 1         # x2 = 1 (incremento)
addi x3, x0, 0         # x3 = 0 (acumulador)

# Loop con dependencias de datos
loop:
    # Load-use hazard: lw seguido de uso inmediato
    sw   x3, 100(x0)   # Guardar acumulador en memoria[100]
    lw   x4, 100(x0)   # Cargar de memoria[100] (crea load-use hazard)
    add  x3, x4, x2    # Usar x4 inmediatamente (requiere stall sin forwarding)
    
    # Más operaciones con dependencias
    add  x5, x3, x2    # x5 depende de x3 (forwarding puede ayudar)
    sub  x6, x5, x2    # x6 depende de x5 (otra dependencia)
    
    # Decrementar contador
    sub  x1, x1, x2    # x1 = x1 - 1
    
    # Branch condicional (control hazard)
    bne  x1, x0, loop  # Si x1 != 0, volver a loop
    
# Resultado final
sw   x3, 200(x0)       # Guardar resultado en memoria[200]
sw   x6, 204(x0)       # Guardar x6 en memoria[204]

# Fin del programa
