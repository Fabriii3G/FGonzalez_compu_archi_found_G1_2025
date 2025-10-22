module led_register (
    input  logic clk,
    input  logic rst_n,
    input  logic load,
    input  logic [3:0] data_in,
    output logic [3:0] data_out
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 4'b0000;
        end else if (load) begin
            data_out <= data_in;
        end
    end
endmodule