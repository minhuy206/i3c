// Paths are relative to the directory from which xrun is invoked (src/verification/)

// ─── Include directories ─────────────────────────────────────────────────────
-incdir ../rtl
-incdir uvm_i3c/dv_inc
-incdir uvm_i3c/dv_reg
-incdir uvm_i3c/dv_i3c
-incdir uvm_i3c/dv_i3c/seq_lib
-incdir uvm_i3c/i3c_core
-incdir uvm_i3c/i3c_core/i3c_vseqs

// ─── RTL packages (must come before RTL sources) ─────────────────────────────
../rtl/i3c_pkg.sv
../rtl/ctrl/controller_pkg.sv

// ─── RTL sources ─────────────────────────────────────────────────────────────
../rtl/phy/i3c_phy.sv
../rtl/ctrl/edge_detector.sv
../rtl/ctrl/stable_high_detector.sv
../rtl/ctrl/bus_monitor.sv
../rtl/scl_generator.sv
../rtl/ctrl/bus_tx.sv
../rtl/ctrl/bus_tx_flow.sv
../rtl/ctrl/bus_rx_flow.sv
../rtl/ctrl/entdaa_fsm.sv
../rtl/ctrl/entdaa_controller.sv
../rtl/ctrl/flow_active.sv
../rtl/ctrl/controller_active.sv
../rtl/hci/sync_fifo.sv
../rtl/hci/hci_queues.sv
../rtl/csr/csr_register.sv
../rtl/i3c_controller_top.sv

// ─── Verification: CSR address package ───────────────────────────────────────
uvm_i3c/dv_inc/i3c_csr_addr_pkg.sv

// ─── Verification: register interface (no external type deps) ────────────────
uvm_i3c/dv_reg/reg_if.sv

// ─── Verification: register agent package ────────────────────────────────────
uvm_i3c/dv_reg/reg_agent_pkg.sv

// ─── Verification: I3C timing package ────────────────────────────────────────
// Defines timing types used by both i3c_if.sv and i3c_agent_pkg.sv.
uvm_i3c/dv_i3c/i3c_timing_pkg.sv

// ─── Verification: I3C interface ─────────────────────────────────────────────
// Imports i3c_timing_t / i2c_timing_t from i3c_timing_pkg.
uvm_i3c/dv_i3c/i3c_if.sv

// ─── Verification: I3C agent package ─────────────────────────────────────────
// Aliases timing types from i3c_timing_pkg and includes agent classes.
uvm_i3c/dv_i3c/i3c_agent_pkg.sv

// ─── Verification: environment package (includes vseqs) ──────────────────────
uvm_i3c/i3c_core/i3c_env_pkg.sv

// ─── Verification: test package ──────────────────────────────────────────────
uvm_i3c/i3c_core/i3c_test_pkg.sv

// ─── Testbench top ───────────────────────────────────────────────────────────
uvm_i3c/i3c_core/tb_i3c_top.sv
