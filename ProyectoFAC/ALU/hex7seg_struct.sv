// Entrada: hex[3:0]; Salida: seg[6:0] orden a..g, activo-alto (1=segmento encendido)
module hex7seg_struct(
    input  logic [3:0] hex,
    output logic [6:0] seg
);
    // One-hot comparadores
    wire h0  = ~(hex[3]|hex[2]|hex[1]|hex[0]);
    wire h1  = ~hex[3] & ~hex[2] & ~hex[1] &  hex[0];
    wire h2  = ~hex[3] & ~hex[2] &  hex[1] & ~hex[0];
    wire h3  = ~hex[3] & ~hex[2] &  hex[1] &  hex[0];
    wire h4  = ~hex[3] &  hex[2] & ~hex[1] & ~hex[0];
    wire h5  = ~hex[3] &  hex[2] & ~hex[1] &  hex[0];
    wire h6  = ~hex[3] &  hex[2] &  hex[1] & ~hex[0];
    wire h7  = ~hex[3] &  hex[2] &  hex[1] &  hex[0];
    wire h8  =  hex[3] & ~hex[2] & ~hex[1] & ~hex[0];
    wire h9  =  hex[3] & ~hex[2] & ~hex[1] &  hex[0];
    wire hA  =  hex[3] & ~hex[2] &  hex[1] & ~hex[0];
    wire hB  =  hex[3] & ~hex[2] &  hex[1] &  hex[0];
    wire hC  =  hex[3] &  hex[2] & ~hex[1] & ~hex[0];
    wire hD  =  hex[3] &  hex[2] & ~hex[1] &  hex[0];
    wire hE  =  hex[3] &  hex[2] &  hex[1] & ~hex[0];
    wire hF  =  hex[3] &  hex[2] &  hex[1] &  hex[0];

    // Tabla a..g (activo-alto) sin ?: (OR de constantes enmascaradas)
    // 0→ 1111110, 1→ 0110000, 2→ 1101101, 3→1111001, 4→0110011
    // 5→ 1011011, 6→ 1011111, 7→1110000, 8→1111111, 9→1111011
    // A→ 1110111, b→ 0011111, C→1001110, d→0111101, E→1001111, F→1000111
    assign seg =
      ({7{h0}} & 7'b1111110) | ({7{h1}} & 7'b0110000) |
      ({7{h2}} & 7'b1101101) | ({7{h3}} & 7'b1111001) |
      ({7{h4}} & 7'b0110011) | ({7{h5}} & 7'b1011011) |
      ({7{h6}} & 7'b1011111) | ({7{h7}} & 7'b1110000) |
      ({7{h8}} & 7'b1111111) | ({7{h9}} & 7'b1111011) |
      ({7{hA}} & 7'b1110111) | ({7{hB}} & 7'b0011111) |
      ({7{hC}} & 7'b1001110) | ({7{hD}} & 7'b0111101) |
      ({7{hE}} & 7'b1001111) | ({7{hF}} & 7'b1000111);
endmodule
