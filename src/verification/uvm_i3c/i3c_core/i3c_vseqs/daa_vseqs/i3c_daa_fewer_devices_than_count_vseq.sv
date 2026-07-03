class i3c_daa_fewer_devices_than_count_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_daa_fewer_devices_than_count_vseq)

  function new(string name = "i3c_daa_fewer_devices_than_count_vseq");
    super.new(name);
  endfunction

  virtual task body();
    addr_assign_desc_t             daa_cmd;
    bit                     [31:0] resp;
    word_queue_t                   rx_words;
    i3c_device_response_seq        assigned_dev_seq;
    i3c_device_response_seq        no_device_seq;
    i3c_daa_stimulus               stimulus;

    stimulus = i3c_daa_stimulus::type_id::create("daa003_stimulus");
    `DV_CHECK_RANDOMIZE_FATAL(stimulus, "daa_003: stimulus randomization failed")

    enable_dut();
    write_dat_entry(0, 7'h00, stimulus.assigned_addr, 1'b0);
    write_dat_entry(1, 7'h00, 7'h08, 1'b0);

    daa_cmd = '0;
    daa_cmd.attr = AddressAssignment;
    daa_cmd.tid = 4'd3;
    daa_cmd.cmd = ENTDAA;
    daa_cmd.dev_idx = 5'd0;
    daa_cmd.dev_count = 4'd2;
    daa_cmd.wroc = 1'b1;
    daa_cmd.toc = 1'b1;

    assigned_dev_seq = i3c_device_response_seq::type_id::create("daa003_assigned_dev_seq");
    assigned_dev_seq.target_addr = 7'h7e;
    assigned_dev_seq.addr_nack = 1'b0;
    assigned_dev_seq.is_i3c = 1'b1;
    assigned_dev_seq.is_daa = 1'b1;
    assigned_dev_seq.dir = 1'b0;
    assigned_dev_seq.entdaa_join = 1'b1;
    assigned_dev_seq.daa_accept_addr = 1'b1;
    assigned_dev_seq.daa_id_bytes = '{
        stimulus.pid[47:40],
        stimulus.pid[39:32],
        stimulus.pid[31:24],
        stimulus.pid[23:16],
        stimulus.pid[15:8],
        stimulus.pid[7:0],
        stimulus.bcr,
        stimulus.dcr
    };

    no_device_seq = i3c_device_response_seq::type_id::create("daa003_no_device_seq");
    no_device_seq.target_addr = 7'h7e;
    no_device_seq.addr_nack = 1'b1;
    no_device_seq.is_i3c = 1'b1;
    no_device_seq.is_daa = 1'b1;
    no_device_seq.dir = 1'b0;
    no_device_seq.entdaa_join = 1'b0;

    fork : device_response
      begin
        assigned_dev_seq.start(p_sequencer.m_i3c_sequencer);
      end
      begin
        wait (assigned_dev_seq.request_issued);
        no_device_seq.start(p_sequencer.m_i3c_sequencer);
      end
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);

    poll_idle();
    wait_for_device_done(assigned_dev_seq, "DAA_003 assigned-device round", 3000);
    wait_for_device_done(no_device_seq, "DAA_003 no-device exit round", 2000);

    read_rx_words(12, rx_words);
    read_response(resp);

    check_all_queues_empty("after DAA_003 fewer-devices-than-count exit");
    disable device_response;
  endtask
endclass
