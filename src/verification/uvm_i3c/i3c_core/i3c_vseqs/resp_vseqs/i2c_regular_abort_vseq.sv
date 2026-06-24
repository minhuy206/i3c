class i2c_regular_abort_vseq extends i3c_base_vseq;
  `uvm_object_utils(i2c_regular_abort_vseq)

  localparam bit [6:0] I2C_STATIC_ADDR = 7'h50;
  localparam bit [6:0] I3C_DYNAMIC_ADDR = 7'h08;
  localparam int unsigned I2C_DEV_IDX = 0;
  localparam int unsigned DATA_LENGTH = 8;
  localparam int unsigned DATA_LENGTH_DEEP = 16;

  localparam bit [3:0] FSM_FETCH_TX_DATA = 4'd7;
  localparam bit [3:0] FSM_ISSUE_CMD = 4'd12;

  function new(string name = "i2c_regular_abort_vseq");
    super.new(name);
  endfunction

  task body();
    run_i2c_write_abort_early_case();
    run_i2c_write_abort_deep_case();
    run_i2c_write_abort_toc_zero_case();
    run_i2c_read_abort_early_case();
    run_i2c_read_abort_deep_case();
    run_i2c_read_abort_toc_zero_case();

    `uvm_info(
        `gfn,
        "ERR_007 conclusion: legacy I2C RegularTransfer write/read abort preserves pre-abort data and SW reset flushes residual queues",
        UVM_LOW)
  endtask

  virtual task run_i2c_write_abort_early_case();
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            exp_data;
    byte_queue_t            no_read_data;
    word_queue_t            tx_words;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;
    int unsigned            tx_depth;

    build_payload_words(8'h40, DATA_LENGTH, exp_data, tx_words);
    setup_i2c_target();

    cfg = make_transfer_cfg(
        .ctxt("ERR_007 write early abort"),
        .seq_name("i2c006_write_early_dev_seq"),
        .tid(4'd6),
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

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    settle_cycles(cfg.settle_before_cmd);
    write_tx_words(tx_words);
    write_write_cmd(cfg, .toc(1'b1));

    wait_for_flow_fsm_state(FSM_FETCH_TX_DATA, cfg.ctxt, device_done_timeout_cycles(cfg));
    tx_depth = hdl_read_fifo_depth(tx_paths.depth_path);
    `DV_CHECK_EQ(tx_depth, tx_words.size(),
                 $sformatf("%s: early abort should fire before TX FIFO word consumption",
                           cfg.ctxt))
    assert_hc_abort();

    finish_write_abort_case(cfg, exp_data, resp, dev_seq, "early_abort");

    `uvm_info(`gfn, $sformatf(
                  "ERR_007 write result: case=early_abort resp=0x%08h sampled_bytes=%0d tx_depth_before_abort=%0d",
                  resp, dev_seq.sampled_data.size(), tx_depth), UVM_LOW)
  endtask

  virtual task run_i2c_write_abort_deep_case();
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            exp_data;
    byte_queue_t            no_read_data;
    word_queue_t            tx_words;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;
    int unsigned            tx_depth;

    build_payload_words(8'h60, DATA_LENGTH_DEEP, exp_data, tx_words);
    setup_i2c_target();

    cfg = make_transfer_cfg(
        .ctxt("ERR_007 write deep abort"),
        .seq_name("i2c006_write_deep_dev_seq"),
        .tid(4'd7),
        .dev_idx(I2C_DEV_IDX[4:0]),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(DATA_LENGTH_DEEP),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    settle_cycles(cfg.settle_before_cmd);
    write_tx_words(tx_words);
    write_write_cmd(cfg, .toc(1'b1));

    wait_for_tx_depth_below(tx_words.size(), tx_depth, cfg.ctxt);
    wait_for_flow_fsm_state(FSM_ISSUE_CMD, cfg.ctxt, device_done_timeout_cycles(cfg));
    assert_hc_abort();

    finish_write_abort_case(cfg, exp_data, resp, dev_seq, "deep_abort");

    `uvm_info(`gfn, $sformatf(
                  "ERR_007 write result: case=deep_abort resp=0x%08h sampled_bytes=%0d tx_depth_before_abort=%0d",
                  resp, dev_seq.sampled_data.size(), tx_depth), UVM_LOW)
  endtask

  virtual task run_i2c_write_abort_toc_zero_case();
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            exp_data;
    byte_queue_t            no_read_data;
    word_queue_t            tx_words;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;

    build_payload_words(8'h80, DATA_LENGTH, exp_data, tx_words);
    setup_i2c_target();

    cfg = make_transfer_cfg(
        .ctxt("ERR_007 write toc0 abort"),
        .seq_name("i2c006_write_toc0_dev_seq"),
        .tid(4'd8),
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

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    settle_cycles(cfg.settle_before_cmd);
    write_tx_words(tx_words);
    write_write_cmd(cfg, .toc(1'b0));

    wait_for_flow_fsm_state(FSM_ISSUE_CMD, cfg.ctxt, device_done_timeout_cycles(cfg));
    assert_hc_abort();

    finish_write_abort_case(cfg, exp_data, resp, dev_seq, "toc0_abort");
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b0,
                 "ERR_007 write toc0 abort must end with STOP, not continuation RSTART")

    `uvm_info(`gfn, $sformatf(
                  "ERR_007 write result: case=toc0_abort resp=0x%08h sampled_bytes=%0d observed_rstart=%0b",
                  resp, dev_seq.sampled_data.size(), dev_seq.observed_rstart), UVM_LOW)
  endtask

  virtual task run_i2c_read_abort_early_case();
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;
    int unsigned            rx_depth;

    build_payload(8'ha0, DATA_LENGTH, read_data);
    setup_i2c_target();

    cfg = make_transfer_cfg(
        .ctxt("ERR_007 read early abort"),
        .seq_name("i2c006_read_early_dev_seq"),
        .tid(4'd9),
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

    start_device_response(cfg, 1'b1, read_data, dev_seq);
    settle_cycles(cfg.settle_before_cmd);
    write_read_cmd(cfg, .toc(1'b1));

    wait_for_flow_fsm_state(FSM_ISSUE_CMD, cfg.ctxt, device_done_timeout_cycles(cfg));
    rx_depth = hdl_read_fifo_depth(rx_paths.depth_path);
    `DV_CHECK_EQ(rx_depth, 0, $sformatf(
                 "%s: early abort should fire before RX FIFO commit", cfg.ctxt))
    assert_hc_abort();

    finish_read_abort_case(cfg, read_data, resp, dev_seq, "early_abort");

    `uvm_info(`gfn, $sformatf(
                  "ERR_007 read result: case=early_abort resp=0x%08h resp_len=%0d rx_depth_before_abort=%0d observed_rstart=%0b",
                  resp, resp[15:0], rx_depth, dev_seq.observed_rstart), UVM_LOW)
  endtask

  virtual task run_i2c_read_abort_deep_case();
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;
    int unsigned            rx_depth;

    build_payload(8'hc0, DATA_LENGTH_DEEP, read_data);
    setup_i2c_target();

    cfg = make_transfer_cfg(
        .ctxt("ERR_007 read deep abort"),
        .seq_name("i2c006_read_deep_dev_seq"),
        .tid(4'd10),
        .dev_idx(I2C_DEV_IDX[4:0]),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(DATA_LENGTH_DEEP),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b1, read_data, dev_seq);
    settle_cycles(cfg.settle_before_cmd);
    write_read_cmd(cfg, .toc(1'b1));

    wait_for_rx_depth_at_least(1, rx_depth, cfg.ctxt);
    assert_hc_abort();

    finish_read_abort_case(cfg, read_data, resp, dev_seq, "deep_abort");

    `uvm_info(`gfn, $sformatf(
                  "ERR_007 read result: case=deep_abort resp=0x%08h resp_len=%0d rx_depth_before_abort=%0d observed_rstart=%0b",
                  resp, resp[15:0], rx_depth, dev_seq.observed_rstart), UVM_LOW)
  endtask

  virtual task run_i2c_read_abort_toc_zero_case();
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;

    build_payload(8'he0, DATA_LENGTH, read_data);
    setup_i2c_target();

    cfg = make_transfer_cfg(
        .ctxt("ERR_007 read toc0 abort"),
        .seq_name("i2c006_read_toc0_dev_seq"),
        .tid(4'd11),
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

    start_device_response(cfg, 1'b1, read_data, dev_seq);
    settle_cycles(cfg.settle_before_cmd);
    write_read_cmd(cfg, .toc(1'b0));

    wait_for_flow_fsm_state(FSM_ISSUE_CMD, cfg.ctxt, device_done_timeout_cycles(cfg));
    assert_hc_abort();

    finish_read_abort_case(cfg, read_data, resp, dev_seq, "toc0_abort");

    `uvm_info(`gfn, $sformatf(
                  "ERR_007 read result: case=toc0_abort resp=0x%08h resp_len=%0d observed_rstart=%0b",
                  resp, resp[15:0], dev_seq.observed_rstart), UVM_LOW)
  endtask

  virtual task finish_write_abort_case(transfer_stimulus_cfg_t cfg, byte_queue_t exp_data,
                                       output bit [31:0] resp,
                                       input i3c_device_response_seq dev_seq,
                                       string case_name);
    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    clear_hc_abort();
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty($sformatf("after ERR_007 %s", case_name));
  endtask

  virtual task finish_read_abort_case(transfer_stimulus_cfg_t cfg, byte_queue_t read_data,
                                      output bit [31:0] resp,
                                      input i3c_device_response_seq dev_seq,
                                      string case_name);
    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    drain_read_abort_rx(resp);

    clear_hc_abort();
    check_all_queues_empty($sformatf("before ERR_007 %s read recovery transfer", case_name));
    run_read_recovery_case(case_name);
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty($sformatf("after ERR_007 %s", case_name));
  endtask

  virtual task run_read_recovery_case(string case_name);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    word_queue_t            rx_words;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;

    read_data.push_back(8'h5A);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_007 %s read recovery without SW reset", case_name)),
        .seq_name($sformatf("i2c006_%s_read_recovery_dev_seq", case_name)),
        .tid(4'hE),
        .dev_idx(I2C_DEV_IDX[4:0]),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(read_data.size()),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );

    run_read_stimulus_words(cfg, read_data, rx_words, resp, dev_seq);

    check_all_queues_empty(cfg.ctxt);
  endtask

  virtual task assert_hc_abort();
    reg_write(ADDR_HC_CONTROL, {28'h0, 1'b1 /*HC_ABORT*/, 1'b0 /*BCAST_EN*/,
                                1'b0 /*SW_RST*/, 1'b1 /*EN*/});
  endtask

  virtual task clear_hc_abort();
    reg_write(ADDR_HC_CONTROL, {28'h0, 1'b0 /*HC_ABORT*/, 1'b0 /*BCAST_EN*/,
                                1'b0 /*SW_RST*/, 1'b1 /*EN*/});
  endtask

  virtual task setup_i2c_target();
    enable_dut(1'b0);
    write_dat_entry(I2C_DEV_IDX, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b1);
  endtask

  virtual function void build_payload(bit [7:0] base_byte, int unsigned data_length,
                                      ref byte_queue_t data);
    data.delete();
    for (int unsigned i = 0; i < data_length; i++) begin
      data.push_back(8'(base_byte + i));
    end
  endfunction

  virtual function void build_payload_words(bit [7:0] base_byte, int unsigned data_length,
                                            ref byte_queue_t data, ref word_queue_t words);
    build_payload(base_byte, data_length, data);
    pack_payload_words(data, words);
  endfunction

  virtual task wait_for_tx_depth_below(int unsigned initial_depth, output int unsigned tx_depth,
                                       string ctxt);
    int unsigned timeout;

    timeout = i2c_device_done_timeout_cycles(DATA_LENGTH_DEEP);
    for (int i = 0; i < timeout; i++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      tx_depth = hdl_read_fifo_depth(tx_paths.depth_path);
      if (tx_depth < initial_depth) return;
    end
    `uvm_error(`gfn, $sformatf("%s: TX FIFO depth did not drop before timeout", ctxt))
  endtask

  virtual task wait_for_rx_depth_at_least(int unsigned exp_depth, output int unsigned rx_depth,
                                          string ctxt);
    int unsigned timeout;

    timeout = i2c_device_done_timeout_cycles(DATA_LENGTH_DEEP);
    for (int i = 0; i < timeout; i++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      rx_depth = hdl_read_fifo_depth(rx_paths.depth_path);
      if (rx_depth >= exp_depth) return;
    end
    `uvm_error(`gfn, $sformatf("%s: RX FIFO depth did not reach %0d before timeout", ctxt,
                               exp_depth))
  endtask

  virtual task drain_read_abort_rx(bit [31:0] resp);
    int unsigned committed_len;
    word_queue_t rx_words;

    committed_len = int'(resp[15:0]);
    read_rx_words(committed_len, rx_words);
  endtask

endclass
