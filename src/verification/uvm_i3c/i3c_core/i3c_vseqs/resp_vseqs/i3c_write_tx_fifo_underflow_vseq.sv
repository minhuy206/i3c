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
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    bit                      [6:0] static_addr;
    bit                      [6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_006 %s toc%0d tx_fifo_underflow_ovl",
            private_addr_mode_name(
                broadcast_header_enable
            ),
            toc
        )),
        .seq_name($sformatf(
            "err006_%s_toc%0d_dev_seq", private_addr_mode_name(broadcast_header_enable), toc
        )),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
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

    build_random_tx_words(ACTUAL_LENGTH, exp_data, tx_words);
    write_tx_words(tx_words);
    write_write_cmd(cfg, toc);

    poll_idle();
    settle_cycles(1);
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_all_queues_empty($sformatf("after ERR_006 toc%0d tx_fifo_underflow_ovl", toc));

    `uvm_info(`gfn, $sformatf(
                  "ERR_006 result: mode=%s toc=%0d requested_len=%0d supplied_words=1 sampled_bytes=%0d",
                  private_addr_mode_name(broadcast_header_enable), toc, DATA_LENGTH,
                  dev_seq.sampled_data.size()), UVM_LOW)
  endtask

  virtual task run_tx_fifo_empty_underflow_ovl_case(bit broadcast_header_enable, bit toc,
                                                    int unsigned data_length);
    transfer_stimulus_cfg_t        cfg;
    transfer_stimulus_cfg_t        dev_cfg;
    byte_queue_t                   no_read_data;
    bit                     [31:0] resp;
    bit                      [6:0] static_addr;
    bit                      [6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_006 %s toc%0d tx_fifo_empty_underflow_ovl len%0d",
            private_addr_mode_name(
                broadcast_header_enable
            ),
            toc,
            data_length
        )),
        .seq_name($sformatf(
            "err006_%s_toc%0d_empty_dev_seq_len%0d",
            private_addr_mode_name(
                broadcast_header_enable
            ),
            toc,
            data_length
        )),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
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

    write_write_cmd(cfg, toc);

    poll_idle();
    settle_cycles(1);
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_all_queues_empty(
        $sformatf("after ERR_006 toc%0d tx_fifo_empty_underflow_ovl len%0d", toc, data_length));

    `uvm_info(`gfn, $sformatf(
                  "ERR_006 result: mode=%s toc=%0d requested_len=%0d supplied_words=0 sampled_bytes=%0d",
                  private_addr_mode_name(broadcast_header_enable), toc, data_length,
                  dev_seq.sampled_data.size()), UVM_LOW)
  endtask

  virtual task run_late_refill_after_underflow_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    transfer_stimulus_cfg_t        dev_cfg;
    byte_queue_t                   no_read_data;
    byte_queue_t                   exp_data;
    byte_queue_t                   late_exp_data;
    word_queue_t                   tx_words;
    word_queue_t                   late_tx_words;
    bit                     [31:0] resp;
    bit                      [6:0] static_addr;
    bit                      [6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_006 %s tx_fifo_late_refill_after_ovl",
            private_addr_mode_name(
                broadcast_header_enable
            )
        )),
        .seq_name($sformatf(
            "err006_%s_late_refill_dev_seq", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
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
                      "after ERR_006 late refill");
    request_sw_reset(1'b1);
    check_all_queues_empty("after ERR_006 late refill SW reset");

    `uvm_info(`gfn, $sformatf(
                  "ERR_006 result: mode=%s requested_len=%0d sampled_bytes_before_late_refill=%0d late_refill_words=1 sw_reset_flushed_queues=1",
                  private_addr_mode_name(broadcast_header_enable), DATA_LENGTH,
                  dev_seq.sampled_data.size()), UVM_LOW)
  endtask

endclass
