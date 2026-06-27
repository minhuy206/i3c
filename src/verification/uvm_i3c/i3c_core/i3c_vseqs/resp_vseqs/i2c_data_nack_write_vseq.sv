class i2c_data_nack_write_vseq extends i3c_base_vseq;
  `uvm_object_utils(i2c_data_nack_write_vseq)

  localparam bit [6:0] I2C_STATIC_ADDR = 7'h50;
  localparam bit [6:0] I3C_DYNAMIC_ADDR = 7'h08;
  localparam int unsigned I2C_DEV_IDX = 0;
  localparam int unsigned DATA_LENGTH = 5;
  localparam int unsigned RECOVERY_LENGTH = 4;

  function new(string name = "i2c_data_nack_write_vseq");
    super.new(name);
  endfunction

  task body();
    enable_dut(1'b0);
    write_dat_entry(I2C_DEV_IDX, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b1);

    run_data_nack_case(.nack_byte_idx(0), .tid(4'd6), .case_name("first"));
    reset_after_data_nack(.nack_byte_idx(0));

    run_data_nack_case(.nack_byte_idx(2), .tid(4'd7), .case_name("middle"));
    reset_after_data_nack(.nack_byte_idx(2));

    run_data_nack_case(.nack_byte_idx(DATA_LENGTH - 1), .tid(4'd8), .case_name("final"));
    reset_after_data_nack(.nack_byte_idx(DATA_LENGTH - 1));

    run_recovery_write_case();

    `uvm_info(
        `gfn,
        "ERR_004 conclusion: legacy I2C write stops on first/middle data-byte NACK, reports final-byte data NACK, and accepts a following legal write",
        UVM_LOW)
  endtask

  virtual task run_data_nack_case(int unsigned nack_byte_idx, bit [3:0] tid, string case_name);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                            data_ack_pattern[$];
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    build_payload(DATA_LENGTH, exp_data, tx_words);
    build_data_ack_pattern(DATA_LENGTH, nack_byte_idx, data_ack_pattern);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_004 %s data NACK byte %0d", case_name, nack_byte_idx)),
        .seq_name($sformatf("err004_%s_data_nack_dev_seq", case_name)),
        .tid(tid),
        .dev_idx(I2C_DEV_IDX[4:0]),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    run_patterned_write_stimulus(cfg, tx_words, data_ack_pattern, resp, dev_seq);
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), nack_byte_idx + 1,
                 $sformatf("ERR_004 %s data NACK sampled byte boundary", case_name))

    `uvm_info(`gfn,
              $sformatf(
                  "ERR_004 %s data NACK result: resp=0x%08h sampled_addr=0x%02h sampled_bytes=%0d",
                  case_name, resp, dev_seq.sampled_addr, dev_seq.sampled_data.size()), UVM_LOW)
  endtask

  virtual task reset_after_data_nack(int unsigned nack_byte_idx);
    if ((nack_byte_idx + 1) < DATA_LENGTH) begin
      `DV_CHECK_GT(hdl_read_fifo_depth(tx_paths.depth_path), 0,
                   "ERR_004 non-final data NACK should preserve unfetched TX FIFO data")
    end
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty($sformatf("after ERR_004 data NACK byte %0d recovery SW reset",
                                     nack_byte_idx));
  endtask

  virtual task run_recovery_write_case();
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    build_payload(RECOVERY_LENGTH, exp_data, tx_words);

    cfg = make_transfer_cfg(
        .ctxt("ERR_004 recovery write"),
        .seq_name("err004_recovery_dev_seq"),
        .tid(4'd9),
        .dev_idx(I2C_DEV_IDX[4:0]),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(RECOVERY_LENGTH),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    check_all_queues_empty("after ERR_004 recovery write");

    `uvm_info(`gfn, $sformatf("ERR_004 recovery result: resp=0x%08h sampled_bytes=%0d", resp,
                              dev_seq.sampled_data.size()), UVM_LOW)
  endtask

  virtual task run_patterned_write_stimulus(transfer_stimulus_cfg_t cfg, word_queue_t tx_words,
                                            bit data_ack_pattern[$], output bit [31:0] resp,
                                            output i3c_device_response_seq dev_seq);
    start_patterned_device_response(cfg, data_ack_pattern, dev_seq);
    if (cfg.settle_before_cmd != 0) settle_cycles(cfg.settle_before_cmd);

    if (cfg.tx_before_cmd) begin
      write_tx_words(tx_words);
      write_write_cmd(cfg);
    end else begin
      write_write_cmd(cfg);
      write_tx_words(tx_words);
    end

    poll_idle();
    if (cfg.wait_device_done) begin
      wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    end
    read_response(resp);
  endtask

  virtual task start_patterned_device_response(transfer_stimulus_cfg_t cfg, bit data_ack_pattern[$],
                                               output i3c_device_response_seq dev_seq);
    byte_queue_t no_read_data;

    dev_seq                             = i3c_device_response_seq::type_id::create(cfg.seq_name);
    dev_seq.target_addr                 = cfg.target_addr;
    dev_seq.ack_address                 = cfg.ack_address;
    dev_seq.ack_data                    = cfg.ack_data;
    dev_seq.is_i3c                      = cfg.is_i3c;
    dev_seq.dir                         = 1'b0;
    dev_seq.start_with_broadcast_header = cfg.start_with_broadcast_header;
    dev_seq.read_data_cnt               = cfg.data_length;
    dev_seq.read_data                   = no_read_data;
    dev_seq.data_ack_pattern            = data_ack_pattern;

    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none
  endtask

  virtual function void build_payload(int unsigned data_length, ref byte_queue_t exp_data,
                                      ref word_queue_t tx_words);
    build_random_tx_words(data_length, exp_data, tx_words);
  endfunction

  virtual function void build_data_ack_pattern(int unsigned data_length,
                                               int unsigned nack_byte_idx,
                                               ref bit data_ack_pattern[$]);
    data_ack_pattern.delete();

    for (int unsigned i = 0; i < data_length; i++) begin
      data_ack_pattern.push_back(i != nack_byte_idx);
    end
  endfunction

endclass
