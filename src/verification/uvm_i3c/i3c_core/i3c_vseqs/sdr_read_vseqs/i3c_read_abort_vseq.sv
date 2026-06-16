class i3c_read_abort_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_abort_vseq)

  localparam int unsigned DATA_LENGTH = 8;
  localparam int unsigned DATA_LENGTH_DEEP = 16;

  localparam bit [3:0] FSM_ISSUE_CMD = 4'd12;

  function new(string name = "i3c_read_abort_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_read_abort_case(broadcast_modes[mode_idx]);
      run_read_abort_deep_case(broadcast_modes[mode_idx]);
    end

    `uvm_info(
        `gfn,
        "SDRR_009 conclusion: HC abort during SDR private read reaches idle and SW reset flushes leftover RX data in both private-address modes",
        UVM_LOW)
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
    uvm_hdl_data_t                 rx_depth;

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
        if (!uvm_hdl_read(rx_paths.depth_path, rx_depth))
          `uvm_fatal(`gfn, "SDRR_009 deep: uvm_hdl_read failed for rx_paths.depth_path")
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

endclass
