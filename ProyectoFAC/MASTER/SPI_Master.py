from machine import Pin, SPI
import time

# ============================================================================
# Configuración de pines
# ============================================================================
cs = Pin(17, Pin.OUT)
sensor = Pin(15, Pin.OUT)

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
sensor.value(1)

# ============================================================================
# Protocolo
# ============================================================================
HANDSHAKE_SEND   = 0xA5
HANDSHAKE_EXPECT = 0x5A

CMD_SEND_A       = 0x10   # 0x1N → envía operando A
CMD_READ_RESULT  = 0x30   # leer resultado de ALU

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
# Comandos
# ============================================================================
def send_operand_a(value):
    """
    Envía A como 0x1N. 
    El operando B ahora viene del SENSOR (4 bits capturados con botón).
    ACK final 0xAN llega tras dos dummies.
    """
    value &= 0x0F
    cmd = CMD_SEND_A | value
    print(f"\nEnviando operando A: 0x{value:X} (0b{value:04b}, decimal {value})")
    print("  (El operando B viene del sensor en la FPGA)")
    
    _r0 = spi_transfer(cmd)
    _r1 = spi_transfer(0x00)
    ack = spi_transfer(0x00)
    print(f"  ACK A recibido: 0x{ack:02X} (esperado 0xA{value:X})")
    time.sleep(0.1)
    return ack

def read_result():
    """
    Lee el resultado de la ALU (4 bits).
    Protocolo: mandar 0x30 y luego DOS dummies para recoger el resultado.
    """
    print("\nSolicitando resultado de ALU...")
    _r0 = spi_transfer(CMD_READ_RESULT)
    _r1 = spi_transfer(0x00)
    result_byte = spi_transfer(0x00)
    result_4 = result_byte & 0x0F
    print(f"Resultado ALU: 0x{result_4:X} (0b{result_4:04b}, decimal {result_4})")
    return result_4

# ============================================================================
# Modo interactivo
# ============================================================================
def interactive_mode():
    print("\n" + "=" * 70)
    print("MODO INTERACTIVO")
    print("=" * 70)
    print("\nInstrucciones:")
    print("  1. Captura los 4 bits del operando B usando el sensor y el botón")
    print("  2. Ajusta los SWITCHES para elegir la operación deseada")
    print("  3. Envía el operando A desde aquí")
    print("  4. El resultado se calcula automáticamente: A op B")
    print("=" * 70)
    
    while True:
        try:
            print("\n" + "-" * 70)
            a_input = input("Operando A (0-F hex, o 'q' para salir): ").strip().upper()
            
            if a_input == 'Q':
                print("Saliendo...")
                break
            
            try:
                a = int(a_input, 16)
                if not (0 <= a <= 15):
                    print("Error: Valor debe estar entre 0 y F")
                    continue
                
                # Enviar operando A (triggers cálculo con B del sensor)
                send_operand_a(a)
                time.sleep(0.3)
                
                # Opcionalmente leer resultado
                read_opt = input("¿Leer resultado? (s/n): ").strip().lower()
                if read_opt == 's':
                    read_result()
                
            except ValueError:
                print("Error: Ingresa un valor hexadecimal válido (0-F)")
        
        except KeyboardInterrupt:
            print("\n\nPrograma detenido")
            break

# ============================================================================
# Main
# ============================================================================
def main():
    
    print("=" * 70)
    print("Master SPI - Control de ALU con SENSOR")
    print("Operando A: desde Raspberry Pi")
    print("Operando B: desde sensor en FPGA (4 bits capturados con botón)")
    print("=" * 70)
    print()
    
    time.sleep(0.5)
    if not do_handshake():
        print("\n¡ERROR! No se pudo establecer comunicación con el FPGA.")
        return
    
    print("\n✓ Comunicación SPI establecida")
    
    # Limpiar pipeline
    print("\nLimpiando pipeline del slave...")
    flush(3)
    time.sleep(0.1)
    
    # Prueba inicial
    print("\n" + "=" * 70)
    print("PRUEBA INICIAL")
    print("=" * 70)
    print("\nPASOS:")
    print("  1. Captura 4 bits en el sensor (presiona el botón 4 veces)")
    print("  2. Ajusta los SWITCHES para elegir la operación")
    print("  3. El siguiente comando enviará A=5 y calculará: 5 op B_sensor")
    print()
    
    input("Presiona ENTER cuando hayas capturado los 4 bits del sensor...")
    
    # Enviar operando A de prueba
    A_test = 0x5
    send_operand_a(A_test)
    time.sleep(0.5)
    
    print("\n" + "-" * 70)
    print("Leyendo resultado...")
    read_result()
    print("-" * 70)
    
    print("\n✓ Prueba completada")
    print("\nAhora puedes:")
    print("  • Ver el resultado en los LEDs de la FPGA")
    print("  • Ver los bits capturados en sensor_leds")
    print("  • Cambiar operaciones con los SWITCHES")
    
    try:
        input("\nPresiona ENTER para modo interactivo, o Ctrl+C para salir...")
        interactive_mode()
    except KeyboardInterrupt:
        pass
    
    print("\nFinalizando. Flushing...")
    flush(2)
    print("Listo.")

if __name__ == "__main__":
    main()
