class i3c_daa_address_rejected_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_daa_address_rejected_vseq)

  function new(string name = "i3c_daa_address_rejected_vseq");
    super.new(name);
  endfunction

  virtual function void configure_rejecting_device(i3c_device_response_seq dev_seq,
                                                   i3c_daa_stimulus stimulus);
    dev_seq.target_addr     = 7'h7e;
    dev_seq.addr_nack     = 1'b0;
    dev_seq.is_i3c          = 1'b1;
    dev_seq.is_daa          = 1'b1;
    dev_seq.dir             = 1'b0;
    dev_seq.entdaa_join     = 1'b1;
    dev_seq.daa_accept_addr = 1'b0;
    dev_seq.daa_id_bytes    = '{
      stimulus.pid[47:40],
      stimulus.pid[39:32],
      stimulus.pid[31:24],
      stimulus.pid[23:16],
      stimulus.pid[15:8],
      stimulus.pid[7:0],
      stimulus.bcr,
      stimulus.dcr
    };
  endfunction

  virtual task body();
    addr_assign_desc_t      daa_cmd;
    bit [31:0]              resp;
    i3c_device_response_seq reject_seq[2];
    i3c_daa_stimulus        stimulus;

    stimulus = i3c_daa_stimulus::type_id::create("daa006_stimulus");
    `DV_CHECK_RANDOMIZE_FATAL(stimulus, "DAA_006 stimulus randomization failed")

    enable_dut();
    write_dat_entry(0, 7'h00, stimulus.assigned_addr, 1'b0);

    for (int unsigned i = 0; i < 2; i++) begin
      reject_seq[i] = i3c_device_response_seq::type_id::create(
          $sformatf("daa006_reject_seq_%0d", i)
      );
      configure_rejecting_device(reject_seq[i], stimulus);
    end

    daa_cmd           = '0;
    daa_cmd.attr      = AddressAssignment;
    daa_cmd.tid       = 4'd6;
    daa_cmd.cmd       = ENTDAA;
    daa_cmd.dev_idx   = 5'd0;
    daa_cmd.dev_count = 4'd1;
    daa_cmd.wroc      = 1'b1;
    daa_cmd.toc       = 1'b1;

    fork : device_response
      reject_seq[0].start(p_sequencer.m_i3c_sequencer);
      begin
        wait (reject_seq[0].request_issued);
        reject_seq[1].start(p_sequencer.m_i3c_sequencer);
      end
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);

    poll_idle();
    wait_for_device_done(reject_seq[0], "DAA_006 first address rejection", 3000);
    wait_for_device_done(reject_seq[1], "DAA_006 second address rejection", 3000);

    read_response(resp);

    check_all_queues_empty("after DAA_006 repeated address rejection");
    `uvm_info(`gfn, $sformatf(
                  "DAA_006 result: resp=0x%08h rejected_addr=0x%02h pid=0x%012h",
                  resp, stimulus.assigned_addr, stimulus.pid), UVM_LOW)

    disable device_response;
  endtask
endclass
