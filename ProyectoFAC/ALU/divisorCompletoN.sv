// ============================================================
// divisorCompletoN.sv
// División entera A/B (long division no-restaurativa)
// - Parametrizable: WIDTH (default 4)
// ============================================================

module divisorCompletoN #(parameter WIDTH=4)(
  input  logic [WIDTH-1:0] A,      // dividendo
  input  logic [WIDTH-1:0] B,      // divisor
  output logic [WIDTH-1:0] Q,      // cociente
  output logic [WIDTH-1:0] R,      // residuo
  output logic              divByZero
);
  // -------- detectar B == 0 SIN operador de reducción --------
  logic anyB;
  generate
    if (WIDTH == 1) begin
      assign anyB = B[0];
    end else begin : OR_CHAIN_B
      logic [WIDTH-2:0] orc;
      assign orc[0] = B[0] | B[1];
      genvar ob;
      for (ob = 2; ob < WIDTH; ob = ob + 1) begin : G_ORB
        assign orc[ob-1] = orc[ob-2] | B[ob];
      end
      assign anyB = orc[WIDTH-2];
    end
  endgenerate
  assign divByZero = ~anyB;

  // -------- restos parciales PR[0..WIDTH] --------
  logic [WIDTH-1:0] PR [0:WIDTH];
  assign PR[0] = '0;

  // -------- bits del cociente --------
  logic qbit [0:WIDTH-1];

  // -------- etapas MSB -> LSB --------
  genvar k;
  generate
    for (k = 0; k < WIDTH; k = k + 1) begin: STAGE
      localparam int IDX = WIDTH-1-k; // bit del dividendo en esta etapa (MSB->LSB)

      logic [WIDTH-1:0] PRsh;        // PR<<1 | A[IDX]
      logic [WIDTH-1:0] PRsh_minusB; // PRsh - B
      logic             borrow_cmp;  // borrow de la resta
      logic             ge;          // PRsh >= B  (borrow==0)

      // Desplazar e inyectar bit de A
      shl_in #(WIDTH) u_sh (.x(PR[k]), .inbit(A[IDX]), .y(PRsh));

      // restadorCompletoN: S = B(minuendo) - A(sustraendo) - Cin
      // Para PRsh - B: conectar A=B (sustraendo), B=PRsh (minuendo), Cin=0
      restadorCompletoN #(.WIDTH(WIDTH)) u_sub (
        .A   (B),         // sustraendo
        .B   (PRsh),      // minuendo
        .Cin (1'b0),
        .S   (PRsh_minusB),
        .Cout(borrow_cmp) // borrow final
      );

      assign ge = ~borrow_cmp; // borrow==0 -> PRsh >= B

      
      // Usamos tu mux2 (s=1 elige d1)
      mux2 #(.WIDTH(WIDTH)) u_mux_pr (
        .d0(PRsh), .d1(PRsh_minusB), .s(ge), .y(PR[k+1])
      );

      // qbit (evita cociente válido si B==0)
      assign qbit[IDX] = ge & ~divByZero;
    end
  endgenerate

  // -------- Ensamblar Q sin reducción --------
  genvar qi;
  generate
    for (qi = 0; qi < WIDTH; qi = qi + 1) begin : GQ
      assign Q[qi] = qbit[qi];
    end
  endgenerate

  // -------- R = PR[WIDTH] si B!=0, si B==0 -> 0 --------
  // s=~divByZero => si B!=0 (s=1) elige PR[WIDTH], si B==0 (s=0) elige 0
  mux2 #(.WIDTH(WIDTH)) u_mux_R (
    .d0('0), .d1(PR[WIDTH]), .s(~divByZero), .y(R)
  );

endmodule
