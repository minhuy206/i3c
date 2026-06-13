class i3c_read_rx_fifo_full_overflow_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_rx_fifo_full_overflow_vseq)

  localparam int unsigned DATA_LENGTH = 8;
  localparam int unsigned OBSERVED_LENGTH = 4;
  localparam int unsigned RX_FIFO_DEPTH = 8;
  localparam int unsigned PREFILL_WORDS = RX_FIFO_DEPTH;

  function new(string name = "i3c_read_rx_fifo_full_overflow_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_rx_fifo_full_overflow_case(broadcast_modes[mode_idx]);
    end
  endtask

  virtual task run_rx_fifo_full_overflow_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    regular_trans_desc_t           rd_cmd;
    byte_queue_t                   read_data;
    bit                     [31:0] rx_word;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    build_read_payload(read_data);
    prefill_rx_fifo();

    cfg = make_transfer_cfg(
        .ctxt($sformatf("SDRR_006 %s rx_fifo_full_overflow",
          private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("sdrr006_%s_dev_seq", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b0);
    start_device_response(cfg, 1'b1, read_data, dev_seq);
    expect_scoreboard_read_data(cfg, read_data, OBSERVED_LENGTH, 1'b1, 1'b0);
    expect_scoreboard_resp_error(4'h6, cfg.tid, 16'(OBSERVED_LENGTH), cfg.ctxt);
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    `DV_CHECK_EQ(dev_seq.done, 1'b1, "SDRR_006: device response did not finish")
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08, "SDRR_006: target address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b1, "SDRR_006: transfer direction should be read")
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b1,
                 "SDRR_006: controller should take over read before forcing STOP")

    `DV_CHECK_EQ(resp[31:28], 4'h6, "SDRR_006: expected Ovl response")
    `DV_CHECK_EQ(resp[27:24], cfg.tid, "SDRR_006: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], 16'(OBSERVED_LENGTH), "SDRR_006: response length mismatch")

    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit, 1'b1, 1'b0,
                      "before SDRR_006 prefill drain");
    for (int unsigned i = 0; i < PREFILL_WORDS; i++) begin
      read_rx_data(rx_word);
      `DV_CHECK_EQ(rx_word, make_prefill_word(i), $sformatf(
                   "SDRR_006: drained RX prefill word[%0d] mismatch", i))
    end

    check_all_queues_empty("after SDRR_006 rx_fifo_full_overflow");

    `uvm_info(`gfn, "SDRR_006 I3C read RX FIFO full overflow checks passed", UVM_LOW)
  endtask

  virtual function bit [31:0] make_prefill_word(int unsigned index);
    return 32'h5A5A_2000 | index[31:0];
  endfunction

  virtual task prefill_rx_fifo();
    for (int unsigned i = 0; i < PREFILL_WORDS; i++) begin
      backdoor_write_fifo_entry(rx_paths, i, make_prefill_word(i));
    end
    backdoor_set_fifo_level(rx_paths, PREFILL_WORDS);
    settle_cycles();
    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit, 1'b1, 1'b0,
                      "after SDRR_006 RX prefill");
  endtask

  virtual function void build_read_payload(ref byte_queue_t read_data);
    read_data.delete();

    for (int unsigned i = 0; i < DATA_LENGTH; i++) begin
      read_data.push_back(8'(8'h60 + i));
    end
  endfunction

endclass
