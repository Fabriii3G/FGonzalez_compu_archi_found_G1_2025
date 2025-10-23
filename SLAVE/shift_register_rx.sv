// ============================================================================
// Módulo: Registro de desplazamiento RX (8 bits, MSB primero)
// ============================================================================
module shift_register_rx (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic serial_in,
    output logic [7:0] parallel_out
);
    logic [7:0] shift_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 8'h00;
        end else begin
            shift_reg <= enable ? {shift_reg[6:0], serial_in} : shift_reg;
        end
    end
    
    assign parallel_out = shift_reg;
endmodule
