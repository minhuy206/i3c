class i3c_daa_single_device_success_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_daa_single_device_success_vseq)

  function new(string name = "i3c_daa_single_device_success_vseq");
    super.new(name);
  endfunction

  virtual task body();
    addr_assign_desc_t             daa_cmd;
    bit                     [31:0] resp;
    word_queue_t                   rx_words;
    i3c_device_response_seq        dev_seq;
    i3c_daa_stimulus               stimulus;

    stimulus = i3c_daa_stimulus::type_id::create("daa001_stimulus");
    `DV_CHECK_RANDOMIZE_FATAL(stimulus, "daa_001: stimulus randomization failed")

    enable_dut();
    write_dat_entry(0, 7'h50, stimulus.assigned_addr, 1'b0);

    daa_cmd = '0;
    daa_cmd.attr = AddressAssignment;
    daa_cmd.tid = 4'd1;
    daa_cmd.cmd = ENTDAA;
    daa_cmd.dev_idx = 5'd0;
    daa_cmd.dev_count = 4'd1;
    daa_cmd.wroc = 1'b1;
    daa_cmd.toc = 1'b1;

    dev_seq = i3c_device_response_seq::type_id::create("daa001_dev_seq");
    dev_seq.target_addr = 7'h7e;
    dev_seq.addr_nack = 1'b0;
    dev_seq.is_i3c = 1'b1;
    dev_seq.is_daa = 1'b1;
    dev_seq.dir = 1'b0;
    dev_seq.entdaa_join = 1'b1;
    dev_seq.daa_accept_addr = 1'b1;
    dev_seq.daa_id_bytes = '{
        stimulus.pid[47:40],
        stimulus.pid[39:32],
        stimulus.pid[31:24],
        stimulus.pid[23:16],
        stimulus.pid[15:8],
        stimulus.pid[7:0],
        stimulus.bcr,
        stimulus.dcr
    };

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, "DAA_001 ENTDAA single-device success", 3000);

    read_rx_words(12, rx_words);
    read_response(resp);

    check_all_queues_empty("after DAA_001 ENTDAA single-device success");
    disable device_response;
  endtask
endclass
