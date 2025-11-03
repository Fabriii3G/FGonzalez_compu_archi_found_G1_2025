module seven_segment_adapter
(
    input  logic [3:0] in,
    output logic [6:0] segments_abcdefg
);
    logic [15:0] decoded;
    decoder_4x16 u_decoder
    (
    .in(in),
    .out(decoded)
    );

    logic a, b, c, d, e, f, g;


    assign a =
    decoded[0] |
    decoded[2] |
    decoded[3] |
    decoded[5] |
    decoded[6] |
    decoded[7] |
    decoded[8] |
    decoded[9] |
    decoded[10] |
    decoded[12] |
    decoded[14] |
    decoded[15];

    assign b =
    decoded[0] |
    decoded[1] |
    decoded[2] |
    decoded[3] |
    decoded[4] |
    decoded[7] |
    decoded[8] |
    decoded[9] |
    decoded[10] |
    decoded[13];

    assign c =
    decoded[0] |
    decoded[1] |
    decoded[3] |
    decoded[4] |
    decoded[5] |
    decoded[6] |
    decoded[7] |
    decoded[8] |
    decoded[9] |
    decoded[10] |
    decoded[11] |
    decoded[13];

    assign d =
    decoded[0] |
    decoded[2] |
    decoded[3] |
    decoded[5] |
    decoded[6] |
    decoded[8] |
    decoded[11] |
    decoded[12] |
    decoded[13] |
    decoded[14];

    assign e =
    decoded[0] |
    decoded[2] |
    decoded[6] |
    decoded[8] |
    decoded[10] |
    decoded[11] |
    decoded[12] |
    decoded[13] |
    decoded[14] |
    decoded[15];

    assign f =
    decoded[0] |
    decoded[4] |
    decoded[5] |
    decoded[6] |
    decoded[8] |
    decoded[9] |
    decoded[10] |
    decoded[11] |
    decoded[12] |
    decoded[14] |
    decoded[15];

    assign g =
    decoded[2] |
    decoded[3] |
    decoded[4] |
    decoded[5] |
    decoded[6] |
    decoded[8] |
    decoded[9] |
    decoded[10] |
    decoded[11] |
    decoded[13] |
    decoded[14] |
    decoded[15];

    assign segments_abcdefg = {~a,~b,~c,~d,~e,~f,~g};

endmodule