class i3c_write_addr_nack_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_addr_nack_vseq)

  localparam bit [31:0] TX_WORD = 32'hA5C3_5A3C;
  localparam int unsigned DATA_LENGTH = 4;

  function new(string name = "i3c_write_addr_nack_vseq");
    super.new(name);
  endfunction

  task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_addr_nack_case(broadcast_modes[mode_idx]);
    end
  endtask

  virtual task run_addr_nack_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("SDRW_005 %s addr_nack", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("sdrw005_%s_dev_seq", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd5),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b0),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    tx_words.push_back(TX_WORD);

    expect_scoreboard_resp_error(4'h4, cfg.tid, 16'd0, cfg.ctxt);
    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    `DV_CHECK_EQ(dev_seq.done, 1'b1, "SDRW_005: device response did not finish")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), 0, "SDRW_005: data phase should not start")
    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), 0, "SDRW_005: T-bit phase should not start")

    `DV_CHECK_EQ(resp[31:28], 4'h4, "SDRW_005: expected AddrHeader response")
    `DV_CHECK_EQ(resp[27:24], cfg.tid, "SDRW_005: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], 16'd0, "SDRW_005: response length should be zero")

    check_queue_flags(cmd_paths.name, cmd_paths.full_bit, cmd_paths.empty_bit, 1'b0, 1'b1,
                      "after SDRW_005 address NACK");
    check_queue_flags(tx_paths.name, tx_paths.full_bit, tx_paths.empty_bit, 1'b0, 1'b0,
                      "after SDRW_005 address NACK");
    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit, 1'b0, 1'b1,
                      "after SDRW_005 address NACK");
    check_queue_flags(resp_paths.name, resp_paths.full_bit, resp_paths.empty_bit, 1'b0, 1'b1,
                      "after SDRW_005 address NACK");

    `uvm_info(`gfn, "SDRW_005 I3C write address NACK checks passed", UVM_LOW)
  endtask

endclass
