module fifo_non_power_of_two_tb;
  logic       clk;
  logic       rst_n;
  logic       flush;
  logic       wvalid;
  logic       wready;
  logic [7:0] wdata;
  logic       rvalid;
  logic       rready;
  logic [7:0] rdata;
  logic       full;
  logic       empty;
  logic [1:0] depth;

  sync_fifo #(
      .Width(8),
      .Depth(3)
  ) dut (
      .clk_i   (clk),
      .rst_ni  (rst_n),
      .flush_i (flush),
      .wvalid_i(wvalid),
      .wready_o(wready),
      .wdata_i (wdata),
      .rvalid_o(rvalid),
      .rready_i(rready),
      .rdata_o (rdata),
      .full_o  (full),
      .empty_o (empty),
      .depth_o (depth)
  );

  initial begin
    clk    = 1'b0;
    rst_n  = 1'b0;
    flush  = 1'b0;
    wvalid = 1'b0;
    wdata  = '0;
    rready = 1'b0;
    #1ns;
    $fatal(1, "fifo_non_power_of_two_tb: invalid sync_fifo depth was not rejected");
  end
endmodule
