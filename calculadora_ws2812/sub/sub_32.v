module sub_32 (A, B, diff);
  input  [31:0] A;
  input  [31:0] B;
  output [31:0] diff;

  assign diff = A - B; // resta en complemento a 2, igual que antes en Migen

endmodule
