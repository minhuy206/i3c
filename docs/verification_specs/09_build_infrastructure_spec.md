# Component: Build Infrastructure

> Status: New
> Location: `verification/` (root), `verification/uvm_i3c/`
> Estimated LoC: ~100 lines (3 files)

## 1. Purpose

Makefile, filelist, and Xcelium arguments for compiling and running UVM simulations. Provides standardized targets for the entire team.

## 2. Dependencies

- Xcelium simulator (xrun)
- UVM 1.2 library (bundled with Xcelium as `CDNS-1.2`)

---

## 3. File: Makefile

### 3.1. Location

`verification/Makefile`

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
	  $(if $(filter 1,$(DUMP_WAVES)),+DUMP_WAVES,)
```

#### `sim`
Run simulation:
```makefile
sim: compile
	$(SIMULATOR) -R \
	  +UVM_TESTNAME=$(TEST) \
	  +UVM_TEST_SEQ=$(SEQ) \
	  +UVM_VERBOSITY=$(VERBOSITY) \
	  -svseed $(SEED)
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
	rm -rf xcelium.d INCA_libs *.shm *.log *.key
```

---

## 4. File: filelist.f

### 4.1. Location

`verification/uvm_i3c/filelist.f`

### 4.2. Contents

Compilation order: packages → interfaces → agents → env → tests → TB top.

```
// Include paths
-incdir ../src
-incdir uvm_i3c/dv_inc
-incdir uvm_i3c/dv_reg
-incdir uvm_i3c/dv_i3c
-incdir uvm_i3c/dv_i3c/seq_lib
-incdir uvm_i3c/i3c_core
-incdir uvm_i3c/i3c_core/i3c_vseqs

// RTL packages (must come first)
../src/i3c_pkg.sv
../src/ctrl/controller_pkg.sv

// RTL sources
../src/phy/i3c_phy.sv
../src/ctrl/edge_detector.sv
../src/ctrl/stable_high_detector.sv
../src/ctrl/bus_monitor.sv
../src/scl_generator.sv
../src/ctrl/bus_tx.sv
../src/ctrl/bus_tx_flow.sv
../src/ctrl/bus_rx_flow.sv
../src/ctrl/entdaa_fsm.sv
../src/ctrl/entdaa_controller.sv
../src/ctrl/flow_active.sv
../src/ctrl/controller_active.sv
../src/hci/sync_fifo.sv
../src/hci/hci_queues.sv
../src/csr/csr_register.sv
../src/i3c_controller_top.sv

// Verification packages and includes
uvm_i3c/dv_inc/i3c_csr_addr_pkg.sv

// Verification interfaces (compiled before packages that reference them)
uvm_i3c/dv_reg/reg_if.sv
uvm_i3c/dv_i3c/i3c_if.sv

// Agent packages
uvm_i3c/dv_reg/reg_agent_pkg.sv
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
4. **Interfaces** — `reg_if` and `i3c_if` must be compiled before agent packages that reference them via `virtual`
5. **Agent packages** — `reg_agent_pkg` and `i3c_agent_pkg` include their agent files
6. **Env package** — includes env, scoreboard, and virtual sequences
7. **Test package** — includes base test
8. **TB top** — last, instantiates everything

---

## 5. File: xrun.args (Optional)

### 5.1. Location

`verification/uvm_i3c/xrun.args`

### 5.2. Purpose

Xcelium-specific compilation arguments that can be reused.

### 5.3. Contents

```
-sv
-uvmhome CDNS-1.2
-timescale 1ns/1ps
-access +rwc
-define UVM
-nowarn DSEM2009
-nowarn CUVIHR
```

Usage: `xrun -f xrun.args -f filelist.f`

---

## 6. File: verification/README.md

### 6.1. Location

`verification/README.md`

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

- The filelist uses relative paths from `verification/` directory — run `make` from `verification/`
- Xcelium's `-access +rwc` enables waveform probing of all signals
- The `-define UVM` flag ensures `dv_macros.svh` uses UVM-compatible logging
- `-nowarn DSEM2009` suppresses common SystemVerilog warnings about `import` in interfaces
- Seed control via `-svseed` allows reproducible randomization
- For CI, the `regression` target can be extended with pass/fail reporting
