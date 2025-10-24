// ============================================================================
// Módulo: Multiplexor 2:1 de 8 bits (modelo estructural)
// ============================================================================
module mux2_8bit (
    input  logic [7:0] in0,
    input  logic [7:0] in1,
    input  logic       sel,
    output logic [7:0] out
);
    // Ocho instancias explícitas (sin generate y sin for)
    mux2_1bit u_mux0 (.in0(in0[0]), .in1(in1[0]), .sel(sel), .out(out[0]));
    mux2_1bit u_mux1 (.in0(in0[1]), .in1(in1[1]), .sel(sel), .out(out[1]));
    mux2_1bit u_mux2 (.in0(in0[2]), .in1(in1[2]), .sel(sel), .out(out[2]));
    mux2_1bit u_mux3 (.in0(in0[3]), .in1(in1[3]), .sel(sel), .out(out[3]));
    mux2_1bit u_mux4 (.in0(in0[4]), .in1(in1[4]), .sel(sel), .out(out[4]));
    mux2_1bit u_mux5 (.in0(in0[5]), .in1(in1[5]), .sel(sel), .out(out[5]));
    mux2_1bit u_mux6 (.in0(in0[6]), .in1(in1[6]), .sel(sel), .out(out[6]));
    mux2_1bit u_mux7 (.in0(in0[7]), .in1(in1[7]), .sel(sel), .out(out[7]));
endmodule
