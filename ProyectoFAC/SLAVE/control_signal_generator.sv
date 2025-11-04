// ============================================================================
// Módulo: Generador de señales de control - ESTRUCTURAL (sin if/case/?)
// Comportamiento idéntico al RTL dado
// ============================================================================
module control_signal_generator (
    input  logic clk,
    input  logic rst_n,          // reset asíncrono activo en 0
    input  logic state_idle,
    input  logic state_transfer,
    input  logic state_process,  // (no se usa aquí, pero se conserva por interfaz)
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
    // ----------------------------
    // Registro auxiliar bit_count_prev
    // ----------------------------
    logic [2:0] bit_count_prev;

    // Carga activa cuando estamos transfiriendo y hay flanco de subida de SCK
    logic load_prev;
    assign load_prev = state_transfer & sck_rising;

    // Limpieza sincrónica en IDLE (prioridad por sclr; no coincide con load si FSM está bien)
    logic clr_prev_sync;
    assign clr_prev_sync = state_idle;

    // Tres FFs dffeas con:
    //  - clrn  = rst_n (reset asíncrono a 0)
    //  - sclr  = state_idle (clear sincrónico)
    //  - ena   = load_prev (carga bit_count cuando corresponde)
    //  - d     = bit_count[i]
    dffeas ff_prev_0(
        .q(bit_count_prev[0]), .d(bit_count[0]), .clk(clk),
        .ena(load_prev), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(clr_prev_sync), .sload(1'b0)
    );

    dffeas ff_prev_1(
        .q(bit_count_prev[1]), .d(bit_count[1]), .clk(clk),
        .ena(load_prev), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(clr_prev_sync), .sload(1'b0)
    );

    dffeas ff_prev_2(
        .q(bit_count_prev[2]), .d(bit_count[2]), .clk(clk),
        .ena(load_prev), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(clr_prev_sync), .sload(1'b0)
    );

    // ----------------------------
    // Señales de control (combinacional pura)
    // ----------------------------

    // RX: habilitar en flancos de subida durante TRANSFER
    assign rx_enable = state_transfer & sck_rising;

    // TX: cargar cuando CS cae en IDLE
    assign tx_load = state_idle & cs_falling;

    // TX: desplazar si el bit ANTERIOR era 0..6 (no 7)
    // (bit_count_prev != 7) == ~(b2 & b1 & b0)
    logic prev_is_7, should_shift;
    assign prev_is_7   = bit_count_prev[2] & bit_count_prev[1] & bit_count_prev[0];
    assign should_shift = ~prev_is_7;

    assign tx_shift = state_transfer & sck_falling & should_shift;

    // Contador: incrementar en flancos de subida durante TRANSFER
    assign counter_enable = state_transfer & sck_rising;

    // Contador: limpiar en IDLE
    assign counter_clear = state_idle;

endmodule
