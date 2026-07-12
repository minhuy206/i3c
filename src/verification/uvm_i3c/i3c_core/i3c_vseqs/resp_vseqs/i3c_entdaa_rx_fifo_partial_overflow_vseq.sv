class i3c_entdaa_rx_fifo_partial_overflow_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_entdaa_rx_fifo_partial_overflow_vseq)

  localparam int unsigned RX_FIFO_DEPTH = 8;
  localparam int unsigned DAA_RESULT_WORDS = 3;

  function new(string name = "i3c_entdaa_rx_fifo_partial_overflow_vseq");
    super.new(name);
  endfunction

  virtual task body();
    for (int unsigned free_words = 0; free_words < DAA_RESULT_WORDS; free_words++) begin
      run_rx_fifo_overflow_case(free_words);
    end
    run_entdaa_recovery_case();
  endtask

  virtual task run_rx_fifo_overflow_case(int unsigned free_words);
    addr_assign_desc_t             daa_cmd;
    bit                     [31:0] resp;
    bit                     [31:0] rx_word;
    i3c_device_response_seq        dev_seq;
    bit                     [ 6:0] assigned_addr;
    bit                     [47:0] pid;
    bit                     [ 7:0] bcr;
    bit                     [ 7:0] dcr;
    int unsigned                   prefill_words;
    int unsigned                   committed_words;
    string                         ctxt;

    prefill_words   = RX_FIFO_DEPTH - free_words;
    committed_words = free_words;
    ctxt            = $sformatf("ERR_007 ENTDAA RX FIFO overflow free_words=%0d", free_words);

    assigned_addr   = 7'h08;
    pid             = 48'h21_22_23_24_25_26 + free_words;
    bcr             = 8'h41 + free_words[7:0];
    dcr             = 8'h6C + free_words[7:0];

    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, assigned_addr, 1'b0);
    prefill_rx_fifo_count(prefill_words, $sformatf(
                          "after ERR_007 RX prefill free_words=%0d", free_words));

    daa_cmd = '0;
    daa_cmd.attr = AddressAssignment;
    daa_cmd.tid = 4'(9 + free_words);
    daa_cmd.cmd = ENTDAA;
    daa_cmd.dev_idx = 5'd0;
    daa_cmd.dev_count = 4'd1;
    daa_cmd.wroc = 1'b1;
    daa_cmd.toc = 1'b1;

    dev_seq = i3c_device_response_seq::type_id::create(
        $sformatf("err007_entdaa_dev_seq_free%0d", free_words));
    dev_seq.target_addr = 7'h7e;
    dev_seq.addr_nack = 1'b0;
    dev_seq.is_i3c = 1'b1;
    dev_seq.dir = 1'b0;
    dev_seq.entdaa_join = 1'b1;
    dev_seq.daa_accept_addr = 1'b1;
    dev_seq.daa_id_bytes = '{
        pid[47:40],
        pid[39:32],
        pid[31:24],
        pid[23:16],
        pid[15:8],
        pid[7:0],
        bcr,
        dcr
    };

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 3000);
    read_response(resp);

    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit, 1'b1, 1'b0, $sformatf(
                      "before ERR_007 RX drain free_words=%0d", free_words));
    for (int unsigned i = 0; i < prefill_words; i++) begin
      read_rx_data(rx_word);
      `DV_CHECK_EQ(rx_word, make_prefill_word(i), $sformatf(
                   "ERR_007 free_words=%0d: drained RX prefill word[%0d] mismatch", free_words, i))
    end
    for (int unsigned i = 0; i < committed_words; i++) begin
      read_rx_data(rx_word);
    end

    check_all_queues_empty($sformatf(
                           "after ERR_007 ENTDAA RX FIFO overflow free_words=%0d", free_words));

    disable device_response;
  endtask

  virtual task run_entdaa_recovery_case();
    addr_assign_desc_t             daa_cmd;
    bit                     [31:0] resp;
    bit                     [31:0] rx_word;
    i3c_device_response_seq        dev_seq;
    bit                     [ 6:0] assigned_addr;
    bit                     [47:0] pid;
    bit                     [ 7:0] bcr;
    bit                     [ 7:0] dcr;

    assigned_addr = 7'h09;
    pid           = 48'h31_32_33_34_35_36;
    bcr           = 8'h52;
    dcr           = 8'h7D;

    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, assigned_addr, 1'b0);

    daa_cmd = '0;
    daa_cmd.attr = AddressAssignment;
    daa_cmd.tid = 4'hF;
    daa_cmd.cmd = ENTDAA;
    daa_cmd.dev_idx = 5'd0;
    daa_cmd.dev_count = 4'd1;
    daa_cmd.wroc = 1'b1;
    daa_cmd.toc = 1'b1;

    dev_seq = i3c_device_response_seq::type_id::create("err007_entdaa_recovery_dev_seq");
    dev_seq.target_addr = 7'h7e;
    dev_seq.addr_nack = 1'b0;
    dev_seq.is_i3c = 1'b1;
    dev_seq.dir = 1'b0;
    dev_seq.entdaa_join = 1'b1;
    dev_seq.daa_accept_addr = 1'b1;
    dev_seq.daa_id_bytes = '{
        pid[47:40],
        pid[39:32],
        pid[31:24],
        pid[23:16],
        pid[15:8],
        pid[7:0],
        bcr,
        dcr
    };

    fork : recovery_device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq, "ERR_007 ENTDAA recovery", 3000);
    read_response(resp);

    read_rx_data(rx_word);
    `DV_CHECK_EQ(rx_word, pid[47:16], "ERR_007 ENTDAA recovery PID[47:16] mismatch")
    read_rx_data(rx_word);
    `DV_CHECK_EQ(rx_word, {pid[15:0], bcr, dcr}, "ERR_007 ENTDAA recovery PID/BCR/DCR mismatch")
    read_rx_data(rx_word);
    `DV_CHECK_EQ(rx_word, {25'h0, assigned_addr},
                 "ERR_007 ENTDAA recovery assigned-address word mismatch")
    check_all_queues_empty("after ERR_007 ENTDAA recovery without SW reset");

    disable recovery_device_response;
  endtask

  virtual function bit [31:0] make_prefill_word(int unsigned index);
    return 32'h6A6A_3000 | index[31:0];
  endfunction

  virtual task prefill_rx_fifo_count(int unsigned count, string ctxt);
    for (int unsigned i = 0; i < RX_FIFO_DEPTH; i++) begin
      if (i < count) backdoor_write_fifo_entry(rx_paths, i, make_prefill_word(i));
    end
    backdoor_set_fifo_level(rx_paths, count);
    settle_cycles();
    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit,
                      (count == RX_FIFO_DEPTH), (count == 0), ctxt);
  endtask
endclass
