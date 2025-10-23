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

    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        TRANSFER = 2'b01,
        PROCESS  = 2'b10
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
    logic [7:0] tx_data_reg;
    logic is_handshake;
    logic [3:0] led_data;
    
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
        .falling_edge(cs_falling)  // CS activándose
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
        .data_in(tx_data_reg),
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
    handshake hs_checker (
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
    // Generación del dato TX - CORREGIDO: preparar ANTES de transacción
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data_reg <= 8'h5A;  // Valor inicial visible para debug
        end else if (current_state == PROCESS) begin
            // Preparar respuesta para la PRÓXIMA transacción
            if (is_handshake) begin
                tx_data_reg <= 8'h5A;  // Respuesta a handshake
            end else begin
                tx_data_reg <= {4'h0, led_data};  // Echo de LEDs
            end
        end
    end
    
    // ========================================================================
    // FSM - Lógica de siguiente estado
    // ========================================================================
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (!cs_sync) begin
                    next_state = TRANSFER;
                end
            end
            
            TRANSFER: begin
                if (cs_sync) begin
                    next_state = IDLE;
                end else if (bit_count_terminal && sck_rising) begin
                    next_state = PROCESS;
                end
            end
            
            PROCESS: begin
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
    // Lógica de control - CORREGIDA con mejor timing
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
                // ✓ CRÍTICO: Cargar TX cuando CS se activa (flanco de bajada)
                if (cs_falling) begin
                    tx_load = 1'b1;
                end
            end
            
            TRANSFER: begin
                // RX: Capturar en flanco de subida
                if (sck_rising) begin
                    rx_enable      = 1'b1;
                    counter_enable = 1'b1;
                    
                    // Cargar buffer RX al completar 8 bits
                    if (bit_count_terminal) begin
                        rx_load = 1'b1;
                    end
                end
                
                // TX: Desplazar en flanco de bajada (preparar siguiente bit)
                if (sck_falling) begin
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
    // Cargar LEDs (solo si NO es handshake)
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
    
    assign leds = led_data;

endmodule