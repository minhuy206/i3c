class i3c_write_tx_fifo_underflow_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_tx_fifo_underflow_vseq)

  localparam int unsigned DATA_LENGTH = 8;
  localparam int unsigned ACTUAL_LENGTH = 4;

  function new(string name = "i3c_write_tx_fifo_underflow_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};
    bit toc_modes[2] = '{1'b1, 1'b0};

    foreach (broadcast_modes[mode_idx]) begin
      foreach (toc_modes[toc_idx]) begin
        run_tx_fifo_underflow_ovl_case(1'b1, broadcast_modes[mode_idx], toc_modes[toc_idx]);
        run_tx_fifo_empty_underflow_ovl_case(1'b1, broadcast_modes[mode_idx], toc_modes[toc_idx],
                                             4);
        run_tx_fifo_empty_underflow_ovl_case(1'b1, broadcast_modes[mode_idx], toc_modes[toc_idx],
                                             8);
      end
      run_underflow_with_queued_followup_case(broadcast_modes[mode_idx]);
      run_late_refill_after_underflow_case(1'b1, broadcast_modes[mode_idx]);
    end

    foreach (toc_modes[toc_idx]) begin
      run_tx_fifo_underflow_ovl_case(1'b0, 1'b0, toc_modes[toc_idx]);
      run_tx_fifo_empty_underflow_ovl_case(1'b0, 1'b0, toc_modes[toc_idx], 4);
    end
    run_late_refill_after_underflow_case(1'b0, 1'b0);

  endtask

  virtual task run_tx_fifo_underflow_ovl_case(bit is_i3c, bit broadcast_header_enable, bit toc);
    transfer_stimulus_cfg_t        cfg;
    transfer_stimulus_cfg_t        dev_cfg;
    byte_queue_t                   no_read_data;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    bit                     [ 6:0] static_addr;
    bit                     [ 6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq;

    enable_dut(is_i3c && broadcast_header_enable);
    if (is_i3c) begin
      randomize_i3c_dat_target(0, static_addr, dynamic_addr);
    end else begin
      static_addr = 7'h50;
      dynamic_addr = 7'h08;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr_valid = 1'b0;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.dynamic_addr_valid = 1'b0;
      write_dat_entry(0, static_addr, dynamic_addr, 1'b1);
    end

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_007 %s_%s toc%0d tx_fifo_underflow_ovl",
            is_i3c ? "i3c" : "i2c",
            private_addr_mode_name(
                broadcast_header_enable
            ),
            toc
        )),
        .seq_name($sformatf(
            "err007_%s_%s_toc%0d_dev_seq",
            is_i3c ? "i3c" : "i2c",
            private_addr_mode_name(
                broadcast_header_enable
            ),
            toc
        )),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(is_i3c ? dynamic_addr : static_addr),
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

    dev_cfg = cfg;
    dev_cfg.data_length = ACTUAL_LENGTH;
    start_device_response(dev_cfg, 1'b0, no_read_data, dev_seq);

    build_random_tx_words(ACTUAL_LENGTH, exp_data, tx_words);
    write_tx_words(tx_words);
    write_write_cmd(cfg, toc);

    poll_idle();
    settle_cycles(1);
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_all_queues_empty($sformatf("after ERR_007 toc%0d tx_fifo_underflow_ovl", toc));

  endtask

  virtual task run_tx_fifo_empty_underflow_ovl_case(bit is_i3c, bit broadcast_header_enable,
                                                    bit toc, int unsigned data_length);
    transfer_stimulus_cfg_t        cfg;
    transfer_stimulus_cfg_t        dev_cfg;
    byte_queue_t                   no_read_data;
    bit                     [31:0] resp;
    bit                     [ 6:0] static_addr;
    bit                     [ 6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq;

    enable_dut(is_i3c && broadcast_header_enable);
    if (is_i3c) begin
      randomize_i3c_dat_target(0, static_addr, dynamic_addr);
    end else begin
      static_addr = 7'h50;
      dynamic_addr = 7'h08;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr_valid = 1'b0;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.dynamic_addr_valid = 1'b0;
      write_dat_entry(0, static_addr, dynamic_addr, 1'b1);
    end

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_007 %s_%s toc%0d tx_fifo_empty_underflow_ovl len%0d",
            is_i3c ? "i3c" : "i2c",
            private_addr_mode_name(
                broadcast_header_enable
            ),
            toc,
            data_length
        )),
        .seq_name($sformatf(
            "err007_%s_%s_toc%0d_empty_dev_seq_len%0d",
            is_i3c ? "i3c" : "i2c",
            private_addr_mode_name(
                broadcast_header_enable
            ),
            toc,
            data_length
        )),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(is_i3c ? dynamic_addr : static_addr),
        .is_i3c(is_i3c),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(is_i3c && broadcast_header_enable),
        .data_length(data_length),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    dev_cfg = cfg;
    dev_cfg.data_length = 0;
    start_device_response(dev_cfg, 1'b0, no_read_data, dev_seq);

    write_write_cmd(cfg, toc);

    poll_idle();
    settle_cycles(1);
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_all_queues_empty(
        $sformatf("after ERR_007 toc%0d tx_fifo_empty_underflow_ovl len%0d", toc, data_length));

  endtask

  virtual task run_late_refill_after_underflow_case(bit is_i3c, bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    transfer_stimulus_cfg_t        dev_cfg;
    byte_queue_t                   no_read_data;
    byte_queue_t                   exp_data;
    byte_queue_t                   late_exp_data;
    word_queue_t                   tx_words;
    word_queue_t                   late_tx_words;
    bit                     [31:0] resp;
    bit                     [ 6:0] static_addr;
    bit                     [ 6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq;

    enable_dut(is_i3c && broadcast_header_enable);
    if (is_i3c) begin
      randomize_i3c_dat_target(0, static_addr, dynamic_addr);
    end else begin
      static_addr = 7'h50;
      dynamic_addr = 7'h08;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr_valid = 1'b0;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.dynamic_addr_valid = 1'b0;
      write_dat_entry(0, static_addr, dynamic_addr, 1'b1);
    end

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_007 %s_%s tx_fifo_late_refill_after_ovl",
            is_i3c ? "i3c" : "i2c",
            private_addr_mode_name(
                broadcast_header_enable
            )
        )),
        .seq_name($sformatf(
            "err007_%s_%s_late_refill_dev_seq",
            is_i3c ? "i3c" : "i2c",
            private_addr_mode_name(
                broadcast_header_enable
            )
        )),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(is_i3c ? dynamic_addr : static_addr),
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

    dev_cfg = cfg;
    dev_cfg.data_length = ACTUAL_LENGTH;
    start_device_response(dev_cfg, 1'b0, no_read_data, dev_seq);

    build_random_tx_words(ACTUAL_LENGTH, exp_data, tx_words);
    write_tx_words(tx_words);
    write_write_cmd(cfg);

    poll_idle();
    settle_cycles(1);
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    build_random_tx_words(4, late_exp_data, late_tx_words);
    write_tx_words(late_tx_words);
    check_queue_flags(tx_paths.name, tx_paths.full_bit, tx_paths.empty_bit, 1'b0, 1'b0,
                      "after ERR_007 late refill");
    request_sw_reset(1'b1);
    check_all_queues_empty("after ERR_007 late refill SW reset");
    run_recovery_write_case(is_i3c, broadcast_header_enable, static_addr, dynamic_addr);

  endtask

  virtual task run_underflow_with_queued_followup_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        dev_cfg0;
    transfer_stimulus_cfg_t        cfg1;
    byte_queue_t                   no_read_data;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    bit                     [ 6:0] static_addr;
    bit                     [ 6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;

    enable_dut(broadcast_header_enable);
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);

    cfg0 = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_007 %s underflow with queued followup",
            private_addr_mode_name(
                broadcast_header_enable
            )
        )),
        .seq_name($sformatf(
            "err007_%s_underflow_queued_dev_seq0", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hA),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    cfg1 = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_007 %s clean command after queued underflow",
            private_addr_mode_name(
                broadcast_header_enable
            )
        )),
        .seq_name($sformatf(
            "err007_%s_underflow_queued_dev_seq1", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hB),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(0),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    dev_cfg0 = cfg0;
    dev_cfg0.data_length = ACTUAL_LENGTH;
    start_ordered_device_responses(dev_cfg0, 1'b0, no_read_data, dev_seq0, cfg1, 1'b0, no_read_data,
                                   dev_seq1);
    build_random_tx_words(ACTUAL_LENGTH, exp_data, tx_words);
    write_tx_words(tx_words);
    write_write_cmd(cfg0, 1'b0);
    write_write_cmd(cfg1, 1'b1);

    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    read_response(resp0);
    read_response(resp1);

    `DV_CHECK_EQ(dev_seq0.observed_rstart, 1'b0,
                 "ERR_007 TX underflow must force STOP instead of continuing queued command")
    check_all_queues_empty("after ERR_007 queued TX-underflow recovery command");
  endtask

  virtual task run_recovery_write_case(bit is_i3c, bit broadcast_header_enable,
                                       bit [6:0] static_addr, bit [6:0] dynamic_addr);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_007 %s recovery write", is_i3c ? "I3C" : "I2C")),
        .seq_name($sformatf("err007_%s_recovery_write_dev_seq", is_i3c ? "i3c" : "i2c")),
        .tid(4'hC),
        .dev_idx(5'd0),
        .target_addr(is_i3c ? dynamic_addr : static_addr),
        .is_i3c(is_i3c),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(is_i3c && broadcast_header_enable),
        .data_length(4),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    build_random_tx_words(cfg.data_length, exp_data, tx_words);
    run_write_stimulus(cfg, tx_words, resp, dev_seq);
    check_all_queues_empty(cfg.ctxt);
  endtask

endclass
