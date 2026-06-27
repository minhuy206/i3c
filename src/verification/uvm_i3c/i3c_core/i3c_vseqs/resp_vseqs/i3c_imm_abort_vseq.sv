class i3c_imm_abort_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_imm_abort_vseq)

  localparam bit [3:0] FSM_ISSUE_CMD = 4'd11;
  localparam string ISSUE_PHASE_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.issue_phase_q";
  localparam int unsigned IMM_ABORT_FSM_TIMEOUT = 5000;

  function new(string name = "i3c_imm_abort_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_i3c_imm_abort_case(broadcast_modes[mode_idx]);
    end
    run_i2c_imm_abort_case();

    `uvm_info(
        `gfn,
        "ERR_007 conclusion: HC abort during immediate data phase reaches idle and SW reset flushes queues in all three cases (private I3C, broadcast I3C, I2C)",
        UVM_LOW)
  endtask

  virtual task wait_for_first_data_ack_phase(string ctxt, int unsigned timeout_cycles);
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
      if (state_val[3:0] == FSM_ISSUE_CMD && phase_val[7:0] == 8'd5) return;
    end
    `uvm_fatal(`gfn, $sformatf(
        "%s: immediate transfer did not complete its first data ACK/T-bit phase", ctxt))
  endtask

  virtual task run_i3c_imm_abort_case(bit bcast_en);
    immediate_data_trans_desc_t        imm_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;

    enable_dut(bcast_en);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    imm_cmd = '0;
    imm_cmd.attr = ImmediateDataTransfer;
    imm_cmd.tid = 4'd7;
    imm_cmd.mode = sdr0;
    imm_cmd.dtt = 3'd4;
    imm_cmd.rnw = 1'b0;
    imm_cmd.toc = 1'b1;
    imm_cmd.wroc = 1'b1;
    imm_cmd.def_or_data_byte1 = 8'hA1;
    imm_cmd.data_byte2 = 8'hA2;
    imm_cmd.data_byte3 = 8'hA3;
    imm_cmd.data_byte4 = 8'hA4;

    dev_seq = i3c_device_response_seq::type_id::create(
        $sformatf("imm006_i3c_%s_dev_seq", private_addr_mode_name(bcast_en)));
    dev_seq.target_addr = 7'h08;
    dev_seq.ack_address = 1'b1;
    dev_seq.is_i3c = 1'b1;
    dev_seq.start_with_broadcast_header = bcast_en;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    wait_for_first_data_ack_phase(
        $sformatf("ERR_007 %s I3C", private_addr_mode_name(bcast_en)),
        IMM_ABORT_FSM_TIMEOUT);

    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1), .iba_include(bcast_en),
                                                .abort(1'b1)));
    `uvm_info(`gfn, $sformatf("ERR_007 %s I3C: abort_asserted=1 after first data byte",
                              private_addr_mode_name(bcast_en)), UVM_LOW)

    poll_idle();
    wait_for_device_done(dev_seq, $sformatf("ERR_007 %s I3C", private_addr_mode_name(bcast_en)),
                         10000);
    read_response(resp);

    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1), .iba_include(bcast_en)));
    check_all_queues_empty(
        $sformatf("ERR_007 %s I3C: before recovery transfer", private_addr_mode_name(bcast_en)));
    run_recovery_case(1'b1, bcast_en);

    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty(
        $sformatf("ERR_007 %s I3C: after recovery SW reset", private_addr_mode_name(bcast_en)));

    `uvm_info(`gfn, $sformatf("ERR_007 result: mode=%s device=I3C resp=0x%08h sampled_bytes=%0d",
                              private_addr_mode_name(bcast_en), resp, dev_seq.sampled_data.size()),
              UVM_LOW)
  endtask

  virtual task run_i2c_imm_abort_case();
    immediate_data_trans_desc_t        imm_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;

    enable_dut(1'b0);
    write_dat_entry(0, 7'h52, 7'h00, 1'b1);

    imm_cmd = '0;
    imm_cmd.attr = ImmediateDataTransfer;
    imm_cmd.tid = 4'd7;
    imm_cmd.mode = sdr0;
    imm_cmd.dtt = 3'd4;
    imm_cmd.rnw = 1'b0;
    imm_cmd.toc = 1'b1;
    imm_cmd.wroc = 1'b1;
    imm_cmd.def_or_data_byte1 = 8'hB1;
    imm_cmd.data_byte2 = 8'hB2;
    imm_cmd.data_byte3 = 8'hB3;
    imm_cmd.data_byte4 = 8'hB4;

    dev_seq = i3c_device_response_seq::type_id::create("imm006_i2c_dev_seq");
    dev_seq.target_addr = 7'h52;
    dev_seq.ack_address = 1'b1;
    dev_seq.is_i3c = 1'b0;
    dev_seq.start_with_broadcast_header = 1'b0;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    wait_for_first_data_ack_phase("ERR_007 I2C", i2c_device_done_timeout_cycles(4));

    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1), .abort(1'b1)));
    `uvm_info(`gfn, "ERR_007 I2C: abort_asserted=1 after first data byte", UVM_LOW)

    poll_idle();
    wait_for_device_done(dev_seq, "ERR_007 I2C", i2c_device_done_timeout_cycles(4));
    read_response(resp);

    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1)));
    check_all_queues_empty("ERR_007 I2C: before recovery transfer");
    run_recovery_case(1'b0, 1'b0);

    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty("ERR_007 I2C: after recovery SW reset");

    `uvm_info(`gfn, $sformatf("ERR_007 result: device=I2C resp=0x%08h sampled_bytes=%0d", resp,
                              dev_seq.sampled_data.size()), UVM_LOW)
  endtask

  virtual task run_recovery_case(bit is_i3c, bit bcast_en);
    immediate_data_trans_desc_t imm_cmd;
    bit                  [31:0] resp;
    i3c_device_response_seq     dev_seq;
    transfer_stimulus_cfg_t     cfg;
    byte_queue_t                no_read_data;
    byte_queue_t                exp_data;
    bit                   [6:0] target_addr;

    target_addr = is_i3c ? 7'h08 : 7'h52;
    exp_data.push_back(is_i3c ? 8'hC1 : 8'hD1);

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = 4'hE;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = 3'd1;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.def_or_data_byte1 = exp_data[0];

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_007 recovery without SW reset device=%s mode=%s",
                        is_i3c ? "I3C" : "I2C", private_addr_mode_name(bcast_en))),
        .seq_name($sformatf("imm006_recovery_%s_%s_dev_seq", is_i3c ? "i3c" : "i2c",
                           private_addr_mode_name(bcast_en))),
        .tid(imm_cmd.tid),
        .dev_idx(5'd0),
        .target_addr(target_addr),
        .is_i3c(is_i3c),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(is_i3c && bcast_en),
        .data_length(exp_data.size()),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);
    check_all_queues_empty(cfg.ctxt);
  endtask

endclass
