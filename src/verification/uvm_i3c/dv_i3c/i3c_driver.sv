class i3c_driver extends uvm_driver #(
    .REQ(i3c_seq_item),
    .RSP(i3c_seq_itemn)
);
  `uvm_component_utils(i3c_driver)

  function new(string name = "", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  bit under_reset;
  i3c_agent_cfg cfg;

  int scl_spinwait_timeout_ns = 1_000_000;  // 1ms
  bit scl_i3c_mode = 0;
  bit scl_i3c_OD = 0;
  bit host_scl_start;
  bit host_scl_stop;
  bit host_scl_force_high = 0;
  bit host_scl_force_low = 0;
  i3c_drv_phase_e bus_state;
  bit stop, rstart;


endclass
