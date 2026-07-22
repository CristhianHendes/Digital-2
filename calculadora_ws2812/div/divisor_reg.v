module divisor_reg (clk, in_B, load, s_B);
  input clk;
  input [31:0] in_B;
  input load;
  output reg [31:0] s_B;

always @(posedge clk)
  if (load)
    s_B <= in_B;

endmodule
