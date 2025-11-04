// ============================================================================
// D-FF 1 bit con clear asíncrono activo en 0 (Intel 'dffeas')
// ============================================================================
module dff_aclr_n_intel (
    input  logic clk,
    input  logic rst_n,   // clear_n
    input  logic d,
    output logic q
);
    // dffeas: q, d, clk, ena, clrn, prn, asdata, sload, aload
    dffeas u_ff (
        .q      (q),
        .d      (d),
        .clk    (clk),
        .ena    (1'b1),
        .clrn   (rst_n),   // clear asíncrono activo en 0
        .prn    (1'b1),
        .asdata (1'b0),
        .sload  (1'b0),
        .aload  (1'b0)
    );
endmodule

// ============================================================================
// Detector de flancos — FF con clear asíncrono HW
// ============================================================================
module edge_detector (
    input  logic clk,
    input  logic rst_n,
    input  logic signal_in,
    output logic rising_edge,
    output logic falling_edge
);
    logic signal_prev;

    // Muestrear 'signal_in' en un FF con clear asíncrono real
    dff_aclr_n_intel u_ff_prev (
        .clk (clk),
        .rst_n (rst_n),
        .d   (signal_in),
        .q   (signal_prev)
    );

    // Misma lógica combinacional
    assign rising_edge  =  signal_in & ~signal_prev;
    assign falling_edge = ~signal_in &  signal_prev;
endmodule