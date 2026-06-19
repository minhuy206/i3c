class i3c_ccc_entdaa_opening_frame_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_ccc_entdaa_opening_frame_vseq)

  function new(string name = "i3c_ccc_entdaa_opening_frame_vseq");
    super.new(name);
  endfunction

  virtual task body();
    addr_assign_desc_t      daa_cmd;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    daa_cmd           = '0;
    daa_cmd.attr      = AddressAssignment;
    daa_cmd.tid       = 4'd1;
    daa_cmd.cmd       = 8'h07;
    daa_cmd.dev_idx   = 5'd0;
    daa_cmd.dev_count = 4'd1;
    daa_cmd.wroc      = 1'b1;
    daa_cmd.toc       = 1'b1;

    dev_seq               = i3c_device_response_seq::type_id::create("ccc001_dev_seq");
    dev_seq.target_addr   = 7'h7e;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = 1;

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, "CCC_001 ENTDAA opening frame", 2000);

    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h7e, "ccc_001: broadcast address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0, "ccc_001: broadcast direction should be write")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), 1, "ccc_001: expected only ENTDAA opcode")

    if (dev_seq.sampled_data.size() >= 1) begin
      `DV_CHECK_EQ(dev_seq.sampled_data[0], 8'h07, "ccc_001: ENTDAA opcode mismatch")
    end

    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), 1, "ccc_001: expected ENTDAA opcode T-bit")
    if (dev_seq.sampled_t_bit.size() >= 1) begin
      `DV_CHECK_EQ(dev_seq.sampled_t_bit[0], ~^8'h07, "ccc_001: ENTDAA opcode T-bit mismatch")
    end
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b1,
                 "ccc_001: expected repeated START before ENTDAA 7'h7E+R round")

    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0,  "ccc_001: expected Success response")
    `DV_CHECK_EQ(resp[27:24], 4'd1,  "ccc_001: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0],  16'd0, "ccc_001: no-device ENTDAA opening should not return data")

    check_all_queues_empty("after CCC_001 ENTDAA opening frame");
    `uvm_info(`gfn, $sformatf(
                  "CCC_001 result: resp=0x%08h opcode=0x%02h observed_rstart=%0b",
                  resp,
                  (dev_seq.sampled_data.size() >= 1) ? dev_seq.sampled_data[0] : 8'h00,
                  dev_seq.observed_rstart), UVM_LOW)

    disable device_response;
  endtask
endclass
