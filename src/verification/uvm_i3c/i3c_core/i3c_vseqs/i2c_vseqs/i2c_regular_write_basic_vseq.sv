class i2c_regular_write_basic_vseq extends i3c_base_vseq;
  `uvm_object_utils(i2c_regular_write_basic_vseq)

  localparam bit [6:0] I3C_DYNAMIC_ADDR = 7'h08;
  localparam int unsigned I2C_DEV_IDX = 0;

  function new(string name = "i2c_regular_write_basic_vseq");
    super.new(name);
  endfunction

  task body();
    enable_dut(1'b0);

    run_i2c_write_case(7'h10, 1, 4'd1);
    run_i2c_write_case(7'h50, 1, 4'd2);
    run_i2c_write_case(7'h50, 4, 4'd3);
    run_i2c_write_case(7'h70, 1, 4'd4);

    // I2C must ignore the I3C broadcast-header enable bit.
    enable_dut(1'b1);
    run_i2c_write_case(7'h50, 2, 4'd5);

  endtask

  virtual task run_i2c_write_case(bit [6:0] static_addr, int unsigned data_length, bit [3:0] tid);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.static_addr = static_addr;
    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.static_addr_valid = 1'b1;
    write_dat_entry(I2C_DEV_IDX, static_addr, I3C_DYNAMIC_ADDR, 1'b1);
    build_payload(data_length, exp_data, tx_words);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("I2C_001 addr 0x%02h len %0d", static_addr, data_length)),
        .seq_name($sformatf("i2c001_addr%02h_len%0d_dev_seq", static_addr, data_length)),
        .tid(tid),
        .dev_idx(I2C_DEV_IDX[4:0]),
        .target_addr(static_addr),
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

    check_all_queues_empty($sformatf("after I2C_001 addr 0x%02h len %0d", static_addr,
                                     data_length));

  endtask

  virtual function void build_payload(int unsigned data_length, ref byte_queue_t exp_data,
                                      ref word_queue_t tx_words);
    build_random_tx_words(data_length, exp_data, tx_words);
  endfunction

endclass
