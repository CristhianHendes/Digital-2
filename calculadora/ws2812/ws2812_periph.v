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

wire init_led;
wire rst_addr;
wire inc_addr;
wire done_led;
wire z;
wire [SIZE-1:0] address;
wire [23:0] rgb;


led_mem_dual  #(.addr_lenght( SIZE ) )  mem0  ( .clk(clk), .w_address(w_address), .w_data(w_data), .we_a(we_a), .address(address), .data_r(rgb) );
ws2812_led  ws2812_0( .clk(clk), .reset(reset), .rgb(rgb), .init(init_led), .rst_cmd(rst_cmd), .dout(dout), .done(done_led) );
count_addr  count0  ( .clk(clk), .rst(rst_addr), .inc(inc_addr), .address(address) );
ctrl_ws_arr ctrl0   ( .clk(clk), .reset(reset), .init_m(init_m), .done_led(done_led), .z(z), .done(done), .init_led(init_led), .rst(rst_addr), .inc(inc_addr) );
comp_ws_arr comp0   ( .in1(address), .in2(N_LEDS), .z(z) );


endmodule
