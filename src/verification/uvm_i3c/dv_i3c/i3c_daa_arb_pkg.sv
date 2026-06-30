package i3c_daa_arb_pkg;
  parameter int unsigned I3C_DAA_ARB_MAX_TARGETS = 4;

  typedef struct packed {
    bit        valid;
    bit [47:0] pid;
    bit [ 7:0] bcr;
    bit [ 7:0] dcr;
    bit        accept_addr;
  } i3c_daa_arb_target_t;
endpackage : i3c_daa_arb_pkg
