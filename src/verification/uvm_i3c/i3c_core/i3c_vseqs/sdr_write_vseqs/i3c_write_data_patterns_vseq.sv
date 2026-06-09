class i3c_write_data_patterns_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_data_patterns_vseq)

  function new(string name = "i3c_write_data_patterns_vseq");
    super.new(name);
  endfunction

  task body();
    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    run_pattern_case(0, "all_zero");
    run_pattern_case(1, "all_one");
    run_pattern_case(2, "walking_one");
    run_pattern_case(3, "alternating");
    run_pattern_case(4, "fixed_random");

    `uvm_info(`gfn, "SDRW_003 I3C regular write data pattern checks passed", UVM_LOW)
  endtask

  virtual task run_pattern_case(int unsigned pattern_idx, string pattern_name);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            exp_data;
    word_queue_t            tx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    build_pattern_payload(pattern_idx, exp_data, tx_words);

    cfg                  = make_transfer_cfg(
        $sformatf("SDRW_003 %s", pattern_name),
        $sformatf("sdrw003_dev_seq_%s", pattern_name),
        4'(pattern_idx + 1),
        5'd0,
        7'h08,
        1'b1,
        exp_data.size()
    );
    cfg.wait_device_done = 1'b1;

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    `DV_CHECK_EQ(dev_seq.done, 1'b1,
                 $sformatf("SDRW_003 %s: device response did not finish", pattern_name))
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08,
                 $sformatf("SDRW_003 %s: target address mismatch", pattern_name))
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0,
                 $sformatf("SDRW_003 %s: transfer direction should be write", pattern_name))
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), exp_data.size(),
                 $sformatf("SDRW_003 %s: sampled byte count mismatch", pattern_name))
    for (int unsigned i = 0; i < exp_data.size(); i++) begin
      if (i < dev_seq.sampled_data.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_data[i], exp_data[i],
                     $sformatf("SDRW_003 %s: sampled byte[%0d] mismatch",
                               pattern_name, i))
      end
    end

    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), exp_data.size(),
                 $sformatf("SDRW_003 %s: sampled T-bit count mismatch", pattern_name))
    for (int unsigned i = 0; i < exp_data.size(); i++) begin
      if (i < dev_seq.sampled_t_bit.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_t_bit[i], ~^exp_data[i],
                     $sformatf("SDRW_003 %s: T-bit parity mismatch for byte[%0d]",
                               pattern_name, i))
      end
    end

    `DV_CHECK_EQ(resp[31:28], 4'h0,
                 $sformatf("SDRW_003 %s: expected Success response", pattern_name))
    `DV_CHECK_EQ(resp[27:24], cfg.tid,
                 $sformatf("SDRW_003 %s: response TID mismatch", pattern_name))
    `DV_CHECK_EQ(resp[15:0], 16'(exp_data.size()),
                 $sformatf("SDRW_003 %s: response length mismatch", pattern_name))

    check_all_queues_empty($sformatf("after SDRW_003 %s", pattern_name));
  endtask

  virtual function void build_pattern_payload(int unsigned pattern_idx,
                                              ref byte_queue_t exp_data,
                                              ref word_queue_t tx_words);
    bit [7:0] fixed_random[16] = '{
        8'h3C, 8'hA7, 8'h19, 8'hE2, 8'h5D, 8'h80, 8'h0F, 8'hB4,
        8'hC1, 8'h26, 8'h7A, 8'h93, 8'h48, 8'hDE, 8'h04, 8'hF0
    };

    exp_data.delete();
    tx_words.delete();

    case (pattern_idx)
      0: begin
        repeat (8) exp_data.push_back(8'h00);
      end
      1: begin
        repeat (8) exp_data.push_back(8'hFF);
      end
      2: begin
        for (int unsigned i = 0; i < 8; i++) begin
          exp_data.push_back(8'(8'h01 << i));
        end
      end
      3: begin
        for (int unsigned i = 0; i < 8; i++) begin
          exp_data.push_back(i[0] ? 8'h55 : 8'hAA);
        end
      end
      4: begin
        foreach (fixed_random[i]) begin
          exp_data.push_back(fixed_random[i]);
        end
      end
      default: begin
        `uvm_fatal(`gfn, $sformatf("SDRW_003: unsupported pattern index %0d", pattern_idx))
      end
    endcase

    pack_payload_words(exp_data, tx_words);
  endfunction

  virtual function void pack_payload_words(ref byte_queue_t exp_data, ref word_queue_t tx_words);
    bit [31:0] tx_word;

    tx_words.delete();
    for (int unsigned word_idx = 0; word_idx < ((exp_data.size() + 3) / 4); word_idx++) begin
      tx_word = '0;
      for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++) begin
        int unsigned data_idx;

        data_idx = (word_idx * 4) + byte_idx;
        if (data_idx < exp_data.size()) begin
          tx_word[(byte_idx*8)+:8] = exp_data[data_idx];
        end
      end
      tx_words.push_back(tx_word);
    end
  endfunction

endclass
