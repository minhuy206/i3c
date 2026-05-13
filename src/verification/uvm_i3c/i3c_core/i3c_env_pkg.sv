package i3c_env_pkg;
  import uvm_pkg::*;
  import reg_agent_pkg::*;
  import i3c_agent_pkg::*;
  import i3c_csr_addr_pkg::*;
  import i3c_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  `include "i3c_env_cfg.sv"
  `include "i3c_virtual_sequencer.sv"
  `include "i3c_scoreboard.sv"
  `include "i3c_env.sv"

  // Virtual sequences
  `include "i3c_vseqs/i3c_vseq_list.sv"
endpackage
