module i2c (
    //Entradas:
    input wire rst,
    input wire clk,
    input wire start,
    //Salidas:
    inout wire sda,
    output reg scl,
    output reg done,
    output reg busy
);

    //Parametros:
    parameter  divF = 4;

    //Estados:
    parameter START   = 4'b0000; // 0
    parameter ADDRESS = 4'b0001; // 1
    parameter RW      = 4'b0010; // 2
    parameter ACK     = 4'b0011; // 3 
    parameter DATA    = 4'b0100; // 4
    parameter ACK_2   = 4'b0101; // 5
    parameter STOP    = 4'b0110; // 60

    // Registros:
    reg [3:0] state, next_state;
    reg [3:0] bit_count;
    reg [2:0] div_count;
    reg       clk_div;
    reg [7:0] cycles;
    reg [6:0] byte_address = 7'b1010101;
    reg [7:0] data_byte    = 8'b10101010; // dato interno de ejemplo: no existe puerto de datos en la interfaz
    reg       rw_bit       = 1'b0;        // 0 = escritura; no existe puerto para seleccionar lectura
    reg       ack_bit;                    // ultimo bit de ACK/NACK muestreado

    // Tristate:
    reg sda_out;
    reg sda_enable;
    wire sda_in;
    assign sda = sda_enable ? sda_out : 1'bz;
    assign sda_in = sda;

    // Logica de cambio de estado:
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= START;
        end else begin
            state <= next_state;
        end
    end

    // Divisor de reloj para SCL (unico driver de div_count/clk_div):
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            div_count <= 0;
            clk_div   <= 1'b1;
        end else if (state == START && !start) begin
            // Mientras se espera 'start' se mantiene la fase sincronizada
            // para garantizar la condicion START correcta al arrancar.
            div_count <= 0;
            clk_div   <= 1'b1;
        end else if (div_count == divF-1) begin
            div_count <= 0;
            clk_div   <= ~clk_div;
        end else begin
            div_count <= div_count + 1;
        end
    end

    // Contadores de ciclo y de bit (unico driver):
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bit_count <= 0;
            cycles    <= 0;
        end else if (state != next_state) begin
            bit_count <= 0;
            cycles    <= 0;
        end else if (state == START && !start) begin
            cycles <= 0;
        end else if (cycles == 2*divF-1) begin
            cycles <= 0;
            if (state == ADDRESS || state == DATA) begin
                bit_count <= bit_count + 1;
            end
        end else begin
            cycles <= cycles + 1;
        end
    end

    // Muestreo del bit de ACK/NACK, a mitad de la fase alta de SCL:
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ack_bit <= 1'b1;
        end else if ((state == ACK || state == ACK_2) && cycles == divF-1) begin
            ack_bit <= sda_in;
        end
    end

    // busy: activo desde que se acepta 'start' hasta terminar STOP:
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy <= 1'b0;
        end else if (state == START && !start) begin
            busy <= 1'b0;
        end else begin
            busy <= 1'b1;
        end
    end

    // done: pulso de un ciclo al completar la condicion STOP:
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 1'b0;
        end else if (state == STOP && next_state == START) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    //Logica de estado futuro:
    always @(*) begin
        next_state = state;
        case (state)
            START: begin
                next_state = START;
                if (start && cycles == (2*divF-1)) begin
                    next_state = ADDRESS;
                end
            end
            ADDRESS: begin
                next_state = ADDRESS;
                if (bit_count == 6 && cycles == (2*divF-1)) begin
                    next_state = RW;
                end
            end
            RW: begin
                next_state = RW;
                if (cycles == (2*divF-1)) begin
                    next_state = ACK;
                end
            end
            ACK: begin
                next_state = ACK;
                if (cycles == (2*divF-1)) begin
                    next_state = ack_bit ? STOP : DATA; // ack_bit=1 (NACK) aborta; 0 (ACK) continua
                end
            end
            DATA: begin
                next_state = DATA;
                if (bit_count == 7 && cycles == (2*divF-1)) begin
                    next_state = ACK_2;
                end
            end
            ACK_2: begin
                next_state = ACK_2;
                if (cycles == (2*divF-1)) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                next_state = STOP;
                if (cycles == (2*divF-1)) begin
                    next_state = START;
                end
            end
            default: next_state = START;
        endcase
    end

    // Logica de salida:
    always @(*) begin
        scl = clk_div;
        sda_out = 1'b1;
        sda_enable = 1'b1;
        case (state)
            START: begin
                sda_enable = 1'b1;
                sda_out = (start && (cycles > divF/4)) ? 1'b0 : 1'b1;
            end
            ADDRESS: begin
                sda_enable = 1'b1;
                sda_out = byte_address[6 - bit_count];
            end
            RW: begin
                sda_enable = 1'b1;
                sda_out = rw_bit;
            end
            ACK: begin
                sda_enable = 1'b0; // libera el bus para leer el ACK del esclavo
            end
            DATA: begin
                sda_enable = 1'b1;
                sda_out = data_byte[7 - bit_count];
            end
            ACK_2: begin
                if (cycles < divF) begin
                    sda_enable = 1'b0; // fase alta: libera el bus para leer el ACK del esclavo
                end else begin
                    sda_enable = 1'b1;
                    sda_out = 1'b0;    // fase baja: prepara SDA en 0 para la condicion STOP
                end
            end
            STOP: begin
                sda_enable = 1'b1;
                sda_out = (cycles > divF/4) ? 1'b1 : 1'b0;
            end
        endcase
    end
endmodule
