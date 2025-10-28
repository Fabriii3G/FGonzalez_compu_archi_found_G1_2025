from machine import Pin, SPI
import time

# ============================================================================
# Configuración de pines
# ============================================================================
cs = Pin(17, Pin.OUT)

# Configuración SPI (Pico W: SCK=GP18, MOSI=GP19, MISO=GP16)
spi = SPI(0,
          baudrate=1_000_000,  # 1 MHz
          polarity=0,
          phase=0,
          bits=8,
          firstbit=SPI.MSB,
          sck=Pin(18),
          mosi=Pin(19),
          miso=Pin(16))

cs.value(1)  # CS inactivo (alto)

# ============================================================================
# Constantes del protocolo (TOP2 modificado)
# ============================================================================
HANDSHAKE_SEND   = 0xA5
HANDSHAKE_EXPECT = 0x5A

CMD_SEND_A       = 0x10  # 0x1N  (N nibble A)
CMD_SEND_B       = 0x20  # 0x2N  (N nibble B)
CMD_READ_RESULT  = 0x30  # 0x30  (leer {0,result} en el byte siguiente)

# ============================================================================
# Utilidades SPI
# ============================================================================
def spi_transfer(tx_byte):
    """Envía un byte por SPI y recibe la respuesta del slave (full-duplex)."""
    tx_data = bytes([tx_byte])
    rx_data = bytearray(1)
    cs.value(0)
    time.sleep_us(50)
    spi.write_readinto(tx_data, rx_data)
    time.sleep_us(50)
    cs.value(1)
    time.sleep_us(100)
    return rx_data[0]

# ============================================================================
# Handshake
# ============================================================================
def do_handshake():
    """Handshake 0xA5 -> 0x5A (mismo byte)."""
    print("Iniciando handshake...")
    response = spi_transfer(HANDSHAKE_SEND)
    if response == HANDSHAKE_EXPECT:
        print(f"✓ Handshake exitoso! Enviado: 0x{HANDSHAKE_SEND:02X}, Recibido: 0x{response:02X}")
        return True
    else:
        print(f"✗ Handshake fallido! Enviado: 0x{HANDSHAKE_SEND:02X}, Esperado: 0x{HANDSHAKE_EXPECT:02X}, Recibido: 0x{response:02X}")
        return False

# ============================================================================
# Comandos de alto nivel (A/B/READ) con lectura correcta de ACK/result
# ============================================================================
def send_operand_a(value):
    """
    Envía A (4 bits) como 0x1N.
    IMPORTANTE: el ACK 0xAN llega en la SIGUIENTE transacción.
    """
    value &= 0x0F
    cmd = CMD_SEND_A | value
    print(f"Enviando operando A: 0x{value:X} (0b{value:04b})")
    _prev_rx = spi_transfer(cmd)      # respuesta anterior (irrelevante)
    ack = spi_transfer(0x00)          # ahora sí, llega 0xAN
    print(f"  ACK A: 0x{ack:02X}  (esperado 0xA{value:X})")
    time.sleep(0.1)
    return ack

def send_operand_b(value):
    """
    Envía B (4 bits) como 0x2N.
    IMPORTANTE: el ACK 0xBN llega en la SIGUIENTE transacción.
    """
    value &= 0x0F
    cmd = CMD_SEND_B | value
    print(f"Enviando operando B: 0x{value:X} (0b{value:04b})")
    _prev_rx = spi_transfer(cmd)      # respuesta anterior (irrelevante)
    ack = spi_transfer(0x00)          # ahora sí, llega 0xBN
    print(f"  ACK B: 0x{ack:02X}  (esperado 0xB{value:X})")
    time.sleep(0.1)
    return ack

def read_result():
    """
    Lee el resultado de la ALU (4 bits).
    Protocolo: mandar 0x30 y luego un dummy para recoger {0,result}.
    """
    print("Solicitando resultado de ALU...")
    _prev_rx = spi_transfer(CMD_READ_RESULT)  # prepara el resultado
    time.sleep(0.1)
    result_byte = spi_transfer(0x00)          # obtiene {0,result}
    result_4bits = result_byte & 0x0F
    print(f"Resultado: 0x{result_4bits:X} (0b{result_4bits:04b}) = {result_4bits}")
    return result_4bits

# ============================================================================
# Flujo de operación: A, B, leer resultado
# ============================================================================
def execute_operation(a, b):
    """
    Envía A y B con protocolo, y lee el resultado.
    La operación la definen los switches del FPGA.
    """
    print("\n" + "=" * 70)
    print(f"Ejecutando operación ALU: A={a} (0x{a:X}), B={b} (0x{b:X})")
    print("=" * 70)

    send_operand_a(a)   # 0x1N + ACK en siguiente transacción
    send_operand_b(b)   # 0x2N + ACK en siguiente transacción

    print("\nEsperando que FPGA procese (ajusta switches para operación)...")
    time.sleep(0.5)

    result = read_result()  # 0x30 + dummy
    print("=" * 70)
    return result

# ============================================================================
# Modo simple interactivo (usa COMANDOS, no nibbles crudos)
# ============================================================================
def simple_mode():
    """
    Envía A y B con comandos 0x1N/0x2N y lee resultado con 0x30.
    """
    print("\n" + "=" * 70)
    print("MODO SIMPLE: Envío secuencial de operandos (protocolo 0x1N/0x2N/0x30)")
    print("=" * 70)
    while True:
        try:
            print("\n" + "-" * 70)
            a_input = input("Operando A (0-F, o 'q' para salir): ").strip().upper()
            if a_input == 'Q':
                print("Saliendo...")
                break
            b_input = input("Operando B (0-F): ").strip().upper()

            try:
                a = int(a_input, 16)
                b = int(b_input, 16)
                if not (0 <= a <= 15 and 0 <= b <= 15):
                    print("Error: Valores deben estar entre 0 y F")
                    continue

                send_operand_a(a)
                time.sleep(0.2)
                send_operand_b(b)
                time.sleep(0.4)

                print("\n⚡ Leyendo resultado desde FPGA...")
                result = read_result()
                print(f"✓ Resultado leído: 0x{result:X} (decimal: {result})")

            except ValueError:
                print("Error: Ingresa valores hexadecimales válidos (0-F)")

        except KeyboardInterrupt:
            print("\n\nPrograma detenido")
            break

# ============================================================================
# Programa principal
# ============================================================================
def main():
    print("=" * 70)
    print("Master SPI - Control de ALU en FPGA (TOP2 protocolo TOP1)")
    print("Proyecto: Máquinas de estados y protocolo SPI")
    print("=" * 70)
    print()

    # Handshake inicial
    time.sleep(0.5)
    if not do_handshake():
        print("\n¡ERROR! No se pudo establecer comunicación con el FPGA.")
        return

    print("\n✓ Comunicación SPI establecida")

    # Limpiar el byte sembrado de handshake (0x5A) del TX del slave
    print("\nLimpiando buffer de handshake...")
    spi_transfer(0x00)
    time.sleep(0.1)
    print()

    # =========================================================================
    # CASO DE PRUEBA
    # =========================================================================
    print("=" * 70)
    print("CASO DE PRUEBA")
    print("=" * 70)
    print()

    A_test = 0x5
    B_test = 0x3

    print(f"Operando A = 0x{A_test:X} (decimal: {A_test})")
    print(f"Operando B = 0x{B_test:X} (decimal: {B_test})")
    print()
    print("Ajusta los SWITCHES para seleccionar la operación en la FPGA.")
    print("  (Los LEDs muestran el resultado en binario y el 7-seg en hex)")
    print()

    # Enviar A y B con protocolo, y leer resultado
    send_operand_a(A_test)
    time.sleep(0.3)
    send_operand_b(B_test)
    time.sleep(0.5)

    print("\n" + "-" * 70)
    print("Leyendo resultado...")
    result_4bits = read_result()
    print("-" * 70)

    print()
    print("=" * 70)
    print("✓ Prueba completada")
    print("=" * 70)
    print()

    # Modo interactivo opcional
    try:
        input("\nPresiona ENTER para entrar en modo interactivo, o Ctrl+C para salir...")
        simple_mode()
    except KeyboardInterrupt:
        pass

    print("\nFinalizando. Enviando dummies para estabilizar...")
    spi_transfer(0x00)
    spi_transfer(0x00)
    print("Listo.")

# ============================================================================
# Ejecución
# ============================================================================
if __name__ == "__main__":
    main()
