class i3c_read_data_patterns_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_data_patterns_vseq)

  function new(string name = "i3c_read_data_patterns_vseq");
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

  endtask

  virtual task run_pattern_case(int unsigned pattern_idx, string pattern_name,
                                bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    word_queue_t                   rx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    build_sdr_data_pattern_payload(pattern_idx, read_data);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRR_004 %s %s", private_addr_mode_name(broadcast_header_enable), pattern_name
        )),
        .seq_name($sformatf(
            "sdrr007_%s_dev_seq_%s", private_addr_mode_name(broadcast_header_enable), pattern_name
        )),
        .tid(4'(pattern_idx + 1)),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(read_data.size()),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_read_stimulus_words(cfg, read_data, rx_words, resp, dev_seq);

    check_all_queues_empty($sformatf("after SDRR_004 %s", pattern_name));

    `uvm_info(`gfn, $sformatf(
                  "SDRR_004 result: mode=%s pattern=%s len=%0d rx_words_drained=%0d resp_len=%0d",
                  private_addr_mode_name(broadcast_header_enable), pattern_name, read_data.size(),
                  rx_words.size(), resp[15:0]), UVM_LOW)
  endtask

endclass
