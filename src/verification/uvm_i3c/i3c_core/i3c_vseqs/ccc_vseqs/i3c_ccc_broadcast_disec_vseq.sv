class i3c_ccc_broadcast_disec_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_ccc_broadcast_disec_vseq)

  function new(string name = "i3c_ccc_broadcast_disec_vseq");
    super.new(name);
  endfunction

  virtual task body();
    immediate_data_trans_desc_t        ccc_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;
    bit                         [ 7:0] event_byte;

    event_byte = 8'h02;

    enable_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    ccc_cmd                   = '0;
    ccc_cmd.attr              = ImmediateDataTransfer;
    ccc_cmd.tid               = 4'd3;
    ccc_cmd.cp                = 1'b1;
    ccc_cmd.cmd               = DISEC;
    ccc_cmd.mode              = sdr0;
    ccc_cmd.dtt               = 3'd4;
    ccc_cmd.rnw               = 1'b0;
    ccc_cmd.toc               = 1'b1;
    ccc_cmd.wroc              = 1'b1;
    ccc_cmd.dev_idx           = 5'd0;
    ccc_cmd.def_or_data_byte1 = event_byte;

    dev_seq                   = i3c_device_response_seq::type_id::create("ccc003_dev_seq");
    dev_seq.target_addr       = 7'h7e;
    dev_seq.addr_nack       = 1'b0;
    dev_seq.is_i3c            = 1'b1;
    dev_seq.dir               = 1'b0;

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(ccc_cmd[31:0], ccc_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, "CCC_003 broadcast DISEC frame", 2000);
    read_response(resp);

    check_all_queues_empty("after CCC_003 broadcast DISEC frame");

    disable device_response;
  endtask
endclass
