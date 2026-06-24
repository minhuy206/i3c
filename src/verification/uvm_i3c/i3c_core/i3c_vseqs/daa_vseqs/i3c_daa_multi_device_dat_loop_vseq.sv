class i3c_daa_multi_device_dat_loop_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_daa_multi_device_dat_loop_vseq)

  localparam int unsigned FIRST_DAT_IDX = 2;
  localparam int unsigned DEVICE_COUNT  = 3;

  function new(string name = "i3c_daa_multi_device_dat_loop_vseq");
    super.new(name);
  endfunction

  virtual function void configure_joining_device(i3c_device_response_seq dev_seq,
                                                 i3c_daa_stimulus stimulus);
    dev_seq.target_addr     = 7'h7e;
    dev_seq.ack_address     = 1'b1;
    dev_seq.is_i3c          = 1'b1;
    dev_seq.is_daa          = 1'b1;
    dev_seq.dir             = 1'b0;
    dev_seq.entdaa_join     = 1'b1;
    dev_seq.daa_accept_addr = 1'b1;
    dev_seq.daa_id_bytes    = '{
      stimulus.pid[47:40],
      stimulus.pid[39:32],
      stimulus.pid[31:24],
      stimulus.pid[23:16],
      stimulus.pid[15:8],
      stimulus.pid[7:0],
      stimulus.bcr,
      stimulus.dcr
    };
  endfunction

  virtual task body();
    addr_assign_desc_t      daa_cmd;
    bit [31:0]              resp;
    word_queue_t            rx_words;
    i3c_device_response_seq dev_seq[DEVICE_COUNT];
    i3c_daa_stimulus        stimulus[DEVICE_COUNT];

    for (int unsigned i = 0; i < DEVICE_COUNT; i++) begin
      stimulus[i] = i3c_daa_stimulus::type_id::create($sformatf("daa004_stimulus_%0d", i));
    end

    `DV_CHECK_RANDOMIZE_FATAL(stimulus[0], "DAA_004 stimulus[0] randomization failed")
    if (!stimulus[1].randomize() with {
          assigned_addr != local::stimulus[0].assigned_addr;
        }) begin
      `uvm_fatal(`gfn, "DAA_004 stimulus[1] randomization failed")
    end
    if (!stimulus[2].randomize() with {
          assigned_addr != local::stimulus[0].assigned_addr;
          assigned_addr != local::stimulus[1].assigned_addr;
        }) begin
      `uvm_fatal(`gfn, "DAA_004 stimulus[2] randomization failed")
    end

    enable_dut();
    for (int unsigned i = 0; i < DEVICE_COUNT; i++) begin
      write_dat_entry(FIRST_DAT_IDX + i, 7'h00, stimulus[i].assigned_addr, 1'b0);
      dev_seq[i] = i3c_device_response_seq::type_id::create(
          $sformatf("daa004_dev_seq_%0d", i)
      );
      configure_joining_device(dev_seq[i], stimulus[i]);
    end

    daa_cmd           = '0;
    daa_cmd.attr      = AddressAssignment;
    daa_cmd.tid       = 4'd4;
    daa_cmd.cmd       = ENTDAA;
    daa_cmd.dev_idx   = FIRST_DAT_IDX;
    daa_cmd.dev_count = DEVICE_COUNT;
    daa_cmd.wroc      = 1'b1;
    daa_cmd.toc       = 1'b1;

    fork : device_response
      dev_seq[0].start(p_sequencer.m_i3c_sequencer);
      begin
        wait (dev_seq[0].request_issued);
        dev_seq[1].start(p_sequencer.m_i3c_sequencer);
      end
      begin
        wait (dev_seq[1].request_issued);
        dev_seq[2].start(p_sequencer.m_i3c_sequencer);
      end
    join_none

    write_cmd(daa_cmd[31:0], daa_cmd[63:32]);

    poll_idle();
    for (int unsigned i = 0; i < DEVICE_COUNT; i++) begin
      wait_for_device_done(dev_seq[i], $sformatf("DAA_004 device round %0d", i), 3000);
    end

    read_rx_words(DEVICE_COUNT * 12, rx_words);
    read_response(resp);

    check_all_queues_empty("after DAA_004 multi-device DAT loop");
    `uvm_info(`gfn, $sformatf(
                  "DAA_004 result: dev_idx=%0d count=%0d resp=0x%08h assigned={0x%02h,0x%02h,0x%02h} rx_words=%0d",
                  FIRST_DAT_IDX, DEVICE_COUNT, resp, stimulus[0].assigned_addr,
                  stimulus[1].assigned_addr, stimulus[2].assigned_addr, rx_words.size()), UVM_LOW)

    disable device_response;
  endtask
endclass
