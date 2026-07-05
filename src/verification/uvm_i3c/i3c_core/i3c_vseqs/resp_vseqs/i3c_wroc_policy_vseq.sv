class i3c_wroc_policy_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_wroc_policy_vseq)

  localparam int unsigned RespFifoDepth = 8;
  localparam bit [6:0] I3cAddr = 7'h08;

  function new(string name = "i3c_wroc_policy_vseq");
    super.new(name);
  endfunction

  virtual task body();
    run_regular_success_case(1'b0, 4'h1);
    run_regular_success_case(1'b1, 4'h2);
    run_immediate_success_case(1'b0, 4'h3);
    run_immediate_success_case(1'b1, 4'h4);
    run_ccc_success_case(1'b0, 4'h5);
    run_ccc_success_case(1'b1, 4'h6);
    run_mixed_wroc_case();
    run_wroc0_continuation_with_resp_full_case();
    run_error_override_case();
  endtask

  virtual function transfer_stimulus_cfg_t make_write_cfg(string ctxt, string seq_name,
                                                           bit [3:0] tid,
                                                           int unsigned data_length = 2,
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
        .data_length(data_length),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
  endfunction

  virtual task configure_target();
    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, I3cAddr, 1'b0);
  endtask

  virtual task check_resp_empty(string ctxt);
    check_queue_flags(resp_paths.name, resp_paths.full_bit, resp_paths.empty_bit, 1'b0, 1'b1,
                      ctxt);
  endtask

  virtual task run_regular_success_case(bit wroc, bit [3:0] tid);
    transfer_stimulus_cfg_t cfg;
    regular_trans_desc_t    cmd;
    byte_queue_t            no_read_data;
    byte_queue_t            exp_data;
    word_queue_t            tx_words;
    i3c_device_response_seq dev_seq;
    bit [31:0]              resp;

    configure_target();
    cfg = make_write_cfg($sformatf("ERR_012 regular wroc=%0b", wroc),
                         $sformatf("err012_regular_wroc%0b_dev_seq", wroc), tid);
    cmd = build_regular_transfer_cmd(cfg, 1'b0, 1'b1);
    cmd.wroc = wroc;

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    build_random_tx_words(cfg.data_length, exp_data, tx_words);
    write_tx_words(tx_words);
    write_cmd(cmd[31:0], cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));

    if (wroc) begin
      read_response(resp);
    end else begin
      check_resp_empty("after successful regular wroc=0 command");
    end
    check_all_queues_empty($sformatf("after ERR_012 regular wroc=%0b", wroc));
  endtask

  virtual task run_immediate_success_case(bit wroc, bit [3:0] tid);
    transfer_stimulus_cfg_t     cfg;
    immediate_data_trans_desc_t cmd;
    byte_queue_t                no_read_data;
    byte_queue_t                random_data;
    i3c_device_response_seq     dev_seq;
    bit [31:0]                  resp;

    configure_target();
    cfg = make_write_cfg($sformatf("ERR_012 immediate wroc=%0b", wroc),
                         $sformatf("err012_immediate_wroc%0b_dev_seq", wroc), tid);
    cmd                   = '0;
    cmd.attr              = ImmediateDataTransfer;
    cmd.tid               = tid;
    cmd.mode              = sdr0;
    cmd.dev_idx           = 5'd0;
    cmd.toc               = 1'b1;
    cmd.wroc              = wroc;
    randomize_immediate_write_data(cfg.data_length, cmd, random_data);

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(cmd[31:0], cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));

    if (wroc) begin
      read_response(resp);
    end else begin
      check_resp_empty("after successful immediate wroc=0 command");
    end
    check_all_queues_empty($sformatf("after ERR_012 immediate wroc=%0b", wroc));
  endtask

  virtual task run_ccc_success_case(bit wroc, bit [3:0] tid);
    immediate_data_trans_desc_t cmd;
    i3c_device_response_seq     dev_seq;
    bit [31:0]                  resp;

    configure_target();
    cmd                   = '0;
    cmd.attr              = ImmediateDataTransfer;
    cmd.tid               = tid;
    cmd.cp                = 1'b1;
    cmd.cmd               = ENEC;
    cmd.mode              = sdr0;
    cmd.dtt               = 3'd4;
    cmd.dev_idx           = 5'd0;
    cmd.toc               = 1'b1;
    cmd.wroc              = wroc;
    cmd.def_or_data_byte1 = 8'h01;

    dev_seq             = i3c_device_response_seq::type_id::create(
        $sformatf("err012_ccc_wroc%0b_dev_seq", wroc));
    dev_seq.target_addr = 7'h7e;
    dev_seq.addr_nack = 1'b0;
    dev_seq.is_i3c      = 1'b1;
    dev_seq.dir         = 1'b0;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(cmd[31:0], cmd[63:32]);
    poll_idle();
    begin : wait_ccc_done
      int timeout = 10000;
      for (int i = 0; i < timeout; i++) begin
        if (dev_seq.done) break;
        @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      end
      `DV_CHECK_EQ(dev_seq.done, 1'b1, "ERR_012 CCC device response timed out")
    end

    if (wroc) begin
      read_response(resp);
    end else begin
      check_resp_empty("after successful immediate CCC wroc=0 command");
    end
    check_all_queues_empty($sformatf("after ERR_012 immediate CCC wroc=%0b", wroc));
  endtask

  virtual task run_mixed_wroc_case();
    transfer_stimulus_cfg_t cfg0;
    transfer_stimulus_cfg_t cfg1;
    regular_trans_desc_t    cmd0;
    regular_trans_desc_t    cmd1;
    byte_queue_t            no_read_data;
    byte_queue_t            exp_data0;
    byte_queue_t            exp_data1;
    word_queue_t            tx_words0;
    word_queue_t            tx_words1;
    i3c_device_response_seq dev_seq0;
    i3c_device_response_seq dev_seq1;
    i3c_response_desc_t     resp_desc;
    bit [31:0]              resp;

    configure_target();
    cfg0 = make_write_cfg("ERR_012 mixed first wroc=0", "err012_mixed_first_dev_seq", 4'h7);
    cfg1 = make_write_cfg("ERR_012 mixed second wroc=1", "err012_mixed_second_dev_seq", 4'h8);
    cmd0 = build_regular_transfer_cmd(cfg0, 1'b0, 1'b1);
    cmd1 = build_regular_transfer_cmd(cfg1, 1'b0, 1'b1);
    cmd0.wroc = 1'b0;
    cmd1.wroc = 1'b1;

    start_ordered_device_responses(cfg0, 1'b0, no_read_data, dev_seq0,
                                   cfg1, 1'b0, no_read_data, dev_seq1);
    build_random_tx_words(cfg0.data_length, exp_data0, tx_words0);
    build_random_tx_words(cfg1.data_length, exp_data1, tx_words1);
    write_tx_words(tx_words0);
    write_tx_words(tx_words1);
    write_cmd(cmd0[31:0], cmd0[63:32]);
    write_cmd(cmd1[31:0], cmd1[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    read_response(resp);
    resp_desc = i3c_response_desc_t'(resp);
    `DV_CHECK_EQ(resp_desc.tid, cmd1.tid,
                 "ERR_012 mixed case must contain only the wroc=1 response")
    check_all_queues_empty("after ERR_012 mixed WROC commands");
  endtask

  virtual task run_wroc0_continuation_with_resp_full_case();
    transfer_stimulus_cfg_t cfg0;
    transfer_stimulus_cfg_t cfg1;
    regular_trans_desc_t    cmd0;
    regular_trans_desc_t    cmd1;
    byte_queue_t            no_read_data;
    byte_queue_t            exp_data0;
    byte_queue_t            exp_data1;
    word_queue_t            tx_words0;
    word_queue_t            tx_words1;
    i3c_device_response_seq dev_seq0;
    i3c_device_response_seq dev_seq1;

    configure_target();
    for (int unsigned i = 0; i < RespFifoDepth; i++) begin
      backdoor_write_fifo_entry(resp_paths, i, 32'hF000_0000 | i);
    end
    backdoor_set_fifo_level(resp_paths, RespFifoDepth);
    check_queue_flags(resp_paths.name, resp_paths.full_bit, resp_paths.empty_bit, 1'b1, 1'b0,
                      "before ERR_012 wroc=0 full-RESP continuation");

    cfg0 = make_write_cfg("ERR_012 full RESP first toc=0 wroc=0",
                          "err012_full_resp_first_dev_seq", 4'h9);
    cfg1 = make_write_cfg("ERR_012 full RESP second toc=1 wroc=0",
                          "err012_full_resp_second_dev_seq", 4'hA);
    cmd0 = build_regular_transfer_cmd(cfg0, 1'b0, 1'b0);
    cmd1 = build_regular_transfer_cmd(cfg1, 1'b0, 1'b1);
    cmd0.wroc = 1'b0;
    cmd1.wroc = 1'b0;

    start_ordered_device_responses(cfg0, 1'b0, no_read_data, dev_seq0,
                                   cfg1, 1'b0, no_read_data, dev_seq1);
    build_random_tx_words(cfg0.data_length, exp_data0, tx_words0);
    build_random_tx_words(cfg1.data_length, exp_data1, tx_words1);
    write_tx_words(tx_words0);
    write_tx_words(tx_words1);
    write_cmd(cmd0[31:0], cmd0[63:32]);
    write_cmd(cmd1[31:0], cmd1[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));

    `DV_CHECK_EQ(dev_seq0.observed_rstart, 1'b1,
                 "ERR_012 wroc=0 toc=0 command must continue with RSTART")
    check_queue_flags(resp_paths.name, resp_paths.full_bit, resp_paths.empty_bit, 1'b1, 1'b0,
                      "after ERR_012 wroc=0 commands completed with RESP full");
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty("after ERR_012 full-RESP cleanup reset");
  endtask

  virtual task run_error_override_case();
    transfer_stimulus_cfg_t     cfg;
    immediate_data_trans_desc_t cmd;
    byte_queue_t                no_read_data;
    byte_queue_t                random_data;
    i3c_device_response_seq     dev_seq;
    i3c_response_desc_t         resp_desc;
    bit [31:0]                  resp;

    configure_target();
    cfg = make_write_cfg("ERR_012 wroc=0 address NACK override",
                         "err012_error_override_dev_seq", 4'hB, 2, 1'b1);
    cmd                   = '0;
    cmd.attr              = ImmediateDataTransfer;
    cmd.tid               = cfg.tid;
    cmd.mode              = sdr0;
    cmd.dev_idx           = 5'd0;
    cmd.toc               = 1'b1;
    cmd.wroc              = 1'b0;
    randomize_immediate_write_data(cfg.data_length, cmd, random_data);

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(cmd[31:0], cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);
    resp_desc = i3c_response_desc_t'(resp);
    `DV_CHECK_EQ(resp_desc.err_status, AddrHeader,
                 "ERR_012 wroc=0 error override must report AddrHeader")
    `DV_CHECK_EQ(resp_desc.tid, cmd.tid, "ERR_012 wroc=0 error override TID mismatch")
    check_all_queues_empty("after ERR_012 wroc=0 error override");
  endtask

endclass
