class i3c_imm_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_imm_vseq)

  function new(string name = "i3c_imm_vseq");
    super.new(name);
  endfunction

  task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_imm_smoke_case(broadcast_modes[mode_idx], 4'(mode_idx));
    end
  endtask

  virtual task run_imm_smoke_case(bit broadcast_header_enable, bit [3:0] tid);
    transfer_stimulus_cfg_t            cfg;
    immediate_data_trans_desc_t        imm_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;
    byte_queue_t                       no_read_data;
    byte_queue_t                       exp_data;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("IMM_001 %s", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("imm001_%s_dev_seq", private_addr_mode_name(broadcast_header_enable))),
        .tid(tid),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    imm_cmd = '0;
    imm_cmd.attr = ImmediateDataTransfer;
    imm_cmd.tid = tid;
    imm_cmd.mode = sdr0;
    imm_cmd.rnw = 1'b0;
    imm_cmd.toc = 1'b1;
    imm_cmd.wroc = 1'b1;
    randomize_immediate_write_data(cfg.data_length, imm_cmd, exp_data);

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);
    check_all_queues_empty($sformatf("after %s", cfg.ctxt));

  endtask

endclass
