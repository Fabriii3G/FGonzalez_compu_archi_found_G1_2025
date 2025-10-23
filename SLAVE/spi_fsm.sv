// ============================================================================
// Módulo: FSM de 2 bits (codificación one-hot simplificada)
// Estados: IDLE=00, TRANSFER=01, PROCESS=10
// ============================================================================
module spi_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic cs_active,
    input  logic bit_count_7,
    input  logic sck_rising,
    output logic state_idle,
    output logic state_transfer,
    output logic state_process
);
    logic [1:0] state_reg;
    
    // Registro de estado con lógica de transición directa
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= 2'b00;  // IDLE
        end else begin
            // Lógica de transición combinada en el always_ff
            if (state_reg == 2'b00) begin  // IDLE
                state_reg <= cs_active ? 2'b01 : 2'b00;
            end else if (state_reg == 2'b01) begin  // TRANSFER
                if (~cs_active) begin
                    state_reg <= 2'b00;  // Abortar si CS se desactiva
                end else if (bit_count_7 & sck_rising) begin
                    state_reg <= 2'b10;  // Ir a PROCESS
                end
            end else begin  // PROCESS (2'b10)
                state_reg <= 2'b00;  // Volver a IDLE
            end
        end
    end
    
    // Decodificación de estados (puramente combinacional)
    assign state_idle     = (state_reg == 2'b00);
    assign state_transfer = (state_reg == 2'b01);
    assign state_process  = (state_reg == 2'b10);
endmodule
