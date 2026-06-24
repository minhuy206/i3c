class i2c_regular_abort_vseq extends i3c_base_vseq;
  `uvm_object_utils(i2c_regular_abort_vseq)

  localparam bit [6:0] I2C_STATIC_ADDR = 7'h50;
  localparam bit [6:0] I3C_DYNAMIC_ADDR = 7'h08;
  localparam bit [3:0] RESP_HC_ABORTED = 4'h8;
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
        "I2C_006 conclusion: legacy I2C RegularTransfer write/read abort preserves pre-abort data and SW reset flushes residual queues",
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
        .ctxt("I2C_006 write early abort"),
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
                  "I2C_006 write result: case=early_abort resp=0x%08h sampled_bytes=%0d tx_depth_before_abort=%0d",
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
        .ctxt("I2C_006 write deep abort"),
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
                  "I2C_006 write result: case=deep_abort resp=0x%08h sampled_bytes=%0d tx_depth_before_abort=%0d",
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
        .ctxt("I2C_006 write toc0 abort"),
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
                 "I2C_006 write toc0 abort must end with STOP, not continuation RSTART")

    `uvm_info(`gfn, $sformatf(
                  "I2C_006 write result: case=toc0_abort resp=0x%08h sampled_bytes=%0d observed_rstart=%0b",
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
        .ctxt("I2C_006 read early abort"),
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
                  "I2C_006 read result: case=early_abort resp=0x%08h resp_len=%0d rx_depth_before_abort=%0d observed_rstart=%0b",
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
        .ctxt("I2C_006 read deep abort"),
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
                  "I2C_006 read result: case=deep_abort resp=0x%08h resp_len=%0d rx_depth_before_abort=%0d observed_rstart=%0b",
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
        .ctxt("I2C_006 read toc0 abort"),
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
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b0,
                 "I2C_006 read toc0 abort must end with STOP, not continuation RSTART")

    `uvm_info(`gfn, $sformatf(
                  "I2C_006 read result: case=toc0_abort resp=0x%08h resp_len=%0d observed_rstart=%0b",
                  resp, resp[15:0], dev_seq.observed_rstart), UVM_LOW)
  endtask

  virtual task finish_write_abort_case(transfer_stimulus_cfg_t cfg, byte_queue_t exp_data,
                                       output bit [31:0] resp,
                                       input i3c_device_response_seq dev_seq,
                                       string case_name);
    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_i2c_address_phase(dev_seq, cfg, 1'b0);
    check_abort_resp(resp, cfg, dev_seq.sampled_data.size());
    check_write_prefix(dev_seq, exp_data, cfg.ctxt, case_name);

    clear_hc_abort();
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty($sformatf("after I2C_006 %s", case_name));
  endtask

  virtual task finish_read_abort_case(transfer_stimulus_cfg_t cfg, byte_queue_t read_data,
                                      output bit [31:0] resp,
                                      input i3c_device_response_seq dev_seq,
                                      string case_name);
    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_i2c_address_phase(dev_seq, cfg, 1'b1);
    check_abort_resp(resp, cfg, int'(resp[15:0]));
    check_read_prefix(resp, cfg, read_data, case_name);
    check_read_abort_nack(dev_seq, resp, cfg, case_name);
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b0,
                 $sformatf("%s: I2C abort must terminate with STOP", cfg.ctxt))

    clear_hc_abort();
    check_all_queues_empty($sformatf("before I2C_006 %s read recovery transfer", case_name));
    run_read_recovery_case(case_name);
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty($sformatf("after I2C_006 %s", case_name));
  endtask

  virtual task run_read_recovery_case(string case_name);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    word_queue_t            rx_words;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;

    read_data.push_back(8'h5A);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("I2C_006 %s read recovery without SW reset", case_name)),
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

    check_i2c_address_phase(dev_seq, cfg, 1'b1);
    `DV_CHECK_EQ(rx_words.size(), 1,
                 $sformatf("%s: recovery RX word count mismatch", cfg.ctxt))
    if (rx_words.size() > 0) begin
      `DV_CHECK_EQ(rx_words[0][7:0], read_data[0],
                   $sformatf("%s: recovery RX data mismatch", cfg.ctxt))
    end
    check_success_resp_fields(resp, cfg.tid, read_data.size(), cfg.ctxt);
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

  virtual task check_i2c_address_phase(i3c_device_response_seq dev_seq,
                                       transfer_stimulus_cfg_t cfg, bit exp_dir);
    `DV_CHECK_EQ(dev_seq.sampled_addr, I2C_STATIC_ADDR,
                 $sformatf("%s: sampled static address mismatch", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.sampled_dir, exp_dir,
                 $sformatf("%s: sampled direction mismatch", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.observed_broadcast_header, 1'b0,
                 $sformatf("%s: I2C transfer must not emit broadcast header", cfg.ctxt))
  endtask

  virtual task check_abort_resp(bit [31:0] resp, transfer_stimulus_cfg_t cfg,
                                int unsigned exp_length);
    check_error_resp_fields(resp, RESP_HC_ABORTED, cfg.tid, exp_length, cfg.ctxt);
    `DV_CHECK_LE(resp[15:0], cfg.data_length,
                 $sformatf("%s: abort response length must not exceed requested length",
                           cfg.ctxt))
  endtask

  virtual task check_write_prefix(i3c_device_response_seq dev_seq, byte_queue_t exp_data,
                                  string ctxt, string case_name);
    `DV_CHECK_LE(dev_seq.sampled_data.size(), exp_data.size(),
                 $sformatf("%s: %s sampled too many write bytes", ctxt, case_name))
    foreach (dev_seq.sampled_data[i]) begin
      if (i < exp_data.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_data[i], exp_data[i],
                     $sformatf("%s: %s pre-abort write byte[%0d] mismatch", ctxt, case_name, i))
      end
    end
    foreach (dev_seq.sampled_t_bit[i]) begin
      `DV_CHECK_EQ(dev_seq.sampled_t_bit[i], SampledAck,
                   $sformatf("%s: %s I2C write byte[%0d] should be ACKed", ctxt, case_name, i))
    end
  endtask

  virtual task check_read_abort_nack(i3c_device_response_seq dev_seq, bit [31:0] resp,
                                     transfer_stimulus_cfg_t cfg, string case_name);
    int unsigned committed_len;

    committed_len = int'(resp[15:0]);
    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), committed_len,
                 $sformatf("%s: %s sampled controller ACK/NACK count mismatch", cfg.ctxt,
                           case_name))
    foreach (dev_seq.sampled_t_bit[i]) begin
      sampled_ack_nack_e exp_ack;

      exp_ack = ((committed_len > 0) && (i < (committed_len - 1))) ? SampledAck : SampledNack;
      `DV_CHECK_EQ(dev_seq.sampled_t_bit[i], exp_ack,
                   $sformatf("%s: %s controller ACK/NACK byte[%0d] mismatch", cfg.ctxt,
                             case_name, i))
    end
  endtask

  virtual task check_read_prefix(bit [31:0] resp, transfer_stimulus_cfg_t cfg,
                                 byte_queue_t read_data, string case_name);
    int unsigned committed_len;
    byte_queue_t committed_data;
    word_queue_t exp_words;
    word_queue_t rx_words;

    committed_len = int'(resp[15:0]);
    `DV_CHECK_LE(committed_len, read_data.size(),
                 $sformatf("%s: committed read length exceeds provided device data", cfg.ctxt))

    committed_data.delete();
    for (int unsigned i = 0; i < committed_len; i++) begin
      committed_data.push_back(read_data[i]);
    end
    pack_payload_words(committed_data, exp_words);
    read_rx_words(committed_len, rx_words);

    `DV_CHECK_EQ(rx_words.size(), exp_words.size(),
                 $sformatf("%s: %s committed RX word count mismatch", cfg.ctxt, case_name))
    foreach (exp_words[i]) begin
      if (i < rx_words.size()) begin
        `DV_CHECK_EQ(rx_words[i], exp_words[i],
                     $sformatf("%s: %s committed RX word[%0d] mismatch", cfg.ctxt, case_name, i))
      end
    end
  endtask

endclass
