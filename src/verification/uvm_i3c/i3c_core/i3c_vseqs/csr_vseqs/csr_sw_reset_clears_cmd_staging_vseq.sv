class csr_sw_reset_clears_cmd_staging_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_sw_reset_clears_cmd_staging_vseq)

  function new(string name = "csr_sw_reset_clears_cmd_staging_vseq");
    super.new(name);
  endfunction

  task body();
    regular_trans_desc_t           stale_cmd;
    regular_trans_desc_t           fresh_cmd;
    i3c_device_response_seq        dev_seq;
    bit                     [31:0] resp;
    bit                     [31:0] fresh_dword0;
    bit                     [31:0] fresh_dword1;
    bit                     [31:0] tx_data;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [63:0] cmd_wdata;
    uvm_hdl_data_t                 raw_hdl;
    i3c_response_desc_t            resp_desc;

    poll_idle();

    stale_cmd             = '0;
    stale_cmd.attr        = RegularTransfer;
    stale_cmd.tid         = 4'd3;
    stale_cmd.rnw         = 1'b1;
    stale_cmd.mode        = sdr0;
    stale_cmd.toc         = 1'b1;
    stale_cmd.wroc        = 1'b1;
    stale_cmd.dev_idx     = 5'd0;
    stale_cmd.data_length = 16'd12;

    reg_write(ADDR_CMD_QUEUE, stale_cmd[31:0]);
    settle_cycles();
    `DV_CHECK_EQ(hdl_read_bit(csr_paths.cmd_staging_valid_path), 1'b1,
                 "csr_sw_reset_clears_cmd_staging_vseq: stale DWORD0 should be staged")
    `DV_CHECK_EQ(hdl_read_word(csr_paths.cmd_dword0_path), stale_cmd[31:0],
                 "csr_sw_reset_clears_cmd_staging_vseq: stale staged DWORD0 mismatch")
    `DV_CHECK_EQ(hdl_read_bit(cmd_paths.write_valid_path), 1'b0,
                 "csr_sw_reset_clears_cmd_staging_vseq: stale DWORD0 must not push CMD")
    check_queue_flags(cmd_paths.name, cmd_paths.full_bit, cmd_paths.empty_bit, 1'b0, 1'b1,
                      "after stale CMD DWORD0 write");

    request_sw_reset(1'b0);
    `DV_CHECK_EQ(hdl_read_bit(csr_paths.cmd_staging_valid_path), 1'b0,
                 "csr_sw_reset_clears_cmd_staging_vseq: SW_RESET should clear CMD staging")
    `DV_CHECK_EQ(hdl_read_bit(cmd_paths.write_valid_path), 1'b0,
                 "csr_sw_reset_clears_cmd_staging_vseq: SW_RESET should clear pending CMD write")
    check_queue_flags(cmd_paths.name, cmd_paths.full_bit, cmd_paths.empty_bit, 1'b0, 1'b1,
                      "after SW_RESET clears stale staging");

    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    fresh_cmd             = '0;
    fresh_cmd.attr        = RegularTransfer;
    fresh_cmd.tid         = 4'd9;
    fresh_cmd.rnw         = 1'b0;
    fresh_cmd.mode        = sdr0;
    fresh_cmd.toc         = 1'b1;
    fresh_cmd.wroc        = 1'b1;
    fresh_cmd.dev_idx     = 5'd0;
    fresh_cmd.data_length = 16'd4;

    fresh_dword0          = fresh_cmd[31:0];
    fresh_dword1          = fresh_cmd[63:32];
    build_random_tx_words(fresh_cmd.data_length, exp_data, tx_words);
    tx_data               = tx_words[0];

    reg_write(ADDR_CMD_QUEUE, fresh_dword0);
    settle_cycles();
    `DV_CHECK_EQ(hdl_read_bit(csr_paths.cmd_staging_valid_path), 1'b1,
                 "csr_sw_reset_clears_cmd_staging_vseq: fresh DWORD0 should be staged")
    `DV_CHECK_EQ(hdl_read_word(csr_paths.cmd_dword0_path), fresh_dword0,
                 "csr_sw_reset_clears_cmd_staging_vseq: fresh staged DWORD0 mismatch")
    `DV_CHECK_EQ(hdl_read_bit(cmd_paths.write_valid_path), 1'b0,
                 "csr_sw_reset_clears_cmd_staging_vseq: fresh DWORD0 must not push CMD")

    reg_write(ADDR_CMD_QUEUE, fresh_dword1);
    write_tx_data(tx_data);
    settle_cycles();
    raw_hdl = hdl_read_checked(cmd_paths.write_data_path);
    cmd_wdata = raw_hdl[63:0];
    `DV_CHECK_EQ(hdl_read_bit(csr_paths.cmd_staging_valid_path), 1'b0,
                 "csr_sw_reset_clears_cmd_staging_vseq: fresh DWORD1 should clear staging")
    `DV_CHECK_EQ(cmd_wdata, {fresh_dword1, fresh_dword0},
                 "csr_sw_reset_clears_cmd_staging_vseq: emitted CMD should use fresh DWORD0")
    check_queue_flags(cmd_paths.name, cmd_paths.full_bit, cmd_paths.empty_bit, 1'b0, 1'b0,
                      "after fresh CMD DWORD1 write");

    dev_seq               = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr   = 7'h08;
    dev_seq.addr_nack   = 1'b0;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = fresh_cmd.data_length;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    enable_dut();
    poll_idle();
    wait_for_device_done(dev_seq, "csr_sw_reset_clears_cmd_staging_vseq");
    `DV_CHECK_EQ(dev_seq.sampled_data_q.size(), fresh_cmd.data_length,
                 "csr_sw_reset_clears_cmd_staging_vseq: payload byte count mismatch")
    if (dev_seq.sampled_data_q.size() >= fresh_cmd.data_length) begin
      `DV_CHECK_EQ(dev_seq.sampled_data_q[0], tx_data[7:0],
                   "csr_sw_reset_clears_cmd_staging_vseq: payload byte0 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data_q[1], tx_data[15:8],
                   "csr_sw_reset_clears_cmd_staging_vseq: payload byte1 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data_q[2], tx_data[23:16],
                   "csr_sw_reset_clears_cmd_staging_vseq: payload byte2 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data_q[3], tx_data[31:24],
                   "csr_sw_reset_clears_cmd_staging_vseq: payload byte3 mismatch")
    end

    read_response(resp);
    resp_desc = i3c_response_desc_t'(resp);
    `DV_CHECK_EQ(resp_desc.err, Success,
                 "csr_sw_reset_clears_cmd_staging_vseq: fresh command RESP status mismatch")
    `DV_CHECK_EQ(resp_desc.tid, fresh_cmd.tid,
                 "csr_sw_reset_clears_cmd_staging_vseq: fresh command RESP TID mismatch")
    `DV_CHECK_EQ(resp_desc.data_length, fresh_cmd.data_length,
                 "csr_sw_reset_clears_cmd_staging_vseq: fresh command RESP length mismatch")

    check_all_queues_empty("after csr_sw_reset_clears_cmd_staging_vseq");

  endtask

endclass
