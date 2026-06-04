module bus_rx_flow_msb_sva (
    input logic       clk_i,
    input logic       rst_ni,
    input logic       scl_posedge_i,
    input logic       sda_i,
    input logic       rx_req_bit_i,
    input logic       rx_req_byte_i,
    input logic [7:0] rx_data_o,
    input logic       rx_done_o,
    input logic       rx_bit_en
);

  logic       byte_active_q;
  logic [7:0] byte_value_q;
  logic [2:0] bit_idx_q;
  logic       bit_active_q;
  logic       bit_value_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin : check_rx_msb_first
    if (!rst_ni) begin
      byte_active_q <= 1'b0;
      byte_value_q  <= '0;
      bit_idx_q     <= 3'd7;
      bit_active_q  <= 1'b0;
      bit_value_q   <= 1'b0;
    end else begin
      if (rx_done_o && rx_req_byte_i && !rx_req_bit_i) begin
        assert (byte_active_q)
        else $error("bus_rx_flow_msb_sva: RX byte done without tracked byte in %m");

        if (byte_active_q) begin
          assert (rx_data_o === byte_value_q)
          else $error("bus_rx_flow_msb_sva: RX byte order mismatch in %m exp=0x%0h got=0x%0h",
                      byte_value_q, rx_data_o);
        end

        byte_active_q <= 1'b0;
        bit_idx_q     <= 3'd7;
      end else if (!rx_req_byte_i) begin
        byte_active_q <= 1'b0;
        bit_idx_q     <= 3'd7;
      end

      if (rx_done_o && rx_req_bit_i && !rx_req_byte_i) begin
        assert (bit_active_q)
        else $error("bus_rx_flow_msb_sva: RX bit done without tracked bit in %m");

        if (bit_active_q) begin
          assert (rx_data_o === {7'b0, bit_value_q})
          else $error("bus_rx_flow_msb_sva: RX single-bit data mismatch in %m exp=%0b got=0x%0h",
                      bit_value_q, rx_data_o);
        end

        bit_active_q <= 1'b0;
      end else if (!rx_req_bit_i) begin
        bit_active_q <= 1'b0;
      end

      if (scl_posedge_i && rx_bit_en && !(rx_req_byte_i && rx_req_bit_i)) begin
        if (rx_req_byte_i) begin
          byte_active_q           <= 1'b1;
          byte_value_q[bit_idx_q] <= sda_i;

          if (bit_idx_q == 3'd0) begin
            bit_idx_q <= 3'd7;
          end else begin
            bit_idx_q <= bit_idx_q - 1'b1;
          end
        end else if (rx_req_bit_i) begin
          bit_active_q <= 1'b1;
          bit_value_q  <= sda_i;
        end
      end
    end
  end

endmodule
