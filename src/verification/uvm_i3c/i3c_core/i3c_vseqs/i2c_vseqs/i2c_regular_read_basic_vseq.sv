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

    `uvm_info(
        `gfn,
        "I2C_002 conclusion: regular I2C legacy reads of 1 and 4 bytes use static address+R and terminate with master NACK",
        UVM_LOW)
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
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(data_length),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    run_read_stimulus(cfg, read_data, rx, resp, dev_seq);

    check_all_queues_empty($sformatf("after I2C_002 len %0d", data_length));

    `uvm_info(`gfn, $sformatf(
                  "I2C_002 result: len=%0d resp=0x%08h sampled_addr=0x%02h rx=0x%08h ack_seq=%s",
                  data_length, resp, dev_seq.sampled_addr, rx,
                  format_master_ack_sequence(dev_seq, data_length)), UVM_LOW)
  endtask

  virtual function void build_payload(int unsigned data_length, ref byte_queue_t read_data);
    read_data.delete();

    for (int unsigned i = 0; i < data_length; i++) begin
      read_data.push_back(8'(8'h82 + i));
    end
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
