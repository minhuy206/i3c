class i3c_read_addr_nack_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_addr_nack_vseq)

  localparam int unsigned DATA_LENGTH = 4;

  function new(string name = "i3c_read_addr_nack_vseq");
    super.new(name);
  endfunction

  task body();
    transfer_stimulus_cfg_t cfg;
    regular_trans_desc_t    rd_cmd;
    byte_queue_t            no_read_data;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg("SDRR_005 addr_nack", "sdrr005_dev_seq", 4'd5, 5'd0, 7'h08, 1'b1,
                            DATA_LENGTH);
    cfg.ack_address      = 1'b0;
    cfg.wait_device_done = 1'b1;

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
