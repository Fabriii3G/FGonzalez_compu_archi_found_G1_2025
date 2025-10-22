// ============================================================================
// Módulo: Contador de bits
// ============================================================================
module bit_counter (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,        // Habilitar conteo
    input  logic clear,         // Reiniciar contador
    output logic [2:0] count,   // Cuenta actual (0-7)
    output logic terminal       // Indica que llegó a 7
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 3'd0;
        end else begin
            if (clear) begin
                count <= 3'd0;
            end else if (enable) begin
                count <= count + 1'b1;
            end
        end
    end
    
    assign terminal = (count == 3'd7);
endmodule