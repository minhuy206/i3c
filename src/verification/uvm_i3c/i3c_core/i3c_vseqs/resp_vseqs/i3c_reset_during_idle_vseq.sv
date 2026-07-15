class i3c_reset_during_idle_vseq extends bus_base_vseq;
  `uvm_object_utils(i3c_reset_during_idle_vseq)

  localparam string FLOW_STATE_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.state_q";
  localparam string SCL_O_PATH = "tb_i3c_top.scl_o";
  localparam string SDA_O_PATH = "tb_i3c_top.sda_o";
  localparam string SDA_OE_PATH = "tb_i3c_top.sda_oe";
  localparam string SEL_OD_PP_PATH = "tb_i3c_top.sel_od_pp";
  localparam string SCL_BUS_PATH = "tb_i3c_top.scl_bus";
  localparam string SDA_BUS_PATH = "tb_i3c_top.sda_bus";

  localparam bit [6:0] RecoveryStaticAddr = 7'h50;
  localparam bit [6:0] RecoveryDynamicAddr = 7'h08;
  localparam bit [3:0] RecoveryTid = 4'hD;
  localparam int unsigned QueuePtrWidth = 4;

  function new(string name = "i3c_reset_during_idle_vseq");
    super.new(name);
  endfunction

  virtual task body();
    prepare_non_reset_idle_state();
    apply_and_check_hard_reset();
    check_post_reset_state();
    run_recovery_command();
  endtask

  virtual task prepare_non_reset_idle_state();
    bit [31:0]                  status;
    immediate_data_trans_desc_t queued_cmd;

    disable_dut();
    poll_idle();

    reg_write(ADDR_HC_CONTROL, hc_control_value(.iba_include(1'b1), .abort(1'b1)));
    reg_write(ADDR_T_R, 32'h0000_0015);
    write_dat_entry(3, 7'h52, 7'h0A, 1'b0);

    queued_cmd         = '0;
    queued_cmd.attr    = ImmediateDataTransfer;
    queued_cmd.tid     = 4'hC;
    queued_cmd.mode    = sdr0;
    queued_cmd.dev_idx = 5'd3;
    queued_cmd.toc     = 1'b1;
    queued_cmd.wroc    = 1'b1;
    // Keep the controller disabled so this valid descriptor remains queued.
    // Frontdoor staging is required for the scoreboard to classify the reset
    // point as RESET_POINT_QUEUED_COMMAND.
    write_cmd(queued_cmd[31:0], queued_cmd[63:32]);
    seed_fifo_for_reset(tx_paths, 32'hCAFE_0130);
    seed_fifo_for_reset(rx_paths, 32'hCAFE_0131);
    seed_fifo_for_reset(resp_paths, 32'hCAFE_0132);
    settle_cycles(1);

    reg_read(ADDR_HC_STATUS, status);
    `DV_CHECK_EQ(status[HC_STS_FSM_IDLE_BIT], 1'b1,
                 "ERR_013 precondition: controller must be idle before hard reset")
    `DV_CHECK_EQ(hdl_read_uint_lsb(FLOW_STATE_PATH, 4), 0,
                 "ERR_013 precondition: protocol FSM state must be Idle")

    check_all_queues_nonempty("before ERR_013 hard reset");
    check_bus_released("before ERR_013 hard reset");
  endtask

  virtual task seed_fifo_for_reset(queue_hdl_paths_t paths, uvm_hdl_data_t data);
    backdoor_write_fifo_entry(paths, 0, data);
    hdl_deposit_checked(paths.rptr_path, '0);
    hdl_deposit_checked(paths.wptr_path, 1);
  endtask

  virtual task check_all_queues_nonempty(string ctxt);
    check_queue_flags(cmd_paths.name, cmd_paths.full_bit, cmd_paths.empty_bit, 1'b0, 1'b0, ctxt);
    check_queue_flags(tx_paths.name, tx_paths.full_bit, tx_paths.empty_bit, 1'b0, 1'b0, ctxt);
    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit, 1'b0, 1'b0, ctxt);
    check_queue_flags(resp_paths.name, resp_paths.full_bit, resp_paths.empty_bit, 1'b0, 1'b0, ctxt);
  endtask

  virtual task apply_and_check_hard_reset();
    force_hard_reset();
    settle_cycles(2);

    `DV_CHECK_EQ(hdl_read_bit(bus_paths.rst_n_path), 1'b0,
                 "ERR_013: hard reset should remain asserted")
    `DV_CHECK_EQ(hdl_read_uint_lsb(FLOW_STATE_PATH, 4), 0,
                 "ERR_013: protocol FSM must asynchronously reset to Idle")
    check_bus_released("while ERR_013 hard reset is asserted");

    release_hard_reset();
    settle_cycles(4);
  endtask

  virtual task check_post_reset_state();
    bit [31:0] data;

    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data, 32'h0000_0000, "ERR_013: HC_CONTROL reset value mismatch")

    reg_read(ADDR_RESET_CONTROL, data);
    `DV_CHECK_EQ(data, 32'h0000_0000, "ERR_013: RESET_CONTROL reset value mismatch")

    reg_read(ADDR_HC_STATUS, data);
    `DV_CHECK_EQ(data, 32'h0000_0005, "ERR_013: HC_STATUS reset value mismatch")

    reg_read(ADDR_T_R, data);
    `DV_CHECK_EQ(data, {12'h000, RST_T_R}, "ERR_013: timing register did not reset")

    reg_read(dat_addr(3), data);
    `DV_CHECK_EQ(data, 32'h0000_0000, "ERR_013: DAT entry did not reset")

    check_all_queues_empty("after ERR_013 hard reset");
    check_fifo_reset_state(cmd_paths);
    check_fifo_reset_state(tx_paths);
    check_fifo_reset_state(rx_paths);
    check_fifo_reset_state(resp_paths);

    `DV_CHECK_EQ(hdl_read_uint_lsb(FLOW_STATE_PATH, 4), 0,
                 "ERR_013: protocol FSM did not remain in Idle after reset release")
    `DV_CHECK_EQ(hdl_read_bit(cmd_paths.read_ready_path), 1'b0,
                 "ERR_013: unexpected CMD pop request after reset")
    `DV_CHECK_EQ(hdl_read_bit(tx_paths.read_ready_path), 1'b0,
                 "ERR_013: unexpected TX pop request after reset")
    `DV_CHECK_EQ(hdl_read_bit(rx_paths.write_valid_path), 1'b0,
                 "ERR_013: unexpected RX push request after reset")
    `DV_CHECK_EQ(hdl_read_bit(resp_paths.write_valid_path), 1'b0,
                 "ERR_013: unexpected RESP push request after reset")
    check_bus_released("after ERR_013 hard reset release");
  endtask

  virtual task check_fifo_reset_state(queue_hdl_paths_t paths);
    `DV_CHECK_EQ(hdl_read_fifo_depth(paths.depth_path), 0,
                 $sformatf("ERR_013: %s FIFO depth did not reset", paths.name))
    `DV_CHECK_EQ(hdl_read_uint_lsb(paths.rptr_path, QueuePtrWidth), 0,
                 $sformatf("ERR_013: %s FIFO read pointer did not reset", paths.name))
    `DV_CHECK_EQ(hdl_read_uint_lsb(paths.wptr_path, QueuePtrWidth), 0,
                 $sformatf("ERR_013: %s FIFO write pointer did not reset", paths.name))
  endtask

  virtual task check_bus_released(string ctxt);
    `DV_CHECK_EQ(hdl_read_bit(SCL_O_PATH), 1'b1,
                 $sformatf("ERR_013: SCL controller output not released %s", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(SDA_O_PATH), 1'b1,
                 $sformatf("ERR_013: SDA controller output not at idle value %s", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(SDA_OE_PATH), 1'b0,
                 $sformatf("ERR_013: SDA output enable not released %s", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(SEL_OD_PP_PATH), 1'b0,
                 $sformatf("ERR_013: OD/PP select not at reset value %s", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(SCL_BUS_PATH), 1'b1,
                 $sformatf("ERR_013: SCL bus not high after release %s", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(SDA_BUS_PATH), 1'b1,
                 $sformatf("ERR_013: SDA bus not high after release %s", ctxt))
  endtask

  virtual task run_recovery_command();
    transfer_stimulus_cfg_t        cfg;
    immediate_data_trans_desc_t    cmd;
    i3c_device_response_seq        dev_seq;
    byte_queue_t                   no_read_data;
    byte_queue_t                   random_data;
    bit [31:0]                     resp;

    enable_dut(1'b0);
    write_dat_entry(0, RecoveryStaticAddr, RecoveryDynamicAddr, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt("ERR_013 post-reset recovery"),
        .seq_name("err013_recovery_dev_seq"),
        .tid(RecoveryTid),
        .dev_idx(5'd0),
        .target_addr(RecoveryDynamicAddr),
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

    cmd                   = '0;
    cmd.attr              = ImmediateDataTransfer;
    cmd.tid               = RecoveryTid;
    cmd.mode              = sdr0;
    cmd.rnw               = 1'b0;
    cmd.toc               = 1'b1;
    cmd.wroc              = 1'b1;
    cmd.dev_idx           = 5'd0;
    randomize_immediate_write_data(cfg.data_length, cmd, random_data);

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(cmd[31:0], cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    `DV_CHECK_EQ(resp[31:28], Success, "ERR_013: post-reset recovery status mismatch")
    `DV_CHECK_EQ(resp[27:24], RecoveryTid, "ERR_013: post-reset recovery TID mismatch")
    `DV_CHECK_EQ(resp[23:16], 8'h00, "ERR_013: post-reset recovery reserved bits mismatch")
    `DV_CHECK_EQ(resp[15:0], 16'd2, "ERR_013: post-reset recovery length mismatch")
    check_all_queues_empty("after ERR_013 post-reset recovery command");
  endtask

endclass
