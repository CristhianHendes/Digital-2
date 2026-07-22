module sub_cmp33 (qr_hi, divisor, diff, borrow);
  input  [32:0] qr_hi;
  input  [31:0] divisor;
  output [32:0] diff;
  output borrow;

  assign diff   = qr_hi - {1'b0, divisor};
  assign borrow = diff[32];

endmodule
