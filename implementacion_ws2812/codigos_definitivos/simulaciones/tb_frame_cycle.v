`timescale 1ns/1ns
// Testbench auxiliar del top estatico: NUM_LEDS reducido a 2 solo
// para verificar rapido que, tras terminar el frame, el top fuerza
// DOUT en bajo (codigo RES) y luego reinicia el envio desde el LED 0.
module tb_frame_cycle;

    reg clk = 0;
    reg rst_n = 0;
    wire dout;

    always #20 clk = ~clk; // 25 MHz

    ws2812_matrix_top #(
        .NUM_LEDS(2),
        .HEX_FILE("corazon.hex"),
        .TRST_CYC(1250)
    ) dut (
        .clk  (clk),
        .rst_n(rst_n),
        .dout (dout)
    );

    time last_edge = 0;
    integer bits_seen = 0;

    always @(dout) begin
        if ($time > 0)
            $display("t=%0t dout=%b prev_width=%0dns state=%b init_m=%b array_done=%b",
                      $time, dout, $time-last_edge, dut.state, dut.init_m, dut.array_done);
        last_edge = $time;
    end

    initial begin
        #100 rst_n = 1;
        #150000;
        $display("fin de simulacion");
        $finish;
    end

endmodule
