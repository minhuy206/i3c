class i3c_read_rx_fifo_full_overflow_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_rx_fifo_full_overflow_vseq)

  localparam int unsigned DATA_LENGTH = 8;
  localparam int unsigned OBSERVED_LENGTH = 4;
  localparam int unsigned RX_FIFO_DEPTH = 8;
  localparam int unsigned PREFILL_WORDS = RX_FIFO_DEPTH;
  localparam int unsigned PARTIAL_PREFILL_WORDS = RX_FIFO_DEPTH - 1;
  localparam logic [3:0]  RESP_OVL = 4'h6;

  function new(string name = "i3c_read_rx_fifo_full_overflow_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_rx_fifo_full_overflow_case(broadcast_modes[mode_idx]);
    end
    run_rx_fifo_partial_overflow_case();
    run_rx_fifo_overflow_toc_zero_case();

  endtask

  // toc=0 overflow: the read is programmed with toc=0 (continuation requested), but RX overflow is
  // an error that must force STOP and override the continuation. Prefill RX one short of full so the
  // read commits exactly one word and then overflows; the controller takes over, STOPs (no
  // continuation RSTART), and reports Ovl. Prefill plus the one accepted word are preserved.
  virtual task run_rx_fifo_overflow_toc_zero_case();
    transfer_stimulus_cfg_t cfg;
    regular_trans_desc_t    rd_cmd;
    byte_queue_t            read_data;
    bit [31:0]              rx_word;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    build_read_payload(read_data);
    prefill_rx_fifo_count(PARTIAL_PREFILL_WORDS, "after SDRR_006 toc0 RX prefill");

    cfg = make_transfer_cfg(
        .ctxt("SDRR_006 toc0 rx_fifo_overflow"),
        .seq_name("sdrr006_toc0_overflow_dev_seq"),
        .tid(4'd8), .dev_idx(5'd0), .target_addr(7'h08), .is_i3c(1'b1),
        .ack_address(1'b1), .ack_data(1'b1), .tx_before_cmd(1'b1), .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0), .data_length(DATA_LENGTH), .settle_before_cmd(0),
        .timeout_cycles(0));

    // toc=0 here is the point of the test: overflow must override the requested continuation.
    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b0);
    start_device_response(cfg, 1'b1, read_data, dev_seq);
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    // Overflow overrides toc=0: response is Ovl and the read ended (takeover) rather than chaining.
    check_error_resp_fields(resp, RESP_OVL, cfg.tid, DATA_LENGTH, cfg.ctxt);

    for (int unsigned i = 0; i < PARTIAL_PREFILL_WORDS; i++) begin
      read_rx_data(rx_word);
      `DV_CHECK_EQ(rx_word, make_prefill_word(i),
                   $sformatf("SDRR_006 toc0: drained RX prefill word[%0d] mismatch", i))
    end
    read_rx_data(rx_word);
    `DV_CHECK_EQ(rx_word, make_read_word(read_data, 0),
                 "SDRR_006 toc0: accepted read word mismatch")

    check_all_queues_empty("after SDRR_006 toc0 rx_fifo_overflow");

    `uvm_info(`gfn, $sformatf(
                  "SDRR_006 result: case=toc0_overflow resp_status=0x%0h resp_len=%0d observed_rstart=%0b accepted_read_words=1",
                  resp[31:28], resp[15:0], dev_seq.observed_rstart), UVM_LOW)
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

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b1);
    start_device_response(cfg, 1'b1, read_data, dev_seq);
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit, 1'b1, 1'b0,
                      "before SDRR_006 prefill drain");
    for (int unsigned i = 0; i < PREFILL_WORDS; i++) begin
      read_rx_data(rx_word);
      `DV_CHECK_EQ(rx_word, make_prefill_word(i), $sformatf(
                   "SDRR_006: drained RX prefill word[%0d] mismatch", i))
    end

    check_all_queues_empty("after SDRR_006 rx_fifo_full_overflow");

    `uvm_info(`gfn, $sformatf(
                  "SDRR_006 result: mode=%s full_prefill_words=%0d read_len=%0d drained_prefill_words=%0d accepted_read_words=0",
                  private_addr_mode_name(broadcast_header_enable), PREFILL_WORDS, DATA_LENGTH,
                  PREFILL_WORDS), UVM_LOW)
  endtask

  virtual task run_rx_fifo_partial_overflow_case();
    transfer_stimulus_cfg_t cfg;
    regular_trans_desc_t    rd_cmd;
    byte_queue_t            read_data;
    bit [31:0]              rx_word;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    build_read_payload(read_data);
    prefill_rx_fifo_count(PARTIAL_PREFILL_WORDS, "after SDRR_006 partial RX prefill");

    cfg = make_transfer_cfg(
        .ctxt("SDRR_006 partial_rx_fifo_overflow"),
        .seq_name("sdrr006_partial_overflow_dev_seq"),
        .tid(4'd7),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
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
    check_error_resp_fields(resp, RESP_OVL, cfg.tid, DATA_LENGTH, cfg.ctxt);

    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit, 1'b1, 1'b0,
                      "before SDRR_006 partial drain");
    for (int unsigned i = 0; i < PARTIAL_PREFILL_WORDS; i++) begin
      read_rx_data(rx_word);
      `DV_CHECK_EQ(rx_word, make_prefill_word(i), $sformatf(
                   "SDRR_006 partial: drained RX prefill word[%0d] mismatch", i))
    end
    read_rx_data(rx_word);
    `DV_CHECK_EQ(rx_word, make_read_word(read_data, 0),
                 "SDRR_006 partial: accepted read word mismatch")

    check_all_queues_empty("after SDRR_006 partial_rx_fifo_overflow");

    `uvm_info(`gfn, $sformatf(
                  "SDRR_006 result: mode=%s partial_prefill_words=%0d read_len=%0d drained_prefill_words=%0d accepted_read_words=1",
                  private_addr_mode_name(1'b0), PARTIAL_PREFILL_WORDS, DATA_LENGTH,
                  PARTIAL_PREFILL_WORDS), UVM_LOW)
  endtask

  virtual function bit [31:0] make_prefill_word(int unsigned index);
    return 32'h5A5A_2000 | index[31:0];
  endfunction

  virtual task prefill_rx_fifo();
    prefill_rx_fifo_count(PREFILL_WORDS, "after SDRR_006 RX prefill");
  endtask

  virtual task prefill_rx_fifo_count(int unsigned count, string ctxt);
    for (int unsigned i = 0; i < PREFILL_WORDS; i++) begin
      if (i < count) backdoor_write_fifo_entry(rx_paths, i, make_prefill_word(i));
    end
    backdoor_set_fifo_level(rx_paths, count);
    settle_cycles();
    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit, (count == RX_FIFO_DEPTH),
                      (count == 0), ctxt);
  endtask

  virtual function void build_read_payload(ref byte_queue_t read_data);
    read_data.delete();

    for (int unsigned i = 0; i < DATA_LENGTH; i++) begin
      read_data.push_back(8'(8'h60 + i));
    end
  endfunction

  virtual function bit [31:0] make_read_word(byte_queue_t read_data, int unsigned word_idx);
    bit [31:0] word;

    word = '0;
    for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++) begin
      int unsigned data_idx;

      data_idx = (word_idx * 4) + byte_idx;
      if (data_idx < read_data.size()) word[(byte_idx*8)+:8] = read_data[data_idx];
    end
    return word;
  endfunction

endclass
