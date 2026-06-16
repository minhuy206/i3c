class i3c_write_len_sweep_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_len_sweep_vseq)

  localparam int unsigned NUM_LENGTHS = 11;

  function new(string name = "i3c_write_len_sweep_vseq");
    super.new(name);
  endfunction

  task body();
    int unsigned lengths[NUM_LENGTHS] = '{0, 1, 2, 3, 4, 5, 7, 8, 16, 64, 256};
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      enable_dut(broadcast_modes[mode_idx]);
      write_dat_entry(0, 7'h50, 7'h08, 1'b0);

      foreach (lengths[sweep_idx]) begin
        run_len_case(sweep_idx, lengths[sweep_idx], broadcast_modes[mode_idx]);
      end
    end

    `uvm_info(`gfn,
              "SDRW_002 conclusion: SDR private writes deliver each requested byte count across the length sweep",
              UVM_LOW)
  endtask

  virtual task run_len_case(int unsigned sweep_idx, int unsigned data_length,
                            bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    bit                            preload_tx;
    i3c_device_response_seq        dev_seq;

    build_payload(sweep_idx, data_length, exp_data, tx_words);
    preload_tx = tx_words.size() <= 8;

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRW_002 %s len %0d", private_addr_mode_name(broadcast_header_enable), data_length
        )),
        .seq_name($sformatf(
            "sdrw002_%s_dev_seq_%0d", private_addr_mode_name(broadcast_header_enable), data_length
        )),
        .tid(4'(sweep_idx + 1)),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(preload_tx),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(data_length),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    `DV_CHECK_EQ(dev_seq.done, 1'b1, $sformatf("SDRW_002 len %0d: device response did not finish",
                                               data_length))
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), data_length,
                 $sformatf("SDRW_002 len %0d: sampled byte count mismatch", data_length))

    check_all_queues_empty($sformatf("after SDRW_002 len %0d", data_length));

    `uvm_info(`gfn, $sformatf(
                  "SDRW_002 result: mode=%s len=%0d tx_words=%0d sampled_bytes=%0d preload_tx=%0b",
                  private_addr_mode_name(broadcast_header_enable), data_length, tx_words.size(),
                  dev_seq.sampled_data.size(), preload_tx), UVM_LOW)
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
