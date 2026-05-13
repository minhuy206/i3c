class i3c_env extends uvm_env;
  `uvm_component_utils(i3c_env)

  i3c_env_cfg cfg;
  i3c_agent m_i3c_agent;
  reg_agent m_reg_agent;
  i3c_virtual_sequencer m_vsequencer;
  i3c_scoreboard m_scoreboard;

  function new(string name = "", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(i3c_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(`gfn, "Failed to get i3c_env_cfg")

    if (cfg.is_active) begin
      m_vsequencer = i3c_virtual_sequencer::type_id::create("m_vsequencer", this);
      m_vsequencer.cfg = cfg;
    end

    m_reg_agent = reg_agent::type_id::create("m_reg_agent", this);
    uvm_config_db#(reg_agent_cfg)::set(this, "m_reg_agent", "cfg", cfg.m_reg_agent_cfg);

    m_i3c_agent = i3c_agent::type_id::create("m_i3c_agent", this);
    uvm_config_db#(i3c_agent_cfg)::set(this, "m_i3c_agent", "cfg", cfg.m_i3c_agent_cfg);
    cfg.m_i3c_agent_cfg.en_monitor = 1'b1;

    if (cfg.en_scb) begin
      m_scoreboard = i3c_scoreboard::type_id::create("m_scoreboard", this);
      m_scoreboard.cfg = cfg;
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    m_vsequencer.m_reg_sequencer = m_reg_agent.sequencer;
    m_vsequencer.m_i3c_sequencer = m_i3c_agent.sequencer;

    if (cfg.en_scb) begin
      m_reg_agent.monitor.analysis_port.connect(m_scoreboard.reg_fifo.analysis_export);
      m_i3c_agent.monitor.analysis_port.connect(m_scoreboard.i3c_fifo.analysis_export);
    end
  endfunction
endclass
