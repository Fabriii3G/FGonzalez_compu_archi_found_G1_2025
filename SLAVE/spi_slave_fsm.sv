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