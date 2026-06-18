class csr_cmd_partial_then_other_write_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_cmd_partial_then_other_write_vseq)

  function new(string name = "csr_cmd_partial_then_other_write_vseq");
    super.new(name);
  endfunction

  task body();
    regular_trans_desc_t           wr_cmd;
    i3c_device_response_seq        dev_seq;
    bit                     [31:0] status;
    bit                     [31:0] resp;
    bit                     [31:0] data;
    bit                     [31:0] dword0;
    bit                     [31:0] dword1;
    bit                     [31:0] tx_data;

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
    tx_data            = 32'h4433_2211;

    reg_write(ADDR_CMD_QUEUE, dword0);
    check_cmd_staging_preserved("after CMD DWORD0 write", dword0);

    reg_write(ADDR_T_LOW, 20'd9);
    reg_read(ADDR_T_LOW, data);
    `DV_CHECK_EQ(data[19:0], 20'd9,
                 "csr_cmd_partial_then_other_write_vseq: interleaved T_LOW write mismatch")
    `DV_CHECK_EQ(data[31:20], 12'h0,
                 "csr_cmd_partial_then_other_write_vseq: T_LOW reserved bits should read 0")
    check_cmd_staging_preserved("after interleaved T_LOW write", dword0);

    write_dat_entry(0, 7'h50, 7'h08, 1'b0);
    reg_read(dat_addr(0), data);
    `DV_CHECK_EQ(data[6:0], 7'h50,
                 "csr_cmd_partial_then_other_write_vseq: interleaved DAT static addr mismatch")
    `DV_CHECK_EQ(data[22:16], 7'h08,
                 "csr_cmd_partial_then_other_write_vseq: interleaved DAT dynamic addr mismatch")
    `DV_CHECK_EQ(data[31], 1'b0,
                 "csr_cmd_partial_then_other_write_vseq: interleaved DAT device bit mismatch")
    check_cmd_staging_preserved("after interleaved DAT write", dword0);

    write_tx_data(tx_data);
    settle_cycles();
    check_cmd_staging_preserved("after interleaved TX_DATA write", dword0);

    reg_write(ADDR_CMD_QUEUE, dword1);
    settle_cycles();

    dev_seq               = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr   = 7'h08;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = 4;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    enable_dut();

    poll_idle();
    wait_for_device_done(dev_seq, "csr_cmd_partial_then_other_write_vseq");

    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0,
                 "csr_cmd_partial_then_other_write_vseq: expected Success response")
    `DV_CHECK_EQ(
        resp[27:24], wr_cmd.tid,
        "csr_cmd_partial_then_other_write_vseq: response TID should come from staged DWORD0")
    `DV_CHECK_EQ(
        resp[15:0], wr_cmd.data_length,
        "csr_cmd_partial_then_other_write_vseq: response length should come from final DWORD1")

    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08,
                 "csr_cmd_partial_then_other_write_vseq: target address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0,
                 "csr_cmd_partial_then_other_write_vseq: command direction should remain write")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), wr_cmd.data_length,
                 "csr_cmd_partial_then_other_write_vseq: device should sample expected data count")
    if (dev_seq.sampled_data.size() >= 4) begin
      `DV_CHECK_EQ(dev_seq.sampled_data[0], tx_data[7:0],
                   "csr_cmd_partial_then_other_write_vseq: data byte 0 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data[1], tx_data[15:8],
                   "csr_cmd_partial_then_other_write_vseq: data byte 1 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data[2], tx_data[23:16],
                   "csr_cmd_partial_then_other_write_vseq: data byte 2 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data[3], tx_data[31:24],
                   "csr_cmd_partial_then_other_write_vseq: data byte 3 mismatch")
    end

    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(
        status[QS_CMD_EMPTY_BIT], 1'b1,
        "csr_cmd_partial_then_other_write_vseq: CMD FIFO should be empty after command consumes")
    `DV_CHECK_EQ(
        status[QS_TX_EMPTY_BIT], 1'b1,
        "csr_cmd_partial_then_other_write_vseq: TX FIFO should be empty after write consumes data")

  endtask

  task check_cmd_staging_preserved(string ctxt, bit [31:0] exp_dword0);
    bit        cmd_staging_valid;
    bit [31:0] cmd_dword0;

    cmd_staging_valid = hdl_read_bit(csr_paths.cmd_staging_valid_path);
    cmd_dword0        = hdl_read_word(csr_paths.cmd_dword0_path);
    `DV_CHECK_EQ(cmd_staging_valid, 1'b1,
                 $sformatf("csr_cmd_partial_then_other_write_vseq: CMD staging valid dropped %s",
                           ctxt))
    `DV_CHECK_EQ(cmd_dword0, exp_dword0,
                 $sformatf("csr_cmd_partial_then_other_write_vseq: CMD DWORD0 changed %s", ctxt))
  endtask

endclass
