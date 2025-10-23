// ============================================================================
// Módulo: Registro de desplazamiento para recepción (MOSI)
// ============================================================================
module shift_register_rx (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic serial_in,
    input  logic load,
    output logic [7:0] data_out
);
    logic [7:0] shift_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 8'h00;
            data_out  <= 8'h00;
        end else begin
            if (enable) begin
                shift_reg <= {shift_reg[6:0], serial_in};
            end
            
            if (load) begin
                data_out <= {shift_reg[6:0], serial_in};  // Incluir último bit
            end
        end
    end
endmodule
