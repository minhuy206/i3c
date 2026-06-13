class i3c_write_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_vseq)

  function new(string name = "i3c_write_vseq");
    super.new(name);
  endfunction

  task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_write_case(broadcast_modes[mode_idx]);
    end
  endtask

  virtual task run_write_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg;
    word_queue_t            tx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg               = make_transfer_cfg(
        .ctxt($sformatf("write_vseq %s", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("dev_seq_%s", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd1),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(4),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    tx_words.push_back(32'hDEAD_BEEF);

    run_write_stimulus(cfg, tx_words, resp, dev_seq);
    check_success_resp(resp, cfg);
  endtask

endclass
