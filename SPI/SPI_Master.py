from machine import Pin, SPI
import time

# ============================================================================
# Configuración de pines
# ============================================================================
cs = Pin(17, Pin.OUT)

# Configuración SPI
# SCK = GP18, MOSI = GP19, MISO = GP16
spi = SPI(0,
          baudrate=1000000,  # 1 MHz
          polarity=0,
          phase=0,
          bits=8,
          firstbit=SPI.MSB,
          sck=Pin(18),
          mosi=Pin(19),
          miso=Pin(16))

cs.value(1)  # CS inactivo (alto)

# ============================================================================
# Constantes del protocolo
# ============================================================================
HANDSHAKE_SEND = 0xA5      # Código de handshake que envía el master
HANDSHAKE_EXPECT = 0x5A    # Respuesta esperada del slave

# ============================================================================
# Funciones auxiliares
# ============================================================================

def spi_transfer(tx_byte):
    """
    Envía un byte por SPI y recibe la respuesta del slave.
    
    Args:
        tx_byte: Byte a enviar (0-255)
    
    Returns:
        Byte recibido del slave
    """
    tx_data = bytes([tx_byte])
    rx_data = bytearray(1)
    
    cs.value(0)                    # Activar slave
    time.sleep_us(10)              # Pequeña pausa
    spi.write_readinto(tx_data, rx_data)
    time.sleep_us(10)              # Pequeña pausa
    cs.value(1)                    # Desactivar slave
    
    return rx_data[0]


def do_handshake():
    """
    Realiza el handshake con el FPGA slave.
    
    Returns:
        True si el handshake fue exitoso, False si falló
    """
    print("Iniciando handshake...")
    response = spi_transfer(HANDSHAKE_SEND)
    
    if response == HANDSHAKE_EXPECT:
        print(f"✓ Handshake exitoso! Enviado: 0x{HANDSHAKE_SEND:02X}, Recibido: 0x{response:02X}")
        return True
    else:
        print(f"✗ Handshake fallido! Enviado: 0x{HANDSHAKE_SEND:02X}, Esperado: 0x{HANDSHAKE_EXPECT:02X}, Recibido: 0x{response:02X}")
        return False


def send_led_pattern(pattern_4bits):
    """
    Envía un patrón de 4 bits al FPGA y verifica la respuesta.
    
    Args:
        pattern_4bits: Valor de 4 bits (0-15) para controlar los LEDs
    
    Returns:
        True si la respuesta coincide, False si no coincide
    """
    # Asegurar que solo usamos 4 bits
    pattern_4bits &= 0x0F
    
    # Enviar patrón (4 bits en la parte baja del byte)
    response = spi_transfer(pattern_4bits)
    
    # Verificar respuesta (debe devolver los mismos 4 bits)
    received_4bits = response & 0x0F
    
    match = (pattern_4bits == received_4bits)
    
    print(f"Enviado: 0b{pattern_4bits:04b} (0x{pattern_4bits:01X}) | "
          f"Recibido: 0b{received_4bits:04b} (0x{received_4bits:01X}) | "
          f"{'✓ MATCH' if match else '✗ ERROR'}")
    
    return match


# ============================================================================
# Programa principal
# ============================================================================

def main():
    print("=" * 60)
    print("Master SPI - Raspberry Pi Pico W")
    print("Control de 4 LEDs en FPGA con verificación")
    print("=" * 60)
    print()
    
    # Paso 1: Realizar handshake
    time.sleep(0.5)  # Esperar a que el FPGA esté listo
    
    if not do_handshake():
        print("\n¡ERROR! No se pudo establecer comunicación con el FPGA.")
        print("Verifica las conexiones:")
        print("  - GP18 (SCK)  → FPGA SCK")
        print("  - GP19 (MOSI) → FPGA MOSI")
        print("  - GP16 (MISO) ← FPGA MISO")
        print("  - GP17 (CS)   → FPGA CS")
        print("  - GND         ⟷ FPGA GND")
        return
    
    print()
    print("=" * 60)
    print("Iniciando prueba de LEDs...")
    print("=" * 60)
    print()
    
    # Paso 2: Enviar diferentes patrones
    test_patterns = [
        0b0000,  # Todos apagados
        0b0001,  # Solo LED 0
        0b0010,  # Solo LED 1
        0b0100,  # Solo LED 2
        0b1000,  # Solo LED 3
        0b0011,  # LED 0 y 1
        0b1100,  # LED 2 y 3
        0b0101,  # LED 0 y 2
        0b1010,  # LED 1 y 3
        0b1111,  # Todos encendidos
    ]
    
    time.sleep(1)
    success_count = 0
    total_count = 0
    
    for pattern in test_patterns:
        if send_led_pattern(pattern):
            success_count += 1
        total_count += 1
        time.sleep(1)  # Pausa para observar los LEDs
    
    print()
    print("=" * 60)
    print(f"Prueba completada: {success_count}/{total_count} transmisiones exitosas")
    print("=" * 60)
    print()
    
    # Paso 3: Modo interactivo continuo
    print("Entrando en modo continuo (secuencia automática)...")
    print("Presiona Ctrl+C para detener")
    print()
    
    try:
        counter = 0
        while True:
            pattern = counter & 0x0F  # Usar 4 bits del contador
            send_led_pattern(pattern)
            counter += 1
            time.sleep(0.5)
            
            # Reiniciar contador después de completar ciclo
            if counter > 15:
                counter = 0
                print("--- Ciclo completado, reiniciando ---")
                print()
                
    except KeyboardInterrupt:
        print("\n\nPrograma detenido por el usuario")
        # Apagar todos los LEDs
        send_led_pattern(0b0000)
        print("LEDs apagados")


# ============================================================================
# Modo alternativo: Control manual
# ============================================================================

def manual_mode():
    """
    Modo interactivo donde el usuario puede controlar los LEDs manualmente.
    """
    print("=" * 60)
    print("Modo Manual - Control de LEDs")
    print("=" * 60)
    print()
    
    if not do_handshake():
        print("Error en handshake. Abortando.")
        return
    
    print("\nIngresa un número de 0 a 15 para controlar los LEDs")
    print("Ejemplo: 15 = 0b1111 = todos encendidos")
    print("         5  = 0b0101 = LED 0 y 2 encendidos")
    print("Escribe 'q' para salir\n")
    
    while True:
        try:
            user_input = input("Patrón (0-15): ").strip()
            
            if user_input.lower() == 'q':
                print("Saliendo...")
                send_led_pattern(0b0000)  # Apagar LEDs
                break
            
            pattern = int(user_input)
            
            if 0 <= pattern <= 15:
                send_led_pattern(pattern)
            else:
                print("Error: Ingresa un número entre 0 y 15")
                
        except ValueError:
            print("Error: Ingresa un número válido o 'q' para salir")
        except KeyboardInterrupt:
            print("\n\nPrograma detenido")
            send_led_pattern(0b0000)
            break


# ============================================================================
# Ejecución
# ============================================================================

if __name__ == "__main__":
    # Descomentar la función que desees usar:
    
    main()           # Modo automático con secuencia
    # manual_mode()  # Modo manual interactivo