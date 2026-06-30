class i3c_entdaa_invalid_descriptor_resp_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_entdaa_invalid_descriptor_resp_vseq)

  localparam string FLOW_DAT_READ_PATH =
      "tb_i3c_top.dut.u_ctrl.u_flow_fsm.dat_read_valid_hw_o";
  localparam string FLOW_GEN_START_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.gen_start_o";
  localparam string FLOW_GEN_RSTART_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.gen_rstart_o";
  localparam string FLOW_GEN_STOP_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.gen_stop_o";
  localparam string FLOW_TX_BYTE_PATH =
      "tb_i3c_top.dut.u_ctrl.u_flow_fsm.bus_tx_req_byte_o";
  localparam string FLOW_TX_BIT_PATH =
      "tb_i3c_top.dut.u_ctrl.u_flow_fsm.bus_tx_req_bit_o";
  localparam string FLOW_RX_BYTE_PATH =
      "tb_i3c_top.dut.u_ctrl.u_flow_fsm.bus_rx_req_byte_o";
  localparam string FLOW_RX_BIT_PATH =
      "tb_i3c_top.dut.u_ctrl.u_flow_fsm.bus_rx_req_bit_o";
  localparam string FLOW_CCC_VALID_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.ccc_valid_o";

  bit [3:0] recovery_tid;

  function new(string name = "i3c_entdaa_invalid_descriptor_resp_vseq");
    super.new(name);
  endfunction

  virtual task body();
    addr_assign_desc_t daa_cmd;

    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);
    write_dat_entry(31, 7'h00, 7'h31, 1'b0);
    recovery_tid = 4'h8;

    daa_cmd           = valid_entdaa_cmd(4'h1);
    daa_cmd.toc       = 1'b0;
    issue_invalid_and_recover(daa_cmd, "ERR_011 AddressAssignment toc=0");

    daa_cmd           = valid_entdaa_cmd(4'h2);
    daa_cmd.wroc      = 1'b0;
    issue_invalid_and_recover(daa_cmd, "ERR_011 AddressAssignment wroc=0");

    daa_cmd           = valid_entdaa_cmd(4'h3);
    daa_cmd.dev_count = 4'd0;
    issue_invalid_and_recover(daa_cmd, "ERR_011 AddressAssignment dev_count=0");

    daa_cmd           = valid_entdaa_cmd(4'h4);
    daa_cmd.dev_idx   = 5'd31;
    daa_cmd.dev_count = 4'd2;
    issue_invalid_and_recover(daa_cmd, "ERR_011 AddressAssignment DAT span overflow");
  endtask

  virtual function addr_assign_desc_t valid_entdaa_cmd(bit [3:0] tid);
    addr_assign_desc_t daa_cmd;

    daa_cmd           = '0;
    daa_cmd.attr      = AddressAssignment;
    daa_cmd.tid       = tid;
    daa_cmd.cmd       = ENTDAA;
    daa_cmd.dev_idx   = 5'd0;
    daa_cmd.dev_count = 4'd1;
    daa_cmd.toc       = 1'b1;
    daa_cmd.wroc      = 1'b1;
    return daa_cmd;
  endfunction

  virtual task issue_invalid_and_recover(addr_assign_desc_t daa_cmd, string ctxt);
    bit        monitor_done;
    bit        saw_dat_read;
    bit        saw_bus_activity;
    bit        saw_daa_activity;
    bit [31:0] resp;

    monitor_done     = 1'b0;
    saw_dat_read     = 1'b0;
    saw_bus_activity = 1'b0;
    saw_daa_activity = 1'b0;

    fork
      begin
        while (!monitor_done) begin
          @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
          saw_dat_read |= hdl_read_bit(FLOW_DAT_READ_PATH);
          saw_bus_activity |= hdl_read_bit(FLOW_GEN_START_PATH) ||
                              hdl_read_bit(FLOW_GEN_RSTART_PATH) ||
                              hdl_read_bit(FLOW_GEN_STOP_PATH) ||
                              hdl_read_bit(FLOW_TX_BYTE_PATH) ||
                              hdl_read_bit(FLOW_TX_BIT_PATH) ||
                              hdl_read_bit(FLOW_RX_BYTE_PATH) ||
                              hdl_read_bit(FLOW_RX_BIT_PATH);
          saw_daa_activity |= hdl_read_bit(FLOW_CCC_VALID_PATH);
        end
      end
      begin
        write_cmd(daa_cmd[31:0], daa_cmd[63:32]);
        poll_idle();
        settle_cycles(2);
        monitor_done = 1'b1;
      end
    join

    read_response(resp);
    `DV_CHECK_EQ(saw_dat_read, 1'b0, $sformatf("%s: invalid command accessed DAT", ctxt))
    `DV_CHECK_EQ(saw_bus_activity, 1'b0,
                 $sformatf("%s: invalid command caused bus activity", ctxt))
    `DV_CHECK_EQ(saw_daa_activity, 1'b0,
                 $sformatf("%s: invalid command activated ENTDAA controller", ctxt))
    `DV_CHECK_EQ(resp[31:28], NotSupported, $sformatf("%s: response status", ctxt))
    `DV_CHECK_EQ(resp[27:24], daa_cmd.tid, $sformatf("%s: response TID", ctxt))
    `DV_CHECK_EQ(resp[23:16], 8'h00, $sformatf("%s: response reserved bits", ctxt))
    `DV_CHECK_EQ(resp[15:0], 16'h0000, $sformatf("%s: response length", ctxt))
    check_all_queues_empty($sformatf("%s after rejection", ctxt));
    run_recovery_case(ctxt);
  endtask

  virtual task run_recovery_case(string prior_ctxt);
    transfer_stimulus_cfg_t     cfg;
    immediate_data_trans_desc_t imm_cmd;
    i3c_device_response_seq     dev_seq;
    byte_queue_t                no_read_data;
    bit [31:0]                  resp;

    recovery_tid++;
    cfg = make_transfer_cfg(
        .ctxt($sformatf("%s recovery", prior_ctxt)),
        .seq_name($sformatf("err011_recovery_%0d_dev_seq", recovery_tid)),
        .tid(recovery_tid),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(1),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = recovery_tid;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = 3'd1;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.dev_idx           = 5'd0;
    imm_cmd.def_or_data_byte1 = 8'h96;

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);
    check_all_queues_empty($sformatf("%s completed", cfg.ctxt));
  endtask
endclass
