class i3c_read_toc_zero_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_toc_zero_vseq)

  function new(string name = "i3c_read_toc_zero_vseq");
    super.new(name);
  endfunction

  virtual task body();
    transfer_stimulus_cfg_t rd_cfg;
    transfer_stimulus_cfg_t wr_cfg;
    byte_queue_t            read_data;
    word_queue_t            tx_words;
    bit [31:0]              resp0;
    bit [31:0]              resp1;
    bit [31:0]              rx;
    int                     rstart_count;
    i3c_device_response_seq dev_seq0;
    i3c_device_response_seq dev_seq1;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    rd_cfg                   = make_transfer_cfg("read_toc0_vseq first", "dev_seq0", 4'd5, 5'd0,
                                                 7'h08, 1'b1, 2);
    wr_cfg                   = make_transfer_cfg("read_toc0_vseq second", "dev_seq1", 4'd6, 5'd0,
                                                 7'h08, 1'b1, 2);
    rd_cfg.settle_before_cmd = 5;
    read_data.push_back(8'h11);
    read_data.push_back(8'h22);
    tx_words.push_back(32'h0000_4433);

    run_toc_zero_read_write_stimulus(rd_cfg, wr_cfg, read_data, tx_words, rx, resp0, resp1,
                                     rstart_count, dev_seq0, dev_seq1);

    `DV_CHECK_EQ(dev_seq0.done, 1'b1, "read_toc0_vseq: first device response did not finish")
    `DV_CHECK_EQ(dev_seq1.done, 1'b1, "read_toc0_vseq: second device response did not finish")
    `DV_CHECK_EQ(rstart_count, 1, "read_toc0_vseq: expected exactly one observed RSTART")
    `DV_CHECK_EQ(dev_seq0.observed_rstart, 1'b1,
                 "read_toc0_vseq: first read should end with RSTART")
    `DV_CHECK_EQ(dev_seq1.observed_rstart, 1'b0,
                 "read_toc0_vseq: second write should end with STOP")
    `DV_CHECK_EQ(dev_seq0.sampled_dir, 1'b1,
                 "read_toc0_vseq: first device response sampled wrong direction")
    `DV_CHECK_EQ(dev_seq1.sampled_dir, 1'b0,
                 "read_toc0_vseq: second device response sampled wrong direction")

    `DV_CHECK_EQ(resp0[31:28], 4'h0,         "read_toc0_vseq: first response expected Success")
    `DV_CHECK_EQ(resp0[27:24], 4'd5,         "read_toc0_vseq: first response TID mismatch")
    `DV_CHECK_EQ(resp0[15:0],  16'd2,        "read_toc0_vseq: first response length mismatch")
    `DV_CHECK_EQ(resp1[31:28], 4'h0,         "read_toc0_vseq: second response expected Success")
    `DV_CHECK_EQ(resp1[27:24], 4'd6,         "read_toc0_vseq: second response TID mismatch")
    `DV_CHECK_EQ(resp1[15:0],  16'd2,        "read_toc0_vseq: second response length mismatch")
  endtask
endclass
