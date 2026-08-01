interface clk_rst_if (input logic clk_i);
  logic rst_ni;

  initial rst_ni = 1'b0;

  task automatic apply_reset(int unsigned cycles = 100);
    @(negedge clk_i);
    rst_ni = 1'b0;
    repeat (cycles) @(posedge clk_i);
    @(negedge clk_i);
    rst_ni = 1'b1;
  endtask
endinterface
