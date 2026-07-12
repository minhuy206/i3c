class i3c_read_rx_fifo_full_overflow_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_rx_fifo_full_overflow_vseq)

  localparam int unsigned DATA_LENGTH = 8;
  localparam int unsigned RX_FIFO_DEPTH = 8;
  localparam int unsigned PREFILL_WORDS = RX_FIFO_DEPTH;
  localparam int unsigned PARTIAL_PREFILL_WORDS = RX_FIFO_DEPTH - 1;

  function new(string name = "i3c_read_rx_fifo_full_overflow_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_rx_fifo_full_overflow_case(1'b1, broadcast_modes[mode_idx]);
    end
    run_rx_fifo_partial_overflow_case(1'b1);
    run_rx_fifo_overflow_toc_zero_case();
    run_rx_fifo_full_overflow_case(1'b0, 1'b0);
    run_rx_fifo_partial_overflow_case(1'b0);

    for (int unsigned data_length = 1; data_length <= 3; data_length++) begin
      run_rx_fifo_partial_dword_overflow_case(1'b1, data_length);
      run_rx_fifo_partial_dword_overflow_case(1'b0, data_length);
    end

    run_recovery_read_case(1'b1);
    run_recovery_read_case(1'b0);

  endtask

  virtual task run_rx_fifo_overflow_toc_zero_case();
    transfer_stimulus_cfg_t        cfg;
    regular_trans_desc_t           rd_cmd;
    byte_queue_t                   read_data;
    bit                     [31:0] rx_word;
    bit                     [31:0] resp;
    transfer_stimulus_cfg_t        cfg1;
    regular_trans_desc_t           wr_cmd;
    byte_queue_t                   no_read_data;
    bit                     [31:0] resp1;
    i3c_device_response_seq        dev_seq;
    i3c_device_response_seq        dev_seq1;

    enable_dut(1'b0);
    configure_rx_target(1'b1);

    build_read_payload(read_data);
    prefill_rx_fifo_count(PARTIAL_PREFILL_WORDS, "after ERR_007 toc0 RX prefill");

    cfg = make_transfer_cfg(
        .ctxt("ERR_007 toc0 rx_fifo_overflow with queued followup"),
        .seq_name("err007_toc0_overflow_dev_seq"),
        .tid(4'd8),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    cfg1 = make_transfer_cfg(
        .ctxt("ERR_007 clean command queued behind RX overflow"),
        .seq_name("err007_toc0_overflow_followup_dev_seq"),
        .tid(4'd9),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(0),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    // Queue a valid next command so overflow must actively suppress continuation.
    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b0);
    wr_cmd = build_regular_transfer_cmd(cfg1, 1'b0, 1'b1);
    start_ordered_device_responses(cfg, 1'b1, read_data, dev_seq, cfg1, 1'b0, no_read_data,
                                   dev_seq1);
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);
    write_cmd(wr_cmd[31:0], wr_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    read_response(resp);
    read_response(resp1);

    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b0,
                 "ERR_007 RX overflow must force STOP instead of continuing queued command")

    for (int unsigned i = 0; i < PARTIAL_PREFILL_WORDS; i++) begin
      read_rx_data(rx_word);
      `DV_CHECK_EQ(rx_word, make_prefill_word(i), $sformatf(
                   "ERR_007 toc0: drained RX prefill word[%0d] mismatch", i))
    end
    read_rx_data(rx_word);

    check_all_queues_empty("after ERR_007 toc0 rx_fifo_overflow");

  endtask

  virtual task run_rx_fifo_full_overflow_case(bit is_i3c, bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    regular_trans_desc_t           rd_cmd;
    byte_queue_t                   read_data;
    bit                     [31:0] rx_word;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(is_i3c && broadcast_header_enable);
    configure_rx_target(is_i3c);

    build_read_payload(read_data);
    prefill_rx_fifo();

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_007 %s_%s rx_fifo_full_overflow",
            is_i3c ? "i3c" : "i2c",
            private_addr_mode_name(
                broadcast_header_enable
            )
        )),
        .seq_name($sformatf(
            "err007_%s_%s_full_dev_seq",
            is_i3c ? "i3c" : "i2c",
            private_addr_mode_name(
                broadcast_header_enable
            )
        )),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(is_i3c ? 7'h08 : 7'h50),
        .is_i3c(is_i3c),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(is_i3c && broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b1);
    start_device_response(cfg, 1'b1, read_data, dev_seq);
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit, 1'b1, 1'b0,
                      "before ERR_007 prefill drain");
    for (int unsigned i = 0; i < PREFILL_WORDS; i++) begin
      read_rx_data(rx_word);
      `DV_CHECK_EQ(rx_word, make_prefill_word(i), $sformatf(
                   "ERR_007: drained RX prefill word[%0d] mismatch", i))
    end

    if (!is_i3c) begin
      `DV_CHECK_GT(dev_seq.sampled_data_nack_q.size(), 0,
                   "ERR_007 I2C RX overflow did not sample an ACK/NACK bit")
      if (dev_seq.sampled_data_nack_q.size() > 0) begin
        `DV_CHECK_EQ(dev_seq.sampled_data_nack_q[dev_seq.sampled_data_nack_q.size()-1], SampledNack,
                     "ERR_007 I2C RX overflow must terminate the final accepted byte with NACK")
      end
    end
    check_all_queues_empty("after ERR_007 rx_fifo_full_overflow");

  endtask

  virtual task run_rx_fifo_partial_overflow_case(bit is_i3c);
    transfer_stimulus_cfg_t        cfg;
    regular_trans_desc_t           rd_cmd;
    byte_queue_t                   read_data;
    bit                     [31:0] rx_word;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(1'b0);
    configure_rx_target(is_i3c);

    build_read_payload(read_data);
    prefill_rx_fifo_count(PARTIAL_PREFILL_WORDS, "after ERR_007 partial RX prefill");

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_007 %s partial_rx_fifo_overflow", is_i3c ? "i3c" : "i2c")),
        .seq_name($sformatf("err007_%s_partial_overflow_dev_seq", is_i3c ? "i3c" : "i2c")),
        .tid(4'd7),
        .dev_idx(5'd0),
        .target_addr(is_i3c ? 7'h08 : 7'h50),
        .is_i3c(is_i3c),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b1);
    start_device_response(cfg, 1'b1, read_data, dev_seq);
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit, 1'b1, 1'b0,
                      "before ERR_007 partial drain");
    for (int unsigned i = 0; i < PARTIAL_PREFILL_WORDS; i++) begin
      read_rx_data(rx_word);
      `DV_CHECK_EQ(rx_word, make_prefill_word(i), $sformatf(
                   "ERR_007 partial: drained RX prefill word[%0d] mismatch", i))
    end
    read_rx_data(rx_word);

    if (!is_i3c) begin
      `DV_CHECK_GT(dev_seq.sampled_data_nack_q.size(), 0,
                   "ERR_007 I2C partial RX overflow did not sample an ACK/NACK bit")
      if (dev_seq.sampled_data_nack_q.size() > 0) begin
        `DV_CHECK_EQ(dev_seq.sampled_data_nack_q[dev_seq.sampled_data_nack_q.size()-1], SampledNack,
                     "ERR_007 I2C partial RX overflow must terminate with NACK")
      end
    end
    check_all_queues_empty("after ERR_007 partial_rx_fifo_overflow");

  endtask

  virtual task run_rx_fifo_partial_dword_overflow_case(bit is_i3c, int unsigned data_length);
    transfer_stimulus_cfg_t        cfg;
    regular_trans_desc_t           rd_cmd;
    byte_queue_t                   read_data;
    bit                     [31:0] rx_word;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(1'b0);
    configure_rx_target(is_i3c);
    build_read_payload_len(data_length, read_data);
    prefill_rx_fifo_count(
        PREFILL_WORDS, $sformatf(
        "after ERR_007 %s partial-DWORD RX prefill len%0d", is_i3c ? "I3C" : "I2C", data_length));

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_007 %s partial-DWORD overflow len%0d", is_i3c ? "I3C" : "I2C", data_length
        )),
        .seq_name($sformatf(
            "err007_%s_partial_dword_len%0d_dev_seq", is_i3c ? "i3c" : "i2c", data_length
        )),
        .tid(4'(data_length)),
        .dev_idx(5'd0),
        .target_addr(is_i3c ? 7'h08 : 7'h50),
        .is_i3c(is_i3c),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(data_length),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b1);
    start_device_response(cfg, 1'b1, read_data, dev_seq);
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    for (int unsigned i = 0; i < PREFILL_WORDS; i++) begin
      read_rx_data(rx_word);
      `DV_CHECK_EQ(rx_word, make_prefill_word(i), $sformatf(
                   "ERR_007 partial-DWORD: drained RX prefill word[%0d] mismatch", i))
    end
    if (!is_i3c) begin
      `DV_CHECK_GT(dev_seq.sampled_data_nack_q.size(), 0,
                   "ERR_007 I2C partial-DWORD overflow did not sample an ACK/NACK bit")
      if (dev_seq.sampled_data_nack_q.size() > 0) begin
        `DV_CHECK_EQ(dev_seq.sampled_data_nack_q[dev_seq.sampled_data_nack_q.size()-1], SampledNack,
                     "ERR_007 I2C partial-DWORD overflow must terminate with NACK")
      end
    end
    check_all_queues_empty(cfg.ctxt);
  endtask

  virtual task run_recovery_read_case(bit is_i3c);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    word_queue_t                   rx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(1'b0);
    configure_rx_target(is_i3c);
    build_read_payload_len(3, read_data);
    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_007 %s read recovery without SW reset", is_i3c ? "I3C" : "I2C")),
        .seq_name($sformatf("err007_%s_read_recovery_dev_seq", is_i3c ? "i3c" : "i2c")),
        .tid(is_i3c ? 4'hD : 4'hE),
        .dev_idx(5'd0),
        .target_addr(is_i3c ? 7'h08 : 7'h50),
        .is_i3c(is_i3c),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(read_data.size()),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_read_stimulus_words(cfg, read_data, cfg.data_length, rx_words, resp, dev_seq);
    check_all_queues_empty(cfg.ctxt);
  endtask

  virtual function bit [31:0] make_prefill_word(int unsigned index);
    return 32'h5A5A_2000 | index[31:0];
  endfunction

  virtual task configure_rx_target(bit is_i3c);
    if (is_i3c) begin
      configure_i3c_dat_target(0, 7'h50, 7'h08);
    end else begin
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr_valid = 1'b0;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.dynamic_addr_valid = 1'b0;
      write_dat_entry(0, 7'h50, 7'h08, 1'b1);
    end
  endtask

  virtual task prefill_rx_fifo();
    prefill_rx_fifo_count(PREFILL_WORDS, "after ERR_007 RX prefill");
  endtask

  virtual task prefill_rx_fifo_count(int unsigned count, string ctxt);
    for (int unsigned i = 0; i < PREFILL_WORDS; i++) begin
      if (i < count) backdoor_write_fifo_entry(rx_paths, i, make_prefill_word(i));
    end
    backdoor_set_fifo_level(rx_paths, count);
    settle_cycles();
    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit,
                      (count == RX_FIFO_DEPTH), (count == 0), ctxt);
  endtask

  virtual function void build_read_payload(ref byte_queue_t read_data);
    build_read_payload_len(DATA_LENGTH, read_data);
  endfunction

  virtual function void build_read_payload_len(int unsigned data_length,
                                               ref byte_queue_t read_data);
    build_random_payload(data_length, read_data);
  endfunction

endclass
