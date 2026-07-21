// =============================================================
// ws2812_led_array_anim.v - Igual que ws2812_led_array.v (FSM
// "seend_N_leds") pero usando led_mem_mux en vez de led_mem, para
// poder alternar entre dos imagenes via frame_sel. No modifica
// ws2812_led_array.v: son dos modulos independientes, se elige
// cual sintetizar segun el top que se use (estatico o animado).
// =============================================================
module ws2812_led_array_anim #(
    parameter SIZE       = 6,
    parameter HEX_FILE_A = "corazon.hex",
    parameter HEX_FILE_B = "corazon_pequeno.hex"
)(
    input    reset,
    input    clk,
    input    init_m,
    input    rst_cmd,
    input    frame_sel,
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


led_mem_mux #(
    .addr_lenght(SIZE),
    .HEX_FILE_A (HEX_FILE_A),
    .HEX_FILE_B (HEX_FILE_B)
) mem0 (
    .clk      (clk),
    .address  (address[SIZE-1:0]),
    .frame_sel(frame_sel),
    .data_r   (rgb)
);
ws2812_led  ws2812_0( .clk(clk), .reset(rst_addr), .rgb(rgb), .init(init_led), .rst_cmd(rst_cmd), .dout(dout), .done(done_led) );
count_addr  count0  ( .clk(clk), .rst(rst_addr), .inc(inc_addr), .address(address) );
ctrl_ws_arr ctrl0   ( .clk(clk), .reset(reset), .init_m(init_m), .done_led(done_led), .z(z), .done(done), .init_led(init_led), .rst(rst_addr), .inc(inc_addr) );
comp_ws_arr comp0   ( .in1(address), .in2(N_LEDS[7:0]), .z(z) );


endmodule
