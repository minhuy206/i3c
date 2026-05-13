class i3c_write_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_vseq)

  function new(string name = "i3c_write_vseq");
    super.new(name);
  endfunction

  task body();
    regular_trans_desc_t    wr_cmd;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    wr_cmd             = '0;
    wr_cmd.attr        = RegularTransfer;
    wr_cmd.tid         = 4'd1;
    wr_cmd.rnw         = 1'b0;
    wr_cmd.mode        = sdr0;
    wr_cmd.toc         = 1'b1;
    wr_cmd.wroc        = 1'b1;
    wr_cmd.data_length = 16'd4;

    dev_seq               = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr   = 7'h08;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.read_data_cnt = 4;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(wr_cmd[31:0], wr_cmd[63:32]);
    write_tx_data(32'hDEAD_BEEF);

    poll_idle();
    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0,  "write_vseq: expected Success response")
    `DV_CHECK_EQ(resp[15:0],  16'd4, "write_vseq: expected data_length 4")
  endtask

endclass
