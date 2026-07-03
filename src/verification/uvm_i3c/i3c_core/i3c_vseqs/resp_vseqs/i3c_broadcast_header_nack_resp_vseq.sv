class i3c_broadcast_header_nack_resp_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_broadcast_header_nack_resp_vseq)

  localparam bit [6:0]   I2C_STATIC_ADDR = 7'h50;
  localparam bit [6:0]   I3C_DYNAMIC_ADDR = 7'h08;

  function new(string name = "i3c_broadcast_header_nack_resp_vseq");
    super.new(name);
  endfunction

  virtual task body();
    run_ccc_broadcast_header_nack_resp_case(ENEC, 8'h01, 4'd8,
                                            "ERR_003 ccc ENEC broadcast_header_nack_resp");
    run_ccc_broadcast_header_nack_resp_case(DISEC, 8'h02, 4'd9,
                                            "ERR_003 ccc DISEC broadcast_header_nack_resp");
    run_entdaa_broadcast_header_nack_resp_case();
  endtask

  virtual task run_ccc_broadcast_header_nack_resp_case(i3c_ccc_e opcode, bit [7:0] event_byte,
                                                       bit [3:0] tid, string ctxt);
    immediate_data_trans_desc_t ccc_cmd;
    bit [31:0]                  resp;
    i3c_device_response_seq     dev_seq;

    enable_dut(1'b0);
    write_dat_entry(0, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b0);

    ccc_cmd                   = '0;
    ccc_cmd.attr              = ImmediateDataTransfer;
    ccc_cmd.tid               = tid;
    ccc_cmd.cp                = 1'b1;
    ccc_cmd.cmd               = opcode;
    ccc_cmd.mode              = sdr0;
    ccc_cmd.dtt               = 3'd4;
    ccc_cmd.rnw               = 1'b0;
    ccc_cmd.toc               = 1'b1;
    ccc_cmd.wroc              = 1'b1;
    ccc_cmd.dev_idx           = 5'd0;
    ccc_cmd.def_or_data_byte1 = event_byte;

    dev_seq             = i3c_device_response_seq::type_id::create("err003_ccc_bhdr_nack_dev_seq");
    dev_seq.target_addr = 7'h7e;
    dev_seq.addr_nack = 1'b1;
    dev_seq.is_i3c      = 1'b1;
    dev_seq.dir         = 1'b0;

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(ccc_cmd[31:0], ccc_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 2000);
    read_response(resp);

    check_all_queues_empty($sformatf("after %s", ctxt));

    disable device_response;
  endtask

  virtual task run_entdaa_broadcast_header_nack_resp_case();
    addr_assign_desc_t      daa_cmd;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;
    string                  ctxt;

    ctxt = "ERR_003 ENTDAA broadcast_header_nack_resp";

    enable_dut(1'b0);
    write_dat_entry(0, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b0);

    daa_cmd           = '0;
    daa_cmd.attr      = AddressAssignment;
    daa_cmd.tid       = 4'd10;
    daa_cmd.cmd       = ENTDAA;
    daa_cmd.dev_idx   = 5'd0;
    daa_cmd.dev_count = 4'd1;
    daa_cmd.wroc      = 1'b1;
    daa_cmd.toc       = 1'b1;

    dev_seq             = i3c_device_response_seq::type_id::create("err003_entdaa_bhdr_nack_dev_seq");
    dev_seq.target_addr = 7'h7e;
    dev_seq.addr_nack = 1'b1;
    dev_seq.is_i3c      = 1'b1;
    dev_seq.is_daa      = 1'b1;
    dev_seq.dir         = 1'b0;

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 2000);
    read_response(resp);

    check_all_queues_empty($sformatf("after %s", ctxt));

    disable device_response;
  endtask

endclass
