// Comparador estricto x < y usando restador con Cin=1 
module cmp_lt_strict #(parameter WIDTH=4)(
  input  logic [WIDTH-1:0] x, // phase
  input  logic [WIDTH-1:0] y, // duty
  output logic             lt // 1 si x < y
);
  logic [WIDTH-1:0] dummy;
  logic borrow;
  // y - x - 1 -> borrow=1 si y <= x  => lt = ~borrow
  restadorCompletoN #(.WIDTH(WIDTH)) u (
    .A(x), .B(y), .Cin(1'b1), .S(dummy), .Cout(borrow)
  );
  assign lt = ~borrow;
endmodule
