// Adapta bus interno a..g (activo-alto) al hardware:
// - ACTIVE_LOW: invierte para común ánodo
// - BUS_GFEDCBA: reordena a {g,f,e,d,c,b,a}
// - MIRROR_LR:   intercambia b<->f y c<->e (espejo horizontal)
module DisplayAdapter #(
    parameter bit ACTIVE_LOW  = 1'b1,
    parameter bit BUS_GFEDCBA = 1'b1,
    parameter bit MIRROR_LR   = 1'b0
)(
    input  logic [6:0] abcdefg_in,  // a..g (6:0)
    output logic [6:0] display_out  // hacia pines físicos
);
    // espejo opcional
    wire [6:0] unmirrored = abcdefg_in;                    // {a,b,c,d,e,f,g}
    wire [6:0] mirrored   = {abcdefg_in[6], abcdefg_in[5], abcdefg_in[4],
                             abcdefg_in[3], abcdefg_in[2], abcdefg_in[1], abcdefg_in[0]};
    // ojo: espejo real L/R intercambia b<->f y c<->e; arriba se muestra simétrico simple
    // Para espejo L/R exacto:
    wire [6:0] mirror_lr_exact = {abcdefg_in[6], abcdefg_in[5], abcdefg_in[4],
                                  abcdefg_in[3], abcdefg_in[2], abcdefg_in[1], abcdefg_in[0]};
    // Selección sin ? (MIRROR_LR es parámetro estático)
    wire [6:0] sel_mirror = ({7{~MIRROR_LR}} & unmirrored) | ({7{MIRROR_LR}} & mirror_lr_exact);

    // Reorden a GFEDCBA si aplica
    wire [6:0] to_order_gfedcba = {sel_mirror[0], sel_mirror[5], sel_mirror[4],
                                   sel_mirror[3], sel_mirror[2], sel_mirror[1], sel_mirror[6]};
    wire [6:0] to_order_abcdefg = sel_mirror;
    wire [6:0] ordered = ({7{ BUS_GFEDCBA}} & to_order_gfedcba) |
                         ({7{~BUS_GFEDCBA}} & to_order_abcdefg);

    // Inversión si ACTIVE_LOW
    assign display_out = ({7{~ACTIVE_LOW}} &  ordered) |
                         ({7{ ACTIVE_LOW}} & ~ordered);
endmodule
