// Sumador completo 1 bit System Verilog

// A + B + C

module sumadorCompleto1bit (
    input  logic A,    // Suma
    input  logic B,    // Suma
    input  logic Cin,  // Acarreo
    output logic S,    // Resultado
    output logic Cout  // Acarreo de salida
);

	// Salida S: (A xor B) xor C

	assign S = (A ^ B) ^ Cin;
	
	// Salida Cout: (A and B) or (Cin and (A or B))
	
	assign Cout = (A & B) | ( Cin & (A | B));
	
endmodule



