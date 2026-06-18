class i2c_broadcast_addr_enable_ignored_vseq extends i3c_base_vseq;
  `uvm_object_utils(i2c_broadcast_addr_enable_ignored_vseq)

  localparam bit [6:0] I2C_STATIC_ADDR = 7'h50;
  localparam bit [6:0] I3C_DYNAMIC_ADDR = 7'h08;
  localparam int unsigned I2C_DEV_IDX = 0;
  localparam int unsigned DATA_LENGTH = 4;

  function new(string name = "i2c_broadcast_addr_enable_ignored_vseq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] hc_control;

    enable_dut(1'b1);
    reg_read(ADDR_HC_CONTROL, hc_control);
    `DV_CHECK_EQ(hc_control[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT], 1'b1,
                 "I2C_003 setup: BROADCAST_ADDR_ENABLE should be set")

    write_dat_entry(I2C_DEV_IDX, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b1);

    run_i2c_write_case();
    run_i2c_read_case();

    `uvm_info(
        `gfn,
        "I2C_003 conclusion: legacy I2C transfers ignore BROADCAST_ADDR_ENABLE and start with the DAT static address",
        UVM_LOW)
  endtask

  virtual task run_i2c_write_case();
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    build_write_payload(exp_data, tx_words);

    cfg = make_transfer_cfg(
        .ctxt("I2C_003 write"),
        .seq_name("i2c003_write_dev_seq"),
        .tid(4'd1),
        .dev_idx(I2C_DEV_IDX[4:0]),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b1),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    check_i2c_address_phase(dev_seq, cfg, 1'b0);
    check_sampled_write_data(dev_seq, exp_data, DATA_LENGTH, cfg.ctxt);
    check_all_queues_empty("after I2C_003 write");

    `uvm_info(
        `gfn,
        $sformatf(
            "I2C_003 write result: resp=0x%08h sampled_addr=0x%02h bcast_hdr=%0b bcast_rstart=%0b",
            resp, dev_seq.sampled_addr, dev_seq.observed_broadcast_header,
            dev_seq.observed_broadcast_rstart), UVM_LOW)
  endtask

  virtual task run_i2c_read_case();
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    bit                     [31:0] rx;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    build_read_payload(read_data);

    cfg = make_transfer_cfg(
        .ctxt("I2C_003 read"),
        .seq_name("i2c003_read_dev_seq"),
        .tid(4'd2),
        .dev_idx(I2C_DEV_IDX[4:0]),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b1),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    run_read_stimulus(cfg, read_data, rx, resp, dev_seq);

    check_i2c_address_phase(dev_seq, cfg, 1'b1);
    `DV_CHECK_EQ(rx, pack_bytes_to_word(read_data), $sformatf("%s: RX data word mismatch",
                                                              cfg.ctxt))
    check_master_ack_sequence(dev_seq, cfg.ctxt);
    check_all_queues_empty("after I2C_003 read");

    `uvm_info(
        `gfn,
        $sformatf(
            "I2C_003 read result: resp=0x%08h sampled_addr=0x%02h rx=0x%08h bcast_hdr=%0b bcast_rstart=%0b ack_seq=%s",
            resp, dev_seq.sampled_addr, rx, dev_seq.observed_broadcast_header,
            dev_seq.observed_broadcast_rstart, format_master_ack_sequence(dev_seq)), UVM_LOW)
  endtask

  virtual function void build_write_payload(ref byte_queue_t exp_data, ref word_queue_t tx_words);
    exp_data.delete();
    tx_words.delete();

    for (int unsigned i = 0; i < DATA_LENGTH; i++) begin
      exp_data.push_back(8'(8'ha0 + i));
    end

    pack_payload_words(exp_data, tx_words);
  endfunction

  virtual function void build_read_payload(ref byte_queue_t read_data);
    read_data.delete();

    for (int unsigned i = 0; i < DATA_LENGTH; i++) begin
      read_data.push_back(8'(8'hb0 + i));
    end
  endfunction

  virtual task check_i2c_address_phase(i3c_device_response_seq dev_seq, transfer_stimulus_cfg_t cfg,
                                       bit exp_dir);
    `DV_CHECK_EQ(cfg.start_with_broadcast_header, 1'b0,
                 $sformatf("%s: I2C cfg should mask broadcast-header preamble", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.observed_broadcast_header, 1'b0,
                 $sformatf("%s: I2C transfer should not emit 0x7e preamble", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.observed_broadcast_rstart, 1'b0,
                 $sformatf("%s: I2C transfer should not emit broadcast repeated-start", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.sampled_addr, I2C_STATIC_ADDR,
                 $sformatf("%s: sampled static address mismatch", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.sampled_dir, exp_dir, $sformatf("%s: sampled direction mismatch",
                                                         cfg.ctxt))
  endtask

  virtual function string format_master_ack_sequence(i3c_device_response_seq dev_seq);
    string s;

    s = "[";
    for (int unsigned i = 0; i < DATA_LENGTH; i++) begin
      if (i > 0) s = {s, " "};
      if (i < dev_seq.sampled_t_bit.size()) begin
        s = {s, dev_seq.sampled_t_bit[i] ? "ACK" : "NACK"};
      end else begin
        s = {s, "MISSING"};
      end
    end
    return {s, "]"};
  endfunction

  virtual task check_master_ack_sequence(i3c_device_response_seq dev_seq, string ctxt);
    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), DATA_LENGTH,
                 $sformatf("%s: sampled master ACK/NACK count mismatch", ctxt))
    for (int unsigned i = 0; i < DATA_LENGTH; i++) begin
      if (i < dev_seq.sampled_t_bit.size()) begin
        bit exp_ack;

        exp_ack = (i < (DATA_LENGTH - 1));
        `DV_CHECK_EQ(dev_seq.sampled_t_bit[i], exp_ack,
                     $sformatf("%s: sampled master ACK/NACK byte[%0d] mismatch", ctxt, i))
      end
    end
  endtask

endclass
