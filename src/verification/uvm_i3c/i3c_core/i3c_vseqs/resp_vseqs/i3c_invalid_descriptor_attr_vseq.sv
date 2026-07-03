class i3c_invalid_descriptor_attr_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_invalid_descriptor_attr_vseq)

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

  bit [3:0] recovery_tid;

  function new(string name = "i3c_invalid_descriptor_attr_vseq");
    super.new(name);
  endfunction

  virtual task body();
    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);
    recovery_tid = 4'h0;

    run_unsupported_attr_cases();
    run_unsupported_mode_cases();
    run_invalid_immediate_cases();
    run_unsupported_ccc_cases();
    run_invalid_regular_cp_case();
    run_invalid_address_assignment_opcode_case();
  endtask

  virtual task run_unsupported_attr_cases();
    bit [63:0] raw_desc;

    for (int unsigned attr = 3; attr <= 7; attr++) begin
      raw_desc        = '0;
      raw_desc[2:0]   = attr[2:0];
      raw_desc[6:3]   = attr[3:0];
      raw_desc[28:26] = sdr0;
      raw_desc[30]    = 1'b1;
      raw_desc[31]    = 1'b1;
      raw_desc[63:48] = 16'd4;
      issue_invalid_and_recover(raw_desc, $sformatf("ERR_010 unsupported attr 0x%0h", attr));
    end
  endtask

  virtual task run_unsupported_mode_cases();
    regular_trans_desc_t        reg_cmd;
    immediate_data_trans_desc_t imm_cmd;

    for (int unsigned mode = 1; mode <= 7; mode++) begin
      reg_cmd             = '0;
      reg_cmd.attr        = RegularTransfer;
      reg_cmd.tid         = mode[3:0];
      reg_cmd.mode        = i3c_trans_mode_e'(mode[2:0]);
      reg_cmd.toc         = 1'b1;
      reg_cmd.wroc        = (mode != 1);
      reg_cmd.dev_idx     = 5'd0;
      reg_cmd.data_length = 16'd1;
      issue_invalid_and_recover(reg_cmd, $sformatf("ERR_010 regular unsupported mode %0d", mode));

      imm_cmd                   = '0;
      imm_cmd.attr              = ImmediateDataTransfer;
      imm_cmd.tid               = 4'(mode + 7);
      imm_cmd.mode              = i3c_trans_mode_e'(mode[2:0]);
      imm_cmd.dtt               = 3'd1;
      imm_cmd.toc               = 1'b1;
      imm_cmd.wroc              = 1'b1;
      imm_cmd.dev_idx           = 5'd0;
      imm_cmd.def_or_data_byte1 = 8'hA5;
      issue_invalid_and_recover(imm_cmd,
                                $sformatf("ERR_010 immediate unsupported mode %0d", mode));
    end
  endtask

  virtual task run_invalid_immediate_cases();
    immediate_data_trans_desc_t imm_cmd;

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = 4'h8;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = 3'd1;
    imm_cmd.rnw               = 1'b1;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.dev_idx           = 5'd0;
    imm_cmd.def_or_data_byte1 = 8'h5A;
    issue_invalid_and_recover(imm_cmd, "ERR_010 immediate rnw=1");

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = 4'h9;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = 3'd5;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.dev_idx           = 5'd0;
    imm_cmd.def_or_data_byte1 = 8'hC3;
    issue_invalid_and_recover(imm_cmd, "ERR_010 immediate dtt>4 pre-DAT rejection");
  endtask

  virtual task run_unsupported_ccc_cases();
    immediate_data_trans_desc_t ccc_cmd;

    ccc_cmd                   = '0;
    ccc_cmd.attr              = ImmediateDataTransfer;
    ccc_cmd.tid               = 4'hA;
    ccc_cmd.cmd               = 8'h02;
    ccc_cmd.cp                = 1'b1;
    ccc_cmd.mode              = sdr0;
    ccc_cmd.dtt               = 3'd1;
    ccc_cmd.toc               = 1'b1;
    ccc_cmd.wroc              = 1'b1;
    ccc_cmd.dev_idx           = 5'd0;
    ccc_cmd.def_or_data_byte1 = 8'h01;
    issue_invalid_and_recover(ccc_cmd, "ERR_010 unsupported broadcast CCC 0x02");

    ccc_cmd                   = '0;
    ccc_cmd.attr              = ImmediateDataTransfer;
    ccc_cmd.tid               = 4'hB;
    ccc_cmd.cmd               = 8'h82;
    ccc_cmd.cp                = 1'b1;
    ccc_cmd.mode              = sdr0;
    ccc_cmd.dtt               = 3'd1;
    ccc_cmd.toc               = 1'b1;
    ccc_cmd.wroc              = 1'b1;
    ccc_cmd.dev_idx           = 5'd0;
    ccc_cmd.def_or_data_byte1 = 8'h01;
    issue_invalid_and_recover(ccc_cmd, "ERR_010 unsupported direct CCC 0x82");
  endtask

  virtual task run_invalid_regular_cp_case();
    regular_trans_desc_t reg_cmd;

    reg_cmd             = '0;
    reg_cmd.attr        = RegularTransfer;
    reg_cmd.tid         = 4'hC;
    reg_cmd.cmd         = 8'h00;
    reg_cmd.cp          = 1'b1;
    reg_cmd.mode        = sdr0;
    reg_cmd.toc         = 1'b1;
    reg_cmd.wroc        = 1'b1;
    reg_cmd.dev_idx     = 5'd0;
    reg_cmd.data_length = 16'd1;
    issue_invalid_and_recover(reg_cmd, "ERR_010 regular cp=1");
  endtask

  virtual task run_invalid_address_assignment_opcode_case();
    addr_assign_desc_t daa_cmd;

    daa_cmd           = '0;
    daa_cmd.attr      = AddressAssignment;
    daa_cmd.tid       = 4'hD;
    daa_cmd.cmd       = 8'h06;
    daa_cmd.dev_idx   = 5'd0;
    daa_cmd.dev_count = 4'd1;
    daa_cmd.toc       = 1'b1;
    daa_cmd.wroc      = 1'b1;
    issue_invalid_and_recover(daa_cmd, "ERR_010 AddressAssignment opcode is not ENTDAA");
  endtask

  virtual task issue_invalid_and_recover(bit [63:0] raw_desc, string ctxt);
    bit          monitor_done;
    bit          saw_dat_read;
    bit          saw_bus_activity;
    bit [31:0]   resp;

    monitor_done     = 1'b0;
    saw_dat_read     = 1'b0;
    saw_bus_activity = 1'b0;

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
        end
      end
      begin
        write_cmd(raw_desc[31:0], raw_desc[63:32]);
        poll_idle();
        settle_cycles(2);
        monitor_done = 1'b1;
      end
    join

    read_response(resp);
    `DV_CHECK_EQ(saw_dat_read, 1'b0, $sformatf("%s: invalid command accessed DAT", ctxt))
    `DV_CHECK_EQ(saw_bus_activity, 1'b0, $sformatf("%s: invalid command caused bus activity", ctxt))
    `DV_CHECK_EQ(resp[31:28], NotSupported, $sformatf("%s: response status", ctxt))
    `DV_CHECK_EQ(resp[27:24], raw_desc[6:3], $sformatf("%s: response TID", ctxt))
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
        .seq_name($sformatf("err010_recovery_%0d_dev_seq", recovery_tid)),
        .tid(recovery_tid),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
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
    `DV_CHECK_EQ(resp[31:28], Success, $sformatf("%s: recovery response status", cfg.ctxt))
    `DV_CHECK_EQ(resp[27:24], recovery_tid, $sformatf("%s: recovery response TID", cfg.ctxt))
    `DV_CHECK_EQ(resp[15:0], 16'd1, $sformatf("%s: recovery response length", cfg.ctxt))
    check_all_queues_empty($sformatf("%s completed", cfg.ctxt));
  endtask
endclass
