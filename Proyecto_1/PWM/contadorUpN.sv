// Contador ascendente por sumador + registro
module contadorUpN #(parameter WIDTH=11)(
  input  logic               clk,
  output logic [WIDTH-1:0]   q
);
  logic [WIDTH-1:0] next;
  logic dummy_cout;

  // next = q + 1
  sumadorCompletoN #(.WIDTH(WIDTH)) u_add (
    .A(q),
    .B({{WIDTH-1{1'b0}},1'b1}),
    .Cin(1'b0),
    .S(next),
    .Cout(dummy_cout)
  );

  registroN #(.WIDTH(WIDTH)) u_reg (.clk(clk), .d(next), .q(q));
endmodule
