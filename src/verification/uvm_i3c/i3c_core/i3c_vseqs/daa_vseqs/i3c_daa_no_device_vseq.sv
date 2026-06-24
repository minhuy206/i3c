class i3c_daa_no_device_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_daa_no_device_vseq)

  function new(string name = "i3c_daa_no_device_vseq");
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
    daa_cmd.tid       = 4'd2;
    daa_cmd.cmd       = ENTDAA;
    daa_cmd.dev_idx   = 5'd0;
    daa_cmd.dev_count = 4'd1;
    daa_cmd.wroc      = 1'b1;
    daa_cmd.toc       = 1'b1;

    dev_seq             = i3c_device_response_seq::type_id::create("daa002_dev_seq");
    dev_seq.target_addr = 7'h7e;
    dev_seq.ack_address = 1'b1;
    dev_seq.is_i3c      = 1'b1;
    dev_seq.is_daa      = 1'b1;
    dev_seq.dir         = 1'b0;
    dev_seq.entdaa_join = 1'b0;

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, "DAA_002 ENTDAA no-device exit", 2000);

    read_response(resp);

    check_all_queues_empty("after DAA_002 ENTDAA no-device exit");
    `uvm_info(`gfn, $sformatf(
                  "DAA_002 result: resp=0x%08h opcode=0x%02h observed_rstart=%0b",
                  resp,
                  (dev_seq.sampled_data.size() >= 1) ? dev_seq.sampled_data[0] : 8'h00,
                  dev_seq.observed_rstart), UVM_LOW)

    disable device_response;
  endtask
endclass
