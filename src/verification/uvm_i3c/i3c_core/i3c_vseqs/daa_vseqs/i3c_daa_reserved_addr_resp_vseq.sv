class i3c_daa_reserved_addr_resp_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_daa_reserved_addr_resp_vseq)

  function new(string name = "i3c_daa_reserved_addr_resp_vseq");
    super.new(name);
  endfunction

  virtual task body();
    addr_assign_desc_t      daa_cmd;
    i3c_device_response_seq dev_seq;
    i3c_response_desc_t     resp_desc;
    bit              [31:0] resp;
    string                  ctxt;

    ctxt = "DAA_008 ENTDAA reserved assigned address";

    enable_dut();
    write_dat_entry(0, 7'h50, 7'h7E, 1'b0);

    daa_cmd           = '0;
    daa_cmd.attr      = AddressAssignment;
    daa_cmd.tid       = 4'hE;
    daa_cmd.cmd       = ENTDAA;
    daa_cmd.dev_idx   = 5'd0;
    daa_cmd.dev_count = 4'd1;
    daa_cmd.wroc      = 1'b1;
    daa_cmd.toc       = 1'b1;

    dev_seq = i3c_device_response_seq::type_id::create("daa008_entdaa_opening_ack_seq");
    dev_seq.target_addr = 7'h7e;
    dev_seq.addr_nack = 1'b0;
    dev_seq.is_i3c = 1'b1;
    dev_seq.dir = 1'b0;
    dev_seq.entdaa_join = 1'b0;

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 3000);
    read_response(resp);

    resp_desc = i3c_response_desc_t'(resp);
    `DV_CHECK_EQ(resp_desc.err_status, NotSupported, $sformatf("%s: response status", ctxt))
    `DV_CHECK_EQ(resp_desc.tid, daa_cmd.tid, $sformatf("%s: response TID", ctxt))
    `DV_CHECK_EQ(resp_desc.__rsvd23_16, 8'h00, $sformatf("%s: response reserved bits", ctxt))
    `DV_CHECK_EQ(resp_desc.data_length, 16'h0000, $sformatf("%s: response length", ctxt))

    check_all_queues_empty($sformatf("after %s", ctxt));
    disable device_response;
  endtask
endclass
