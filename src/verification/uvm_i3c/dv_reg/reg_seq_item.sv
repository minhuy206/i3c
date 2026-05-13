class reg_seq_item extends uvm_sequence_item;
  rand bit [11:0] addr;
  rand bit [31:0] wdata;
  rand bit is_write;
  bit [31:0] rdata;

  `uvm_object_utils_begin(reg_seq_item)
    `uvm_field_int(addr, UVM_DEFAULT)
    `uvm_field_int(wdata, UVM_DEFAULT)
    `uvm_field_int(is_write, UVM_DEFAULT)
    `uvm_field_int(rdata, UVM_DEFAULT | UVM_NOCOMPARE)
  `uvm_object_utils_end

  function new(string name = "");
    super.new(name);
  endfunction

  constraint addr_aligned_c {addr[1:0] == 2'b00;}

  // constraint addr_range_c {addr inside {[12'h000 : 12'hFFF]};}

  virtual function string convert2string();
    return $sformatf(
        "%s addr=0x%03h %s=0x%08h",
        is_write ? "WR" : "RD",
        addr,
        is_write ? "wdata" : "rdata",
        is_write ? wdata : rdata
    );
  endfunction

endclass
