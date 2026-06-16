class i3c_read_toc_zero_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_toc_zero_vseq)

  function new(string name = "i3c_read_toc_zero_vseq");
    super.new(name);
  endfunction

  virtual task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_read_toc_zero_case(broadcast_modes[mode_idx]);
    end

    `uvm_info(`gfn,
              "SDRR_008 conclusion: toc=0 keeps the SDR private transaction active with one repeated START before the following command",
              UVM_LOW)
  endtask

  virtual task run_read_toc_zero_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t rd_cfg;
    transfer_stimulus_cfg_t wr_cfg;
    byte_queue_t            read_data;
    word_queue_t            tx_words;
    bit [31:0]              resp0;
    bit [31:0]              resp1;
    bit [31:0]              rx;
    int                     rstart_count;
    i3c_device_response_seq dev_seq0;
    i3c_device_response_seq dev_seq1;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    rd_cfg                   = make_transfer_cfg(
        .ctxt($sformatf("read_toc0_vseq %s first", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("dev_seq0_%s", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd5),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(2),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );
    wr_cfg                   = make_transfer_cfg(
        .ctxt($sformatf("read_toc0_vseq %s second", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("dev_seq1_%s", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    read_data.push_back(8'h11);
    read_data.push_back(8'h22);
    tx_words.push_back(32'h0000_4433);

    run_toc_zero_read_write_stimulus(rd_cfg, wr_cfg, read_data, tx_words, rx, resp0, resp1,
                                     rstart_count, dev_seq0, dev_seq1);

    `DV_CHECK_EQ(dev_seq0.done, 1'b1, "read_toc0_vseq: first device response did not finish")
    `DV_CHECK_EQ(dev_seq1.done, 1'b1, "read_toc0_vseq: second device response did not finish")
    `DV_CHECK_EQ(rstart_count, 1, "read_toc0_vseq: expected exactly one observed RSTART")
    `DV_CHECK_EQ(dev_seq0.observed_rstart, 1'b1,
                 "read_toc0_vseq: first read should end with RSTART")
    `DV_CHECK_EQ(dev_seq1.observed_rstart, 1'b0,
                 "read_toc0_vseq: second write should end with STOP")

    `DV_CHECK_EQ(resp0[31:28], 4'h0,         "read_toc0_vseq: first response expected Success")
    `DV_CHECK_EQ(resp0[27:24], 4'd5,         "read_toc0_vseq: first response TID mismatch")
    `DV_CHECK_EQ(resp0[15:0],  16'd2,        "read_toc0_vseq: first response length mismatch")
    `DV_CHECK_EQ(resp1[31:28], 4'h0,         "read_toc0_vseq: second response expected Success")
    `DV_CHECK_EQ(resp1[27:24], 4'd6,         "read_toc0_vseq: second response TID mismatch")
    `DV_CHECK_EQ(resp1[15:0],  16'd2,        "read_toc0_vseq: second response length mismatch")

    `uvm_info(`gfn, $sformatf(
                  "SDRR_008 result: mode=%s rstart_count=%0d first_observed_rstart=%0b second_observed_rstart=%0b read_resp_len=%0d write_resp_len=%0d",
                  private_addr_mode_name(broadcast_header_enable), rstart_count,
                  dev_seq0.observed_rstart, dev_seq1.observed_rstart, resp0[15:0],
                  resp1[15:0]), UVM_LOW)
  endtask
endclass
