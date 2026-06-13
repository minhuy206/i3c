class csr_base_vseq extends i3c_base_vseq;
  `uvm_object_utils(csr_base_vseq)

  typedef struct {
    string cmd_staging_valid_path;
    string cmd_dword0_path;
  } csr_hdl_paths_t;

  csr_hdl_paths_t csr_paths;

  function new(string name = "csr_base_vseq");
    super.new(name);
    init_csr_hdl_paths();
  endfunction

  virtual function void init_csr_hdl_paths();
    csr_paths.cmd_staging_valid_path = "tb_i3c_top.dut.u_csr.cmd_staging_valid";
    csr_paths.cmd_dword0_path        = "tb_i3c_top.dut.u_csr.cmd_dword0";
  endfunction

  virtual task check_reg_eq(bit [11:0] addr, bit [31:0] exp, string reg_name, string ctxt = "");
    bit [31:0] data;

    reg_read(addr, data);
    `DV_CHECK_EQ(data, exp, $sformatf("%s: %s value mismatch %s", get_type_name(), reg_name, ctxt))
  endtask

  virtual task check_timing_reg(bit [11:0] addr, bit [19:0] exp, string reg_name, string ctxt = "");
    bit [31:0] data;

    reg_read(addr, data);
    `DV_CHECK_EQ(data[19:0], exp, $sformatf("%s: %s value mismatch %s", get_type_name(), reg_name,
                                            ctxt))
    `DV_CHECK_EQ(data[31:20], 12'h0, $sformatf("%s: %s reserved bits should read 0 %s",
                                               get_type_name(), reg_name, ctxt))
  endtask

  virtual task check_queue_flags(string queue_name, int full_bit, int empty_bit, bit exp_full,
                                 bit exp_empty, string ctxt);
    bit [31:0] status;

    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(status[full_bit], exp_full, $sformatf("%s: %s full flag mismatch %s",
                                                       get_type_name(), queue_name, ctxt))
    `DV_CHECK_EQ(status[empty_bit], exp_empty, $sformatf("%s: %s empty flag mismatch %s",
                                                         get_type_name(), queue_name, ctxt))
  endtask

  virtual task check_no_host_start_for_cycles(int unsigned cycles, string ctxt);
    fork : no_host_start_window
      begin
        p_sequencer.cfg.m_i3c_agent_cfg.vif.wait_for_host_start();
        `uvm_error(`gfn, $sformatf("%s: bus START observed during disabled window", ctxt))
      end
      begin
        repeat (cycles) @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      end
    join_any
    disable fork;
  endtask

  virtual task clear_scoreboard_cmd_tx_model(string ctxt);
    uvm_component  comp;
    i3c_scoreboard scb;

    comp = uvm_top.find("uvm_test_top.env.m_scoreboard");
    if (!$cast(scb, comp)) begin
      `uvm_fatal(`gfn, $sformatf("%s: could not find i3c_scoreboard", ctxt))
    end

    scb.exp_txn_queue.delete();
    scb.tx_data_queue.delete();
  endtask

  virtual task request_sw_reset(bit keep_enabled = 1'b0);
    bit [31:0] data;
    bit        keep_broadcast_header_enable;

    poll_idle();
    reg_read(ADDR_HC_CONTROL, data);
    keep_broadcast_header_enable = data[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT];
    reg_write(ADDR_HC_CONTROL, {29'h0, keep_broadcast_header_enable, 1'b1, keep_enabled});
    settle_cycles();

    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], keep_enabled,
                 $sformatf("%s: SW_RESET should preserve requested enable state", get_type_name()))
    `DV_CHECK_EQ(data[HC_CTRL_SW_RESET_BIT], 1'b0, $sformatf("%s: SW_RESET should self-clear",
                                                             get_type_name()))
    `DV_CHECK_EQ(data[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT], keep_broadcast_header_enable,
                 $sformatf("%s: SW_RESET should preserve BROADCAST_HEADER_ENABLE config",
                           get_type_name()))
  endtask

endclass
