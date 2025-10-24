// ============================================================================
// FSM SPI (estructural, sin if/case/?), estados: IDLE=00, TRANSFER=01, PROCESS=10
// ============================================================================
module spi_fsm (
    input  logic clk,
    input  logic rst_n,        // reset asincrono activo en 0
    input  logic cs_active,
    input  logic bit_count_7,
    input  logic sck_rising,
    output logic state_idle,
    output logic state_transfer,
    output logic state_process
);
    // FFs de estado (q1 q0)
    logic q1, q0;      // estado actual
    logic nq1, nq0;    // siguiente estado

    // Señal auxiliar: fin de byte en flanco de SCK
    logic t;
    assign t = bit_count_7 & sck_rising;

    // === Lógica de siguiente estado (solo compuertas) ===
    // nq1 = 1 solo cuando: estado=01 (q1=0,q0=1) y cs=1 y t=1  -> PROCESS (10)
    assign nq1 = (~q1) & q0 & cs_active & t;

    // nq0 = 1 cuando:
    //   - desde IDLE(00) con cs=1 -> TRANSFER(01)
    //   - desde TRANSFER(01) con cs=1 y NO(t) -> permanecer en TRANSFER(01)
    // Fórmula minimizada: nq0 = (~q1 & cs) & ( ~q0 | ~t )
    assign nq0 = (~q1) & cs_active & ( (~q0) | (~t) );

    // === Flip-flops de estado (dffeas) ===
    dffeas ff_q1(
        .q(q1), .d(nq1), .clk(clk),
        .ena(1'b1), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0)
    );

    dffeas ff_q0(
        .q(q0), .d(nq0), .clk(clk),
        .ena(1'b1), .clrn(rst_n), .prn(1'b1),
        .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0)
    );

    // === Decodificación Moore de salidas (solo compuertas) ===
    assign state_idle     = (~q1) & (~q0); // 00
    assign state_transfer = (~q1) &  q0;   // 01
    assign state_process  =  q1  & (~q0);  // 10

    // Nota: estado 11 es no usado; con estas ecuaciones converge a 00 (IDLE).
endmodule
