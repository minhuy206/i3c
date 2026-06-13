class i3c_read_len_sweep_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_len_sweep_vseq)

  localparam int unsigned NUM_LENGTHS = 8;

  function new(string name = "i3c_read_len_sweep_vseq");
    super.new(name);
  endfunction

  task body();
    int unsigned lengths[NUM_LENGTHS] = '{1, 2, 3, 4, 5, 7, 8, 16};
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      enable_dut(broadcast_modes[mode_idx]);
      write_dat_entry(0, 7'h50, 7'h08, 1'b0);

      foreach (lengths[sweep_idx]) begin
        run_len_case(sweep_idx, lengths[sweep_idx], broadcast_modes[mode_idx]);
      end
    end

    `uvm_info(`gfn, "SDRR_002 I3C regular read length sweep checks passed", UVM_LOW)
  endtask

  virtual task run_len_case(int unsigned sweep_idx, int unsigned data_length,
                            bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    word_queue_t            rx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    build_payload(sweep_idx, data_length, read_data);

    cfg                  = make_transfer_cfg(
        .ctxt($sformatf("SDRR_002 %s len %0d", private_addr_mode_name(broadcast_header_enable),
          data_length)),
        .seq_name($sformatf("sdrr002_%s_dev_seq_%0d", private_addr_mode_name(broadcast_header_enable),
          data_length)),
        .tid(4'(sweep_idx + 1)),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(data_length),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_read_stimulus_words(cfg, read_data, rx_words, resp, dev_seq);

    `DV_CHECK_EQ(dev_seq.done, 1'b1,
                 $sformatf("SDRR_002 len %0d: device response did not finish", data_length))
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08,
                 $sformatf("SDRR_002 len %0d: target address mismatch", data_length))
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b1,
                 $sformatf("SDRR_002 len %0d: transfer direction should be read", data_length))

    `DV_CHECK_EQ(resp[31:28], 4'h0,
                 $sformatf("SDRR_002 len %0d: expected Success response", data_length))
    `DV_CHECK_EQ(resp[27:24], cfg.tid,
                 $sformatf("SDRR_002 len %0d: response TID mismatch", data_length))
    `DV_CHECK_EQ(resp[15:0], 16'(data_length),
                 $sformatf("SDRR_002 len %0d: response length mismatch", data_length))

    check_all_queues_empty($sformatf("after SDRR_002 len %0d", data_length));
  endtask

  virtual function void build_payload(int unsigned sweep_idx, int unsigned data_length,
                                      ref byte_queue_t read_data);
    read_data.delete();

    for (int unsigned i = 0; i < data_length; i++) begin
      read_data.push_back(8'(8'h40 + (sweep_idx * 8) + i));
    end
  endfunction

endclass
