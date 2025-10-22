// ============================================================================
// Módulo: Registro de desplazamiento para transmisión (MISO)
// ============================================================================
module shift_register_tx (
    input  logic clk,
    input  logic rst_n,
    input  logic load,
    input  logic shift,
    input  logic [7:0] data_in,
    output logic serial_out
);
    logic [7:0] shift_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= 8'h00;
            serial_out <= 1'b0;
        end else begin
            if (load) begin
                shift_reg  <= data_in;
                serial_out <= data_in[7];  // MSB primero
            end else if (shift) begin
                shift_reg  <= {shift_reg[6:0], 1'b0};
                serial_out <= shift_reg[7];  // CORREGIDO: usar bit 7, no 6
            end
        end
    end
endmodule