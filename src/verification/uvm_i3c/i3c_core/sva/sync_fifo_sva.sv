module sync_fifo_sva #(
    parameter  int unsigned Width  = 32,
    parameter  int unsigned Depth  = 64,
    localparam int unsigned PtrW   = $clog2(Depth),
    localparam int unsigned DepthW = $clog2(Depth + 1)
) (
    input logic clk_i,
    input logic rst_ni,
    input logic flush_i,

    input logic wvalid_i,
    input logic wready_o,

    input logic rvalid_o,
    input logic rready_i,

    input logic              full_o,
    input logic              empty_o,
    input logic [DepthW-1:0] depth_o,
    input logic [    PtrW:0] wptr_q,
    input logic [    PtrW:0] rptr_q
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

  ap_hard_reset_clears_fifo_state :
  assert property (@(posedge clk_i)
                   !rst_ni |->
                   (empty_o && !full_o && (depth_o == '0) &&
                    (wptr_q == '0) && (rptr_q == '0)))
  else $error("sync_fifo_sva: hard reset did not clear FIFO state");

  cp_hard_reset_clears_fifo_state :
  cover property (@(posedge clk_i)
                  !rst_ni && empty_o && !full_o && (depth_o == '0) &&
                  (wptr_q == '0) && (rptr_q == '0));

  ap_status_matches_depth :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !flush_i |->
                   ((full_o == (depth_o == DepthW'(Depth))) &&
                    (empty_o == (depth_o == '0)) &&
                    (wready_o == !full_o) &&
                    (rvalid_o == !empty_o)))
  else $error("sync_fifo_sva: status/handshake outputs do not match FIFO depth");

  ap_flush_clears_fifo_state :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   flush_i |=> (empty_o && (depth_o == '0) && (wptr_q == '0) && (rptr_q == '0)))
  else $error("sync_fifo_sva: flush did not clear FIFO state");

  cp_flush_clears_fifo_state :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  flush_i ##1 (empty_o && (depth_o == '0) && (wptr_q == '0) && (rptr_q == '0)));

  cp_flush_with_write_request :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  flush_i && wvalid_i
                  ##1 (empty_o && (depth_o == '0)));

  cp_flush_with_read_request :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  flush_i && rready_i
                  ##1 (empty_o && (depth_o == '0)));

  cp_flush_with_read_write_requests :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  flush_i && wvalid_i && rready_i
                  ##1 (empty_o && (depth_o == '0)));

  ap_read_pop_advances_rptr :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   past_valid_q && !flush_i && do_read
                   |=> (rptr_q == ($past(
      rptr_q
  ) + 1'b1)))
  else $error("sync_fifo_sva: valid read did not advance rptr");

  cp_read_pop_advances_rptr :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && do_read
                  ##1 (rptr_q == ($past(
      rptr_q
  ) + 1'b1)));

  cp_read_pointer_wrap_toggles_extra_msb :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && do_read &&
                  (rptr_q == {1'b0, {PtrW{1'b1}}})
                  ##1 (rptr_q == {1'b1, {PtrW{1'b0}}}));

  cp_read_pointer_wrap_reuses_zero :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && do_read && (rptr_q == '1)
                  ##1 (rptr_q == '0));

  ap_read_only_decrements_depth :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   past_valid_q && !flush_i && do_read && !do_write
                   |=> (depth_o == ($past(
      depth_o
  ) - 1'b1)))
  else $error("sync_fifo_sva: read-only pop did not decrement depth");

  cp_read_only_decrements_depth :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && do_read && !do_write
                  ##1 (depth_o == ($past(
      depth_o
  ) - 1'b1)));

  ap_write_push_advances_wptr :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   past_valid_q && !flush_i && do_write
                   |=> (wptr_q == ($past(
      wptr_q
  ) + 1'b1)))
  else $error("sync_fifo_sva: valid write did not advance wptr");

  cp_write_push_advances_wptr :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && do_write
                  ##1 (wptr_q == ($past(
      wptr_q
  ) + 1'b1)));

  cp_write_pointer_wrap_toggles_extra_msb :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && do_write &&
                  (wptr_q == {1'b0, {PtrW{1'b1}}})
                  ##1 (wptr_q == {1'b1, {PtrW{1'b0}}}));

  cp_write_pointer_wrap_reuses_zero :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && do_write && (wptr_q == '1)
                  ##1 (wptr_q == '0));

  ap_write_only_increments_depth :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   past_valid_q && !flush_i && do_write && !do_read
                   |=> (depth_o == ($past(
      depth_o
  ) + 1'b1)))
  else $error("sync_fifo_sva: write-only push did not increment depth");

  cp_write_only_increments_depth :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && do_write && !do_read
                  ##1 (depth_o == ($past(
      depth_o
  ) + 1'b1)));

  ap_simultaneous_read_write_preserves_depth :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   past_valid_q && !flush_i && do_read && do_write
                   |=> (depth_o == $past(
      depth_o
  )))
  else $error("sync_fifo_sva: simultaneous read/write changed FIFO depth");

  cp_simultaneous_read_write_preserves_depth :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && do_read && do_write
                  ##1 (depth_o == $past(
      depth_o
  )));

  cp_simultaneous_read_write_near_empty :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && do_read && do_write &&
                  (depth_o == DepthW'(1))
                  ##1 (depth_o == $past(
      depth_o
  )));

  cp_simultaneous_read_write_mid_depth :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && do_read && do_write &&
                  (depth_o > DepthW'(1)) && (depth_o < DepthW'(Depth - 1))
                  ##1 (depth_o == $past(
      depth_o
  )));

  cp_simultaneous_read_write_near_full :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && do_read && do_write &&
                  (depth_o == DepthW'(Depth - 1))
                  ##1 (depth_o == $past(
      depth_o
  )));

  ap_full_write_does_not_advance_wptr :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   past_valid_q && !flush_i && wvalid_i && !wready_o
                   |=> (wptr_q == $past(
      wptr_q
  )))
  else $error("sync_fifo_sva: blocked full write advanced wptr");

  cp_full_write_does_not_advance_wptr :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && wvalid_i && !wready_o
                  ##1 (wptr_q == $past(
      wptr_q
  )));

  ap_empty_read_does_not_advance_rptr :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   past_valid_q && !flush_i && rready_i && !rvalid_o
                   |=> (rptr_q == $past(
      rptr_q
  )))
  else $error("sync_fifo_sva: empty read advanced rptr");

  cp_empty_read_does_not_advance_rptr :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && rready_i && !rvalid_o
                  ##1 (rptr_q == $past(
      rptr_q
  )));

  ap_empty_read_only_preserves_state :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   past_valid_q && !flush_i && rready_i && !rvalid_o && !do_write
                   |=> ((rptr_q == $past(
      rptr_q
  )) && (wptr_q == $past(
      wptr_q
  )) && (depth_o == $past(
      depth_o
  ))))
  else $error("sync_fifo_sva: empty read-only cycle changed FIFO state");

  cp_empty_read_only_preserves_state :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  past_valid_q && !flush_i && rready_i && !rvalid_o && !do_write
                  ##1 ((rptr_q == $past(
      rptr_q
  )) && (wptr_q == $past(
      wptr_q
  )) && (depth_o == $past(
      depth_o
  ))));

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
    .rvalid_o,
    .rready_i,
    .full_o,
    .empty_o,
    .depth_o,
    .wptr_q,
    .rptr_q
);
