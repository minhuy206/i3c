module entdaa_fsm_sva (
    input logic        clk_i,
    input logic        rst_ni,
    input logic [ 2:0] state_q,
    input logic [63:0] id_shift_q,
    input logic [ 5:0] bit_cnt_q,
    input logic        stop_pending_i,
    input logic [ 6:0] daa_addr_i,
    input logic        done_daa_o,
    input logic        addr_valid_o,
    input logic        no_device_o,
    input logic        stop_req_o,
    input logic        stopped_o,
    input logic [47:0] pid_o,
    input logic [ 7:0] bcr_o,
    input logic [ 7:0] dcr_o,
    input logic [ 7:0] bus_rx_data_i,
    input logic        bus_rx_done_i,
    input logic        bus_tx_req_byte_o,
    input logic        bus_tx_req_bit_o,
    input logic [ 7:0] bus_tx_req_value_o,
    input logic        bus_tx_sel_od_pp_o,
    input logic        bus_stop_det_i
);

  localparam logic [2:0] Idle = 3'd0;
  localparam logic [2:0] ReadRsvdAck = 3'd2;
  localparam logic [2:0] ReceiveIDBit = 3'd3;
  localparam logic [2:0] SendAddr = 3'd4;
  localparam logic [2:0] ReadAddrAck = 3'd5;
  localparam logic [2:0] WaitStop = 3'd6;
  localparam logic [2:0] Done = 3'd7;

  covergroup daa_addr_parity_cg @(posedge clk_i);
    option.per_instance = 1;

    cp_daa_addr: coverpoint daa_addr_i
        iff (rst_ni && state_q == SendAddr && bus_tx_req_byte_o) {
      bins low         = {[7'h08:7'h1f]};
      bins high        = {[7'h60:7'h7d]};
      bins alternating = {7'h2a, 7'h55};
      bins other       = default;
    }

    cp_daa_parity: coverpoint bus_tx_req_value_o[0]
        iff (rst_ni && state_q == SendAddr && bus_tx_req_byte_o) {
      bins parity_zero = {1'b0};
      bins parity_one  = {1'b1};
    }

    cx_daa_addr_parity: cross cp_daa_addr, cp_daa_parity;
  endgroup

  daa_addr_parity_cg daa_addr_parity_cov = new();

  covergroup err009_daa_abort_cg @(posedge clk_i);
    option.per_instance = 1;

    cp_daa_abort_point: coverpoint state_q iff (rst_ni && stop_pending_i) {
      bins identity = {ReceiveIDBit};
      bins assigned_address[] = {SendAddr, ReadAddrAck};
      bins completed_round_boundary = {Idle};
    }
  endgroup

  err009_daa_abort_cg err009_daa_abort_cov = new();

  ap_entdaa_ack_enters_receive_id: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadRsvdAck && bus_rx_done_i &&
     !bus_rx_data_i[0] && !bus_stop_det_i)
    |=> (state_q == ReceiveIDBit)
  );

  cp_entdaa_ack_enters_receive_id: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadRsvdAck && bus_rx_done_i &&
     !bus_rx_data_i[0] && !bus_stop_det_i)
    ##1 (state_q == ReceiveIDBit)
  );

  ap_entdaa_id_complete_sends_addr: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReceiveIDBit && bus_rx_done_i &&
     bit_cnt_q == 6'd0 && !stop_pending_i && !bus_stop_det_i)
    |=> (state_q == SendAddr)
  );

  cp_entdaa_id_complete_sends_addr: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReceiveIDBit && bus_rx_done_i &&
     bit_cnt_q == 6'd0 && !stop_pending_i && !bus_stop_det_i)
    ##1 (state_q == SendAddr)
  );

  ap_entdaa_id_complete_with_stop_waits_stop: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReceiveIDBit && bus_rx_done_i &&
     bit_cnt_q == 6'd0 && stop_pending_i && !bus_stop_det_i)
    |=> (state_q == WaitStop && stop_req_o)
  );

  cp_entdaa_id_complete_with_stop_waits_stop: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReceiveIDBit && bus_rx_done_i &&
     bit_cnt_q == 6'd0 && stop_pending_i && !bus_stop_det_i)
    ##1 (state_q == WaitStop && stop_req_o)
  );

  ap_entdaa_send_addr_value: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == SendAddr)
    |->
    (bus_tx_req_byte_o &&
     !bus_tx_req_bit_o &&
     bus_tx_req_value_o == {daa_addr_i, ~^daa_addr_i} &&
     !bus_tx_sel_od_pp_o)
  );

  cp_entdaa_send_addr_value: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == SendAddr &&
     bus_tx_req_byte_o &&
     !bus_tx_req_bit_o &&
     bus_tx_req_value_o == {daa_addr_i, ~^daa_addr_i} &&
     !bus_tx_sel_od_pp_o)
  );

  ap_entdaa_addr_ack_sets_done_valid: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadAddrAck && bus_rx_done_i &&
     !bus_rx_data_i[0] && !stop_pending_i && !bus_stop_det_i)
    |=> (state_q == Done && done_daa_o && addr_valid_o && !no_device_o)
  );

  cp_entdaa_addr_ack_sets_done_valid: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadAddrAck && bus_rx_done_i &&
     !bus_rx_data_i[0] && !stop_pending_i && !bus_stop_det_i)
    ##1 (state_q == Done && done_daa_o && addr_valid_o && !no_device_o)
  );

  ap_entdaa_addr_ack_with_stop_waits_stop: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadAddrAck && bus_rx_done_i &&
     stop_pending_i && !bus_stop_det_i)
    |=> (state_q == WaitStop && stop_req_o)
  );

  cp_entdaa_addr_ack_with_stop_waits_stop: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadAddrAck && bus_rx_done_i &&
     stop_pending_i && !bus_stop_det_i)
    ##1 (state_q == WaitStop && stop_req_o)
  );

  ap_entdaa_done_outputs_id_fields: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == Done)
    |->
    (pid_o == id_shift_q[63:16] &&
     bcr_o == id_shift_q[15:8] &&
     dcr_o == id_shift_q[7:0])
  );

  cp_entdaa_done_outputs_id_fields: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == Done &&
     pid_o == id_shift_q[63:16] &&
     bcr_o == id_shift_q[15:8] &&
     dcr_o == id_shift_q[7:0])
  );

  ap_entdaa_nack_enters_no_device: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadRsvdAck && bus_rx_done_i &&
     bus_rx_data_i[0] && !bus_stop_det_i)
    |=> (state_q == Done && done_daa_o && no_device_o && !addr_valid_o)
  );

  cp_entdaa_nack_enters_no_device: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadRsvdAck && bus_rx_done_i &&
     bus_rx_data_i[0] && !bus_stop_det_i)
    ##1 (state_q == Done && done_daa_o && no_device_o && !addr_valid_o)
  );

  ap_entdaa_wait_stop_requests_stop: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == WaitStop)
    |-> stop_req_o
  );

  cp_entdaa_wait_stop_requests_stop: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == WaitStop && stop_req_o)
  );

  ap_entdaa_observed_stop_completes_stopped: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q != Idle && state_q != Done && bus_stop_det_i)
    |=> (state_q == Done && done_daa_o && stopped_o)
  );

  cp_entdaa_observed_stop_completes_stopped: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q != Idle && state_q != Done && bus_stop_det_i)
    ##1 (state_q == Done && done_daa_o && stopped_o)
  );

  ap_entdaa_stop_after_addr_ack_preserves_assignment: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == WaitStop && addr_valid_o && bus_stop_det_i)
    |=> (state_q == Done && done_daa_o && stopped_o && addr_valid_o)
  );

  cp_entdaa_stop_after_addr_ack_preserves_assignment: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == WaitStop && addr_valid_o && bus_stop_det_i)
    ##1 (state_q == Done && done_daa_o && stopped_o && addr_valid_o)
  );

  ap_entdaa_done_returns_idle: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == Done)
    |=> (state_q == Idle)
  );

  cp_entdaa_done_returns_idle: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == Done)
    ##1 (state_q == Idle)
  );

endmodule

bind entdaa_fsm entdaa_fsm_sva u_entdaa_fsm_sva (
    .clk_i,
    .rst_ni,
    .state_q,
    .id_shift_q,
    .bit_cnt_q,
    .stop_pending_i,
    .daa_addr_i(addr_i),
    .done_daa_o(done_o),
    .addr_valid_o,
    .no_device_o,
    .stop_req_o(req_stop_o),
    .stopped_o,
    .pid_o,
    .bcr_o,
    .dcr_o,
    .bus_rx_data_i,
    .bus_rx_done_i,
    .bus_tx_req_byte_o,
    .bus_tx_req_bit_o,
    .bus_tx_req_value_o,
    .bus_tx_sel_od_pp_o,
    .bus_stop_det_i
);
