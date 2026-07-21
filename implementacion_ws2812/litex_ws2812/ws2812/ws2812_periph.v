module ws2812_periph (
    input        reset,
    input        clk,
    input        init_m,
    input        rst_cmd,

    input [23:0] w_data,
    input [7:0]  w_address,

    input        we_a,
    output       dout,
    output       done
);

parameter SIZE   = 8;
parameter N_LEDS = 8'h2**SIZE;

// Tiempos del protocolo WS2812, en ciclos del reloj "clk" que
// realmente llega a este modulo. IMPORTANTE: los defaults de abajo
// (y los de ws2812.v) asumen 25MHz; si "clk" corre a otra frecuencia
// (p.ej. sys_clk_freq=60MHz en el SoC LiteX) hay que sobreescribir
// estos 4 parametros con los ciclos correctos, o los pulsos quedan
// fuera de la tolerancia del datasheet WS2812 y los LEDs no
// reconocen ningun dato (sintoma: no enciende nada, ni basura).
parameter T0H = 15'd10;
parameter T1H = 15'd20;
parameter PER = 15'd31;
parameter RES = 15'd12500;

wire init_led;
wire rst_addr;
wire inc_addr;
wire done_led;
wire z;
// count_addr tiene un contador nativo de 8 bits; si aca lo
// truncaramos a [SIZE-1:0] (p.ej. 6 bits para N_LEDS=64), el
// contador NUNCA podria alcanzar el valor N_LEDS=2**SIZE (maximo
// representable en SIZE bits es 2**SIZE - 1), por lo que "z" jamas
// se activaria y ctrl_ws_arr quedaria en loop infinito sin fin de
// pasada (mismo bug de truncamiento ya visto y corregido en
// codigos_2/ws2812_led_array.v). Se mantiene address a 8 bits para
// la comparacion contra N_LEDS y solo se trunca al indexar la
// memoria.
wire [7:0] address;
wire [23:0] rgb;


led_mem_dual  #(.addr_lenght( SIZE ) )  mem0  ( .clk(clk), .w_address(w_address), .w_data(w_data), .we_a(we_a), .address(address[SIZE-1:0]), .data_r(rgb) );
ws2812_led  #(.T0H(T0H), .T1H(T1H), .PER(PER), .RES(RES))
            ws2812_0( .clk(clk), .reset(reset), .rgb(rgb), .init(init_led), .rst_cmd(rst_cmd), .dout(dout), .done(done_led) );
count_addr  count0  ( .clk(clk), .rst(rst_addr), .inc(inc_addr), .address(address) );
ctrl_ws_arr ctrl0   ( .clk(clk), .reset(reset), .init_m(init_m), .done_led(done_led), .z(z), .done(done), .init_led(init_led), .rst(rst_addr), .inc(inc_addr) );
comp_ws_arr comp0   ( .in1(address), .in2(N_LEDS), .z(z) );


endmodule
