class i3c_write_tbit_parity_generation_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_tbit_parity_generation_vseq)

  localparam int unsigned NUM_TEST_BYTES = 8;

  function new(string name = "i3c_write_tbit_parity_generation_vseq");
    super.new(name);
  endfunction

  virtual task body();
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            exp_data;
    word_queue_t            tx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    build_payload(exp_data, tx_words);

    cfg                  = make_transfer_cfg(
        "SDRW_004 tbit_parity",
        "sdrw004_dev_seq",
        4'd4,
        5'd0,
        7'h08,
        1'b1,
        NUM_TEST_BYTES
    );
    cfg.wait_device_done = 1'b1;

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    `DV_CHECK_EQ(dev_seq.done, 1'b1, "SDRW_004: device response did not finish")
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08, "SDRW_004: target address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0, "SDRW_004: transfer direction should be write")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), NUM_TEST_BYTES,
                 "SDRW_004: sampled byte count mismatch")
    for (int unsigned i = 0; i < NUM_TEST_BYTES; i++) begin
      if (i < dev_seq.sampled_data.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_data[i], exp_data[i],
                     $sformatf("SDRW_004: sampled byte[%0d] mismatch", i))
      end
    end

    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), NUM_TEST_BYTES,
                 "SDRW_004: sampled T-bit count mismatch")
    for (int unsigned i = 0; i < NUM_TEST_BYTES; i++) begin
      if (i < dev_seq.sampled_t_bit.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_t_bit[i], ~^exp_data[i],
                     $sformatf("SDRW_004: T-bit parity mismatch for byte[%0d]", i))
      end
    end

    `DV_CHECK_EQ(resp[31:28], 4'h0, "SDRW_004: expected Success response")
    `DV_CHECK_EQ(resp[27:24], cfg.tid, "SDRW_004: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], 16'(NUM_TEST_BYTES), "SDRW_004: response length mismatch")

    check_all_queues_empty("after SDRW_004 tbit_parity");

    `uvm_info(`gfn, "SDRW_004 I3C write T-bit parity generation checks passed", UVM_LOW)
  endtask

  virtual function void build_payload(ref byte_queue_t exp_data, ref word_queue_t tx_words);
    exp_data.delete();
    tx_words.delete();

    exp_data.push_back(8'h00);
    exp_data.push_back(8'h01);
    exp_data.push_back(8'h03);
    exp_data.push_back(8'h07);
    exp_data.push_back(8'h0F);
    exp_data.push_back(8'h1F);
    exp_data.push_back(8'h55);
    exp_data.push_back(8'hFE);

    tx_words.push_back(32'h0703_0100);
    tx_words.push_back(32'hFE55_1F0F);
  endfunction

endclass
