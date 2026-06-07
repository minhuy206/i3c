class i3c_read_target_more_than_requested_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_target_more_than_requested_vseq)

  localparam int unsigned NUM_CASES = 3;
  localparam int unsigned FLOW_STATE_ISSUE_CMD = 12;
  localparam int unsigned PHASE_ADDR_ACK = 2;
  localparam string FLOW_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm";

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

  virtual task run_more_than_requested_case(int unsigned case_idx,
                                            int unsigned requested_length,
                                            int unsigned target_length);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    word_queue_t            exp_words;
    word_queue_t            rx_words;
    bit [31:0]              resp;
    bit                     forced_continue_tbit;
    i3c_device_response_seq dev_seq;

    `DV_CHECK_GT(target_length, requested_length,
                 $sformatf("SDRR_004 case %0d must provide more target bytes than requested",
                           case_idx))

    build_payload(case_idx, requested_length, target_length, read_data, exp_words);

    cfg                  = make_transfer_cfg(
        $sformatf("SDRR_004 req %0d target %0d", requested_length, target_length),
        $sformatf("sdrr004_dev_seq_%0d_%0d", requested_length, target_length),
        4'(case_idx + 1),
        5'd0,
        7'h08,
        1'b1,
        requested_length
    );
    cfg.wait_device_done = 1'b1;

    fork
      force_final_read_tbit_continue(cfg.ctxt, forced_continue_tbit);
      run_read_stimulus_words_with_actual_len(cfg, read_data, requested_length, rx_words, resp,
                                              dev_seq);
    join

    `DV_CHECK_EQ(forced_continue_tbit, 1'b1,
                 $sformatf("SDRR_004 req %0d target %0d: final target continue T-bit was not injected",
                           requested_length, target_length))

    `DV_CHECK_EQ(dev_seq.done, 1'b1,
                 $sformatf("SDRR_004 req %0d target %0d: device response did not finish",
                           requested_length, target_length))
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08,
                 $sformatf("SDRR_004 req %0d target %0d: target address mismatch",
                           requested_length, target_length))
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b1,
                 $sformatf("SDRR_004 req %0d target %0d: transfer direction should be read",
                           requested_length, target_length))
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b0,
                 $sformatf("SDRR_004 req %0d target %0d: toc=1 read should end with STOP",
                           requested_length, target_length))

    `DV_CHECK_EQ(rx_words.size(), exp_words.size(),
                 $sformatf("SDRR_004 req %0d target %0d: RX word count mismatch",
                           requested_length, target_length))
    for (int unsigned i = 0; i < exp_words.size(); i++) begin
      if (i < rx_words.size()) begin
        `DV_CHECK_EQ(rx_words[i], exp_words[i],
                     $sformatf("SDRR_004 req %0d target %0d: RX word[%0d] mismatch",
                               requested_length, target_length, i))
      end
    end

    `DV_CHECK_EQ(resp[31:28], 4'h0,
                 $sformatf("SDRR_004 req %0d target %0d: expected Success response",
                           requested_length, target_length))
    `DV_CHECK_EQ(resp[27:24], cfg.tid,
                 $sformatf("SDRR_004 req %0d target %0d: response TID mismatch",
                           requested_length, target_length))
    `DV_CHECK_EQ(resp[15:0], 16'(requested_length),
                 $sformatf("SDRR_004 req %0d target %0d: response length mismatch",
                           requested_length, target_length))

    check_all_queues_empty($sformatf("after SDRR_004 req %0d target %0d",
                                     requested_length, target_length));
  endtask

  virtual function void build_payload(int unsigned case_idx,
                                      int unsigned requested_length,
                                      int unsigned target_length,
                                      ref byte_queue_t read_data,
                                      ref word_queue_t exp_words);
    bit [31:0] rx_word;

    read_data.delete();
    exp_words.delete();

    for (int unsigned i = 0; i < requested_length; i++) begin
      read_data.push_back(8'(8'hC0 + (case_idx * 8) + i));
    end

    for (int unsigned word_idx = 0; word_idx < ((requested_length + 3) / 4); word_idx++) begin
      rx_word = '0;
      for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++) begin
        int unsigned data_idx;

        data_idx = (word_idx * 4) + byte_idx;
        if (data_idx < requested_length) begin
          rx_word[(byte_idx*8)+:8] = read_data[data_idx];
        end
      end
      exp_words.push_back(rx_word);
    end
  endfunction

  virtual task force_final_read_tbit_continue(string ctxt, output bit forced);
    string state_path;
    string phase_path;
    string remaining_path;
    string done_path;
    string data_path;

    state_path     = {FLOW_PATH, ".state_q"};
    phase_path     = {FLOW_PATH, ".issue_phase_q"};
    remaining_path = {FLOW_PATH, ".remaining_len_q"};
    done_path      = {FLOW_PATH, ".bus_rx_done_i"};
    data_path      = {FLOW_PATH, ".bus_rx_data_i"};
    forced         = 1'b0;

    for (int unsigned cycle = 0; cycle < 10000; cycle++) begin
      bit [31:0] state;
      bit [31:0] phase;
      bit [31:0] remaining;

      state     = hdl_read_word(state_path);
      phase     = hdl_read_word(phase_path);
      remaining = hdl_read_word(remaining_path);

      if (state[3:0] == FLOW_STATE_ISSUE_CMD &&
          phase[7:0] > PHASE_ADDR_ACK &&
          !phase[0] &&
          remaining[15:0] == 16'd1 &&
          !hdl_read_bit(done_path)) begin
        hdl_force_checked(data_path, 8'h01);

        for (int unsigned done_cycle = 0; done_cycle < 512; done_cycle++) begin
          @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
          if (hdl_read_bit(done_path)) begin
            forced = 1'b1;
            @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
            hdl_release_checked(data_path);
            return;
          end
        end

        hdl_release_checked(data_path);
        `uvm_error(`gfn, $sformatf("%s: timed out waiting for forced final read T-bit sample",
                                   ctxt))
        return;
      end

      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    end

    `uvm_error(`gfn, $sformatf("%s: final read T-bit phase was not reached", ctxt))
  endtask

endclass
