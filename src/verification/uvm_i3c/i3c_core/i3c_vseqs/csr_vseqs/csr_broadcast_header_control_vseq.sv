class csr_broadcast_header_control_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_broadcast_header_control_vseq)

  localparam bit [31:0] TX_WORD = 32'hDEAD_BEEF;
  localparam int unsigned DATA_LENGTH = 4;

  function new(string name = "csr_broadcast_header_control_vseq");
    super.new(name);
  endfunction

  task body();
    check_control_bit_behavior();
    check_functional_write_effect(1'b0);
    check_functional_write_effect(1'b1);

  endtask

  virtual task check_control_bit_behavior();
    bit [31:0] data;

    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                 "csr_broadcast_header_control_vseq: controller should start disabled")
    `DV_CHECK_EQ(
        data[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT], 1'b0,
        "csr_broadcast_header_control_vseq: BROADCAST_HEADER_ENABLE should start disabled")

    fork
      check_no_host_start_for_cycles(100, "csr_broadcast_header_control_vseq");
      begin
        reg_write(ADDR_HC_CONTROL, 32'h0000_0004);
        reg_read(ADDR_HC_CONTROL, data);
        `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                     "csr_broadcast_header_control_vseq: BROADCAST_HEADER_ENABLE must not enable controller")
        `DV_CHECK_EQ(
            data[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT], 1'b1,
            "csr_broadcast_header_control_vseq: BROADCAST_HEADER_ENABLE should be writable")
      end
    join

    reg_read(ADDR_HC_STATUS, data);
    `DV_CHECK_EQ(data[HC_STS_FSM_IDLE_BIT], 1'b1,
                 "csr_broadcast_header_control_vseq: controller should remain idle")

    disable_dut();
    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                 "csr_broadcast_header_control_vseq: controller should remain disabled")
    `DV_CHECK_EQ(data[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT], 1'b0,
                 "csr_broadcast_header_control_vseq: BROADCAST_HEADER_ENABLE should clear")
  endtask

  virtual task check_functional_write_effect(bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            exp_data;
    word_queue_t            tx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    exp_data.push_back(8'hEF);
    exp_data.push_back(8'hBE);
    exp_data.push_back(8'hAD);
    exp_data.push_back(8'hDE);
    tx_words.push_back(TX_WORD);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("CSR_003 %s write", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("csr003_%s_dev_seq", private_addr_mode_name(broadcast_header_enable))),
        .tid(broadcast_header_enable ? 4'd2 : 4'd1),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    `DV_CHECK_EQ(cfg.start_with_broadcast_header, broadcast_header_enable,
                 "CSR_003: private address mode mismatch")
    `DV_CHECK_EQ(dev_seq.done, 1'b1, "CSR_003: device response did not finish")
    `DV_CHECK_EQ(dev_seq.observed_broadcast_header, broadcast_header_enable,
                 $sformatf("CSR_003: observed broadcast header mismatch %s",
                           private_addr_mode_name(broadcast_header_enable)))
    `DV_CHECK_EQ(dev_seq.observed_broadcast_rstart, broadcast_header_enable,
                 $sformatf("CSR_003: observed broadcast RSTART mismatch %s",
                           private_addr_mode_name(broadcast_header_enable)))
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08, "CSR_003: target address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0, "CSR_003: transfer direction should be write")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), DATA_LENGTH, "CSR_003: sampled byte count mismatch")
    for (int unsigned i = 0; i < DATA_LENGTH; i++) begin
      if (i < dev_seq.sampled_data.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_data[i], exp_data[i],
                     $sformatf("CSR_003: sampled byte[%0d] mismatch", i))
      end
    end

    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), DATA_LENGTH,
                 "CSR_003: sampled T-bit count mismatch")
    for (int unsigned i = 0; i < DATA_LENGTH; i++) begin
      if (i < dev_seq.sampled_t_bit.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_t_bit[i], ~^exp_data[i],
                     $sformatf("CSR_003: T-bit parity mismatch for byte[%0d]", i))
      end
    end

    `DV_CHECK_EQ(resp[31:28], 4'h0, "CSR_003: expected Success response")
    `DV_CHECK_EQ(resp[27:24], cfg.tid, "CSR_003: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], 16'(DATA_LENGTH), "CSR_003: response length mismatch")

    check_all_queues_empty($sformatf("after CSR_003 %s write",
                                     private_addr_mode_name(broadcast_header_enable)));
  endtask

endclass
