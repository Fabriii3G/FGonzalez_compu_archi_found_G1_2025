// MUX 2:1 N bits (s=0 -> d0, s=1 -> d1) 
module mux2 #(parameter WIDTH = 4) (
  input  logic [WIDTH-1:0] d0, d1,
  input  logic             s,
  output logic [WIDTH-1:0] y
);
  wire [WIDTH-1:0] S  = {WIDTH{s}};
  wire [WIDTH-1:0] nS = ~S;
  assign y = (d0 & nS) | (d1 & S);
endmodule
