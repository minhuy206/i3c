class csr_enable_disable_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_enable_disable_vseq)

  function new(string name = "csr_enable_disable_vseq");
    super.new(name);
  endfunction

  task body();
    immediate_data_trans_desc_t        imm_cmd;
    i3c_device_response_seq            dev_seq;
    bit                         [31:0] data;
    bit                         [31:0] resp;

    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                 "csr_enable_disable_vseq: controller should start disabled")

    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = 4'd2;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = 3'd2;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.dev_idx           = 5'd0;
    imm_cmd.def_or_data_byte1 = 8'hAA;
    imm_cmd.data_byte2        = 8'hBB;

    fork : iso_fork
      begin
        fork : disabled_start_watch
          begin
            p_sequencer.cfg.m_i3c_agent_cfg.vif.wait_for_host_start();
            `uvm_error(`gfn, "csr_enable_disable_vseq: bus START observed while disabled")
          end
          begin
            write_cmd(imm_cmd[31:0], imm_cmd[63:32]);
            repeat (100) @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
          end
        join_any
        disable fork;
      end
    join

    reg_read(ADDR_QUEUE_STATUS, data);
    `DV_CHECK_EQ(data[QS_CMD_EMPTY_BIT], 1'b0,
                 "csr_enable_disable_vseq: queued command should remain pending while disabled")
    `DV_CHECK_EQ(data[QS_RESP_EMPTY_BIT], 1'b1,
                 "csr_enable_disable_vseq: no response should exist before enable")

    dev_seq             = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr = 7'h08;
    dev_seq.ack_address = 1'b1;
    dev_seq.is_i3c      = 1'b1;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    // reg_write(ADDR_HC_CONTROL, 32'h0000_0001);
    configure_dut();

    poll_idle();
    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0, "csr_enable_disable_vseq: expected Success response")

    reg_read(ADDR_HC_STATUS, data);
    `DV_CHECK_EQ(data[HC_STS_FSM_IDLE_BIT], 1'b1,
                 "csr_enable_disable_vseq: controller should return idle after completion")

    `uvm_info(`gfn, "CSR enable/disable checks passed", UVM_LOW)
  endtask

endclass
