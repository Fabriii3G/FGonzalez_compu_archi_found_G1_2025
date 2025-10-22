// ============================================================================
// Módulo TOP: SPI Slave FSM
// Optimizado para 50 MHz clock con SPI hasta 1 MHz
// ============================================================================
module spi_slave_fsm (
    input  logic clk,              // 50 MHz system clock
    input  logic rst_n,
    
    input  logic spi_sck,
    input  logic spi_mosi,
    input  logic spi_cs_n,
    output logic spi_miso,
    
    output logic [3:0] leds,
    output logic handshake_ok,
    output logic data_valid
);

    typedef enum logic [2:0] {
        IDLE     = 3'b000,
        WAIT_CS  = 3'b001,  // NUEVO: Esperar que CS se estabilice
        TRANSFER = 3'b010,
        PROCESS  = 3'b011
    } state_t;
    
    state_t current_state, next_state;
    
    // Señales sincronizadas
    logic sck_sync, cs_sync, mosi_sync;
    logic sck_rising, sck_falling;
    logic cs_falling;  // Detectar activación de CS
    
    // Señales de control
    logic rx_enable, rx_load;
    logic tx_load, tx_shift;
    logic counter_enable, counter_clear;
    logic check_handshake;
    logic led_load;
    
    // Señales internas
    logic [2:0] bit_count;
    logic bit_count_terminal;
    logic [7:0] rx_data;
    logic [7:0] tx_data;
    logic [7:0] tx_data_next;  // Dato para la PRÓXIMA transacción
    logic is_handshake;
    logic [3:0] led_data;
    
    // Contador de espera para estabilización (50 MHz = 20ns por ciclo)
    // Esperar ~1us = 50 ciclos
    logic [5:0] wait_counter;
    logic wait_done;
    
    // ========================================================================
    // Sincronizadores
    // ========================================================================
    synchronizer sync_sck (
        .clk(clk), .rst_n(rst_n),
        .async_in(spi_sck), .sync_out(sck_sync)
    );
    
    synchronizer sync_cs (
        .clk(clk), .rst_n(rst_n),
        .async_in(spi_cs_n), .sync_out(cs_sync)
    );
    
    synchronizer sync_mosi (
        .clk(clk), .rst_n(rst_n),
        .async_in(spi_mosi), .sync_out(mosi_sync)
    );
    
    // Detector de flancos
    edge_detector edge_det_sck (
        .clk(clk), .rst_n(rst_n),
        .signal_in(sck_sync),
        .rising_edge(sck_rising),
        .falling_edge(sck_falling)
    );
    
    edge_detector edge_det_cs (
        .clk(clk), .rst_n(rst_n),
        .signal_in(cs_sync),
        .rising_edge(),  // No usado
        .falling_edge(cs_falling)
    );
    
    // ========================================================================
    // Shift registers
    // ========================================================================
    shift_register_rx rx_shifter (
        .clk(clk), .rst_n(rst_n),
        .enable(rx_enable),
        .serial_in(mosi_sync),
        .load(rx_load),
        .data_out(rx_data)
    );
    
    shift_register_tx tx_shifter (
        .clk(clk), .rst_n(rst_n),
        .load(tx_load),
        .shift(tx_shift),
        .data_in(tx_data),
        .serial_out(spi_miso)
    );
    
    // ========================================================================
    // Contador de bits
    // ========================================================================
    bit_counter counter (
        .clk(clk), .rst_n(rst_n),
        .enable(counter_enable),
        .clear(counter_clear),
        .count(bit_count),
        .terminal(bit_count_terminal)
    );
    
    // ========================================================================
    // Verificador de handshake
    // ========================================================================
    handshake_checker hs_checker (
        .clk(clk), .rst_n(rst_n),
        .check_enable(check_handshake),
        .data_in(rx_data),
        .is_handshake(is_handshake)
    );
    
    // ========================================================================
    // Registro de LEDs
    // ========================================================================
    led_register led_reg (
        .clk(clk), .rst_n(rst_n),
        .load(led_load),
        .data_in(rx_data[3:0]),
        .data_out(led_data)
    );
    
    // ========================================================================
    // Contador de espera
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wait_counter <= 6'd0;
        end else begin
            if (current_state == WAIT_CS) begin
                wait_counter <= wait_counter + 1'b1;
            end else begin
                wait_counter <= 6'd0;
            end
        end
    end
    
    assign wait_done = (wait_counter >= 6'd10);  // ~200ns @ 50MHz
    
    // ========================================================================
    // Generación del próximo dato TX (lógica combinacional)
    // ========================================================================
    always_comb begin
        if (is_handshake) begin
            tx_data_next = 8'h5A;  // Respuesta a handshake
        end else begin
            tx_data_next = {4'b0000, led_data};  // Echo de LEDs
        end
    end
    
    // ========================================================================
    // Registro del dato TX actual
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data <= 8'h00;
        end else if (current_state == PROCESS) begin
            // Actualizar para la PRÓXIMA transacción
            tx_data <= tx_data_next;
        end
    end
    
    // ========================================================================
    // FSM - Lógica de siguiente estado
    // ========================================================================
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                // Detectar activación de CS
                if (cs_falling) begin
                    next_state = WAIT_CS;
                end
            end
            
            WAIT_CS: begin
                // Esperar estabilización antes de empezar transferencia
                if (cs_sync) begin
                    // CS se desactivó, volver a IDLE
                    next_state = IDLE;
                end else if (wait_done) begin
                    // CS estable, comenzar transferencia
                    next_state = TRANSFER;
                end
            end
            
            TRANSFER: begin
                if (cs_sync) begin
                    // CS desactivado, abortar
                    next_state = IDLE;
                end else if (bit_count_terminal && sck_rising) begin
                    // 8 bits completos
                    next_state = PROCESS;
                end
            end
            
            PROCESS: begin
                // Procesar y volver a IDLE
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // ========================================================================
    // FSM - Registro de estado
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // ========================================================================
    // Lógica de control
    // ========================================================================
    always_comb begin
        // Valores por defecto
        rx_enable       = 1'b0;
        rx_load         = 1'b0;
        tx_load         = 1'b0;
        tx_shift        = 1'b0;
        counter_enable  = 1'b0;
        counter_clear   = 1'b0;
        check_handshake = 1'b0;
        data_valid      = 1'b0;
        
        case (current_state)
            IDLE: begin
                counter_clear = 1'b1;
            end
            
            WAIT_CS: begin
                // Cargar TX apenas se active CS
                if (wait_done) begin
                    tx_load = 1'b1;
                end
            end
            
            TRANSFER: begin
                // RX: Capturar en flanco de subida
                if (sck_rising) begin
                    rx_enable      = 1'b1;
                    counter_enable = 1'b1;
                    
                    // Cargar dato recibido al completar 8 bits
                    if (bit_count_terminal) begin
                        rx_load = 1'b1;
                    end
                end
                
                // TX: Desplazar en flanco de bajada
                // No desplazar en el primer bit (count=0)
                if (sck_falling && bit_count != 3'd0) begin
                    tx_shift = 1'b1;
                end
            end
            
            PROCESS: begin
                check_handshake = 1'b1;
                data_valid      = 1'b1;
            end
            
            default: begin
                counter_clear = 1'b1;
            end
        endcase
    end
    
    // ========================================================================
    // Cargar LEDs
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_load <= 1'b0;
        end else begin
            led_load <= (current_state == PROCESS && !is_handshake);
        end
    end
    
    // ========================================================================
    // Registro de handshake_ok
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            handshake_ok <= 1'b0;
        end else if (current_state == PROCESS && is_handshake) begin
            handshake_ok <= 1'b1;
        end
    end
    
    // ========================================================================
    // Salidas
    // ========================================================================
    assign leds = led_data;

endmodule