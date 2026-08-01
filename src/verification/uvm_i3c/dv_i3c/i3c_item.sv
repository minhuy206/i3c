typedef enum {
  I3cBusEventStart,
  I3cBusEventRStart,
  I3cBusEventAddress,
  I3cBusEventAck,
  I3cBusEventNack,
  I3cBusEventCcc,
  I3cBusEventData,
  I3cBusEventTBit,
  I3cBusEventStop
} i3c_bus_event_kind_e;

typedef enum {
  I3cBusRoleGeneric,
  I3cBusRoleDaaPid,
  I3cBusRoleDaaBcr,
  I3cBusRoleDaaDcr,
  I3cBusRoleDaaAssign
} i3c_bus_event_role_e;

class i3c_bus_event extends uvm_object;
  i3c_bus_event_kind_e kind;
  i3c_bus_event_role_e role;
  bit [7:0]            value;
  int unsigned         index;
  bus_op_e             bus_op;

  `uvm_object_utils_begin(i3c_bus_event)
    `uvm_field_enum(i3c_bus_event_kind_e, kind, UVM_DEFAULT)
    `uvm_field_enum(i3c_bus_event_role_e, role, UVM_DEFAULT)
    `uvm_field_int(value, UVM_DEFAULT)
    `uvm_field_int(index, UVM_DEFAULT)
    `uvm_field_enum(bus_op_e, bus_op, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "");
    super.new(name);
    role = I3cBusRoleGeneric;
  endfunction : new
endclass : i3c_bus_event

class i3c_item extends uvm_sequence_item;

  // transaction data part
  bit [6:0] addr;
  bit addr_nack;
  bit start_with_broadcast_header;
  bit broadcast_header_nack;
  bit i3c_direct;
  i3c_ccc_e CCC;
  bit CCC_valid;
  bit ccc_t_bit_valid;
  bit ccc_t_bit;
  i3c_item CCC_direct_q[$];
  int tran_id;
  int num_data;  // valid data
  bus_op_e bus_op;
  bit [7:0] data_q[$];
  bit data_nack_q[$];  // I2C NAck (1=NACK), I3C T-bit
  bit interrupted;  // I3C read stopped by controller
  // transaction control part
  bit i3c;
  bit start_from_rstart;
  bit rstart;
  bit stop;
  i3c_bus_event bus_event_q[$];

  // Use for debug print
  string pname = "";

  `uvm_object_utils_begin(i3c_item)
    `uvm_field_int(tran_id, UVM_DEFAULT)
    `uvm_field_enum(bus_op_e, bus_op, UVM_DEFAULT)
    `uvm_field_int(addr, UVM_DEFAULT)
    `uvm_field_int(start_with_broadcast_header, UVM_DEFAULT)
    `uvm_field_int(broadcast_header_nack, UVM_DEFAULT)
    `uvm_field_int(i3c_direct, UVM_DEFAULT)
    `uvm_field_enum(i3c_ccc_e, CCC, UVM_DEFAULT)
    `uvm_field_int(ccc_t_bit_valid, UVM_DEFAULT)
    `uvm_field_int(ccc_t_bit, UVM_DEFAULT)
    `uvm_field_queue_object(CCC_direct_q, UVM_DEFAULT)
    `uvm_field_int(num_data, UVM_DEFAULT)
    `uvm_field_int(start_from_rstart, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(rstart, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(stop, UVM_DEFAULT)
    `uvm_field_int(interrupted, UVM_DEFAULT)
    `uvm_field_queue_int(data_q, UVM_DEFAULT)
    `uvm_field_int(i3c, UVM_DEFAULT | UVM_NOPRINT | UVM_NOCOMPARE)
    `uvm_field_int(addr_nack, UVM_DEFAULT | UVM_NOCOMPARE | UVM_NOPRINT)
    `uvm_field_queue_int(data_nack_q, UVM_DEFAULT | UVM_NOCOMPARE | UVM_NOPRINT)
    `uvm_field_queue_object(bus_event_q, UVM_DEFAULT | UVM_NOCOMPARE | UVM_NOPRINT)
  `uvm_object_utils_end

  function new(string name = "");
    super.new(name);
  endfunction : new

  function void clear_data();
    num_data = 0;
    addr     = 0;
    data_q.delete();
    addr_nack = 0;
    start_with_broadcast_header = 0;
    broadcast_header_nack = 0;
    data_nack_q.delete();
    CCC_direct_q.delete();
    CCC_valid = 0;
    ccc_t_bit_valid = 0;
    ccc_t_bit = 0;
    i3c_direct = 0;
    bus_event_q.delete();
  endfunction : clear_data

  function void clear_flag();
    start_from_rstart = 1'b0;
    stop              = 1'b0;
    rstart            = 1'b0;
  endfunction : clear_flag

  function void clear_all();
    clear_data();
    clear_flag();
  endfunction : clear_all

  function string ack_to_string(bit ack);
    return ack ? "ACK" : "NACK";
  endfunction

  virtual function string convert2string();
    string str = "";
    str = {str, $sformatf("%s:tran_id   = %0d\n", pname, tran_id)};
    str = {str, $sformatf("%s:bus_op    = %s\n", pname, bus_op.name)};
    str = {str, $sformatf("%s:addr      = 0x%2x\n", pname, addr)};
    str = {str, $sformatf("%s:bcast_hdr = %1b\n", pname, start_with_broadcast_header)};
    str = {str, $sformatf("%s:bcast_ack = %s\n", pname, ack_to_string(!broadcast_header_nack))};
    str = {str, $sformatf("%s:direct    = 0x%2x\n", pname, i3c_direct)};
    if (CCC_valid) begin
      str = {str, $sformatf("%s:CCC       = %s\n", pname, CCC.name())};
      str = {
        str,
        $sformatf(
            "%s:CCC T-bit = %s\n", pname, ccc_t_bit_valid ? $sformatf("%0b", ccc_t_bit) : "--"
        )
      };
    end
    str = {str, $sformatf("%s:num_data  = %0d\n", pname, num_data)};
    str = {str, $sformatf("%s:start_sr  = %1b\n", pname, start_from_rstart)};
    str = {str, $sformatf("%s:stop      = %1b\n", pname, stop)};
    str = {str, $sformatf("%s:rstart    = %1b\n", pname, rstart)};
    foreach (data_q[i]) begin
      str = {str, $sformatf("%s:data_q[%0d]=0x%2x\n", pname, i, data_q[i])};
    end
    return str;
  endfunction
endclass : i3c_item
