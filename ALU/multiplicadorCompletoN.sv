// Multiplicación estructural 
module multiplicadorCompletoN #(parameter WIDTH=4)(
  input  logic [WIDTH-1:0] multiplicando,
  input  logic [WIDTH-1:0] multiplicador, 
  output logic [WIDTH-1:0] res,
  output logic             overflow
);
  logic [2*WIDTH-1:0] acc   [0:WIDTH];
  logic [2*WIDTH-1:0] addend[0:WIDTH-1];
  logic [2*WIDTH-1:0] sum_i [0:WIDTH-1];
  logic               cout_i[0:WIDTH-1];

  assign acc[0] = '0;

  genvar i;
  generate
    for (i=0;i<WIDTH;i++) begin: G
      // addend = multiplicando << i (zero-extend)
      assign addend[i] = {{WIDTH{1'b0}}, multiplicando} << i;

      // sum_i = acc[i] + addend[i]
      sumadorCompletoN #(.WIDTH(2*WIDTH)) u_add (
        .A(acc[i]), .B(addend[i]), .Cin(1'b0), .S(sum_i[i]), .Cout(cout_i[i])
      );

      // acc[i+1] = (multiplicador[i]) ? sum_i : acc[i]  ==> MUX por compuertas
      mux2 #(.WIDTH(2*WIDTH)) u_mux (
        .d0(acc[i]), .d1(sum_i[i]), .s(multiplicador[i]), .y(acc[i+1])
      );
    end
  endgenerate

  // resultado truncado (LOW WIDTH bits)
  assign res = acc[WIDTH][WIDTH-1:0];

  // overflow = OR de los bits altos (2*WIDTH-1 : WIDTH) sin reducción
  logic any_high;
  generate
    if (WIDTH==1) begin
      assign any_high = acc[WIDTH][2*WIDTH-1];
    end else begin: G_ORH
      localparam int HBW = WIDTH;
      logic [HBW-2:0] oh;
      // vector de bits altos
      wire [HBW-1:0] highs = acc[WIDTH][2*WIDTH-1:WIDTH];
      assign oh[0] = highs[0] | highs[1];
      genvar hi;
      for (hi=2; hi<HBW; hi=hi+1) begin: GH
        assign oh[hi-1] = oh[hi-2] | highs[hi];
      end
      assign any_high = oh[HBW-2];
    end
  endgenerate

  assign overflow = any_high;
endmodule
