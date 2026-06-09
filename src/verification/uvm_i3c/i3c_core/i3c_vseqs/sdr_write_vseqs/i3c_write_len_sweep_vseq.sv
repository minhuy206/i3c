class i3c_write_len_sweep_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_len_sweep_vseq)

  localparam int unsigned NUM_LENGTHS = 8;

  function new(string name = "i3c_write_len_sweep_vseq");
    super.new(name);
  endfunction

  task body();
    int unsigned lengths[NUM_LENGTHS] = '{1, 2, 3, 4, 5, 7, 8, 16};

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    foreach (lengths[sweep_idx]) begin
      run_len_case(sweep_idx, lengths[sweep_idx]);
    end

    `uvm_info(`gfn, "SDRW_002 I3C regular write length sweep checks passed", UVM_LOW)
  endtask

  virtual task run_len_case(int unsigned sweep_idx, int unsigned data_length);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            exp_data;
    word_queue_t            tx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    build_payload(sweep_idx, data_length, exp_data, tx_words);

    cfg                  = make_transfer_cfg(
        $sformatf("SDRW_002 len %0d", data_length),
        $sformatf("sdrw002_dev_seq_%0d", data_length),
        4'(sweep_idx + 1),
        5'd0,
        7'h08,
        1'b1,
        data_length
    );
    cfg.wait_device_done = 1'b1;

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    `DV_CHECK_EQ(dev_seq.done, 1'b1,
                 $sformatf("SDRW_002 len %0d: device response did not finish", data_length))
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08,
                 $sformatf("SDRW_002 len %0d: target address mismatch", data_length))
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0,
                 $sformatf("SDRW_002 len %0d: transfer direction should be write", data_length))
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), data_length,
                 $sformatf("SDRW_002 len %0d: sampled byte count mismatch", data_length))
    for (int unsigned i = 0; i < data_length; i++) begin
      if (i < dev_seq.sampled_data.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_data[i], exp_data[i],
                     $sformatf("SDRW_002 len %0d: sampled byte[%0d] mismatch", data_length, i))
      end
    end

    `DV_CHECK_EQ(resp[31:28], 4'h0,
                 $sformatf("SDRW_002 len %0d: expected Success response", data_length))
    `DV_CHECK_EQ(resp[27:24], cfg.tid,
                 $sformatf("SDRW_002 len %0d: response TID mismatch", data_length))
    `DV_CHECK_EQ(resp[15:0], 16'(data_length),
                 $sformatf("SDRW_002 len %0d: response length mismatch", data_length))

    check_all_queues_empty($sformatf("after SDRW_002 len %0d", data_length));
  endtask

  virtual function void build_payload(int unsigned sweep_idx, int unsigned data_length,
                                      ref byte_queue_t exp_data, ref word_queue_t tx_words);
    bit [31:0] tx_word;

    exp_data.delete();
    tx_words.delete();

    for (int unsigned i = 0; i < data_length; i++) begin
      exp_data.push_back(8'(8'h20 + (sweep_idx * 8) + i));
    end

    for (int unsigned word_idx = 0; word_idx < ((data_length + 3) / 4); word_idx++) begin
      tx_word = '0;
      for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++) begin
        int unsigned data_idx;

        data_idx = (word_idx * 4) + byte_idx;
        if (data_idx < data_length) begin
          tx_word[(byte_idx*8)+:8] = exp_data[data_idx];
        end
      end
      tx_words.push_back(tx_word);
    end
  endfunction

endclass
