module bus_rx_flow_msb_sva (
    input logic       clk_i,
    input logic       rst_ni,
    input logic       scl_posedge_i,
    input logic       sda_i,
    input logic       rx_req_bit_i,
    input logic       rx_req_byte_i,
    input logic [7:0] rx_data_o,
    input logic       rx_done_o,
    input logic       rx_idle_o,
    input logic       rx_bit_en,
    input logic       rx_done,
    input logic       rx_bit,
    input logic [6:0] rx_data,
    input logic [3:0] bit_counter,
    input logic       bit_counter_en,
    input logic [2:0] state_q,
    input logic [2:0] state_d
);

  localparam logic [2:0] StateIdle             = 3'd0;
  localparam logic [2:0] StateReadByte         = 3'd1;
  localparam logic [2:0] StateReadBit          = 3'd2;
  localparam logic [2:0] StateNextTaskDecision = 3'd3;

  logic       past_valid_q;
  logic       byte_active_q;
  logic [7:0] byte_value_q;
  logic [2:0] bit_idx_q;
  logic [3:0] byte_sample_count_q;
  logic       bit_active_q;
  logic       bit_value_q;
  logic       sample_event;
  logic       req;

  assign sample_event = scl_posedge_i && rx_bit_en;
  assign req          = rx_req_byte_i || rx_req_bit_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin : check_rx_msb_first
    if (!rst_ni) begin
      past_valid_q        <= 1'b0;
      byte_active_q       <= 1'b0;
      byte_value_q        <= '0;
      bit_idx_q           <= 3'd7;
      byte_sample_count_q <= '0;
      bit_active_q        <= 1'b0;
      bit_value_q         <= 1'b0;
    end else begin
      past_valid_q <= 1'b1;

      if (rx_done_o && rx_req_byte_i && !rx_req_bit_i) begin
        assert (byte_active_q)
        else $error("bus_rx_flow_msb_sva: RX byte done without tracked byte in %m");

        assert (byte_sample_count_q == 4'd8)
        else $error("bus_rx_flow_msb_sva: RX byte done after %0d samples in %m",
                    byte_sample_count_q);

        if (byte_active_q) begin
          assert (rx_data_o === byte_value_q)
          else $error("bus_rx_flow_msb_sva: RX byte order mismatch in %m exp=0x%0h got=0x%0h",
                      byte_value_q, rx_data_o);
        end

        byte_active_q       <= 1'b0;
        bit_idx_q           <= 3'd7;
        byte_sample_count_q <= '0;
      end else if (!rx_req_byte_i) begin
        byte_active_q       <= 1'b0;
        bit_idx_q           <= 3'd7;
        byte_sample_count_q <= '0;
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

      if (sample_event && !(rx_req_byte_i && rx_req_bit_i)) begin
        if (rx_req_byte_i) begin
          assert (byte_sample_count_q < 4'd8)
          else $error("bus_rx_flow_msb_sva: RX byte sampled more than 8 bits in %m");

          byte_active_q           <= 1'b1;
          byte_value_q[bit_idx_q] <= sda_i;
          byte_sample_count_q     <= byte_sample_count_q + 1'b1;

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

  ap_rx_req_mutual_exclusion :
  assert property (@(posedge clk_i) disable iff (!rst_ni) !(rx_req_bit_i && rx_req_byte_i))
  else $error("bus_rx_flow_msb_sva: RX bit and byte requests must be mutually exclusive in %m");

  ap_rx_sample_has_one_request :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   sample_event |-> (rx_req_byte_i ^ rx_req_bit_i))
  else $error("bus_rx_flow_msb_sva: RX sample must have exactly one active request in %m");

  ap_rx_done_has_one_request :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   rx_done_o |-> (rx_req_byte_i ^ rx_req_bit_i))
  else $error("bus_rx_flow_msb_sva: RX done must have exactly one active request in %m");

  ap_rx_done_one_cycle_pulse :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   rx_done_o |=> !rx_done_o)
  else $error("bus_rx_flow_msb_sva: RX done must be a one-cycle pulse in %m");

  ap_rx_done_no_sample_overlap :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   rx_done_o |-> !sample_event)
  else $error("bus_rx_flow_msb_sva: RX done must not overlap a new bus sample in %m");

  ap_rx_sample_to_internal_done :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   sample_event |=> rx_done)
  else $error("bus_rx_flow_msb_sva: internal rx_done must follow a bus sample in %m");

  ap_rx_internal_done_has_sample :
  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   rx_done |-> $past(sample_event))
  else $error("bus_rx_flow_msb_sva: internal rx_done asserted without prior bus sample in %m");

  ap_rx_bit_captures_sda :
  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   rx_done |-> (rx_bit === $past(sda_i)))
  else $error("bus_rx_flow_msb_sva: internal rx_bit did not capture sampled SDA in %m");

  ap_rx_single_bit_output :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (rx_req_bit_i && !rx_req_byte_i) |-> (rx_data_o === {7'b0, rx_bit}))
  else $error("bus_rx_flow_msb_sva: single-bit RX output must use bit[0] in %m");

  ap_rx_byte_output :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!rx_req_bit_i) |-> (rx_data_o === {rx_data[6:0], rx_bit}))
  else $error("bus_rx_flow_msb_sva: byte RX output must expose shifted byte data in %m");

  ap_rx_bit_counter_decrement :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (bit_counter_en && rx_done) |=> (bit_counter == ($past(bit_counter) - 1'b1)))
  else $error("bus_rx_flow_msb_sva: bit counter must decrement after sampled byte bit in %m");

  ap_rx_bit_counter_hold :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (bit_counter_en && !rx_done) |=> (bit_counter == $past(bit_counter)))
  else $error("bus_rx_flow_msb_sva: bit counter must hold without sampled byte bit in %m");

  ap_rx_bit_counter_reset :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !bit_counter_en |=> (bit_counter == 4'h7))
  else $error("bus_rx_flow_msb_sva: bit counter must reset when disabled in %m");

  ap_rx_byte_shift_update :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (bit_counter_en && rx_done) |=> (rx_data === {$past(rx_data[5:0]), $past(rx_bit)}))
  else $error("bus_rx_flow_msb_sva: RX byte shift register update mismatch in %m");

  ap_rx_byte_shift_clear :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !bit_counter_en |=> (rx_data == '0))
  else $error("bus_rx_flow_msb_sva: RX byte shift register must clear when disabled in %m");

  ap_rx_idle_outputs :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateIdle)
                   |-> (rx_idle_o && !rx_done_o && !rx_bit_en && !bit_counter_en))
  else $error("bus_rx_flow_msb_sva: Idle outputs mismatch in %m");

  ap_rx_read_byte_outputs :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateReadByte)
                   |-> (!rx_idle_o && bit_counter_en && (rx_bit_en == !rx_done) &&
                        (rx_done_o == ((bit_counter == '0) && rx_done))))
  else $error("bus_rx_flow_msb_sva: ReadByte outputs mismatch in %m");

  ap_rx_read_bit_outputs :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateReadBit)
                   |-> (!rx_idle_o && !bit_counter_en && (rx_bit_en == !rx_done) &&
                        (rx_done_o == rx_done)))
  else $error("bus_rx_flow_msb_sva: ReadBit outputs mismatch in %m");

  ap_rx_next_task_decision_outputs :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateNextTaskDecision)
                   |-> (!rx_idle_o && !rx_done_o && !bit_counter_en && (rx_bit_en == req)))
  else $error("bus_rx_flow_msb_sva: NextTaskDecision outputs mismatch in %m");

  ap_rx_idle_to_request :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateIdle && req)
                   |-> (state_d == (rx_req_byte_i ? StateReadByte : StateReadBit)))
  else $error("bus_rx_flow_msb_sva: Idle transition mismatch for active request in %m");

  ap_rx_idle_hold :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateIdle && !req) |-> (state_d == StateIdle))
  else $error("bus_rx_flow_msb_sva: Idle transition mismatch for no request in %m");

  ap_rx_read_byte_abort :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateReadByte && !rx_req_byte_i) |-> (state_d == StateIdle))
  else $error("bus_rx_flow_msb_sva: ReadByte abort transition mismatch in %m");

  ap_rx_read_byte_done :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateReadByte && rx_req_byte_i && rx_done_o)
                   |-> (state_d == StateNextTaskDecision))
  else $error("bus_rx_flow_msb_sva: ReadByte done transition mismatch in %m");

  ap_rx_read_byte_hold :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateReadByte && rx_req_byte_i && !rx_done_o)
                   |-> (state_d == StateReadByte))
  else $error("bus_rx_flow_msb_sva: ReadByte hold transition mismatch in %m");

  ap_rx_read_bit_abort :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateReadBit && !rx_req_bit_i) |-> (state_d == StateIdle))
  else $error("bus_rx_flow_msb_sva: ReadBit abort transition mismatch in %m");

  ap_rx_read_bit_done :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateReadBit && rx_req_bit_i && rx_done)
                   |-> (state_d == StateNextTaskDecision))
  else $error("bus_rx_flow_msb_sva: ReadBit done transition mismatch in %m");

  ap_rx_read_bit_hold :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateReadBit && rx_req_bit_i && !rx_done)
                   |-> (state_d == StateReadBit))
  else $error("bus_rx_flow_msb_sva: ReadBit hold transition mismatch in %m");

  ap_rx_next_task_decision_to_request :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateNextTaskDecision && req)
                   |-> (state_d == (rx_req_byte_i ? StateReadByte : StateReadBit)))
  else $error("bus_rx_flow_msb_sva: NextTaskDecision transition mismatch for active request in %m");

  ap_rx_next_task_decision_to_idle :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateNextTaskDecision && !req) |-> (state_d == StateIdle))
  else $error("bus_rx_flow_msb_sva: NextTaskDecision transition mismatch for no request in %m");

  cp_rx_byte_complete :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  rx_done_o && rx_req_byte_i && !rx_req_bit_i && (byte_sample_count_q == 4'd8));

  cp_rx_single_bit_complete :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  rx_done_o && rx_req_bit_i && !rx_req_byte_i && bit_active_q);

  cp_rx_request_abort :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q inside {StateReadByte, StateReadBit}) && !req && (state_d == StateIdle));

endmodule
