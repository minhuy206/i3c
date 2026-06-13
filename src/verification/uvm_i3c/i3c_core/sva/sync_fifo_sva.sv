module sync_fifo_sva #(
    parameter  int unsigned Width  = 32,
    parameter  int unsigned Depth  = 64,
    localparam int unsigned PtrW   = $clog2(Depth),
    localparam int unsigned DepthW = $clog2(Depth + 1)
) (
    input logic clk_i,
    input logic rst_ni,
    input logic flush_i,

    input logic             wvalid_i,
    input logic             wready_o,
    input logic [Width-1:0] wdata_i,

    input logic             rvalid_o,
    input logic             rready_i,
    input logic [Width-1:0] rdata_o,

    input logic              empty_o,
    input logic [DepthW-1:0] depth_o,
    input logic [  PtrW:0]   wptr_q,
    input logic [  PtrW:0]   rptr_q
);

  logic do_write;
  logic do_read;
  logic past_valid_q;

  assign do_write = wvalid_i && wready_o;
  assign do_read  = rready_i && rvalid_o;

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_past_valid
    if (!rst_ni) past_valid_q <= 1'b0;
    else past_valid_q <= 1'b1;
  end

  ap_read_pop_advances_rptr:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q || flush_i)
                   do_read |=> (rptr_q == ($past(rptr_q) + 1'b1)))
  else $error("sync_fifo_sva: valid read did not advance rptr");

  cp_read_pop_advances_rptr:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q || flush_i)
                  do_read ##1 (rptr_q == ($past(rptr_q) + 1'b1)));

  ap_read_only_decrements_depth:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q || flush_i)
                   do_read && !do_write |=> (depth_o == ($past(depth_o) - 1'b1)))
  else $error("sync_fifo_sva: read-only pop did not decrement depth");

  cp_read_only_decrements_depth:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q || flush_i)
                  do_read && !do_write ##1 (depth_o == ($past(depth_o) - 1'b1)));

  ap_empty_read_does_not_advance_rptr:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q || flush_i)
                   rready_i && !rvalid_o |=> (rptr_q == $past(rptr_q)))
  else $error("sync_fifo_sva: empty read advanced rptr");

  cp_empty_read_does_not_advance_rptr:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q || flush_i)
                  rready_i && !rvalid_o ##1 (rptr_q == $past(rptr_q)));

  ap_empty_read_only_preserves_state:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q || flush_i)
                   rready_i && !rvalid_o && !do_write
                   |=> ((rptr_q == $past(rptr_q)) &&
                        (wptr_q == $past(wptr_q)) &&
                        (depth_o == $past(depth_o))))
  else $error("sync_fifo_sva: empty read-only cycle changed FIFO state");

  cp_empty_read_only_preserves_state:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q || flush_i)
                  rready_i && !rvalid_o && !do_write
                  ##1 ((rptr_q == $past(rptr_q)) &&
                       (wptr_q == $past(wptr_q)) &&
                       (depth_o == $past(depth_o))));

endmodule

bind sync_fifo sync_fifo_sva #(
    .Width(Width),
    .Depth(Depth)
) u_sync_fifo_sva (
    .clk_i,
    .rst_ni,
    .flush_i,
    .wvalid_i,
    .wready_o,
    .wdata_i,
    .rvalid_o,
    .rready_i,
    .rdata_o,
    .empty_o,
    .depth_o,
    .wptr_q,
    .rptr_q
);
