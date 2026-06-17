class i3c_imm_toc_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_imm_toc_vseq)

  function new(string name = "i3c_imm_toc_vseq");
    super.new(name);
  endfunction

  task body();
    bit i3c_broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (i3c_broadcast_modes[mode_idx]) begin
      run_toc_case(.is_i2c(1'b0), .broadcast_header_enable(i3c_broadcast_modes[mode_idx]),
                   .toc(1'b1), .tid({1'b0, i3c_broadcast_modes[mode_idx], 1'b1, 1'b0}));
      run_toc_case(.is_i2c(1'b0), .broadcast_header_enable(i3c_broadcast_modes[mode_idx]),
                   .toc(1'b0), .tid({1'b0, i3c_broadcast_modes[mode_idx], 1'b0, 1'b0}));
    end

    run_toc_case(.is_i2c(1'b1), .broadcast_header_enable(1'b0), .toc(1'b1), .tid(4'hC));
    run_toc_case(.is_i2c(1'b1), .broadcast_header_enable(1'b0), .toc(1'b0), .tid(4'hD));
  endtask

  virtual task run_toc_case(bit is_i2c, bit broadcast_header_enable, bit toc, bit [3:0] tid);
    transfer_stimulus_cfg_t     cfg;
    immediate_data_trans_desc_t imm_cmd;
    i3c_device_response_seq     dev_seq;
    byte_queue_t                no_read_data;
    byte_queue_t                exp_data;
    bit [31:0]                  resp;
    bit [6:0]                   target_addr;
    string                      device_name;

    target_addr = is_i2c ? 7'h50 : 7'h08;
    device_name = is_i2c ? "i2c" : "i3c";

    enable_dut(broadcast_header_enable && !is_i2c);
    write_dat_entry(0, 7'h50, 7'h08, is_i2c);

    exp_data.push_back(8'hAA);
    exp_data.push_back(8'hBB);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("IMM_003 %s %s toc%0d", device_name,
                        private_addr_mode_name(broadcast_header_enable && !is_i2c), toc)),
        .seq_name($sformatf("imm003_%s_%s_toc%0d_dev_seq", device_name,
                            private_addr_mode_name(broadcast_header_enable && !is_i2c), toc)),
        .tid(tid),
        .dev_idx(5'd0),
        .target_addr(target_addr),
        .is_i3c(!is_i2c),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable && !is_i2c),
        .data_length(exp_data.size()),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = tid;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = 3'd2;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = toc;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.def_or_data_byte1 = exp_data[0];
    imm_cmd.data_byte2        = exp_data[1];

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    check_sampled_write_data(dev_seq, exp_data, exp_data.size(), cfg.ctxt);
    `DV_CHECK_EQ(dev_seq.observed_broadcast_header, cfg.start_with_broadcast_header,
                 $sformatf("%s: broadcast-header observation mismatch", cfg.ctxt))
    read_response(resp);
    if (toc) begin
      check_success_resp_fields(resp, tid, exp_data.size(), cfg.ctxt);
    end else begin
      check_error_resp_fields(resp, 4'hA, tid, exp_data.size(), cfg.ctxt);
    end
    check_all_queues_empty($sformatf("after %s", cfg.ctxt));

    `uvm_info(`gfn, $sformatf("IMM_003 result: %s toc=%0b resp=0x%08h", cfg.ctxt, toc,
                              resp), UVM_LOW)
  endtask
endclass
