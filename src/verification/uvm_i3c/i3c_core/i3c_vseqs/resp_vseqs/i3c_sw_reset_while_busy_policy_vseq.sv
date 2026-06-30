class i3c_sw_reset_while_busy_policy_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_sw_reset_while_busy_policy_vseq)

  localparam string TX_FLOW_STATE_PATH = "tb_i3c_top.dut.u_ctrl.u_tx_flow.state_q";
  localparam string SW_RESET_PATH = "tb_i3c_top.dut.sw_reset";

  localparam bit [3:0] FSM_ISSUE_CMD = 4'd11;
  localparam bit [2:0] TX_DRIVE_BYTE = 3'd1;
  localparam bit [6:0] StaticAddr = 7'h50;
  localparam bit [6:0] DynamicAddr = 7'h08;

  function new(string name = "i3c_sw_reset_while_busy_policy_vseq");
    super.new(name);
  endfunction

  virtual task body();
    run_busy_sw_reset_noop_case();
  endtask

  virtual function transfer_stimulus_cfg_t make_write_cfg(string ctxt, string seq_name,
                                                           bit [3:0] tid,
                                                           int unsigned data_length);
    return make_transfer_cfg(
        .ctxt(ctxt),
        .seq_name(seq_name),
        .tid(tid),
        .dev_idx(5'd0),
        .target_addr(DynamicAddr),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(data_length),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
  endfunction

  virtual task run_busy_sw_reset_noop_case();
    transfer_stimulus_cfg_t cfg0;
    transfer_stimulus_cfg_t cfg1;
    transfer_stimulus_cfg_t cfg2;
    i3c_device_response_seq dev_seq0;
    i3c_device_response_seq dev_seq1;
    i3c_device_response_seq dev_seq2;
    byte_queue_t            no_read_data;
    word_queue_t            tx_words;
    bit              [31:0] status;
    bit              [31:0] resp0;
    bit              [31:0] resp1;
    bit              [31:0] resp2;

    disable_dut();
    write_dat_entry(0, StaticAddr, DynamicAddr, 1'b0);

    cfg0 = make_write_cfg("ERR_015 busy SOFT_RST write[0]", "err015_dev_seq0", 4'h1, 16);
    cfg1 = make_write_cfg("ERR_015 busy SOFT_RST write[1]", "err015_dev_seq1", 4'h2, 4);
    cfg2 = make_write_cfg("ERR_015 busy SOFT_RST write[2]", "err015_dev_seq2", 4'h3, 4);

    tx_words.push_back(32'h1312_1110);
    tx_words.push_back(32'h2322_2120);
    tx_words.push_back(32'h3332_3130);
    tx_words.push_back(32'h4342_4140);
    tx_words.push_back(32'h5352_5150);
    tx_words.push_back(32'h6362_6160);

    start_device_response(cfg0, 1'b0, no_read_data, dev_seq0);
    wait_for_device_request_issued(dev_seq0, cfg0.ctxt);
    start_device_response(cfg1, 1'b0, no_read_data, dev_seq1);
    settle_cycles(1);
    start_device_response(cfg2, 1'b0, no_read_data, dev_seq2);
    settle_cycles(1);

    write_tx_words(tx_words);
    write_write_cmd(cfg0);
    write_write_cmd(cfg1);
    write_write_cmd(cfg2);

    enable_dut(1'b0);
    wait_for_data_tx_phase("ERR_015 busy SOFT_RST");

    reg_read(ADDR_HC_STATUS, status);
    `DV_CHECK_EQ(status[HC_STS_FSM_IDLE_BIT], 1'b0,
                 "ERR_015: HC_STATUS.FSM_IDLE must be 0 before busy SOFT_RST write")
    write_busy_sw_reset_and_check_no_pulse();
    reg_read(ADDR_RESET_CONTROL, status);
    `DV_CHECK_EQ(status[RESET_CTRL_SOFT_RST_BIT], 1'b0,
                 "ERR_015: RESET_CONTROL.SOFT_RST must read self-cleared after busy write")

    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    wait_for_device_done(dev_seq2, cfg2.ctxt, device_done_timeout_cycles(cfg2));

    read_response(resp0);
    read_response(resp1);
    read_response(resp2);
    check_success_resp(resp0, cfg0.tid, 16'(cfg0.data_length), cfg0.ctxt);
    check_success_resp(resp1, cfg1.tid, 16'(cfg1.data_length), cfg1.ctxt);
    check_success_resp(resp2, cfg2.tid, 16'(cfg2.data_length), cfg2.ctxt);

    check_all_queues_empty("after ERR_015 busy SOFT_RST no-op");
    disable_dut();

    `uvm_info(`gfn,
              "ERR_015 result: busy RESET_CONTROL.SOFT_RST was accepted as a no-op; queued transfers completed",
              UVM_LOW)
  endtask

  virtual task wait_for_data_tx_phase(string ctxt);
    for (int unsigned cycle = 0; cycle < 10000; cycle++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if ((hdl_read_uint_lsb(FLOW_FSM_STATE_PATH, 4) == FSM_ISSUE_CMD) &&
          (hdl_read_uint_lsb(TX_FLOW_STATE_PATH, 3) == TX_DRIVE_BYTE)) return;
    end
    `uvm_fatal(`gfn, $sformatf("%s: data TX phase was not observed", ctxt))
  endtask

  virtual task write_busy_sw_reset_and_check_no_pulse();
    bit saw_sw_reset;
    bit write_done;

    saw_sw_reset = 1'b0;
    write_done = 1'b0;
    fork
      begin
        do begin
          @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
          if (hdl_read_bit(SW_RESET_PATH)) saw_sw_reset = 1'b1;
        end while (!write_done);
        repeat (4) begin
          @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
          if (hdl_read_bit(SW_RESET_PATH)) saw_sw_reset = 1'b1;
        end
      end
      begin
        reg_write(ADDR_RESET_CONTROL, 32'h1 << RESET_CTRL_SOFT_RST_BIT);
        write_done = 1'b1;
      end
    join

    `DV_CHECK_EQ(saw_sw_reset, 1'b0,
                 "ERR_015: busy SOFT_RST write must not pulse DUT sw_reset")
  endtask

  virtual function void check_success_resp(bit [31:0] resp, bit [3:0] tid,
                                           bit [15:0] data_length, string ctxt);
    `DV_CHECK_EQ(resp[31:28], Success, $sformatf("%s: response status mismatch", ctxt))
    `DV_CHECK_EQ(resp[27:24], tid, $sformatf("%s: response TID mismatch", ctxt))
    `DV_CHECK_EQ(resp[23:16], 8'h00, $sformatf("%s: response reserved bits must be zero", ctxt))
    `DV_CHECK_EQ(resp[15:0], data_length, $sformatf("%s: response length mismatch", ctxt))
  endfunction

endclass
