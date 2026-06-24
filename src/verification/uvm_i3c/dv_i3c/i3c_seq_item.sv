class i3c_seq_item extends uvm_sequence_item;

  rand bit        i3c;
  rand bit [ 6:0] addr;
  rand bit [ 6:0] static_addr;
  rand bit        dir;
  rand bit        dev_ack;
  // Common for both I2C and I3C
  rand bit [ 7:0] data                        [$];
  rand bit [15:0] data_cnt;
  // Contains I2C ACK/NACK if i3c is false,
  // or I3C T bits if i3c = true
  rand bit        T_bit                       [$];
  rand bit        end_with_rstart;
  rand bit        start_with_broadcast_header;
  bit             observed_broadcast_header;
  bit             observed_broadcast_rstart;
  rand bit        is_daa;
  rand bit        entdaa_join;
  rand bit [ 7:0] daa_id_bytes                [$];
  rand bit        daa_accept_addr;
  rand bit [ 6:0] ccc_target_addr;
  rand bit        ccc_target_addr_valid;
  bit      [ 6:0] sampled_addr_q              [$];
  bit             sampled_dir_q               [$];

  bit             static_addr_constraint_en;
  bit             dynamic_addr_constraint_en;
  bit             payload_constraint_en;
  bit      [ 6:0] avoid_static_addr  = 7'h7e;
  bit      [ 6:0] avoid_dynamic_addr = 7'h7e;
  int unsigned    payload_len;

  constraint static_addr_c {
    if (static_addr_constraint_en) {
      static_addr inside {[7'h08 : 7'h77]};
      static_addr != avoid_static_addr;
    }
  }

  constraint dynamic_addr_c {
    if (dynamic_addr_constraint_en) {
      addr inside {[7'h04 : 7'h7d]};
      addr != avoid_dynamic_addr;
    }
  }

  constraint payload_c {
    if (payload_constraint_en) {
      data_cnt == payload_len;
      data.size() == payload_len;
    }
  }

  function new(string name = "");
    super.new(name);
  endfunction : new

  `uvm_object_utils_begin(i3c_seq_item)
    `uvm_field_int(i3c, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(addr, UVM_DEFAULT)
    `uvm_field_int(static_addr, UVM_DEFAULT)
    `uvm_field_int(dir, UVM_DEFAULT)
    `uvm_field_int(dev_ack, UVM_DEFAULT)
    `uvm_field_int(is_daa, UVM_DEFAULT)
    `uvm_field_queue_int(data, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(data_cnt, UVM_DEFAULT)
    `uvm_field_queue_int(T_bit, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(end_with_rstart, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(start_with_broadcast_header, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(observed_broadcast_header, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(observed_broadcast_rstart, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(entdaa_join, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_queue_int(daa_id_bytes, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(daa_accept_addr, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(ccc_target_addr, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(ccc_target_addr_valid, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_queue_int(sampled_addr_q, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_queue_int(sampled_dir_q, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(static_addr_constraint_en, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(dynamic_addr_constraint_en, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(payload_constraint_en, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(avoid_static_addr, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(avoid_dynamic_addr, UVM_DEFAULT | UVM_NOCOMPARE)
    `uvm_field_int(payload_len, UVM_DEFAULT | UVM_NOCOMPARE)
  `uvm_object_utils_end

endclass : i3c_seq_item
