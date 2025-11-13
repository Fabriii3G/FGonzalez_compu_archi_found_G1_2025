// ============================================================================
// SENSOR_CAPTURE: Captura 1 bit del sensor cada vez que se presiona el botón
// Guarda 4 bits en total (1 bit por cada pulsación del botón)
// Estilo completamente estructural (sin if/case/?/for/generate)
// ============================================================================
module sensor_capture (
    input  logic       clk,          // Reloj del sistema (ej: 50 MHz)
    input  logic       rst_n,        // Reset activo bajo
    input  logic       sensor_data,  // Entrada del sensor (1 bit)
    input  logic       capture_btn,  // Botón: captura 1 bit por pulsación
    output logic [3:0] stored_data,  // 4 bits capturados
    output logic       data_valid    // Se activa cuando se capturan los 4 bits
);

    // ============================================
    // SINCRONIZACIÓN DEL SENSOR (2 etapas)
    // ============================================
    logic sensor_sync1, sensor_sync2;
    
    dffeas u_sens_s1 (.q(sensor_sync1), .d(sensor_data), .clk(clk),
                      .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                      .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    dffeas u_sens_s2 (.q(sensor_sync2), .d(sensor_sync1), .clk(clk),
                      .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                      .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    
    // ============================================
    // SINCRONIZACIÓN DEL BOTÓN (2 etapas)
    // ============================================
    logic btn_sync1, btn_sync2, btn_prev;
    
    dffeas u_btn_s1 (.q(btn_sync1), .d(capture_btn), .clk(clk),
                     .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                     .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    dffeas u_btn_s2 (.q(btn_sync2), .d(btn_sync1), .clk(clk),
                     .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                     .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    
    // ============================================
    // DETECTOR DE FLANCO ASCENDENTE DEL BOTÓN
    // ============================================
    dffeas u_btn_prev (.q(btn_prev), .d(btn_sync2), .clk(clk),
                       .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                       .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    // Detecta cuando presionas el botón (0→1)
    wire btn_edge = btn_sync2 & ~btn_prev;
    
    
    // ============================================
    // CONTADOR DE BITS CAPTURADOS (0 a 4)
    // ============================================
    // Cuenta cuántos bits se han capturado
    logic [2:0] bit_count;  // 0, 1, 2, 3, 4
    
    // Incrementar contador cuando se presiona botón Y no hemos llegado a 4
    wire count_not_4 = ~(bit_count[2] & ~bit_count[1] & ~bit_count[0]);  // !(count==4)
    wire count_enable = btn_edge & count_not_4;
    
    // Sumador de 1: count_next = count + 1
    wire count_next_0 = count_enable ^ bit_count[0];
    wire carry_0      = count_enable & bit_count[0];
    
    wire count_next_1 = carry_0 ^ bit_count[1];
    wire carry_1      = carry_0 & bit_count[1];
    
    wire count_next_2 = carry_1 ^ bit_count[2];
    
    // Multiplexor: si count_enable, incrementar; sino, mantener
    wire cnt_d0 = (count_enable & count_next_0) | (~count_enable & bit_count[0]);
    wire cnt_d1 = (count_enable & count_next_1) | (~count_enable & bit_count[1]);
    wire cnt_d2 = (count_enable & count_next_2) | (~count_enable & bit_count[2]);
    
    dffeas u_cnt0 (.q(bit_count[0]), .d(cnt_d0), .clk(clk),
                   .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                   .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    dffeas u_cnt1 (.q(bit_count[1]), .d(cnt_d1), .clk(clk),
                   .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                   .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    dffeas u_cnt2 (.q(bit_count[2]), .d(cnt_d2), .clk(clk),
                   .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                   .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    
    // ============================================
    // DECODIFICADOR: detectar count == 0, 1, 2, 3
    // ============================================
    wire count_is_0 = ~bit_count[2] & ~bit_count[1] & ~bit_count[0];
    wire count_is_1 = ~bit_count[2] & ~bit_count[1] &  bit_count[0];
    wire count_is_2 = ~bit_count[2] &  bit_count[1] & ~bit_count[0];
    wire count_is_3 = ~bit_count[2] &  bit_count[1] &  bit_count[0];
    
    
    // ============================================
    // REGISTRO DE CAPTURA (4 bits)
    // ============================================
    // Cada bit se guarda cuando count coincide y hay btn_edge
    logic [3:0] data_reg;
    
    // Habilitar escritura en cada bit según el contador
    wire write_bit0 = btn_edge & count_is_0;
    wire write_bit1 = btn_edge & count_is_1;
    wire write_bit2 = btn_edge & count_is_2;
    wire write_bit3 = btn_edge & count_is_3;
    
    // Multiplexor para cada bit: si write, cargar sensor; sino, mantener
    wire data_next_0 = (write_bit0 & sensor_sync2) | (~write_bit0 & data_reg[0]);
    wire data_next_1 = (write_bit1 & sensor_sync2) | (~write_bit1 & data_reg[1]);
    wire data_next_2 = (write_bit2 & sensor_sync2) | (~write_bit2 & data_reg[2]);
    wire data_next_3 = (write_bit3 & sensor_sync2) | (~write_bit3 & data_reg[3]);
    
    dffeas u_dat0 (.q(data_reg[0]), .d(data_next_0), .clk(clk),
                   .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                   .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    dffeas u_dat1 (.q(data_reg[1]), .d(data_next_1), .clk(clk),
                   .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                   .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    dffeas u_dat2 (.q(data_reg[2]), .d(data_next_2), .clk(clk),
                   .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                   .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    dffeas u_dat3 (.q(data_reg[3]), .d(data_next_3), .clk(clk),
                   .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                   .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    
    // ============================================
    // FLAG DE VALIDEZ (se activa cuando count == 4)
    // ============================================
    logic valid_flag;
    wire count_is_4 = bit_count[2] & ~bit_count[1] & ~bit_count[0];
    wire valid_next = count_is_4 | valid_flag;
    
    dffeas u_valid (.q(valid_flag), .d(valid_next), .clk(clk),
                    .ena(1'b1), .clrn(rst_n), .prn(1'b1),
                    .asdata(1'b0), .aload(1'b0), .sclr(1'b0), .sload(1'b0));
    
    
    // ============================================
    // SALIDAS
    // ============================================
    assign stored_data = data_reg;
    assign data_valid  = valid_flag;

endmodule


// ============================================================================
// FUNCIONAMIENTO:
// ============================================================================
/*
EJEMPLO DE USO:

Paso | Sensor | Botón | Acción              | data_reg | count | valid
-----|--------|-------|---------------------|----------|-------|-------
  0  |   1    |   0   | (esperando)         |   0000   |   0   |   0
  1  |   1    |   1↑  | Captura bit[0] = 1  |   0001   |   1   |   0
  2  |   0    |   0   | (esperando)         |   0001   |   1   |   0
  3  |   0    |   1↑  | Captura bit[1] = 0  |   0001   |   2   |   0
  4  |   1    |   0   | (esperando)         |   0001   |   2   |   0
  5  |   1    |   1↑  | Captura bit[2] = 1  |   0101   |   3   |   0
  6  |   0    |   0   | (esperando)         |   0101   |   3   |   0
  7  |   1    |   1↑  | Captura bit[3] = 1  |   1101   |   4   |   1
  8  |   x    |   x   | COMPLETO!           |   1101   |   4   |   1

Resultado final: stored_data = 1101, data_valid = 1

Nota: Si presionas el botón una 5ta vez, no hace nada (count ya es 4)
Para capturar nuevos 4 bits, necesitas hacer reset.
*/