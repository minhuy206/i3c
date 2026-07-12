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
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(data_length),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    check_all_queues_empty($sformatf("after I2C_004 write len %0d", data_length));
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
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(data_length),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    run_read_stimulus_words(cfg, read_data, cfg.data_length, rx_words, resp, dev_seq);

    check_all_queues_empty($sformatf("after I2C_004 read len %0d", data_length));

  endtask

  virtual function void build_write_payload(int unsigned data_length, ref byte_queue_t exp_data,
                                            ref word_queue_t tx_words);
    build_random_tx_words(data_length, exp_data, tx_words);
  endfunction

  virtual function void build_read_payload(int unsigned data_length, ref byte_queue_t read_data);
    build_random_payload(data_length, read_data);
  endfunction

endclass
