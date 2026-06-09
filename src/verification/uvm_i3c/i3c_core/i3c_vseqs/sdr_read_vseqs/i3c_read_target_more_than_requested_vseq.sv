class i3c_read_target_more_than_requested_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_target_more_than_requested_vseq)

  localparam int unsigned NUM_CASES = 3;

  function new(string name = "i3c_read_target_more_than_requested_vseq");
    super.new(name);
  endfunction

  task body();
    int unsigned req_lengths[NUM_CASES] = '{1, 4, 5};
    int unsigned target_lengths[NUM_CASES] = '{3, 6, 8};

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    foreach (req_lengths[case_idx]) begin
      run_more_than_requested_case(case_idx, req_lengths[case_idx], target_lengths[case_idx]);
    end

    `uvm_info(`gfn, "SDRR_004 I3C read target-more-than-requested checks passed", UVM_LOW)
  endtask

  virtual task run_more_than_requested_case(int unsigned case_idx, int unsigned requested_length,
                                            int unsigned target_length);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    word_queue_t                   rx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    `DV_CHECK_GT(target_length, requested_length,
                 $sformatf("SDRR_004 case %0d must provide more target bytes than requested",
                           case_idx))

    build_payload(case_idx, target_length, read_data);

    cfg = make_transfer_cfg(
        $sformatf(
            "SDRR_004 req %0d target %0d", requested_length, target_length
        ),
        $sformatf(
            "sdrr004_dev_seq_%0d_%0d", requested_length, target_length
        ),
        4'(case_idx + 1),
        5'd0,
        7'h08,
        1'b1,
        requested_length
    );
    cfg.wait_device_done = 1'b1;

    run_read_stimulus_words_with_actual_len(cfg, read_data, requested_length, rx_words, resp,
                                            dev_seq, 1'b1);

    `DV_CHECK_EQ(dev_seq.done, 1'b1,
                 $sformatf("SDRR_004 req %0d target %0d: device response did not finish",
                           requested_length, target_length))
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08,
                 $sformatf("SDRR_004 req %0d target %0d: target address mismatch",
                           requested_length, target_length))
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b1,
                 $sformatf("SDRR_004 req %0d target %0d: transfer direction should be read",
                           requested_length, target_length))
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b1,
                 $sformatf("SDRR_004 req %0d target %0d: controller should terminate read with RSTART",
                           requested_length, target_length))

    `DV_CHECK_EQ(resp[31:28], 4'h0, $sformatf(
                                        "SDRR_004 req %0d target %0d: expected Success response",
                                        requested_length, target_length))
    `DV_CHECK_EQ(resp[27:24], cfg.tid, $sformatf(
                                           "SDRR_004 req %0d target %0d: response TID mismatch",
                                           requested_length, target_length))
    `DV_CHECK_EQ(resp[15:0], 16'(requested_length),
                 $sformatf("SDRR_004 req %0d target %0d: response length mismatch",
                           requested_length, target_length))

    check_all_queues_empty($sformatf(
                           "after SDRR_004 req %0d target %0d", requested_length, target_length));
  endtask

  virtual function void build_payload(int unsigned case_idx, int unsigned target_length,
                                      ref byte_queue_t read_data);
    read_data.delete();

    for (int unsigned i = 0; i < target_length; i++) begin
      read_data.push_back(8'(8'hC0 + (case_idx * 8) + i));
    end
  endfunction

endclass
