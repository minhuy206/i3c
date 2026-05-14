# Component: Build Infrastructure

> Status: New
> Location: `src/verification/` (root), `src/verification/uvm_i3c/`
> Estimated LoC: ~130 lines (4 files)

## 1. Purpose

Makefile, filelist, and Xcelium arguments for compiling and running UVM simulations. Provides standardized targets for the entire team.

## 2. Dependencies

- Xcelium simulator (xrun)
- UVM 1.2 library (bundled with Xcelium as `CDNS-1.2`)

---

## 3. File: Makefile

### 3.1. Location

`src/verification/Makefile`

### 3.2. Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SIMULATOR` | `xrun` | Simulator command |
| `UVM_HOME` | `CDNS-1.2` | UVM library identifier |
| `TEST` | `i3c_base_test` | UVM test name |
| `SEQ` | `i3c_smoke_vseq` | Virtual sequence name |
| `VERBOSITY` | `UVM_MEDIUM` | UVM verbosity level |
| `SEED` | `random` | Simulation seed |
| `DUMP_WAVES` | `0` | 1 = dump waveforms |

### 3.3. Targets

#### `compile`
Compile RTL + UVM testbench:
```makefile
compile:
	$(SIMULATOR) -compile -elaborate \
	  -uvmhome $(UVM_HOME) \
	  -f uvm_i3c/filelist.f \
	  -timescale 1ns/1ps \
	  -access +rwc \
	  -define UVM \
	  -64 \
	  -xceligen on
```

#### `sim`
Run simulation:
```makefile
sim: compile
	$(SIMULATOR) -R \
	  +UVM_TESTNAME=$(TEST) \
	  +UVM_TEST_SEQ=$(SEQ) \
	  +UVM_VERBOSITY=$(VERBOSITY) \
	  -svseed $(SEED) \
	  -xceligen on $(if $(filter 1,$(DUMP_WAVES)),+DUMP_WAVES,)
```

#### `smoke`
Quick smoke test:
```makefile
smoke:
	$(MAKE) sim TEST=i3c_base_test SEQ=i3c_smoke_vseq
```

#### `regression`
Run all Phase 1 tests:
```makefile
regression:
	$(MAKE) sim SEQ=i3c_smoke_vseq
	$(MAKE) sim SEQ=i3c_write_vseq
	$(MAKE) sim SEQ=i3c_read_vseq
```

#### `waves`
Run with waveform dump:
```makefile
waves:
	$(MAKE) sim DUMP_WAVES=1
```

#### `clean`
Remove build artifacts:
```makefile
clean:
	rm -rf xcelium.d INCA_libs waves.shm xrun.history .simvision \
	       xmsc_run.log *.log *.key *.shm .cxl.*
```

---

## 4. File: filelist.f

### 4.1. Location

`src/verification/uvm_i3c/filelist.f`

### 4.2. Contents

Compilation order: packages → interfaces → agents → env → tests → TB top.

```
// Paths relative to src/verification/ (run make from that directory)

// Include paths
-incdir ../rtl
-incdir uvm_i3c/dv_inc
-incdir uvm_i3c/dv_reg
-incdir uvm_i3c/dv_i3c
-incdir uvm_i3c/dv_i3c/seq_lib
-incdir uvm_i3c/i3c_core
-incdir uvm_i3c/i3c_core/i3c_vseqs

// RTL packages (must come first)
../rtl/i3c_pkg.sv
../rtl/ctrl/controller_pkg.sv

// RTL sources
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

// Verification: CSR address package
uvm_i3c/dv_inc/i3c_csr_addr_pkg.sv

// Verification: register interface (no external type deps)
uvm_i3c/dv_reg/reg_if.sv

// Verification: register agent package
uvm_i3c/dv_reg/reg_agent_pkg.sv

// Verification: I3C timing package
uvm_i3c/dv_i3c/i3c_timing_pkg.sv

// Verification: I3C interface (imports timing types from i3c_timing_pkg)
uvm_i3c/dv_i3c/i3c_if.sv

// Verification: I3C agent package
uvm_i3c/dv_i3c/i3c_agent_pkg.sv

// Environment package (includes vseqs)
uvm_i3c/i3c_core/i3c_env_pkg.sv

// Test package
uvm_i3c/i3c_core/i3c_test_pkg.sv

// Testbench top
uvm_i3c/i3c_core/tb_i3c_top.sv
```

### 4.3. Compilation Order Rationale

1. **RTL packages** — `i3c_pkg`, `controller_pkg` define shared types
2. **RTL sources** — all design modules
3. **CSR address package** — standalone, no dependencies
4. **`reg_if`** — no external type deps; compile early
5. **`reg_agent_pkg`** — depends on `reg_if` via `virtual reg_if` (resolved at elaboration)
6. **`i3c_timing_pkg`** — defines shared timing types used by the interface and agent package
7. **`i3c_if`** — imports timing types from `i3c_timing_pkg`; compiles before `i3c_agent_pkg` to avoid package/interface cycles
8. **`i3c_agent_pkg`** — aliases timing types and includes agent classes, including cfg with `virtual i3c_if`
9. **Env package** — includes env, scoreboard, and virtual sequences
10. **Test package** — includes base test
11. **TB top** — last, instantiates everything

---

## 5. File: xrun.args (Optional)

### 5.1. Location

`src/verification/uvm_i3c/xrun.args`

### 5.2. Purpose

Xcelium-specific compilation arguments that can be reused.

### 5.3. Contents

```
-uvm
-uvmhome CDNS-1.2
-timescale 1ns/1ps
-access +rwc
-define UVM
-64
-xceligen on
-nowarn DSEM2009
-nowarn CUVIHR
```

Usage from `src/verification/`: `xrun -f uvm_i3c/xrun.args -f uvm_i3c/filelist.f`

---

## 6. File: src/verification/README.md

### 6.1. Location

`src/verification/README.md`

### 6.2. Contents

Document:
- Directory structure overview
- Prerequisites (Xcelium version, UVM)
- Quick start commands (compile, smoke test, regression)
- How to add new virtual sequences
- How to add new agent-level sequences
- Waveform viewing instructions

---

## 7. Implementation Notes

- The filelist uses relative paths from `src/verification/` directory — run `make` from `src/verification/`
- Xcelium's `-access +rwc` enables waveform probing of all signals
- The `-define UVM` flag ensures `dv_macros.svh` uses UVM-compatible logging
- `i3c_timing_pkg` breaks the dependency cycle between `i3c_if` timing task types and `i3c_agent_pkg`
- Seed control via `-svseed` allows reproducible randomization
- `+DUMP_WAVES` is a runtime plusarg and must be passed on `xrun -R`
- For CI, the `regression` target can be extended with pass/fail reporting
