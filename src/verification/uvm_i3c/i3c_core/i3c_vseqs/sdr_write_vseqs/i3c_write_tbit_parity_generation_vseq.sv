class i3c_write_tbit_parity_generation_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_tbit_parity_generation_vseq)

  localparam int unsigned NUM_TEST_BYTES = 8;

  function new(string name = "i3c_write_tbit_parity_generation_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_tbit_case(broadcast_modes[mode_idx]);
    end

  endtask

  virtual task run_tbit_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    bit                            saw_tbit_zero;
    bit                            saw_tbit_one;
    bit                      [6:0] static_addr;
    bit                      [6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);

    build_random_payload(NUM_TEST_BYTES, exp_data);
    saw_tbit_zero = 1'b0;
    saw_tbit_one = 1'b0;
    foreach (exp_data[i]) begin
      if (~^exp_data[i]) saw_tbit_one = 1'b1;
      else saw_tbit_zero = 1'b1;
    end
    if (!(saw_tbit_zero && saw_tbit_one) && (exp_data.size() > 1)) begin
      exp_data[exp_data.size()-1] = exp_data[0] ^ 8'h01;
    end
    pack_payload_words(exp_data, tx_words);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRW_004 %s tbit_parity", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf("sdrw004_%s_dev_seq", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd4),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(NUM_TEST_BYTES),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    `DV_CHECK_EQ(dev_seq.done, 1'b1, "SDRW_004: device response did not finish")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), NUM_TEST_BYTES,
                 "SDRW_004: sampled byte count mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), NUM_TEST_BYTES,
                 "SDRW_004: sampled T-bit count mismatch")
    for (int unsigned i = 0; i < NUM_TEST_BYTES; i++) begin
      if ((i < dev_seq.sampled_t_bit.size()) && (i < dev_seq.sampled_data.size())) begin
        `DV_CHECK_EQ(dev_seq.sampled_t_bit[i], ~^dev_seq.sampled_data[i],
                     $sformatf("SDRW_004: T-bit parity mismatch for byte[%0d]", i))
      end
    end

    check_all_queues_empty("after SDRW_004 tbit_parity");

    `uvm_info(`gfn, $sformatf(
                  "SDRW_004 result: mode=%s len=%0d sampled_bytes=%0d sampled_t_bits=%0d parity_checks=%0d",
                  private_addr_mode_name(broadcast_header_enable), NUM_TEST_BYTES,
                  dev_seq.sampled_data.size(), dev_seq.sampled_t_bit.size(), NUM_TEST_BYTES),
              UVM_LOW)
  endtask

endclass
