class bus_tx_byte_and_bit_order_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_tx_byte_and_bit_order_vseq)

  localparam int unsigned NUM_TEST_BYTES = 4;

  function new(string name = "bus_tx_byte_and_bit_order_vseq");
    super.new(name);
  endfunction

  task body();
    transfer_stimulus_cfg_t        cfg;
    word_queue_t                   tx_words;
    i3c_device_response_seq        dev_seq;
    bit                     [ 7:0] exp_data[NUM_TEST_BYTES];
    bit                     [31:0] resp;

    exp_data[0] = 8'h00;
    exp_data[1] = 8'hff;
    exp_data[2] = 8'ha5;
    exp_data[3] = 8'h96;

    enable_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt("BUS_008"),
        .seq_name("dev_seq"),
        .tid(4'd8),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(NUM_TEST_BYTES),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    tx_words.push_back({exp_data[3], exp_data[2], exp_data[1], exp_data[0]});

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08, "BUS_008: target address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0, "BUS_008: transfer direction should be write")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), NUM_TEST_BYTES,
                 "BUS_008: device should sample all write data bytes")
    for (int i = 0; i < NUM_TEST_BYTES; i++) begin
      if (i < dev_seq.sampled_data.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_data[i], exp_data[i],
                     $sformatf("BUS_008: sampled byte[%0d] mismatch; bit order is wrong", i))
      end
    end

    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), NUM_TEST_BYTES,
                 "BUS_008: device should sample one controller T-bit per data byte")
    for (int i = 0; i < NUM_TEST_BYTES; i++) begin
      if (i < dev_seq.sampled_t_bit.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_t_bit[i], ~^exp_data[i],
                     $sformatf("BUS_008: T-bit parity mismatch for byte[%0d]", i))
      end
    end

    `DV_CHECK_EQ(resp[31:28], 4'h0, "BUS_008: expected Success response")
    `DV_CHECK_EQ(resp[27:24], cfg.tid, "BUS_008: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], NUM_TEST_BYTES[15:0], "BUS_008: response length mismatch")

    `uvm_info(`gfn, "BUS_008 full SDR write byte and bit-order checks passed", UVM_LOW)
  endtask

endclass
