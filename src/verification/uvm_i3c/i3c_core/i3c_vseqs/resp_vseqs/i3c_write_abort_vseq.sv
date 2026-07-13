class i3c_write_abort_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_abort_vseq)

  // Early abort: fires right at IssueI3CWrite entry, likely 0-3 bytes sent.
  localparam int unsigned DATA_LENGTH = 8;
  // Deep abort: fires after >=1 TX word consumed (>=4 bytes sent), tests SW reset flushes TX FIFO.
  localparam int unsigned DATA_LENGTH_DEEP = 16;


  function new(string name = "i3c_write_abort_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_write_abort_case(broadcast_modes[mode_idx]);
      run_write_abort_deep_case(broadcast_modes[mode_idx]);
      run_write_abort_toc_zero_case(broadcast_modes[mode_idx]);
    end

  endtask

  virtual task run_write_abort_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   no_read_data;
    byte_queue_t                   exp_data;
    bit                     [31:0] resp;
    bit                     [ 6:0] static_addr;
    bit                     [ 6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq;

    word_queue_t                   tx_words;
    build_random_tx_words(DATA_LENGTH, exp_data, tx_words);

    enable_dut(broadcast_header_enable);
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_009 %s write_abort", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("err009_%s_dev_seq", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd9),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);

    write_tx_words(tx_words);
    write_write_cmd(cfg, .toc(1'b1));

    wait_for_flow_fsm_state(IssueI3CWrite, cfg.ctxt, device_done_timeout_cycles(cfg));

    reg_write(ADDR_HC_CONTROL, hc_control_value(
              .bus_enable(1'b1), .iba_include(broadcast_header_enable), .abort(1'b1)));

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    reg_write(ADDR_HC_CONTROL, hc_control_value(
              .bus_enable(1'b1), .iba_include(broadcast_header_enable)));
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty(
        $sformatf(
        "ERR_009 %s: after recovery SW reset", private_addr_mode_name(broadcast_header_enable)));

  endtask

  // Deep-abort case: waits until at least one TX word is consumed (>=4 bytes sent) before
  // asserting abort. Exercises the path where SW reset must flush remaining TX FIFO entries.
  virtual task run_write_abort_deep_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   no_read_data;
    byte_queue_t                   exp_data;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;
    int unsigned                   tx_depth;
    bit                     [ 6:0] static_addr;
    bit                     [ 6:0] dynamic_addr;

    word_queue_t                   tx_words;
    build_random_tx_words(DATA_LENGTH_DEEP, exp_data, tx_words);

    enable_dut(broadcast_header_enable);
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_009 %s write_abort_deep", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "err009_%s_deep_dev_seq", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'd9),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH_DEEP),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);

    write_tx_words(tx_words);
    write_write_cmd(cfg, .toc(1'b1));

    // Enter data phase, then hold off abort until >=1 TX word has been popped from the FIFO.
    wait_for_flow_fsm_state(IssueI3CWrite, cfg.ctxt, device_done_timeout_cycles(cfg));
    begin : wait_tx_consumed
      int timeout = device_done_timeout_cycles(cfg);
      for (int i = 0; i < timeout; i++) begin
        @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
        tx_depth = hdl_read_fifo_depth(tx_paths.depth_path);
        if (tx_depth < DATA_LENGTH_DEEP / 4) break;
      end
      if (tx_depth >= DATA_LENGTH_DEEP / 4)
        `uvm_error(`gfn, "ERR_009 deep: TX FIFO never consumed a word before timeout")
    end

    reg_write(ADDR_HC_CONTROL, hc_control_value(
              .bus_enable(1'b1), .iba_include(broadcast_header_enable), .abort(1'b1)));
    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    reg_write(ADDR_HC_CONTROL, hc_control_value(
              .bus_enable(1'b1), .iba_include(broadcast_header_enable)));
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty(
        $sformatf(
        "ERR_009 %s deep: after recovery SW reset", private_addr_mode_name(broadcast_header_enable)
        ));

  endtask

  // toc=0 abort: the write is programmed with toc=0 (continuation requested), but HC abort during
  // the data phase must override the continuation -- the controller still terminates with STOP and
  // reports HcAborted, never a Repeated-START continuation. Bytes sent before abort are intact.
  virtual task run_write_abort_toc_zero_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   no_read_data;
    byte_queue_t                   exp_bytes;
    bit                     [31:0] resp;
    bit                     [ 6:0] static_addr;
    bit                     [ 6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq;

    word_queue_t                   tx_words;
    build_random_tx_words(DATA_LENGTH, exp_bytes, tx_words);

    enable_dut(broadcast_header_enable);
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_009 %s write_abort_toc0", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "err009_%s_toc0_dev_seq", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'd9),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);

    write_tx_words(tx_words);
    write_write_cmd(cfg, .toc(1'b0));

    wait_for_flow_fsm_state(IssueI3CWrite, cfg.ctxt, device_done_timeout_cycles(cfg));

    reg_write(ADDR_HC_CONTROL, hc_control_value(
              .bus_enable(1'b1), .iba_include(broadcast_header_enable), .abort(1'b1)));

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    reg_write(ADDR_HC_CONTROL, hc_control_value(
              .bus_enable(1'b1), .iba_include(broadcast_header_enable)));
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty(
        $sformatf(
        "ERR_009 %s toc0: after recovery SW reset", private_addr_mode_name(broadcast_header_enable)
        ));

  endtask

endclass
