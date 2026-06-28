class i3c_hc_abort_policy_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_hc_abort_policy_vseq)

  localparam bit [3:0] FSM_ISSUE_IMMEDIATE_CCC = 4'd5;
  localparam string ISSUE_PHASE_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.issue_phase_q";
  localparam string ADDR_NACK_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.addr_nack_q";
  localparam bit [6:0] TARGET_ADDR = 7'h08;
  localparam bit [7:0] EVENT_BYTE = 8'h01;

  function new(string name = "i3c_hc_abort_policy_vseq");
    super.new(name);
  endfunction

  virtual task body();
    run_idle_prebus_holdoff_case();
    run_ccc_abort_case(1'b0);
    run_ccc_abort_case(1'b1);
    run_addr_nack_priority_case();
  endtask

  virtual function immediate_data_trans_desc_t make_ccc_cmd(bit direct, bit [3:0] tid);
    immediate_data_trans_desc_t ccc_cmd;

    ccc_cmd                   = '0;
    ccc_cmd.attr              = ImmediateDataTransfer;
    ccc_cmd.tid               = tid;
    ccc_cmd.cp                = 1'b1;
    ccc_cmd.cmd               = direct ? DIR_ENEC : ENEC;
    ccc_cmd.mode              = sdr0;
    ccc_cmd.dtt               = 3'd4;
    ccc_cmd.rnw               = 1'b0;
    ccc_cmd.toc               = 1'b1;
    ccc_cmd.wroc              = 1'b1;
    ccc_cmd.dev_idx           = 5'd0;
    ccc_cmd.def_or_data_byte1 = EVENT_BYTE;
    return ccc_cmd;
  endfunction

  virtual function i3c_device_response_seq make_ccc_device(string name, bit direct,
                                                           bit ack_broadcast_header = 1'b1);
    i3c_device_response_seq dev_seq;

    dev_seq             = i3c_device_response_seq::type_id::create(name);
    dev_seq.target_addr = 7'h7e;
    dev_seq.ack_address = ack_broadcast_header;
    dev_seq.is_i3c      = 1'b1;
    dev_seq.dir         = 1'b0;
    if (direct) begin
      dev_seq.ccc_target_addr       = TARGET_ADDR;
      dev_seq.ccc_target_addr_valid = 1'b1;
    end
    return dev_seq;
  endfunction

  virtual task run_idle_prebus_holdoff_case();
    immediate_data_trans_desc_t ccc_cmd;
    i3c_device_response_seq     dev_seq;
    bit                  [31:0] resp;
    bit                         hold_window_done;

    enable_dut();
    write_dat_entry(0, 7'h50, TARGET_ADDR, 1'b0);
    ccc_cmd = make_ccc_cmd(1'b0, 4'h1);

    set_hc_abort(1'b1);
    write_cmd(ccc_cmd[31:0], ccc_cmd[63:32]);

    hold_window_done = 1'b0;
    fork : no_start_while_abort_held
      begin
        p_sequencer.cfg.m_i3c_agent_cfg.vif.wait_for_host_start(
            p_sequencer.cfg.m_i3c_agent_cfg.tc.i3c_tc);
        if (!hold_window_done) begin
          `uvm_error(`gfn, "ERR_009 idle/pre-bus: START observed while HC abort was held")
        end
      end
      begin
        repeat (32) @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
        hold_window_done = 1'b1;
      end
    join_any
    disable no_start_while_abort_held;

    `DV_CHECK_EQ(hdl_read_fifo_depth(cmd_paths.depth_path), 1,
                 "ERR_009 idle/pre-bus: queued command must remain pending while abort is held")
    `DV_CHECK_EQ(hdl_read_fifo_depth(resp_paths.depth_path), 0,
                 "ERR_009 idle/pre-bus: held command must not create a response")

    dev_seq = make_ccc_device("err009_idle_release_dev_seq", 1'b0);
    fork : idle_release_device
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    set_hc_abort(1'b0);
    poll_idle();
    wait_for_device_done(dev_seq, "ERR_009 idle/pre-bus release", 3000);
    read_response(resp);
    check_success_resp(resp, ccc_cmd.tid, 16'd1, "ERR_009 idle/pre-bus release");
    check_all_queues_empty("ERR_009 idle/pre-bus release");
    disable idle_release_device;
  endtask

  virtual task run_ccc_abort_case(bit direct);
    immediate_data_trans_desc_t ccc_cmd;
    i3c_device_response_seq     dev_seq;
    bit                  [31:0] resp;
    bit                   [7:0] abort_phase;
    string                      ctxt;

    ctxt = $sformatf("ERR_009 %s CCC execution abort", direct ? "direct" : "broadcast");
    // Assert during the controller's STOP phase, after the final event-byte T-bit has
    // completed. This keeps the monitored CCC transaction structurally complete while
    // still exercising the active IssueImmediateCcc abort path.
    abort_phase = direct ? 8'd10 : 8'd7;

    enable_dut();
    write_dat_entry(0, 7'h50, TARGET_ADDR, 1'b0);
    ccc_cmd = make_ccc_cmd(direct, direct ? 4'h3 : 4'h2);
    dev_seq = make_ccc_device($sformatf("err009_%s_ccc_abort_dev_seq",
                                       direct ? "direct" : "broadcast"), direct);

    fork : ccc_abort_device
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(ccc_cmd[31:0], ccc_cmd[63:32]);
    wait_for_ccc_phase(abort_phase, ctxt, 5000);
    set_hc_abort(1'b1);

    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 5000);
    read_response(resp);
    check_hc_aborted_resp(resp, ccc_cmd.tid, 16'd1, ctxt);

    set_hc_abort(1'b0);
    check_all_queues_empty(ctxt);
    disable ccc_abort_device;

    run_ccc_recovery_case(direct);
  endtask

  virtual task run_addr_nack_priority_case();
    immediate_data_trans_desc_t ccc_cmd;
    i3c_device_response_seq     dev_seq;
    bit                  [31:0] resp;
    string                      ctxt;

    ctxt = "ERR_009 AddrHeader priority over HC abort";
    enable_dut();
    write_dat_entry(0, 7'h50, TARGET_ADDR, 1'b0);
    ccc_cmd = make_ccc_cmd(1'b0, 4'h4);
    dev_seq = make_ccc_device("err009_addr_nack_priority_dev_seq", 1'b0, 1'b0);

    fork : priority_device
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(ccc_cmd[31:0], ccc_cmd[63:32]);
    wait_for_hdl_bit(ADDR_NACK_PATH, ctxt, 5000);
    set_hc_abort(1'b1);

    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 5000);
    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], AddrHeader,
                 $sformatf("%s: AddrHeader must have priority over HcAborted", ctxt))
    `DV_CHECK_EQ(resp[27:24], ccc_cmd.tid, $sformatf("%s: TID mismatch", ctxt))
    `DV_CHECK_EQ(resp[23:16], 8'h00, $sformatf("%s: reserved bits must be zero", ctxt))
    `DV_CHECK_EQ(resp[15:0], 16'd0, $sformatf("%s: response length must be zero", ctxt))

    set_hc_abort(1'b0);
    check_all_queues_empty(ctxt);
    disable priority_device;

    run_ccc_recovery_case(1'b0);
  endtask

  virtual task run_ccc_recovery_case(bit direct);
    immediate_data_trans_desc_t ccc_cmd;
    i3c_device_response_seq     dev_seq;
    bit                  [31:0] resp;
    string                      ctxt;

    ctxt = $sformatf("ERR_009 %s CCC recovery without SW reset",
                     direct ? "direct" : "broadcast");
    ccc_cmd = make_ccc_cmd(direct, direct ? 4'hD : 4'hC);
    dev_seq = make_ccc_device($sformatf("err009_%s_ccc_recovery_dev_seq",
                                       direct ? "direct" : "broadcast"), direct);

    fork : ccc_recovery_device
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(ccc_cmd[31:0], ccc_cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 5000);
    read_response(resp);
    check_success_resp(resp, ccc_cmd.tid, 16'd1, ctxt);
    check_all_queues_empty(ctxt);
    disable ccc_recovery_device;
  endtask

  virtual task wait_for_ccc_phase(bit [7:0] target_phase, string ctxt,
                                  int unsigned timeout_cycles);
    uvm_hdl_data_t state_val;
    uvm_hdl_data_t phase_val;

    for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if (!uvm_hdl_read(FLOW_FSM_STATE_PATH, state_val)) begin
        `uvm_fatal(`gfn, $sformatf("%s: failed to read %s", ctxt, FLOW_FSM_STATE_PATH))
      end
      if (!uvm_hdl_read(ISSUE_PHASE_PATH, phase_val)) begin
        `uvm_fatal(`gfn, $sformatf("%s: failed to read %s", ctxt, ISSUE_PHASE_PATH))
      end
      if ((state_val[3:0] == FSM_ISSUE_IMMEDIATE_CCC) &&
          (phase_val[7:0] == target_phase)) return;
    end
    `uvm_fatal(`gfn, $sformatf("%s: CCC phase %0d was not reached", ctxt, target_phase))
  endtask

  virtual task wait_for_hdl_bit(string path, string ctxt, int unsigned timeout_cycles);
    uvm_hdl_data_t value;

    for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if (!uvm_hdl_read(path, value)) begin
        `uvm_fatal(`gfn, $sformatf("%s: failed to read %s", ctxt, path))
      end
      if (value[0]) return;
    end
    `uvm_fatal(`gfn, $sformatf("%s: %s did not assert", ctxt, path))
  endtask

  virtual task set_hc_abort(bit value);
    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1), .abort(value)));
  endtask

  virtual function void check_hc_aborted_resp(bit [31:0] resp, bit [3:0] tid,
                                              bit [15:0] data_length, string ctxt);
    `DV_CHECK_EQ(resp[31:28], HcAborted, $sformatf("%s: status mismatch", ctxt))
    `DV_CHECK_EQ(resp[27:24], tid, $sformatf("%s: TID mismatch", ctxt))
    `DV_CHECK_EQ(resp[23:16], 8'h00, $sformatf("%s: reserved bits must be zero", ctxt))
    `DV_CHECK_EQ(resp[15:0], data_length, $sformatf("%s: data length mismatch", ctxt))
  endfunction

  virtual function void check_success_resp(bit [31:0] resp, bit [3:0] tid,
                                           bit [15:0] data_length, string ctxt);
    `DV_CHECK_EQ(resp[31:28], Success, $sformatf("%s: status mismatch", ctxt))
    `DV_CHECK_EQ(resp[27:24], tid, $sformatf("%s: TID mismatch", ctxt))
    `DV_CHECK_EQ(resp[23:16], 8'h00, $sformatf("%s: reserved bits must be zero", ctxt))
    `DV_CHECK_EQ(resp[15:0], data_length, $sformatf("%s: data length mismatch", ctxt))
  endfunction

endclass
