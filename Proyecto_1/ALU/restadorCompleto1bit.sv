// Restador completo 1 bit System Verilog

// Realiza B - A - Cin

module restadorCompleto1bit (
    input  logic A,    // Sustraendo
    input  logic B,    // Minuendo
    input  logic Cin,  // Acarreo/Préstamo de entrada
    output logic S,    // Diferencia
    output logic Cout  // Acarreo/Préstamo de salida
);

    // Salida S: (B xor A) xor Cin
    assign S = (B ^ A) ^ Cin;

    // Salida Cout: (Cin and not(B)) or (Cin and A) or (not(B) and A)
    assign Cout = (Cin & ~B) | (Cin & A) | (~B & A);

endmodule