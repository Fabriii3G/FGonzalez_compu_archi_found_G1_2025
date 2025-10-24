module shl_in #(parameter WIDTH=4)(
  input  logic [WIDTH-1:0] x,
  input  logic             inbit,
  output logic [WIDTH-1:0] y
);
  // PR_next = (x << 1) | inbit   (cableado)
  assign y = {x[WIDTH-2:0], inbit};
endmodule