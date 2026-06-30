class i3c_read_back_to_back_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_back_to_back_vseq)

  function new(string name = "i3c_read_back_to_back_vseq");
    super.new(name);
  endfunction

  task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_back_to_back_case(broadcast_modes[mode_idx]);
    end

  endtask

  virtual task run_back_to_back_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        cfg1;
    transfer_stimulus_cfg_t        cfg2;
    byte_queue_t                   read_data0;
    byte_queue_t                   read_data1;
    byte_queue_t                   read_data2;
    word_queue_t                   rx_words0;
    word_queue_t                   rx_words1;
    word_queue_t                   rx_words2;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    bit                     [31:0] resp2;
    bit                      [6:0] static_addr;
    bit                      [6:0] dynamic_addr;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;
    i3c_device_response_seq        dev_seq2;

    disable_dut();
    randomize_i3c_dat_target(0, static_addr, dynamic_addr);

    cfg0 = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRR_005 %s back_to_back[0]", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrr005_%s_dev_seq0", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'h8),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(3),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    cfg1 = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRR_005 %s back_to_back[1]", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrr005_%s_dev_seq1", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'h9),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(5),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    cfg2 = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRR_005 %s back_to_back[2]", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "sdrr005_%s_dev_seq2", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'hA),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
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

    build_random_payload(cfg0.data_length, read_data0);
    build_random_payload(cfg1.data_length, read_data1);
    build_random_payload(cfg2.data_length, read_data2);
    start_back_to_back_device_responses(cfg0, read_data0, cfg1, read_data1, cfg2, read_data2,
                                        dev_seq0, dev_seq1, dev_seq2);

    write_read_cmd(cfg0);
    write_read_cmd(cfg1);
    write_read_cmd(cfg2);

    enable_dut(broadcast_header_enable);
    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    wait_for_device_done(dev_seq2, cfg2.ctxt, device_done_timeout_cycles(cfg2));

    read_rx_words(cfg0.data_length, rx_words0);
    read_rx_words(cfg1.data_length, rx_words1);
    read_rx_words(cfg2.data_length, rx_words2);
    read_response(resp0);
    read_response(resp1);
    read_response(resp2);


    check_all_queues_empty("after SDRR_005 back_to_back");
    disable_dut();

    `uvm_info(`gfn, $sformatf(
                  "SDRR_005 result: mode=%s queued_cmds=3 target_addr=0x%02h rx_words_drained={%0d,%0d,%0d} observed_rstart={%0b,%0b,%0b}",
                  private_addr_mode_name(broadcast_header_enable), dynamic_addr, rx_words0.size(),
                  rx_words1.size(), rx_words2.size(), dev_seq0.observed_rstart,
                  dev_seq1.observed_rstart, dev_seq2.observed_rstart), UVM_LOW)
  endtask

  virtual task start_back_to_back_device_responses(
      input transfer_stimulus_cfg_t cfg0, input byte_queue_t read_data0,
      input transfer_stimulus_cfg_t cfg1, input byte_queue_t read_data1,
      input transfer_stimulus_cfg_t cfg2, input byte_queue_t read_data2,
      output i3c_device_response_seq dev_seq0, output i3c_device_response_seq dev_seq1,
      output i3c_device_response_seq dev_seq2);
    start_device_response(cfg0, 1'b1, read_data0, dev_seq0);
    wait_for_device_request_issued(dev_seq0, cfg0.ctxt);

    start_device_response(cfg1, 1'b1, read_data1, dev_seq1);
    settle_cycles(1);
    start_device_response(cfg2, 1'b1, read_data2, dev_seq2);
    settle_cycles(1);
  endtask



endclass
