`timescale 1ns/1ns
// Decodifica dout bit a bit y arma el color de cada LED, para
// comparar directamente contra corazon.hex / corazon_pequeno.hex
// antes y despues de que frame_sel cambie. Umbral de decision:
// >600ns de alto = bit 1, si no = bit 0 (T0H=400ns, T1H=800ns).
//
// Esta fue la prueba que confirmo, bit a bit, que el RTL era 100%
// correcto (frame=0 == corazon.hex, frame=1 == corazon_pequeno.hex)
// cuando el bug real resulto estar en TRST_CYC siendo muy corto
// para el hardware (ver ws2812_matrix_top_anim.v).
module tb_anim_decode;

    reg clk = 0;
    reg rst_n = 0;
    wire dout;

    always #20 clk = ~clk; // 25 MHz

    ws2812_matrix_top_anim #(
        .NUM_LEDS        (64),
        .HEX_FILE_A      ("corazon.hex"),
        .HEX_FILE_B      ("corazon_pequeno.hex"),
        .TRST_CYC        (1250),
        .FRAMES_PER_IMAGE(1)
    ) dut (
        .clk  (clk),
        .rst_n(rst_n),
        .dout (dout)
    );

    integer bit_idx  = 0;   // 0..23 dentro del LED actual
    integer led_idx  = 0;   // 0..63
    reg [23:0] shift_reg = 0;
    time rise_t = 0;
    reg prev_dout = 0;
    integer frame_num = 0;
    reg last_sel = 0;

    always @(posedge clk) begin
        if (dut.frame_sel !== last_sel) begin
            $display("--- frame_sel -> %b (nuevo frame numero %0d) ---", dut.frame_sel, frame_num);
            last_sel = dut.frame_sel;
        end
    end

    always @(dout) begin
        if (dout && !prev_dout) begin
            rise_t = $time;
        end else if (!dout && prev_dout) begin
            // flanco de bajada: ancho del pulso alto = bit
            if (($time - rise_t) > 600) begin
                shift_reg = {shift_reg[22:0], 1'b1};
            end else begin
                shift_reg = {shift_reg[22:0], 1'b0};
            end
            bit_idx = bit_idx + 1;
            if (bit_idx == 24) begin
                $display("frame=%0d led=%0d color=%h", frame_num, led_idx, shift_reg);
                bit_idx = 0;
                led_idx = led_idx + 1;
                if (led_idx == 64) begin
                    led_idx = 0;
                    frame_num = frame_num + 1;
                end
            end
        end
        prev_dout = dout;
    end

    initial begin
        #100 rst_n = 1;
        #10000000; // ~10ms: deberia cubrir ~4 frames completos (FRAMES_PER_IMAGE=1)
        $display("fin de simulacion");
        $finish;
    end

endmodule
