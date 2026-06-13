class i3c_write_data_patterns_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_data_patterns_vseq)

  function new(string name = "i3c_write_data_patterns_vseq");
    super.new(name);
  endfunction

  task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      enable_dut(broadcast_modes[mode_idx]);
      write_dat_entry(0, 7'h50, 7'h08, 1'b0);

      run_pattern_case(0, "all_zero", broadcast_modes[mode_idx]);
      run_pattern_case(1, "all_one", broadcast_modes[mode_idx]);
      run_pattern_case(2, "walking_one", broadcast_modes[mode_idx]);
      run_pattern_case(3, "alternating", broadcast_modes[mode_idx]);
      run_pattern_case(4, "fixed_random", broadcast_modes[mode_idx]);
    end

    `uvm_info(`gfn, "SDRW_003 I3C regular write data pattern checks passed", UVM_LOW)
  endtask

  virtual task run_pattern_case(int unsigned pattern_idx, string pattern_name,
                                bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            exp_data;
    word_queue_t            tx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    build_pattern_payload(pattern_idx, exp_data, tx_words);

    cfg                  = make_transfer_cfg(
        .ctxt($sformatf("SDRW_003 %s %s", private_addr_mode_name(broadcast_header_enable),
          pattern_name)),
        .seq_name($sformatf("sdrw003_%s_dev_seq_%s", private_addr_mode_name(broadcast_header_enable),
          pattern_name)),
        .tid(4'(pattern_idx + 1)),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(exp_data.size()),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    `DV_CHECK_EQ(dev_seq.done, 1'b1,
                 $sformatf("SDRW_003 %s: device response did not finish", pattern_name))
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), exp_data.size(),
                 $sformatf("SDRW_003 %s: sampled byte count mismatch", pattern_name))
    for (int unsigned i = 0; i < exp_data.size(); i++) begin
      if (i < dev_seq.sampled_data.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_data[i], exp_data[i],
                     $sformatf("SDRW_003 %s: sampled byte[%0d] mismatch",
                               pattern_name, i))
      end
    end

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
