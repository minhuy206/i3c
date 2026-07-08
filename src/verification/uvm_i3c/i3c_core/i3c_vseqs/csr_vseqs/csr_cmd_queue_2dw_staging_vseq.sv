class csr_cmd_queue_2dw_staging_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_cmd_queue_2dw_staging_vseq)

  function new(string name = "csr_cmd_queue_2dw_staging_vseq");
    super.new(name);
  endfunction

  task body();
    immediate_data_trans_desc_t        imm_cmd;
    i3c_device_response_seq            dev_seq;
    bit                         [31:0] status;
    bit                         [31:0] resp;
    bit                         [31:0] cmd_readback;
    bit                         [31:0] dword0;
    bit                         [31:0] dword1;
    bit                         [63:0] cmd_wdata;
    uvm_hdl_data_t                     raw_hdl;
    int unsigned                       exp_data_bytes;
    byte_queue_t                       random_data;

    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = 4'd5;
    imm_cmd.mode              = sdr0;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.dev_idx           = 5'd0;
    randomize_immediate_write_data(2, imm_cmd, random_data);
    exp_data_bytes            = int'(imm_cmd.dtt);

    dword0                    = imm_cmd[31:0];
    dword1                    = imm_cmd[63:32];

    reg_write(ADDR_CMD_QUEUE, dword0);
    settle_cycles();
    `DV_CHECK_EQ(hdl_read_bit(csr_paths.cmd_staging_valid_path), 1'b1,
                 "csr_cmd_queue_2dw_staging_vseq: DWORD0 should be staged")
    `DV_CHECK_EQ(hdl_read_word(csr_paths.cmd_dword0_path), dword0,
                 "csr_cmd_queue_2dw_staging_vseq: staged DWORD0 mismatch")
    `DV_CHECK_EQ(hdl_read_bit(cmd_paths.write_valid_path), 1'b0,
                 "csr_cmd_queue_2dw_staging_vseq: first DWORD must not push CMD")
    check_queue_flags(cmd_paths.name, cmd_paths.full_bit, cmd_paths.empty_bit, 1'b0, 1'b1,
                      "after CMD DWORD0 write");

    reg_read(ADDR_CMD_QUEUE, cmd_readback);
    settle_cycles();
    `DV_CHECK_EQ(cmd_readback, 32'h0,
                 "csr_cmd_queue_2dw_staging_vseq: CMD_QUEUE read should return zero")
    `DV_CHECK_EQ(hdl_read_bit(csr_paths.cmd_staging_valid_path), 1'b1,
                 "csr_cmd_queue_2dw_staging_vseq: CMD_QUEUE read cleared DWORD0 staging")
    `DV_CHECK_EQ(hdl_read_word(csr_paths.cmd_dword0_path), dword0,
                 "csr_cmd_queue_2dw_staging_vseq: CMD_QUEUE read changed staged DWORD0")
    `DV_CHECK_EQ(hdl_read_bit(cmd_paths.write_valid_path), 1'b0,
                 "csr_cmd_queue_2dw_staging_vseq: CMD_QUEUE read pushed a command")
    check_queue_flags(cmd_paths.name, cmd_paths.full_bit, cmd_paths.empty_bit, 1'b0, 1'b1,
                      "after CMD_QUEUE read with DWORD0 staged");

    reg_write(ADDR_CMD_QUEUE, dword1);
    settle_cycles();
    raw_hdl = hdl_read_checked(cmd_paths.write_data_path);
    cmd_wdata = raw_hdl[63:0];
    `DV_CHECK_EQ(hdl_read_bit(csr_paths.cmd_staging_valid_path), 1'b0,
                 "csr_cmd_queue_2dw_staging_vseq: DWORD1 should clear staging")
    `DV_CHECK_EQ(cmd_wdata, {dword1, dword0},
                 "csr_cmd_queue_2dw_staging_vseq: emitted CMD dword order mismatch")
    check_queue_flags(cmd_paths.name, cmd_paths.full_bit, cmd_paths.empty_bit, 1'b0, 1'b0,
                      "after CMD DWORD1 write");

    reg_read(ADDR_CMD_QUEUE, cmd_readback);
    settle_cycles();
    `DV_CHECK_EQ(cmd_readback, 32'h0,
                 "csr_cmd_queue_2dw_staging_vseq: queued CMD_QUEUE read should return zero")
    check_queue_flags(cmd_paths.name, cmd_paths.full_bit, cmd_paths.empty_bit, 1'b0, 1'b0,
                      "after CMD_QUEUE read with command queued");

    dev_seq             = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr   = 7'h08;
    dev_seq.addr_nack   = 1'b0;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = exp_data_bytes;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    enable_dut();

    poll_idle();
    wait_for_device_done(dev_seq, "csr_cmd_queue_2dw_staging_vseq");
    `DV_CHECK_EQ(dev_seq.sampled_data_q.size(), exp_data_bytes,
                 "csr_cmd_queue_2dw_staging_vseq: immediate payload byte count mismatch")
    if (dev_seq.sampled_data_q.size() >= exp_data_bytes) begin
      `DV_CHECK_EQ(dev_seq.sampled_data_q[0], imm_cmd.def_or_data_byte1,
                   "csr_cmd_queue_2dw_staging_vseq: immediate byte1 mismatch")
      `DV_CHECK_EQ(dev_seq.sampled_data_q[1], imm_cmd.data_byte2,
                   "csr_cmd_queue_2dw_staging_vseq: immediate byte2 mismatch")
    end

    read_response(resp);

    reg_read(ADDR_QUEUE_STATUS, status);
    check_all_queues_empty("after csr_cmd_queue_2dw_staging_vseq");

  endtask

endclass
