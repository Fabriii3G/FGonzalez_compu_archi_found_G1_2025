// ============================================================================
// Módulo: Decodificador de Comandos
// ============================================================================
module command_decoder (
    input  logic [7:0] rx_data,
    output logic is_handshake_start,  // 0xA5
    output logic is_handshake_end,    // 0x5A
    output logic is_pilot_signal,     // 0xFF
    output logic is_led_command       // Cualquier otro valor
);
    always_comb begin
        is_handshake_start = (rx_data == 8'hA5);
        is_handshake_end   = (rx_data == 8'h5A);
        is_pilot_signal    = (rx_data == 8'hFF);
        is_led_command     = ~is_handshake_start & ~is_handshake_end & ~is_pilot_signal;
    end
endmodule