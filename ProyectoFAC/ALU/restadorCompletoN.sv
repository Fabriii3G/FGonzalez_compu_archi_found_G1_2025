// Restador N (WIDTH) bits parametrizable y combinacional
// Hace: B - A - Cin

module restadorCompletoN #(parameter WIDTH = 8) (
    input  logic [WIDTH-1:0] A,    // Sustraendo, vector pues depende de parametro
    input  logic [WIDTH-1:0] B,    // Minuendo
    input  logic Cin,              // Borrow inicial
    output logic [WIDTH-1:0] S,    // Diferencia
    output logic Cout              // Borrow final
);

    logic [WIDTH:0] aux; // vector auxiliar para poder pasar el Cout al Cin siguiente

    assign aux[0] = Cin; // Se asigna el primer auxiliar a Cin

    // Generación de N restadores de 1 bit
    genvar i; // define una variable i para poder iterar
    generate
        for (i = 0; i < WIDTH; i++) begin : loop //inicia el loop
            restadorCompleto1bit u_rest ( //u_rest es una instancia del restador completo de 1 bit
                .A   (A[i]),
                .B   (B[i]),
                .Cin (aux[i]), //se asigna el bit correspondiente al vector actual i 
                .S   (S[i]),
                .Cout(aux[i+1]) // +1 porque se necesita que el Cout sea el Cin del siguiente
            );
        end
    endgenerate

    assign Cout = aux[WIDTH]; // se asegura que el borrow final coincida con el ultimo aux

endmodule