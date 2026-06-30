class i3c_coverage extends uvm_subscriber #(i3c_item);
  `uvm_component_utils(i3c_coverage)

  function new(string name = "i3c_coverage", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void write(i3c_item t);
  endfunction
endclass
