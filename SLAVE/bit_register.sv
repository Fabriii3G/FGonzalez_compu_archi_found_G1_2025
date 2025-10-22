module led_register (
    input  logic clk,
    input  logic rst_n,
    input  logic load,              // Cargar nuevos datos
    input  logic [3:0] data_in,     // 4 bits de entrada
    output logic [3:0] data_out     // 4 bits para LEDs
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 4'b0000;
        end else if (load) begin
            data_out <= data_in;
        end
    end
endmodule