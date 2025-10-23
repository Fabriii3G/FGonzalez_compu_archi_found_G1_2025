// ============================================================================
// Módulo TOP MODIFICADO: SPI Slave con Watchdog y Handshakes completos
// ============================================================================
module spi_slave_fsm (
    input  logic clk,              // 50 MHz
    input  logic rst_n,
    
    input  logic spi_sck,
    input  logic spi_mosi,
    input  logic spi_cs_n,
    output logic spi_miso,
    
    output logic [3:0] leds,
    output logic handshake_ok,     // Comunicación activa
    output logic data_valid,
    output logic timeout_error     // LED de error por timeout
);

    // Estados de la FSM AMPLIADA
    typedef enum logic [2:0] {
        IDLE           = 3'b000,  // Sin comunicación
        WAIT_HANDSHAKE = 3'b001,  // Esperando handshake inicial
        ACTIVE         = 3'b010,  // Comunicación establecida
        TRANSFER       = 3'b011,  // Transfiriendo datos
        PROCESS        = 3'b100   // Procesando comando recibido
    } state_t;
    
    state_t current_state, next_state;
    
    // Señales sincronizadas (del código original)
    logic sck_sync, cs_sync, mosi_sync;
    logic sck_rising, sck_falling, cs_falling;
    
    // Señales de control
    logic rx_enable, tx_load, tx_shift;
    logic counter_enable, counter_clear;
    
    // Datos
    logic [7:0] rx_data;
    logic [7:0] tx_data_reg;
    logic [2:0] bit_count;
    logic [3:0] led_data;
    
    // Decodificación de comandos
    logic is_handshake_start, is_handshake_end;
    logic is_pilot_signal, is_led_command;
    
    // Watchdog
    logic watchdog_enable, watchdog_timeout, watchdog_activity;
    
    // Control de estados
    logic bit_count_7, cs_active;
    logic communication_established;
    
    // ========================================================================
    // Instanciar módulos auxiliares (sincronizadores, etc.)
    // [Usar el código del documento 3]
    // ========================================================================

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
    
// ahora watchdog y comand
    
    // ========================================================================
    // Decodificador de comandos
    // ========================================================================
    command_decoder cmd_dec (
        .rx_data(rx_data),
        .is_handshake_start(is_handshake_start),
        .is_handshake_end(is_handshake_end),
        .is_pilot_signal(is_pilot_signal),
        .is_led_command(is_led_command)
    );
    
    // ========================================================================
    // Watchdog Timer
    // ========================================================================
    watchdog_timer wdog (
        .clk(clk),
        .rst_n(rst_n),
        .activity(watchdog_activity),
        .enable(watchdog_enable),
        .timeout(watchdog_timeout)
    );
    
    // Activity = cualquier transacción completada
    assign watchdog_activity = (current_state == PROCESS);
    assign watchdog_enable = communication_established;
    
    // ========================================================================
    // FSM - Lógica de siguiente estado AMPLIADA
    // ========================================================================
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                // Esperar actividad en CS
                if (cs_active) begin
                    next_state = WAIT_HANDSHAKE;
                end
            end
            
            WAIT_HANDSHAKE: begin
                if (!cs_active) begin
                    next_state = IDLE;
                end else if (bit_count_7 && sck_rising) begin
                    next_state = PROCESS;
                end
            end
            
            ACTIVE: begin
                // Comunicación establecida, esperar comandos
                if (watchdog_timeout) begin
                    next_state = IDLE;  // Timeout: cerrar comunicación
                end else if (cs_active) begin
                    next_state = TRANSFER;
                end
            end
            
            TRANSFER: begin
                if (!cs_active) begin
                    next_state = ACTIVE;
                end else if (bit_count_7 && sck_rising) begin
                    next_state = PROCESS;
                end
            end
            
            PROCESS: begin
                // Decidir siguiente estado según comando
                if (is_handshake_end || watchdog_timeout) begin
                    next_state = IDLE;  // Cerrar comunicación
                end else begin
                    next_state = ACTIVE;  // Continuar activo
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // ========================================================================
    // Registro de estado
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // ========================================================================
    // Lógica de comunicación establecida
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            communication_established <= 1'b0;
        end else begin
            if (current_state == PROCESS && is_handshake_start) begin
                communication_established <= 1'b1;
            end else if (current_state == IDLE) begin
                communication_established <= 1'b0;
            end
        end
    end
    
    // ========================================================================
    // Generación de TX data según comando
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data_reg <= 8'h00;
        end else if (current_state == PROCESS) begin
            if (is_handshake_start) begin
                tx_data_reg <= 8'h5A;  // ACK de handshake
            end else if (is_pilot_signal) begin
                tx_data_reg <= 8'hFF;  // Echo de piloto
            end else if (is_led_command) begin
                tx_data_reg <= {4'h0, led_data};  // Echo de LEDs
            end else begin
                tx_data_reg <= 8'h00;
            end
        end
    end
    
    // ========================================================================
    // Actualización de LEDs (solo con comandos LED)
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_data <= 4'h0;
        end else if (current_state == PROCESS && is_led_command && communication_established) begin
            led_data <= rx_data[3:0];
        end else if (!communication_established) begin
            led_data <= 4'h0;  // Apagar LEDs si no hay comunicación
        end
    end
    
    // ========================================================================
    // Salidas
    // ========================================================================
    assign leds = led_data;
    assign handshake_ok = communication_established;
    assign data_valid = (current_state == PROCESS);
    assign timeout_error = watchdog_timeout;

endmodule