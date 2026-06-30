class i2c_regular_write_basic_vseq extends i3c_base_vseq;
  `uvm_object_utils(i2c_regular_write_basic_vseq)

  localparam bit [6:0] I2C_STATIC_ADDR = 7'h50;
  localparam bit [6:0] I3C_DYNAMIC_ADDR = 7'h08;
  localparam int unsigned I2C_DEV_IDX = 0;

  function new(string name = "i2c_regular_write_basic_vseq");
    super.new(name);
  endfunction

  task body();
    enable_dut(1'b0);
    write_dat_entry(I2C_DEV_IDX, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b1);

    run_i2c_write_case(1, 4'd1);
    run_i2c_write_case(4, 4'd2);

    `uvm_info(
        `gfn,
        "I2C_001 conclusion: regular I2C legacy writes of 1 and 4 bytes use static address+W and produce Success responses",
        UVM_LOW)
  endtask

  virtual task run_i2c_write_case(int unsigned data_length, bit [3:0] tid);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    build_payload(data_length, exp_data, tx_words);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("I2C_001 len %0d", data_length)),
        .seq_name($sformatf("i2c001_len%0d_dev_seq", data_length)),
        .tid(tid),
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

    check_all_queues_empty($sformatf("after I2C_001 len %0d", data_length));

    `uvm_info(`gfn, $sformatf(
                  "I2C_001 result: len=%0d resp=0x%08h sampled_addr=0x%02h sampled_bytes=%0d",
                  data_length, resp, dev_seq.sampled_addr, dev_seq.sampled_data.size()), UVM_LOW)
  endtask

  virtual function void build_payload(int unsigned data_length, ref byte_queue_t exp_data,
                                      ref word_queue_t tx_words);
    build_random_tx_words(data_length, exp_data, tx_words);
  endfunction

endclass
