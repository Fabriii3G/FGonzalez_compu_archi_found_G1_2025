// ============================================================================
// Celda base: MUX 2:1 de 1 bit (estructural con compuertas)
// out = (in0 & ~sel) | (in1 & sel)
// ============================================================================
module mux2_1bit (
    input  logic in0,
    input  logic in1,
    input  logic sel,
    output logic out
);

    assign out = in0 & ~sel | in1 & sel;

endmodule
