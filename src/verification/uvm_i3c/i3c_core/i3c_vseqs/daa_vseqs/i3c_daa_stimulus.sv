class i3c_daa_stimulus extends uvm_object;
  rand bit [6:0]  assigned_addr;
  rand bit [47:0] pid;
  rand bit [7:0]  bcr;
  rand bit [7:0]  dcr;

  constraint assigned_addr_c {
    assigned_addr inside {
      [7'h08 : 7'h3d],
      [7'h3f : 7'h5d],
      [7'h5f : 7'h6d],
      [7'h6f : 7'h75]
    };
  }

  `uvm_object_utils_begin(i3c_daa_stimulus)
    `uvm_field_int(assigned_addr, UVM_DEFAULT)
    `uvm_field_int(pid, UVM_DEFAULT)
    `uvm_field_int(bcr, UVM_DEFAULT)
    `uvm_field_int(dcr, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "i3c_daa_stimulus");
    super.new(name);
  endfunction
endclass
