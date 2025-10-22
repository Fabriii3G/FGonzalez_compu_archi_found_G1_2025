module tx_response_generator (
    input  logic clk,
    input  logic rst_n,
    input  logic is_handshake,      // Es mensaje de handshake
    input  logic [3:0] led_data,    // Datos de los LEDs
    output logic [7:0] tx_data      // Byte a transmitir
);
    localparam HANDSHAKE_RESPONSE = 8'h5A;  // Respuesta al handshake
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_data <= 8'h00;
        end else begin
            if (is_handshake) begin
                tx_data <= HANDSHAKE_RESPONSE;
            end else begin
                // Enviar los 4 bits en la parte baja, parte alta en 0
                tx_data <= {4'b0000, led_data};
            end
        end
    end
endmodule