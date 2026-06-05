class i3c_write_toc_zero_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_toc_zero_vseq)

  function new(string name = "i3c_write_toc_zero_vseq");
    super.new(name);
  endfunction

  virtual task body();
    transfer_stimulus_cfg_t cfg0;
    transfer_stimulus_cfg_t cfg1;
    word_queue_t            tx_words;
    bit [31:0]              resp0;
    bit [31:0]              resp1;
    int                     rstart_count;
    i3c_device_response_seq dev_seq0;
    i3c_device_response_seq dev_seq1;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg0                   = make_transfer_cfg("toc0_vseq first", "dev_seq0", 4'd3, 5'd0, 7'h08,
                                               1'b1, 2);
    cfg1                   = make_transfer_cfg("toc0_vseq second", "dev_seq1", 4'd4, 5'd0, 7'h08,
                                               1'b1, 2);
    cfg0.settle_before_cmd = 5;
    tx_words.push_back(32'h0000_BBAA);
    tx_words.push_back(32'h0000_DDCC);

    run_toc_zero_write_stimulus(cfg0, cfg1, tx_words, resp0, resp1, rstart_count, dev_seq0,
                                dev_seq1);

    `DV_CHECK_EQ(dev_seq0.done, 1'b1, "toc0_vseq: first device response did not finish")
    `DV_CHECK_EQ(dev_seq1.done, 1'b1, "toc0_vseq: second device response did not finish")
    `DV_CHECK_EQ((rstart_count > 0), 1'b1, "toc0_vseq: expected at least one observed RSTART")

    `DV_CHECK_EQ(resp0[31:28], 4'h0,  "toc0_vseq: first response expected Success")
    `DV_CHECK_EQ(resp0[27:24], 4'd3,  "toc0_vseq: first response TID mismatch")
    `DV_CHECK_EQ(resp0[15:0],  16'd2, "toc0_vseq: first response length mismatch")
    `DV_CHECK_EQ(resp1[31:28], 4'h0,  "toc0_vseq: second response expected Success")
    `DV_CHECK_EQ(resp1[27:24], 4'd4,  "toc0_vseq: second response TID mismatch")
    `DV_CHECK_EQ(resp1[15:0],  16'd2, "toc0_vseq: second response length mismatch")
  endtask
endclass
