// ============================================================================
// SPI ALU TOP - Versión con señales de debug
// ============================================================================

module spi_alu_top #(
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
    output logic [3:0]  leds,
    output logic [6:0]  display,
    output logic        handshake_ok,
    output logic        data_valid,
    
    // PWM
    output logic        pwm_out,
    output logic        pwm_led,
    
    // SENSOR
    input  logic        sensor_serial,
    input  logic        sensor_btn,
    output logic [3:0]  sensor_leds,
    output logic        sensor_valid_led
);

    localparam [7:0] HANDSHAKE_CODE = 8'hA5;
    localparam [7:0] HANDSHAKE_RESP = 8'h5A;

    // ========================================================================
    // SINCRONIZADORES SPI
    // ========================================================================
    logic sck_sync, cs_sync, mosi_sync;
    
    synchronizer sync_sck_inst  (.clk(clk), .rst_n(rst_n), .async_in(spi_sck),  .sync_out(sck_sync));
    synchronizer sync_cs_inst   (.clk(clk), .rst_n(rst_n), .async_in(spi_cs_n), .sync_out(cs_sync));
    synchronizer sync_mosi_inst (.clk(clk), .rst_n(rst_n), .async_in(spi_mosi), .sync_out(mosi_sync));

    // ========================================================================
    // DETECTORES DE FLANCO
    // ========================================================================
    logic sck_rising, sck_falling, cs_rising, cs_falling;
    
    edge_detector edge_sck (.clk(clk), .rst_n(rst_n), .signal_in(sck_sync), 
                           .rising_edge(sck_rising), .falling_edge(sck_falling));
    edge_detector edge_cs  (.clk(clk), .rst_n(rst_n), .signal_in(cs_sync),  
                           .rising_edge(cs_rising),  .falling_edge(cs_falling));

    // ========================================================================
    // SHIFT REGISTERS
    // ========================================================================
    logic [7:0] rx_data;
    logic [7:0] tx_data_reg;
    
    logic rx_enable, tx_load, tx_shift;
    
    shift_register_rx rx_shift_inst (
        .clk(clk), .rst_n(rst_n),
        .enable(rx_enable),
        .serial_in(mosi_sync),
        .parallel_out(rx_data)
    );
    
    wire [7:0] tx_preload;
    assign tx_preload = ({8{handshake_ok}} & tx_data_reg) | 
                       ({8{~handshake_ok}} & HANDSHAKE_RESP);
    
    shift_register_tx tx_shift_inst (
        .clk(clk), .rst_n(rst_n),
        .load(tx_load),
        .shift(tx_shift),
        .parallel_in(tx_preload),
        .serial_out(spi_miso)
    );

    // ========================================================================
    // CONTROL SPI
    // ========================================================================
    logic [2:0] bit_count;
    logic counter_enable, counter_clear;
    
    bit_counter u_cnt (
        .clk(clk), .rst_n(rst_n),
        .enable(counter_enable),
        .clear(counter_clear),
        .count(bit_count)
    );
    
    wire cs_active;
    assign cs_active = ~cs_sync;
    
    assign rx_enable      = cs_active & sck_rising;
    assign tx_shift       = cs_active & sck_falling;
    assign tx_load        = cs_falling;
    assign counter_enable = cs_active & sck_rising;
    assign counter_clear  = cs_rising | cs_falling;
    
    wire bit_count_7;
    assign bit_count_7 = (bit_count == 3'd7);
    
    wire process_pulse;
    assign process_pulse = cs_active & sck_rising & bit_count_7;
    
    logic latch_byte;
    always_ff @(posedge clk or negedge rst_n) begin
        latch_byte <= ~rst_n & 1'b0;
        latch_byte <= rst_n & process_pulse;
    end

    // ========================================================================
    // BYTE RECIBIDO
    // ========================================================================
    logic [7:0] rx_byte;
    wire [7:0] rx_byte_next;
    
    assign rx_byte_next = ({8{latch_byte}} & rx_data) | 
                         ({8{~latch_byte}} & rx_byte);
    
    always_ff @(posedge clk or negedge rst_n) begin
        rx_byte <= ~rst_n & 8'h00;
        rx_byte <= rst_n & rx_byte_next;
    end
    
    wire [3:0] rx_hi, rx_lo;
    assign rx_hi = rx_byte[7:4];
    assign rx_lo = rx_byte[3:0];

    // ========================================================================
    // COMPARADOR DE HANDSHAKE
    // ========================================================================
    wire is_handshake_byte;
    comparator_8bit hs_comp (
        .data_a(rx_byte),
        .data_b(HANDSHAKE_CODE),
        .equal(is_handshake_byte)
    );

    // ========================================================================
    // SWITCHES SINCRONIZADOS
    // ========================================================================
    logic [3:0] sw_sync1, sw_sync2;
    
    always_ff @(posedge clk or negedge rst_n) begin
        sw_sync1 <= ~rst_n & 4'h0;
        sw_sync1 <= rst_n & switches;
        
        sw_sync2 <= ~rst_n & 4'h0;
        sw_sync2 <= rst_n & sw_sync1;
    end
    
    wire [3:0] op_eff;
    wire [3:0] sw_inverted;
    
    assign sw_inverted[0] = sw_sync2[0] ^ SW_ACTIVE_LOW;
    assign sw_inverted[1] = sw_sync2[1] ^ SW_ACTIVE_LOW;
    assign sw_inverted[2] = sw_sync2[2] ^ SW_ACTIVE_LOW;
    assign sw_inverted[3] = sw_sync2[3] ^ SW_ACTIVE_LOW;
    
    assign op_eff = sw_inverted;

    // ========================================================================
    // DECODIFICACIÓN DE COMANDOS
    // ========================================================================
    wire dec_A, dec_B, dec_R;
    wire rx_hi_eq_1, rx_hi_eq_2, rx_hi_eq_3;
    wire rx_byte_eq_30;
    
    assign rx_hi_eq_1 = (rx_hi == 4'h1);
    assign rx_hi_eq_2 = (rx_hi == 4'h2);
    assign rx_hi_eq_3 = (rx_hi == 4'h3);
    assign rx_byte_eq_30 = (rx_byte == 8'h30);
    
    assign dec_A = rx_hi_eq_1;
    assign dec_B = rx_hi_eq_2;
    assign dec_R = rx_byte_eq_30 | rx_hi_eq_3;
    
    wire sel_hs, sel_a, sel_b, sel_r, sel_k;
    
    assign sel_hs = is_handshake_byte;
    assign sel_a  = ~sel_hs & dec_A;
    assign sel_b  = ~sel_hs & ~dec_A & dec_B;
    assign sel_r  = ~sel_hs & ~dec_A & ~dec_B & dec_R;
    assign sel_k  = ~sel_hs & ~dec_A & ~dec_B & ~dec_R;

    // ========================================================================
    // SENSOR
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
    // REGISTRO A
    // ========================================================================
    logic [3:0] A_reg;
    wire load_A;
    wire [3:0] A_next;
    
    assign load_A = sel_a & latch_byte;
    assign A_next = ({4{load_A}} & rx_lo) | ({4{~load_A}} & A_reg);
    
    always_ff @(posedge clk or negedge rst_n) begin
        A_reg <= ~rst_n & 4'h0;
        A_reg <= rst_n & A_next;
    end

    // ========================================================================
    // REGISTRO OP
    // ========================================================================
    logic [3:0] op_latched;
    wire [3:0] op_next;
    
    assign op_next = ({4{load_A}} & op_eff) | ({4{~load_A}} & op_latched);
    
    always_ff @(posedge clk or negedge rst_n) begin
        op_latched <= ~rst_n & 4'h0;
        op_latched <= rst_n & op_next;
    end

    // ========================================================================
    // ALU
    // ========================================================================
    logic [3:0] alu_S;
    logic       alu_Cout, alu_Z, alu_N, alu_V;
    logic [6:0] seg_unused;
    
    alu #(.WIDTH(4)) u_alu (
        .A(A_reg),
        .B(captured_data),
        .boton0(op_latched[0]),
        .boton1(op_latched[1]),
        .boton2(op_latched[2]),
        .boton3(op_latched[3]),
        .Cin(1'b0),
        .S(alu_S),
        .Cout(alu_Cout),
        .Z(alu_Z),
        .N(alu_N),
        .V(alu_V),
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
    
    wire [3:0] leds_debug;
    assign leds_debug = ({4{ever_computed}} & result_reg) |
                       ({4{~ever_computed & ever_loaded_a}} & A_reg) |
                       ({4{~ever_computed & ~ever_loaded_a}} & captured_data);
    
    assign leds       = leds_debug;
    assign data_valid = compute_result;

    // ========================================================================
    // DISPLAY 7 SEGMENTOS
    // ========================================================================
    wire [6:0] seg_ah_abcdefg;
    hex7seg_struct u_hex (.hex(leds_debug), .seg(seg_ah_abcdefg));
    
    localparam bit COMMON_ANODE = 1'b1;
    localparam bit PINS_GFEDCBA = 1'b1;
    localparam bit MIRROR_LR    = 1'b0;
    
    wire [6:0] seg_mirror;
    assign seg_mirror = {seg_ah_abcdefg[6], seg_ah_abcdefg[1], seg_ah_abcdefg[2],
                        seg_ah_abcdefg[3], seg_ah_abcdefg[4], seg_ah_abcdefg[5],
                        seg_ah_abcdefg[0]};
    
    wire [6:0] seg_sel;
    assign seg_sel = ({7{~MIRROR_LR}} & seg_ah_abcdefg) | 
                    ({7{MIRROR_LR}} & seg_mirror);
    
    wire [6:0] seg_ordered;
    wire [6:0] seg_gfedcba_order;
    assign seg_gfedcba_order = {seg_sel[0], seg_sel[1], seg_sel[2], 
                               seg_sel[3], seg_sel[4], seg_sel[5], seg_sel[6]};
    
    assign seg_ordered = ({7{PINS_GFEDCBA}} & seg_gfedcba_order) |
                        ({7{~PINS_GFEDCBA}} & seg_sel);
    
    wire [6:0] seg_inverted;
    assign seg_inverted[0] = ~seg_ordered[0];
    assign seg_inverted[1] = ~seg_ordered[1];
    assign seg_inverted[2] = ~seg_ordered[2];
    assign seg_inverted[3] = ~seg_ordered[3];
    assign seg_inverted[4] = ~seg_ordered[4];
    assign seg_inverted[5] = ~seg_ordered[5];
    assign seg_inverted[6] = ~seg_ordered[6];
    
    assign display = ({7{~COMMON_ANODE}} & seg_ordered) | 
                    ({7{COMMON_ANODE}} & seg_inverted);

    // ========================================================================
    // PWM
    // ========================================================================
    localparam int unsigned PWM_CNTR_BITS = 11;
    
    wire pwm_en;
    assign pwm_en = handshake_ok;
    
    wire pwm_raw;
    pwm16_struct #(.CNTR_BITS(PWM_CNTR_BITS)) u_pwm (
        .clk(clk),
        .en(pwm_en),
        .duty(leds_debug),
        .pwm_out(pwm_raw)
    );
    
    assign pwm_out = pwm_raw;
    assign pwm_led = pwm_raw ^ PWM_LED_ACTIVE_LOW;

endmodule