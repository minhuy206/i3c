class i3c_read_addr_nack_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_addr_nack_vseq)

  localparam int unsigned DATA_LENGTH = 4;

  function new(string name = "i3c_read_addr_nack_vseq");
    super.new(name);
  endfunction

  task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_addr_nack_case(broadcast_modes[mode_idx]);
    end
  endtask

  virtual task run_addr_nack_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg;
    regular_trans_desc_t    rd_cmd;
    byte_queue_t            no_read_data;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("SDRR_005 %s addr_nack", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("sdrr005_%s_dev_seq", private_addr_mode_name(broadcast_header_enable))),
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

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b1);
    start_device_response(cfg, 1'b1, no_read_data, dev_seq);
    if (cfg.settle_before_cmd != 0) settle_cycles(cfg.settle_before_cmd);

    expect_scoreboard_resp_error(4'h4, cfg.tid, 16'd0, cfg.ctxt);
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    `DV_CHECK_EQ(dev_seq.done, 1'b1, "SDRR_005: device response did not finish")
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08, "SDRR_005: target address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b1, "SDRR_005: transfer direction should be read")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), 0, "SDRR_005: data phase should not start")
    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), 0, "SDRR_005: T-bit phase should not start")

    `DV_CHECK_EQ(resp[31:28], 4'h4, "SDRR_005: expected AddrHeader response")
    `DV_CHECK_EQ(resp[27:24], cfg.tid, "SDRR_005: response TID mismatch")
    `DV_CHECK_EQ(resp[23:16], 8'h00, "SDRR_005: response reserved field should be zero")
    `DV_CHECK_EQ(resp[15:0], 16'd0, "SDRR_005: response length should be zero")

    check_all_queues_empty("after SDRR_005 address NACK");

    `uvm_info(`gfn, "SDRR_005 I3C read address NACK checks passed", UVM_LOW)
  endtask

endclass
