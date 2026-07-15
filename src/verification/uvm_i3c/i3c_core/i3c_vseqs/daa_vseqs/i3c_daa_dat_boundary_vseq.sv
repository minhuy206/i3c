class i3c_daa_dat_boundary_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_daa_dat_boundary_vseq)

  localparam logic [3:0] RESP_NOT_SUPPORTED = 4'hA;

  function new(string name = "i3c_daa_dat_boundary_vseq");
    super.new(name);
  endfunction

  virtual task body();
    run_last_entry_success();
    run_middle_ends_at_last_success();
    run_out_of_range_rejection();
    run_middle_crosses_boundary_rejection();
  endtask

  virtual function void configure_joining_device(i3c_device_response_seq dev_seq,
                                                 bit [47:0] pid,
                                                 bit [7:0] bcr,
                                                 bit [7:0] dcr);
    dev_seq.target_addr = 7'h7e;
    dev_seq.addr_nack = 1'b0;
    dev_seq.is_i3c = 1'b1;
    dev_seq.dir = 1'b0;
    dev_seq.entdaa_join = 1'b1;
    dev_seq.daa_accept_addr = 1'b1;
    dev_seq.daa_id_bytes = '{pid[47:40], pid[39:32], pid[31:24], pid[23:16],
                             pid[15:8], pid[7:0], bcr, dcr};
  endfunction

  virtual task run_last_entry_success();
    addr_assign_desc_t             daa_cmd;
    bit                     [31:0] resp;
    word_queue_t                   rx_words;
    i3c_device_response_seq        dev_seq;
    bit                     [ 6:0] assigned_addr;
    bit                     [47:0] pid;
    bit                     [ 7:0] bcr;
    bit                     [ 7:0] dcr;
    string                         ctxt;

    assigned_addr = 7'h31;
    pid           = 48'h31_32_33_34_35_36;
    bcr           = 8'h41;
    dcr           = 8'h52;
    ctxt          = "DAA_007 last DAT entry";

    enable_dut();
    write_dat_entry(31, 7'h00, assigned_addr, 1'b0);

    daa_cmd = '0;
    daa_cmd.attr = AddressAssignment;
    daa_cmd.tid = 4'd7;
    daa_cmd.cmd = ENTDAA;
    daa_cmd.dev_idx = 5'd31;
    daa_cmd.dev_count = 4'd1;
    daa_cmd.wroc = 1'b1;
    daa_cmd.toc = 1'b1;

    dev_seq = i3c_device_response_seq::type_id::create("daa007_last_dev_seq");
    dev_seq.target_addr = 7'h7e;
    dev_seq.addr_nack = 1'b0;
    dev_seq.is_i3c = 1'b1;
    dev_seq.dir = 1'b0;
    dev_seq.entdaa_join = 1'b1;
    dev_seq.daa_accept_addr = 1'b1;
    dev_seq.daa_id_bytes = '{
        pid[47:40],
        pid[39:32],
        pid[31:24],
        pid[23:16],
        pid[15:8],
        pid[7:0],
        bcr,
        dcr
    };

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 3000);
    read_rx_words(12, rx_words);
    read_response(resp);

    check_all_queues_empty($sformatf("after %s", ctxt));
    disable device_response;
  endtask

  virtual task run_middle_ends_at_last_success();
    addr_assign_desc_t      daa_cmd;
    i3c_device_response_seq dev_seq[2];
    word_queue_t            rx_words;
    i3c_response_desc_t     resp_desc;
    bit [31:0]              resp;

    enable_dut();
    write_dat_entry(30, 7'h00, 7'h30, 1'b0);
    write_dat_entry(31, 7'h00, 7'h31, 1'b0);
    for (int unsigned i = 0; i < 2; i++) begin
      dev_seq[i] = i3c_device_response_seq::type_id::create(
          $sformatf("daa007_middle_end_dev_seq_%0d", i));
      configure_joining_device(dev_seq[i], 48'h20_00_00_00_00_00 + i,
                               8'h40 + i, 8'h50 + i);
    end

    daa_cmd           = '0;
    daa_cmd.attr      = AddressAssignment;
    daa_cmd.tid       = 4'h9;
    daa_cmd.cmd       = ENTDAA;
    daa_cmd.dev_idx   = 5'd30;
    daa_cmd.dev_count = 4'd2;
    daa_cmd.wroc      = 1'b1;
    daa_cmd.toc       = 1'b1;

    fork : middle_end_device_response
      dev_seq[0].start(p_sequencer.m_i3c_sequencer);
      begin
        wait (dev_seq[0].request_issued);
        dev_seq[1].start(p_sequencer.m_i3c_sequencer);
      end
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq[0], "DAA_007 middle ends-at-last device 0", 3000);
    wait_for_device_done(dev_seq[1], "DAA_007 middle ends-at-last device 1", 3000);
    read_rx_words(24, rx_words);
    read_response(resp);
    resp_desc = i3c_response_desc_t'(resp);
    `DV_CHECK_EQ(resp_desc.err_status, Success,
                 "DAA_007 middle ends-at-last response status")
    `DV_CHECK_EQ(resp_desc.data_length, 16'd24,
                 "DAA_007 middle ends-at-last response length")
    check_all_queues_empty("after DAA_007 middle ends-at-last accepted span");
    disable middle_end_device_response;
  endtask

  virtual task run_out_of_range_rejection();
    addr_assign_desc_t        daa_cmd;
    bit                [31:0] resp;
    string                    ctxt;

    ctxt              = "DAA_007 out-of-range DAT span";

    daa_cmd           = '0;
    daa_cmd.attr      = AddressAssignment;
    daa_cmd.tid       = 4'd8;
    daa_cmd.cmd       = ENTDAA;
    daa_cmd.dev_idx   = 5'd31;
    daa_cmd.dev_count = 4'd2;
    daa_cmd.wroc      = 1'b1;
    daa_cmd.toc       = 1'b1;

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);

    poll_idle();
    read_response(resp);

    check_all_queues_empty($sformatf("after %s", ctxt));
  endtask

  virtual task run_middle_crosses_boundary_rejection();
    addr_assign_desc_t    daa_cmd;
    i3c_response_desc_t   resp_desc;
    bit            [31:0] resp;

    daa_cmd           = '0;
    daa_cmd.attr      = AddressAssignment;
    daa_cmd.tid       = 4'hA;
    daa_cmd.cmd       = ENTDAA;
    daa_cmd.dev_idx   = 5'd30;
    daa_cmd.dev_count = 4'd3;
    daa_cmd.wroc      = 1'b1;
    daa_cmd.toc       = 1'b1;

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);
    poll_idle();
    read_response(resp);
    resp_desc = i3c_response_desc_t'(resp);
    `DV_CHECK_EQ(resp_desc.err_status, NotSupported,
                 "DAA_007 middle crossing span must be rejected")
    check_all_queues_empty("after DAA_007 middle crossing DAT span rejection");
  endtask
endclass
