module sync_fifo #(
    parameter  int unsigned Width  = 32,
    parameter  int unsigned Depth  = 64,
    localparam int unsigned PtrW   = $clog2(Depth),
    localparam int unsigned DepthW = $clog2(Depth + 1)
) (
    input logic clk_i,
    input logic rst_ni,
    input logic flush_i, // Synchronous flush

    // Write port
    input  logic             wvalid_i,
    output logic             wready_o,
    input  logic [Width-1:0] wdata_i,

    // Read port
    output logic             rvalid_o,
    input  logic             rready_i,
    output logic [Width-1:0] rdata_o,

    // Status
    output logic              full_o,
    output logic              empty_o,
    output logic [DepthW-1:0] depth_o
);
  logic [Width-1:0] mem[0:Depth-1];

  logic [PtrW:0] wptr_q, wptr_d;
  logic [PtrW:0] rptr_q, rptr_d;

  logic do_write, do_read;
  logic past_valid_q;

  initial begin
    assert (Depth == (1 << PtrW))
    else $fatal(1, "sync_fifo: Depth (%0d) must be a power of 2", Depth);
  end

  always_comb begin : update_wptr_d
    wptr_d = wptr_q;
    if (do_write) begin
      wptr_d = wptr_q + 1'b1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_wptr_q
    if (!rst_ni) begin
      wptr_q <= '0;
    end else if (flush_i) begin
      wptr_q <= '0;
    end else begin
      wptr_q <= wptr_d;
    end
  end

  always_comb begin : update_rptr_d
    rptr_d = rptr_q;
    if (do_read) begin
      rptr_d = rptr_q + 1'b1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_rptr_q
    if (!rst_ni) begin
      rptr_q <= '0;
    end else if (flush_i) begin
      rptr_q <= '0;
    end else begin
      rptr_q <= rptr_d;
    end
  end

  always_ff @(posedge clk_i) begin : write_mem
    if (do_write) begin
      mem[wptr_q[PtrW-1:0]] <= wdata_i;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_past_valid
    if (!rst_ni) begin
      past_valid_q <= 1'b0;
    end else begin
      past_valid_q <= 1'b1;
    end
  end

  // Extra-MSB pointer comparison for full/empty detection
  assign full_o  = (rptr_q == {~wptr_q[PtrW], wptr_q[PtrW-1:0]});
  assign empty_o = (wptr_q == rptr_q);
  assign depth_o = wptr_q - rptr_q;

  assert property (@(posedge clk_i) disable iff (!rst_ni) (depth_o <= Depth))
  else $error("sync_fifo: depth_o (%0d) exceeds Depth (%0d)", depth_o, Depth);

  assert property (@(posedge clk_i) disable iff (!rst_ni) (empty_o == (depth_o == '0)))
  else $error("sync_fifo: empty_o must mirror zero depth");

  assert property (@(posedge clk_i) disable iff (!rst_ni) (full_o == (depth_o == DepthW'(Depth))))
  else $error("sync_fifo: full_o must mirror full depth");

  assert property (@(posedge clk_i) disable iff (!rst_ni) (wready_o == !full_o))
  else $error("sync_fifo: wready_o must mirror !full_o");

  assert property (@(posedge clk_i) disable iff (!rst_ni) (rvalid_o == !empty_o))
  else $error("sync_fifo: rvalid_o must mirror !empty_o");

  assert property (@(posedge clk_i) disable iff (!rst_ni) flush_i |=> (empty_o && (depth_o == '0)))
  else $error("sync_fifo: flush_i must clear FIFO occupancy");

  assert property (@(posedge clk_i) disable iff (!rst_ni || flush_i || !past_valid_q)
                   (wvalid_i && !wready_o)
                   |=> (!wvalid_i || $stable(wdata_i)))
  else $error("sync_fifo: write data changed while wvalid_i remained blocked");

  assert property (@(posedge clk_i) disable iff (!rst_ni || flush_i || !past_valid_q)
                   (rvalid_o && !rready_i)
                   |=> (rvalid_o && $stable(rdata_o)))
  else $error("sync_fifo: read data changed while rvalid_o waited for rready_i");

  assert property (@(posedge clk_i) disable iff (!rst_ni || flush_i || !past_valid_q)
                   (do_write && !do_read)
                   |=> ((depth_o == ($past(depth_o) + 1'b1)) &&
                        (wptr_q == ($past(wptr_q) + 1'b1)) &&
                        (rptr_q == $past(rptr_q))))
  else $error("sync_fifo: write-only handshake must increment depth and write pointer");

  assert property (@(posedge clk_i) disable iff (!rst_ni || flush_i || !past_valid_q)
                   (do_read && !do_write)
                   |=> ((depth_o == ($past(depth_o) - 1'b1)) &&
                        (rptr_q == ($past(rptr_q) + 1'b1)) &&
                        (wptr_q == $past(wptr_q))))
  else $error("sync_fifo: read-only handshake must decrement depth and read pointer");

  assert property (@(posedge clk_i) disable iff (!rst_ni || flush_i || !past_valid_q)
                   (do_write && do_read)
                   |=> ((depth_o == $past(depth_o)) &&
                        (wptr_q == ($past(wptr_q) + 1'b1)) &&
                        (rptr_q == ($past(rptr_q) + 1'b1))))
  else $error("sync_fifo: simultaneous read/write must preserve depth and advance both pointers");

  assert property (@(posedge clk_i) disable iff (!rst_ni || flush_i || !past_valid_q)
                   (wvalid_i && !wready_o && !do_read)
                   |=> ((depth_o == $past(depth_o)) && (wptr_q == $past(wptr_q))))
  else $error("sync_fifo: blocked write must not change FIFO occupancy");

  assert property (@(posedge clk_i) disable iff (!rst_ni || flush_i || !past_valid_q)
                   (rready_i && !rvalid_o && !do_write)
                   |=> ((depth_o == $past(depth_o)) && (rptr_q == $past(rptr_q))))
  else $error("sync_fifo: blocked read must not change FIFO occupancy");

  assert property (@(posedge clk_i) disable iff (!rst_ni) flush_i
                   |=> (empty_o && (depth_o == '0) && (wptr_q == '0) && (rptr_q == '0)))
  else $error("sync_fifo: flush_i must clear FIFO pointers");

  cover property (@(posedge clk_i) disable iff (!rst_ni) full_o);
  cover property (@(posedge clk_i) disable iff (!rst_ni) past_valid_q && empty_o);
  cover property (@(posedge clk_i) disable iff (!rst_ni || flush_i) do_write && do_read);
  cover property (@(posedge clk_i) disable iff (!rst_ni) flush_i && (wvalid_i || rready_i));
  cover property (@(posedge clk_i) disable iff (!rst_ni || flush_i) wvalid_i && !wready_o);
  cover property (@(posedge clk_i) disable iff (!rst_ni || flush_i) rready_i && !rvalid_o);

  assign wready_o = ~full_o;
  assign rvalid_o = ~empty_o;

  assign rdata_o  = mem[rptr_q[PtrW-1:0]];

  assign do_write = wvalid_i && wready_o;
  assign do_read  = rready_i && rvalid_o;

endmodule
