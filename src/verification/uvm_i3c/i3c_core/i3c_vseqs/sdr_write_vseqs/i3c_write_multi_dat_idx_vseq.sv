class i3c_write_multi_dat_idx_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_multi_dat_idx_vseq)

  localparam int unsigned DAT_INDEX_COUNT = 32;
  localparam bit [6:0] DYNAMIC_ADDR_BASE = 7'h08;

  function new(string name = "i3c_write_multi_dat_idx_vseq");
    super.new(name);
  endfunction

  task body();
    run_multi_dat_idx_case(1'b0);
    run_toc_zero_multi_dat_idx_case(1'b0);
    run_dat_idx_sweep_case();
  endtask

  virtual function bit [6:0] sweep_dynamic_addr(int unsigned dev_idx);
    return DYNAMIC_ADDR_BASE + 7'(dev_idx);
  endfunction

  virtual task configure_dat_idx_sweep_targets();
    disable_dut();
    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.dynamic_addr_valid = 1'b0;
    for (int unsigned dev_idx = 0; dev_idx < DAT_INDEX_COUNT; dev_idx++) begin
      write_dat_entry(dev_idx, 7'h00, sweep_dynamic_addr(dev_idx), 1'b0);
    end
  endtask

  virtual function void select_sweep_monitor_target(int unsigned dev_idx);
    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.static_addr_valid  = 1'b0;
    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr       = sweep_dynamic_addr(dev_idx);
    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr_valid = 1'b1;
  endfunction

  virtual task run_dat_idx_sweep_case();
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            exp_data;
    word_queue_t            tx_words;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;

    configure_dat_idx_sweep_targets();
    enable_dut(1'b0);

    for (int unsigned dev_idx = 0; dev_idx < DAT_INDEX_COUNT; dev_idx++) begin
      select_sweep_monitor_target(dev_idx);
      cfg = make_transfer_cfg(
          .ctxt($sformatf("SDRW_005 DAT-index sweep DAT[%0d]", dev_idx)),
          .seq_name($sformatf("sdrw005_dat_idx_%0d_dev_seq", dev_idx)),
          .tid(4'(dev_idx)),
          .dev_idx(5'(dev_idx)),
          .target_addr(sweep_dynamic_addr(dev_idx)),
          .is_i3c(1'b1),
          .addr_nack(1'b0),
          .data_nack(1'b0),
          .tx_before_cmd(1'b1),
          .wait_device_done(1'b1),
          .start_with_broadcast_header(1'b0),
          .data_length(4),
          .settle_before_cmd(0),
          .timeout_cycles(0)
      );

      build_random_tx_words(cfg.data_length, exp_data, tx_words);
      run_write_stimulus(cfg, tx_words, resp, dev_seq);
      settle_cycles();
      check_all_queues_empty($sformatf("after SDRW_005 DAT-index sweep DAT[%0d]", dev_idx));
    end
  endtask

  virtual task configure_multi_dat_targets(
      output bit [6:0] static_addr0, output bit [6:0] dynamic_addr0, output bit [6:0] static_addr1,
      output bit [6:0] dynamic_addr1);
    disable_dut();
    randomize_i3c_dat_target(0, static_addr0, dynamic_addr0);
    randomize_i3c_dat_target(1, static_addr1, dynamic_addr1);
  endtask

  virtual task run_multi_dat_idx_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        cfg1;
    byte_queue_t                   no_read_data;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    bit                     [ 6:0] static_addr0;
    bit                     [ 6:0] dynamic_addr0;
    bit                     [ 6:0] static_addr1;
    bit                     [ 6:0] dynamic_addr1;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;

    configure_multi_dat_targets(static_addr0, dynamic_addr0, static_addr1, dynamic_addr1);

    cfg0 = make_transfer_cfg(
        .ctxt($sformatf("SDRW_005 %s DAT[0]", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf(
            "sdrw005_%s_dev_seq0", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'h9),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr0),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(3),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    cfg1 = make_transfer_cfg(
        .ctxt($sformatf("SDRW_005 %s DAT[1]", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf(
            "sdrw005_%s_dev_seq1", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hB),
        .dev_idx(5'd1),
        .target_addr(dynamic_addr1),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
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

    check_all_queues_empty(
        $sformatf("after SDRW_005 %s multi DAT", private_addr_mode_name(broadcast_header_enable)));

  endtask

  virtual task run_toc_zero_multi_dat_idx_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        cfg1;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    int                            rstart_count;
    bit                     [ 6:0] static_addr0;
    bit                     [ 6:0] dynamic_addr0;
    bit                     [ 6:0] static_addr1;
    bit                     [ 6:0] dynamic_addr1;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;

    configure_multi_dat_targets(static_addr0, dynamic_addr0, static_addr1, dynamic_addr1);
    enable_dut(broadcast_header_enable);

    cfg0 = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRW_005 %s toc0 DAT[0]", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrw005_%s_toc0_dev_seq0", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hC),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr0),
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
        .ctxt($sformatf(
            "SDRW_005 %s toc0 DAT[1]", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrw005_%s_toc0_dev_seq1", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hD),
        .dev_idx(5'd1),
        .target_addr(dynamic_addr1),
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


    check_all_queues_empty(
        $sformatf(
        "after SDRW_005 %s toc0 multi-DAT", private_addr_mode_name(broadcast_header_enable)));

  endtask


endclass
