
package reg_agent_pkg;
  import uvm_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  // Forward declarations
  typedef class reg_seq_item;
  typedef class reg_agent_cfg;

  // Source files (order matters)
  `include "reg_seq_item.sv"
  `include "reg_agent_cfg.sv"
  `include "reg_monitor.sv"
  `include "reg_driver.sv"
  `include "reg_sequencer.sv"
  `include "reg_agent.sv"
endpackage
