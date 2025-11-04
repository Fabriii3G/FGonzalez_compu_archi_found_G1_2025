// ============================================================================
// Módulo: Comparador de 8 bits
// ============================================================================
module comparator_8bit (
    input  logic [7:0] data_a,
    input  logic [7:0] data_b,
    output logic equal
);
    assign equal = (data_a == data_b);
endmodule