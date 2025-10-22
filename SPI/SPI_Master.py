from machine import Pin, SPI
import time

# ============================================================================
# Configuración de pines
# ============================================================================
cs = Pin(17, Pin.OUT)

# Configuración SPI
# Con 50 MHz en FPGA: 500 kHz = 100 ciclos por bit SPI
# Suficiente para sincronización (2 ciclos) + procesamiento FSM
spi = SPI(0,
          baudrate=250000,  # 250 kHz = 200 ciclos FPGA por bit SPI
          polarity=0,
          phase=0,
          bits=8,
          firstbit=SPI.MSB,
          sck=Pin(18),
          mosi=Pin(19),
          miso=Pin(16))

cs.value(1)  # CS inactivo

# ============================================================================
# Constantes
# ============================================================================
HANDSHAKE_SEND = 0xA5
HANDSHAKE_EXPECT = 0x5A

# ============================================================================
# Funciones auxiliares
# ============================================================================

def spi_transfer(tx_byte):
    """
    Envía un byte por SPI y recibe respuesta.
    IMPORTANTE: Delays aumentados para dar tiempo a la FSM.
    """
    tx_data = bytes([tx_byte])
    rx_data = bytearray(1)
    
    cs.value(0)
    time.sleep_ms(1)  # Delay aumentado a 1ms antes de la transferencia
    spi.write_readinto(tx_data, rx_data)
    time.sleep_ms(2)  # Delay aumentado a 2ms después de la transferencia
    cs.value(1)
    
    time.sleep_ms(5)  # Delay adicional entre transacciones
    
    return rx_data[0]


def do_handshake():
    """Realiza handshake con el FPGA."""
    print("Iniciando handshake...")
    response = spi_transfer(HANDSHAKE_SEND)
    
    # Nota: La PRIMERA respuesta será basura (0x00 típicamente)
    # porque el TX aún no está preparado. La SEGUNDA respuesta será correcta.
    print(f"Primera respuesta: 0x{response:02X}")
    
    # Enviar handshake de nuevo para obtener la respuesta correcta
    time.sleep_ms(10)
    response = spi_transfer(HANDSHAKE_SEND)
    
    if response == HANDSHAKE_EXPECT:
        print(f"✓ Handshake exitoso! Recibido: 0x{response:02X}")
        return True
    else:
        print(f"✗ Handshake fallido! Esperado: 0x{HANDSHAKE_EXPECT:02X}, Recibido: 0x{response:02X}")
        return False


def send_led_pattern(pattern_4bits):
    """
    Envía patrón de LEDs y verifica respuesta.
    """
    pattern_4bits &= 0x0F
    
    # Primera transacción: enviar el patrón
    response = spi_transfer(pattern_4bits)
    print(f"Envío inicial - TX: 0b{pattern_4bits:04b}, RX: 0x{response:02X}")
    
    # Segunda transacción: leer el echo del FPGA
    time.sleep_ms(10)
    response = spi_transfer(0x00)  # Enviar dummy byte
    received_4bits = response & 0x0F
    
    match = (pattern_4bits == received_4bits)
    
    print(f"Echo - Enviado: 0b{pattern_4bits:04b} | "
          f"Recibido: 0b{received_4bits:04b} | "
          f"{'✓ MATCH' if match else '✗ ERROR'}")
    
    return match


# ============================================================================
# Programa principal
# ============================================================================

def main():
    print("=" * 60)
    print("Master SPI - Raspberry Pi Pico W")
    print("Control de 4 LEDs en FPGA")
    print("=" * 60)
    print()
    
    # Esperar a que el FPGA esté listo
    print("Esperando inicialización del FPGA...")
    time.sleep(1)
    
    # Realizar handshake
    if not do_handshake():
        print("\n¡ERROR! No se pudo establecer comunicación.")
        print("\nVerifica:")
        print("  - GP18 (SCK)  → FPGA Pin XX")
        print("  - GP19 (MOSI) → FPGA Pin XX")
        print("  - GP16 (MISO) ← FPGA Pin XX")
        print("  - GP17 (CS)   → FPGA Pin XX")
        print("  - GND común")
        print("\nTambién verifica que:")
        print("  - El bitstream esté cargado en la FPGA")
        print("  - El reloj de la FPGA esté funcionando")
        print("  - El reset de la FPGA esté desactivado")
        return
    
    print()
    print("=" * 60)
    print("Iniciando prueba de LEDs...")
    print("=" * 60)
    print()
    
    # Patrones de prueba
    test_patterns = [
        0b0001,  # LED 0
        0b0010,  # LED 1
        0b0100,  # LED 2
        0b1000,  # LED 3
        0b0011,  # LED 0,1
        0b1100,  # LED 2,3
        0b0101,  # LED 0,2
        0b1010,  # LED 1,3
        0b1111,  # Todos
        0b0000,  # Ninguno
    ]
    
    success_count = 0
    total_count = 0
    
    for i, pattern in enumerate(test_patterns):
        print(f"\n--- Test {i+1}/{len(test_patterns)} ---")
        if send_led_pattern(pattern):
            success_count += 1
        total_count += 1
        time.sleep(1)
    
    print()
    print("=" * 60)
    print(f"Resultado: {success_count}/{total_count} exitosas")
    print("=" * 60)
    print()
    
    # Modo continuo
    print("Iniciando secuencia automática...")
    print("Presiona Ctrl+C para detener\n")
    
    try:
        counter = 0
        while True:
            pattern = counter & 0x0F
            print(f"\nContador: {counter}")
            send_led_pattern(pattern)
            counter = (counter + 1) % 16
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\n\nDetenido por usuario")
        send_led_pattern(0b0000)
        time.sleep_ms(100)
        send_led_pattern(0b0000)  # Enviar dos veces para asegurar
        print("LEDs apagados")


def manual_mode():
    """Modo manual para control directo."""
    print("=" * 60)
    print("Modo Manual")
    print("=" * 60)
    print()
    
    if not do_handshake():
        print("Error en handshake.")
        return
    
    print("\nIngresa 0-15 para controlar LEDs")
    print("'q' para salir\n")
    
    while True:
        try:
            user_input = input("Patrón: ").strip()
            
            if user_input.lower() == 'q':
                send_led_pattern(0)
                time.sleep_ms(100)
                send_led_pattern(0)
                break
            
            pattern = int(user_input)
            
            if 0 <= pattern <= 15:
                send_led_pattern(pattern)
            else:
                print("Rango: 0-15")
                
        except ValueError:
            print("Número inválido")
        except KeyboardInterrupt:
            print("\nDetenido")
            send_led_pattern(0)
            break


# ============================================================================
# Prueba de diagnóstico básica
# ============================================================================

def diagnostic_test():
    """Prueba básica de comunicación SPI."""
    print("=" * 60)
    print("PRUEBA DE DIAGNÓSTICO")
    print("=" * 60)
    print()
    
    print("Test 1: Verificando pines...")
    print(f"  CS  (GP17): {'OK' if cs else 'ERROR'}")
    print(f"  SPI configurado: {spi}")
    print()
    
    print("Test 2: Enviando handshake (3 intentos)...")
    for i in range(3):
        response = spi_transfer(HANDSHAKE_SEND)
        print(f"  Intento {i+1}: TX=0x{HANDSHAKE_SEND:02X}, RX=0x{response:02X}")
        time.sleep_ms(100)
    print()
    
    print("Test 3: Enviando patrones simples...")
    for pattern in [0x00, 0x0F, 0x05, 0x0A]:
        response = spi_transfer(pattern)
        print(f"  TX=0x{pattern:02X}, RX=0x{response:02X}")
        time.sleep_ms(100)
    print()
    
    print("Diagnóstico completado.")
    print("Si todas las respuestas son 0x00, verifica:")
    print("  1. Conexiones físicas")
    print("  2. Bitstream cargado en FPGA")
    print("  3. Reloj de FPGA funcionando")


# ============================================================================
# Ejecución
# ============================================================================

if __name__ == "__main__":
    # Descomentar la que necesites:
    
    main()              # Modo automático
    # manual_mode()     # Modo manual
    # diagnostic_test() # Diagnóstico básico