class i3c_write_addr_nack_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_addr_nack_vseq)

  localparam bit [31:0] TX_WORD = 32'hA5C3_5A3C;
  localparam int unsigned DATA_LENGTH = 4;

  function new(string name = "i3c_write_addr_nack_vseq");
    super.new(name);
  endfunction

  task body();
    transfer_stimulus_cfg_t        cfg;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg("SDRW_005 addr_nack", "sdrw005_dev_seq", 4'd5, 5'd0, 7'h08, 1'b1,
                            DATA_LENGTH);
    cfg.ack_address = 1'b0;
    cfg.wait_device_done = 1'b1;

    tx_words.push_back(TX_WORD);

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    `DV_CHECK_EQ(dev_seq.done, 1'b1, "SDRW_005: device response did not finish")
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08, "SDRW_005: target address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0, "SDRW_005: transfer direction should be write")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), 0, "SDRW_005: data phase should not start")
    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), 0, "SDRW_005: T-bit phase should not start")

    `DV_CHECK_EQ(resp[31:28], 4'h4, "SDRW_005: expected AddrHeader response")
    `DV_CHECK_EQ(resp[27:24], cfg.tid, "SDRW_005: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], 16'd0, "SDRW_005: response length should be zero")

    check_all_queues_empty("after SDRW_005 address NACK");

    `uvm_info(`gfn, "SDRW_005 I3C write address NACK checks passed", UVM_LOW)
  endtask

endclass
