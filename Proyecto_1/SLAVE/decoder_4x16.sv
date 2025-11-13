module decoder_4x16
(
    input  logic [3:0] in,
    output logic [15:0] out
);

    logic bit0, bit1, bit2, bit3;

    assign bit0 = in[0];
    assign bit1 = in[1];
    assign bit2 = in[2];
    assign bit3 = in[3];

    assign out[0]  = ~bit0 & ~bit1 & ~bit2 & ~bit3;
    assign out[1]  =  bit0 & ~bit1 & ~bit2 & ~bit3;
    assign out[2]  = ~bit0 &  bit1 & ~bit2 & ~bit3;
    assign out[3]  =  bit0 &  bit1 & ~bit2 & ~bit3;
    assign out[4]  = ~bit0 & ~bit1 &  bit2 & ~bit3;
    assign out[5]  =  bit0 & ~bit1 &  bit2 & ~bit3;
    assign out[6]  = ~bit0 &  bit1 &  bit2 & ~bit3;
    assign out[7]  =  bit0 &  bit1 &  bit2 & ~bit3;

    assign out[8]  = ~bit0 & ~bit1 & ~bit2 &  bit3;
    assign out[9]  =  bit0 & ~bit1 & ~bit2 &  bit3;
    assign out[10] = ~bit0 &  bit1 & ~bit2 &  bit3;
    assign out[11] =  bit0 &  bit1 & ~bit2 &  bit3;
    assign out[12] = ~bit0 & ~bit1 &  bit2 &  bit3;
    assign out[13] =  bit0 & ~bit1 &  bit2 &  bit3;
    assign out[14] = ~bit0 &  bit1 &  bit2 &  bit3;
    assign out[15] =  bit0 &  bit1 &  bit2 &  bit3;

endmodule
