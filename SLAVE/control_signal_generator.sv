// ============================================================================
// Módulo: Generador de señales de control
// ============================================================================
module control_signal_generator (
    input  logic clk,
    input  logic rst_n,
    input  logic state_idle,
    input  logic state_transfer,
    input  logic state_process,
    input  logic cs_falling,
    input  logic sck_rising,
    input  logic sck_falling,
    input  logic bit_count_0,
    output logic rx_enable,
    output logic tx_load,
    output logic tx_shift,
    output logic counter_enable,
    output logic counter_clear
);
    // RX: habilitar en flancos de subida durante TRANSFER
    assign rx_enable = state_transfer & sck_rising;
    
    // TX: cargar cuando CS cae en IDLE
    assign tx_load = state_idle & cs_falling;
    
    // TX: desplazar DESPUÉS de cada captura RX (en flanco de subida)
    // pero NO en el bit 0 (el primer bit ya está cargado)
    assign tx_shift = state_transfer & sck_rising & ~bit_count_0;
    
    // Contador: incrementar en flancos de subida durante TRANSFER
    assign counter_enable = state_transfer & sck_rising;
    
    // Contador: limpiar en IDLE o al entrar a PROCESS
    assign counter_clear = state_idle | state_process;
endmodule