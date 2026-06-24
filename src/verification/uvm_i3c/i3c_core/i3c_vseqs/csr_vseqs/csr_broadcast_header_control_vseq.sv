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

    fork
      check_no_host_start_for_cycles(100, "csr_broadcast_header_control_vseq");
      begin
        reg_write(ADDR_HC_CONTROL, 32'h0000_0004);
        reg_read(ADDR_HC_CONTROL, data);
      end
    join

    reg_read(ADDR_HC_STATUS, data);

    disable_dut();
    reg_read(ADDR_HC_CONTROL, data);
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




    check_all_queues_empty($sformatf("after CSR_003 %s write",
                                     private_addr_mode_name(broadcast_header_enable)));
  endtask

endclass
