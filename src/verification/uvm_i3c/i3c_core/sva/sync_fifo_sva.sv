module sync_fifo_model_sva #(
    parameter  int unsigned Width  = 32,
    parameter  int unsigned Depth  = 64,
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
    input logic [DepthW-1:0] depth_o
);

  logic [Width-1:0] model_q[$];
  bit               model_valid_q;

  logic do_write;
  logic do_read;

  assign do_write = wvalid_i && wready_o;
  assign do_read  = rready_i && rvalid_o;

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_fifo_model
    if (!rst_ni) begin
      model_q.delete();
      model_valid_q <= 1'b1;
    end else if (flush_i) begin
      model_q.delete();
      model_valid_q <= 1'b1;
    end else if (model_valid_q && (model_q.size() != int'(depth_o))) begin
      model_q.delete();
      model_valid_q <= empty_o && (depth_o == '0);
    end else if (model_valid_q) begin
      if (do_read) begin
        assert (model_q.size() > 0)
        else $error("sync_fifo_model_sva: tracked read underflow in %m");

        if (model_q.size() > 0) begin
          assert (rdata_o === model_q[0])
          else $error("sync_fifo_model_sva: read order mismatch in %m exp=0x%0h got=0x%0h",
                      model_q[0], rdata_o);
          void'(model_q.pop_front());
        end
      end

      if (do_write) begin
        assert (model_q.size() < Depth)
        else $error("sync_fifo_model_sva: tracked write overflow in %m");

        if (model_q.size() < Depth) begin
          model_q.push_back(wdata_i);
        end
      end
    end else if (empty_o && (depth_o == '0)) begin
      model_q.delete();
      model_valid_q <= 1'b1;
    end
  end

endmodule
