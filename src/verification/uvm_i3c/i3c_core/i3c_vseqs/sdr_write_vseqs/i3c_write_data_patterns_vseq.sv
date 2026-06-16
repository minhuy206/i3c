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

    `uvm_info(`gfn,
              "SDRW_003 conclusion: SDR private writes preserve all exercised data patterns in both private-address modes",
              UVM_LOW)
  endtask

  virtual task run_pattern_case(int unsigned pattern_idx, string pattern_name,
                                bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            exp_data;
    word_queue_t            tx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    build_sdr_data_pattern_payload(pattern_idx, exp_data);
    pack_payload_words(exp_data, tx_words);

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

    `uvm_info(`gfn, $sformatf(
                  "SDRW_003 result: mode=%s pattern=%s len=%0d tx_words=%0d sampled_bytes=%0d",
                  private_addr_mode_name(broadcast_header_enable), pattern_name, exp_data.size(),
                  tx_words.size(), dev_seq.sampled_data.size()), UVM_LOW)
  endtask

endclass
