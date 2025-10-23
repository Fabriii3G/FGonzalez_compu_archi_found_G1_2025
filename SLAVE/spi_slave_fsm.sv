// ============================================================================
// Módulo TOP: SPI Slave - Diseño Estructural
// ============================================================================
module spi_slave_fsm (
    input  logic clk,              // 50 MHz
    input  logic rst_n,
    
    input  logic spi_sck,
    input  logic spi_mosi,
    input  logic spi_cs_n,
    output logic spi_miso,
    
    output logic [3:0] leds,
    output logic handshake_ok,
    output logic data_valid
);

    // Señales sincronizadas
    logic sck_sync, cs_sync, mosi_sync;
    logic sck_rising, sck_falling;
    logic cs_falling;
    
    // Señales de control
    logic rx_enable, tx_load, tx_shift;
    logic counter_enable, counter_clear;
    
    // Datos y estados
    logic [7:0] rx_data;
    logic [7:0] tx_data_reg;
    logic [7:0] tx_data_mux;
    logic [2:0] bit_count;
    logic [3:0] led_data;
    
    // Señales de estado
    logic state_idle, state_transfer, state_process;
    
    // Señales de comparación
    logic is_handshake;
    logic bit_count_7;
    logic cs_active;
    logic led_load;
    
    // Constantes
    localparam [7:0] HANDSHAKE_CODE = 8'hA5;
    localparam [7:0] HANDSHAKE_RESP = 8'h5A;
    
    // ========================================================================
    // Sincronizadores
    // ========================================================================
    synchronizer sync_sck_inst (
        .clk(clk), .rst_n(rst_n),
        .async_in(spi_sck), .sync_out(sck_sync)
    );
    
    synchronizer sync_cs_inst (
        .clk(clk), .rst_n(rst_n),
        .async_in(spi_cs_n), .sync_out(cs_sync)
    );
    
    synchronizer sync_mosi_inst (
        .clk(clk), .rst_n(rst_n),
        .async_in(spi_mosi), .sync_out(mosi_sync)
    );
    
    // ========================================================================
    // Detectores de flancos
    // ========================================================================
    edge_detector edge_sck (
        .clk(clk), .rst_n(rst_n),
        .signal_in(sck_sync),
        .rising_edge(sck_rising),
        .falling_edge(sck_falling)
    );
    
    edge_detector edge_cs (
        .clk(clk), .rst_n(rst_n),
        .signal_in(cs_sync),
        .rising_edge(),
        .falling_edge(cs_falling)
    );
    
    // ========================================================================
    // Shift registers
    // ========================================================================
    shift_register_rx rx_shift_inst (
        .clk(clk), .rst_n(rst_n),
        .enable(rx_enable),
        .serial_in(mosi_sync),
        .parallel_out(rx_data)
    );
    
    shift_register_tx tx_shift_inst (
        .clk(clk), .rst_n(rst_n),
        .load(tx_load),
        .shift(tx_shift),
        .parallel_in(tx_data_reg),
        .serial_out(spi_miso)
    );
    
    // ========================================================================
    // Contador de bits
    // ========================================================================
    bit_counter counter (
        .clk(clk), .rst_n(rst_n),
        .enable(counter_enable),
        .clear(counter_clear),
        .count(bit_count)
    );
    
    // ========================================================================
    // Comparadores
    // ========================================================================
    comparator_8bit handshake_comp (
        .data_a(rx_data),
        .data_b(HANDSHAKE_CODE),
        .equal(is_handshake)
    );
    
    assign bit_count_7 = (bit_count == 3'd7);
    assign cs_active   = ~cs_sync;
    
    // ========================================================================
    // FSM
    // ========================================================================
    spi_fsm fsm_inst (
        .clk(clk), .rst_n(rst_n),
        .cs_active(cs_active),
        .bit_count_7(bit_count_7),
        .sck_rising(sck_rising),
        .state_idle(state_idle),
        .state_transfer(state_transfer),
        .state_process(state_process)
    );
    
    // ========================================================================
    // Generador de señales de control
    // ========================================================================
    control_signal_generator ctrl_gen (
        .clk(clk), .rst_n(rst_n),
        .state_idle(state_idle),
        .state_transfer(state_transfer),
        .state_process(state_process),
        .cs_falling(cs_falling),
        .sck_rising(sck_rising),
        .sck_falling(sck_falling),
        .bit_count(bit_count),
        .rx_enable(rx_enable),
        .tx_load(tx_load),
        .tx_shift(tx_shift),
        .counter_enable(counter_enable),
        .counter_clear(counter_clear)
    );
    
    // ========================================================================
    // Multiplexor para TX data (handshake vs LED echo)
    // ========================================================================
    mux2_8bit tx_mux (
        .in0({4'h0, led_data}),
        .in1(HANDSHAKE_RESP),
        .sel(is_handshake),
        .out(tx_data_mux)
    );
    
    // ========================================================================
    // Registro de TX data (actualiza en PROCESS)
    // ========================================================================
    register_8bit tx_data_reg_inst (
        .clk(clk), .rst_n(rst_n),
        .enable(state_process),
        .data_in(tx_data_mux),
        .data_out(tx_data_reg)
    );
    
    // ========================================================================
    // Registro de LEDs (carga solo si NO es handshake)
    // ========================================================================
    assign led_load = state_process & ~is_handshake;
    
    register_4bit led_reg (
        .clk(clk), .rst_n(rst_n),
        .enable(led_load),
        .data_in(rx_data[3:0]),
        .data_out(led_data)
    );
    
    // ========================================================================
    // Registro de handshake_ok
    // ========================================================================
    logic hs_set;
    assign hs_set = state_process & is_handshake;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            handshake_ok <= 1'b0;
        end else begin
            handshake_ok <= hs_set | handshake_ok;
        end
    end
    
    // ========================================================================
    // Salidas
    // ========================================================================
    assign leds = led_data;
    assign data_valid = state_process;

endmodule