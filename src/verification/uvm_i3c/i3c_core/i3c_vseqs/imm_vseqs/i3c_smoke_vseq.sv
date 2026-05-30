class i3c_smoke_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_smoke_vseq)

  function new(string name = "i3c_smoke_vseq");
    super.new(name);
  endfunction

  task body();
    immediate_data_trans_desc_t imm_cmd;
    bit [31:0]                  resp;
    i3c_device_response_seq     dev_seq;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = 4'd0;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = 3'd2;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.def_or_data_byte1 = 8'hAA;
    imm_cmd.data_byte2        = 8'hBB;

    dev_seq             = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr = 7'h08;
    dev_seq.ack_address = 1'b1;
    dev_seq.is_i3c      = 1'b1;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    poll_idle();
    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0, "smoke_vseq: expected Success response")
  endtask

endclass
