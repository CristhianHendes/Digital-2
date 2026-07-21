// =============================================================
// ws2812_matrix_top.v
// Controlador de una matriz WS2812B 8x8 (64 LEDs) construido a
// partir de las 3 maquinas de estado documentadas en
// Diagramas_datapath.pdf / FSM(*).jpg, en vez de un unico FSM
// monolitico (como ws2812b_controller.v en ../Codigos):
//
//   ws2812_led_array (ctrl_ws_arr.v)  -> FSM(seend_N_leds).jpg
//     ws2812_led (ctrl_wsled.v)       -> FSM(rest).jpg
//       ws2812 (ctrl_ws.v)           -> FSM(send1_0).jpg
//
// Estas 3 FSMs solo saben enviar UNA pasada por los 64 LEDs.
// Esta capa agrega la secuencia que falta para un display
// continuo: enviar el frame y despues mantener DOUT en bajo
// >= 50us (codigo RES/latch) antes de repetir, igual que hace
// el estado ST_RESET del controlador monolitico de Codigos.
//
// Reloj objetivo: 25 MHz (Colorlight i9) -> 1 ciclo = 40 ns.
// =============================================================
module ws2812_matrix_top #(
    parameter NUM_LEDS = 64,          // 8x8
    parameter HEX_FILE = "corazon.hex",
    parameter TRST_CYC = 1250         // >= 50 us @ 25 MHz (igual que RES en ws2812.v)
)(
    input  wire clk,     // 25 MHz
    input  wire rst_n,   // reset activo en bajo
    output wire dout     // hacia DIN del primer LED
);

    localparam integer SIZE = $clog2(NUM_LEDS);

    localparam SEND  = 1'b0;
    localparam LATCH = 1'b1;

    reg        state;
    reg        init_m;
    reg [11:0] res_timer;

    wire array_dout;
    wire array_done;

    ws2812_led_array #(
        .SIZE    (SIZE),
        .HEX_FILE(HEX_FILE)
    ) u_array (
        .reset  (!rst_n),
        .clk    (clk),
        .init_m (init_m),
        .rst_cmd(1'b0),      // el RES/latch lo genera esta capa (ver mas abajo)
        .dout   (array_dout),
        .done   (array_done)
    );

    // Secuenciador: envia un frame completo (los NUM_LEDS colores)
    // y luego fuerza la linea en bajo durante TRST_CYC ciclos antes
    // de reiniciar el ciclo, para que los LEDs hagan latch del dato.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= SEND;
            init_m    <= 1'b1;
            res_timer <= 12'd0;
        end else begin
            case (state)
                SEND: begin
                    init_m <= 1'b1;
                    if (array_done) begin
                        state     <= LATCH;
                        init_m    <= 1'b0;
                        res_timer <= 12'd0;
                    end
                end
                LATCH: begin
                    init_m <= 1'b0;
                    if (res_timer == TRST_CYC - 1) begin
                        state <= SEND;
                    end else begin
                        res_timer <= res_timer + 12'd1;
                    end
                end
                default: state <= SEND;
            endcase
        end
    end

    assign dout = (state == LATCH) ? 1'b0 : array_dout;

endmodule
