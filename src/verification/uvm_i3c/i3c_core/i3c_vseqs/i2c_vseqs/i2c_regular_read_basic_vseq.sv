class i2c_regular_read_basic_vseq extends i3c_base_vseq;
  `uvm_object_utils(i2c_regular_read_basic_vseq)

  localparam bit [6:0] I2C_STATIC_ADDR = 7'h50;
  localparam bit [6:0] I3C_DYNAMIC_ADDR = 7'h08;
  localparam int unsigned I2C_DEV_IDX = 0;

  function new(string name = "i2c_regular_read_basic_vseq");
    super.new(name);
  endfunction

  task body();
    enable_dut(1'b0);
    write_dat_entry(I2C_DEV_IDX, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b1);

    run_i2c_read_case(1, 4'd1);
    run_i2c_read_case(4, 4'd2);

  endtask

  virtual task run_i2c_read_case(int unsigned data_length, bit [3:0] tid);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    bit                     [31:0] rx;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    build_payload(data_length, read_data);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("I2C_002 len %0d", data_length)),
        .seq_name($sformatf("i2c002_len%0d_dev_seq", data_length)),
        .tid(tid),
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

    run_read_stimulus(cfg, read_data, rx, resp, dev_seq);

    check_all_queues_empty($sformatf("after I2C_002 len %0d", data_length));

  endtask

  virtual function void build_payload(int unsigned data_length, ref byte_queue_t read_data);
    build_random_payload(data_length, read_data);
  endfunction

endclass
