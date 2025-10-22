// ============================================================================
// Módulo: Registro de desplazamiento para transmisión (MISO)
// ============================================================================
module shift_register_tx (
    input  logic clk,
    input  logic rst_n,
    input  logic load,          // Cargar nuevo dato
    input  logic shift,         // Habilitar desplazamiento
    input  logic [7:0] data_in, // Dato a enviar
    output logic serial_out     // Bit de salida (MISO)
);
    logic [7:0] shift_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= 8'h00;
            serial_out <= 1'b0;
        end else begin
            if (load) begin
                shift_reg  <= data_in;
                serial_out <= data_in[7];  // Primer bit (MSB)
            end else if (shift) begin
                shift_reg  <= {shift_reg[6:0], 1'b0};
                serial_out <= shift_reg[6]; // Siguiente bit
            end
        end
    end
endmodule