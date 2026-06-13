class i3c_write_toc_zero_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_toc_zero_vseq)

  function new(string name = "i3c_write_toc_zero_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_toc_zero_case(broadcast_modes[mode_idx]);
      run_toc_zero_missing_next_cmd_case(broadcast_modes[mode_idx]);
    end
  endtask

  virtual task run_toc_zero_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg0;
    transfer_stimulus_cfg_t cfg1;
    word_queue_t            tx_words;
    bit [31:0]              resp0;
    bit [31:0]              resp1;
    int                     rstart_count;
    i3c_device_response_seq dev_seq0;
    i3c_device_response_seq dev_seq1;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg0                   = make_transfer_cfg(
        .ctxt($sformatf("toc0_vseq %s first", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("dev_seq0_%s", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd3),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(2),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );
    cfg1                   = make_transfer_cfg(
        .ctxt($sformatf("toc0_vseq %s second", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("dev_seq1_%s", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd4),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    tx_words.push_back(32'h0000_BBAA);
    tx_words.push_back(32'h0000_DDCC);

    run_toc_zero_write_stimulus(cfg0, cfg1, tx_words, resp0, resp1, rstart_count, dev_seq0,
                                dev_seq1);

    `DV_CHECK_EQ(dev_seq0.done, 1'b1, "toc0_vseq: first device response did not finish")
    `DV_CHECK_EQ(dev_seq1.done, 1'b1, "toc0_vseq: second device response did not finish")
    `DV_CHECK_EQ(rstart_count, 1, "toc0_vseq: expected exactly one observed RSTART")
    `DV_CHECK_EQ(dev_seq0.observed_rstart, 1'b1,
                 "toc0_vseq: first write should end with RSTART")
    `DV_CHECK_EQ(dev_seq1.observed_rstart, 1'b0,
                 "toc0_vseq: second write should end with STOP")
    `DV_CHECK_EQ(dev_seq0.observed_broadcast_header, broadcast_header_enable,
                 "toc0_vseq: first write broadcast header mismatch")
    `DV_CHECK_EQ(dev_seq0.observed_broadcast_rstart, broadcast_header_enable,
                 "toc0_vseq: first write broadcast header RSTART mismatch")
    `DV_CHECK_EQ(dev_seq1.observed_broadcast_header, 1'b0,
                 "toc0_vseq: continuation should not emit a second broadcast header")
    `DV_CHECK_EQ(dev_seq1.observed_broadcast_rstart, 1'b0,
                 "toc0_vseq: continuation should not emit a second broadcast header RSTART")

    check_success_resp(resp0, cfg0);
    check_success_resp(resp1, cfg1);

    check_all_queues_empty($sformatf("after toc0_vseq %s valid continuation",
                                     private_addr_mode_name(broadcast_header_enable)));
  endtask

  virtual task run_toc_zero_missing_next_cmd_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            no_read_data;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("toc0_missing_next_cmd_vseq %s",
                        private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("toc0_missing_next_cmd_dev_seq_%s",
                            private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd5),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    expect_scoreboard_resp_error(4'hA, cfg.tid, 16'(cfg.data_length), cfg.ctxt);
    write_tx_data(32'h0000_2211);
    write_write_cmd(cfg, 1'b0);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    `DV_CHECK_EQ(dev_seq.done, 1'b1,
                 "toc0_missing_next_cmd_vseq: device response did not finish")
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b0,
                 "toc0_missing_next_cmd_vseq: missing continuation should terminate with STOP")
    `DV_CHECK_EQ(dev_seq.observed_broadcast_header, broadcast_header_enable,
                 "toc0_missing_next_cmd_vseq: broadcast header mismatch")
    `DV_CHECK_EQ(dev_seq.observed_broadcast_rstart, broadcast_header_enable,
                 "toc0_missing_next_cmd_vseq: broadcast header RSTART mismatch")

    `DV_CHECK_EQ(resp[31:28], 4'hA,
                 "toc0_missing_next_cmd_vseq: expected NotSupported response")
    `DV_CHECK_EQ(resp[27:24], cfg.tid,
                 "toc0_missing_next_cmd_vseq: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], 16'(cfg.data_length),
                 "toc0_missing_next_cmd_vseq: response length mismatch")

    check_all_queues_empty($sformatf("after toc0_missing_next_cmd_vseq %s",
                                     private_addr_mode_name(broadcast_header_enable)));
    request_sw_reset(1'b1);
    check_all_queues_empty($sformatf("after toc0_missing_next_cmd_vseq %s SW reset",
                                     private_addr_mode_name(broadcast_header_enable)));
  endtask
endclass
