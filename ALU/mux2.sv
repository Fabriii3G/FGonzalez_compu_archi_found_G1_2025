// Multiplexor para seleccionar señales

module mux2 #(parameter WIDTH = 4) (
	
	input logic [WIDTH-1:0] d0,
	input logic [WIDTH-1:0] d1,
	input logic s,
	
	output logic [WIDTH-1:0] y
	);
	
	assign y = s ? d0:d1; // si s = 0, y = do
	
	// podria hacerse con compuertas logicas...
	
endmodule