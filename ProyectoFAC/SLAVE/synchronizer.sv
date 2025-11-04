// ============================================================================
// Módulo: Sincronizador de señales 
// Reset asíncrono activo en 0, liberación síncrona con el clk.
// ============================================================================
module synchronizer (
    input  logic clk,
    input  logic rst_n,     // reset asíncrono activo en 0
    input  logic async_in,
    output logic sync_out
);
    (* ASYNC_REG = "TRUE" *) logic sync_ff1;

    // Primera etapa: al caer rst_n, asigna 0 (porque async_in & rst_n = 0)
    always_ff @(posedge clk or negedge rst_n) begin
        sync_ff1 <= async_in & rst_n;
    end

    // Segunda etapa: igual mecanismo, encadenada
    always_ff @(posedge clk or negedge rst_n) begin
        sync_out <= sync_ff1 & rst_n;
    end
endmodule