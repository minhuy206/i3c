class i3c_read_abort_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_abort_vseq)

  localparam int unsigned DATA_LENGTH = 8;
  localparam int unsigned DATA_LENGTH_DEEP = 16;

  localparam bit [3:0] FSM_ISSUE_CMD = 4'd12;
  localparam bit [3:0] RESP_HC_ABORTED = 4'h8;

  function new(string name = "i3c_read_abort_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_read_abort_case(broadcast_modes[mode_idx]);
      run_read_abort_deep_case(broadcast_modes[mode_idx]);
      run_read_abort_toc_zero_case(broadcast_modes[mode_idx]);
    end

  endtask

  virtual task run_read_abort_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    byte_queue_t                   read_data;
    for (int i = 0; i < DATA_LENGTH; i++) read_data.push_back(8'hA0 + 8'(i));

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("SDRR_009 %s read_abort", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("sdrr009_%s_dev_seq", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd9),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b1, read_data, dev_seq);

    write_read_cmd(cfg, .toc(1'b1));

    wait_for_flow_fsm_state(FSM_ISSUE_CMD, cfg.ctxt, device_done_timeout_cycles(cfg));

    reg_write(ADDR_HC_CONTROL, {
              28'h0, 1'b1  /*HC_ABORT*/, broadcast_header_enable, 1'b0  /*SW_RST*/, 1'b1  /*EN*/});
    `uvm_info(`gfn, $sformatf("SDRR_009 result: mode=%s abort_asserted=1 source=HC_CONTROL[3]",
                              private_addr_mode_name(broadcast_header_enable)), UVM_LOW)

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    // Spec-compliant abort (MIPI I3C Basic v1.1.1 5.1.2.3.4): the controller must
    // not STOP right after the address ACK. It clocks the first data word to its
    // T-Bit, then (Target still parked, T=1) retakes SDA with a Repeated START
    // before STOP. Response reports HcAborted with the bytes actually received.
    `DV_CHECK_EQ(resp[31:28], 4'h8,
                 "SDRR_009 early abort: response status must be HcAborted")
    `DV_CHECK_GT(resp[15:0], 16'd0,
                 "SDRR_009 early abort: first data word must be clocked before takeover (no STOP right after ACK)")
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b1,
                 "SDRR_009 early abort: controller must retake SDA via Repeated START at the T-Bit")
    check_read_abort_payload(resp, cfg, read_data, "early_abort");

    reg_write(ADDR_HC_CONTROL, {28'h0, 1'b0  /*abort off*/, broadcast_header_enable, 1'b0, 1'b1});
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty(
        $sformatf(
        "SDRR_009 %s: after recovery SW reset", private_addr_mode_name(broadcast_header_enable)));

    `uvm_info(
        `gfn,
        $sformatf(
            "SDRR_009 result: mode=%s case=early_abort resp_data_length=%0d requested_len=%0d sw_reset_flushed_queues=1",
            private_addr_mode_name(broadcast_header_enable), resp[15:0], DATA_LENGTH), UVM_LOW)
  endtask

  virtual task run_read_abort_deep_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;
    uvm_hdl_data_t                 rx_depth_raw;
    int unsigned                   rx_depth;

    byte_queue_t                   read_data;
    for (int i = 0; i < DATA_LENGTH_DEEP; i++) read_data.push_back(8'hB0 + 8'(i));

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRR_009 %s read_abort_deep", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrr009_%s_deep_dev_seq", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'd9),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH_DEEP),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b1, read_data, dev_seq);

    write_read_cmd(cfg, .toc(1'b1));

    wait_for_flow_fsm_state(FSM_ISSUE_CMD, cfg.ctxt, device_done_timeout_cycles(cfg));
    begin : wait_rx_committed
      int timeout = device_done_timeout_cycles(cfg);
      for (int i = 0; i < timeout; i++) begin
        @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
        if (!uvm_hdl_read(rx_paths.depth_path, rx_depth_raw))
          `uvm_fatal(`gfn, "SDRR_009 deep: uvm_hdl_read failed for rx_paths.depth_path")
        rx_depth = int'(rx_depth_raw[3:0]);
        if (rx_depth >= 1) break;
      end
      if (rx_depth < 1)
        `uvm_error(`gfn, "SDRR_009 deep: RX FIFO never received a committed word before timeout")
    end

    reg_write(ADDR_HC_CONTROL, {
              28'h0, 1'b1  /*HC_ABORT*/, broadcast_header_enable, 1'b0  /*SW_RST*/, 1'b1  /*EN*/});
    `uvm_info(
        `gfn,
        $sformatf(
            "SDRR_009 result: mode=%s case=deep_abort abort_asserted=1 rx_depth_before_abort=%0d",
            private_addr_mode_name(broadcast_header_enable), rx_depth), UVM_LOW)

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    // Abort lands mid-stream (>=1 committed word). The controller finishes the
    // in-flight data word, then retakes SDA with a Repeated START at its T-Bit
    // (Target still has data, T=1) before STOP. Response reports HcAborted.
    `DV_CHECK_EQ(resp[31:28], 4'h8,
                 "SDRR_009 deep abort: response status must be HcAborted")
    `DV_CHECK_GT(resp[15:0], 16'd0,
                 "SDRR_009 deep abort: committed data words must be reported")
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b1,
                 "SDRR_009 deep abort: controller must retake SDA via Repeated START at the T-Bit")
    check_read_abort_payload(resp, cfg, read_data, "deep_abort");

    reg_write(ADDR_HC_CONTROL, {28'h0, 1'b0  /*abort off*/, broadcast_header_enable, 1'b0, 1'b1});
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty(
        $sformatf(
        "SDRR_009 %s deep: after recovery SW reset", private_addr_mode_name(broadcast_header_enable)
        ));

    `uvm_info(
        `gfn,
        $sformatf(
            "SDRR_009 result: mode=%s case=deep_abort resp_data_length=%0d requested_len=%0d sw_reset_flushed_queues=1",
            private_addr_mode_name(broadcast_header_enable), resp[15:0], DATA_LENGTH_DEEP), UVM_LOW)
  endtask

  // toc=0 abort: the read is programmed with toc=0 (continuation requested), but HC abort during
  // the data phase must override the continuation. The controller still retakes SDA with a Repeated
  // START at the T-Bit (MIPI I3C Basic v1.1.1 5.1.2.3.4) and then STOPs -- it must NOT chain a
  // continuation command. Response is HcAborted with the bytes received before the abort.
  virtual task run_read_abort_toc_zero_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    byte_queue_t                   read_data;
    for (int i = 0; i < DATA_LENGTH; i++) read_data.push_back(8'hA0 + 8'(i));

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("SDRR_009 %s read_abort_toc0",
                        private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("sdrr009_%s_toc0_dev_seq",
                            private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd9),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b1, read_data, dev_seq);

    write_read_cmd(cfg, .toc(1'b0));

    wait_for_flow_fsm_state(FSM_ISSUE_CMD, cfg.ctxt, device_done_timeout_cycles(cfg));

    reg_write(ADDR_HC_CONTROL, {
              28'h0, 1'b1  /*HC_ABORT*/, broadcast_header_enable, 1'b0  /*SW_RST*/, 1'b1  /*EN*/});

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    // Abort overrides the toc=0 continuation: HcAborted, takeover Repeated START then STOP.
    `DV_CHECK_EQ(resp[31:28], 4'h8,
                 "SDRR_009 toc0 abort: response status must be HcAborted")
    `DV_CHECK_GT(resp[15:0], 16'd0,
                 "SDRR_009 toc0 abort: first data word must be clocked before takeover")
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b1,
                 "SDRR_009 toc0 abort: controller must retake SDA via Repeated START at the T-Bit")
    check_read_abort_payload(resp, cfg, read_data, "toc0_abort");

    reg_write(ADDR_HC_CONTROL, {28'h0, 1'b0  /*abort off*/, broadcast_header_enable, 1'b0, 1'b1});
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty(
        $sformatf("SDRR_009 %s toc0: after recovery SW reset",
                  private_addr_mode_name(broadcast_header_enable)));

    `uvm_info(
        `gfn,
        $sformatf(
            "SDRR_009 result: mode=%s case=toc0_abort resp_data_length=%0d observed_rstart=%0b resp_status=0x%0h sw_reset_flushed_queues=1",
            private_addr_mode_name(broadcast_header_enable), resp[15:0], dev_seq.observed_rstart,
            resp[31:28]), UVM_LOW)
  endtask

  virtual task check_read_abort_payload(input bit [31:0] resp,
                                        input transfer_stimulus_cfg_t cfg,
                                        input byte_queue_t read_data,
                                        input string case_name);
    int unsigned committed_len;
    int unsigned drain_len;
    byte_queue_t committed_data;
    word_queue_t exp_words;
    word_queue_t rx_words;

    committed_len = int'(resp[15:0]);
    drain_len = (committed_len <= cfg.data_length) ? committed_len : cfg.data_length;

    `DV_CHECK_EQ(resp[31:28], RESP_HC_ABORTED,
                 $sformatf("%s: response status must be HcAborted", cfg.ctxt))
    `DV_CHECK_EQ(resp[27:24], cfg.tid, $sformatf("%s: response TID mismatch", cfg.ctxt))
    `DV_CHECK_EQ(resp[23:16], 8'h00, $sformatf("%s: response reserved field must be zero",
                                                cfg.ctxt))
    `DV_CHECK_LE(committed_len, cfg.data_length,
                 $sformatf("%s: committed length must not exceed request length", cfg.ctxt))

    committed_data.delete();
    for (int unsigned i = 0; i < drain_len; i++) begin
      committed_data.push_back(read_data[i]);
    end
    pack_payload_words(committed_data, exp_words);
    read_rx_words(drain_len, rx_words);

    `DV_CHECK_EQ(rx_words.size(), exp_words.size(),
                 $sformatf("%s: %s RX committed word count mismatch", cfg.ctxt, case_name))
    foreach (exp_words[i]) begin
      if (i < rx_words.size()) begin
        `DV_CHECK_EQ(rx_words[i], exp_words[i],
                     $sformatf("%s: %s RX committed word[%0d] mismatch", cfg.ctxt, case_name, i))
      end
    end
  endtask

endclass
