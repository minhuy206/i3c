class i3c_daa_hc_abort_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_daa_hc_abort_vseq)

  localparam logic [2:0] ENTDAA_RECEIVE_ID_BIT = 3'd3;
  localparam logic [2:0] ENTDAA_SEND_ADDR = 3'd4;
  localparam string ENTDAA_FSM_STATE_PATH =
      "tb_i3c_top.dut.u_ctrl.u_daa_ctrl.u_entdaa_fsm.state_q";
  localparam string ENTDAA_BIT_COUNT_PATH =
      "tb_i3c_top.dut.u_ctrl.u_daa_ctrl.u_entdaa_fsm.bit_cnt_q";
  localparam string ENTDAA_DEV_ROUND_PATH =
      "tb_i3c_top.dut.u_ctrl.u_daa_ctrl.dev_round_q";

  function new(string name = "i3c_daa_hc_abort_vseq");
    super.new(name);
  endfunction

  virtual task body();
    enable_dut();

    run_mid_identity_abort();
    run_recovery_after_abort();
    run_address_phase_abort();
    run_after_completed_round_abort();
  endtask

  virtual function void configure_joining_device(i3c_device_response_seq dev_seq,
                                                 i3c_daa_stimulus stimulus);
    dev_seq.target_addr     = 7'h7e;
    dev_seq.ack_address     = 1'b1;
    dev_seq.is_i3c          = 1'b1;
    dev_seq.is_daa          = 1'b1;
    dev_seq.dir             = 1'b0;
    dev_seq.entdaa_join     = 1'b1;
    dev_seq.daa_accept_addr = 1'b1;
    dev_seq.daa_id_bytes    = '{
      stimulus.pid[47:40],
      stimulus.pid[39:32],
      stimulus.pid[31:24],
      stimulus.pid[23:16],
      stimulus.pid[15:8],
      stimulus.pid[7:0],
      stimulus.bcr,
      stimulus.dcr
    };
  endfunction

  virtual function addr_assign_desc_t make_daa_cmd(bit [3:0] tid, bit [4:0] dev_idx,
                                                   bit [3:0] dev_count);
    addr_assign_desc_t daa_cmd;

    daa_cmd           = '0;
    daa_cmd.attr      = AddressAssignment;
    daa_cmd.tid       = tid;
    daa_cmd.cmd       = ENTDAA;
    daa_cmd.dev_idx   = dev_idx;
    daa_cmd.dev_count = dev_count;
    daa_cmd.wroc      = 1'b1;
    daa_cmd.toc       = 1'b1;
    return daa_cmd;
  endfunction

  virtual task run_mid_identity_abort();
    addr_assign_desc_t      daa_cmd;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;
    i3c_daa_stimulus        stimulus;
    string                  ctxt;

    ctxt = "ERR_007 HC abort during ENTDAA identity";
    stimulus = i3c_daa_stimulus::type_id::create("err007_mid_id_stimulus");
    `DV_CHECK_RANDOMIZE_FATAL(stimulus, "ERR_007 mid-identity stimulus randomization failed")

    write_dat_entry(0, 7'h50, stimulus.assigned_addr, 1'b0);
    daa_cmd = make_daa_cmd(4'd8, 5'd0, 4'd1);

    dev_seq = i3c_device_response_seq::type_id::create("err007_mid_id_dev_seq");
    configure_joining_device(dev_seq, stimulus);

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);
    wait_for_identity_window(4'd0, 6'd55, 6'd16, ctxt, 3000);
    set_hc_abort(1'b1);

    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 3000);
    read_response(resp);

    set_hc_abort(1'b0);
    check_all_queues_empty($sformatf("after %s", ctxt));
    disable device_response;
  endtask

  virtual task run_recovery_after_abort();
    addr_assign_desc_t      daa_cmd;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;
    i3c_daa_stimulus        stimulus;
    string                  ctxt;

    ctxt = "ERR_007 recovery ENTDAA after HC abort";
    stimulus = i3c_daa_stimulus::type_id::create("err007_recovery_stimulus");
    `DV_CHECK_RANDOMIZE_FATAL(stimulus, "ERR_007 recovery stimulus randomization failed")

    write_dat_entry(0, 7'h50, stimulus.assigned_addr, 1'b0);
    daa_cmd = make_daa_cmd(4'd9, 5'd0, 4'd1);

    dev_seq = i3c_device_response_seq::type_id::create("err007_recovery_dev_seq");
    configure_joining_device(dev_seq, stimulus);

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 3000);
    read_response(resp);
    drain_daa_result();

    check_all_queues_empty($sformatf("after %s", ctxt));
    disable device_response;
  endtask

  virtual task run_address_phase_abort();
    addr_assign_desc_t      daa_cmd;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;
    i3c_daa_stimulus        stimulus;
    string                  ctxt;

    ctxt = "ERR_007 HC abort during assigned-address phase";
    stimulus = i3c_daa_stimulus::type_id::create("err007_addr_phase_stimulus");
    `DV_CHECK_RANDOMIZE_FATAL(stimulus, "ERR_007 address-phase stimulus randomization failed")

    write_dat_entry(1, 7'h50, stimulus.assigned_addr, 1'b0);
    daa_cmd = make_daa_cmd(4'd10, 5'd1, 4'd1);

    dev_seq = i3c_device_response_seq::type_id::create("err007_addr_phase_dev_seq");
    configure_joining_device(dev_seq, stimulus);

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);
    wait_for_entdaa_state(ENTDAA_SEND_ADDR, ctxt, 10000);
    set_hc_abort(1'b1);

    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 3000);
    read_response(resp);
    drain_daa_result();

    set_hc_abort(1'b0);
    check_all_queues_empty($sformatf("after %s", ctxt));
    disable device_response;
  endtask

  virtual task run_after_completed_round_abort();
    addr_assign_desc_t      daa_cmd;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq[2];
    i3c_daa_stimulus        stimulus[2];
    string                  ctxt;

    ctxt = "ERR_007 HC abort after one completed ENTDAA round";
    stimulus[0] = i3c_daa_stimulus::type_id::create("err007_round0_stimulus");
    stimulus[1] = i3c_daa_stimulus::type_id::create("err007_round1_stimulus");
    `DV_CHECK_RANDOMIZE_FATAL(stimulus[0], "ERR_007 round[0] stimulus randomization failed")
    if (!stimulus[1].randomize() with {
          assigned_addr != local::stimulus[0].assigned_addr;
        }) begin
      `uvm_fatal(`gfn, "ERR_007 round[1] stimulus randomization failed")
    end

    for (int unsigned i = 0; i < 2; i++) begin
      write_dat_entry(2 + i, 7'h50, stimulus[i].assigned_addr, 1'b0);
      dev_seq[i] = i3c_device_response_seq::type_id::create(
          $sformatf("err007_round%0d_dev_seq", i)
      );
      configure_joining_device(dev_seq[i], stimulus[i]);
    end
    daa_cmd = make_daa_cmd(4'd11, 5'd2, 4'd2);

    fork : device_response
      dev_seq[0].start(p_sequencer.m_i3c_sequencer);
      begin
        wait (dev_seq[0].request_issued);
        dev_seq[1].start(p_sequencer.m_i3c_sequencer);
      end
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);
    wait_for_round_boundary(4'd1, ctxt, 12000);
    set_hc_abort(1'b1);

    poll_idle();
    for (int unsigned i = 0; i < 2; i++) begin
      wait_for_device_done(dev_seq[i], $sformatf("%s device round %0d", ctxt, i), 3000);
    end
    read_response(resp);
    drain_daa_result();

    set_hc_abort(1'b0);
    check_all_queues_empty($sformatf("after %s", ctxt));
    disable device_response;
  endtask

  virtual task set_hc_abort(bit value);
    reg_write(ADDR_HC_CONTROL,
              {28'h0, value, 1'b0 /*BCAST_EN*/, 1'b0 /*SW_RST*/, 1'b1 /*EN*/});
  endtask

  virtual task drain_daa_result();
    word_queue_t rx_words;

    read_rx_words(12, rx_words);
  endtask

  virtual task wait_for_entdaa_state(logic [2:0] target_state, string ctxt,
                                     int unsigned timeout_cycles);
    uvm_hdl_data_t state_val;

    for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if (!uvm_hdl_read(ENTDAA_FSM_STATE_PATH, state_val)) begin
        `uvm_fatal(`gfn, $sformatf("%s: failed to read %s", ctxt, ENTDAA_FSM_STATE_PATH))
      end
      if (state_val[2:0] == target_state) return;
    end

    `uvm_fatal(`gfn, $sformatf("%s: ENTDAA FSM did not reach state %0d", ctxt, target_state))
  endtask

  virtual task wait_for_round_boundary(bit [3:0] completed_rounds, string ctxt,
                                       int unsigned timeout_cycles);
    uvm_hdl_data_t state_val;
    uvm_hdl_data_t dev_round_val;
    bit            new_command_seen;

    new_command_seen = 1'b0;
    for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if (!uvm_hdl_read(ENTDAA_FSM_STATE_PATH, state_val)) begin
        `uvm_fatal(`gfn, $sformatf("%s: failed to read %s", ctxt, ENTDAA_FSM_STATE_PATH))
      end
      if (!uvm_hdl_read(ENTDAA_DEV_ROUND_PATH, dev_round_val)) begin
        `uvm_fatal(`gfn, $sformatf("%s: failed to read %s", ctxt, ENTDAA_DEV_ROUND_PATH))
      end
      if (!new_command_seen) begin
        new_command_seen = (dev_round_val[3:0] == 4'd0);
      end else if (state_val[2:0] == 3'd0 &&
                   dev_round_val[3:0] == completed_rounds) begin
        return;
      end
    end

    `uvm_fatal(`gfn, $sformatf("%s: ENTDAA round boundary was not observed", ctxt))
  endtask

  virtual task wait_for_identity_window(bit [3:0] target_round, bit [5:0] first_bit_count,
                                        bit [5:0] last_bit_count, string ctxt,
                                        int unsigned timeout_cycles);
    uvm_hdl_data_t state_val;
    uvm_hdl_data_t bit_count_val;
    uvm_hdl_data_t dev_round_val;

    for (int unsigned cycle = 0; cycle < timeout_cycles; cycle++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if (!uvm_hdl_read(ENTDAA_FSM_STATE_PATH, state_val)) begin
        `uvm_fatal(`gfn, $sformatf("%s: failed to read %s", ctxt, ENTDAA_FSM_STATE_PATH))
      end
      if (!uvm_hdl_read(ENTDAA_BIT_COUNT_PATH, bit_count_val)) begin
        `uvm_fatal(`gfn, $sformatf("%s: failed to read %s", ctxt, ENTDAA_BIT_COUNT_PATH))
      end
      if (!uvm_hdl_read(ENTDAA_DEV_ROUND_PATH, dev_round_val)) begin
        `uvm_fatal(`gfn, $sformatf("%s: failed to read %s", ctxt, ENTDAA_DEV_ROUND_PATH))
      end
      if (state_val[2:0] == ENTDAA_RECEIVE_ID_BIT &&
          dev_round_val[3:0] == target_round &&
          bit_count_val[5:0] <= first_bit_count &&
          bit_count_val[5:0] >= last_bit_count) begin
        return;
      end
    end

    `uvm_fatal(`gfn, $sformatf("%s: ENTDAA identity window was not observed", ctxt))
  endtask
endclass
