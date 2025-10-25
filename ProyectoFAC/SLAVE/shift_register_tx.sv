// ============================================================================
// Registro de desplazamiento TX (8 bits, MSB primero) - ESTRUCTURAL SÓLIDA
// - Reset asíncrono: q = 8'h5A, serial_out = 1
// - load: carga paralela y serial_out = parallel_in[7]
// - shift: shift-left (MSB-first), relleno con 0; serial_out toma el "siguiente" bit
// - Sin if/case/?: se implementan MUX con AND/OR/NOT
// ============================================================================
module shift_register_tx (
    input  logic clk,
    input  logic rst_n,         // activo en 0
    input  logic load,          // carga paralela
    input  logic shift,         // desplazar
    input  logic [7:0] parallel_in,
    output logic serial_out
);
    // Estado actual
    logic [7:0] q;

    // Negaciones para MUX 2:1
    logic nL, nS;
    assign nL = ~load;
    assign nS = ~shift;

    // Fuentes del SHIFT (MSB-first, shift-left: entra 0 por LSB)
    logic [7:0] sh;   // "valor desplazado"
    assign sh[7] = q[6];
    assign sh[6] = q[5];
    assign sh[5] = q[4];
    assign sh[4] = q[3];
    assign sh[3] = q[2];
    assign sh[2] = q[1];
    assign sh[1] = q[0];
    assign sh[0] = 1'b0;

    // Primer MUX por bit: selS = (shift ? sh : q) = (S&sh) | (~S&q)
    logic [7:0] selS;
    assign selS[0] = (shift & sh[0]) | (nS & q[0]);
    assign selS[1] = (shift & sh[1]) | (nS & q[1]);
    assign selS[2] = (shift & sh[2]) | (nS & q[2]);
    assign selS[3] = (shift & sh[3]) | (nS & q[3]);
    assign selS[4] = (shift & sh[4]) | (nS & q[4]);
    assign selS[5] = (shift & sh[5]) | (nS & q[5]);
    assign selS[6] = (shift & sh[6]) | (nS & q[6]);
    assign selS[7] = (shift & sh[7]) | (nS & q[7]);

    // Segundo MUX por bit: next_q = (load ? parallel_in : selS) = (L&pin) | (~L&selS)
    logic [7:0] next_q;
    assign next_q[0] = (load & parallel_in[0]) | (nL & selS[0]);
    assign next_q[1] = (load & parallel_in[1]) | (nL & selS[1]);
    assign next_q[2] = (load & parallel_in[2]) | (nL & selS[2]);
    assign next_q[3] = (load & parallel_in[3]) | (nL & selS[3]);
    assign next_q[4] = (load & parallel_in[4]) | (nL & selS[4]);
    assign next_q[5] = (load & parallel_in[5]) | (nL & selS[5]);
    assign next_q[6] = (load & parallel_in[6]) | (nL & selS[6]);
    assign next_q[7] = (load & parallel_in[7]) | (nL & selS[7]);

    // Serial_out: mismo esquema (hold/shift/load) pero con sus fuentes:
    //   hold -> serial_out
    //   shift -> q[6] (siguiente bit)
    //   load  -> parallel_in[7] (MSB)
    logic next_so;
    assign next_so = (load & parallel_in[7]) |
                     (nL & ((shift & q[6]) | (nS & serial_out)));

    // =========================
    // Flip-flops dffeas (ena=1)
    // Reset a 0x5A: 0101_1010  => q[7..0] = 0,1,0,1,1,0,1,0
    // Para reset a 1: usar PRN=rst_n; para reset a 0: CLRN=rst_n.
    // =========================

    // q[0] reset->0
    dffeas ff0(.q(q[0]), .d(next_q[0]), .clk(clk),
               .ena(1'b1), .clrn(rst_n), .prn(1'b1),
               .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    // q[1] reset->1
    dffeas ff1(.q(q[1]), .d(next_q[1]), .clk(clk),
               .ena(1'b1), .clrn(1'b1), .prn(rst_n),
               .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    // q[2] reset->0
    dffeas ff2(.q(q[2]), .d(next_q[2]), .clk(clk),
               .ena(1'b1), .clrn(rst_n), .prn(1'b1),
               .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    // q[3] reset->1
    dffeas ff3(.q(q[3]), .d(next_q[3]), .clk(clk),
               .ena(1'b1), .clrn(1'b1), .prn(rst_n),
               .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    // q[4] reset->1
    dffeas ff4(.q(q[4]), .d(next_q[4]), .clk(clk),
               .ena(1'b1), .clrn(1'b1), .prn(rst_n),
               .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    // q[5] reset->0
    dffeas ff5(.q(q[5]), .d(next_q[5]), .clk(clk),
               .ena(1'b1), .clrn(rst_n), .prn(1'b1),
               .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    // q[6] reset->1
    dffeas ff6(.q(q[6]), .d(next_q[6]), .clk(clk),
               .ena(1'b1), .clrn(1'b1), .prn(rst_n),
               .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    // q[7] reset->0
    dffeas ff7(.q(q[7]), .d(next_q[7]), .clk(clk),
               .ena(1'b1), .clrn(rst_n), .prn(1'b1),
               .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    // serial_out reset->1
    dffeas ffso(.q(serial_out), .d(next_so), .clk(clk),
                .ena(1'b1), .clrn(1'b1), .prn(rst_n),
                .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

endmodule
