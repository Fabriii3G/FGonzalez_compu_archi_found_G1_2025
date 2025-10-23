// ============================================================================
// Módulo: Registro de desplazamiento TX (8 bits, MSB primero)
// CORREGIDO: Shift correcto sin glitches
// ============================================================================
// ============================================================================
// Módulo: Registro de desplazamiento TX - VERSIÓN FINAL CORREGIDA
// El serial_out debe actualizarse CON el desplazamiento, no antes
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
    logic [7:0] next_shift_reg;
    logic next_serial_out;
    
    // Lógica combinacional para calcular próximo estado
    always_comb begin
        if (load) begin
            next_shift_reg = parallel_in;
            next_serial_out = parallel_in[7];
        end else if (shift) begin
            next_shift_reg = {shift_reg[6:0], 1'b0};
            next_serial_out = shift_reg[6];  // El bit que SERÁ el nuevo [7]
        end else begin
            next_shift_reg = shift_reg;
            next_serial_out = serial_out;
        end
    end
    
    // Registro secuencial
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= 8'h5A;
            serial_out <= 1'b1;
        end else begin
            shift_reg  <= next_shift_reg;
            serial_out <= next_serial_out;
        end
    end
endmodule