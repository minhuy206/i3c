class i3c_write_tx_fifo_underflow_ovl_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_tx_fifo_underflow_ovl_vseq)

  localparam int unsigned DATA_LENGTH = 8;
  localparam int unsigned ACTUAL_LENGTH = 4;
  localparam logic [3:0] RESP_OVL = 4'h6;

  function new(string name = "i3c_write_tx_fifo_underflow_ovl_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};
    bit toc_modes[2] = '{1'b1, 1'b0};

    foreach (broadcast_modes[mode_idx]) begin
      foreach (toc_modes[toc_idx]) begin
        run_tx_fifo_underflow_ovl_case(broadcast_modes[mode_idx], toc_modes[toc_idx]);
        run_tx_fifo_empty_underflow_ovl_case(broadcast_modes[mode_idx], toc_modes[toc_idx], 4);
        run_tx_fifo_empty_underflow_ovl_case(broadcast_modes[mode_idx], toc_modes[toc_idx], 8);
      end
      run_late_refill_after_underflow_case(broadcast_modes[mode_idx]);
    end
  endtask

  virtual task run_tx_fifo_underflow_ovl_case(bit broadcast_header_enable, bit toc);
    transfer_stimulus_cfg_t        cfg;
    transfer_stimulus_cfg_t        dev_cfg;
    byte_queue_t                   no_read_data;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRW_006 %s toc%0d tx_fifo_underflow_ovl",
            private_addr_mode_name(broadcast_header_enable),
            toc
        )),
        .seq_name($sformatf(
            "sdrw006_%s_toc%0d_dev_seq",
            private_addr_mode_name(broadcast_header_enable),
            toc
        )),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    dev_cfg = cfg;
    dev_cfg.data_length = ACTUAL_LENGTH;
    start_device_response(dev_cfg, 1'b0, no_read_data, dev_seq);
    expect_scoreboard_resp_error(RESP_OVL, cfg.tid, 16'(ACTUAL_LENGTH), cfg.ctxt);

    write_tx_data(32'h4433_2211);
    write_write_cmd(cfg, toc);

    poll_idle();
    settle_cycles(1);
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_underflow_device_write(dev_seq, cfg, ACTUAL_LENGTH, toc);
    check_ovl_resp(resp, cfg, ACTUAL_LENGTH);

    check_all_queues_empty($sformatf("after SDRW_006 toc%0d tx_fifo_underflow_ovl", toc));

    `uvm_info(`gfn,
              $sformatf("SDRW_006 I3C write TX FIFO underflow Ovl checks passed for toc=%0d", toc),
              UVM_LOW)
  endtask

  virtual task run_tx_fifo_empty_underflow_ovl_case(bit broadcast_header_enable, bit toc,
                                                    int unsigned data_length);
    transfer_stimulus_cfg_t        cfg;
    transfer_stimulus_cfg_t        dev_cfg;
    byte_queue_t                   no_read_data;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRW_006 %s toc%0d tx_fifo_empty_underflow_ovl len%0d",
            private_addr_mode_name(broadcast_header_enable),
            toc,
            data_length
        )),
        .seq_name($sformatf(
            "sdrw006_%s_toc%0d_empty_dev_seq_len%0d",
            private_addr_mode_name(broadcast_header_enable),
            toc,
            data_length
        )),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(data_length),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    dev_cfg = cfg;
    dev_cfg.data_length = 0;
    start_device_response(dev_cfg, 1'b0, no_read_data, dev_seq);
    expect_scoreboard_resp_error(RESP_OVL, cfg.tid, 16'd0, cfg.ctxt);

    write_write_cmd(cfg, toc);

    poll_idle();
    settle_cycles(1);
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_underflow_device_write(dev_seq, cfg, 0, toc);
    check_ovl_resp(resp, cfg, 0);
    check_all_queues_empty($sformatf("after SDRW_006 toc%0d tx_fifo_empty_underflow_ovl len%0d",
                                     toc, data_length));
  endtask

  virtual task run_late_refill_after_underflow_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    transfer_stimulus_cfg_t        dev_cfg;
    byte_queue_t                   no_read_data;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRW_006 %s tx_fifo_late_refill_after_ovl",
            private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrw006_%s_late_refill_dev_seq", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    dev_cfg = cfg;
    dev_cfg.data_length = ACTUAL_LENGTH;
    start_device_response(dev_cfg, 1'b0, no_read_data, dev_seq);
    expect_scoreboard_resp_error(RESP_OVL, cfg.tid, 16'(ACTUAL_LENGTH), cfg.ctxt);

    write_tx_data(32'h4433_2211);
    write_write_cmd(cfg);

    poll_idle();
    settle_cycles(1);
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_underflow_device_write(dev_seq, cfg, ACTUAL_LENGTH, 1'b1);
    check_ovl_resp(resp, cfg, ACTUAL_LENGTH);

    write_tx_data(32'h8877_6655);
    check_queue_flags(tx_paths.name, tx_paths.full_bit, tx_paths.empty_bit, 1'b0, 1'b0,
                      "after SDRW_006 late refill");
    request_sw_reset(1'b1);
    check_all_queues_empty("after SDRW_006 late refill SW reset");
  endtask

  virtual task check_underflow_device_write(input i3c_device_response_seq dev_seq,
                                            input transfer_stimulus_cfg_t cfg,
                                            input int unsigned actual_length, input bit toc);
    `DV_CHECK_EQ(dev_seq.done, 1'b1, $sformatf("%s: device response did not finish", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b0,
                 $sformatf("%s toc%0d: underflow must terminate with STOP, not RSTART", cfg.ctxt,
                           toc))
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), actual_length,
                 $sformatf("%s: sampled byte count mismatch", cfg.ctxt))
  endtask

  virtual task check_ovl_resp(input bit [31:0] resp, input transfer_stimulus_cfg_t cfg,
                              input int unsigned actual_length);
    `DV_CHECK_EQ(resp[31:28], RESP_OVL, $sformatf("%s: expected Ovl response", cfg.ctxt))
    `DV_CHECK_EQ(resp[27:24], cfg.tid, $sformatf("%s: response TID mismatch", cfg.ctxt))
    `DV_CHECK_EQ(resp[15:0], 16'(actual_length), $sformatf("%s: response length mismatch",
                                                           cfg.ctxt))
  endtask

endclass
