// Multiplexor de 4 entradas

module mux4 #(parameter WIDTH = 4)(
	input logic [WIDTH-1:0] d0, d1, d2, d3,
	input logic [1:0] s, // es un vector de 2 bits.
		// El primer bit trabaja los mux low y high, y el segundo el final
	output logic [WIDTH-1:0] y
);

	logic [WIDTH-1:0] low, high; // auxiliares para llevar los bits al finalmux

	mux2 lowmux(d0, d1, s[0], low); // si s es 0, pasa d0, si es 1 pasa d1
	mux2 highmux(d2, d3, s[0], high); // si s es 0, pasa d2, si es 1 pasa d3
	mux2 finalmux(low, high, s[1], y); // si s es 0, pasa low, si es 1 pasa high
	// el mux final elige entre d0 y d2 o entre d1 y d3
	
endmodule