`timescale 1ns/1ns
// Testbench del top estatico (ws2812_matrix_top.v), escala real
// (64 LEDs, corazon.hex). Solo imprime los flancos de dout con su
// ancho, para verificar visualmente T0H=400ns / T1H=800ns y la
// carga secuencial de los colores.

module tb_ws2812_matrix_top;

    reg clk = 0;
    reg rst_n = 0;
    wire dout;

    always #20 clk = ~clk; // 25 MHz

    ws2812_matrix_top #(
        .NUM_LEDS(64),
        .HEX_FILE("corazon.hex"),
        .TRST_CYC(1250)
    ) dut (
        .clk  (clk),
        .rst_n(rst_n),
        .dout (dout)
    );

    integer edge_count = 0;
    time    last_edge  = 0;

    always @(dout) begin
        if ($time > 0) begin
            $display("t=%0t  dout=%b  width=%0dns", $time, dout, $time - last_edge);
        end
        last_edge = $time;
        edge_count = edge_count + 1;
    end

    initial begin
        #100 rst_n = 1;
        #200000; // ~200us: deberia cubrir bastante mas de 1 LED y llegar al RES
        $display("edges observados: %0d", edge_count);
        $finish;
    end

endmodule
