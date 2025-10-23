// ============================================================================
// Módulo: Detector de flancos
// ============================================================================
module edge_detector (
    input  logic clk,
    input  logic rst_n,
    input  logic signal_in,
    output logic rising_edge,
    output logic falling_edge
);
    logic signal_prev;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            signal_prev <= 1'b0;
        end else begin
            signal_prev <= signal_in;
        end
    end
    
    assign rising_edge  = signal_in & ~signal_prev;
    assign falling_edge = ~signal_in & signal_prev;
endmodule