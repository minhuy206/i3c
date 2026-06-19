class i3c_ccc_direct_disec_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_ccc_direct_disec_vseq)

  function new(string name = "i3c_ccc_direct_disec_vseq");
    super.new(name);
  endfunction

  virtual task body();
    immediate_data_trans_desc_t        ccc_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            bcast_seq;
    i3c_device_response_seq            target_seq;
    bit                          [6:0] target_addr;
    bit                          [7:0] event_byte;

    target_addr = 7'h08;
    event_byte  = 8'h02;

    enable_dut();
    write_dat_entry(0, 7'h50, target_addr, 1'b0);

    ccc_cmd                   = '0;
    ccc_cmd.attr              = ImmediateDataTransfer;
    ccc_cmd.tid               = 4'd5;
    ccc_cmd.cp                = 1'b1;
    ccc_cmd.cmd               = 8'h81;
    ccc_cmd.mode              = sdr0;
    ccc_cmd.dtt               = 3'd4;
    ccc_cmd.rnw               = 1'b0;
    ccc_cmd.toc               = 1'b1;
    ccc_cmd.wroc              = 1'b1;
    ccc_cmd.dev_idx           = 5'd0;
    ccc_cmd.def_or_data_byte1 = event_byte;

    bcast_seq                 = i3c_device_response_seq::type_id::create("ccc005_bcast_seq");
    bcast_seq.target_addr     = 7'h7e;
    bcast_seq.ack_address     = 1'b1;
    bcast_seq.is_i3c          = 1'b1;
    bcast_seq.dir             = 1'b0;
    bcast_seq.read_data_cnt   = 1;

    target_seq               = i3c_device_response_seq::type_id::create("ccc005_target_seq");
    target_seq.target_addr   = target_addr;
    target_seq.ack_address   = 1'b1;
    target_seq.is_i3c        = 1'b1;
    target_seq.dir           = 1'b0;
    target_seq.read_data_cnt = 1;

    fork : device_response
      begin
        bcast_seq.start(p_sequencer.m_i3c_sequencer);
      end
      begin
        wait_for_device_request_issued(bcast_seq, "CCC_005 broadcast leg");
        target_seq.start(p_sequencer.m_i3c_sequencer);
      end
    join_none

    write_cmd(ccc_cmd[31:0], ccc_cmd[63:32]);

    poll_idle();
    wait_for_device_done(bcast_seq, "CCC_005 direct DISEC broadcast leg", 2000);
    wait_for_device_done(target_seq, "CCC_005 direct DISEC target leg", 2000);
    settle_cycles(4);

    `DV_CHECK_EQ(bcast_seq.sampled_addr, 7'h7e, "ccc_005: broadcast address mismatch")
    `DV_CHECK_EQ(bcast_seq.sampled_dir, 1'b0, "ccc_005: broadcast direction should be write")
    `DV_CHECK_EQ(bcast_seq.sampled_data.size(), 1, "ccc_005: expected direct DISEC opcode")
    if (bcast_seq.sampled_data.size() >= 1) begin
      `DV_CHECK_EQ(bcast_seq.sampled_data[0], 8'h81, "ccc_005: direct DISEC opcode mismatch")
    end
    `DV_CHECK_EQ(bcast_seq.sampled_t_bit.size(), 1, "ccc_005: expected opcode T-bit")
    if (bcast_seq.sampled_t_bit.size() >= 1) begin
      `DV_CHECK_EQ(bcast_seq.sampled_t_bit[0], ~^8'h81,
                   "ccc_005: direct DISEC opcode T-bit mismatch")
    end
    `DV_CHECK_EQ(bcast_seq.observed_rstart, 1'b1,
                 "ccc_005: direct DISEC should issue repeated START after opcode")

    `DV_CHECK_EQ(target_seq.sampled_addr, target_addr, "ccc_005: target address mismatch")
    `DV_CHECK_EQ(target_seq.sampled_dir, 1'b0, "ccc_005: target direction should be write")
    `DV_CHECK_EQ(target_seq.sampled_data.size(), 1, "ccc_005: expected one Target Events byte")
    if (target_seq.sampled_data.size() >= 1) begin
      `DV_CHECK_EQ(target_seq.sampled_data[0], event_byte,
                   "ccc_005: Target Events byte mismatch")
    end
    `DV_CHECK_EQ(target_seq.sampled_t_bit.size(), 1, "ccc_005: expected event byte T-bit")
    if (target_seq.sampled_t_bit.size() >= 1) begin
      `DV_CHECK_EQ(target_seq.sampled_t_bit[0], ~^event_byte,
                   "ccc_005: event byte T-bit mismatch")
    end
    `DV_CHECK_EQ(target_seq.observed_rstart, 1'b0,
                 "ccc_005: direct DISEC should stop after target data phase")

    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0, "ccc_005: expected Success response")
    `DV_CHECK_EQ(resp[27:24], 4'd5, "ccc_005: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], 16'd1, "ccc_005: response length should count event byte")

    check_all_queues_empty("after CCC_005 direct DISEC frame");
    `uvm_info(`gfn, $sformatf(
                  "CCC_005 result: resp=0x%08h opcode=0x%02h target=0x%02h event=0x%02h",
                  resp,
                  (bcast_seq.sampled_data.size() >= 1) ? bcast_seq.sampled_data[0] : 8'h00,
                  target_seq.sampled_addr,
                  (target_seq.sampled_data.size() >= 1) ? target_seq.sampled_data[0] : 8'h00),
              UVM_LOW)

    disable device_response;
  endtask
endclass
