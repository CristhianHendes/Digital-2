// Divisor 32/32 -> cociente(32) + residuo(32), sin signo.
// Mismo esquema de conexion que mult_32.v: un modulo "control" (FSM)
// mas un puñado de registros/combinacional de datapath, conectados
// aqui arriba.
module div_32 (clk, rst, init, A, B, q, r, done);

  input clk;
  input rst;
  input init;
  input [31:0] A;
  input [31:0] B;
  output [31:0] q;
  output [31:0] r;
  output done;

  wire w_load;
  wire w_shift;
  wire w_borrow;
  wire [31:0] w_divisor;
  wire [63:0] w_qr;
  wire [32:0] w_diff;

  divisor_reg divisor0 (.clk(clk), .in_B(B), .load(w_load), .s_B(w_divisor));

  qr_reg qr0 (.clk(clk), .in_A(A), .load(w_load), .shift(w_shift),
              .borrow(w_borrow), .diff(w_diff), .s_qr(w_qr));

  sub_cmp33 cmp0 (.qr_hi(w_qr[63:31]), .divisor(w_divisor),
                   .diff(w_diff), .borrow(w_borrow));

  control_div control0 (.clk(clk), .rst(rst), .init(init), .done(done),
                         .load(w_load), .shift(w_shift));

  assign q = w_qr[31:0];
  assign r = w_qr[63:32];

endmodule
