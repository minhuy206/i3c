class i3c_read_short_target_end_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_short_target_end_vseq)

  localparam int unsigned NUM_CASES = 5;
  function new(string name = "i3c_read_short_target_end_vseq");
    super.new(name);
  endfunction

  task body();
    int unsigned req_lengths[NUM_CASES] = '{4, 8, 8, 9, 6};
    int unsigned actual_lengths[NUM_CASES] = '{1, 3, 4, 5, 5};
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      enable_dut(broadcast_modes[mode_idx]);
      write_dat_entry(0, 7'h50, 7'h08, 1'b0);

      foreach (req_lengths[case_idx]) begin
        run_short_case(case_idx, req_lengths[case_idx], actual_lengths[case_idx],
                       broadcast_modes[mode_idx]);
      end
    end

    run_sre_wroc_policy_case(1'b1, 1'b0, 4'd12);
    run_sre_wroc_policy_case(1'b0, 1'b1, 4'd13);
    run_sre_wroc_policy_case(1'b0, 1'b0, 4'd14);
    run_short_toc_zero_case();

  endtask

  virtual task run_short_toc_zero_case();
    transfer_stimulus_cfg_t        rd_cfg;
    transfer_stimulus_cfg_t        wr_cfg;
    byte_queue_t                   read_data;  // 2 bytes only -> short vs requested 4
    word_queue_t                   tx_words;
    bit                     [31:0] rx;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    int                            rstart_count;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;

    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    rd_cfg = make_transfer_cfg(
        .ctxt("ERR_005 toc0 permitted_short_read_first"),
        .seq_name("err005_toc0_rd_dev_seq"),
        .tid(4'd10),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(4),
        .settle_before_cmd(5),
        .timeout_cycles(0),
        .sre(1'b0),
        .wroc(1'b1)
    );
    wr_cfg = make_transfer_cfg(
        .ctxt("ERR_005 toc0 write_second"),
        .seq_name("err005_toc0_wr_dev_seq"),
        .tid(4'd11),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    build_random_payload(2, read_data);
    begin
      byte_queue_t exp_write_data;
      build_random_tx_words(wr_cfg.data_length, exp_write_data, tx_words);
    end

    run_toc_zero_read_write_stimulus(rd_cfg, wr_cfg, read_data, tx_words, rx, resp0, resp1,
                                     rstart_count, dev_seq0, dev_seq1);

    `DV_CHECK_EQ(rstart_count, 0,
                 "ERR_005 toc0: short read must suppress the continuation (no continuation RSTART)")

    check_all_queues_empty("after ERR_005 toc0 permitted short-read continuation suppression");

  endtask

  virtual task run_sre_wroc_policy_case(bit sre, bit wroc, bit [3:0] tid);
    localparam int unsigned RequestedLength = 4;
    localparam int unsigned ActualLength = 2;
    transfer_stimulus_cfg_t        cfg;
    regular_trans_desc_t           rd_cmd;
    byte_queue_t                   read_data;
    word_queue_t                   rx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(1'b0);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);
    build_random_payload(ActualLength, read_data);
    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_005 sre=%0b wroc=%0b", sre, wroc)),
        .seq_name($sformatf("err005_sre%0b_wroc%0b_dev_seq", sre, wroc)),
        .tid(tid),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(RequestedLength),
        .settle_before_cmd(0),
        .timeout_cycles(0),
        .sre(sre),
        .wroc(wroc)
    );

    if (sre || wroc) begin
      run_read_stimulus_words(cfg, read_data, ActualLength, rx_words, resp, dev_seq);
    end else begin
      rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b1);
      start_device_response(cfg, 1'b1, read_data, dev_seq);
      write_cmd(rd_cmd[31:0], rd_cmd[63:32]);
      poll_idle();
      wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
      read_rx_words(ActualLength, rx_words);
      check_queue_flags(resp_paths.name, resp_paths.full_bit, resp_paths.empty_bit, 1'b0, 1'b1,
                        "after permitted short read with wroc=0");
    end

    check_all_queues_empty($sformatf("after ERR_005 sre=%0b wroc=%0b", sre, wroc));
  endtask

  virtual task run_short_case(int unsigned case_idx, int unsigned requested_length,
                              int unsigned actual_length, bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    word_queue_t                   rx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    `DV_CHECK_LT(actual_length, requested_length,
                 $sformatf("ERR_005 case %0d must end before requested length", case_idx))

    build_payload(case_idx, actual_length, read_data);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_005 %s req %0d actual %0d",
            private_addr_mode_name(
                broadcast_header_enable
            ),
            requested_length,
            actual_length
        )),
        .seq_name($sformatf(
            "err005_%s_dev_seq_%0d_%0d",
            private_addr_mode_name(
                broadcast_header_enable
            ),
            requested_length,
            actual_length
        )),
        .tid(4'(case_idx + 1)),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(requested_length),
        .settle_before_cmd(0),
        .timeout_cycles(0),
        .sre(1'b1),
        .wroc(1'b1)
    );

    run_read_stimulus_words(cfg, read_data, actual_length, rx_words, resp, dev_seq);

    check_all_queues_empty($sformatf(
                           "after ERR_005 req %0d actual %0d", requested_length, actual_length));

    `uvm_info(`gfn,
              $sformatf(
                  "ERR_005 result: mode=%s requested_len=%0d actual_len=%0d rx_words_drained=%0d",
                  private_addr_mode_name(broadcast_header_enable), requested_length, actual_length,
                  rx_words.size()), UVM_LOW)
  endtask

  virtual function void build_payload(int unsigned case_idx, int unsigned actual_length,
                                      ref byte_queue_t read_data);
    build_random_payload(actual_length, read_data);
  endfunction

endclass
