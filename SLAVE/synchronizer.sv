// ============================================================================
// Módulo: Sincronizador de señales (anti-metaestabilidad)
// ============================================================================
module synchronizer (
    input  logic clk,
    input  logic rst_n,
    input  logic async_in,
    output logic sync_out
);
    logic sync_ff1;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1  <= 1'b0;
            sync_out  <= 1'b0;
        end else begin
            sync_ff1  <= async_in;
            sync_out  <= sync_ff1;
        end
    end
endmodule