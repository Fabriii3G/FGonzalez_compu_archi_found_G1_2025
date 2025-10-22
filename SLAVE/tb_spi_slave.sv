
// Testbench simple para verificar SPI Slave
module tb_spi_slave;
    logic clk;
    logic rst_n;
    logic spi_sck;
    logic spi_mosi;
    logic spi_cs_n;
    logic spi_miso;
    logic [3:0] leds;
    logic handshake_ok;
    logic data_valid;
    
    // Instancia del DUT
    spi_slave_fsm dut (
        .clk(clk),
        .rst_n(rst_n),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_cs_n(spi_cs_n),
        .spi_miso(spi_miso),
        .leds(leds),
        .handshake_ok(handshake_ok),
        .data_valid(data_valid)
    );
    
    // Generador de reloj 50 MHz
    initial begin
        clk = 0;
        forever #10ns clk = ~clk;  // 50 MHz = 20ns período
    end
    
    // Tarea para enviar un byte por SPI
    task automatic send_spi_byte(input logic [7:0] data);
        integer i;
        begin
            spi_cs_n = 0;  // Activar CS
            #2us;          // Esperar estabilización
            
            // Enviar 8 bits (MSB primero, CPOL=0, CPHA=0)
            for (i = 7; i >= 0; i--) begin
                spi_mosi = data[i];
                #2us;
                spi_sck = 1;  // Flanco de subida (slave captura)
                #2us;
                spi_sck = 0;  // Flanco de bajada (slave actualiza MISO)
                #2us;
            end
            
            spi_cs_n = 1;  // Desactivar CS
            #10us;         // Esperar procesamiento
        end
    endtask
    
    // Estímulos
    initial begin
        // Inicialización
        rst_n = 0;
        spi_sck = 0;
        spi_mosi = 0;
        spi_cs_n = 1;
        
        // Dump para ver formas de onda
        $dumpfile("spi_slave.vcd");
        $dumpvars(0, tb_spi_slave);
        
        // Reset
        #100ns;
        rst_n = 1;
        #100ns;
        
        $display("=== Test 1: Handshake ===");
        send_spi_byte(8'hA5);
        
        if (handshake_ok) begin
            $display("✓ Handshake OK detectado");
        end else begin
            $display("✗ Handshake NO detectado");
        end
        
        #50us;
        
        $display("=== Test 2: Enviar patrón de LEDs ===");
        send_spi_byte(8'h05);  // 0b0101
        
        #50us;
        
        if (leds == 4'b0101) begin
            $display("✓ LEDs actualizados correctamente: %b", leds);
        end else begin
            $display("✗ LEDs incorrectos. Esperado: 0101, Recibido: %b", leds);
        end
        
        $display("=== Test 3: Otro patrón ===");
        send_spi_byte(8'h0A);  // 0b1010
        
        #50us;
        
        if (leds == 4'b1010) begin
            $display("✓ LEDs actualizados correctamente: %b", leds);
        end else begin
            $display("✗ LEDs incorrectos. Esperado: 1010, Recibido: %b", leds);
        end
        
        #100us;
        
        $display("=== Simulación completada ===");
        $finish;
    end
    
    // Monitor para ver qué pasa en MISO
    initial begin
        $monitor("Tiempo=%0t | CS=%b SCK=%b MOSI=%b MISO=%b | LEDs=%b | HS=%b DV=%b | Estado=%s",
                 $time, spi_cs_n, spi_sck, spi_mosi, spi_miso, leds, 
                 handshake_ok, data_valid, dut.current_state.name());
    end
    
endmodule