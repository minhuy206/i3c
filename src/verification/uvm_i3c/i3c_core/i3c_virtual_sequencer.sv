class i3c_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(i3c_virtual_sequencer)

  i3c_env_cfg   cfg;
  reg_sequencer m_reg_sequencer;
  i3c_sequencer m_i3c_sequencer;

  function new(string name = "", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

endclass
