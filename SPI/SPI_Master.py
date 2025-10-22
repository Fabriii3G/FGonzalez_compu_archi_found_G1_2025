from machine import Pin, SPI
import time


# Pin Chip Select (CS)
cs = Pin(17, Pin.OUT)

# Configuración SPI
# SPI(0) usa los pines por defecto:
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

# --- Envío de un byte por SPI ---
data = bytes([0b10101010])  # Byte a enviar

while True:
    cs.value(0)          # Seleccionar esclavo
    spi.write(data)      # Enviar byte
    cs.value(1)          # Liberar esclavo

    print("Dato enviado:", bin(data[0]))
    time.sleep(1)        # Espera 1 segundo antes de enviar nuevamente
