class i3c_env_cfg extends uvm_object;
  bit is_active = 1;
  bit en_scb = 1;
  bit under_reset = 0;
  bit is_initialized = 0;
  reg_agent_cfg m_reg_agent_cfg;
  i3c_agent_cfg m_i3c_agent_cfg;

  `uvm_object_utils_begin(i3c_env_cfg)
    `uvm_field_int(is_active, UVM_DEFAULT)
    `uvm_field_int(en_scb, UVM_DEFAULT)
    `uvm_field_object(m_reg_agent_cfg, UVM_DEFAULT)
    `uvm_field_object(m_i3c_agent_cfg, UVM_DEFAULT)
  `uvm_object_utils_end

  virtual function initialize();
    is_initialized = 1'b1;

    m_reg_agent_cfg = reg_agent_cfg::type_id::create("m_reg_agent_cfg");
    m_reg_agent_cfg.is_active = 1'b1;
    m_reg_agent_cfg.has_driver = 1'b1;

    m_i3c_agent_cfg = i3c_agent_cfg::type_id::create("m_i3c_agent_cfg");
    m_i3c_agent_cfg.is_active = 1'b1;
    m_i3c_agent_cfg.if_mode = Device;
    m_i3c_agent_cfg.has_driver = 1'b1;
    m_i3c_agent_cfg.en_monitor = 1'b1;

    m_i3c_agent_cfg.i3c_target0.dynamic_addr = 7'h08;
    m_i3c_agent_cfg.i3c_target0.dynamic_addr_valid = 1;
    m_i3c_agent_cfg.i3c_target0.static_addr = 7'h50;
    m_i3c_agent_cfg.i3c_target0.static_addr_valid = 1;
    m_i3c_agent_cfg.i3c_target0.bcr = 8'h00;
    m_i3c_agent_cfg.i3c_target0.dcr = 8'h00;
    m_i3c_agent_cfg.i3c_target0.pid = 48'h0000_0000_0001;
  endfunction
endclass
