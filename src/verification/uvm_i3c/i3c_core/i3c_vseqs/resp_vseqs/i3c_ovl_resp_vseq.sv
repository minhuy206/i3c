class i3c_ovl_resp_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_ovl_resp_vseq)

  localparam int unsigned WR_DATA_LENGTH = 8;
  localparam int unsigned WR_ACTUAL_LENGTH = 4;
  localparam int unsigned RD_DATA_LENGTH = 8;
  localparam int unsigned RD_OBSERVED_LENGTH = 4;
  localparam int unsigned RX_FIFO_DEPTH = 8;
  localparam logic [3:0]  RESP_OVL = 4'h6;

  function new(string name = "i3c_ovl_resp_vseq");
    super.new(name);
  endfunction

  virtual task body();
    run_tx_underflow_resp_case(WR_ACTUAL_LENGTH);
    run_tx_underflow_resp_case(0);
    run_rx_fifo_full_resp_case();

  endtask

  virtual task run_tx_underflow_resp_case(int unsigned actual_length);
    transfer_stimulus_cfg_t cfg;
    transfer_stimulus_cfg_t dev_cfg;
    byte_queue_t            no_read_data;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_005 tx_underflow_ovl_resp actual%0d", actual_length)),
        .seq_name($sformatf("err005_tx_underflow_dev_seq_%0d", actual_length)),
        .tid(4'd5),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(WR_DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    dev_cfg = cfg;
    dev_cfg.data_length = actual_length;
    start_device_response(dev_cfg, 1'b0, no_read_data, dev_seq);
    if (actual_length != 0) write_tx_data(32'h4433_2211);
    write_write_cmd(cfg);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_error_resp_fields(resp, RESP_OVL, cfg.tid, actual_length, cfg.ctxt);
    check_all_queues_empty("after ERR_005 TX underflow Ovl RESP");
  endtask

  virtual task run_rx_fifo_full_resp_case();
    transfer_stimulus_cfg_t cfg;
    regular_trans_desc_t    rd_cmd;
    byte_queue_t            read_data;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);
    build_read_payload(read_data);
    prefill_rx_fifo();

    cfg = make_transfer_cfg(
        .ctxt("ERR_005 rx_fifo_full_ovl_resp"),
        .seq_name("err005_rx_fifo_full_dev_seq"),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(RD_DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b0);
    start_device_response(cfg, 1'b1, read_data, dev_seq);
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_error_resp_fields(resp, RESP_OVL, cfg.tid, RD_OBSERVED_LENGTH, cfg.ctxt);
    drain_prefilled_rx_fifo();
    check_all_queues_empty("after ERR_005 RX FIFO full Ovl RESP");
  endtask

  virtual function bit [31:0] make_prefill_word(int unsigned index);
    return 32'h5A5A_2000 | index[31:0];
  endfunction

  virtual task prefill_rx_fifo();
    for (int unsigned i = 0; i < RX_FIFO_DEPTH; i++) begin
      backdoor_write_fifo_entry(rx_paths, i, make_prefill_word(i));
    end
    backdoor_set_fifo_level(rx_paths, RX_FIFO_DEPTH);
    settle_cycles();
  endtask

  virtual task drain_prefilled_rx_fifo();
    bit [31:0] rx_word;

    for (int unsigned i = 0; i < RX_FIFO_DEPTH; i++) begin
      read_rx_data(rx_word);
    end
  endtask

  virtual function void build_read_payload(ref byte_queue_t read_data);
    read_data.delete();
    for (int unsigned i = 0; i < RD_DATA_LENGTH; i++) begin
      read_data.push_back(8'(8'h60 + i));
    end
  endfunction

endclass
