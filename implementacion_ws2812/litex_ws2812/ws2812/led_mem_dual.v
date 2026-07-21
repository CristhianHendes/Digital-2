module led_mem_dual#(
    parameter addr_lenght = 8
) (
   input                           clk,
   input      [addr_lenght -1 :0]  address,
   output reg [23:0]               data_r,
//
   input                           we_a,
   input      [addr_lenght -1 :0]  w_address,
   input      [23:0]               w_data
);
    reg [23:0] MEM [0: (2**(addr_lenght) - 1)];
    initial begin
        $readmemh("/home/cristhianhendes/digital_2/Digital-2/implementacion_ws2812/litex_ws2812/ws2812/display.hex",MEM);
    end

    always @(negedge clk) begin
        data_r <= MEM[address];
    end

//------------------------------------------------------------------
// write port A
//------------------------------------------------------------------

    always @(negedge clk)
    begin
        if (we_a) begin
            MEM[w_address] <= w_data;
        end 
    end


endmodule
