class i3c_read_abort_after_first_byte_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_abort_after_first_byte_vseq)

  localparam int unsigned DATA_LENGTH = 8;
  localparam int unsigned ABORT_TIMEOUT_CYCLES = 5000;
  localparam string ISSUE_PHASE_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.issue_phase_q";

  function new(string name = "i3c_read_abort_after_first_byte_vseq");
    super.new(name);
  endfunction

  virtual task body();
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    word_queue_t            rx_words;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;

    build_random_payload(DATA_LENGTH, read_data);
    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt("I3C read abort after first data byte"),
        .seq_name("read_abort_after_first_byte_dev_seq"),
        .tid(4'd9),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b1, read_data, dev_seq);
    write_read_cmd(cfg, .toc(1'b1));

    wait_until_first_data_byte_received(cfg.ctxt);
    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1), .abort(1'b1)));

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);
    read_rx_words(int'(resp[15:0]), rx_words);

    reg_write(ADDR_HC_CONTROL, hc_control_value(.bus_enable(1'b1)));
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty({cfg.ctxt, ": after cleanup"});
  endtask

  virtual task wait_until_first_data_byte_received(string ctxt);
    uvm_hdl_data_t state_val;
    uvm_hdl_data_t phase_val;

    for (int unsigned cycle = 0; cycle < ABORT_TIMEOUT_CYCLES; cycle++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if (!uvm_hdl_read(FLOW_FSM_STATE_PATH, state_val))
        `uvm_fatal(`gfn, $sformatf("%s: failed to read %s", ctxt, FLOW_FSM_STATE_PATH))
      if (!uvm_hdl_read(ISSUE_PHASE_PATH, phase_val))
        `uvm_fatal(`gfn, $sformatf("%s: failed to read %s", ctxt, ISSUE_PHASE_PATH))

      // Phase 3 receives DATA[0]. Phase 4 is the following T-bit handoff,
      // so asserting HC abort here terminates the read after exactly one byte.
      if ((state_val[3:0] == IssueI3CRead) && (phase_val[7:0] == 8'd4)) return;
    end

    `uvm_fatal(`gfn, $sformatf("%s: first data byte was not received", ctxt))
  endtask
endclass
