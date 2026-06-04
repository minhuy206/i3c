module bus_tx_flow_msb_sva (
    input logic       clk_i,
    input logic       rst_ni,
    input logic       scl_posedge_i,
    input logic       req_byte_i,
    input logic       req_bit_i,
    input logic [7:0] req_value_i,
    input logic       req_error_o,
    input logic       drive_bit_en,
    input logic       sda_o
);

  logic       byte_active_q;
  logic [7:0] byte_value_q;
  logic [2:0] bit_idx_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin : check_tx_msb_first
    if (!rst_ni) begin
      byte_active_q <= 1'b0;
      byte_value_q  <= '0;
      bit_idx_q     <= 3'd7;
    end else begin
      if (req_error_o || !req_byte_i) begin
        byte_active_q <= 1'b0;
        bit_idx_q     <= 3'd7;
      end

      if (scl_posedge_i && drive_bit_en && !req_error_o) begin
        if (req_byte_i && !req_bit_i) begin
          if (!byte_active_q) begin
            assert (sda_o === req_value_i[7])
            else $error("bus_tx_flow_msb_sva: TX byte bit[7] must be driven first in %m");

            byte_active_q <= 1'b1;
            byte_value_q  <= req_value_i;
            bit_idx_q     <= 3'd6;
          end else begin
            assert (sda_o === byte_value_q[bit_idx_q])
            else $error("bus_tx_flow_msb_sva: TX byte bit[%0d] mismatch in %m", bit_idx_q);

            if (bit_idx_q == 3'd0) begin
              byte_active_q <= 1'b0;
              bit_idx_q     <= 3'd7;
            end else begin
              bit_idx_q <= bit_idx_q - 1'b1;
            end
          end
        end else if (req_bit_i && !req_byte_i) begin
          assert (sda_o === req_value_i[0])
          else $error("bus_tx_flow_msb_sva: TX single-bit request must drive req_value_i[0] in %m");

          byte_active_q <= 1'b0;
          bit_idx_q     <= 3'd7;
        end
      end
    end
  end

endmodule
