// Registro que retiene el divisor durante toda la division (se carga
// una sola vez al inicio; no necesita desplazarse como en mult/rsr.v
// porque el divisor no cambia de posicion en este algoritmo).
module divisor_reg (clk, in_B, load, s_B);
  input clk;
  input [31:0] in_B;
  input load;
  output reg [31:0] s_B;

always @(posedge clk)
  if (load)
    s_B <= in_B;

endmodule
