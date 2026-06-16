class i3c_read_short_target_end_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_short_target_end_vseq)

  localparam int unsigned NUM_CASES = 4;
  localparam logic [3:0] RESP_SHORT_READ = 4'h7;

  function new(string name = "i3c_read_short_target_end_vseq");
    super.new(name);
  endfunction

  task body();
    int unsigned req_lengths[NUM_CASES] = '{4, 8, 8, 9};
    int unsigned actual_lengths[NUM_CASES] = '{1, 3, 4, 5};
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      enable_dut(broadcast_modes[mode_idx]);
      write_dat_entry(0, 7'h50, 7'h08, 1'b0);

      foreach (req_lengths[case_idx]) begin
        run_short_case(case_idx, req_lengths[case_idx], actual_lengths[case_idx],
                       broadcast_modes[mode_idx]);
      end
    end

    `uvm_info(`gfn,
              "SDRR_003 conclusion: target early end drains only transferred read bytes and leaves the queues clean in both private-address modes",
              UVM_LOW)
  endtask

  virtual task run_short_case(int unsigned case_idx, int unsigned requested_length,
                              int unsigned actual_length, bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    word_queue_t                   rx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    `DV_CHECK_LT(actual_length, requested_length,
                 $sformatf("SDRR_003 case %0d must end before requested length", case_idx))

    build_payload(case_idx, actual_length, read_data);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRR_003 %s req %0d actual %0d",
            private_addr_mode_name(
                broadcast_header_enable
            ),
            requested_length,
            actual_length
        )),
        .seq_name($sformatf(
            "sdrr003_%s_dev_seq_%0d_%0d",
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
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(requested_length),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_read_stimulus_words_with_actual_len(cfg, read_data, actual_length, rx_words, resp, dev_seq);

    check_all_queues_empty($sformatf(
                           "after SDRR_003 req %0d actual %0d", requested_length, actual_length));

    `uvm_info(`gfn, $sformatf(
                  "SDRR_003 result: mode=%s requested_len=%0d actual_len=%0d rx_words_drained=%0d",
                  private_addr_mode_name(broadcast_header_enable), requested_length, actual_length,
                  rx_words.size()), UVM_LOW)
  endtask

  virtual function void build_payload(int unsigned case_idx, int unsigned actual_length,
                                      ref byte_queue_t read_data);
    read_data.delete();

    for (int unsigned i = 0; i < actual_length; i++) begin
      read_data.push_back(8'(8'h90 + (case_idx * 8) + i));
    end
  endfunction

endclass
