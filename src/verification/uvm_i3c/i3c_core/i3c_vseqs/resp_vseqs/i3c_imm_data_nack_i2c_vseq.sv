class i3c_imm_data_nack_i2c_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_imm_data_nack_i2c_vseq)

  localparam bit [3:0] RESP_I2C_DATA_NACK = 4'h9;

  function new(string name = "i3c_imm_data_nack_i2c_vseq");
    super.new(name);
  endfunction

  task body();
    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, 7'h0, 1'b1);

    for (int unsigned dtt = 2; dtt <= 4; dtt++) begin
      run_data_nack_case(3'(dtt));
    end

    run_recovery_case();

    `uvm_info(
        `gfn,
        "IMM_005 conclusion: I2C immediate write data NACK generates STOP after first byte, no later inline byte transmitted, RESP I2cDataNackOrI3cBusAborted for dtt=2..4",
        UVM_LOW)
  endtask

  virtual task run_data_nack_case(bit [2:0] dtt);
    immediate_data_trans_desc_t        imm_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;
    transfer_stimulus_cfg_t            cfg;
    byte_queue_t                       no_read_data;
    bit                         [ 3:0] tid;

    tid                       = {1'b0, dtt};

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = tid;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = dtt;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.def_or_data_byte1 = 8'hD1;
    imm_cmd.data_byte2        = 8'hD2;
    imm_cmd.data_byte3        = 8'hD3;
    imm_cmd.data_byte4        = 8'hD4;

    `uvm_info(`gfn, $sformatf("IMM_005 dtt=%0d: I2C immediate write, address ACK, data NACK", dtt),
              UVM_MEDIUM)

    cfg = make_transfer_cfg(
        .ctxt($sformatf("IMM_005 dtt%0d", dtt)),
        .seq_name($sformatf("imm005_dtt%0d_dev_seq", dtt)),
        .tid(tid),
        .dev_idx(5'd0),
        .target_addr(7'h50),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(dtt),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));

    `DV_CHECK_EQ(dev_seq.sampled_data.size(), 1,
                 $sformatf("IMM_005 dtt=%0d: only first byte should be transmitted before NACK",
                           dtt))
    `DV_CHECK_EQ(dev_seq.sampled_data[0], 8'hD1,
                 $sformatf("IMM_005 dtt=%0d: first transmitted byte must equal descriptor byte0",
                           dtt))

    read_response(resp);
    check_error_resp_fields(resp, RESP_I2C_DATA_NACK, tid, 1, cfg.ctxt);
    check_all_queues_empty($sformatf("IMM_005 after dtt=%0d", dtt));

    `uvm_info(`gfn, $sformatf("IMM_005 result: dtt=%0d resp=0x%08h sampled_bytes=%0d", dtt, resp,
                              dev_seq.sampled_data.size()), UVM_LOW)
  endtask

  virtual task run_recovery_case();
    immediate_data_trans_desc_t imm_cmd;
    bit                  [31:0] resp;
    i3c_device_response_seq     dev_seq;
    transfer_stimulus_cfg_t     cfg;
    byte_queue_t                no_read_data;
    byte_queue_t                exp_data;

    exp_data.push_back(8'hE1);

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = 4'hE;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = 3'd1;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.def_or_data_byte1 = exp_data[0];

    cfg = make_transfer_cfg(
        .ctxt("IMM_005 recovery without SW reset"),
        .seq_name("imm005_recovery_dev_seq"),
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
    check_sampled_write_data(dev_seq, exp_data, exp_data.size(), cfg.ctxt);
    read_response(resp);
    check_success_resp_fields(resp, cfg.tid, exp_data.size(), cfg.ctxt);
    check_all_queues_empty(cfg.ctxt);
  endtask

endclass
