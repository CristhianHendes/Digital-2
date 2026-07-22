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
