module shift_register_nibble (
    input  logic clk,
    input  logic rst_n,       // reset asíncrono activo en 0
    input  logic enable,
    input  logic serial_in,
    output logic [3:0] parallel_out
);
    logic q0, q1, q2, q3;

    // dffeas: puertos (orden común) -> q, d, clk, ena, clrn, prn, asdata, sload, aload
    dffeas ff0 (.q(q0), .d(serial_in), .clk(clk), .ena(enable), .clrn(rst_n), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));
    dffeas ff1 (.q(q1), .d(q0),       .clk(clk), .ena(enable), .clrn(rst_n), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));
    dffeas ff2 (.q(q2), .d(q1),       .clk(clk), .ena(enable), .clrn(rst_n), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));
    dffeas ff3 (.q(q3), .d(q2),       .clk(clk), .ena(enable), .clrn(rst_n), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));
    
    assign parallel_out = {q3, q2, q1, q0};
endmodule
