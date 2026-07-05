class i3c_daa_multi_device_dat_loop_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_daa_multi_device_dat_loop_vseq)

  localparam int unsigned FIRST_DAT_IDX = 2;
  localparam int unsigned DEVICE_COUNT = 3;

  function new(string name = "i3c_daa_multi_device_dat_loop_vseq");
    super.new(name);
  endfunction

  virtual function bit [63:0] daa_identity(i3c_daa_stimulus stimulus);
    return {stimulus.pid, stimulus.bcr, stimulus.dcr};
  endfunction

  virtual function void sort_winner_order(input i3c_daa_stimulus stimulus[DEVICE_COUNT],
                                          output int unsigned order[DEVICE_COUNT]);
    int unsigned tmp;

    for (int unsigned i = 0; i < DEVICE_COUNT; i++) begin
      order[i] = i;
    end
    for (int unsigned i = 0; i < DEVICE_COUNT; i++) begin
      for (int unsigned j = i + 1; j < DEVICE_COUNT; j++) begin
        if (daa_identity(stimulus[order[j]]) < daa_identity(stimulus[order[i]])) begin
          tmp = order[i];
          order[i] = order[j];
          order[j] = tmp;
        end
      end
    end
  endfunction

  virtual function bit [31:0] expected_pid_word0(i3c_daa_stimulus stimulus);
    return {stimulus.pid[47:40], stimulus.pid[39:32], stimulus.pid[31:24], stimulus.pid[23:16]};
  endfunction

  virtual function bit [31:0] expected_pid_word1(i3c_daa_stimulus stimulus);
    return {stimulus.pid[15:8], stimulus.pid[7:0], stimulus.bcr, stimulus.dcr};
  endfunction

  virtual function void configure_joining_device(i3c_device_response_seq dev_seq,
                                                 i3c_daa_stimulus stimulus);
    dev_seq.target_addr = 7'h7e;
    dev_seq.addr_nack = 1'b0;
    dev_seq.is_i3c = 1'b1;
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
  endfunction

  virtual task body();
    addr_assign_desc_t             daa_cmd;
    bit                     [31:0] resp;
    word_queue_t                   rx_words;
    i3c_device_response_seq        dev_seq     [DEVICE_COUNT];
    i3c_daa_stimulus               stimulus    [DEVICE_COUNT];
    int unsigned                   winner_order[DEVICE_COUNT];

    for (int unsigned i = 0; i < DEVICE_COUNT; i++) begin
      stimulus[i] = i3c_daa_stimulus::type_id::create($sformatf("daa004_stimulus_%0d", i));
    end

    `DV_CHECK_RANDOMIZE_FATAL(stimulus[0], "DAA_004 stimulus[0] randomization failed")
    if (!stimulus[1].randomize() with {assigned_addr != local:: stimulus[0].assigned_addr;}) begin
      `uvm_fatal(`gfn, "DAA_004 stimulus[1] randomization failed")
    end
    if (!stimulus[2].randomize() with {
          assigned_addr != local:: stimulus[0].assigned_addr;
          assigned_addr != local:: stimulus[1].assigned_addr;
        }) begin
      `uvm_fatal(`gfn, "DAA_004 stimulus[2] randomization failed")
    end

    // Present resolved winners in legal ENTDAA arbitration order. Targets 1 and 2 differ only
    // in DCR, while target 0 appears in a later round because it has the larger PID.
    stimulus[0].pid = 48'h3000_0000_0000;
    stimulus[0].bcr = 8'h10;
    stimulus[0].dcr = 8'h30;
    stimulus[1].pid = 48'h0123_4567_89ab;
    stimulus[1].bcr = 8'h22;
    stimulus[1].dcr = 8'hf0;
    stimulus[2].pid = 48'h0123_4567_89ab;
    stimulus[2].bcr = 8'h22;
    stimulus[2].dcr = 8'h0f;
    sort_winner_order(stimulus, winner_order);

    enable_dut();
    for (int unsigned i = 0; i < DEVICE_COUNT; i++) begin
      dev_seq[i] = i3c_device_response_seq::type_id::create($sformatf("daa004_dev_seq_%0d", i));
      configure_joining_device(dev_seq[i], stimulus[i]);
    end
    for (int unsigned round = 0; round < DEVICE_COUNT; round++) begin
      int unsigned winner;

      winner = winner_order[round];
      write_dat_entry(FIRST_DAT_IDX + round, 7'h00, stimulus[winner].assigned_addr, 1'b0);
    end

    daa_cmd           = '0;
    daa_cmd.attr      = AddressAssignment;
    daa_cmd.tid       = 4'd4;
    daa_cmd.cmd       = ENTDAA;
    daa_cmd.dev_idx   = FIRST_DAT_IDX;
    daa_cmd.dev_count = DEVICE_COUNT;
    daa_cmd.wroc      = 1'b1;
    daa_cmd.toc       = 1'b1;

    fork : device_response
      dev_seq[winner_order[0]].start(p_sequencer.m_i3c_sequencer);
      begin
        wait (dev_seq[winner_order[0]].request_issued);
        dev_seq[winner_order[1]].start(p_sequencer.m_i3c_sequencer);
      end
      begin
        wait (dev_seq[winner_order[1]].request_issued);
        dev_seq[winner_order[2]].start(p_sequencer.m_i3c_sequencer);
      end
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);

    poll_idle();
    for (int unsigned round = 0; round < DEVICE_COUNT; round++) begin
      wait_for_device_done(dev_seq[winner_order[round]], $sformatf("DAA_004 device round %0d", round
                           ), 3000);
    end

    read_rx_words(DEVICE_COUNT * 12, rx_words);
    read_response(resp);

    for (int unsigned round = 0; round < DEVICE_COUNT; round++) begin
      int unsigned winner;

      winner = winner_order[round];
      `DV_CHECK_EQ(rx_words[(round*3)+0], expected_pid_word0(stimulus[winner]), $sformatf(
                   "DAA_004 winner[%0d] PID word0", round))
      `DV_CHECK_EQ(rx_words[(round*3)+1], expected_pid_word1(stimulus[winner]), $sformatf(
                   "DAA_004 winner[%0d] PID/BCR/DCR word1", round))
    end

    check_all_queues_empty("after DAA_004 multi-device DAT loop");

    disable device_response;
  endtask
endclass
