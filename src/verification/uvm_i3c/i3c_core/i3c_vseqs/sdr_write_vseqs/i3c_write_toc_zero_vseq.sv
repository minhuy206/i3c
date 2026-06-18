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
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        cfg1;
    word_queue_t                   tx_words;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    int                            rstart_count;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg0 = make_transfer_cfg(
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
    cfg1 = make_transfer_cfg(
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

    `uvm_info(`gfn, $sformatf(
                  "SDRW_005 result: mode=%s case=valid_continuation rstart_count=%0d first_observed_rstart=%0b second_observed_rstart=%0b first_broadcast_header=%0b second_broadcast_header=%0b",
                  private_addr_mode_name(broadcast_header_enable), rstart_count,
                  dev_seq0.observed_rstart, dev_seq1.observed_rstart,
                  dev_seq0.observed_broadcast_header, dev_seq1.observed_broadcast_header),
              UVM_LOW)
  endtask

  virtual task run_toc_zero_missing_next_cmd_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   no_read_data;
    bit                     [31:0] resp;
    bit                     [31:0] intr_status;
    bit                     [31:0] intr_status_before_clear;
    bit                     [31:0] exp_intr_bits;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "toc0_missing_next_cmd_vseq %s", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "toc0_missing_next_cmd_dev_seq_%s", private_addr_mode_name(broadcast_header_enable)
        )),
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
    write_tx_data(32'h0000_2211);
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

    exp_intr_bits = (32'h1 << INTR_HC_SEQ_CANCEL_STAT_BIT) |
                    (32'h1 << INTR_HC_ERR_CMD_SEQ_TIMEOUT_STAT_BIT);
    reg_read(ADDR_INTR_STATUS, intr_status);
    intr_status_before_clear = intr_status;
    `DV_CHECK_EQ(intr_status & exp_intr_bits, exp_intr_bits,
                 "toc0_missing_next_cmd_vseq: missing continuation interrupt bits not set")
    `DV_CHECK_EQ(intr_status & ~exp_intr_bits, 32'h0,
                 "toc0_missing_next_cmd_vseq: unexpected INTR_STATUS bits set")

    reg_write(ADDR_INTR_STATUS, exp_intr_bits);
    reg_read(ADDR_INTR_STATUS, intr_status);
    `DV_CHECK_EQ(intr_status & exp_intr_bits, 32'h0,
                 "toc0_missing_next_cmd_vseq: W1C did not clear interrupt bits")

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

    `uvm_info(`gfn, $sformatf(
                  "SDRW_005 result: mode=%s case=missing_continuation observed_rstart=%0b intr_bits_before_clear=0x%08h intr_bits_after_clear=0x%08h",
                  private_addr_mode_name(broadcast_header_enable), dev_seq.observed_rstart,
                  intr_status_before_clear & exp_intr_bits, intr_status & exp_intr_bits), UVM_LOW)
  endtask
endclass
