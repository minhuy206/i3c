class i3c_entdaa_multi_target_arbitration_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_entdaa_multi_target_arbitration_vseq)

  function new(string name = "i3c_entdaa_multi_target_arbitration_vseq");
    super.new(name);
  endfunction

  virtual function bit [63:0] daa_identity(i3c_daa_arb_target_t target);
    return {target.pid, target.bcr, target.dcr};
  endfunction

  virtual function void sort_winner_order(input i3c_daa_arb_target_t targets[
                                          I3C_DAA_ARB_MAX_TARGETS],
                                          input int unsigned target_count,
                                          output int unsigned order[
                                          I3C_DAA_ARB_MAX_TARGETS]);
    int unsigned tmp;

    for (int unsigned i = 0; i < I3C_DAA_ARB_MAX_TARGETS; i++) begin
      order[i] = i;
    end

    for (int unsigned i = 0; i < target_count; i++) begin
      for (int unsigned j = i + 1; j < target_count; j++) begin
        if (daa_identity(targets[order[j]]) < daa_identity(targets[order[i]])) begin
          tmp = order[i];
          order[i] = order[j];
          order[j] = tmp;
        end
      end
    end
  endfunction

  virtual function bit [31:0] expected_pid_word0(i3c_daa_arb_target_t target);
    return {target.pid[47:40], target.pid[39:32], target.pid[31:24], target.pid[23:16]};
  endfunction

  virtual function bit [31:0] expected_pid_word1(i3c_daa_arb_target_t target);
    return {target.pid[15:8], target.pid[7:0], target.bcr, target.dcr};
  endfunction

  virtual function addr_assign_desc_t make_daa_cmd(bit [3:0] tid, bit [4:0] dev_idx,
                                                   bit [3:0] dev_count);
    addr_assign_desc_t cmd;

    cmd           = '0;
    cmd.attr      = AddressAssignment;
    cmd.tid       = tid;
    cmd.cmd       = ENTDAA;
    cmd.dev_idx   = dev_idx;
    cmd.dev_count = dev_count;
    cmd.wroc      = 1'b1;
    cmd.toc       = 1'b1;
    return cmd;
  endfunction

  virtual task run_arbitration_case(
      string ctxt, bit [3:0] tid, bit [4:0] first_dat_idx, int unsigned target_count,
      i3c_daa_arb_target_t targets[I3C_DAA_ARB_MAX_TARGETS],
      bit [6:0] assigned_addr[I3C_DAA_ARB_MAX_TARGETS]);
    addr_assign_desc_t      daa_cmd;
    i3c_device_response_seq dev_seq;
    word_queue_t            rx_words;
    bit [31:0]              resp;
    int unsigned            order[I3C_DAA_ARB_MAX_TARGETS];

    sort_winner_order(targets, target_count, order);

    for (int unsigned i = 0; i < target_count; i++) begin
      write_dat_entry(first_dat_idx + i, 7'h00, assigned_addr[i], 1'b0);
    end

    dev_seq = i3c_device_response_seq::type_id::create($sformatf("%s_dev_seq", ctxt));
    dev_seq.target_addr = 7'h7e;
    dev_seq.ack_address = 1'b1;
    dev_seq.is_i3c = 1'b1;
    dev_seq.is_daa = 1'b1;
    dev_seq.dir = 1'b0;
    dev_seq.daa_target_count = target_count;
    dev_seq.daa_targets = targets;

    daa_cmd = make_daa_cmd(tid, first_dat_idx[4:0], target_count[3:0]);

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 6000);

    read_rx_words(target_count * 12, rx_words);
    read_response(resp);

    `DV_CHECK_EQ(resp[31:28], Success, $sformatf("%s RESP status", ctxt))
    `DV_CHECK_EQ(resp[27:24], tid, $sformatf("%s RESP TID", ctxt))
    `DV_CHECK_EQ(resp[15:0], target_count * 12, $sformatf("%s RESP length", ctxt))
    `DV_CHECK_EQ(rx_words.size(), target_count * 3, $sformatf("%s RX word count", ctxt))

    for (int unsigned i = 0; i < target_count; i++) begin
      int unsigned winner;

      winner = order[i];
      `DV_CHECK_EQ(rx_words[(i*3)+0], expected_pid_word0(targets[winner]),
                   $sformatf("%s winner[%0d] PID word0", ctxt, i))
      `DV_CHECK_EQ(rx_words[(i*3)+1], expected_pid_word1(targets[winner]),
                   $sformatf("%s winner[%0d] PID/BCR/DCR word1", ctxt, i))
      `DV_CHECK_EQ(rx_words[(i*3)+2], {25'h0, assigned_addr[i]},
                   $sformatf("%s winner[%0d] assigned address", ctxt, i))
    end

    check_all_queues_empty($sformatf("after %s", ctxt));
    `uvm_info(`gfn, $sformatf(
              "%s result: winners={%0d,%0d,%0d,%0d} resp=0x%08h rx_words=%0d",
              ctxt, order[0], order[1], order[2], order[3], resp, rx_words.size()), UVM_LOW)
  endtask

  virtual task body();
    i3c_daa_arb_target_t targets[I3C_DAA_ARB_MAX_TARGETS];
    bit [6:0] assigned_addr[I3C_DAA_ARB_MAX_TARGETS];

    enable_dut();

    targets = '{default: '0};
    assigned_addr = '{default: '0};
    targets[0] = '{valid: 1'b1, pid: 48'h3000_0000_0000, bcr: 8'h10, dcr: 8'h30,
                   accept_addr: 1'b1};
    targets[1] = '{valid: 1'b1, pid: 48'h1000_0000_0000, bcr: 8'h10, dcr: 8'h10,
                   accept_addr: 1'b1};
    assigned_addr[0] = 7'h30;
    assigned_addr[1] = 7'h31;
    run_arbitration_case("ARB_001 early PID dropout", 4'hA, 5'd0, 2, targets, assigned_addr);

    targets = '{default: '0};
    assigned_addr = '{default: '0};
    targets[0] = '{valid: 1'b1, pid: 48'h0123_4567_89ab, bcr: 8'h22, dcr: 8'hf0,
                   accept_addr: 1'b1};
    targets[1] = '{valid: 1'b1, pid: 48'h0123_4567_89ab, bcr: 8'h22, dcr: 8'h0f,
                   accept_addr: 1'b1};
    assigned_addr[0] = 7'h40;
    assigned_addr[1] = 7'h41;
    run_arbitration_case("ARB_001 late DCR dropout", 4'hB, 5'd4, 2, targets, assigned_addr);
  endtask
endclass
