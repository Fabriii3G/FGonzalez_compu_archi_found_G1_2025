// ============================================================================
// Registro de 4 bits con enable - ESTRUCTURAL (sin if/case/?/for)
// ============================================================================
module register_4bit (
    input  logic clk,
    input  logic rst_n,     // reset asíncrono activo en 0
    input  logic enable,    // carga cuando enable=1
    input  logic [3:0] data_in,
    output logic [3:0] data_out
);
    // Bit 0
    dffeas ff0(
        .q(data_out[0]), .d(data_in[0]), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(1'b0), .sload(1'b0)
    );

    // Bit 1
    dffeas ff1(
        .q(data_out[1]), .d(data_in[1]), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(1'b0), .sload(1'b0)
    );

    // Bit 2
    dffeas ff2(
        .q(data_out[2]), .d(data_in[2]), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(1'b0), .sload(1'b0)
    );

    // Bit 3
    dffeas ff3(
        .q(data_out[3]), .d(data_in[3]), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(1'b0), .sload(1'b0)
    );
endmodule
