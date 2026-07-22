// Resta/comparacion de 33 bits: qr_hi son los 33 bits altos de s_qr
// (bits [63:31], es decir el residuo parcial de 32 bits MAS el bit que
// esta a punto de entrar desde la mitad baja este ciclo). Se le resta
// el divisor (extendido a 33 bits); si el resultado se hace negativo
// ("borrow", equivalente a diff[32]==1), el residuo parcial todavia es
// menor que el divisor y no se debe restar.
module sub_cmp33 (qr_hi, divisor, diff, borrow);
  input  [32:0] qr_hi;
  input  [31:0] divisor;
  output [32:0] diff;
  output borrow;

  assign diff   = qr_hi - {1'b0, divisor};
  assign borrow = diff[32];

endmodule
