class csr_base_vseq extends i3c_base_vseq;
  `uvm_object_utils(csr_base_vseq)

  function new(string name = "csr_base_vseq");
    super.new(name);
  endfunction

  virtual task settle_cycles(int unsigned cycles = 4);
    repeat (cycles) @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
  endtask

  virtual function void hdl_deposit_checked(string path, uvm_hdl_data_t value);
    if (!uvm_hdl_deposit(path, value)) begin
      `uvm_fatal(`gfn, $sformatf("%s: uvm_hdl_deposit failed for %s", get_type_name(), path))
    end
  endfunction

  virtual function uvm_hdl_data_t hdl_read_checked(string path);
    uvm_hdl_data_t value;

    if (!uvm_hdl_read(path, value)) begin
      `uvm_fatal(`gfn, $sformatf("%s: uvm_hdl_read failed for %s", get_type_name(), path))
    end
    return value;
  endfunction

  virtual function bit hdl_read_bit(string path);
    uvm_hdl_data_t value;

    value = hdl_read_checked(path);
    return value[0];
  endfunction

  virtual function bit [31:0] hdl_read_word(string path);
    uvm_hdl_data_t value;

    value = hdl_read_checked(path);
    return value[31:0];
  endfunction

  virtual task check_reg_eq(bit [11:0] addr, bit [31:0] exp, string reg_name,
                            string ctxt = "");
    bit [31:0] data;

    reg_read(addr, data);
    `DV_CHECK_EQ(data, exp, $sformatf("%s: %s value mismatch %s", get_type_name(), reg_name,
                                      ctxt))
  endtask

  virtual task check_timing_reg(bit [11:0] addr, bit [19:0] exp, string reg_name,
                                string ctxt = "");
    bit [31:0] data;

    reg_read(addr, data);
    `DV_CHECK_EQ(data[19:0], exp, $sformatf("%s: %s value mismatch %s", get_type_name(),
                                            reg_name, ctxt))
    `DV_CHECK_EQ(data[31:20], 12'h0, $sformatf(
                                         "%s: %s reserved bits should read 0 %s",
                                         get_type_name(), reg_name, ctxt))
  endtask

  virtual task check_queue_flags(string queue_name, int full_bit, int empty_bit, bit exp_full,
                                 bit exp_empty, string ctxt);
    bit [31:0] status;

    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(status[full_bit], exp_full, $sformatf(
                 "%s: %s full flag mismatch %s", get_type_name(), queue_name, ctxt))
    `DV_CHECK_EQ(status[empty_bit], exp_empty, $sformatf(
                 "%s: %s empty flag mismatch %s", get_type_name(), queue_name, ctxt))
  endtask

  virtual task check_all_queues_empty(string ctxt);
    check_queue_flags("CMD", QS_CMD_FULL_BIT, QS_CMD_EMPTY_BIT, 1'b0, 1'b1, ctxt);
    check_queue_flags("TX", QS_TX_FULL_BIT, QS_TX_EMPTY_BIT, 1'b0, 1'b1, ctxt);
    check_queue_flags("RX", QS_RX_FULL_BIT, QS_RX_EMPTY_BIT, 1'b0, 1'b1, ctxt);
    check_queue_flags("RESP", QS_RESP_FULL_BIT, QS_RESP_EMPTY_BIT, 1'b0, 1'b1, ctxt);
  endtask

  virtual task request_sw_reset(bit keep_enabled = 1'b0);
    bit [31:0] data;

    poll_idle();
    reg_write(ADDR_HC_CONTROL, {30'h0, 1'b1, keep_enabled});
    settle_cycles();

    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_SW_RESET_BIT], 1'b0,
                 $sformatf("%s: SW_RESET should self-clear", get_type_name()))
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], keep_enabled,
                 $sformatf("%s: SW_RESET should preserve requested enable state",
                           get_type_name()))
  endtask

endclass
