module multiplicadorCompletoN #(parameter WIDTH=4)(
    input  logic [WIDTH-1:0] multiplicando,
    input  logic [WIDTH-1:0] multiplicador, 
    output logic [WIDTH-1:0] res,
	 output logic overflow
);

    logic [2*WIDTH-1:0] res_parcial [0:WIDTH];
    logic [2*WIDTH-1:0] mult_desplazado [0:WIDTH-1];
    logic [2*WIDTH-1:0] suma_res [0:WIDTH-1];
    logic cout [0:WIDTH-1];

    // inicialización
    assign res_parcial[0] = '0;

    genvar i;
    generate
        for(i=0; i < WIDTH; i++) begin : loop
            assign mult_desplazado[i] = {{WIDTH{1'b0}}, multiplicando} << i;

            sumadorCompletoN #(.WIDTH(2*WIDTH)) sumador (
                .A(res_parcial[i]),
                .B(mult_desplazado[i]),
                .Cin(1'b0),
                .S(suma_res[i]),
                .Cout(cout[i])
            );

            assign res_parcial[i+1] = multiplicador[i] ? suma_res[i] : res_parcial[i];
        end
    endgenerate
    assign res = res_parcial[WIDTH];
	 assign overflow = |res_parcial[WIDTH][2*WIDTH-1:WIDTH];// OR de bits altos
endmodule