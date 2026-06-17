class i3c_imm_abort_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_imm_abort_vseq)

  localparam bit [3:0] FSM_I3C_WRITE_IMM = 4'd5;
  localparam bit [3:0] FSM_I2C_WRITE_IMM = 4'd6;
  localparam bit [3:0] RESP_HC_ABORTED = 4'h8;

  localparam int unsigned IMM_ABORT_FSM_TIMEOUT = 5000;

  function new(string name = "i3c_imm_abort_vseq");
    super.new(name);
  endfunction

  virtual function void check_abort_result(bit [31:0] resp, byte_queue_t sampled,
                                           bit [7:0] expected[4], string ctxt);
    `DV_CHECK_EQ(resp[31:28], RESP_HC_ABORTED, $sformatf("%s: expected RESP HcAborted (4'h8)", ctxt
                 ))
    foreach (sampled[i]) begin
      `DV_CHECK_EQ(sampled[i], expected[i], $sformatf("%s: pre-abort byte %0d mismatch", ctxt, i))
    end
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_i3c_imm_abort_case(broadcast_modes[mode_idx]);
    end
    run_i2c_imm_abort_case();

    `uvm_info(
        `gfn,
        "IMM_006 conclusion: HC abort during immediate data phase reaches idle and SW reset flushes queues in all three cases (private I3C, broadcast I3C, I2C)",
        UVM_LOW)
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

    wait_for_flow_fsm_state(
        FSM_I3C_WRITE_IMM, $sformatf(
        "IMM_006 %s I3C: wait for I3CWriteImmediate", private_addr_mode_name(bcast_en)),
        IMM_ABORT_FSM_TIMEOUT);

    reg_write(ADDR_HC_CONTROL, {28'h0, 1'b1  /*HC_ABORT*/, bcast_en, 1'b0  /*SW_RST*/, 1'b1  /*EN*/
              });
    `uvm_info(`gfn, $sformatf("IMM_006 %s I3C: abort_asserted=1 while in I3CWriteImmediate",
                              private_addr_mode_name(bcast_en)), UVM_LOW)

    poll_idle();
    wait_for_device_done(dev_seq, $sformatf("IMM_006 %s I3C", private_addr_mode_name(bcast_en)),
                         10000);
    read_response(resp);

    reg_write(ADDR_HC_CONTROL, {28'h0, 1'b0  /*abort off*/, bcast_en, 1'b0, 1'b1});
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty(
        $sformatf("IMM_006 %s I3C: after recovery SW reset", private_addr_mode_name(bcast_en)));

    check_abort_result(resp, dev_seq.sampled_data, '{8'hA1, 8'hA2, 8'hA3, 8'hA4}, $sformatf(
                       "IMM_006 %s I3C", private_addr_mode_name(bcast_en)));

    `uvm_info(`gfn, $sformatf("IMM_006 result: mode=%s device=I3C resp=0x%08h sampled_bytes=%0d",
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

    wait_for_flow_fsm_state(FSM_I2C_WRITE_IMM, "IMM_006 I2C: wait for I2CWriteImmediate",
                            IMM_ABORT_FSM_TIMEOUT);

    reg_write(ADDR_HC_CONTROL, {
              28'h0, 1'b1  /*HC_ABORT*/, 1'b0  /*bcast_en*/, 1'b0  /*SW_RST*/, 1'b1  /*EN*/});
    `uvm_info(`gfn, "IMM_006 I2C: abort_asserted=1 while in I2CWriteImmediate", UVM_LOW)

    poll_idle();
    wait_for_device_done(dev_seq, "IMM_006 I2C", i2c_device_done_timeout_cycles(4));
    read_response(resp);

    reg_write(ADDR_HC_CONTROL, {28'h0, 1'b0  /*abort off*/, 1'b0, 1'b0, 1'b1});
    request_sw_reset(.keep_enabled(1'b1));
    check_all_queues_empty("IMM_006 I2C: after recovery SW reset");

    check_abort_result(resp, dev_seq.sampled_data, '{8'hB1, 8'hB2, 8'hB3, 8'hB4}, "IMM_006 I2C");

    `uvm_info(`gfn, $sformatf("IMM_006 result: device=I2C resp=0x%08h sampled_bytes=%0d", resp,
                              dev_seq.sampled_data.size()), UVM_LOW)
  endtask

endclass
