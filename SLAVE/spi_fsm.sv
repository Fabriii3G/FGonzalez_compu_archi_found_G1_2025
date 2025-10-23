// ============================================================================
// Módulo: FSM de 2 bits (codificación one-hot simplificada)
// Estados: IDLE=00, TRANSFER=01, PROCESS=10
// ============================================================================
module spi_fsm (
    input  logic clk,
    input  logic rst_n,
    input  logic cs_active,        // CS activo (bajo)
    input  logic bit_count_7,      // Contador llegó a 7
    input  logic sck_rising,       // Flanco de subida de SCK
    output logic state_idle,
    output logic state_transfer,
    output logic state_process
);
    logic [1:0] state_reg;
    logic [1:0] state_next;
    
    // Registro de estado
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= 2'b00;  // IDLE
        end else begin
            state_reg <= state_next;
        end
    end
    
    // Lógica de siguiente estado (estructural)
    logic go_to_transfer, go_to_process, go_to_idle;
    
    assign go_to_transfer = state_idle & cs_active;
    assign go_to_process  = state_transfer & bit_count_7 & sck_rising;
    assign go_to_idle     = (state_transfer & ~cs_active) | state_process;
    
    assign state_next[0] = go_to_transfer | (state_transfer & ~go_to_process & ~go_to_idle);
    assign state_next[1] = go_to_process;
    
    // Decodificación de estados
    assign state_idle     = (state_reg == 2'b00);
    assign state_transfer = (state_reg == 2'b01);
    assign state_process  = (state_reg == 2'b10);
endmodule