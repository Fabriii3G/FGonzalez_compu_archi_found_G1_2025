// ============================================================================
// Módulo: Registro de 8 bits con enable
// ============================================================================
module register_8bit (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic [7:0] data_in,
    output logic [7:0] data_out
);
    logic [7:0] reg_data;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            reg_data <= 8'h00;
        end else begin
            reg_data <= enable ? data_in : reg_data;
        end
    end
    
    assign data_out = reg_data;
endmodule