// Registro combinado cociente:residuo (64 bits) del algoritmo de
// division por resta-y-corrimiento (restoring division). Al cargar,
// s_qr = {32'b0, dividendo}. En cada "shift", se decide con la
// resta ya calculada (sub_cmp33) si el residuo parcial (bits altos)
// es mayor o igual al divisor:
//   - si "borrow" (residuo parcial < divisor): se descarta la resta,
//     se desplaza todo 1 bit a la izquierda insertando un 0 (ese bit
//     del cociente es 0).
//   - si no hay "borrow" (residuo parcial >= divisor): se guarda el
//     resultado de la resta como nuevo residuo parcial, y se inserta
//     un 1 (ese bit del cociente es 1).
// Al terminar las 32 iteraciones: s_qr[31:0]=cociente, s_qr[63:32]=residuo.
module qr_reg (clk, in_A, load, shift, borrow, diff, s_qr);
  input clk;
  input [31:0] in_A;
  input load;
  input shift;
  input borrow;
  input [32:0] diff;
  output reg [63:0] s_qr;

always @(posedge clk)
  if (load)
    s_qr <= {32'b0, in_A};
  else if (shift) begin
    if (borrow)
      s_qr <= {s_qr[62:0], 1'b0};
    else
      s_qr <= {diff[31:0], s_qr[30:0], 1'b1};
  end

endmodule
