// ============================================================================
// Módulo TOP: Máquina de estados SPI Slave 
// ============================================================================
module spi_slave_fsm (
    input  logic clk,              // Reloj del sistema FPGA
    input  logic rst_n,            // Reset activo bajo
    
    // Señales SPI
    input  logic spi_sck,          // SPI Clock del Master
    input  logic spi_mosi,         // Master Out Slave In
    input  logic spi_cs_n,         // Chip Select activo bajo
    output logic spi_miso,         // Master In Slave Out
    
    // Señales de salida
    output logic [3:0] leds,       // 4 LEDs físicos
    output logic handshake_ok,     // Indica handshake exitoso
    output logic data_valid        // Pulso cuando hay dato válido
);

    // ========================================================================
    // Definición de estados - CORREGIDA
    // ========================================================================
    typedef enum logic [1:0] {
        IDLE       = 2'b00,   // Estado de inicio/espera
        TRANSFER   = 2'b01,   // Transferencia simultánea RX/TX
        PROCESS    = 2'b10    // Procesar dato recibido (handshake o LEDs)
    } state_t;
    
    state_t current_state, next_state;
    
    
    // ========================================================================
    // Señales sincronizadas
    // ========================================================================
    logic sck_sync, cs_sync, mosi_sync;
    logic sck_rising, sck_falling;
    
    
    // ========================================================================
    // Señales de control de la FSM
    // ========================================================================
    logic rx_enable;           // Habilitar recepción
    logic rx_load;             // Cargar dato recibido en buffer
    logic tx_load;             // Cargar dato en registro TX
    logic tx_shift;            // Desplazar registro TX
    logic counter_enable;      // Habilitar contador de bits
    logic counter_clear;       // Reiniciar contador
    logic check_handshake;     // Verificar si es handshake
    logic led_load;            // Cargar datos en LEDs
    
    
    // ========================================================================
    // Señales internas de los módulos
    // ========================================================================
    logic [2:0] bit_count;
    logic bit_count_terminal;
    logic [7:0] rx_data;
    logic [7:0] tx_data;
    logic is_handshake;
    logic [3:0] led_data;
    
    
    // ========================================================================
    // Instanciación de módulos auxiliares
    // ========================================================================
    
    // Sincronizadores
    synchronizer sync_sck (
        .clk(clk),
        .rst_n(rst_n),
        .async_in(spi_sck),
        .sync_out(sck_sync)
    );
    
    synchronizer sync_cs (
        .clk(clk),
        .rst_n(rst_n),
        .async_in(spi_cs_n),
        .sync_out(cs_sync)
    );
    
    synchronizer sync_mosi (
        .clk(clk),
        .rst_n(rst_n),
        .async_in(spi_mosi),
        .sync_out(mosi_sync)
    );
    
    // Detector de flancos para SCK
    edge_detector edge_det (
        .clk(clk),
        .rst_n(rst_n),
        .signal_in(sck_sync),
        .rising_edge(sck_rising),
        .falling_edge(sck_falling)
    );
    
    // Registro de desplazamiento RX
    shift_register_rx rx_shifter (
        .clk(clk),
        .rst_n(rst_n),
        .enable(rx_enable),
        .serial_in(mosi_sync),
        .load(rx_load),
        .data_out(rx_data)
    );
    
    // Registro de desplazamiento TX
    shift_register_tx tx_shifter (
        .clk(clk),
        .rst_n(rst_n),
        .load(tx_load),
        .shift(tx_shift),
        .data_in(tx_data),
        .serial_out(spi_miso)
    );
    
    // Contador de bits
    bit_counter counter (
        .clk(clk),
        .rst_n(rst_n),
        .enable(counter_enable),
        .clear(counter_clear),
        .count(bit_count),
        .terminal(bit_count_terminal)
    );
    
    // Verificador de handshake
    handshake_checker hs_checker (
        .clk(clk),
        .rst_n(rst_n),
        .check_enable(check_handshake),
        .data_in(rx_data),
        .is_handshake(is_handshake)
    );
    
    // Registro de LEDs
    led_register led_reg (
        .clk(clk),
        .rst_n(rst_n),
        .load(led_load),
        .data_in(rx_data[3:0]),  // Solo los 4 bits bajos
        .data_out(led_data)
    );
    
    // Generador de respuesta TX
    tx_response_generator tx_gen (
        .clk(clk),
        .rst_n(rst_n),
        .is_handshake(is_handshake),
        .led_data(led_data),
        .tx_data(tx_data)
    );
    
    
    // ========================================================================
    // Máquina de estados - Lógica de siguiente estado CORREGIDA
    // ========================================================================
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                // Esperar a que CS se active (bajo)
                if (!cs_sync) begin
                    next_state = TRANSFER;
                end
            end
            
            TRANSFER: begin
                // Si CS se desactiva prematuramente, volver a IDLE
                if (cs_sync) begin
                    next_state = IDLE;
                // Si completamos 8 bits, procesar
                end else if (bit_count_terminal && sck_rising) begin
                    next_state = PROCESS;
                end
            end
            
            PROCESS: begin
                // Siempre volver a IDLE después de procesar
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    
    // ========================================================================
    // Máquina de estados - Registro de estado
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    
    // ========================================================================
    // Señal interna para led_load
    // ========================================================================
    logic led_load_internal;
    
    
    // ========================================================================
    // Lógica de control - Generación de señales de control CORREGIDA
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
                tx_load       = 1'b1;  // Preparar respuesta TX
            end
            
            TRANSFER: begin
                // RX: Capturar en flanco de subida (CPOL=0, CPHA=0)
                if (sck_rising) begin
                    rx_enable      = 1'b1;
                    counter_enable = 1'b1;
                end
                
                // TX: Actualizar salida en flanco de bajada
                if (sck_falling) begin
                    tx_shift = 1'b1;
                end
                
                // Cargar dato recibido al completar 8 bits
                if (bit_count_terminal && sck_rising) begin
                    rx_load = 1'b1;
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
    // Lógica para cargar LEDs (solo si NO es handshake)
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_load_internal <= 1'b0;
        end else begin
            if (current_state == PROCESS && !is_handshake) begin
                led_load_internal <= 1'b1;
            end else begin
                led_load_internal <= 1'b0;
            end
        end
    end
    
    // Asignar señal interna al módulo LED
    assign led_load = led_load_internal;
    
    
    // ========================================================================
    // Registro de handshake_ok (se mantiene activo tras handshake exitoso)
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            handshake_ok <= 1'b0;
        end else begin
            if (current_state == PROCESS && is_handshake) begin
                handshake_ok <= 1'b1;
            end
        end
    end
    
    
    // ========================================================================
    // Asignación de salidas
    // ========================================================================
    assign leds = led_data;

endmodule