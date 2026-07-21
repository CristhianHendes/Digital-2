// =============================================================
// led_mem_mux.v - Selector de imagen (mux) para animar entre dos
// memorias ($readmemh) sin tocar led_mem.v ni el datapath de las
// 3 FSMs. Instancia dos led_mem de solo lectura (imagen A y B) y
// entrega el color de la que este seleccionada via frame_sel.
// =============================================================
module led_mem_mux #(
    parameter addr_lenght = 6,
    parameter HEX_FILE_A  = "corazon.hex",         // imagen 0 (frame_sel=0)
    parameter HEX_FILE_B  = "corazon_pequeno.hex"  // imagen 1 (frame_sel=1)
) (
    input                          clk,
    input      [addr_lenght-1:0]   address,
    input                          frame_sel,
    output                  [23:0] data_r
);

    wire [23:0] data_a;
    wire [23:0] data_b;

    led_mem #(
        .addr_lenght(addr_lenght),
        .HEX_FILE   (HEX_FILE_A)
    ) mem_a (
        .clk    (clk),
        .address(address),
        .data_r (data_a)
    );

    led_mem #(
        .addr_lenght(addr_lenght),
        .HEX_FILE   (HEX_FILE_B)
    ) mem_b (
        .clk    (clk),
        .address(address),
        .data_r (data_b)
    );

    // led_mem registra data_r en negedge clk; ambas memorias tienen
    // la misma latencia, asi que el mux puede ser combinacional.
    assign data_r = frame_sel ? data_b : data_a;

endmodule
