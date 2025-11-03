from machine import Pin, SPI
import time

# ============================================================================
# Configuración de pines
# ============================================================================
cs = Pin(17, Pin.OUT)

# SPI (Pico W: SCK=GP18, MOSI=GP19, MISO=GP16) — Modo-0
spi = SPI(0,
          baudrate=1_000_000,
          polarity=0,
          phase=0,
          bits=8,
          firstbit=SPI.MSB,
          sck=Pin(18),
          mosi=Pin(19),
          miso=Pin(16))

cs.value(1)  # CS inactivo

# ============================================================================
# Protocolo
# ============================================================================
HANDSHAKE_SEND   = 0xA5
HANDSHAKE_EXPECT = 0x5A

CMD_SEND_A       = 0x10   # 0x1N
CMD_SEND_B       = 0x20   # 0x2N
CMD_READ_RESULT  = 0x30   # preparar resultado; recoger en dummy posterior

# ============================================================================
# Utilidades
# ============================================================================
def spi_transfer(tx_byte):
    tx = bytes([tx_byte])
    rx = bytearray(1)
    cs.value(0)
    time.sleep_us(50)
    spi.write_readinto(tx, rx)
    time.sleep_us(50)
    cs.value(1)
    time.sleep_us(100)
    return rx[0]

def flush(n=2):
    last = 0
    for _ in range(n):
        last = spi_transfer(0x00)
    return last

# ============================================================================
# Handshake
# ============================================================================
def do_handshake():
    print("Iniciando handshake...")
    resp = spi_transfer(HANDSHAKE_SEND)
    if resp == HANDSHAKE_EXPECT:
        print(f"✓ Handshake exitoso! Enviado: 0x{HANDSHAKE_SEND:02X}, Recibido: 0x{resp:02X}")
        return True
    print(f"✗ Handshake fallido! Enviado: 0x{HANDSHAKE_SEND:02X}, Esperado: 0x{HANDSHAKE_EXPECT:02X}, Recibido: 0x{resp:02X}")
    return False

# ============================================================================
# Comandos altos
# ============================================================================
def send_operand_a(value):
    """Envía A como 0x1N. El ACK final 0xAN llega tras dos dummies."""
    value &= 0x0F
    cmd = CMD_SEND_A | value
    print(f"Enviando operando A: 0x{value:X} (0b{value:04b})")
    _r0 = spi_transfer(cmd)
    _r1 = spi_transfer(0x00)
    ack = spi_transfer(0x00)
    print(f"  ACK A (final): 0x{ack:02X}  (esperado 0xA{value:X})")
    time.sleep(0.1)
    return ack

def send_operand_b_dummy():
    """Envía un operando B fijo (dummy) para mantener protocolo."""
    dummy_value = 0x0  # puedes cambiar a otro valor si lo prefieres
    cmd = CMD_SEND_B | dummy_value
    print(f"Enviando operando B (dummy): 0x{dummy_value:X}")
    _r0 = spi_transfer(cmd)
    _r1 = spi_transfer(0x00)
    ack = spi_transfer(0x00)
    print(f"  ACK B (dummy): 0x{ack:02X}")
    time.sleep(0.1)
    return ack

def read_result():
    print("Solicitando resultado de ALU...")
    _r0 = spi_transfer(CMD_READ_RESULT)
    _r1 = spi_transfer(0x00)
    result_byte = spi_transfer(0x00)
    result_4 = result_byte & 0x0F
    print(f"Resultado: 0x{result_4:X} (0b{result_4:04b}) = {result_4}")
    return result_4

# ============================================================================
# Modo simple
# ============================================================================
def simple_mode():
    print("\n" + "=" * 70)
    print("MODO SIMPLE (solo A se envía manualmente; B es dummy)")
    print("=" * 70)
    while True:
        try:
            print("\n" + "-" * 70)
            a_input = input("Operando A (0-F, o 'q' para salir): ").strip().upper()
            if a_input == 'Q':
                print("Saliendo...")
                break

            try:
                a = int(a_input, 16)
                if not (0 <= a <= 15):
                    print("Error: Valor debe estar entre 0 y F")
                    continue

                send_operand_a(a)
                time.sleep(0.2)
                send_operand_b_dummy()
                time.sleep(0.3)

            except ValueError:
                print("Error: Ingresa un valor hexadecimal válido (0-F)")

        except KeyboardInterrupt:
            print("\n\nPrograma detenido")
            break

# ============================================================================
# Principal
# ============================================================================
def main():
    print("=" * 70)
    print("Master SPI - ALU (solo A real, B dummy)")
    print("=" * 70)
    print()

    time.sleep(0.5)
    if not do_handshake():
        print("\n¡ERROR! No se pudo establecer comunicación con el FPGA.")
        return

    print("\n✓ Comunicación SPI establecida")
    print("\nLimpiando pipeline del slave...")
    flush(3)
    time.sleep(0.1)
    print()

    A_test = 0x5
    print(f"Operando A = 0x{A_test:X}")
    send_operand_a(A_test)
    time.sleep(0.3)
    send_operand_b_dummy()
    time.sleep(0.5)
    print("\n✓ Prueba completada\n")

    try:
        input("\nPresiona ENTER para modo interactivo, o Ctrl+C para salir...")
        simple_mode()
    except KeyboardInterrupt:
        pass

    print("\nFinalizando. Flushing...")
    flush(2)
    print("Listo.")

if __name__ == "__main__":
    main()

