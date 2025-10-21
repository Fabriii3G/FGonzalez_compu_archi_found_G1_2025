module alu #(parameter WIDTH=4)(
    input  logic [WIDTH-1:0] A,
    input  logic [WIDTH-1:0] B,
    input  logic boton0,
    input  logic boton1, 
    input  logic boton2,
    input  logic boton3,
    input  logic Cin,
    
    output logic [WIDTH-1:0] S,        // Salida siempre de 4 bits
    output logic Cout,
    output logic Z, N, V,
    output logic [6:0] segments_units,
    output logic [6:0] segments_tens
);

    // Botones en un vector de 4 bits para controlar las operaciones
    logic [3:0] botones;
    assign botones = {boton3, boton2, boton1, boton0};
    
    // Señales internas (para que todo no esté manejado al mismo S)
    logic [WIDTH-1:0] sum_S, rest_S, div_S, mod_S;
    logic [WIDTH-1:0] multiplicador_S;
    logic sum_Cout, rest_Cout, shiftL_Cout, shiftR_Cout, mult_overflow;
    logic [WIDTH-1:0] and_S, or_S, xor_S;
    logic [WIDTH-1:0] shiftL_S, shiftR_S;
    
    // Señales para detectar overflow
    logic [2*WIDTH-1:0] res_multiplicacion; // Para capturar resultado completo de multiplicación
    
    logic [3:0] units_digit;
    logic [3:0] tens_digit;

    // 1. Sumador parametrizable
    sumadorCompletoN #(.WIDTH(WIDTH)) u_sumador (
        .A(A),
        .B(B),
        .Cin(Cin),
        .S(sum_S),
        .Cout(sum_Cout)
    );

    // 2. Restador parametrizable
    restadorCompletoN #(.WIDTH(WIDTH)) u_restador (
        .A(A),
        .B(B),
        .Cin(Cin),
        .S(rest_S),
        .Cout(rest_Cout)
    );
    
    // 3. Multiplicador parametrizable
    multiplicadorCompletoN #(.WIDTH(WIDTH)) u_multiplicador (
        .multiplicando(A),
        .multiplicador(B),
        .res(res_multiplicacion),
		  .overflow(mult_overflow)
    );
    
    // Tomar solo los 4 bits bajos del resultado de multiplicación
    assign multiplicador_S = res_multiplicacion[WIDTH-1:0];
    
    // 4. División parametrizable
    always_comb begin
        if (B != 0) begin
            div_S = A / B;
        end else begin
            div_S = {WIDTH{1'b1}}; // Valor de error para división por cero
        end
    end
    
    // 5. Módulo parametrizable
    always_comb begin
        if (B != 0) begin
            mod_S = A % B;
        end else begin
            mod_S = {WIDTH{1'b0}}; // Valor de error para módulo por cero
        end
    end
    
    // 6. Operaciones lógicas AND, OR, XOR
    assign and_S = A & B; // AND
    assign or_S = A | B;  // OR
    assign xor_S = A ^ B; // XOR
    
    // 7. Shift left y right
    assign shiftL_S = A << 1;     // Left
    assign shiftR_S = A >> 1;     // Right
    assign shiftL_Cout = A[WIDTH-1]; // Left Cout
    assign shiftR_Cout = A[0];       // Right Cout
    
    // 8. Case para elegir opciones
    always_comb begin
			S     = {WIDTH{1'b0}};
			Cout  = 1'b0;
			V     = 1'b0;
			N     = 1'b0;
			Z     = 1'b0;


        case(botones)
            4'b1110: begin // suma
                S = sum_S;  
                Cout = sum_Cout;
					 V = 1'b0;
            end
				
				4'b1101: begin // resta
					S = rest_S; 
					Cout = rest_Cout; 
					// N solo vale 1 cuando B < A 
					N = (B < A);
					V = 1'b0;
				end

            
            4'b1100: begin // mult
                S = multiplicador_S;
                Cout = 1'b0;
                 V = mult_overflow;
            end
            
            4'b1011: begin // division
                S = div_S;
                Cout = 1'b0;
                V = 1'b0;
            end
            
            4'b1010: begin // modulo
                S = mod_S;
                Cout = 1'b0;
                V = 1'b0;
            end
            
            4'b1001: begin // and
                S = and_S;
                Cout = 1'b0;
                V = 1'b0;
            end
            
            4'b1000: begin // or
                S = or_S;
                Cout = 1'b0;
                V = 1'b0;
            end
            
            4'b0111: begin // xor
                S = xor_S;
                Cout = 1'b0;
                V = 1'b0;
            end
            
            4'b0110: begin // shift L
                S = shiftL_S; 
                Cout = shiftL_Cout;
                V = 1'b0;
            end
            
            4'b0101: begin // shift R
                S = shiftR_S; 
                Cout = shiftR_Cout;
                V = 1'b0;
            end
            
            default: begin
                S = {WIDTH{1'b0}};
                Cout = 1'b0;
                V = 1'b0;
            end
        endcase
		  
		      // 11. Flags de estado
		Z = (S == {WIDTH{1'b0}}); // zero flag

		  
    end
    
    // 9. Conversión para display de 7 segmentos
    always_comb begin
        if (S < 10) begin
            tens_digit = 4'b0000;
            units_digit = S[3:0];
        end else if (S < 20) begin
            tens_digit = 4'b0001;
            units_digit = S - 10;
        end else if (S < 30) begin
            tens_digit = 4'b0010;
            units_digit = S - 20;
        end else if (S < 40) begin
            tens_digit = 4'b0011;
            units_digit = S - 30;
        end else if (S < 50) begin
            tens_digit = 4'b0100;
            units_digit = S - 40;
        end else if (S < 60) begin
            tens_digit = 4'b0101;
            units_digit = S - 50;
        end else begin // 60-63 para WIDTH=4
            tens_digit = 4'b0110;
            units_digit = S - 60;
        end
    end
    
    // 10. Instanciación de decodificadores de 7 segmentos
    decoder_segmentos display_decenas (
        .data(tens_digit),
        .segments(segments_tens)
    );
    
    decoder_segmentos display_unidades (
        .data(units_digit),
        .segments(segments_units)
    );
  

endmodule