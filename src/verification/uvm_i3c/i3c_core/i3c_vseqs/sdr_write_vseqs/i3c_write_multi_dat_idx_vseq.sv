class i3c_write_multi_dat_idx_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_multi_dat_idx_vseq)

  function new(string name = "i3c_write_multi_dat_idx_vseq");
    super.new(name);
  endfunction

  task body();
    run_multi_dat_idx_case(1'b0);
    run_toc_zero_multi_dat_idx_case(1'b0);

  endtask

  virtual task configure_multi_dat_targets(output bit [6:0] static_addr0,
                                           output bit [6:0] dynamic_addr0,
                                           output bit [6:0] static_addr1,
                                           output bit [6:0] dynamic_addr1);
    disable_dut();
    randomize_i3c_dat_target(0, static_addr0, dynamic_addr0);
    randomize_i3c_dat_target(1, static_addr1, dynamic_addr1, static_addr0, dynamic_addr0);
  endtask

  virtual task run_multi_dat_idx_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        cfg1;
    byte_queue_t                   no_read_data;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    bit                      [6:0] static_addr0;
    bit                      [6:0] dynamic_addr0;
    bit                      [6:0] static_addr1;
    bit                      [6:0] dynamic_addr1;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;

    configure_multi_dat_targets(static_addr0, dynamic_addr0, static_addr1, dynamic_addr1);

    cfg0 = make_transfer_cfg(
        .ctxt($sformatf("SDRW_007 %s DAT[0]", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf(
            "sdrw007_%s_dev_seq0", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'h9),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr0),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(3),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    cfg1 = make_transfer_cfg(
        .ctxt($sformatf("SDRW_007 %s DAT[1]", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf(
            "sdrw007_%s_dev_seq1", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hB),
        .dev_idx(5'd1),
        .target_addr(dynamic_addr1),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(5),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    build_random_tx_words(cfg0.data_length + cfg1.data_length, exp_data, tx_words);

    start_ordered_device_responses(cfg0, 1'b0, no_read_data, dev_seq0, cfg1, 1'b0, no_read_data,
                                   dev_seq1);
    write_tx_words(tx_words);
    write_write_cmd(cfg0);
    write_write_cmd(cfg1);

    enable_dut(broadcast_header_enable);
    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    read_response(resp0);
    read_response(resp1);

    check_dat_addr(dev_seq0, cfg0);
    check_dat_addr(dev_seq1, cfg1);
    check_all_queues_empty(
        $sformatf("after SDRW_007 %s multi DAT", private_addr_mode_name(broadcast_header_enable)));

    `uvm_info(`gfn, $sformatf(
                  "SDRW_007 result: mode=%s case=multi_dat target_addrs={0x%02h,0x%02h} sampled_addrs={0x%02h,0x%02h} sampled_bytes={%0d,%0d}",
                  private_addr_mode_name(broadcast_header_enable), cfg0.target_addr,
                  cfg1.target_addr, dev_seq0.sampled_addr, dev_seq1.sampled_addr,
                  dev_seq0.sampled_data.size(), dev_seq1.sampled_data.size()), UVM_LOW)
  endtask

  virtual task run_toc_zero_multi_dat_idx_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        cfg1;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    int                            rstart_count;
    bit                      [6:0] static_addr0;
    bit                      [6:0] dynamic_addr0;
    bit                      [6:0] static_addr1;
    bit                      [6:0] dynamic_addr1;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;

    configure_multi_dat_targets(static_addr0, dynamic_addr0, static_addr1, dynamic_addr1);
    enable_dut(broadcast_header_enable);

    cfg0 = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRW_007 %s toc0 DAT[0]", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrw007_%s_toc0_dev_seq0", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hC),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr0),
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
        .ctxt($sformatf(
            "SDRW_007 %s toc0 DAT[1]", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrw007_%s_toc0_dev_seq1", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hD),
        .dev_idx(5'd1),
        .target_addr(dynamic_addr1),
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

    build_random_tx_words(cfg0.data_length + cfg1.data_length, exp_data, tx_words);

    run_toc_zero_write_stimulus(cfg0, cfg1, tx_words, resp0, resp1, rstart_count, dev_seq0,
                                dev_seq1);

    check_dat_addr(dev_seq0, cfg0);
    check_dat_addr(dev_seq1, cfg1);
    `DV_CHECK_EQ(rstart_count, 1, "SDRW_007 toc0 multi-DAT: expected exactly one RSTART")
    `DV_CHECK_EQ(dev_seq0.observed_rstart, 1'b1,
                 "SDRW_007 toc0 multi-DAT: first write should end with RSTART")
    `DV_CHECK_EQ(dev_seq1.observed_rstart, 1'b0,
                 "SDRW_007 toc0 multi-DAT: second write should end with STOP")

    check_all_queues_empty(
        $sformatf(
        "after SDRW_007 %s toc0 multi-DAT", private_addr_mode_name(broadcast_header_enable)));

    `uvm_info(`gfn, $sformatf(
                  "SDRW_007 result: mode=%s case=toc0_multi_dat target_addrs={0x%02h,0x%02h} sampled_addrs={0x%02h,0x%02h} rstart_count=%0d first_observed_rstart=%0b second_observed_rstart=%0b",
                  private_addr_mode_name(broadcast_header_enable), cfg0.target_addr,
                  cfg1.target_addr, dev_seq0.sampled_addr, dev_seq1.sampled_addr, rstart_count,
                  dev_seq0.observed_rstart, dev_seq1.observed_rstart), UVM_LOW)
  endtask

  virtual task check_dat_addr(input i3c_device_response_seq dev_seq,
                              input transfer_stimulus_cfg_t cfg);
    `DV_CHECK_EQ(dev_seq.done, 1'b1, $sformatf("%s: device response did not finish", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.sampled_addr, cfg.target_addr, $sformatf("%s: target address mismatch",
                                                                  cfg.ctxt))
  endtask

endclass
