class i3c_ccc_direct_disec_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_ccc_direct_disec_vseq)

  function new(string name = "i3c_ccc_direct_disec_vseq");
    super.new(name);
  endfunction

  virtual task body();
    immediate_data_trans_desc_t        ccc_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;
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
    ccc_cmd.cmd               = DIR_DISEC;
    ccc_cmd.mode              = sdr0;
    ccc_cmd.dtt               = 3'd4;
    ccc_cmd.rnw               = 1'b0;
    ccc_cmd.toc               = 1'b1;
    ccc_cmd.wroc              = 1'b1;
    ccc_cmd.dev_idx           = 5'd0;
    ccc_cmd.def_or_data_byte1 = event_byte;

    dev_seq                       = i3c_device_response_seq::type_id::create("ccc005_dev_seq");
    dev_seq.target_addr           = 7'h7e;
    dev_seq.ack_address           = 1'b1;
    dev_seq.is_i3c                = 1'b1;
    dev_seq.dir                   = 1'b0;
    dev_seq.ccc_target_addr       = target_addr;
    dev_seq.ccc_target_addr_valid = 1'b1;

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(ccc_cmd[31:0], ccc_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, "CCC_005 direct DISEC frame", 2000);
    settle_cycles(4);

    `DV_CHECK_GE(dev_seq.sampled_addr_q.size(), 2, "ccc_005: expected broadcast and target address phases")
    if (dev_seq.sampled_addr_q.size() >= 2) begin
      `DV_CHECK_EQ(dev_seq.sampled_addr_q[0], 7'h7e, "ccc_005: broadcast address mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_dir_q[0], 1'b0, "ccc_005: broadcast direction should be write")
      `DV_CHECK_EQ(dev_seq.sampled_addr_q[1], target_addr, "ccc_005: target address mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_dir_q[1], 1'b0, "ccc_005: target direction should be write")
    end
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), 2, "ccc_005: expected opcode and Target Events byte")
    if (dev_seq.sampled_data.size() >= 2) begin
      `DV_CHECK_EQ(dev_seq.sampled_data[0], 8'(DIR_DISEC),
                   "ccc_005: direct DISEC opcode mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data[1], event_byte, "ccc_005: Target Events byte mismatch")
    end
    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), 2, "ccc_005: expected opcode and event T-bits")
    if (dev_seq.sampled_t_bit.size() >= 2) begin
      `DV_CHECK_EQ(dev_seq.sampled_t_bit[0], ~^8'(DIR_DISEC),
                   "ccc_005: direct DISEC opcode T-bit mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_t_bit[1], ~^event_byte,
                   "ccc_005: event byte T-bit mismatch")
    end
    `DV_CHECK_EQ(dev_seq.observed_broadcast_rstart, 1'b1,
                 "ccc_005: direct DISEC should issue repeated START after opcode")
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b0,
                 "ccc_005: direct DISEC should stop after target data phase")

    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0, "ccc_005: expected Success response")
    `DV_CHECK_EQ(resp[27:24], 4'd5, "ccc_005: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], 16'd1, "ccc_005: response length should count event byte")

    check_all_queues_empty("after CCC_005 direct DISEC frame");
    `uvm_info(`gfn, $sformatf(
                  "CCC_005 result: resp=0x%08h opcode=0x%02h target=0x%02h event=0x%02h",
                  resp,
                  (dev_seq.sampled_data.size() >= 1) ? dev_seq.sampled_data[0] : 8'h00,
                  (dev_seq.sampled_addr_q.size() >= 2) ? dev_seq.sampled_addr_q[1] : 7'h00,
                  (dev_seq.sampled_data.size() >= 2) ? dev_seq.sampled_data[1] : 8'h00),
              UVM_LOW)

    disable device_response;
  endtask
endclass
