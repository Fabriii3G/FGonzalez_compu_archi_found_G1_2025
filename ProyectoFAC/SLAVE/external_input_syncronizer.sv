// Receives an asyncronous input lasting at least one cycle.
// Outputs a signal lasting one cycle.
// Con only output again after the input has turned off and on again.
module external_input_syncronizer
(
    input  logic [3:0] async_in,
    input logic clk,
    input logic clrn,    // Active low means it must be on for the DFF (D Flip Flop) to work.
    output logic [15:0] sync_out
);

logic q0, q1;

dffeas flipflop0 (.q(q0), .d(async_in), .clk(clk), .ena(1'b1), .clrn(clrn), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));
dffeas flipflop1 (.q(q1), .d(q0), .clk(clk), .ena(1'b1), .clrn(clrn), .prn(1'b1), .asdata(1'b0), .sload(1'b0), .aload(1'b0));

assign sync_out = q0 & ~q1; // This makes the output last only one cycle even if async_in lasts longer.
endmodule
