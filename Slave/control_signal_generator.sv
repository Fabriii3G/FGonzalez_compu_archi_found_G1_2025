// ============================================================================
// Módulo: Generador de señales de control - CON REGISTRO AUXILIAR
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
    input  logic [2:0] bit_count,
    output logic rx_enable,
    output logic tx_load,
    output logic tx_shift,
    output logic counter_enable,
    output logic counter_clear
);
    logic [2:0] bit_count_prev;
    
    // Capturar el count anterior para saber si debemos hacer shift
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count_prev <= 3'd0;
        end else if (state_transfer & sck_rising) begin
            bit_count_prev <= bit_count;  // Guardar count ANTES del increment
        end else if (state_idle) begin
            bit_count_prev <= 3'd0;
        end
    end
    
    // RX: habilitar en flancos de subida durante TRANSFER
    assign rx_enable = state_transfer & sck_rising;
    
    // TX: cargar cuando CS cae en IDLE  
    assign tx_load = state_idle & cs_falling;
    
    // TX: desplazar si el bit ANTERIOR era 0-6 (no 7)
    logic should_shift;
    assign should_shift = (bit_count_prev != 3'd7);
    assign tx_shift = state_transfer & sck_falling & should_shift;
    
    // Contador: incrementar en flancos de subida durante TRANSFER
    assign counter_enable = state_transfer & sck_rising;
    
    // Contador: limpiar en IDLE
    assign counter_clear = state_idle;
endmodule