class csr_sw_reset_clears_cmd_staging_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_sw_reset_clears_cmd_staging_vseq)

  function new(string name = "csr_sw_reset_clears_cmd_staging_vseq");
    super.new(name);
  endfunction

  task body();
    regular_trans_desc_t           stale_cmd;
    regular_trans_desc_t           fresh_cmd;
    i3c_device_response_seq        dev_seq;
    bit                     [31:0] status;
    bit                     [31:0] resp;
    bit                     [31:0] fresh_dword0;
    bit                     [31:0] fresh_dword1;
    bit                     [31:0] tx_data;

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

    request_sw_reset(1'b0);
    `DV_CHECK_EQ(hdl_read_bit(csr_paths.cmd_staging_valid_path), 1'b0,
                 "csr_sw_reset_clears_cmd_staging_vseq: CMD staging valid should clear after SW reset")

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
    tx_data               = 32'h7856_3412;

    reg_write(ADDR_CMD_QUEUE, fresh_dword0);
    settle_cycles();

    reg_write(ADDR_CMD_QUEUE, fresh_dword1);
    write_tx_data(tx_data);
    settle_cycles();

    dev_seq               = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr   = 7'h08;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = fresh_cmd.data_length;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    configure_dut();
    poll_idle();
    wait_for_device_done(dev_seq, "csr_sw_reset_clears_cmd_staging_vseq");
    `DV_CHECK_EQ(dev_seq.done, 1'b1,
                 "csr_sw_reset_clears_cmd_staging_vseq: fresh command should reach target")

    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0,
                 "csr_sw_reset_clears_cmd_staging_vseq: fresh command should complete successfully")
    `DV_CHECK_EQ(resp[27:24], fresh_cmd.tid,
                 "csr_sw_reset_clears_cmd_staging_vseq: response TID should be fresh, not stale")
    `DV_CHECK_NE(resp[27:24], stale_cmd.tid,
                 "csr_sw_reset_clears_cmd_staging_vseq: stale TID must not appear in response")
    `DV_CHECK_EQ(resp[15:0], fresh_cmd.data_length,
                 "csr_sw_reset_clears_cmd_staging_vseq: response length should be fresh")

    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08,
                 "csr_sw_reset_clears_cmd_staging_vseq: target address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, fresh_cmd.rnw,
                 "csr_sw_reset_clears_cmd_staging_vseq: direction should be fresh write command")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), fresh_cmd.data_length,
                 "csr_sw_reset_clears_cmd_staging_vseq: target should sample fresh write length")
    if (dev_seq.sampled_data.size() >= 4) begin
      `DV_CHECK_EQ(dev_seq.sampled_data[0], tx_data[7:0],
                   "csr_sw_reset_clears_cmd_staging_vseq: data byte 0 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data[1], tx_data[15:8],
                   "csr_sw_reset_clears_cmd_staging_vseq: data byte 1 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data[2], tx_data[23:16],
                   "csr_sw_reset_clears_cmd_staging_vseq: data byte 2 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data[3], tx_data[31:24],
                   "csr_sw_reset_clears_cmd_staging_vseq: data byte 3 mismatch")
    end

    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(status[QS_CMD_EMPTY_BIT], 1'b1,
                 "csr_sw_reset_clears_cmd_staging_vseq: CMD FIFO should drain after fresh command")
    `DV_CHECK_EQ(status[QS_TX_EMPTY_BIT], 1'b1,
                 "csr_sw_reset_clears_cmd_staging_vseq: TX FIFO should drain after fresh command")

    `uvm_info(`gfn, "CSR software reset clears CMD staging checks passed", UVM_LOW)
  endtask

endclass
