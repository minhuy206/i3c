class csr_enable_disable_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_enable_disable_vseq)

  function new(string name = "csr_enable_disable_vseq");
    super.new(name);
  endfunction

  task body();
    immediate_data_trans_desc_t        imm_cmd;
    i3c_device_response_seq            dev_seq;
    bit                         [31:0] data;
    bit                         [31:0] hc_status_before;
    bit                         [31:0] resp;
    byte_queue_t                       random_data;
    event                              disabled_window_done;
    event                              disabled_window_done_after_disable;

    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                 "csr_enable_disable_vseq: HC_CONTROL.ENABLE should reset disabled")

    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = 4'd2;
    imm_cmd.mode              = sdr0;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.dev_idx           = 5'd0;
    randomize_immediate_write_data(2, imm_cmd, random_data);

    fork
      check_no_host_start_until_event(disabled_window_done, "csr_enable_disable_vseq");
      begin
        write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

        reg_read(ADDR_QUEUE_STATUS, data);
        `DV_CHECK_EQ(data[QS_CMD_EMPTY_BIT], 1'b0,
                     "csr_enable_disable_vseq: disabled CMD queue should hold pending command")
        `DV_CHECK_EQ(data[QS_RESP_EMPTY_BIT], 1'b1,
                     "csr_enable_disable_vseq: disabled controller should not create response")

        dev_seq               = i3c_device_response_seq::type_id::create("dev_seq");
        dev_seq.target_addr   = 7'h08;
        dev_seq.addr_nack   = 1'b0;
        dev_seq.is_i3c        = 1'b1;
        dev_seq.dir           = 1'b0;
        dev_seq.read_data_cnt = 2;
        fork
          dev_seq.start(p_sequencer.m_i3c_sequencer);
        join_none

        -> disabled_window_done;
      end
    join

    enable_dut();

    poll_idle();
    wait_for_device_done(dev_seq, "csr_enable_disable_vseq");
    read_response(resp);

    reg_read(ADDR_HC_STATUS, data);
    `DV_CHECK_EQ(data[HC_STS_FSM_IDLE_BIT], 1'b1,
                 "csr_enable_disable_vseq: HC_STATUS.FSM_IDLE should be set after completion")
    check_all_queues_empty("after csr_enable_disable_vseq first enable run");

    hc_status_before = data;
    reg_write(ADDR_HC_STATUS, 32'hFFFF_FFFF);
    reg_read(ADDR_HC_STATUS, data);
    `DV_CHECK_EQ(data, hc_status_before,
                 "csr_enable_disable_vseq: all-ones write changed read-only HC_STATUS")
    reg_write(ADDR_HC_STATUS, 32'h0000_0000);
    reg_read(ADDR_HC_STATUS, data);
    `DV_CHECK_EQ(data, hc_status_before,
                 "csr_enable_disable_vseq: all-zeroes write changed read-only HC_STATUS")

    disable_dut();
    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                 "csr_enable_disable_vseq: HC_CONTROL.ENABLE should clear after disable")

    fork
      check_no_host_start_until_event(disabled_window_done_after_disable,
                                      "csr_enable_disable_vseq disable_after_enable");
      begin
        write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

        reg_read(ADDR_QUEUE_STATUS, data);
        `DV_CHECK_EQ(data[QS_CMD_EMPTY_BIT], 1'b0,
                     "csr_enable_disable_vseq: disabled-after-enable CMD queue should hold pending command")
        `DV_CHECK_EQ(data[QS_RESP_EMPTY_BIT], 1'b1,
                     "csr_enable_disable_vseq: disabled-after-enable controller should not create response")

        dev_seq               = i3c_device_response_seq::type_id::create("dev_seq_after_disable");
        dev_seq.target_addr   = 7'h08;
        dev_seq.addr_nack   = 1'b0;
        dev_seq.is_i3c        = 1'b1;
        dev_seq.dir           = 1'b0;
        dev_seq.read_data_cnt = 2;
        fork
          dev_seq.start(p_sequencer.m_i3c_sequencer);
        join_none

        -> disabled_window_done_after_disable;
      end
    join

    enable_dut();

    poll_idle();
    wait_for_device_done(dev_seq, "csr_enable_disable_vseq disable_after_enable");
    read_response(resp);
    reg_read(ADDR_HC_STATUS, data);
    `DV_CHECK_EQ(data[HC_STS_FSM_IDLE_BIT], 1'b1,
                 "csr_enable_disable_vseq: HC_STATUS.FSM_IDLE should be set after re-enable completion")
    check_all_queues_empty("after csr_enable_disable_vseq re-enable run");

  endtask

endclass
