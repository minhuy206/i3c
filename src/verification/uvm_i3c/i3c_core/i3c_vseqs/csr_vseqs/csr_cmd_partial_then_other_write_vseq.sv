class csr_cmd_partial_then_other_write_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_cmd_partial_then_other_write_vseq)

  function new(string name = "csr_cmd_partial_then_other_write_vseq");
    super.new(name);
  endfunction

  task body();
    regular_trans_desc_t           wr_cmd;
    i3c_device_response_seq        dev_seq;
    bit                     [31:0] resp;
    bit                     [31:0] data;
    bit                     [31:0] dword0;
    bit                     [31:0] dword1;
    bit                     [31:0] tx_data;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [63:0] cmd_wdata;
    uvm_hdl_data_t                 raw_hdl;

    wr_cmd             = '0;
    wr_cmd.attr        = RegularTransfer;
    wr_cmd.tid         = 4'd6;
    wr_cmd.rnw         = 1'b0;
    wr_cmd.mode        = sdr0;
    wr_cmd.toc         = 1'b1;
    wr_cmd.wroc        = 1'b1;
    wr_cmd.dev_idx     = 5'd0;
    wr_cmd.data_length = 16'd4;

    dword0             = wr_cmd[31:0];
    dword1             = wr_cmd[63:32];
    build_random_tx_words(wr_cmd.data_length, exp_data, tx_words);
    tx_data            = tx_words[0];

    reg_write(ADDR_CMD_QUEUE, dword0);
    check_cmd_staging_preserved("after CMD DWORD0 write", dword0);

    reg_write(ADDR_T_LOW, 20'd9);
    reg_read(ADDR_T_LOW, data);
    check_cmd_staging_preserved("after interleaved T_LOW write", dword0);

    write_dat_entry(0, 7'h50, 7'h08, 1'b0);
    reg_read(dat_addr(0), data);
    check_cmd_staging_preserved("after interleaved DAT write", dword0);

    write_tx_data(tx_data);
    settle_cycles();
    check_cmd_staging_preserved("after interleaved TX_DATA write", dword0);

    reg_write(ADDR_CMD_QUEUE, dword1);
    settle_cycles();
    raw_hdl = hdl_read_checked(cmd_paths.write_data_path);
    cmd_wdata = raw_hdl[63:0];
    `DV_CHECK_EQ(hdl_read_bit(csr_paths.cmd_staging_valid_path), 1'b0,
                 "csr_cmd_partial_then_other_write_vseq: DWORD1 should clear staging")
    `DV_CHECK_EQ(cmd_wdata, {dword1, dword0},
                 "csr_cmd_partial_then_other_write_vseq: emitted CMD dword order mismatch")
    check_queue_flags(cmd_paths.name, cmd_paths.full_bit, cmd_paths.empty_bit, 1'b0, 1'b0,
                      "after interleaved CMD DWORD1 write");

    dev_seq               = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr   = 7'h08;
    dev_seq.addr_nack   = 1'b0;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = 4;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    enable_dut();

    poll_idle();
    wait_for_device_done(dev_seq, "csr_cmd_partial_then_other_write_vseq");
    `DV_CHECK_EQ(dev_seq.sampled_data_q.size(), 4,
                 "csr_cmd_partial_then_other_write_vseq: payload byte count mismatch")
    if (dev_seq.sampled_data_q.size() >= 4) begin
      `DV_CHECK_EQ(dev_seq.sampled_data_q[0], tx_data[7:0],
                   "csr_cmd_partial_then_other_write_vseq: payload byte0 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data_q[1], tx_data[15:8],
                   "csr_cmd_partial_then_other_write_vseq: payload byte1 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data_q[2], tx_data[23:16],
                   "csr_cmd_partial_then_other_write_vseq: payload byte2 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data_q[3], tx_data[31:24],
                   "csr_cmd_partial_then_other_write_vseq: payload byte3 mismatch")
    end

    read_response(resp);
    check_all_queues_empty("after csr_cmd_partial_then_other_write_vseq");

  endtask

  task check_cmd_staging_preserved(string ctxt, bit [31:0] exp_dword0);
    bit        cmd_staging_valid;
    bit [31:0] cmd_dword0;

    cmd_staging_valid = hdl_read_bit(csr_paths.cmd_staging_valid_path);
    cmd_dword0        = hdl_read_word(csr_paths.cmd_dword0_path);
    `DV_CHECK_EQ(cmd_staging_valid, 1'b1,
                 $sformatf("csr_cmd_partial_then_other_write_vseq: staging invalid %s", ctxt))
    `DV_CHECK_EQ(cmd_dword0, exp_dword0,
                 $sformatf("csr_cmd_partial_then_other_write_vseq: staged DWORD0 mismatch %s",
                           ctxt))
    `DV_CHECK_EQ(hdl_read_bit(cmd_paths.write_valid_path), 1'b0,
                 $sformatf("csr_cmd_partial_then_other_write_vseq: non-CMD write pushed CMD %s",
                           ctxt))
    check_queue_flags(cmd_paths.name, cmd_paths.full_bit, cmd_paths.empty_bit, 1'b0, 1'b1, ctxt);
  endtask

endclass
