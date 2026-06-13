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

    `uvm_info(`gfn, "SDRR_007 I3C regular read data pattern checks passed", UVM_LOW)
  endtask

  virtual task run_pattern_case(int unsigned pattern_idx, string pattern_name,
                                bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    word_queue_t            rx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    build_pattern_payload(pattern_idx, read_data);

    cfg                  = make_transfer_cfg(
        .ctxt($sformatf("SDRR_007 %s %s", private_addr_mode_name(broadcast_header_enable),
          pattern_name)),
        .seq_name($sformatf("sdrr007_%s_dev_seq_%s", private_addr_mode_name(broadcast_header_enable),
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
        .data_length(read_data.size()),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_read_stimulus_words(cfg, read_data, rx_words, resp, dev_seq);

    `DV_CHECK_EQ(dev_seq.done, 1'b1,
                 $sformatf("SDRR_007 %s: device response did not finish", pattern_name))
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08,
                 $sformatf("SDRR_007 %s: target address mismatch", pattern_name))
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b1,
                 $sformatf("SDRR_007 %s: transfer direction should be read", pattern_name))

    `DV_CHECK_EQ(resp[31:28], 4'h0,
                 $sformatf("SDRR_007 %s: expected Success response", pattern_name))
    `DV_CHECK_EQ(resp[27:24], cfg.tid,
                 $sformatf("SDRR_007 %s: response TID mismatch", pattern_name))
    `DV_CHECK_EQ(resp[15:0], 16'(read_data.size()),
                 $sformatf("SDRR_007 %s: response length mismatch", pattern_name))

    check_all_queues_empty($sformatf("after SDRR_007 %s", pattern_name));
  endtask

  virtual function void build_pattern_payload(int unsigned pattern_idx,
                                              ref byte_queue_t read_data);
    bit [7:0] fixed_random[16] = '{
        8'h3C, 8'hA7, 8'h19, 8'hE2, 8'h5D, 8'h80, 8'h0F, 8'hB4,
        8'hC1, 8'h26, 8'h7A, 8'h93, 8'h48, 8'hDE, 8'h04, 8'hF0
    };

    read_data.delete();

    case (pattern_idx)
      0: begin
        repeat (8) read_data.push_back(8'h00);
      end
      1: begin
        repeat (8) read_data.push_back(8'hFF);
      end
      2: begin
        for (int unsigned i = 0; i < 8; i++) begin
          read_data.push_back(8'(8'h01 << i));
        end
      end
      3: begin
        for (int unsigned i = 0; i < 8; i++) begin
          read_data.push_back(i[0] ? 8'h55 : 8'hAA);
        end
      end
      4: begin
        foreach (fixed_random[i]) begin
          read_data.push_back(fixed_random[i]);
        end
      end
      default: begin
        `uvm_fatal(`gfn, $sformatf("SDRR_007: unsupported pattern index %0d", pattern_idx))
      end
    endcase
  endfunction

endclass
