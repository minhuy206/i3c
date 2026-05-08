module sync_fifo #(
  parameter int unsigned Width = 32,
  parameter int unsigned Depth = 64,
  localparam int unsigned PtrW   = $clog2(Depth),
  localparam int unsigned DepthW = $clog2(Depth + 1)
)(
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             flush_i,    // Synchronous flush

  // Write port
  input  logic             wvalid_i,
  output logic             wready_o,
  input  logic [Width-1:0] wdata_i,

  // Read port
  output logic             rvalid_o,
  input  logic             rready_i,
  output logic [Width-1:0] rdata_o,

  // Status
  output logic             full_o,
  output logic             empty_o,
  output logic [DepthW-1:0] depth_o
);
  logic [Width-1:0] mem [0:Depth-1];

  logic [PtrW:0] wptr_q, wptr_d;
  logic [PtrW:0] rptr_q, rptr_d;

  logic do_write, do_read;
  assign do_write = wvalid_i && wready_o;
  assign do_read  = rready_i && rvalid_o;

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
    end else if(flush_i) begin
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

  // Extra-MSB pointer comparison for full/empty detection
  assign full_o  = (rptr_q == {~wptr_q[PtrW], wptr_q[PtrW-1:0]});
  assign empty_o = (wptr_q == rptr_q);
  assign depth_o = wptr_q - rptr_q;

  assign wready_o = ~full_o;
  assign rvalid_o = ~empty_o;

  assign rdata_o = mem[rptr_q[PtrW-1:0]];

endmodule