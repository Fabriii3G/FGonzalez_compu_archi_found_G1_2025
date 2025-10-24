// ============================================================================
// Módulo de PRUEBA SIMPLE: Loopback MISO = MOSI
// Si este funciona, el problema es la FSM. Si no funciona, es el pin.
// ============================================================================
module spi_loopback_test (
    input  logic clk,          // 50 MHz (no usado en este test)
    input  logic rst_n,        // Reset (no usado en este test)
    
    // Señales SPI
    input  logic spi_sck,
    input  logic spi_mosi,
    input  logic spi_cs_n,
    output logic spi_miso,     // ← IMPORTANTE: debe ser OUTPUT
    
    // LEDs para debug
    output logic [3:0] leds
);

    // ========================================================================
    // TEST 1: Simplemente hacer MISO = MOSI (loopback directo)
    // ========================================================================
    assign spi_miso = spi_mosi;  // Echo directo
    
    // ========================================================================
    // TEST 2: Mostrar estado de CS en los LEDs
    // ========================================================================
    assign leds[0] = ~spi_cs_n;  // LED 0 = CS activo
    assign leds[1] = spi_sck;    // LED 1 = SCK
    assign leds[2] = spi_mosi;   // LED 2 = MOSI
    assign leds[3] = spi_miso;   // LED 3 = MISO (debe ser igual a LED 2)
    
    // Si los LEDs funcionan, la FPGA está programada
    // Si MISO = MOSI en el Pico, el pin MISO funciona
    
endmodule