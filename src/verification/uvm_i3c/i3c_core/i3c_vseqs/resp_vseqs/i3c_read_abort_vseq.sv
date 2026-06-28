class i3c_read_abort_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_abort_vseq)

  localparam int unsigned DATA_LENGTH = 8;
  localparam int unsigned DATA_LENGTH_DEEP = 16;

  localparam bit [3:0] FSM_ISSUE_CMD = 4'd11;

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
    word_queue_t                   rx_words;

    byte_queue_t                   read_data;
    for (int i = 0; i < DATA_LENGTH; i++) read_data.push_back(8'hA0 + 8'(i));

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_009 %s read_abort", private_addr_mode_name(broadcast_header_enable))),
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

    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1),
                                                .iba_include(broadcast_header_enable),
                                                .abort(1'b1)));
    `uvm_info(`gfn, $sformatf("ERR_009 result: mode=%s abort_asserted=1 source=HC_CONTROL[29]",
                              private_addr_mode_name(broadcast_header_enable)), UVM_LOW)

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);
    read_rx_words(int'(resp[15:0]), rx_words);

    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1),
                                                .iba_include(broadcast_header_enable)));
    check_all_queues_empty(
        $sformatf("ERR_009 %s early: before recovery transfer",
                  private_addr_mode_name(broadcast_header_enable)));
    run_read_recovery_case(broadcast_header_enable, "early_abort");
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty(
        $sformatf(
        "ERR_009 %s: after recovery SW reset", private_addr_mode_name(broadcast_header_enable)));

    `uvm_info(
        `gfn,
        $sformatf(
            "ERR_009 result: mode=%s case=early_abort resp_data_length=%0d requested_len=%0d recovery_without_reset=1",
            private_addr_mode_name(broadcast_header_enable), resp[15:0], DATA_LENGTH), UVM_LOW)
  endtask

  virtual task run_read_abort_deep_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;
    int unsigned                   rx_depth;
    word_queue_t                   rx_words;

    byte_queue_t                   read_data;
    for (int i = 0; i < DATA_LENGTH_DEEP; i++) read_data.push_back(8'hB0 + 8'(i));

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_009 %s read_abort_deep", private_addr_mode_name(broadcast_header_enable)
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
        rx_depth = hdl_read_fifo_depth(rx_paths.depth_path);
        if (rx_depth >= 1) break;
      end
      if (rx_depth < 1)
        `uvm_error(`gfn, "ERR_009 deep: RX FIFO never received a committed word before timeout")
    end

    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1),
                                                .iba_include(broadcast_header_enable),
                                                .abort(1'b1)));
    `uvm_info(
        `gfn,
        $sformatf(
            "ERR_009 result: mode=%s case=deep_abort abort_asserted=1 rx_depth_before_abort=%0d",
            private_addr_mode_name(broadcast_header_enable), rx_depth), UVM_LOW)

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);
    read_rx_words(int'(resp[15:0]), rx_words);

    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1),
                                                .iba_include(broadcast_header_enable)));
    check_all_queues_empty(
        $sformatf("ERR_009 %s deep: before recovery transfer",
                  private_addr_mode_name(broadcast_header_enable)));
    run_read_recovery_case(broadcast_header_enable, "deep_abort");
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty(
        $sformatf(
        "ERR_009 %s deep: after recovery SW reset", private_addr_mode_name(broadcast_header_enable)
        ));

    `uvm_info(
        `gfn,
        $sformatf(
            "ERR_009 result: mode=%s case=deep_abort resp_data_length=%0d requested_len=%0d recovery_without_reset=1",
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
    word_queue_t                   rx_words;

    byte_queue_t                   read_data;
    for (int i = 0; i < DATA_LENGTH; i++) read_data.push_back(8'hA0 + 8'(i));

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_009 %s read_abort_toc0",
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

    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1),
                                                .iba_include(broadcast_header_enable),
                                                .abort(1'b1)));

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);
    read_rx_words(int'(resp[15:0]), rx_words);

    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1),
                                                .iba_include(broadcast_header_enable)));
    check_all_queues_empty(
        $sformatf("ERR_009 %s toc0: before recovery transfer",
                  private_addr_mode_name(broadcast_header_enable)));
    run_read_recovery_case(broadcast_header_enable, "toc0_abort");
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty(
        $sformatf("ERR_009 %s toc0: after recovery SW reset",
                  private_addr_mode_name(broadcast_header_enable)));

    `uvm_info(
        `gfn,
        $sformatf(
            "ERR_009 result: mode=%s case=toc0_abort resp_data_length=%0d observed_rstart=%0b resp_status=0x%0h recovery_without_reset=1",
            private_addr_mode_name(broadcast_header_enable), resp[15:0], dev_seq.observed_rstart,
            resp[31:28]), UVM_LOW)
  endtask

  virtual task run_read_recovery_case(bit broadcast_header_enable, string case_name);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    word_queue_t            rx_words;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;

    build_random_payload(1, read_data);
    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_009 %s %s read recovery without SW reset",
                        private_addr_mode_name(broadcast_header_enable), case_name)),
        .seq_name($sformatf("err009_%s_%s_read_recovery_dev_seq",
                           private_addr_mode_name(broadcast_header_enable), case_name)),
        .tid(4'hE),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(read_data.size()),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    run_read_stimulus_words(cfg, read_data, rx_words, resp, dev_seq);
    check_all_queues_empty(cfg.ctxt);
  endtask

endclass
