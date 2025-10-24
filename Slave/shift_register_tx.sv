// ============================================================================
// Módulo: Registro de desplazamiento TX (8 bits, MSB primero)
// CORREGIDO: El shift saca el bit correcto
// ============================================================================
module shift_register_tx (
    input  logic clk,
    input  logic rst_n,
    input  logic load,
    input  logic shift,
    input  logic [7:0] parallel_in,
    output logic serial_out
);
    logic [7:0] shift_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= 8'h5A;
            serial_out <= 1'b1;
        end else begin
            if (load) begin
                // Cargar y poner MSB en salida
                shift_reg  <= parallel_in;
                serial_out <= parallel_in[7];
            end else if (shift) begin
                // Desplazar Y actualizar salida al mismo tiempo
                shift_reg  <= {shift_reg[6:0], 1'b0};
                serial_out <= shift_reg[6];  // Siguiente bit listo
            end
        end
    end
endmodule