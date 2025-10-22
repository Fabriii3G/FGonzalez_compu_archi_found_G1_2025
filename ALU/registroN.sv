// Registro N bits (vector de FFs)
module registroN #(parameter WIDTH=8)(
  input  logic                clk,
  input  logic [WIDTH-1:0]    d,
  output logic [WIDTH-1:0]    q
);
  genvar i;
  generate
    for (i=0; i<WIDTH; i++) begin: GFF
      dff1 u_ff(.clk(clk), .d(d[i]), .q(q[i]));
    end
  endgenerate
endmodule
