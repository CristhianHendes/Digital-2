`timescale 1ns/1ns
// Testbench del top animado a escala real (NUM_LEDS=64, igual que
// el hardware) pero con FRAMES_PER_IMAGE bajo para poder observar
// varios toggles sin simular cientos de ms reales. Imprime cuando
// frame_sel cambia, para confirmar que el contador de alternancia
// funciona con el ancho de direccion real (SIZE=6).
module tb_anim_real;

    reg clk = 0;
    reg rst_n = 0;
    wire dout;

    always #20 clk = ~clk; // 25 MHz

    ws2812_matrix_top_anim #(
        .NUM_LEDS        (64),
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
            $display("t=%0t frame_sel -> %b  frame_count=%0d state=%b",
                       $time, dut.frame_sel, dut.frame_count, dut.state);
            last_sel = dut.frame_sel;
        end
    end

    initial begin
        #100 rst_n = 1;
        #14000000; // ~14ms: deberia cubrir varios refrescos completos (~2.2ms c/u)
        $display("fin de simulacion");
        $finish;
    end

endmodule
