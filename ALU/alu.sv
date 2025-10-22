// ============================================================
// ALU estructural (suma, resta = B-A-Cin, mult, div)

// ============================================================
module alu #(parameter WIDTH=4)(
  input  logic [WIDTH-1:0] A,
  input  logic [WIDTH-1:0] B,
  input  logic             boton0,
  input  logic             boton1, 
  input  logic             boton2,
  input  logic             boton3,
  input  logic             Cin,

  output logic [WIDTH-1:0] S,
  output logic             Cout,
  output logic             Z, N, V,
  output logic [6:0]       segments_units

);
  // -------- decodificación de operación (one-hot) --------
  wire wb0 = boton0;
  wire wb1 = boton1;
  wire wb2 = boton2;
  wire wb3 = boton3;

  wire sel_sum  =  wb3 &  wb2 &  wb1 & ~wb0; // 1110
  wire sel_rest =  wb3 &  wb2 & ~wb1 &  wb0; // 1101
  wire sel_mult =  wb3 &  wb2 & ~wb1 & ~wb0; // 1100
  wire sel_div  =  wb3 & ~wb2 &  wb1 &  wb0; // 1011

  // -------- SUMA --------
  logic [WIDTH-1:0] sum_S; logic sum_Cout;
  sumadorCompletoN #(.WIDTH(WIDTH)) u_sum (
    .A(A), .B(B), .Cin(Cin), .S(sum_S), .Cout(sum_Cout)
  );

  // -------- RESTA: B - A - Cin --------
  logic [WIDTH-1:0] rest_S; logic rest_borrow;
  restadorCompletoN #(.WIDTH(WIDTH)) u_res (
    .A(A), .B(B), .Cin(Cin), .S(rest_S), .Cout(rest_borrow)
  );

  // -------- MULT --------
  logic [WIDTH-1:0] mult_S; logic mult_overflow;
  multiplicadorCompletoN #(.WIDTH(WIDTH)) u_mul(
    .multiplicando(A), .multiplicador(B), .res(mult_S), .overflow(mult_overflow)
  );

  // -------- DIV --------
  logic [WIDTH-1:0] div_Q, div_R; logic divByZero;
  divisorCompletoN #(.WIDTH(WIDTH)) u_div(
    .A(A), .B(B), .Q(div_Q), .R(div_R), .divByZero(divByZero)
  );

  // -------- Selector por enmascarado + OR --------
  wire [WIDTH-1:0] m_sum = sum_S  & {WIDTH{sel_sum}};
  wire [WIDTH-1:0] m_res = rest_S & {WIDTH{sel_rest}};
  wire [WIDTH-1:0] m_mul = mult_S & {WIDTH{sel_mult}};
  wire [WIDTH-1:0] m_div = div_Q  & {WIDTH{sel_div}};
  assign S = m_sum | m_res | m_mul | m_div;

  // Cout/borrow solo en suma/resta
  assign Cout = (sum_Cout & sel_sum) | (rest_borrow & sel_rest);

  // -------- Flags --------
  assign N = S[WIDTH-1];

  // Z sin '==': OR-chain
  logic anyS;
  generate
    if (WIDTH==1) begin
      assign anyS = S[0];
    end else begin: G_ORZ
      logic [WIDTH-2:0] oz;
      assign oz[0] = S[0] | S[1];
      genvar zi;
      for (zi=2; zi<WIDTH; zi=zi+1) begin: GZ
        assign oz[zi-1] = oz[zi-2] | S[zi];
      end
      assign anyS = oz[WIDTH-2];
    end
  endgenerate
  assign Z = ~anyS;

  // Overflow: A+B y B-A (por orden de entrada del restador)
  wire Amsb    = A[WIDTH-1];
  wire Bmsb    = B[WIDTH-1];
  wire sum_msb = sum_S [WIDTH-1];
  wire res_msb = rest_S[WIDTH-1];
  wire V_add   = (~(Amsb ^ Bmsb)) & (Amsb ^ sum_msb);
  wire V_sub   =  (Bmsb ^ Amsb)  & (Bmsb ^ res_msb);
  wire V_mul   =  mult_overflow;
  wire V_div   =  1'b0;
  assign V = (V_add & sel_sum) | (V_sub & sel_rest) | (V_mul & sel_mult) | (V_div & sel_div);

  // -------- Display único HEX 0..F (S[3:0]) --------
  logic [6:0] seg_u_raw;
  hex7seg_struct u_hex (.hex(S[3:0]), .seg(seg_u_raw));

  assign segments_units = seg_u_raw;



endmodule
