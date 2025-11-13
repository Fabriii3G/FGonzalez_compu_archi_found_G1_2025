// Flip-flop D 1 bit (registro)
module dff1(
  input  logic clk,
  input  logic d,
  output logic q
);
  always_ff @(posedge clk) q <= d;
endmodule
