// Memoria de solo lectura con los colores de la matriz, cargada
// desde HEX_FILE (formato $readmemh, orden GRB, ver img2hex.py).
module led_mem #(
    parameter addr_lenght = 6,
    parameter HEX_FILE    = "corazon.hex"
) (
   input                          clk,
   input      [addr_lenght -1 :0] address,
   output reg [23:0]              data_r
);
    reg [23:0] MEM [0: (2**(addr_lenght) - 1)];
    initial begin
        $readmemh(HEX_FILE, MEM);
    end

    always @(negedge clk) begin
        data_r <= MEM[address];
    end

endmodule
