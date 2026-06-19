class i3c_ccc_broadcast_disec_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_ccc_broadcast_disec_vseq)

  function new(string name = "i3c_ccc_broadcast_disec_vseq");
    super.new(name);
  endfunction

  virtual task body();
    immediate_data_trans_desc_t        ccc_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;
    bit                          [7:0] event_byte;

    event_byte = 8'h02;

    enable_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    ccc_cmd                   = '0;
    ccc_cmd.attr              = ImmediateDataTransfer;
    ccc_cmd.tid               = 4'd3;
    ccc_cmd.cp                = 1'b1;
    ccc_cmd.cmd               = 8'h01;
    ccc_cmd.mode              = sdr0;
    ccc_cmd.dtt               = 3'd4;
    ccc_cmd.rnw               = 1'b0;
    ccc_cmd.toc               = 1'b1;
    ccc_cmd.wroc              = 1'b1;
    ccc_cmd.dev_idx           = 5'd0;
    ccc_cmd.def_or_data_byte1 = event_byte;

    dev_seq                   = i3c_device_response_seq::type_id::create("ccc003_dev_seq");
    dev_seq.target_addr       = 7'h7e;
    dev_seq.ack_address       = 1'b1;
    dev_seq.is_i3c            = 1'b1;
    dev_seq.dir               = 1'b0;
    dev_seq.read_data_cnt     = 2;

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(ccc_cmd[31:0], ccc_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, "CCC_003 broadcast DISEC frame", 2000);

    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h7e, "ccc_003: broadcast address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0, "ccc_003: broadcast direction should be write")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), 2, "ccc_003: expected CCC opcode and event byte")

    if (dev_seq.sampled_data.size() >= 2) begin
      `DV_CHECK_EQ(dev_seq.sampled_data[0], 8'h01, "ccc_003: DISEC opcode mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data[1], event_byte, "ccc_003: Target Events byte mismatch")
    end

    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), 2, "ccc_003: expected two controller T-bits")
    if (dev_seq.sampled_t_bit.size() >= 2) begin
      `DV_CHECK_EQ(dev_seq.sampled_t_bit[0], ~^8'h01, "ccc_003: DISEC opcode T-bit mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_t_bit[1], ~^event_byte,
                   "ccc_003: event byte T-bit mismatch")
    end
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b0,
                 "ccc_003: broadcast DISEC should not enter ENTDAA or direct CCC phase")

    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0, "ccc_003: expected Success response")
    `DV_CHECK_EQ(resp[27:24], 4'd3, "ccc_003: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], 16'd1, "ccc_003: response length should count event byte")

    check_all_queues_empty("after CCC_003 broadcast DISEC frame");
    `uvm_info(`gfn, $sformatf("CCC_003 result: resp=0x%08h opcode=0x%02h event=0x%02h",
                              resp,
                              (dev_seq.sampled_data.size() >= 1) ? dev_seq.sampled_data[0] : 8'h00,
                              (dev_seq.sampled_data.size() >= 2) ? dev_seq.sampled_data[1] : 8'h00),
              UVM_LOW)

    disable device_response;
  endtask
endclass
