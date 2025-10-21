`timescale 1ns/1ps

module alu_tb;

    parameter WIDTH = 4;

    // Entradas a probar
	 
    logic [WIDTH-1:0] A, B;
    logic boton0, boton1, boton2, boton3;
	 logic Cin;

    // Salidas
    logic [WIDTH-1:0] S;
	 logic [2*WIDTH-1:0]res;
    logic Cout; //Carry
	 logic Z; //Zero
	 logic N; //Negativo
	 logic V; // Overflow

    // Instancia de la ALU
    alu #(.WIDTH(WIDTH)) dut (
        .A(A),
        .B(B),
		  
        .boton0(boton0),
		  .boton1(boton1),
		  .boton2(boton2),
		  .boton3(boton3),
  
        .Cin(Cin),
        .S(S),
        .Cout(Cout),
		  .Z(Z),
		  .N(N),
		  .V(V)

    );

    // Proceso de prueba
    initial begin

        // Caso 1.1: Suma (3 + 6)
        A = 4'b0011; B = 4'b0110; Cin = 0;
		  boton3 = 1; boton2 = 1; boton1 = 1; boton0 = 0; #10;
		  assert (S === 4'b1001) else $error("suma 3 + 6 failed");
		  assert (Cout === 0) else $error("carry 3+6 failed");
		  assert (Z === 0) else $error("zero 3 + 6 failed");
		  
        
        // Caso 1.2: Suma con carry (15 + 1)
        A = 4'b1111; B = 4'b0001; Cin = 0;
		  boton3 = 1; boton2 = 1; boton1 = 1; boton0 = 0; #10;
		  assert (S === 4'b0000) else $error("suma 15 + 1 failed");
		  assert (Cout === 1) else $error("carry 15 + 1 failed");
		  assert (Z === 1) else $error("zero 15 + 1 failed");
		  
		  // ------------------------------------------------------
        

        // Caso 2.1: Resta (5 - 8) pues es B - A
        A = 4'b1000; B = 4'b0101; Cin = 0;
		  boton3 = 1; boton2 = 1; boton1 = 0; boton0 = 1; #10;
		  assert (S === 4'b1101) else $error("resta 5 - 8 failed");
		  assert (Cout === 1) else $error("carry 5 - 8 failed");
		  assert (N === 1) else $error("resta negativa failed");
        

        // Caso 2.2: Resta con resultado positivo (10 - 3)
        A = 4'b0011; B = 4'b1010; Cin = 0;
        boton3 = 1; boton2 = 1; boton1 = 0; boton0 = 1; #10;
		  assert (S === 4'b0111) else $error("resta 10 - 3 failed");
		  assert (Cout === 0) else $error("carry 10 - 3 failed");
		  assert (N === 0) else $error("resta positiva failed");
		  
		  // ---------------------------------------------------------
		  
		  // Caso 3.1 Multiplicacion 3x5
        A = 4'b0011; B = 4'b0101; Cin = 0;
        boton3 = 1; boton2 = 1; boton1 = 0; boton0 = 0; #10;
		  assert (S === 4'b1111) else $error("3 x 5 failed");
		  assert (V === 0) else $error("no debio haber overflow");
		  
		  // Caso 3.2 Multiplicacion 5x5
		  A = 4'b0101; B = 4'b0101; Cin = 0;
        boton3 = 1; boton2 = 1; boton1 = 0; boton0 = 0; #10;
		  assert (S === 4'b1001) else $error("5 x 5 failed");
		  assert (V === 1) else $error("debio haber overflow");
		  
		  // ----------------------------------------------------------
		  
		  // Caso 4.1: Division entera (6 / 2)
        A = 4'b0110; B = 4'b0010; Cin = 0;
        boton3 = 1; boton2 = 0; boton1 = 1; boton0 = 1; #10;
		  assert (S === 4'b0011) else $error("division entera failed");
		  
		  // Caso 4.2: Division decimal y menor (3 / 10)
        A = 4'b0011; B = 4'b1010; Cin = 0;
        boton3 = 1; boton2 = 0; boton1 = 1; boton0 = 1; #10;
		  assert (S === 4'b0000) else $error("division decimal failed");
		  
		  // ------------------------------------------------------------
		  
		  // Caso 5.1: Modulo entera (6 % 3)
        A = 4'b0110; B = 4'b0010; Cin = 0;
        boton3 = 1; boton2 = 0; boton1 = 1; boton0 = 0; #10;
		  assert (S === 4'b0000) else $error("modulo entero failed");
		  
		  // Caso 5.2: Modulo decimal y menor (3 % 10)
        A = 4'b0011; B = 4'b1010; Cin = 0;
        boton3 = 1; boton2 = 0; boton1 = 1; boton0 = 0; #10;
		  assert (S === 4'b0011) else $error("modulo decimal failed");
		  
		  // --------------------------------------------------------------
		  
		  // Caso 6.1: AND simple
        A = 4'b0110; B = 4'b0110; Cin = 0;
        boton3 = 1; boton2 = 0; boton1 = 0; boton0 = 1; #10;
		  assert (S === 4'b0110) else $error("AND simple failed");
		  
		  // Caso 6.2: AND mezclado
        A = 4'b0101; B = 4'b1010; Cin = 0;
        boton3 = 1; boton2 = 0; boton1 = 0; boton0 = 1; #10;
		  assert (S === 4'b0000) else $error("AND mezclado failed");
		  
		  // -------------------------------------------------------------
		  
		  // Caso 7.1: OR simple
        A = 4'b0110; B = 4'b0110; Cin = 0;
        boton3 = 1; boton2 = 0; boton1 = 0; boton0 = 0; #10;
		  assert (S === 4'b0110) else $error("OR simple failed");
		  
		  // Caso 7.2: OR mezclado
        A = 4'b0101; B = 4'b1010; Cin = 0;
        boton3 = 1; boton2 = 0; boton1 = 0; boton0 = 0; #10;
		  assert (S === 4'b1111) else $error("OR mezclado failed");
		  
		  // -------------------------------------------------------------
		  
		  // Caso 8.1: XOR simple
        A = 4'b0110; B = 4'b0110; Cin = 0;
        boton3 = 0; boton2 = 1; boton1 = 1; boton0 = 1; #10;
		  assert (S === 4'b0000) else $error("XOR simple failed");
		  
		  // Caso 8.2: XOR mezclado
        A = 4'b0101; B = 4'b1010; Cin = 0;
        boton3 = 0; boton2 = 1; boton1 = 1; boton0 = 1; #10;
		  assert (S === 4'b1111) else $error("XOR mezclado failed");
		  
		  // -------------------------------------------------------------
		  
		  // Caso 9.1: Shift L simple
        A = 4'b0110; B = 4'b0000; Cin = 0;
        boton3 = 0; boton2 = 1; boton1 = 1; boton0 = 0; #10;
		  assert (S === 4'b1100) else $error("shiftL simple failed");
		  assert (Cout === 0) else $error("carry 0 failed");
		  
		  // Caso 9.2: Shift L desborda
        A = 4'b1010; B = 4'b0000; Cin = 0;
        boton3 = 0; boton2 = 1; boton1 = 1; boton0 = 0; #10;
		  assert (S === 4'b0100) else $error("shiftL desborda failed");
		  assert (Cout === 1) else $error("carry 1 failed");
		  
		  // -------------------------------------------------------------
		  
		  // Caso 10.1: Shift R simple
        A = 4'b0110; B = 4'b0000; Cin = 0;
        boton3 = 0; boton2 = 1; boton1 = 0; boton0 = 1; #10;
		  assert (S === 4'b0011) else $error("shiftL simple failed");
		  assert (Cout === 0) else $error("carry L 0 failed");
		  
		  // Caso 10.2: Shift R desborda
        A = 4'b0101; B = 4'b0000; Cin = 0;
        boton3 = 0; boton2 = 1; boton1 = 0; boton0 = 1; #10;
		  assert (S === 4'b0010) else $error("shiftR desborda failed");
		  assert (Cout === 1) else $error("carry R 1 failed");
		  
		  
		  
		  
		  
    end

endmodule