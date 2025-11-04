// ============================================================================
// Módulo: Contador de 3 bits (0-7) - ESTRUCTURAL (sin if/case/?/for/+)
// - Incrementa en 1 cuando enable=1
// - clear: borrado sincrónico a 0 (tiene prioridad sobre enable)
// - rst_n: reset asíncrono activo en 0
// ============================================================================
module bit_counter (
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    input  logic clear,
    output logic [2:0] count
);
    // Estado actual
    logic q2, q1, q0;

    // Lógica de incremento (ripple, +1) sólo con compuertas
    logic d2, d1, d0;
    logic c0, c1;

    // bit0: d0 = ~q0; carry c0 = q0
    assign d0 = ~q0;
    assign c0 = q0;

    // bit1: d1 = q1 ^ c0; carry c1 = q1 & c0
    assign d1 = q1 ^ c0;
    assign c1 = q1 & c0;

    // bit2: d2 = q2 ^ c1
    assign d2 = q2 ^ c1;

    // Flip-flops (dffeas):
    //  - clrn = rst_n  (reset asíncrono a 0)
    //  - sclr = clear  (clear sincrónico; prioridad sobre ena)
    //  - ena  = enable (sólo captura cuando enable=1)
    dffeas ff0(
        .q(q0), .d(d0), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(clear), .sload(1'b0)
    );

    dffeas ff1(
        .q(q1), .d(d1), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(clear), .sload(1'b0)
    );

    dffeas ff2(
        .q(q2), .d(d2), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(clear), .sload(1'b0)
    );

    // Salida
    assign count = {q2, q1, q0};

endmodule
