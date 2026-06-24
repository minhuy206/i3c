class i3c_imm_dtt_sweep_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_imm_dtt_sweep_vseq)

  function new(string name = "i3c_imm_dtt_sweep_vseq");
    super.new(name);
  endfunction

  task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      for (int unsigned dtt = 0; dtt <= 7; dtt++) begin
        run_dtt_case(broadcast_modes[mode_idx], 3'(dtt),
                     {broadcast_modes[mode_idx], 3'(dtt)});
      end
    end
  endtask

  virtual task run_dtt_case(bit broadcast_header_enable, bit [2:0] dtt, bit [3:0] tid);
    transfer_stimulus_cfg_t    cfg;
    immediate_data_trans_desc_t imm_cmd;
    i3c_device_response_seq     dev_seq;
    byte_queue_t                no_read_data;
    byte_queue_t                exp_data;
    bit [31:0]                  resp;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    exp_data.push_back(8'hA1);
    exp_data.push_back(8'hA2);
    exp_data.push_back(8'hA3);
    exp_data.push_back(8'hA4);

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = tid;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = dtt;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.def_or_data_byte1 = exp_data[0];
    imm_cmd.data_byte2        = exp_data[1];
    imm_cmd.data_byte3        = exp_data[2];
    imm_cmd.data_byte4        = exp_data[3];

    cfg = make_transfer_cfg(
        .ctxt($sformatf("IMM_002 %s dtt%0d", private_addr_mode_name(broadcast_header_enable),
                        dtt)),
        .seq_name($sformatf("imm002_%s_dtt%0d_dev_seq",
                            private_addr_mode_name(broadcast_header_enable), dtt)),
        .tid(tid),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(dtt),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    if (dtt <= 3'd4) begin
      start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    end

    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);
    poll_idle();

    if (dtt <= 3'd4) begin
      wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
      read_response(resp);
    end else begin
      read_response(resp);
    end

    check_all_queues_empty($sformatf("after %s", cfg.ctxt));
    `uvm_info(`gfn, $sformatf("IMM_002 result: mode=%s dtt=%0d resp=0x%08h",
                              private_addr_mode_name(broadcast_header_enable), dtt, resp), UVM_LOW)
  endtask
endclass
