// ============================================================================
// Módulo: Registro de desplazamiento RX (8 bits, MSB primero)
// Implementación ESTRUCTURAL con DFFs Intel 'dffeas' (sin if / ?: / case)
//  - rst_n: clear asíncrono activo en 0 (CLRN del FF)
//  - enable: conectado a ENA del FF (hold cuando 0, captura cuando 1)
//  - MSB-first: q0<=serial_in; q1<=q0; ...; q7<=q6
// ============================================================================
module shift_register_rx (
    input  logic clk,
    input  logic rst_n,       // reset asíncrono activo en 0
    input  logic enable,
    input  logic serial_in,
    output logic [7:0] parallel_out
);
    logic q0, q1, q2, q3, q4, q5, q6, q7;

    // dffeas: puertos (orden común) -> q, d, clk, ena, clrn, prn, asdata, sload, aload
    dffeas ff0 (.q(q0), .d(serial_in), .clk(clk), .ena(enable), .clrn(rst_n), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));
    dffeas ff1 (.q(q1), .d(q0),       .clk(clk), .ena(enable), .clrn(rst_n), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));
    dffeas ff2 (.q(q2), .d(q1),       .clk(clk), .ena(enable), .clrn(rst_n), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));
    dffeas ff3 (.q(q3), .d(q2),       .clk(clk), .ena(enable), .clrn(rst_n), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));
    dffeas ff4 (.q(q4), .d(q3),       .clk(clk), .ena(enable), .clrn(rst_n), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));
    dffeas ff5 (.q(q5), .d(q4),       .clk(clk), .ena(enable), .clrn(rst_n), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));
    dffeas ff6 (.q(q6), .d(q5),       .clk(clk), .ena(enable), .clrn(rst_n), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));
    dffeas ff7 (.q(q7), .d(q6),       .clk(clk), .ena(enable), .clrn(rst_n), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));

    assign parallel_out = {q7, q6, q5, q4, q3, q2, q1, q0};
endmodule
