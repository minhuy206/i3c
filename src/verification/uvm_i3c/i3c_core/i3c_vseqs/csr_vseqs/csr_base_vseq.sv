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

  virtual task check_no_host_start_until_event(event done_e, string ctxt);
    fork : no_host_start_until_event
      begin
        p_sequencer.cfg.m_i3c_agent_cfg.vif.wait_for_host_start(
            p_sequencer.cfg.m_i3c_agent_cfg.tc.i3c_tc);
        `uvm_error(`gfn, $sformatf("%s: bus START observed during disabled window", ctxt))
      end
      begin
        @done_e;
      end
    join_any
    disable fork;
  endtask

endclass
