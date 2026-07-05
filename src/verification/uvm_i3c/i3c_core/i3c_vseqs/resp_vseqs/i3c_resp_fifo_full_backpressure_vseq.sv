class i3c_resp_fifo_full_backpressure_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_resp_fifo_full_backpressure_vseq)

  localparam int unsigned RespFifoDepth = 8;
  localparam bit [3:0] FSM_WRITE_RESP = 4'd12;
  localparam bit [6:0] I3cAddr = 7'h08;

  bit [31:0] prefill_words[RespFifoDepth];

  function new(string name = "i3c_resp_fifo_full_backpressure_vseq");
    super.new(name);
  endfunction

  virtual task body();
    run_success_backpressure_case();
    run_error_backpressure_case();
  endtask

  virtual function transfer_stimulus_cfg_t make_write_cfg(string ctxt, string seq_name,
                                                           bit [3:0] tid,
                                                           bit addr_nack = 1'b0);
    return make_transfer_cfg(
        .ctxt(ctxt),
        .seq_name(seq_name),
        .tid(tid),
        .dev_idx(5'd0),
        .target_addr(I3cAddr),
        .is_i3c(1'b1),
        .addr_nack(addr_nack),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
  endfunction

  virtual task configure_target();
    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, I3cAddr, 1'b0);
  endtask

  virtual function bit [31:0] make_prefill_word(bit [7:0] case_tag, int unsigned index);
    i3c_response_desc_t desc;

    desc             = '0;
    desc.err_status  = Success;
    desc.tid         = index[3:0];
    desc.data_length = {case_tag, index[7:0]};
    return desc;
  endfunction

  virtual task prefill_resp_fifo(bit [7:0] case_tag, string ctxt);
    for (int unsigned i = 0; i < RespFifoDepth; i++) begin
      prefill_words[i] = make_prefill_word(case_tag, i);
      backdoor_write_fifo_entry(resp_paths, i, prefill_words[i]);
    end
    backdoor_set_fifo_level(resp_paths, RespFifoDepth);
    settle_cycles();

    `DV_CHECK_EQ(hdl_read_fifo_depth(resp_paths.depth_path), RespFifoDepth,
                 $sformatf("%s: RESP FIFO depth mismatch after prefill", ctxt))
    check_queue_flags(resp_paths.name, resp_paths.full_bit, resp_paths.empty_bit, 1'b1, 1'b0,
                      $sformatf("%s after prefill", ctxt));
  endtask

  virtual task verify_response_stalled(bit [31:0] expected_resp, string ctxt);
    bit [31:0] mem_before[RespFifoDepth];
    bit [31:0] rptr_before;
    bit [31:0] wptr_before;
    int unsigned depth_before;

    rptr_before  = hdl_read_word(resp_paths.rptr_path);
    wptr_before  = hdl_read_word(resp_paths.wptr_path);
    depth_before = hdl_read_fifo_depth(resp_paths.depth_path);
    for (int unsigned i = 0; i < RespFifoDepth; i++) begin
      mem_before[i] = hdl_read_word(fifo_mem_path(resp_paths, i));
    end

    repeat (8) begin
      `DV_CHECK_EQ(hdl_read_uint_lsb(FLOW_FSM_STATE_PATH, 4), FSM_WRITE_RESP,
                   $sformatf("%s: FSM must remain in WriteResp while RESP is full", ctxt))
      `DV_CHECK_EQ(hdl_read_bit(resp_paths.write_valid_path), 1'b1,
                   $sformatf("%s: pending response valid must remain asserted", ctxt))
      `DV_CHECK_EQ(hdl_read_bit(resp_paths.write_ready_path), 1'b0,
                   $sformatf("%s: RESP write-ready must remain low while full", ctxt))
      `DV_CHECK_EQ(hdl_read_word(resp_paths.write_data_path), expected_resp,
                   $sformatf("%s: pending response changed under backpressure", ctxt))
      `DV_CHECK_EQ(hdl_read_word(resp_paths.rptr_path), rptr_before,
                   $sformatf("%s: RESP read pointer changed while stalled", ctxt))
      `DV_CHECK_EQ(hdl_read_word(resp_paths.wptr_path), wptr_before,
                   $sformatf("%s: RESP write pointer changed while stalled", ctxt))
      `DV_CHECK_EQ(hdl_read_fifo_depth(resp_paths.depth_path), depth_before,
                   $sformatf("%s: RESP depth changed while stalled", ctxt))
      for (int unsigned i = 0; i < RespFifoDepth; i++) begin
        `DV_CHECK_EQ(hdl_read_word(fifo_mem_path(resp_paths, i)), mem_before[i],
                     $sformatf("%s: RESP entry %0d overwritten while stalled", ctxt, i))
      end
      settle_cycles(1);
    end
  endtask

  virtual task release_and_check_response(bit [31:0] expected_resp, string ctxt);
    bit [31:0] observed;

    read_response(observed);
    `DV_CHECK_EQ(observed, prefill_words[0],
                 $sformatf("%s: first prefilled response changed", ctxt))

    poll_idle();
    check_queue_flags(resp_paths.name, resp_paths.full_bit, resp_paths.empty_bit, 1'b1, 1'b0,
                      $sformatf("%s after one pop and pending-response write", ctxt));
    `DV_CHECK_EQ(hdl_read_fifo_depth(resp_paths.depth_path), RespFifoDepth,
                 $sformatf("%s: one pop must release exactly one pending write", ctxt))

    for (int unsigned i = 1; i < RespFifoDepth; i++) begin
      read_response(observed);
      `DV_CHECK_EQ(observed, prefill_words[i],
                   $sformatf("%s: prefilled response %0d changed", ctxt, i))
    end

    read_response(observed);
    `DV_CHECK_EQ(observed, expected_resp,
                 $sformatf("%s: released response mismatch or duplicate ordering", ctxt))
    settle_cycles();
    `DV_CHECK_EQ(hdl_read_fifo_depth(resp_paths.depth_path), 0,
                 $sformatf("%s: RESP FIFO must contain no duplicate response", ctxt))
    check_queue_flags(resp_paths.name, resp_paths.full_bit, resp_paths.empty_bit, 1'b0, 1'b1,
                      $sformatf("%s after complete drain", ctxt));
  endtask

  virtual task run_success_backpressure_case();
    transfer_stimulus_cfg_t cfg;
    regular_trans_desc_t    cmd;
    i3c_response_desc_t     expected_desc;
    byte_queue_t            no_read_data;
    byte_queue_t            exp_data;
    word_queue_t            tx_words;
    i3c_device_response_seq dev_seq;

    configure_target();
    prefill_resp_fifo(8'h81, "ERR_008 wroc=1 success");

    cfg = make_write_cfg("ERR_008 wroc=1 success", "err008_success_dev_seq", 4'h8);
    cmd = build_regular_transfer_cmd(cfg, 1'b0, 1'b1);
    cmd.wroc = 1'b1;

    expected_desc             = '0;
    expected_desc.err_status  = Success;
    expected_desc.tid         = cmd.tid;
    expected_desc.data_length = cmd.data_length;

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    build_random_tx_words(cfg.data_length, exp_data, tx_words);
    write_tx_words(tx_words);
    write_cmd(cmd[31:0], cmd[63:32]);
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    wait_for_flow_fsm_state(FSM_WRITE_RESP, cfg.ctxt, device_done_timeout_cycles(cfg));

    verify_response_stalled(expected_desc, cfg.ctxt);
    release_and_check_response(expected_desc, cfg.ctxt);
    check_all_queues_empty("after ERR_008 wroc=1 success backpressure");
  endtask

  virtual task run_error_backpressure_case();
    transfer_stimulus_cfg_t     cfg;
    immediate_data_trans_desc_t cmd;
    i3c_response_desc_t         expected_desc;
    byte_queue_t                no_read_data;
    byte_queue_t                random_data;
    i3c_device_response_seq     dev_seq;

    configure_target();
    prefill_resp_fifo(8'h82, "ERR_008 wroc=0 error override");

    cfg                   = make_write_cfg("ERR_008 wroc=0 error override",
                                           "err008_error_dev_seq", 4'h9, 1'b1);
    cmd                   = '0;
    cmd.attr              = ImmediateDataTransfer;
    cmd.tid               = cfg.tid;
    cmd.mode              = sdr0;
    cmd.dev_idx           = 5'd0;
    cmd.toc               = 1'b1;
    cmd.wroc              = 1'b0;
    randomize_immediate_write_data(cfg.data_length, cmd, random_data);

    expected_desc             = '0;
    expected_desc.err_status  = AddrHeader;
    expected_desc.tid         = cmd.tid;
    expected_desc.data_length = 16'd0;

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(cmd[31:0], cmd[63:32]);
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    wait_for_flow_fsm_state(FSM_WRITE_RESP, cfg.ctxt, device_done_timeout_cycles(cfg));

    verify_response_stalled(expected_desc, cfg.ctxt);
    release_and_check_response(expected_desc, cfg.ctxt);
    check_all_queues_empty("after ERR_008 wroc=0 error backpressure");
  endtask

endclass
