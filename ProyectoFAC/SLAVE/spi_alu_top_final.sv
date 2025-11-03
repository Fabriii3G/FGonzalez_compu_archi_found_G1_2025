// ============================================================================
// SPI ALU TOP - Versión con señales de debug
// ============================================================================

module spi_alu_top_final #(
    parameter bit SW_ACTIVE_LOW       = 1'b0,
    parameter bit LOOSE_HANDSHAKE     = 1'b1,
    parameter bit ACK_SWAP_NIBBLES    = 1'b1,
    parameter bit RES_SWAP_NIBBLES    = 1'b1,
    parameter bit PWM_LED_ACTIVE_LOW  = 1'b1
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
    // output logic [3:0]  leds,
    output logic [3:0]  operand_b_leds,
    output logic [3:0]  operand_a_leds,
    // output logic [6:0]  display,
    output logic [6:0]  display_ALU_result,
    output logic        handshake_ok,
    output logic        data_valid,

    output logic [6:0] alu_flag_negative_segments,    // show a '-', or nothing.
    output logic [6:0] alu_flag_zero_segments,        // show a 0, or nothing.
    output logic [6:0] alu_flag_carry_segments,       // show a C, or nothing.
    
    // PWM
    output logic        pwm_out,
    output logic        pwm_led,
    
    // SENSOR
    input  logic        sensor_serial,
    input  logic        sensor_btn,
    output logic [3:0]  sensor_leds,        // remove
    output logic        sensor_valid_led    // remove
);

    // ========================================================================
    // SENSOR   - Keep
    // ========================================================================
    logic [3:0] captured_data;
    logic       capture_complete;
    
    sensor_capture u_sensor (
        .clk(clk),
        .rst_n(rst_n),
        .sensor_data(sensor_serial),
        .capture_btn(sensor_btn),
        .stored_data(captured_data),
        .data_valid(capture_complete)
    );
    
    assign sensor_leds      = captured_data;
    assign sensor_valid_led = capture_complete;

    // ========================================================================
    // Receive Reg_A through SPI
    // ========================================================================
    
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

    shift_register_rx rx_shift_inst (
        .clk(clk), .rst_n(rst_n),
        .enable(rx_enable),
        .serial_in(mosi_sync),
        .parallel_out(rx_data)
    );

    // PRELOAD 0x5A mientras !handshake_ok
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

    // ------------------------------ Control SPI modo-0
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

    // *** Fix2: retrasa 1 ciclo el cierre de byte ***
    logic latch_byte;
    dffeas u_pp (.q(latch_byte), .d(process_pulse), .clk(clk),
                 .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                 .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));

    // ------------------------------ Byte latcheado
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

    // ------------------------------ Handshake
    wire is_handshake_byte = (rx_byte == HANDSHAKE_CODE);

    // ------------------------------ Switches sincronizados
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

    // ------------------------------ Decodificación
    wire dec_A = (rx_hi == 4'h1);                         // 0x1N
    wire dec_B = (rx_hi == 4'h2);                         // 0x2N
    wire dec_R = (rx_byte == 8'h30) | (rx_hi == 4'h3);    // 0x30 ó 0x3N

    // Priorización
    wire sel_hs = is_handshake_byte;
    wire sel_a  = (~sel_hs) &  dec_A;
    wire sel_b  = (~sel_hs) & (~dec_A) & dec_B;
    wire sel_r  = (~sel_hs) & (~dec_A) & (~dec_B) & dec_R;
    wire sel_k  = (~sel_hs) & (~dec_A) & (~dec_B) & (~dec_R);

    // ------------------------------ Banco de registros A/B/OP
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

    // ========================================================================
    // ALU
    // ========================================================================
    // Instantiate shift register for operand B.
    // Instantiate asyncronous input syncronizer for the switch that enables thr shift register for operand B.
    logic operand_b_enabler;
    external_input_syncronizer operand_b_syncronizer
    (
        .async_in(sensor_btn),
        .clk(clk),
        .clrn(rst_n),    // Active low means it must be on for the DFF (D Flip Flop) to work.
        .sync_out(operand_b_enabler)
    );
    logic [3:0] operand_b;    // This is the [3:0] operand B that is received by the ALU.
    shift_register_nibble operand_b_shift_register
    (
        .clk(clk),
        .rst_n(rst_n),
        .enable(operand_b_enabler),
        .serial_in(sensor_serial),
        .parallel_out(operand_b)
    );


    logic [3:0] alu_S;
    logic       alu_Cout, alu_Z, alu_N, alu_V;
    logic [6:0] seg_unused;
    
    alu #(.WIDTH(4)) u_alu (
        .A(A_reg),                  // MUST BE A_reg
        .B(operand_b),              // - Changed to shift reg.
        .boton0(switches[0]),       // The actual not debounced switches of the FPGA.
        .boton1(switches[1]),
        .boton2(switches[2]),
        .boton3(switches[3]),
        .Cin(1'b0),
        .S(alu_S),  
        .Cout(alu_Cout),            // Carry flag.
        .Z(alu_Z),                  // Zero flag.
        .N(alu_N),                  // Negative flag.
        .V(alu_V),                  // Overflow flag.
        .segments_units(seg_unused)
    );

    // ========================================================================
    // RESULTADO - CON DEBUG
    // ========================================================================
    
    // DEBUG: Registrar si alguna vez se activó load_A
    logic ever_loaded_a;
    wire ever_loaded_a_next;
    assign ever_loaded_a_next = ever_loaded_a | load_A;
    
    always_ff @(posedge clk or negedge rst_n) begin
        ever_loaded_a <= ~rst_n & 1'b0;
        ever_loaded_a <= rst_n & ever_loaded_a_next;
    end
    
    // Calcular solo si ambos operandos están listos
    wire compute_result;
    assign compute_result = load_A & capture_complete;
    
    // DEBUG: Registrar si alguna vez se computó
    logic ever_computed;
    wire ever_computed_next;
    assign ever_computed_next = ever_computed | compute_result;
    
    always_ff @(posedge clk or negedge rst_n) begin
        ever_computed <= ~rst_n & 1'b0;
        ever_computed <= rst_n & ever_computed_next;
    end
    
    logic [3:0] result_reg;
    wire [3:0] result_next;
    
    assign result_next = ({4{compute_result}} & alu_S) | 
                        ({4{~compute_result}} & result_reg);
    
    always_ff @(posedge clk or negedge rst_n) begin
        result_reg <= ~rst_n & 4'h0;
        result_reg <= rst_n & result_next;
    end

    // ========================================================================
    // TX PATH
    // ========================================================================
    
    wire [7:0] ack_A_base;
    assign ack_A_base = {4'hA, rx_lo};
    
    wire [7:0] ack_A_swapped;
    assign ack_A_swapped = {ack_A_base[3:0], ack_A_base[7:4]};
    
    wire [7:0] ack_A;
    assign ack_A = ({8{~ACK_SWAP_NIBBLES}} & ack_A_base) | 
                  ({8{ACK_SWAP_NIBBLES}} & ack_A_swapped);
    
    wire [7:0] ack_B_base;
    assign ack_B_base = {4'hB, rx_lo};
    
    wire [7:0] ack_B_swapped;
    assign ack_B_swapped = {ack_B_base[3:0], ack_B_base[7:4]};
    
    wire [7:0] ack_B;
    assign ack_B = ({8{~ACK_SWAP_NIBBLES}} & ack_B_base) | 
                  ({8{ACK_SWAP_NIBBLES}} & ack_B_swapped);
    
    wire [7:0] tx_prep_res_base;
    assign tx_prep_res_base = {4'h0, result_reg};
    
    wire [7:0] tx_prep_res_swapped;
    assign tx_prep_res_swapped = {tx_prep_res_base[3:0], tx_prep_res_base[7:4]};
    
    wire [7:0] tx_prep_res;
    assign tx_prep_res = ({8{~RES_SWAP_NIBBLES}} & tx_prep_res_base) | 
                        ({8{RES_SWAP_NIBBLES}} & tx_prep_res_swapped);
    
    wire [7:0] tx_prep_hs;
    assign tx_prep_hs = HANDSHAKE_RESP;
    
    // DEBUG: Si nunca se computó, enviar 0xDD en lugar del resultado
    wire [7:0] tx_prep_res_debug;
    assign tx_prep_res_debug = ({8{ever_computed}} & tx_prep_res) |
                              ({8{~ever_computed}} & 8'hDD);
    
    wire [7:0] tx_sel_process;
    assign tx_sel_process = ({8{sel_hs}} & tx_prep_hs)        |
                           ({8{sel_a}}  & ack_A)              |
                           ({8{sel_b}}  & ack_B)              |
                           ({8{sel_r}}  & tx_prep_res_debug)  |
                           ({8{sel_k}}  & tx_data_reg);
    
    wire [7:0] tx_data_next;
    assign tx_data_next = ({8{latch_byte}} & tx_sel_process) | 
                         ({8{~latch_byte}} & tx_data_reg);
    
    always_ff @(posedge clk or negedge rst_n) begin
        tx_data_reg <= ~rst_n & 8'h00;
        tx_data_reg <= rst_n & tx_data_next;
    end

    // ========================================================================
    // HANDSHAKE_OK
    // ========================================================================
    logic seen_first_byte;
    wire seen_first_byte_next;
    
    assign seen_first_byte_next = seen_first_byte | latch_byte;
    
    always_ff @(posedge clk or negedge rst_n) begin
        seen_first_byte <= ~rst_n & 1'b0;
        seen_first_byte <= rst_n & seen_first_byte_next;
    end
    
    wire first_byte_pulse;
    assign first_byte_pulse = latch_byte & ~seen_first_byte;
    
    wire hs_set_strict, hs_set_loose, hs_set;
    assign hs_set_strict = latch_byte & is_handshake_byte;
    assign hs_set_loose  = first_byte_pulse & LOOSE_HANDSHAKE;
    assign hs_set        = hs_set_strict | hs_set_loose;
    
    wire hs_next;
    assign hs_next = handshake_ok | hs_set;
    
    always_ff @(posedge clk or negedge rst_n) begin
        handshake_ok <= ~rst_n & 1'b0;
        handshake_ok <= rst_n & hs_next;
    end

    // ========================================================================
    // SALIDAS - CON DEBUG
    // ========================================================================
    // Mostrar en LEDs:
    // - Si ever_computed: mostrar resultado
    // - Si solo ever_loaded_a: mostrar A_reg
    // - Si ninguno: mostrar captured_data
    
    // wire [3:0] leds_debug;
    // assign leds_debug = ({4{ever_computed}} & result_reg) |
    //                    ({4{~ever_computed & ever_loaded_a}} & A_reg) |
    //                    ({4{~ever_computed & ~ever_loaded_a}} & captured_data);
    
    // assign leds       = leds_debug;
    // assign data_valid = compute_result;

    // ========================================================================
    // DISPLAY 7 SEGMENTOS
    // ========================================================================
    // wire [6:0] seg_ah_abcdefg;
    // hex7seg_struct u_hex (.hex(leds_debug), .seg(seg_ah_abcdefg));
    
    // localparam bit COMMON_ANODE = 1'b1;
    // localparam bit PINS_GFEDCBA = 1'b1;
    // localparam bit MIRROR_LR    = 1'b0;
    
    // wire [6:0] seg_mirror;
    // assign seg_mirror = {seg_ah_abcdefg[6], seg_ah_abcdefg[1], seg_ah_abcdefg[2],
    //                     seg_ah_abcdefg[3], seg_ah_abcdefg[4], seg_ah_abcdefg[5],
    //                     seg_ah_abcdefg[0]};
    
    // wire [6:0] seg_sel;
    // assign seg_sel = ({7{~MIRROR_LR}} & seg_ah_abcdefg) | 
    //                 ({7{MIRROR_LR}} & seg_mirror);
    
    // wire [6:0] seg_ordered;
    // wire [6:0] seg_gfedcba_order;
    // assign seg_gfedcba_order = {seg_sel[0], seg_sel[1], seg_sel[2], 
    //                            seg_sel[3], seg_sel[4], seg_sel[5], seg_sel[6]};
    
    // assign seg_ordered = ({7{PINS_GFEDCBA}} & seg_gfedcba_order) |
    //                     ({7{~PINS_GFEDCBA}} & seg_sel);
    
    // wire [6:0] seg_inverted;
    // assign seg_inverted[0] = ~seg_ordered[0];
    // assign seg_inverted[1] = ~seg_ordered[1];
    // assign seg_inverted[2] = ~seg_ordered[2];
    // assign seg_inverted[3] = ~seg_ordered[3];
    // assign seg_inverted[4] = ~seg_ordered[4];
    // assign seg_inverted[5] = ~seg_ordered[5];
    // assign seg_inverted[6] = ~seg_ordered[6];
    
    // assign display = ({7{~COMMON_ANODE}} & seg_ordered) | 
    //                 ({7{COMMON_ANODE}} & seg_inverted);

    seven_segment_adapter alu_result_adapter
    (
        .in(alu_S),
        .segments_abcdefg(display_ALU_result)
    );
    assign operand_b_leds = operand_b;
    assign operand_a_leds = A_reg;  // MUST BE A_reg
    
    // Use a mux to chose between an empty 7 segment display or to display the g segment '-' based on the negative flag to represent it.
    // mux is 8 bit.
    logic [7:0] alu_flag_negative_segments_8_bit;
    mux2_8bit show_negative_flag_mux
    (
    .in0(8'hff),    // no segments lit.
    .in1(8'hfe),    // turn on g segment. '-'
    .sel(alu_N),
    .out(alu_flag_negative_segments_8_bit)
    );
    assign alu_flag_negative_segments = alu_flag_negative_segments_8_bit[6:0];  // Take out the MSB to have an 7 bit array.

    logic [7:0] alu_flag_zero_segments_8_bit;
    mux2_8bit show_zero_flag_mux
    (
    .in0(8'hff),    // no segments lit.
    .in1(8'h01),    // turn on segments for '0'.
    .sel(alu_Z),
    .out(alu_flag_zero_segments_8_bit)
    );
    assign alu_flag_zero_segments = alu_flag_zero_segments_8_bit[6:0];  // Take out the MSB to have an 7 bit array.
    
    logic [7:0] alu_flag_carry_segments_8_bit;
    mux2_8bit show_carry_flag_mux
    (
    .in0(8'hff),    // no segments lit.
    .in1(8'h31),    // turn on segments for 'C'.
    .sel(alu_Cout),
    .out(alu_flag_carry_segments_8_bit)
    );
    assign alu_flag_carry_segments = alu_flag_carry_segments_8_bit[6:0];  // Take out the MSB to have an 7 bit array.


    // ========================================================================
    // PWM
    // ========================================================================
    localparam int unsigned PWM_CNTR_BITS = 11;
    
    // Always enable pmw output.
    // wire pwm_en;
    // assign pwm_en = handshake_ok;
    
    // wire pwm_raw;
    pwm16_struct #(.CNTR_BITS(PWM_CNTR_BITS)) u_pwm (
        .clk(clk),
        .en(1'b1),
        .duty(alu_S),   // The PWM generator is given the ALU result
        .pwm_out(pwm_out)   // pwm_out output of the FPGA is assigned here.
    );
    
    // assign pwm_out = pwm_raw;
    assign pwm_led = pwm_out ^ PWM_LED_ACTIVE_LOW;  // inverts pwm_out if PWM_LED_ACTIVE_LOW is 1.

endmodule