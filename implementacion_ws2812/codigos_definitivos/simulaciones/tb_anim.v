`timescale 1ns/1ns
// Testbench auxiliar del top animado: NUM_LEDS=2 y
// FRAMES_PER_IMAGE=2 solo para verificar rapido que frame_sel
// alterna. TRST_CYC se reduce a 1250 (el minimo del datasheet)
// unicamente para que la simulacion no tarde tanto; en hardware
// real el top usa 12500 (500us) por el problema de latch de los
// clones WS2812B/SK6812 (ver nota en ws2812_matrix_top_anim.v).
module tb_anim;

    reg clk = 0;
    reg rst_n = 0;
    wire dout;

    always #20 clk = ~clk; // 25 MHz

    ws2812_matrix_top_anim #(
        .NUM_LEDS        (2),
        .HEX_FILE_A      ("corazon.hex"),
        .HEX_FILE_B      ("corazon_pequeno.hex"),
        .TRST_CYC        (1250),
        .FRAMES_PER_IMAGE(2)
    ) dut (
        .clk  (clk),
        .rst_n(rst_n),
        .dout (dout)
    );

    reg last_sel = 0;
    always @(posedge clk) begin
        if (dut.frame_sel !== last_sel) begin
            $display("t=%0t frame_sel cambio a %b (frame_count=%0d)", $time, dut.frame_sel, dut.frame_count);
            last_sel = dut.frame_sel;
        end
    end

    initial begin
        #100 rst_n = 1;
        #700000;
        $display("fin de simulacion");
        $finish;
    end

endmodule
