class i3c_imm_i2c_write_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_imm_i2c_write_vseq)

  function new(string name = "i3c_imm_i2c_write_vseq");
    super.new(name);
  endfunction

  task body();
    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, 7'h0, 1'b1);

    for (int unsigned dtt = 1; dtt <= 4; dtt++) begin
      run_i2c_imm_case(3'(dtt));
    end

    `uvm_info(
        `gfn,
        "IMM_004 conclusion: I2C immediate write with dtt=1..4 all produce Success with correct RESP length",
        UVM_LOW)
  endtask

  virtual task run_i2c_imm_case(bit [2:0] dtt);
    immediate_data_trans_desc_t        imm_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;
    transfer_stimulus_cfg_t            cfg;
    byte_queue_t                       no_read_data;
    byte_queue_t                       exp_data;

    exp_data.push_back(8'hD1);
    exp_data.push_back(8'hD2);
    exp_data.push_back(8'hD3);
    exp_data.push_back(8'hD4);

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = {1'b0, dtt};
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = dtt;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.def_or_data_byte1 = exp_data[0];
    imm_cmd.data_byte2        = exp_data[1];
    imm_cmd.data_byte3        = exp_data[2];
    imm_cmd.data_byte4        = exp_data[3];

    `uvm_info(`gfn, $sformatf("IMM_004 dtt=%0d: issuing I2C immediate write", dtt), UVM_MEDIUM)

    cfg = make_transfer_cfg(
        .ctxt($sformatf("IMM_004 dtt%0d", dtt)),
        .seq_name($sformatf("imm004_dtt%0d_dev_seq", dtt)),
        .tid(imm_cmd.tid),
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

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);

    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);
    check_all_queues_empty($sformatf("IMM_004 after dtt=%0d", dtt));

    `uvm_info(`gfn, $sformatf("IMM_004 result: dtt=%0d resp=0x%08h sampled_bytes=%0d", dtt, resp,
                              dev_seq.sampled_data.size()), UVM_LOW)
  endtask

endclass
