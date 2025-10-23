// ============================================================================
// Módulo: Contador de 3 bits (0-7)
// ============================================================================
module bit_counter (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic clear,
    output logic [2:0] count
);
    logic [2:0] count_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_reg <= 3'd0;
        end else begin
            count_reg <= clear ? 3'd0 : (enable ? count_reg + 3'd1 : count_reg);
        end
    end
    
    assign count = count_reg;
endmodule