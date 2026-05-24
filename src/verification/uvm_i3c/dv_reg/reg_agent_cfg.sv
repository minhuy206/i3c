class reg_agent_cfg extends uvm_object;
  bit is_active  = 1'b1;
  bit has_driver = 1'b1;

  `uvm_object_utils_begin(reg_agent_cfg)
    `uvm_field_int(is_active, UVM_DEFAULT)
    `uvm_field_int(has_driver, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "");
    super.new(name);
  endfunction
endclass
