class i3c_read_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_vseq)

  function new(string name = "i3c_read_vseq");
    super.new(name);
  endfunction

  task body();
    regular_trans_desc_t    rd_cmd;
    bit [31:0]              resp;
    bit [31:0]              rx;
    i3c_device_response_seq dev_seq;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    rd_cmd             = '0;
    rd_cmd.attr        = RegularTransfer;
    rd_cmd.tid         = 4'd2;
    rd_cmd.rnw         = 1'b1;
    rd_cmd.mode        = sdr0;
    rd_cmd.toc         = 1'b1;
    rd_cmd.wroc        = 1'b1;
    rd_cmd.data_length = 16'd4;

    dev_seq             = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr = 7'h08;
    dev_seq.is_i3c      = 1'b1;
    dev_seq.read_data.push_back(8'hCA);
    dev_seq.read_data.push_back(8'hFE);
    dev_seq.read_data.push_back(8'hBA);
    dev_seq.read_data.push_back(8'hBE);
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);

    poll_idle();
    read_response(resp);
    read_rx_data(rx);
    `DV_CHECK_EQ(resp[31:28], 4'h0,         "read_vseq: expected Success response")
    `DV_CHECK_EQ(rx,          32'hBEBA_FECA, "read_vseq: RX data mismatch")
  endtask

endclass
