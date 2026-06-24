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

    fork
      check_no_host_start_for_cycles(100, "csr_enable_disable_vseq");
      write_cmd(imm_cmd[31:0], imm_cmd[63:32]);
    join

    reg_read(ADDR_QUEUE_STATUS, data);

    dev_seq               = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr   = 7'h08;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = 2;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    enable_dut();

    poll_idle();
    wait_for_device_done(dev_seq, "csr_enable_disable_vseq");
    read_response(resp);

    reg_read(ADDR_HC_STATUS, data);

    disable_dut();

    fork
      check_no_host_start_for_cycles(100, "csr_enable_disable_vseq disable_after_enable");
      write_cmd(imm_cmd[31:0], imm_cmd[63:32]);
    join

    reg_read(ADDR_QUEUE_STATUS, data);

    dev_seq               = i3c_device_response_seq::type_id::create("dev_seq_after_disable");
    dev_seq.target_addr   = 7'h08;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = 2;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    enable_dut();

    poll_idle();
    wait_for_device_done(dev_seq, "csr_enable_disable_vseq disable_after_enable");
    read_response(resp);

  endtask

endclass
