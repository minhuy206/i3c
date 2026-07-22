class i3c_write_toc_zero_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_toc_zero_vseq)

  function new(string name = "i3c_write_toc_zero_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_toc_zero_case(broadcast_modes[mode_idx]);
      run_toc_zero_write_read_case(broadcast_modes[mode_idx]);
      run_toc_zero_missing_next_cmd_case(broadcast_modes[mode_idx]);
      run_toc_zero_unsupported_next_cmd_case(broadcast_modes[mode_idx]);
    end

  endtask

  virtual task run_toc_zero_write_read_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg0;
    transfer_stimulus_cfg_t cfg1;
    regular_trans_desc_t    write_cmd_desc;
    regular_trans_desc_t    read_cmd_desc;
    byte_queue_t            no_read_data;
    byte_queue_t            read_data;
    byte_queue_t            exp_write_data;
    word_queue_t            tx_words;
    word_queue_t            rx_words;
    i3c_device_response_seq dev_seq0;
    i3c_device_response_seq dev_seq1;
    i3c_response_desc_t     resp_desc;
    bit              [31:0] resp;
    bit              [ 6:0] static_addr;
    bit              [ 6:0] dynamic_addr;

    enable_dut(broadcast_header_enable);
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);
    cfg0 = make_transfer_cfg(
        .ctxt($sformatf("toc0 write-read %s write",
                        private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("toc0_wr_rd_%s_write_dev_seq",
                            private_addr_mode_name(broadcast_header_enable))),
        .tid(4'h8), .dev_idx(5'd0), .target_addr(dynamic_addr), .is_i3c(1'b1),
        .addr_nack(1'b0), .data_nack(1'b0), .tx_before_cmd(1'b1),
        .wait_device_done(1'b1), .start_with_broadcast_header(broadcast_header_enable),
        .data_length(2), .settle_before_cmd(0), .timeout_cycles(0));
    cfg1 = make_transfer_cfg(
        .ctxt($sformatf("toc0 write-read %s read",
                        private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("toc0_wr_rd_%s_read_dev_seq",
                            private_addr_mode_name(broadcast_header_enable))),
        .tid(4'h9), .dev_idx(5'd0), .target_addr(dynamic_addr), .is_i3c(1'b1),
        .addr_nack(1'b0), .data_nack(1'b0), .tx_before_cmd(1'b0),
        .wait_device_done(1'b1), .start_with_broadcast_header(1'b0),
        .data_length(2), .settle_before_cmd(0), .timeout_cycles(0));

    write_cmd_desc = build_regular_transfer_cmd(cfg0, 1'b0, 1'b0);
    read_cmd_desc = build_regular_transfer_cmd(cfg1, 1'b1, 1'b1);
    build_random_tx_words(cfg0.data_length, exp_write_data, tx_words);
    build_random_payload(cfg1.data_length, read_data);
    start_ordered_device_responses(cfg0, 1'b0, no_read_data, dev_seq0,
                                   cfg1, 1'b1, read_data, dev_seq1);
    write_tx_words(tx_words);
    write_cmd(write_cmd_desc[31:0], write_cmd_desc[63:32]);
    write_cmd(read_cmd_desc[31:0], read_cmd_desc[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    read_rx_words(cfg1.data_length, rx_words);
    read_response(resp);
    resp_desc = i3c_response_desc_t'(resp);
    `DV_CHECK_EQ(resp_desc.err, Success, "toc0 write-read write status")
    `DV_CHECK_EQ(resp_desc.tid, cfg0.tid, "toc0 write-read write TID")
    read_response(resp);
    resp_desc = i3c_response_desc_t'(resp);
    `DV_CHECK_EQ(resp_desc.err, Success, "toc0 write-read read status")
    `DV_CHECK_EQ(resp_desc.tid, cfg1.tid, "toc0 write-read read TID")
    `DV_CHECK_EQ(dev_seq0.observed_rstart, 1'b1,
                 "toc0 write-read must transition through repeated START")
    `DV_CHECK_EQ(dev_seq1.observed_rstart, 1'b0,
                 "toc0 write-read final read must terminate with STOP")
    check_all_queues_empty($sformatf("after toc0 write-read %s",
                                     private_addr_mode_name(broadcast_header_enable)));
  endtask

  virtual task run_toc_zero_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        cfg1;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    int                            rstart_count;
    bit                     [ 6:0] static_addr;
    bit                     [ 6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;

    enable_dut(broadcast_header_enable);
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);

    cfg0 = make_transfer_cfg(
        .ctxt($sformatf("toc0_vseq %s first", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("dev_seq0_%s", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd3),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(2),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );
    cfg1 = make_transfer_cfg(
        .ctxt($sformatf("toc0_vseq %s second", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("dev_seq1_%s", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd4),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    build_random_tx_words(cfg0.data_length + cfg1.data_length, exp_data, tx_words);

    run_toc_zero_write_stimulus(cfg0, cfg1, tx_words, resp0, resp1, rstart_count, dev_seq0,
                                dev_seq1);

    `DV_CHECK_EQ(dev_seq0.done, 1'b1, "toc0_vseq: first device response did not finish")
    `DV_CHECK_EQ(dev_seq1.done, 1'b1, "toc0_vseq: second device response did not finish")
    `DV_CHECK_EQ(rstart_count, 1, "toc0_vseq: expected exactly one observed RSTART")
    `DV_CHECK_EQ(dev_seq0.observed_rstart, 1'b1, "toc0_vseq: first write should end with RSTART")
    `DV_CHECK_EQ(dev_seq1.observed_rstart, 1'b0, "toc0_vseq: second write should end with STOP")
    `DV_CHECK_EQ(dev_seq0.observed_broadcast_header, broadcast_header_enable,
                 "toc0_vseq: first write broadcast header mismatch")
    `DV_CHECK_EQ(dev_seq0.observed_broadcast_rstart, broadcast_header_enable,
                 "toc0_vseq: first write broadcast header RSTART mismatch")
    `DV_CHECK_EQ(dev_seq1.observed_broadcast_header, 1'b0,
                 "toc0_vseq: continuation should not emit a second broadcast header")
    `DV_CHECK_EQ(dev_seq1.observed_broadcast_rstart, 1'b0,
                 "toc0_vseq: continuation should not emit a second broadcast header RSTART")

    check_all_queues_empty(
        $sformatf(
        "after toc0_vseq %s valid continuation", private_addr_mode_name(broadcast_header_enable)));

  endtask

  virtual task run_toc_zero_missing_next_cmd_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   no_read_data;
    bit                     [31:0] resp;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [ 6:0] static_addr;
    bit                     [ 6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "toc0_missing_next_cmd_vseq %s", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "toc0_missing_next_cmd_dev_seq_%s", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'd5),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    build_random_tx_words(cfg.data_length, exp_data, tx_words);
    write_tx_words(tx_words);
    write_write_cmd(cfg, 1'b0);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    `DV_CHECK_EQ(dev_seq.done, 1'b1, "toc0_missing_next_cmd_vseq: device response did not finish")
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b0,
                 "toc0_missing_next_cmd_vseq: missing continuation should terminate with STOP")
    `DV_CHECK_EQ(dev_seq.observed_broadcast_header, broadcast_header_enable,
                 "toc0_missing_next_cmd_vseq: broadcast header mismatch")
    `DV_CHECK_EQ(dev_seq.observed_broadcast_rstart, broadcast_header_enable,
                 "toc0_missing_next_cmd_vseq: broadcast header RSTART mismatch")

    check_all_queues_empty(
        $sformatf(
        "after toc0_missing_next_cmd_vseq %s", private_addr_mode_name(broadcast_header_enable)));
    request_sw_reset(1'b1);
    check_all_queues_empty($sformatf(
                           "after toc0_missing_next_cmd_vseq %s SW reset",
                           private_addr_mode_name(
                               broadcast_header_enable
                           )
                           ));

  endtask

  virtual task run_toc_zero_unsupported_next_cmd_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        cfg1;
    regular_trans_desc_t           first_cmd;
    immediate_data_trans_desc_t    unsupported_cmd;
    byte_queue_t                   no_read_data;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;
    i3c_response_desc_t            resp_desc;
    bit                     [31:0] resp;
    bit                     [ 6:0] static_addr;
    bit                     [ 6:0] dynamic_addr;

    enable_dut(broadcast_header_enable);
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);
    cfg0 = make_transfer_cfg(
        .ctxt($sformatf("toc0 unsupported continuation %s",
                        private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("toc0_unsupported_%s_dev_seq",
                            private_addr_mode_name(broadcast_header_enable))),
        .tid(4'h6),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    cfg1 = make_transfer_cfg(
        .ctxt($sformatf("standalone immediate after unsupported continuation %s",
                        private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("toc0_unsupported_%s_followup_dev_seq",
                            private_addr_mode_name(broadcast_header_enable))),
        .tid(4'h7),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(0),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    first_cmd = build_regular_transfer_cmd(cfg0, 1'b0, 1'b0);
    first_cmd.wroc = 1'b1;
    unsupported_cmd        = '0;
    unsupported_cmd.attr   = ImmediateDataTransfer;
    unsupported_cmd.tid    = 4'h7;
    unsupported_cmd.mode   = sdr0;
    unsupported_cmd.dev_idx = 5'd0;
    unsupported_cmd.toc    = 1'b1;
    unsupported_cmd.wroc   = 1'b1;

    start_ordered_device_responses(cfg0, 1'b0, no_read_data, dev_seq0,
                                   cfg1, 1'b0, no_read_data, dev_seq1);
    build_random_tx_words(cfg0.data_length, exp_data, tx_words);
    write_tx_words(tx_words);
    write_cmd(first_cmd[31:0], first_cmd[63:32]);
    write_cmd(unsupported_cmd[31:0], unsupported_cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));

    read_response(resp);
    resp_desc = i3c_response_desc_t'(resp);
    `DV_CHECK_EQ(resp_desc.err, NotSupported,
                 "toc0 unsupported continuation must report NotSupported")
    `DV_CHECK_EQ(resp_desc.tid, first_cmd.tid,
                 "toc0 unsupported continuation response TID mismatch")
    `DV_CHECK_EQ(resp_desc.data_length, first_cmd.data_length,
                 "toc0 unsupported continuation response length mismatch")
    `DV_CHECK_EQ(dev_seq0.observed_rstart, 1'b0,
                 "toc0 unsupported continuation must terminate with STOP")

    // ImmediateDataTransfer is unsupported as a continuation but valid when
    // the retained descriptor is considered later as a new command.
    read_response(resp);
    resp_desc = i3c_response_desc_t'(resp);
    `DV_CHECK_EQ(resp_desc.err, Success,
                 "standalone immediate follow-up must succeed")
    `DV_CHECK_EQ(resp_desc.tid, unsupported_cmd.tid,
                 "standalone immediate follow-up response TID mismatch")
    `DV_CHECK_EQ(resp_desc.data_length, 16'h0000,
                 "standalone immediate follow-up response length mismatch")
    check_all_queues_empty($sformatf("after toc0 unsupported continuation %s",
                                     private_addr_mode_name(broadcast_header_enable)));
  endtask
endclass
