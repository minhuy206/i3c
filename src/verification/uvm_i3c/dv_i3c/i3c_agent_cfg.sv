class i3c_agent_cfg extends uvm_object;
  `uvm_object_utils_begin(i3c_agent_cfg)
    `uvm_field_int(is_active,           UVM_DEFAULT)
    `uvm_field_enum(if_mode_e, if_mode, UVM_DEFAULT)
    `uvm_field_int(has_driver,          UVM_DEFAULT)
    `uvm_field_int(ok_to_end_delay_ns,  UVM_DEFAULT)
    `uvm_field_int(in_reset,            UVM_DEFAULT)
    `uvm_field_int(en_monitor,          UVM_DEFAULT)
    `uvm_field_int(driver_rst,          UVM_DEFAULT)
    `uvm_field_int(monitor_rst,         UVM_DEFAULT)
  `uvm_object_utils_end

  // Agent mode and capability
  bit        is_active          = 1'b1;
  if_mode_e  if_mode            = Device;
  bit        has_driver         = 1'b1;
  bit        en_monitor         = 1'b1;

  // Reset tracking
  bit        in_reset           = 1'b0;
  bit        driver_rst         = 1'b0;
  bit        monitor_rst        = 1'b0;

  // Phase completion delay
  int        ok_to_end_delay_ns = 1000;

  // Virtual interface handle (populated by agent build_phase)
  virtual i3c_if vif;

  // Bus timing — defaults from i2c_timing_t / i3c_timing_t struct members in i3c_agent_pkg
  bus_timing_t tc;

  // Single target device configuration (Phase 1)
  I3C_device i3c_target0;

  function new(string name = "i3c_agent_cfg");
    super.new(name);
    // Initialize target0 to known-good defaults
    i3c_target0.static_addr        = 7'h50;
    i3c_target0.static_addr_valid  = 1'b1;
    i3c_target0.dynamic_addr       = 7'h08;
    i3c_target0.dynamic_addr_valid = 1'b0;
    i3c_target0.bcr                = 8'h00;
    i3c_target0.dcr                = 8'h00;
    i3c_target0.pid                = 48'h0;
    i3c_target0.max_read_length   = 16'h0;
    i3c_target0.max_write_length  = 16'h0;
    i3c_target0.device_read_limit  = 16'h0;
    i3c_target0.device_write_limit = 16'h0;
    i3c_target0.status             = 16'h0;
  endfunction : new

endclass : i3c_agent_cfg
