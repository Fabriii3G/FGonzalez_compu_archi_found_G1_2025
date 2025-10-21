`timescale 1ns/1ps

module alu_tb;

  localparam int WIDTH = 4;

  // Entradas
  logic [WIDTH-1:0] A, B;
  logic boton0, boton1, boton2, boton3;
  logic Cin;

  // Salidas
  logic [WIDTH-1:0] S;
  logic Cout, Z, N, V;
  logic [6:0] segments_units; // solo para conectar el DUT (no se usan)
  logic [6:0] segments_tens;  // solo para conectar el DUT (no se usan)

  // DUT
  alu #(.WIDTH(WIDTH)) dut (
    .A(A), .B(B),
    .boton0(boton0), .boton1(boton1), .boton2(boton2), .boton3(boton3),
    .Cin(Cin),
    .S(S), .Cout(Cout), .Z(Z), .N(N), .V(V),
    .segments_units(segments_units), .segments_tens(segments_tens)
  );

  // Helpers para poner el opcode de botones
  task automatic set_op_suma(); begin    boton3=1; boton2=1; boton1=1; boton0=0; end endtask // 1110
  task automatic set_op_resta(); begin   boton3=1; boton2=1; boton1=0; boton0=1; end endtask // 1101
  task automatic set_op_mult(); begin    boton3=1; boton2=1; boton1=0; boton0=0; end endtask // 1100
  task automatic set_op_div(); begin     boton3=1; boton2=0; boton1=1; boton0=1; end endtask // 1011

  initial begin
    // Defaults
    A=0; B=0; Cin=0; boton0=0; boton1=0; boton2=0; boton3=0;
    #5;

    // ---------------- SUMA ----------------
    // 3 + 6 = 9, Cout=0
    A=4'd3; B=4'd6; Cin=0; set_op_suma(); #10;
    assert(S===4'd9) else $error("SUMA 3+6 -> S=%0d, esp=9", S);
    assert(Cout===1'b0) else $error("SUMA 3+6 Cout esp=0");
    assert(Z===1'b0) else $error("SUMA 3+6 Z esp=0");

    // 15 + 1 = 0 (mod 16), Cout=1
    A=4'd15; B=4'd1; Cin=0; set_op_suma(); #10;
    assert(S===4'd0) else $error("SUMA 15+1 -> S=%0d, esp=0", S);
    assert(Cout===1'b1) else $error("SUMA 15+1 Cout esp=1");
    assert(Z===1'b1) else $error("SUMA 15+1 Z esp=1");

    // ---------------- RESTA ----------------
    // Nota: tu restador hace B - A - Cin.
    // Caso: (5 - 8) => con A=8, B=5 => resultado = 13 (1101), N=1 (porque B<A)
    A=4'd8; B=4'd5; Cin=0; set_op_resta(); #10;
    assert(S===4'd13) else $error("RESTA 5-8 -> S=%0d, esp=13", S);
    assert(N===1'b1) else $error("RESTA 5-8 N esp=1");

    // Caso: (10 - 3) => A=3, B=10 => 7, N=0
    A=4'd3; B=4'd10; Cin=0; set_op_resta(); #10;
    assert(S===4'd7) else $error("RESTA 10-3 -> S=%0d, esp=7", S);
    assert(N===1'b0) else $error("RESTA 10-3 N esp=0");

    // ---------------- MULT ----------------
    // 3 * 5 = 15, sin overflow (depende de tu multiplicador: V=0 esperado)
    A=4'd3; B=4'd5; set_op_mult(); #10;
    assert(S===4'd15) else $error("MULT 3*5 -> S=%0d, esp=15", S);
    assert(V===1'b0) else $error("MULT 3*5 V esp=0");

    // 5 * 5 = 25 -> 25 mod 16 = 9 (1001), overflow=1
    A=4'd5; B=4'd5; set_op_mult(); #10;
    assert(S===4'd9) else $error("MULT 5*5 -> S=%0d, esp=9", S);
    assert(V===1'b1) else $error("MULT 5*5 V esp=1");

    // ---------------- DIV ----------------
    // 6 / 2 = 3
    A=4'd6; B=4'd2; set_op_div(); #10;
    assert(S===4'd3) else $error("DIV 6/2 -> S=%0d, esp=3", S);

    // 3 / 10 = 0 (A<B)
    A=4'd3; B=4'd10; set_op_div(); #10;
    assert(S===4'd0) else $error("DIV 3/10 -> S=%0d, esp=0", S);

    // 7 / 3 = 2 (truncado)
    A=4'd7; B=4'd3; set_op_div(); #10;
    assert(S===4'd2) else $error("DIV 7/3 -> S=%0d, esp=2", S);

    // 15 / 2 = 7
    A=4'd15; B=4'd2; set_op_div(); #10;
    assert(S===4'd7) else $error("DIV 15/2 -> S=%0d, esp=7", S);

    // B = 0 -> nuestro divisor entrega Q=0 (y levanta flag interno divByZero)
    A=4'd5; B=4'd0; set_op_div(); #10;
    assert(S===4'd0) else $error("DIV 5/0 -> S=%0d, esp=0", S);

    $display(">> PRUEBAS COMPLETADAS OK");
    $finish;
  end

endmodule
