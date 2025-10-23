// ============================================================================
// Módulo: Registro de 4 bits con enable
// ============================================================================
module register_4bit (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic [3:0] data_in,
    output logic [3:0] data_out
);
    logic [3:0] reg_data;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_data <= 4'h0;
        end else begin
            reg_data <= enable ? data_in : reg_data;
        end
    end
    
    assign data_out = reg_data;
endmodule