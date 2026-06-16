class i3c_read_multi_dat_idx_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_multi_dat_idx_vseq)

  function new(string name = "i3c_read_multi_dat_idx_vseq");
    super.new(name);
  endfunction

  task body();
    run_multi_dat_idx_case(1'b0);
    run_toc_zero_multi_dat_idx_case(1'b0);

    `uvm_info(`gfn,
              "SDRR_010 conclusion: SDR private reads select the programmed DAT index and preserve that selection across toc=0 continuation",
              UVM_LOW)
  endtask

  virtual task configure_multi_dat_targets();
    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr = 7'h08;
    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr_valid = 1'b1;
    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.dynamic_addr = 7'h12;
    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.dynamic_addr_valid = 1'b1;

    disable_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);
    write_dat_entry(1, 7'h51, 7'h12, 1'b0);
  endtask

  virtual function void build_read_payload(input byte base, input int unsigned data_length,
                                           ref byte_queue_t read_data);
    read_data.delete();
    for (int unsigned i = 0; i < data_length; i++) begin
      read_data.push_back(8'(base + i));
    end
  endfunction

  virtual task run_multi_dat_idx_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        cfg1;
    byte_queue_t                   read_data0;
    byte_queue_t                   read_data1;
    word_queue_t                   rx_words0;
    word_queue_t                   rx_words1;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;

    configure_multi_dat_targets();

    cfg0 = make_transfer_cfg(
        .ctxt($sformatf("SDRR_010 %s DAT[0]", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf(
            "sdrr010_%s_dev_seq0", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'h9),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(4),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    cfg1 = make_transfer_cfg(
        .ctxt($sformatf("SDRR_010 %s DAT[1]", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf(
            "sdrr010_%s_dev_seq1", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hB),
        .dev_idx(5'd1),
        .target_addr(7'h12),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(8),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    build_read_payload(8'hA0, cfg0.data_length, read_data0);
    build_read_payload(8'hC0, cfg1.data_length, read_data1);

    start_ordered_device_responses(cfg0, 1'b1, read_data0, dev_seq0, cfg1, 1'b1, read_data1,
                                   dev_seq1);
    write_read_cmd(cfg0);
    write_read_cmd(cfg1);

    enable_dut(broadcast_header_enable);
    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    read_rx_words(cfg0.data_length, rx_words0);
    read_rx_words(cfg1.data_length, rx_words1);
    read_response(resp0);
    read_response(resp1);

    check_dat_addr(dev_seq0, cfg0);
    check_dat_addr(dev_seq1, cfg1);
    check_all_queues_empty(
        $sformatf("after SDRR_010 %s multi DAT", private_addr_mode_name(broadcast_header_enable)));

    `uvm_info(`gfn, $sformatf(
                  "SDRR_010 result: mode=%s case=multi_dat target_addrs={0x%02h,0x%02h} sampled_addrs={0x%02h,0x%02h} rx_words_drained={%0d,%0d}",
                  private_addr_mode_name(broadcast_header_enable), cfg0.target_addr,
                  cfg1.target_addr, dev_seq0.sampled_addr, dev_seq1.sampled_addr,
                  rx_words0.size(), rx_words1.size()), UVM_LOW)
  endtask

  virtual task run_toc_zero_multi_dat_idx_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        cfg1;
    byte_queue_t                   read_data0;
    byte_queue_t                   read_data1;
    word_queue_t                   rx_words0;
    word_queue_t                   rx_words1;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    int                            rstart_count;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;

    configure_multi_dat_targets();
    enable_dut(broadcast_header_enable);

    cfg0 = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRR_010 %s toc0 DAT[0]", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrr010_%s_toc0_dev_seq0", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hC),
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
        .ctxt($sformatf(
            "SDRR_010 %s toc0 DAT[1]", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrr010_%s_toc0_dev_seq1", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hD),
        .dev_idx(5'd1),
        .target_addr(7'h12),
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

    build_read_payload(8'hBA, cfg0.data_length, read_data0);
    build_read_payload(8'hDC, cfg1.data_length, read_data1);

    run_toc_zero_read_stimulus(cfg0, cfg1, read_data0, read_data1, rx_words0, rx_words1, resp0,
                               resp1, rstart_count, dev_seq0, dev_seq1);

    check_dat_addr(dev_seq0, cfg0);
    check_dat_addr(dev_seq1, cfg1);
    `DV_CHECK_EQ(rstart_count, 1, "SDRR_010 toc0 multi-DAT: expected exactly one RSTART")
    `DV_CHECK_EQ(dev_seq0.observed_rstart, 1'b1,
                 "SDRR_010 toc0 multi-DAT: first read should end with RSTART")
    `DV_CHECK_EQ(dev_seq1.observed_rstart, 1'b0,
                 "SDRR_010 toc0 multi-DAT: second read should end with STOP")

    check_all_queues_empty(
        $sformatf(
        "after SDRR_010 %s toc0 multi-DAT", private_addr_mode_name(broadcast_header_enable)));

    `uvm_info(`gfn, $sformatf(
                  "SDRR_010 result: mode=%s case=toc0_multi_dat target_addrs={0x%02h,0x%02h} sampled_addrs={0x%02h,0x%02h} rstart_count=%0d first_observed_rstart=%0b second_observed_rstart=%0b",
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
