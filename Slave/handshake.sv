module handshake (
    input  logic clk,
    input  logic rst_n,
    input  logic check_enable,
    input  logic [7:0] data_in,
    output logic is_handshake
);
    localparam HANDSHAKE_CODE = 8'hA5;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_handshake <= 1'b0;
        end else if (check_enable) begin
            is_handshake <= (data_in == HANDSHAKE_CODE);
        end
    end
endmodule