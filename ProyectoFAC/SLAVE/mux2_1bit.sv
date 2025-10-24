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
    logic nsel;
    logic a0, a1;

    // Compuertas primitivas
    not u_inv (nsel, sel);     // nsel = ~sel
    and u_and0(a0, in0, nsel); // a0 = in0 & ~sel
    and u_and1(a1, in1, sel);  // a1 = in1 &  sel
    or  u_or  (out, a0, a1);   // out = a0 | a1
endmodule