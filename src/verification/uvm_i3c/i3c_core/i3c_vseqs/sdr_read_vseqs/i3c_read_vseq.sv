class i3c_read_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_vseq)

  function new(string name = "i3c_read_vseq");
    super.new(name);
  endfunction

  task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_read_case(broadcast_modes[mode_idx]);
    end

  endtask

  virtual task run_read_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    bit                     [31:0] resp;
    bit                     [31:0] rx;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("read_vseq %s", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("dev_seq_%s", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd2),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(4),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    read_data.push_back(8'hCA);
    read_data.push_back(8'hFE);
    read_data.push_back(8'hBA);
    read_data.push_back(8'hBE);

    run_read_stimulus(cfg, read_data, rx, resp, dev_seq);
    check_all_queues_empty($sformatf(
                           "after SDRR_001 %s", private_addr_mode_name(broadcast_header_enable)));

    `uvm_info(`gfn, $sformatf(
                  "SDRR_001 result: mode=%s requested_len=%0d rx_word=0x%08h resp_len=%0d",
                  private_addr_mode_name(broadcast_header_enable), cfg.data_length, rx, resp[15:0]),
              UVM_LOW)
  endtask

endclass
