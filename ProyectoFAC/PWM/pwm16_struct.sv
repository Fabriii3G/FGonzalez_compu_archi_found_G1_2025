// PWM 16 niveles (usa 4 MSB del contador como fase), 
// f_pwm = f_clk / 2^CNTR_BITS   (requerido: CNTR_BITS >= 4)
module pwm16_struct #(
  parameter CNTR_BITS = 11
)(
  input  logic       clk,
  input  logic       en,        // habilitación externa/seguridad
  input  logic [3:0] duty,      // 0..15
  output logic       pwm_out
);
  logic [CNTR_BITS-1:0] cnt;
  contadorUpN #(.WIDTH(CNTR_BITS)) u_cnt(.clk(clk), .q(cnt));

  // Fase: 4 bits más altos del contador
  logic [3:0] phase4;
  assign phase4 = cnt[CNTR_BITS-1 -: 4];

  // phase4 < duty (estricto) por restador
  logic lt;
  cmp_lt_strict #(.WIDTH(4)) u_cmp(.x(phase4), .y(duty), .lt(lt));

  // Salida PWM
  assign pwm_out = en & lt;
endmodule
