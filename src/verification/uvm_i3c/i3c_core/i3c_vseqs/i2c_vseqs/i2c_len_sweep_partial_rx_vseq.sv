class i2c_len_sweep_partial_rx_vseq extends i3c_base_vseq;
  `uvm_object_utils(i2c_len_sweep_partial_rx_vseq)

  localparam bit [6:0] I2C_STATIC_ADDR = 7'h50;
  localparam bit [6:0] I3C_DYNAMIC_ADDR = 7'h08;
  localparam int unsigned I2C_DEV_IDX = 0;
  localparam int unsigned NUM_LENGTHS = 7;

  function new(string name = "i2c_len_sweep_partial_rx_vseq");
    super.new(name);
  endfunction

  task body();
    int unsigned lengths[NUM_LENGTHS] = '{1, 2, 3, 4, 5, 7, 8};

    enable_dut(1'b0);
    write_dat_entry(I2C_DEV_IDX, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b1);

    foreach (lengths[sweep_idx]) begin
      run_i2c_write_len_case(sweep_idx, lengths[sweep_idx]);
      run_i2c_read_len_case(sweep_idx, lengths[sweep_idx]);
    end

    `uvm_info(
        `gfn,
        "I2C_004 conclusion: legacy I2C reads and writes preserve byte packing across partial and full DWORD lengths",
        UVM_LOW)
  endtask

  virtual task run_i2c_write_len_case(int unsigned sweep_idx, int unsigned data_length);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    build_write_payload(data_length, exp_data, tx_words);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("I2C_004 write len %0d", data_length)),
        .seq_name($sformatf("i2c004_wr_len%0d_dev_seq", data_length)),
        .tid(4'(sweep_idx + 1)),
        .dev_idx(I2C_DEV_IDX[4:0]),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(data_length),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    check_all_queues_empty($sformatf("after I2C_004 write len %0d", data_length));

    `uvm_info(`gfn, $sformatf(
                  "I2C_004 write result: len=%0d resp=0x%08h tx_words=%0d sampled_bytes=%0d",
                  data_length, resp, tx_words.size(), dev_seq.sampled_data.size()), UVM_LOW)
  endtask

  virtual task run_i2c_read_len_case(int unsigned sweep_idx, int unsigned data_length);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    word_queue_t                   rx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    build_read_payload(data_length, read_data);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("I2C_004 read len %0d", data_length)),
        .seq_name($sformatf("i2c004_rd_len%0d_dev_seq", data_length)),
        .tid(4'(8 + sweep_idx)),
        .dev_idx(I2C_DEV_IDX[4:0]),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(data_length),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    run_read_stimulus_words(cfg, read_data, rx_words, resp, dev_seq);

    check_all_queues_empty($sformatf("after I2C_004 read len %0d", data_length));

    `uvm_info(`gfn, $sformatf(
                  "I2C_004 read result: len=%0d resp=0x%08h rx_words=%0d ack_seq=%s",
                  data_length, resp, rx_words.size(),
                  format_master_ack_sequence(dev_seq, data_length)), UVM_LOW)
  endtask

  virtual function void build_write_payload(int unsigned data_length, ref byte_queue_t exp_data,
                                            ref word_queue_t tx_words);
    build_random_tx_words(data_length, exp_data, tx_words);
  endfunction

  virtual function void build_read_payload(int unsigned data_length, ref byte_queue_t read_data);
    build_random_payload(data_length, read_data);
  endfunction

  virtual function string format_master_ack_sequence(i3c_device_response_seq dev_seq,
                                                     int unsigned data_length);
    string s;

    s = "[";
    for (int unsigned i = 0; i < data_length; i++) begin
      if (i > 0) s = {s, " "};
      if (i < dev_seq.sampled_t_bit.size()) begin
        s = {s, (dev_seq.sampled_t_bit[i] == SampledAck) ? "ACK" : "NACK"};
      end else begin
        s = {s, "MISSING"};
      end
    end
    return {s, "]"};
  endfunction

endclass
