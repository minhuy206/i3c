class i3c_imm_data_nack_i2c_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_imm_data_nack_i2c_vseq)

  function new(string name = "i3c_imm_data_nack_i2c_vseq");
    super.new(name);
  endfunction

  task body();
    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, 7'h0, 1'b1);

    run_data_nack_case(.dtt(3'd2), .nack_byte_idx(0), .case_name("first"));
    run_data_nack_case(.dtt(3'd3), .nack_byte_idx(1), .case_name("middle"));
    run_data_nack_case(.dtt(3'd4), .nack_byte_idx(3), .case_name("final"));

    run_recovery_case();
  endtask

  virtual task run_data_nack_case(bit [2:0] dtt, int unsigned nack_byte_idx, string case_name);
    immediate_data_trans_desc_t        imm_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;
    transfer_stimulus_cfg_t            cfg;
    byte_queue_t                       exp_data;
    bit                                data_ack_pattern[$];
    bit                         [ 3:0] tid;

    tid                       = {1'b0, dtt};
    build_random_payload(dtt, exp_data);
    build_data_ack_pattern(dtt, nack_byte_idx, data_ack_pattern);

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = tid;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = dtt;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.def_or_data_byte1 = exp_data[0];
    if (dtt > 1) imm_cmd.data_byte2 = exp_data[1];
    if (dtt > 2) imm_cmd.data_byte3 = exp_data[2];
    if (dtt > 3) imm_cmd.data_byte4 = exp_data[3];

    `uvm_info(`gfn,
              $sformatf("ERR_004 %s dtt=%0d: I2C immediate write, data NACK byte %0d",
                        case_name, dtt, nack_byte_idx),
              UVM_MEDIUM)

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_004 %s dtt%0d nack%0d", case_name, dtt, nack_byte_idx)),
        .seq_name($sformatf("err004_%s_dtt%0d_dev_seq", case_name, dtt)),
        .tid(tid),
        .dev_idx(5'd0),
        .target_addr(7'h50),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(dtt),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_patterned_device_response(cfg, data_ack_pattern, dev_seq);
    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));

    read_response(resp);
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), nack_byte_idx + 1,
                 $sformatf("ERR_004 immediate %s sampled byte boundary", case_name))
    check_all_queues_empty($sformatf("ERR_004 after %s dtt=%0d", case_name, dtt));

  endtask

  virtual task start_patterned_device_response(transfer_stimulus_cfg_t cfg,
                                               bit data_ack_pattern[$],
                                               output i3c_device_response_seq dev_seq);
    byte_queue_t no_read_data;

    dev_seq                             = i3c_device_response_seq::type_id::create(cfg.seq_name);
    dev_seq.target_addr                 = cfg.target_addr;
    dev_seq.ack_address                 = cfg.ack_address;
    dev_seq.ack_data                    = cfg.ack_data;
    dev_seq.is_i3c                      = cfg.is_i3c;
    dev_seq.dir                         = 1'b0;
    dev_seq.start_with_broadcast_header = cfg.start_with_broadcast_header;
    dev_seq.read_data_cnt               = cfg.data_length;
    dev_seq.read_data                   = no_read_data;
    dev_seq.data_ack_pattern            = data_ack_pattern;

    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none
  endtask

  virtual task run_recovery_case();
    immediate_data_trans_desc_t        imm_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;
    transfer_stimulus_cfg_t            cfg;
    byte_queue_t                       no_read_data;
    byte_queue_t                       exp_data;

    build_random_payload(1, exp_data);

    imm_cmd = '0;
    imm_cmd.attr = ImmediateDataTransfer;
    imm_cmd.tid = 4'hE;
    imm_cmd.mode = sdr0;
    imm_cmd.dtt = 3'd1;
    imm_cmd.rnw = 1'b0;
    imm_cmd.toc = 1'b1;
    imm_cmd.wroc = 1'b1;
    imm_cmd.def_or_data_byte1 = exp_data[0];

    cfg = make_transfer_cfg(
        .ctxt("ERR_004 recovery without SW reset"),
        .seq_name("err004_imm_recovery_dev_seq"),
        .tid(imm_cmd.tid),
        .dev_idx(5'd0),
        .target_addr(7'h50),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(exp_data.size()),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);
    check_all_queues_empty(cfg.ctxt);
  endtask

  virtual function void build_data_ack_pattern(int unsigned data_length,
                                               int unsigned nack_byte_idx,
                                               ref bit data_ack_pattern[$]);
    data_ack_pattern.delete();

    for (int unsigned i = 0; i < data_length; i++) begin
      data_ack_pattern.push_back(i != nack_byte_idx);
    end
  endfunction

endclass
