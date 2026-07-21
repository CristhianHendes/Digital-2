// =============================================================
// ws2812_matrix_top_anim.v
// Variante animada de ws2812_matrix_top.v (que queda intacto, sin
// modificar, para poder mandar a la FPGA el estatico o este segun
// convenga). Alterna entre HEX_FILE_A (corazon grande) y
// HEX_FILE_B (corazon chico) cada FRAMES_PER_IMAGE refrescos
// completos de la matriz, dando un efecto de "latido".
//
// El mux entre imagenes vive aparte, en led_mem_mux.v, y este top
// solo agrega el contador que decide CUANDO alternar frame_sel;
// las 3 FSMs de los diagramas (ctrl_ws, ctrl_wsled, ctrl_ws_arr)
// no se tocan.
// =============================================================
module ws2812_matrix_top_anim #(
    parameter NUM_LEDS         = 64,                     // 8x8
    parameter HEX_FILE_A       = "corazon.hex",           // corazon grande
    parameter HEX_FILE_B       = "corazon_pequeno.hex",   // corazon chico
    parameter TRST_CYC         = 12500,                   // 500 us @ 25 MHz (codigo RES/latch)
    parameter FRAMES_PER_IMAGE = 200                      // ~0.44 s por imagen @ 25MHz (ver nota abajo)
)(
    input  wire clk,     // 25 MHz
    input  wire rst_n,   // reset activo en bajo
    output wire dout     // hacia DIN del primer LED
);

    // Duracion aproximada de un refresco completo (64 LEDs x 24 bits,
    // ~1.4us/bit con el overhead de las FSMs) + TRST_CYC de latch:
    //   64*24*1.4us + 500us =~ 2.65 ms/refresco
    // FRAMES_PER_IMAGE=200 -> ~530 ms mostrando cada imagen.
    //
    // TRST_CYC subido de 1250 (50us, el minimo del datasheet oficial)
    // a 12500 (500us): muchos clones baratos de WS2812B/SK6812
    // necesitan bastante mas de 50us para re-latchear datos NUEVOS
    // (no solo repetir los mismos). Con 50us el primer frame (que
    // llega con mucho mas tiempo de por medio, viniendo del power-on)
    // s parece latchear bien, pero el re-latch entre frames distintos
    // fallaba silenciosamente: la imagen se quedaba fija en la
    // primera que si logro cargar, aunque frame_sel siguiera
    // alternando correctamente por dentro.

    localparam integer SIZE = $clog2(NUM_LEDS);

    localparam SEND  = 1'b0;
    localparam LATCH = 1'b1;

    reg        state;
    reg        init_m;
    reg [14:0] res_timer;
    reg        frame_sel;
    reg [7:0]  frame_count;

    wire array_dout;
    wire array_done;

    ws2812_led_array_anim #(
        .SIZE      (SIZE),
        .HEX_FILE_A(HEX_FILE_A),
        .HEX_FILE_B(HEX_FILE_B)
    ) u_array (
        .reset    (!rst_n),
        .clk      (clk),
        .init_m   (init_m),
        .rst_cmd  (1'b0),      // el RES/latch lo genera esta capa, igual que en el top estatico
        .frame_sel(frame_sel),
        .dout     (array_dout),
        .done     (array_done)
    );

    // Mismo secuenciador SEND/LATCH que ws2812_matrix_top.v; al volver
    // de LATCH a SEND se cuenta un refresco completo y, cada
    // FRAMES_PER_IMAGE refrescos, se alterna frame_sel.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= SEND;
            init_m      <= 1'b1;
            res_timer   <= 15'd0;
            frame_sel   <= 1'b0;
            frame_count <= 8'd0;
        end else begin
            case (state)
                SEND: begin
                    init_m <= 1'b1;
                    if (array_done) begin
                        state     <= LATCH;
                        init_m    <= 1'b0;
                        res_timer <= 15'd0;
                    end
                end
                LATCH: begin
                    init_m <= 1'b0;
                    if (res_timer == TRST_CYC - 1) begin
                        state <= SEND;
                        if (frame_count == FRAMES_PER_IMAGE - 1) begin
                            frame_count <= 8'd0;
                            frame_sel   <= ~frame_sel;
                        end else begin
                            frame_count <= frame_count + 8'd1;
                        end
                    end else begin
                        res_timer <= res_timer + 15'd1;
                    end
                end
                default: state <= SEND;
            endcase
        end
    end

    assign dout = (state == LATCH) ? 1'b0 : array_dout;

endmodule
