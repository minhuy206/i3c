class csr_broadcast_header_control_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_broadcast_header_control_vseq)

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
    event      control_check_done;

    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                 "CSR_003 reset: HC_CONTROL.ENABLE should reset to 0")
    `DV_CHECK_EQ(data[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT], 1'b0,
                 "CSR_003 reset: BROADCAST_HEADER_ENABLE should reset to 0")
    reg_read(ADDR_RESET_CONTROL, data);
    `DV_CHECK_EQ(data[RESET_CTRL_SOFT_RST_BIT], 1'b0,
                 "CSR_003 reset: RESET_CONTROL.SOFT_RST should read 0")

    fork
      check_no_host_start_until_event(control_check_done, "csr_broadcast_header_control_vseq");
      begin
        reg_write(ADDR_HC_CONTROL, hc_control_value(.iba_include(1'b1)));
        reg_read(ADDR_HC_CONTROL, data);
        `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                     "CSR_003 set-only: BROADCAST_HEADER_ENABLE must not set ENABLE")
        `DV_CHECK_EQ(data[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT], 1'b1,
                     "CSR_003 set-only: BROADCAST_HEADER_ENABLE readback mismatch")

        reg_read(ADDR_HC_STATUS, data);
        `DV_CHECK_EQ(data[HC_STS_FSM_IDLE_BIT], 1'b1,
                     "CSR_003 set-only: controller should remain idle")

        disable_dut();
        reg_read(ADDR_HC_CONTROL, data);
        `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                     "CSR_003 clear: HC_CONTROL.ENABLE should remain 0")
        `DV_CHECK_EQ(data[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT], 1'b0,
                     "CSR_003 clear: BROADCAST_HEADER_ENABLE readback mismatch")
        ->control_check_done;
      end
    join
  endtask

  virtual task check_functional_write_effect(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    reg_read(ADDR_HC_CONTROL, resp);
    `DV_CHECK_EQ(resp[HC_CTRL_ENABLE_BIT], 1'b1,
                 "CSR_003 functional: HC_CONTROL.ENABLE readback mismatch")
    `DV_CHECK_EQ(resp[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT], broadcast_header_enable,
                 "CSR_003 functional: BROADCAST_HEADER_ENABLE readback mismatch")

    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    build_random_tx_words(DATA_LENGTH, exp_data, tx_words);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("CSR_003 %s write", private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("csr003_%s_dev_seq", private_addr_mode_name(broadcast_header_enable))),
        .tid(broadcast_header_enable ? 4'd2 : 4'd1),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    `DV_CHECK_EQ(dev_seq.sampled_addr, cfg.target_addr,
                 $sformatf("CSR_003 %s: target address mismatch",
                           private_addr_mode_name(broadcast_header_enable)))
    `DV_CHECK_EQ(dev_seq.observed_broadcast_header, broadcast_header_enable,
                 $sformatf("CSR_003 %s: broadcast header observation mismatch",
                           private_addr_mode_name(broadcast_header_enable)))
    `DV_CHECK_EQ(dev_seq.observed_broadcast_rstart, broadcast_header_enable,
                 $sformatf("CSR_003 %s: broadcast repeated START observation mismatch",
                           private_addr_mode_name(broadcast_header_enable)))

    check_all_queues_empty(
        $sformatf("after CSR_003 %s write", private_addr_mode_name(broadcast_header_enable)));
  endtask

endclass
