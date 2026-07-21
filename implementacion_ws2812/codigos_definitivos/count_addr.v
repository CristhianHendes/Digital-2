// Contador de direccion de LED (0..N_LEDS-1), 8 bits fijos.
// Se mantiene en 8 bits (en vez de parametrizarlo con SIZE) para
// que la comparacion en comp_ws_arr funcione para cualquier
// N_LEDS <= 255, no solo para potencias exactas de 2 (ver nota
// en ws2812_led_array.v).
module count_addr (
    input            clk,
    input            rst,
    input            inc,
    output reg [7:0] address

);
    always @(negedge clk ) begin
        if (rst)
            address <= 0;
        else begin
            if (inc)
                address <= address +1;
            else
                address <= address;
        end
    end
endmodule
