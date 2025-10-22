// Decodificador HEX -> 7 segmentos (activo-alto)
// Salida seg[6:0] = {a,b,c,d,e,f,g}
module hex7seg_struct(
  input  logic [3:0] hex,     // {h3 h2 h1 h0}
  output logic [6:0] seg      // {a,b,c,d,e,f,g}
);
  wire h3=hex[3], h2=hex[2], h1=hex[1], h0=hex[0];
  wire n3=~h3,    n2=~h2,    n1=~h1,    n0=~h0;

  // Minterminos 0..15 (one-hot)
  wire m0  = n3 & n2 & n1 & n0;
  wire m1  = n3 & n2 & n1 & h0;
  wire m2  = n3 & n2 & h1 & n0;
  wire m3  = n3 & n2 & h1 & h0;
  wire m4  = n3 & h2 & n1 & n0;
  wire m5  = n3 & h2 & n1 & h0;
  wire m6  = n3 & h2 & h1 & n0;
  wire m7  = n3 & h2 & h1 & h0;
  wire m8  = h3 & n2 & n1 & n0;
  wire m9  = h3 & n2 & n1 & h0;
  wire m10 = h3 & n2 & h1 & n0;
  wire m11 = h3 & n2 & h1 & h0;
  wire m12 = h3 & h2 & n1 & n0;
  wire m13 = h3 & h2 & n1 & h0;
  wire m14 = h3 & h2 & h1 & n0;
  wire m15 = h3 & h2 & h1 & h0;

  // Segmentos activos (a..g) para 0..F (común cátodo, activo-alto)
  wire a = m0 | m2 | m3 | m5 | m6 | m7 | m8 | m9 | m10 | m12 | m14 | m15;
  wire b = m0 | m1 | m2 | m3 | m4 | m7 | m8 | m9 | m10 | m13;
  wire c = m0 | m1 | m3 | m4 | m5 | m6 | m7 | m8 | m9 | m10 | m11 | m13;
  wire d = m0 | m2 | m3 | m5 | m6 | m8 | m9 | m11 | m12 | m13 | m14;
  wire e = m0 | m2 | m6 | m8 | m10 | m11 | m12 | m13 | m14 | m15;
  wire f = m0 | m4 | m5 | m6 | m8 | m9 | m10 | m11 | m12 | m14 | m15;
  wire g =       m2 | m3 | m4 | m5 | m6 | m8 | m9 | m10 | m11 | m13 | m14 | m15;

  assign seg = {a,b,c,d,e,f,g};
endmodule
