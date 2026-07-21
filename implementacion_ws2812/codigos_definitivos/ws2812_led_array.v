// =============================================================
// ws2812_led_array.v - Recorre los N_LEDS de la matriz y envia
// el color de cada uno. Junta el nivel "FSM(seend_N_leds).jpg"
// (ctrl_ws_arr) con el nivel de un solo LED (ws2812_led.v).
//
// SIZE=6 -> N_LEDS = 2**6 = 64 (matriz 8x8).
//
// Nota de ancho: 'address' se mantiene en 8 bits (igual que
// count_addr/comp_ws_arr) y solo se recortan sus SIZE bits bajos
// para direccionar la memoria. Si 'address' se declarara con
// solo SIZE bits, la comparacion contra N_LEDS truncaria el
// valor y 'z' nunca se activaria para N_LEDS que no sean
// potencia exacta de la anchura del contador (256).
// =============================================================
module ws2812_led_array #(
    parameter SIZE    = 6,
    parameter HEX_FILE = "corazon.hex"
)(
    input    reset,
    input    clk,
    input    init_m,
    input    rst_cmd,
    output   dout,
    output   done
);

localparam N_LEDS = 2**SIZE;

wire init_led;
wire rst_addr;
wire inc_addr;
wire done_led;
wire z;
wire [7:0] address;
wire [23:0] rgb;


led_mem     #(.addr_lenght( SIZE ), .HEX_FILE(HEX_FILE) )  mem0  ( .clk(clk), .address(address[SIZE-1:0]), .data_r(rgb) );
ws2812_led  ws2812_0( .clk(clk), .reset(rst_addr), .rgb(rgb), .init(init_led), .rst_cmd(rst_cmd), .dout(dout), .done(done_led) );
count_addr  count0  ( .clk(clk), .rst(rst_addr), .inc(inc_addr), .address(address) );
ctrl_ws_arr ctrl0   ( .clk(clk), .reset(reset), .init_m(init_m), .done_led(done_led), .z(z), .done(done), .init_led(init_led), .rst(rst_addr), .inc(inc_addr) );
comp_ws_arr comp0   ( .in1(address), .in2(N_LEDS[7:0]), .z(z) );


endmodule
