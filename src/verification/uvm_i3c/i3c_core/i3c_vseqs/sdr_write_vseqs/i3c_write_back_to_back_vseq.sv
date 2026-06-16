class i3c_write_back_to_back_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_back_to_back_vseq)

  function new(string name = "i3c_write_back_to_back_vseq");
    super.new(name);
  endfunction

  task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_back_to_back_case(broadcast_modes[mode_idx]);
    end

    `uvm_info(`gfn,
              "SDRW_008 conclusion: queued SDR private writes execute back-to-back and each target transaction completes with STOP",
              UVM_LOW)
  endtask

  virtual task run_back_to_back_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        cfg1;
    transfer_stimulus_cfg_t        cfg2;
    word_queue_t                   tx_words;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    bit                     [31:0] resp2;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;
    i3c_device_response_seq        dev_seq2;

    disable_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg0 = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRW_008 %s back_to_back[0]", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrw008_%s_dev_seq0", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'h8),
        .dev_idx(5'd0),
        .target_addr(7'h08),
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
        .ctxt($sformatf(
            "SDRW_008 %s back_to_back[1]", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrw008_%s_dev_seq1", private_addr_mode_name(broadcast_header_enable)
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
        .data_length(5),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    cfg2 = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRW_008 %s back_to_back[2]", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrw008_%s_dev_seq2", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hA),
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

    tx_words.delete();

    tx_words.push_back(32'hE712_1110);
    tx_words.push_back(32'h2322_2120);
    tx_words.push_back(32'hD6C5_B424);
    tx_words.push_back(32'h3332_3130);
    start_back_to_back_device_responses(cfg0, cfg1, cfg2, dev_seq0, dev_seq1, dev_seq2);

    write_tx_words(tx_words);
    write_write_cmd(cfg0);
    write_write_cmd(cfg1);
    write_write_cmd(cfg2);

    enable_dut(broadcast_header_enable);
    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    wait_for_device_done(dev_seq2, cfg2.ctxt, device_done_timeout_cycles(cfg2));

    read_response(resp0);
    read_response(resp1);
    read_response(resp2);

    check_back_to_back_write_done(dev_seq0, cfg0);
    check_back_to_back_write_done(dev_seq1, cfg1);
    check_back_to_back_write_done(dev_seq2, cfg2);

    check_all_queues_empty("after SDRW_008 back_to_back");
    disable_dut();

    `uvm_info(`gfn, $sformatf(
                  "SDRW_008 result: mode=%s queued_cmds=3 sampled_bytes={%0d,%0d,%0d} observed_rstart={%0b,%0b,%0b}",
                  private_addr_mode_name(broadcast_header_enable), dev_seq0.sampled_data.size(),
                  dev_seq1.sampled_data.size(), dev_seq2.sampled_data.size(),
                  dev_seq0.observed_rstart, dev_seq1.observed_rstart,
                  dev_seq2.observed_rstart), UVM_LOW)
  endtask

  virtual task start_back_to_back_device_responses(
      input transfer_stimulus_cfg_t cfg0, input transfer_stimulus_cfg_t cfg1,
      input transfer_stimulus_cfg_t cfg2, output i3c_device_response_seq dev_seq0,
      output i3c_device_response_seq dev_seq1, output i3c_device_response_seq dev_seq2);
    byte_queue_t no_read_data;

    start_device_response(cfg0, 1'b0, no_read_data, dev_seq0);
    wait_for_device_request_issued(dev_seq0, cfg0.ctxt);

    start_device_response(cfg1, 1'b0, no_read_data, dev_seq1);
    settle_cycles(1);
    start_device_response(cfg2, 1'b0, no_read_data, dev_seq2);
    settle_cycles(1);
  endtask

  virtual task check_back_to_back_write_done(input i3c_device_response_seq dev_seq,
                                             input transfer_stimulus_cfg_t cfg);
    `DV_CHECK_EQ(dev_seq.done, 1'b1, $sformatf("%s: device response did not finish", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b0, $sformatf("%s: transfer should end with STOP",
                                                          cfg.ctxt))
  endtask

endclass
