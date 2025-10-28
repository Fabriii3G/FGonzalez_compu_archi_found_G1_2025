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
    """Envía un byte por SPI y recibe el del slave (full-duplex)."""
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
    """Arrastra n bytes del pipeline del slave (dummies 0x00)."""
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
# Comandos altos (con “doble dummy” para alinear pipeline)
# ============================================================================
def send_operand_a(value):
    """Envía A como 0x1N. El ACK final 0xAN llega tras dos dummies."""
    value &= 0x0F
    cmd = CMD_SEND_A | value
    print(f"Enviando operando A: 0x{value:X} (0b{value:04b})")
    _r0 = spi_transfer(cmd)
    _r1 = spi_transfer(0x00)
    ack = spi_transfer(0x00)   # <-- aquí debe llegar 0xAN (con swap ya tratado en el TOP)
    print(f"  ACK A (final): 0x{ack:02X}  (esperado 0xA{value:X})")
    time.sleep(0.1)
    return ack

def send_operand_b(value):
    """Envía B como 0x2N. El ACK final 0xBN llega tras dos dummies."""
    value &= 0x0F
    cmd = CMD_SEND_B | value
    print(f"Enviando operando B: 0x{value:X} (0b{value:04b})")
    _r0 = spi_transfer(cmd)
    _r1 = spi_transfer(0x00)
    ack = spi_transfer(0x00)   # <-- aquí debe llegar 0xBN
    print(f"  ACK B (final): 0x{ack:02X}  (esperado 0xB{value:X})")
    time.sleep(0.1)
    return ack

def read_result():
    """
    Lee el resultado de la ALU (4 bits).
    Protocolo: mandar 0x30 y luego DOS dummies para recoger {0,result}.
    """
    print("Solicitando resultado de ALU...")
    _r0 = spi_transfer(CMD_READ_RESULT)  # prepara
    _r1 = spi_transfer(0x00)             # arrastra posible previo
    result_byte = spi_transfer(0x00)     # <-- aquí llega {0,result} (TOP ya manda nibble bajo)
    result_4 = result_byte & 0x0F
    print(f"Resultado: 0x{result_4:X} (0b{result_4:04b}) = {result_4}")
    return result_4

# ============================================================================
# Modo simple e integración
# ============================================================================
def simple_mode():
    print("\n" + "=" * 70)
    print("MODO SIMPLE: 0x1N (A), 0x2N (B), 0x30 (READ) + doble dummy")
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

                #print("\n⚡ Leyendo resultado desde FPGA...")
                #result = read_result()
                #print(f"✓ Resultado leído: 0x{result:X} (decimal: {result})")

            except ValueError:
                print("Error: Ingresa valores hexadecimales válidos (0-F)")

        except KeyboardInterrupt:
            print("\n\nPrograma detenido")
            break

def main():
    print("=" * 70)
    print("Master SPI - Control de ALU en FPGA (TOP2 protocolo TOP1)")
    print("Proyecto: Máquinas de estados y protocolo SPI")
    print("=" * 70)
    print()

    time.sleep(0.5)
    if not do_handshake():
        print("\n¡ERROR! No se pudo establecer comunicación con el FPGA.")
        return

    print("\n✓ Comunicación SPI establecida")

    # Limpiar bien el byte sembrado del handshake y cualquier rezago
    print("\nLimpiando pipeline del slave...")
    flush(3)
    time.sleep(0.1)
    print()

    # Demo corta
    print("=" * 70)
    print("CASO DE PRUEBA")
    print("=" * 70)
    print()

    A_test = 0x5
    B_test = 0x3

    print(f"Operando A = 0x{A_test:X} (decimal: {A_test})")
    print(f"Operando B = 0x{B_test:X} (decimal: {B_test})")
    print("\nAjusta los SWITCHES en la FPGA para elegir la operación.\n")

    send_operand_a(A_test)
    time.sleep(0.3)
    send_operand_b(B_test)
    time.sleep(0.5)

    #print("\n" + "-" * 70)
    #print("Leyendo resultado...")
    #_ = read_result()
    #print("-" * 70)

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
