// ============================================================================
// Módulo: Multiplexor 2:1 de 8 bits
// ============================================================================
module mux2_8bit (
    input  logic [7:0] in0,
    input  logic [7:0] in1,
    input  logic sel,
    output logic [7:0] out
);
    assign out = sel ? in1 : in0;
endmodule