// ============================================================================
// Registro de 8 bits con enable - ESTRUCTURAL (sin if/case/?/for)
// ============================================================================
module register_8bit (
    input  logic clk,
    input  logic rst_n,      // reset asíncrono activo en 0
    input  logic enable,     // carga cuando enable=1
    input  logic [7:0] data_in,
    output logic [7:0] data_out
);
    // FF bit 0
    dffeas ff0(
        .q(data_out[0]), .d(data_in[0]), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(1'b0), .sload(1'b0)
    );

    // FF bit 1
    dffeas ff1(
        .q(data_out[1]), .d(data_in[1]), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(1'b0), .sload(1'b0)
    );

    // FF bit 2
    dffeas ff2(
        .q(data_out[2]), .d(data_in[2]), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(1'b0), .sload(1'b0)
    );

    // FF bit 3
    dffeas ff3(
        .q(data_out[3]), .d(data_in[3]), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(1'b0), .sload(1'b0)
    );

    // FF bit 4
    dffeas ff4(
        .q(data_out[4]), .d(data_in[4]), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(1'b0), .sload(1'b0)
    );

    // FF bit 5
    dffeas ff5(
        .q(data_out[5]), .d(data_in[5]), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(1'b0), .sload(1'b0)
    );

    // FF bit 6
    dffeas ff6(
        .q(data_out[6]), .d(data_in[6]), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(1'b0), .sload(1'b0)
    );

    // FF bit 7
    dffeas ff7(
        .q(data_out[7]), .d(data_in[7]), .clk(clk),
        .ena(enable), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0),
        .sclr(1'b0), .sload(1'b0)
    );

endmodule
