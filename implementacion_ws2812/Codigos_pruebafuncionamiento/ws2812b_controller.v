// =============================================================
// ws2812b_controller.v
// Controlador de 64 LEDs WS2812B en un solo modulo.
// Los colores se cargan desde un archivo .hex con $readmemh.
//
// Reloj objetivo: 25 MHz (Colorlight i9) -> 1 ciclo = 40 ns
//
// Timing segun datasheet (TH+TL = 1.25 us +/- 600 ns):
//   T0H = 0.40 us -> 10 ciclos
//   T0L = 0.85 us -> 21 ciclos (840 ns, dentro de tolerancia)
//   T1H = 0.80 us -> 20 ciclos
//   T1L = 0.45 us -> 11 ciclos (440 ns, dentro de tolerancia)
//   RES > 50 us   -> 2500 ciclos (100 us, con margen)
//
// Formato del .hex: 64 lineas de 24 bits (6 digitos hex) en
// orden GRB (el datasheet exige G7..G0, R7..R0, B7..B0),
// bit mas significativo primero.
//   Ejemplo: FF0000 = verde, 00FF00 = rojo, 0000FF = azul
// =============================================================

module ws2812b_controller #(
    parameter NUM_LEDS = 64,
    parameter HEX_FILE = "corazon.hex"
)(
    input  wire clk,     // 25 MHz
    input  wire rst_n,   // reset activo en bajo
    output reg  dout     // hacia DIN del primer LED
);

    // ---------------- Timing en ciclos @ 25 MHz ----------------
    localparam integer T0H_CYC  = 10;    // 400 ns
    localparam integer T0L_CYC  = 21;    // 840 ns
    localparam integer T1H_CYC  = 20;    // 800 ns
    localparam integer T1L_CYC  = 11;    // 440 ns
    localparam integer TRST_CYC = 2500;  // 100 us > 50 us

    // ---------------- Estados de la FSM ----------------
    localparam [1:0] ST_RESET = 2'd0,   // pulso de reset (linea en bajo)
                     ST_HIGH  = 2'd1,   // parte alta del bit
                     ST_LOW   = 2'd2;   // parte baja del bit

    // ---------------- Memoria de colores ----------------
    reg [23:0] led_mem [0:NUM_LEDS-1];
    initial $readmemh(HEX_FILE, led_mem);

    // ---------------- Registros ----------------
    reg [1:0]  state;
    reg [11:0] timer;     // alcanza para TRST_CYC = 2500
    reg [6:0]  led_idx;   // 7 bits: evita overflow al comparar con 63
    reg [4:0]  bit_idx;   // 0..23
    reg [23:0] shift;     // registro de desplazamiento, MSB primero

    // Bit actual y duraciones segun su valor
    wire        cur_bit = shift[23];
    wire [11:0] t_high  = cur_bit ? T1H_CYC[11:0] : T0H_CYC[11:0];
    wire [11:0] t_low   = cur_bit ? T1L_CYC[11:0] : T0L_CYC[11:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= ST_RESET;
            timer   <= 12'd0;
            led_idx <= 7'd0;
            bit_idx <= 5'd0;
            shift   <= 24'd0;
            dout    <= 1'b0;
        end else begin
            case (state)

                // ---------- Reset: linea en bajo >= 50 us ----------
                ST_RESET: begin
                    dout <= 1'b0;
                    if (timer == TRST_CYC - 1) begin
                        timer   <= 12'd0;
                        led_idx <= 7'd0;
                        bit_idx <= 5'd0;
                        shift   <= led_mem[0];
                        state   <= ST_HIGH;
                    end else begin
                        timer <= timer + 12'd1;
                    end
                end

                // ---------- Parte alta del bit ----------
                ST_HIGH: begin
                    dout <= 1'b1;
                    if (timer == t_high - 1) begin
                        timer <= 12'd0;
                        state <= ST_LOW;
                    end else begin
                        timer <= timer + 12'd1;
                    end
                end

                // ---------- Parte baja del bit ----------
                ST_LOW: begin
                    dout <= 1'b0;
                    if (timer == t_low - 1) begin
                        timer <= 12'd0;
                        if (bit_idx == 5'd23) begin
                            // Se enviaron los 24 bits del LED actual
                            bit_idx <= 5'd0;
                            if (led_idx == NUM_LEDS - 1) begin
                                // Ultimo LED: latch de datos con reset
                                led_idx <= 7'd0;
                                state   <= ST_RESET;
                            end else begin
                                led_idx <= led_idx + 7'd1;
                                shift   <= led_mem[led_idx + 7'd1];
                                state   <= ST_HIGH;
                            end
                        end else begin
                            bit_idx <= bit_idx + 5'd1;
                            shift   <= {shift[22:0], 1'b0};
                            state   <= ST_HIGH;
                        end
                    end else begin
                        timer <= timer + 12'd1;
                    end
                end

                default: state <= ST_RESET;
            endcase
        end
    end

endmodule