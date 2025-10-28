// ============================================================================
// TOP: SPI Slave + ALU — Protocolo TOP1, lógica estructural (sin if/case/?)
//  - Handshake 0xA5 -> 0x5A MISMO byte (preload 0x5A mientras !handshake_ok)
//  - 0x1N = A, 0x2N = B, 0x30 = READ_RESULT (resultado en siguiente byte)
//  - Modo-0: RX=SCK↑, MISO cambia en SCK↓, load en CS↓
//  - Fix1: B_for_alu usa rx_lo en el cierre de B (sel_b)
//  - Fix2: Latch de rx_byte y control con latch_byte (1 ciclo después del cierre)
//  - Swap opcional de nibbles para ACKs y RESULT (para alinear con tu master.py)
// ============================================================================

module spi_alu_top #(
    parameter bit SW_ACTIVE_LOW     = 1'b0,
    parameter bit LOOSE_HANDSHAKE   = 1'b1,  // 1 = acepta 1er byte como handshake aunque no sea 0xA5
    parameter bit ACK_SWAP_NIBBLES  = 1'b1,  // 1 = swapea nibbles en ACK (recomendado con tu TX)
    parameter bit RES_SWAP_NIBBLES  = 1'b1   // 1 = swapea nibbles en RESULT (recomendado con tu TX)
)(
    input  logic        clk,
    input  logic        rst_n,

    // SPI
    input  logic        spi_sck,
    input  logic        spi_mosi,
    input  logic        spi_cs_n,
    output logic        spi_miso,

    // Selección de operación
    input  logic [3:0]  switches,

    // Salidas
    output logic [3:0]  leds,
    output logic [6:0]  display,
    output logic        handshake_ok,
    output logic        data_valid
);

    // ------------------------------ Constantes
    localparam [7:0] HANDSHAKE_CODE = 8'hA5;
    localparam [7:0] HANDSHAKE_RESP = 8'h5A;

    // ------------------------------ Sincronizadores
    logic sck_sync, cs_sync, mosi_sync;
    synchronizer sync_sck_inst  (.clk(clk), .rst_n(rst_n), .async_in(spi_sck),  .sync_out(sck_sync));
    synchronizer sync_cs_inst   (.clk(clk), .rst_n(rst_n), .async_in(spi_cs_n), .sync_out(cs_sync));
    synchronizer sync_mosi_inst (.clk(clk), .rst_n(rst_n), .async_in(spi_mosi), .sync_out(mosi_sync));

    // ------------------------------ Detectores de flanco
    logic sck_rising, sck_falling, cs_rising, cs_falling;
    edge_detector edge_sck (.clk(clk), .rst_n(rst_n), .signal_in(sck_sync), .rising_edge(sck_rising), .falling_edge(sck_falling));
    edge_detector edge_cs  (.clk(clk), .rst_n(rst_n), .signal_in(cs_sync),  .rising_edge(cs_rising),  .falling_edge(cs_falling));

    // ------------------------------ Shift registers
    logic [7:0] rx_data;
    logic [7:0] tx_data_reg;

    // shift_register_rx: MSB-first en SCK↑
    // shift_register_tx: saca MSB en SCK↓; carga con tx_load (CS↓)
    shift_register_rx rx_shift_inst (
        .clk(clk), .rst_n(rst_n),
        .enable(rx_enable),
        .serial_in(mosi_sync),
        .parallel_out(rx_data)
    );

    // PRELOAD 0x5A mientras !handshake_ok → handshake 1-byte garantizado
    wire [7:0] tx_preload =
        ({8{ handshake_ok}} & tx_data_reg   ) |
        ({8{~handshake_ok}} & HANDSHAKE_RESP);

    shift_register_tx tx_shift_inst (
        .clk(clk), .rst_n(rst_n),
        .load(tx_load),
        .shift(tx_shift),
        .parallel_in(tx_preload),
        .serial_out(spi_miso)
    );

    // ------------------------------ Contador y control Modo-0
    logic [2:0] bit_count;
    bit_counter u_cnt (.clk(clk), .rst_n(rst_n), .enable(counter_enable), .clear(counter_clear), .count(bit_count));

    wire cs_active = ~cs_sync;

    wire rx_enable      = cs_active & sck_rising;   // muestrea MOSI en SCK↑
    wire tx_shift       = cs_active & sck_falling;  // cambia MISO en SCK↓
    wire tx_load        = cs_falling;               // precarga TX en CS↓
    wire counter_enable = cs_active & sck_rising;   // cuenta en SCK↑
    wire counter_clear  = cs_rising | cs_falling;   // reinicia en CS↑/CS↓

    // Fin de byte (8º bit)
    wire bit_count_7   = (bit_count == 3'd7);
    wire process_pulse = cs_active & sck_rising & bit_count_7;

    // *** Fix2: retrasa 1 ciclo el pulso de cierre de byte para evitar off-by-one ***
    logic latch_byte; // 1 ciclo después del 8º SCK↑
    dffeas u_pp (.q(latch_byte), .d(process_pulse), .clk(clk),
                 .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                 .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    // ------------------------------ Byte latcheado (con latch_byte)
    logic [7:0] rx_byte;
    wire  [7:0] rx_byte_d = ({8{ latch_byte}} & rx_data) | ({8{~latch_byte}} & rx_byte);

    genvar rbi;
    generate
        for (rbi=0; rbi<8; rbi++) begin : REG_RXBYTE
            dffeas u_rxbyte (.q(rx_byte[rbi]), .d(rx_byte_d[rbi]), .clk(clk),
                             .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                             .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
        end
    endgenerate

    wire [3:0] rx_hi = rx_byte[7:4];
    wire [3:0] rx_lo = rx_byte[3:0];

    // ------------------------------ Handshake (sobre rx_byte)
    wire is_handshake_byte = (rx_byte == HANDSHAKE_CODE);

    // ------------------------------ Switches sincronizados y operación efectiva
    logic [3:0] sw_sync1, sw_sync2;
    genvar sw_i;
    generate
        for (sw_i=0; sw_i<4; sw_i++) begin : SW_SYNC
            dffeas u_sw1 (.q(sw_sync1[sw_i]), .d(switches[sw_i]), .clk(clk),
                          .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                          .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
            dffeas u_sw2 (.q(sw_sync2[sw_i]), .d(sw_sync1[sw_i]), .clk(clk),
                          .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                          .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
        end
    endgenerate
    wire [3:0] op_eff = sw_sync2 ^ {4{SW_ACTIVE_LOW}};

    // ------------------------------ Decodificación (sobre rx_byte)
    wire dec_A = (rx_hi == 4'h1);                         // 0x1N
    wire dec_B = (rx_hi == 4'h2);                         // 0x2N
    wire dec_R = (rx_byte == 8'h30) | (rx_hi == 4'h3);    // 0x30 ó 0x3N

    // Priorización (hs > A > B > R > keep)
    wire sel_hs = is_handshake_byte;
    wire sel_a  = (~sel_hs) &  dec_A;
    wire sel_b  = (~sel_hs) & (~dec_A) & dec_B;
    wire sel_r  = (~sel_hs) & (~dec_A) & (~dec_B) & dec_R;
    wire sel_k  = (~sel_hs) & (~dec_A) & (~dec_B) & (~dec_R);

    // ------------------------------ Banco de registros A/B/OP (carga con latch_byte)
    logic [3:0] A_reg, B_reg, op_latched;

    wire load_A = sel_a & latch_byte;
    wire load_B = sel_b & latch_byte;

    wire [3:0] A_d  = ({4{ load_A}} & rx_lo ) | ({4{~load_A}} & A_reg);
    wire [3:0] B_d  = ({4{ load_B}} & rx_lo ) | ({4{~load_B}} & B_reg);
    wire [3:0] OP_d = ({4{ load_A}} & op_eff) | ({4{~load_A}} & op_latched);

    genvar ai, bi, oi;
    generate
        for (ai=0; ai<4; ai++) begin : REG_A
            dffeas u_a (.q(A_reg[ai]), .d(A_d[ai]), .clk(clk),
                        .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                        .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
        end
        for (bi=0; bi<4; bi++) begin : REG_B
            dffeas u_b (.q(B_reg[bi]), .d(B_d[bi]), .clk(clk),
                        .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                        .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
        end
        for (oi=0; oi<4; oi++) begin : REG_OP
            dffeas u_op (.q(op_latched[oi]), .d(OP_d[oi]), .clk(clk),
                         .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                         .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
        end
    endgenerate

    // ------------------------------ ALU combinacional (B_for_alu con rx_lo en B)
    wire [3:0] B_for_alu =
        ({4{ sel_b}} & rx_lo ) |
        ({4{~sel_b}} & B_reg );

    logic [3:0] alu_S;
    logic       alu_Cout, alu_Z, alu_N, alu_V;
    logic [6:0] seg_unused;

    alu #(.WIDTH(4)) u_alu (
        .A(A_reg),
        .B(B_for_alu),
        .boton0(op_latched[0]),
        .boton1(op_latched[1]),
        .boton2(op_latched[2]),
        .boton3(op_latched[3]),
        .Cin(1'b0),
        .S(alu_S),
        .Cout(alu_Cout),
        .Z(alu_Z), .N(alu_N), .V(alu_V),
        .segments_units(seg_unused)
    );

    // ------------------------------ Resultado registrado (cuando llega B)
    logic [3:0] result_reg;
    wire [3:0] result_d = ({4{ load_B}} & alu_S) | ({4{~load_B}} & result_reg);

    genvar ri;
    generate
        for (ri=0; ri<4; ri++) begin : REG_RES
            dffeas u_res (.q(result_reg[ri]), .d(result_d[ri]), .clk(clk),
                          .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                          .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
        end
    endgenerate

    // Pulso de dato válido (1 ciclo) = load_B
    logic result_pulse;
    dffeas u_dv (.q(result_pulse), .d(load_B), .clk(clk),
                 .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                 .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    // ------------------------------ TX path (ACK / RESULT para la SIGUIENTE transacción)
    // ACK base (sobre rx_byte latcheado)
    wire [7:0] ack_A_base = {4'hA, rx_lo};
    wire [7:0] ack_B_base = {4'hB, rx_lo};
    // Swap opcional de nibbles por si tu TX/lectura los invierte
    wire [7:0] ack_A = ({8{~ACK_SWAP_NIBBLES}} & ack_A_base) |
                       ({8{ ACK_SWAP_NIBBLES}} & {ack_A_base[3:0], ack_A_base[7:4]});
    wire [7:0] ack_B = ({8{~ACK_SWAP_NIBBLES}} & ack_B_base) |
                       ({8{ ACK_SWAP_NIBBLES}} & {ack_B_base[3:0], ack_B_base[7:4]});

    // Resultado (swap opcional igual que ACK)
    wire [7:0] tx_prep_res_base = {4'h0, result_reg};
    wire [7:0] tx_prep_res      = ({8{~RES_SWAP_NIBBLES}} & tx_prep_res_base) |
                                  ({8{ RES_SWAP_NIBBLES}} & {tx_prep_res_base[3:0], tx_prep_res_base[7:4]});

    wire [7:0] tx_prep_hs  = HANDSHAKE_RESP;

    wire [7:0] tx_sel_process =
        ({8{ sel_hs}} & tx_prep_hs ) |
        ({8{ sel_a }} & ack_A      ) |
        ({8{ sel_b }} & ack_B      ) |
        ({8{ sel_r }} & tx_prep_res) |
        ({8{ sel_k }} & tx_data_reg);

    // Registrar el TX al cierre del byte (latch_byte)
    wire [7:0] tx_d =
        ({8{ latch_byte}} & tx_sel_process) |
        ({8{~latch_byte}} & tx_data_reg);

    genvar ti;
    generate
        for (ti=0; ti<8; ti++) begin : REG_TX
            dffeas u_tx (.q(tx_data_reg[ti]), .d(tx_d[ti]), .clk(clk),
                         .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                         .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
        end
    endgenerate

    // ------------------------------ Handshake_ok robusto (con latch_byte)
    logic seen_first_byte;
    wire  seen_first_byte_d = seen_first_byte | latch_byte;
    dffeas u_seen (.q(seen_first_byte), .d(seen_first_byte_d), .clk(clk),
                   .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                   .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    wire first_byte_pulse = latch_byte & ~seen_first_byte;

    wire hs_set_strict = latch_byte & (rx_byte == HANDSHAKE_CODE);
    wire hs_set_loose  = latch_byte & first_byte_pulse & LOOSE_HANDSHAKE;
    wire hs_set        = hs_set_strict | hs_set_loose;

    wire hs_d = handshake_ok | hs_set;
    dffeas u_hs (.q(handshake_ok), .d(hs_d), .clk(clk),
                 .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                 .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    // ------------------------------ Salidas
    assign leds       = result_reg;
    assign data_valid = result_pulse;

    // ------------------------------ Display 7-seg directo (ajústalo a tu placa)
    wire [6:0] seg_ah_abcdefg; // a..g activo-alto
    hex7seg_struct u_hex (.hex(result_reg), .seg(seg_ah_abcdefg));

    localparam bit COMMON_ANODE = 1'b1;  // 1: invierte (ánodo común)
    localparam bit PINS_GFEDCBA = 1'b1;  // 1: pines {g,f,e,d,c,b,a}
    localparam bit MIRROR_LR    = 1'b0;  // 1: espejo horizontal

    wire [6:0] seg_mirror = { seg_ah_abcdefg[6], // a
                              seg_ah_abcdefg[1], // f
                              seg_ah_abcdefg[2], // e
                              seg_ah_abcdefg[3], // d
                              seg_ah_abcdefg[4], // c
                              seg_ah_abcdefg[5], // b
                              seg_ah_abcdefg[0]  // g
                            };

    wire [6:0] seg_sel =
        ({7{~MIRROR_LR}} & seg_ah_abcdefg) |
        ({7{ MIRROR_LR}} & seg_mirror);

    wire [6:0] seg_ordered =
        ({7{ PINS_GFEDCBA}} & {seg_sel[0], seg_sel[1], seg_sel[2],
                               seg_sel[3], seg_sel[4], seg_sel[5], seg_sel[6]}) |
        ({7{~PINS_GFEDCBA}} &  seg_sel);

    assign display =
        ({7{~COMMON_ANODE}} &  seg_ordered) |
        ({7{ COMMON_ANODE}} & ~seg_ordered);

endmodule
