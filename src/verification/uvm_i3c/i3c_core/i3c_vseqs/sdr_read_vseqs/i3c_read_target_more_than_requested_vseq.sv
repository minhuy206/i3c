class i3c_read_target_more_than_requested_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_target_more_than_requested_vseq)

  localparam int unsigned NUM_CASES = 4;

  function new(string name = "i3c_read_target_more_than_requested_vseq");
    super.new(name);
  endfunction

  task body();
    int unsigned req_lengths[NUM_CASES] = '{1, 4, 5, 4};
    int unsigned target_lengths[NUM_CASES] = '{2, 6, 8, 5};  // cases 0 and 3 are the +1 boundary
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      enable_dut(broadcast_modes[mode_idx]);
      write_dat_entry(0, 7'h50, 7'h08, 1'b0);

      foreach (req_lengths[case_idx]) begin
        run_more_than_requested_case(case_idx, req_lengths[case_idx], target_lengths[case_idx],
                                     broadcast_modes[mode_idx]);
      end
    end

    run_more_than_requested_toc_zero_case();

  endtask

  virtual task run_more_than_requested_toc_zero_case();
    transfer_stimulus_cfg_t        rd_cfg;
    transfer_stimulus_cfg_t        wr_cfg;
    byte_queue_t                   read_data;  // 6 bytes offered vs 4 requested -> over-length
    byte_queue_t                   exp_data;
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
        .ctxt("SDRR_003 toc0 over_length_first"),
        .seq_name("sdrr003_toc0_rd_dev_seq"),
        .tid(4'd12),
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
        .timeout_cycles(0)
    );
    wr_cfg = make_transfer_cfg(
        .ctxt("SDRR_003 toc0 write_second"),
        .seq_name("sdrr003_toc0_wr_dev_seq"),
        .tid(4'd13),
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

    build_random_payload(6, read_data);  // target offers 6, only 4 read
    build_random_tx_words(wr_cfg.data_length, exp_data, tx_words);

    run_toc_zero_read_write_stimulus(rd_cfg, wr_cfg, read_data, tx_words, rx, resp0, resp1,
                                     rstart_count, dev_seq0, dev_seq1);

    // Over-length read is not an error: toc=0 continues into the second command with one RSTART.
    `DV_CHECK_EQ(rstart_count, 1,
                 "SDRR_003 toc0: over-length read must continue with exactly one RSTART")
    `DV_CHECK_EQ(dev_seq0.observed_rstart, 1'b1,
                 "SDRR_003 toc0: over-length first read should end with a continuation RSTART")
    `DV_CHECK_EQ(dev_seq1.observed_rstart, 1'b0,
                 "SDRR_003 toc0: second (write) command should end with STOP")

    check_all_queues_empty("after SDRR_003 toc0 over-length continuation");

  endtask

  virtual task run_more_than_requested_case(int unsigned case_idx, int unsigned requested_length,
                                            int unsigned target_length,
                                            bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    word_queue_t                   rx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    `DV_CHECK_GT(target_length, requested_length,
                 $sformatf("SDRR_003 case %0d must provide more target bytes than requested",
                           case_idx))

    build_payload(target_length, read_data);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRR_003 %s req %0d target %0d",
            private_addr_mode_name(
                broadcast_header_enable
            ),
            requested_length,
            target_length
        )),
        .seq_name($sformatf(
            "sdrr003_%s_dev_seq_%0d_%0d",
            private_addr_mode_name(
                broadcast_header_enable
            ),
            requested_length,
            target_length
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
        .timeout_cycles(0)
    );

    run_read_stimulus_words(cfg, read_data, requested_length, rx_words, resp, dev_seq, 1'b1);

    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b1,
                 $sformatf(
                     "SDRR_003 req %0d target %0d: controller should terminate read with RSTART",
                     requested_length, target_length))

    check_all_queues_empty($sformatf(
                           "after SDRR_003 req %0d target %0d", requested_length, target_length));

  endtask

  virtual function void build_payload(int unsigned target_length, ref byte_queue_t read_data);
    build_random_payload(target_length, read_data);
  endfunction

endclass
