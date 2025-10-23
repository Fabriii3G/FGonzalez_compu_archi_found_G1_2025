// ============================================================================
// Módulo: Watchdog Timer - Detecta timeout de 3 segundos
// ============================================================================
module watchdog_timer (
    input  logic clk,              // 50 MHz
    input  logic rst_n,
    input  logic activity,         // Pulso cuando hay actividad
    input  logic enable,           // Habilitar watchdog
    output logic timeout           // 1 si han pasado 3 segundos sin actividad
);
    // 3 segundos a 50 MHz = 150,000,000 ciclos
    // Usamos 27 bits para contar hasta ~134M (suficiente para 3s)
    localparam TIMEOUT_CYCLES = 150_000_000;
    logic [26:0] counter;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 27'd0;
            timeout <= 1'b0;
        end else if (!enable) begin
            counter <= 27'd0;
            timeout <= 1'b0;
        end else if (activity) begin
            // Resetear contador cuando hay actividad
            counter <= 27'd0;
            timeout <= 1'b0;
        end else if (counter >= TIMEOUT_CYCLES[26:0]) begin
            // Timeout alcanzado
            timeout <= 1'b1;
        end else begin
            counter <= counter + 1'b1;
        end
    end
endmodule