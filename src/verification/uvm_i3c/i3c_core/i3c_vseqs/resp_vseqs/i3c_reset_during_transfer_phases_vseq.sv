class i3c_reset_during_transfer_phases_vseq extends bus_base_vseq;
  `uvm_object_utils(i3c_reset_during_transfer_phases_vseq)

  localparam string FLOW_STATE_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.state_q";
  localparam string ISSUE_PHASE_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.issue_phase_q";
  localparam string SCL_GEN_STATE_PATH = "tb_i3c_top.dut.u_ctrl.u_scl_gen.state_q";
  localparam string TX_FLOW_STATE_PATH = "tb_i3c_top.dut.u_ctrl.u_tx_flow.state_q";
  localparam string RX_FLOW_STATE_PATH = "tb_i3c_top.dut.u_ctrl.u_rx_flow.state_q";
  localparam string ENTDAA_STATE_PATH = "tb_i3c_top.dut.u_ctrl.u_daa_ctrl.u_entdaa_fsm.state_q";
  localparam string SCL_O_PATH = "tb_i3c_top.scl_o";
  localparam string SDA_O_PATH = "tb_i3c_top.sda_o";
  localparam string SDA_OE_PATH = "tb_i3c_top.sda_oe";
  localparam string SEL_OD_PP_PATH = "tb_i3c_top.sel_od_pp";
  localparam string SCL_BUS_PATH = "tb_i3c_top.scl_bus";
  localparam string SDA_BUS_PATH = "tb_i3c_top.sda_bus";

  localparam bit [7:0] PHASE_ADDR_ACK = 8'd2;
  localparam bit [3:0] SCL_GENERATE_START = 4'd1;
  localparam bit [2:0] TX_DRIVE_BYTE = 3'd1;
  localparam bit [2:0] RX_READ_BYTE = 3'd1;
  localparam bit [2:0] RX_READ_BIT = 3'd2;
  localparam bit [2:0] ENTDAA_RECEIVE_ID_BIT = 3'd3;

  localparam bit [6:0] StaticAddr = 7'h50;
  localparam bit [6:0] DynamicAddr = 7'h08;
  localparam int unsigned RespFifoDepth = 8;
  localparam int unsigned PhaseTimeoutCycles = 10000;

  function new(string name = "i3c_reset_during_transfer_phases_vseq");
    super.new(name);
  endfunction

  virtual task body();
    run_start_reset_case();
    run_address_ack_reset_case();
    run_data_tx_reset_case();
    run_data_rx_reset_case();
    run_daa_reset_case();
    run_write_resp_reset_case();
  endtask

  virtual task configure_target_and_enable();
    configure_i3c_dat_target(0, StaticAddr, DynamicAddr);
    enable_dut(1'b0);
  endtask

  virtual function immediate_data_trans_desc_t make_immediate_cmd(bit [3:0] tid, bit [2:0] dtt);
    immediate_data_trans_desc_t cmd;
    byte_queue_t                random_data;

    cmd         = '0;
    cmd.attr    = ImmediateDataTransfer;
    cmd.tid     = tid;
    cmd.mode    = sdr0;
    cmd.rnw     = 1'b0;
    cmd.toc     = 1'b1;
    cmd.wroc    = 1'b1;
    cmd.dev_idx = 5'd0;
    randomize_immediate_write_data(dtt, cmd, random_data);
    return cmd;
  endfunction

  virtual task start_immediate_write(string ctxt, string seq_name, bit [3:0] tid,
                                     output i3c_device_response_seq dev_seq);
    transfer_stimulus_cfg_t     cfg;
    immediate_data_trans_desc_t cmd;
    byte_queue_t                no_read_data;

    configure_target_and_enable();
    cfg = make_transfer_cfg(
        .ctxt(ctxt),
        .seq_name(seq_name),
        .tid(tid),
        .dev_idx(5'd0),
        .target_addr(DynamicAddr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(4),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    cmd = make_immediate_cmd(tid, 3'd4);

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    wait_for_device_request_issued(dev_seq, ctxt);
    write_cmd(cmd[31:0], cmd[63:32]);
  endtask

  virtual task run_start_reset_case();
    i3c_device_response_seq dev_seq;
    string                  ctxt;

    ctxt = "ERR_014 reset during START";
    start_immediate_write(ctxt, "err014_start_dev_seq", 4'h0, dev_seq);
    wait_for_path_value(SCL_GEN_STATE_PATH, 4, SCL_GENERATE_START, ctxt);
    apply_reset_and_recover(dev_seq, ctxt, 4'h8);
  endtask

  virtual task run_address_ack_reset_case();
    i3c_device_response_seq dev_seq;
    string                  ctxt;

    ctxt = "ERR_014 reset during address ACK";
    start_immediate_write(ctxt, "err014_addr_ack_dev_seq", 4'h1, dev_seq);
    wait_for_address_ack_phase(ctxt);
    apply_reset_and_recover(dev_seq, ctxt, 4'h9);
  endtask

  virtual task run_data_tx_reset_case();
    i3c_device_response_seq dev_seq;
    string                  ctxt;

    ctxt = "ERR_014 reset during data TX";
    start_immediate_write(ctxt, "err014_data_tx_dev_seq", 4'h2, dev_seq);
    wait_for_data_tx_phase(ctxt);
    apply_reset_and_recover(dev_seq, ctxt, 4'hA);
  endtask

  virtual task run_data_rx_reset_case();
    transfer_stimulus_cfg_t cfg;
    regular_trans_desc_t    cmd;
    byte_queue_t            read_data;
    i3c_device_response_seq dev_seq;
    string                  ctxt;

    ctxt = "ERR_014 reset during data RX";
    configure_target_and_enable();
    build_random_payload(8, read_data);
    cfg = make_transfer_cfg(
        .ctxt(ctxt),
        .seq_name("err014_data_rx_dev_seq"),
        .tid(4'h3),
        .dev_idx(5'd0),
        .target_addr(DynamicAddr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(read_data.size()),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b1);

    start_device_response(cfg, 1'b1, read_data, dev_seq);
    wait_for_device_request_issued(dev_seq, ctxt);
    write_cmd(cmd[31:0], cmd[63:32]);
    wait_for_data_rx_phase(ctxt);
    apply_reset_and_recover(dev_seq, ctxt, 4'hB);
  endtask

  virtual task run_daa_reset_case();
    addr_assign_desc_t      cmd;
    i3c_device_response_seq dev_seq;
    i3c_daa_stimulus        stimulus;
    string                  ctxt;

    ctxt = "ERR_014 reset during DAA identity";
    stimulus = i3c_daa_stimulus::type_id::create("err014_daa_stimulus");
    `DV_CHECK_RANDOMIZE_FATAL(stimulus, "ERR_014 DAA stimulus randomization failed")

    write_dat_entry(0, StaticAddr, stimulus.assigned_addr, 1'b0);
    enable_dut(1'b0);

    cmd = '0;
    cmd.attr = AddressAssignment;
    cmd.tid = 4'h4;
    cmd.cmd = ENTDAA;
    cmd.dev_idx = 5'd0;
    cmd.dev_count = 4'd1;
    cmd.wroc = 1'b1;
    cmd.toc = 1'b1;

    dev_seq = i3c_device_response_seq::type_id::create("err014_daa_dev_seq");
    dev_seq.target_addr = 7'h7e;
    dev_seq.addr_nack = 1'b0;
    dev_seq.is_i3c = 1'b1;
    dev_seq.dir = 1'b0;
    dev_seq.entdaa_join = 1'b1;
    dev_seq.daa_accept_addr = 1'b1;
    dev_seq.daa_id_bytes = '{
        stimulus.pid[47:40],
        stimulus.pid[39:32],
        stimulus.pid[31:24],
        stimulus.pid[23:16],
        stimulus.pid[15:8],
        stimulus.pid[7:0],
        stimulus.bcr,
        stimulus.dcr
    };

    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none
    wait_for_device_request_issued(dev_seq, ctxt);
    write_cmd(cmd[31:0], cmd[63:32]);
    wait_for_path_value(ENTDAA_STATE_PATH, 3, ENTDAA_RECEIVE_ID_BIT, ctxt);
    apply_reset_and_recover(dev_seq, ctxt, 4'hC);
  endtask

  virtual task run_write_resp_reset_case();
    i3c_device_response_seq dev_seq;
    string                  ctxt;

    ctxt = "ERR_014 reset during response write";
    configure_target_and_enable();
    prefill_response_fifo(ctxt);
    start_immediate_write_without_reconfigure(ctxt, "err014_write_resp_dev_seq", 4'h5, dev_seq);
    wait_for_write_resp_stall(ctxt);
    apply_reset_and_recover(dev_seq, ctxt, 4'hD);
  endtask

  virtual task start_immediate_write_without_reconfigure(
      string ctxt, string seq_name, bit [3:0] tid, output i3c_device_response_seq dev_seq);
    transfer_stimulus_cfg_t     cfg;
    immediate_data_trans_desc_t cmd;
    byte_queue_t                no_read_data;

    cfg = make_transfer_cfg(
        .ctxt(ctxt),
        .seq_name(seq_name),
        .tid(tid),
        .dev_idx(5'd0),
        .target_addr(DynamicAddr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(4),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    cmd = make_immediate_cmd(tid, 3'd4);

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    wait_for_device_request_issued(dev_seq, ctxt);
    write_cmd(cmd[31:0], cmd[63:32]);
  endtask

  virtual task prefill_response_fifo(string ctxt);
    for (int unsigned i = 0; i < RespFifoDepth; i++) begin
      backdoor_write_fifo_entry(resp_paths, i, 32'hE140_0000 | i);
    end
    backdoor_set_fifo_level(resp_paths, RespFifoDepth);
    settle_cycles(2);

    `DV_CHECK_EQ(hdl_read_fifo_depth(resp_paths.depth_path), RespFifoDepth,
                     $sformatf("%s: RESP FIFO prefill depth mismatch", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(resp_paths.write_ready_path), 1'b0,
                     $sformatf("%s: RESP FIFO must be full before command", ctxt))
  endtask

  virtual task wait_for_path_value(string path, int unsigned width, int unsigned expected,
                                   string ctxt, int unsigned timeout_cycles = PhaseTimeoutCycles);
    for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if (hdl_read_uint_lsb(path, width) == expected) return;
    end
    `uvm_fatal(`gfn, $sformatf("%s: %s did not reach value %0d", ctxt, path, expected))
  endtask

  virtual task wait_for_address_ack_phase(string ctxt);
    for (int unsigned cycle = 0; cycle < PhaseTimeoutCycles; cycle++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if ((hdl_read_uint_lsb(
              FLOW_STATE_PATH, 4
          ) == InitWrite) && (hdl_read_uint_lsb(
              ISSUE_PHASE_PATH, 8
          ) == PHASE_ADDR_ACK) && (hdl_read_uint_lsb(
              RX_FLOW_STATE_PATH, 3
          ) == RX_READ_BIT))
        return;
    end
    `uvm_fatal(`gfn, $sformatf("%s: address ACK phase was not observed", ctxt))
  endtask

  virtual task wait_for_data_tx_phase(string ctxt);
    for (int unsigned cycle = 0; cycle < PhaseTimeoutCycles; cycle++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if ((hdl_read_uint_lsb(
              FLOW_STATE_PATH, 4
          ) == IssueI3CWrite) && (hdl_read_uint_lsb(
              TX_FLOW_STATE_PATH, 3
          ) == TX_DRIVE_BYTE))
        return;
    end
    `uvm_fatal(`gfn, $sformatf("%s: data TX phase was not observed", ctxt))
  endtask

  virtual task wait_for_data_rx_phase(string ctxt);
    for (int unsigned cycle = 0; cycle < PhaseTimeoutCycles; cycle++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if ((hdl_read_uint_lsb(
              FLOW_STATE_PATH, 4
          ) == IssueI3CRead) && (hdl_read_uint_lsb(
              RX_FLOW_STATE_PATH, 3
          ) == RX_READ_BYTE))
        return;
    end
    `uvm_fatal(`gfn, $sformatf("%s: data RX phase was not observed", ctxt))
  endtask

  virtual task wait_for_write_resp_stall(string ctxt);
    for (int unsigned cycle = 0; cycle < PhaseTimeoutCycles; cycle++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if ((hdl_read_uint_lsb(
              FLOW_STATE_PATH, 4
          ) == WriteResp) && hdl_read_bit(
              resp_paths.write_valid_path
          ) && !hdl_read_bit(
              resp_paths.write_ready_path
          ))
        return;
    end
    `uvm_fatal(`gfn, $sformatf("%s: stalled WriteResp phase was not observed", ctxt))
  endtask

  virtual task apply_reset_and_recover(i3c_device_response_seq dev_seq, string ctxt,
                                       bit [3:0] recovery_tid);
    force_hard_reset();
    settle_cycles(2);
    check_state_while_reset(ctxt);

    release_hard_reset();
    settle_cycles(4);
    wait_for_device_done(dev_seq, ctxt, 2000);
    check_state_after_reset(ctxt);
    run_recovery_command(ctxt, recovery_tid);
  endtask

  virtual task check_state_while_reset(string ctxt);
    `DV_CHECK_EQ(hdl_read_bit(bus_paths.rst_n_path), 1'b0,
                     $sformatf("%s: hard reset should remain asserted", ctxt))
    `DV_CHECK_EQ(hdl_read_uint_lsb(FLOW_STATE_PATH, 4), 0,
                     $sformatf("%s: flow FSM did not reset to Idle", ctxt))
    `DV_CHECK_EQ(hdl_read_uint_lsb(SCL_GEN_STATE_PATH, 4), 0,
                     $sformatf("%s: SCL generator did not reset to Idle", ctxt))
    `DV_CHECK_EQ(hdl_read_uint_lsb(TX_FLOW_STATE_PATH, 3), 0,
                     $sformatf("%s: TX flow did not reset to Idle", ctxt))
    `DV_CHECK_EQ(hdl_read_uint_lsb(RX_FLOW_STATE_PATH, 3), 0,
                     $sformatf("%s: RX flow did not reset to Idle", ctxt))
    `DV_CHECK_EQ(hdl_read_uint_lsb(ENTDAA_STATE_PATH, 3), 0,
                     $sformatf("%s: ENTDAA FSM did not reset to Idle", ctxt))
    check_bus_released(ctxt);
  endtask

  virtual task check_state_after_reset(string ctxt);
    check_all_queues_empty($sformatf("after %s", ctxt));
    `DV_CHECK_EQ(hdl_read_uint_lsb(FLOW_STATE_PATH, 4), 0,
                     $sformatf("%s: flow FSM did not remain Idle after reset", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(cmd_paths.read_ready_path), 1'b0,
                     $sformatf("%s: unexpected CMD pop after reset", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(tx_paths.read_ready_path), 1'b0,
                     $sformatf("%s: unexpected TX pop after reset", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(rx_paths.write_valid_path), 1'b0,
                     $sformatf("%s: unexpected RX push after reset", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(resp_paths.write_valid_path), 1'b0,
                     $sformatf("%s: unexpected RESP push after reset", ctxt))
    check_bus_released(ctxt);
  endtask

  virtual task check_bus_released(string ctxt);
    `DV_CHECK_EQ(hdl_read_bit(SCL_O_PATH), 1'b1, $sformatf("%s: SCL output not released", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(SDA_O_PATH), 1'b1, $sformatf("%s: SDA output not at idle value",
                                                           ctxt))
    `DV_CHECK_EQ(hdl_read_bit(SDA_OE_PATH), 1'b0, $sformatf("%s: SDA output enable not released",
                                                            ctxt))
    `DV_CHECK_EQ(hdl_read_bit(SEL_OD_PP_PATH), 1'b0,
                     $sformatf("%s: OD/PP select not at reset value", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(SCL_BUS_PATH), 1'b1, $sformatf("%s: SCL bus not high", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(SDA_BUS_PATH), 1'b1, $sformatf("%s: SDA bus not high", ctxt))
  endtask

  virtual task run_recovery_command(string reset_ctxt, bit [3:0] tid);
    transfer_stimulus_cfg_t            cfg;
    immediate_data_trans_desc_t        cmd;
    i3c_device_response_seq            dev_seq;
    byte_queue_t                       no_read_data;
    bit                         [31:0] resp;
    string                             ctxt;

    ctxt = $sformatf("%s recovery", reset_ctxt);
    configure_target_and_enable();
    cfg = make_transfer_cfg(
        .ctxt(ctxt),
        .seq_name($sformatf("err014_recovery_%0h_dev_seq", tid)),
        .tid(tid),
        .dev_idx(5'd0),
        .target_addr(DynamicAddr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    cmd = make_immediate_cmd(tid, 3'd2);

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    wait_for_device_request_issued(dev_seq, ctxt);
    write_cmd(cmd[31:0], cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq, ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);
    check_all_queues_empty($sformatf("after %s", ctxt));
  endtask

endclass
