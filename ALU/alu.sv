module alu #(parameter WIDTH=4)(
    input  logic [WIDTH-1:0] A,
    input  logic [WIDTH-1:0] B,
    input  logic boton0,
    input  logic boton1, 
    input  logic boton2,
    input  logic boton3,
    input  logic Cin,
    
    output logic [WIDTH-1:0] S,        // Salida
    output logic Cout,
    output logic Z, N, V,
    output logic [6:0] segments_units,
    output logic [6:0] segments_tens
);

    // Botones en un vector de 4 bits para controlar las operaciones
    logic [3:0] botones;
    assign botones = {boton3, boton2, boton1, boton0};
    
    // Señales internas necesarias
    logic [WIDTH-1:0] sum_S, rest_S;
    logic sum_Cout, rest_Cout;
    logic [WIDTH-1:0] multiplicador_S;
    logic mult_overflow;

    // División (cociente/residuo)
    logic [WIDTH-1:0] div_Q;  // cociente
    logic [WIDTH-1:0] div_R;  // residuo (no mostrado, pero disponible)
    logic             divByZero;

    // 1) SUMA
    sumadorCompletoN #(.WIDTH(WIDTH)) u_sumador (
        .A(A), .B(B), .Cin(Cin),
        .S(sum_S), .Cout(sum_Cout)
    );

    // 2) RESTA
    restadorCompletoN #(.WIDTH(WIDTH)) u_restador (
        .A(A), .B(B), .Cin(Cin),
        .S(rest_S), .Cout(rest_Cout)
    );

    // 3) MULTIPLICACIÓN (tu módulo)
    multiplicadorCompletoN #(.WIDTH(WIDTH)) u_multiplicador (
        .multiplicando(A),
        .multiplicador(B),
        .res(multiplicador_S),
        .overflow(mult_overflow)
    );

    // 4) DIVISIÓN (estructural, sin / ni %)
    divisorCompletoN #(.WIDTH(WIDTH)) u_divisor (
        .A(A), .B(B),
        .Q(div_Q), .R(div_R),
        .divByZero(divByZero)
    );

    // Selector: SOLO 4 operaciones
    always_comb begin
        S     = {WIDTH{1'b0}};
        Cout  = 1'b0;
        V     = 1'b0;
        N     = 1'b0;
        Z     = 1'b0;

        case (botones)
          4'b1110: begin // SUMA
            S    = sum_S;
            Cout = sum_Cout;
            V    = 1'b0;
          end

          4'b1101: begin // RESTA
            S    = rest_S;
            Cout = rest_Cout;
            N    = (B < A);
            V    = 1'b0;
          end

          4'b1100: begin // MULT
            S    = multiplicador_S;
            Cout = 1'b0;
            V    = mult_overflow; // overflow del multiplicador
          end

          4'b1011: begin // DIV
            S    = div_Q;
            Cout = 1'b0;
            V    = 1'b0;
          end

          default: begin
            S    = {WIDTH{1'b0}};
            Cout = 1'b0;
            V    = 1'b0;
          end
        endcase

        // Flags finales
        Z = (S == {WIDTH{1'b0}});
    end


endmodule
