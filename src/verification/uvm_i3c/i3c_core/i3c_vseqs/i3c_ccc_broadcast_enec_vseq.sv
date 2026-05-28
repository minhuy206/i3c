class i3c_ccc_broadcast_enec_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_ccc_broadcast_enec_vseq)

  function new(string name = "i3c_ccc_broadcast_enec_vseq");
    super.new(name);
  endfunction

  virtual task body();
    immediate_data_trans_desc_t ccc_cmd;
    bit [31:0]                  resp;
    i3c_device_response_seq     dev_seq;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    ccc_cmd                   = '0;
    ccc_cmd.attr              = ImmediateDataTransfer;
    ccc_cmd.tid               = 4'd2;
    ccc_cmd.cp                = 1'b1;
    ccc_cmd.cmd               = 8'h00;
    ccc_cmd.mode              = sdr0;
    ccc_cmd.dtt               = 3'd5;
    ccc_cmd.rnw               = 1'b0;
    ccc_cmd.toc               = 1'b1;
    ccc_cmd.wroc              = 1'b1;
    ccc_cmd.dev_idx           = 5'd0;
    ccc_cmd.def_or_data_byte1 = 8'h01;

    dev_seq               = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr   = 7'h7e;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = 2;

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(ccc_cmd[31:0], ccc_cmd[63:32]);

    poll_idle();

    for (int i = 0; i < 1000; i++) begin
      if (dev_seq.done) break;
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    end

    `DV_CHECK_EQ(dev_seq.done, 1'b1, "ccc_002: device response did not finish")
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h7e, "ccc_002: broadcast address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0, "ccc_002: broadcast direction should be write")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), 2, "ccc_002: expected CCC opcode and event byte")

    if (dev_seq.sampled_data.size() >= 2) begin
      `DV_CHECK_EQ(dev_seq.sampled_data[0], 8'h00, "ccc_002: ENEC opcode mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data[1], 8'h01, "ccc_002: Target Events byte mismatch")
    end

    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), 2, "ccc_002: expected two controller T-bits")
    if (dev_seq.sampled_t_bit.size() >= 2) begin
      `DV_CHECK_EQ(dev_seq.sampled_t_bit[0], ~^8'h00, "ccc_002: ENEC opcode T-bit mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_t_bit[1], ~^8'h01, "ccc_002: event byte T-bit mismatch")
    end

    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0,  "ccc_002: expected Success response")
    `DV_CHECK_EQ(resp[27:24], 4'd2,  "ccc_002: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0],  16'd1, "ccc_002: response length should count event byte")

    disable device_response;
  endtask
endclass
