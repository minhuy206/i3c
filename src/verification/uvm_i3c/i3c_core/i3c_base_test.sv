class i3c_base_test extends uvm_test;
  `uvm_component_utils(i3c_base_test)
  i3c_env env;
  i3c_env_cfg cfg;
  virtual clk_rst_if clk_rst_vif;
  int unsigned num_seqs_run;

  function new(string name = "", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    env = i3c_env::type_id::create("env", this);
    cfg = i3c_env_cfg::type_id::create("cfg", this);

    cfg.initialize();
    `DV_CHECK_RANDOMIZE_FATAL(cfg)
    uvm_config_db#(i3c_env_cfg)::set(this, "env", "cfg", cfg);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

  protected function void parse_seq_list(string seq_list, ref string seq_names[$]);
    int unsigned token_start;

    seq_names.delete();
    token_start = 0;
    for (int unsigned i = 0; i <= seq_list.len(); i++) begin
      if ((i == seq_list.len()) || (seq_list.getc(i) == ",")) begin
        if (i > token_start) seq_names.push_back(seq_list.substr(token_start, i - 1));
        token_start = i + 1;
      end
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    uvm_object obj;
    uvm_factory factory;
    uvm_sequence test_seq;
    string test_seq_list = "i3c_imm_vseq";
    string test_seq_names[$];
    i3c_agent_pkg::I3C_device default_target0;
    i3c_agent_pkg::I3C_device default_target1;
    bit [6:0] default_i2c_target_addr0;
    bit [6:0] default_i2c_target_addr1;

    void'($value$plusargs("UVM_TEST_SEQ=%0s", test_seq_list));
    parse_seq_list(test_seq_list, test_seq_names);
    if (test_seq_names.size() == 0) begin
      `uvm_fatal(`gfn, "UVM_TEST_SEQ did not contain a sequence name")
    end
    if (!uvm_config_db#(virtual clk_rst_if)::get(this, "", "clk_rst_vif", clk_rst_vif)) begin
      `uvm_fatal(`gfn, "could not get clk_rst_vif")
    end
    default_target0 = cfg.m_i3c_agent_cfg.i3c_target0;
    default_target1 = cfg.m_i3c_agent_cfg.i3c_target1;
    default_i2c_target_addr0 = cfg.m_i3c_agent_cfg.i2c_target_addr0;
    default_i2c_target_addr1 = cfg.m_i3c_agent_cfg.i2c_target_addr1;

    factory = uvm_factory::get();
    phase.raise_objection(this);
    foreach (test_seq_names[i]) begin
      // Restore mutable agent configuration so each vseq sees the same UVM-side
      // target state as an independent simulation.
      cfg.m_i3c_agent_cfg.en_monitor = 1'b1;
      cfg.m_i3c_agent_cfg.i3c_target0 = default_target0;
      cfg.m_i3c_agent_cfg.i3c_target1 = default_target1;
      cfg.m_i3c_agent_cfg.i2c_target_addr0 = default_i2c_target_addr0;
      cfg.m_i3c_agent_cfg.i2c_target_addr1 = default_i2c_target_addr1;
      clk_rst_vif.apply_reset();
      obj = factory.create_object_by_name(test_seq_names[i], "", test_seq_names[i]);
      if (obj == null) begin
        factory.print(1);
        `uvm_fatal(`gfn, $sformatf("could not create %0s seq", test_seq_names[i]))
      end
      if (!$cast(test_seq, obj)) begin
        `uvm_fatal(`gfn, $sformatf(
                   "cast failed - %0s is not a uvm_sequence", test_seq_names[i]))
      end
      `uvm_info(`gfn, $sformatf(
                "starting vseq %0d/%0d: %0s",
                i + 1, test_seq_names.size(), test_seq_names[i]), UVM_LOW)
      test_seq.start(env.m_vsequencer);
      num_seqs_run++;
    end
    phase.drop_objection(this);
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV_SUMMARY",
              $sformatf("combined functional coverage over %0d vseq(s) = %0.2f%%",
                        num_seqs_run, $get_coverage()), UVM_NONE)
  endfunction
endclass
