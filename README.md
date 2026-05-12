# I3C Master Controller

A simplified MIPI I3C Basic v1.1.1 Active Controller implemented in SystemVerilog, developed as a graduation thesis at Ho Chi Minh City University of Science (HCMUS).

**Author:** Vo Minh Huy (22207042)  
**Supervisor:** Nguyen Duy Manh Thi

---

## Overview

This project implements a minimal I3C Master Controller targeting SDR mode operation with I2C backward compatibility. The design is derived from the open-source [CHIPS Alliance i3c-core](https://github.com/chipsalliance/i3c-core) reference — studied, extracted, and significantly simplified to focus on core protocol features (~92% code reduction from the reference).

### Supported Features

- **SDR mode** — 12.5 MHz SCL
- **I2C backward compatibility** — 400 kHz Fast Mode (FM)
- **Dynamic Address Assignment** — ENTDAA
- **Private Read/Write** — basic data transfer
- **CCC support** — ENTDAA, ENEC, DISEC only

### Out of Scope

- In-Band Interrupts (IBI), Hot-Join
- HDR modes (DDR, TSL, TSP)
- Multi-master / secondary controller
- Target (slave) mode
- Full HCI compliance

---

## Architecture

Three-layer design in a single clock domain (minimum **333 MHz** system clock):

```
i3c_controller_top
├── i3c_phy                    # 2FF metastability sync + OD/PP output drivers
├── csr_register               # Hand-written 32-bit register file + 16-entry DAT
├── hci_queues                 # CMD/TX/RX/RESP sync FIFOs
└── controller_active          # Protocol engine wrapper
    ├── flow_active             # 13-state command FSM (most critical module)
    ├── entdaa_controller       # ENTDAA loop manager
    │   └── entdaa_fsm          # 8-state per-device DAA arbitration FSM
    ├── bus_tx_flow             # TX byte serializer (4-state)
    ├── bus_tx                  # TX bit-level engine
    ├── bus_rx_flow             # RX deserializer (4-state)
    ├── bus_monitor             # START/STOP/Sr edge detection
    └── scl_generator           # SCL clock timing FSM
```

**Transaction data flow:**
1. Host writes 64-bit command descriptor → CMD FIFO
2. `flow_active` dequeues CMD, drives FSM transitions
3. `bus_tx_flow` / `bus_rx_flow` serialize/deserialize bytes via `bus_tx` + `scl_generator`
4. Completion → RESP FIFO; received data → RX FIFO
5. Host polls/reads RESP and RX FIFOs via `csr_register`

---

## Key Design Decisions

| Area | Reference (CHIPS Alliance) | This Project |
|---|---|---|
| Register interface | AXI4 + AHB-Lite adapters (~700 lines) | Simple 32-bit addr/data/wen/ren (~50 lines) |
| CSR | 14K auto-generated via PeakRDL | Hand-written ~300 lines |
| Top-level | 50+ params, `ifdef` conditional compilation | ~10 params, no `ifdef` |
| CCC support | 40+ CCCs, 1,406 lines | 3 CCCs, ~800 lines |
| DAT entry | 64-bit Caliptra-specific struct | Simplified 32-bit struct |
| `flow_active` FSM | 8 of 13 states left as TODO | All 13 states implemented |

---

## Repository Structure

```
i3c/
├── src/
│   ├── rtl/                            # RTL design (~4,100 lines)
│   │   ├── i3c_pkg.sv                  # Shared types: bus_state_t, cmd/resp descriptors
│   │   ├── i3c_controller_top.sv       # Top-level integration
│   │   ├── scl_generator.sv            # SCL clock gen (12.5 MHz SDR / 400 kHz I2C FM)
│   │   ├── phy/
│   │   │   └── i3c_phy.sv              # 2FF sync + Open-Drain/Push-Pull output drivers
│   │   ├── ctrl/
│   │   │   ├── controller_pkg.sv       # Controller types: dat_entry_t, cmd_transfer_dir_e
│   │   │   ├── controller_active.sv    # Structural wrapper + OD/PP switching
│   │   │   ├── flow_active.sv          # 13-state command FSM (most critical)
│   │   │   ├── entdaa_controller.sv    # ENTDAA loop manager
│   │   │   ├── entdaa_fsm.sv           # 8-state per-device DAA arbitration FSM
│   │   │   ├── bus_tx_flow.sv          # 4-state TX serializer
│   │   │   ├── bus_rx_flow.sv          # 4-state RX deserializer
│   │   │   ├── bus_tx.sv               # TX bit-level engine
│   │   │   ├── bus_monitor.sv          # START/STOP/Sr edge detection
│   │   │   ├── edge_detector.sv
│   │   │   └── stable_high_detector.sv
│   │   ├── csr/
│   │   │   └── csr_register.sv         # Register file + 16-entry DAT
│   │   └── hci/
│   │       ├── hci_queues.sv           # CMD (64-bit) / TX / RX / RESP (32-bit) FIFOs
│   │       └── sync_fifo.sv            # Generic parameterized FIFO primitive
│   └── verification/
│       └── uvm_i3c/                    # UVM testbench — Phase 1 (~2,500 lines)
│           ├── dv_inc/
│           │   ├── dv_macros.svh       # Shared UVM convenience macros
│           │   └── i3c_csr_addr_pkg.sv # CSR address constants
│           ├── dv_reg/                 # Register bus agent
│           │   ├── reg_agent_pkg.sv
│           │   ├── reg_agent.sv
│           │   ├── reg_agent_cfg.sv
│           │   ├── reg_driver.sv
│           │   ├── reg_monitor.sv
│           │   ├── reg_sequencer.sv
│           │   ├── reg_if.sv
│           │   └── req_seq_item.sv
│           └── dv_i3c/                 # I3C bus agent
│               ├── i3c_agent_pkg.sv
│               ├── i3c_agent.sv
│               ├── i3c_agent_cfg.sv
│               ├── i3c_driver.sv
│               ├── i3c_monitor.sv
│               ├── i3c_sequencer.sv
│               ├── i3c_if.sv
│               ├── i3c_item.sv
│               ├── i3c_seq_item.sv
│               └── seq_lib/
│                   ├── i3c_seq_list.sv
│                   └── i3c_device_response_seq.sv
└── docs/
    ├── phase1_spec_v2.md               # FSM state definitions, register maps, timing
    ├── improvements.md                 # Simplification analysis vs reference design
    ├── bug_analysis_report.md          # Known bugs — read before modifying ctrl/
    ├── implementation_plan.md
    ├── module_specs/                   # Per-module specs (ports, FSMs, timing)
    │   ├── 01_i3c_phy_spec.md
    │   ├── 02_bus_monitor_spec.md
    │   ├── 03_scl_generator_spec.md
    │   ├── 04_bus_tx_spec.md
    │   ├── 05_bus_rx_flow_spec.md
    │   ├── 06_hci_queues_spec.md
    │   ├── 07_csr_registers_spec.md
    │   ├── 08_ccc_processor_spec.md
    │   ├── 09_flow_active_spec.md      # Most critical module spec
    │   ├── 10_controller_active_spec.md
    │   └── 11_i3c_controller_top_spec.md
    └── verification_specs/             # 10 UVM spec files for planned testbench
```

---

## Signal Conventions

- Inputs: `signal_i`, Outputs: `signal_o`
- Active-low asynchronous reset: `rst_ni`
- Clock: `clk_i`
- FIFO handshake: `*_valid_i` / `*_ready_o`
- I3C bus inputs: `scl_i`, `sda_i` (synchronized); outputs: `scl_o`, `sda_o` (active-low open-drain)
- `sel_od_pp_o`: `1` = push-pull data phase, `0` = open-drain address/ACK phase

## Register Interface

Simple 32-bit bus (no AXI/AHB):

- Write: `reg_addr_i[11:0]` + `reg_wdata_i[31:0]` + `reg_wen_i`
- Read: `reg_addr_i[11:0]` + `reg_ren_i` → `reg_rdata_o[31:0]` + `reg_ready_o`

---

## Verification Status

| Component | Status |
|---|---|
| `dv_reg` — register bus agent | Implemented |
| `dv_i3c` — I3C bus agent (driver, monitor, sequences) | Implemented |
| Environment, scoreboard, coverage | Planned |
| Test suite, virtual sequences | Planned |
| Build infrastructure (Makefile, `filelist.f`) | Planned |

Simulator target: **Xcelium (`xrun`)** with UVM 1.2 (CDNS-1.2 bundled).

---

## Reference

- **Specification:** MIPI I3C Basic v1.1.1 with Errata 01 (2022) — `docs/mipi_i3c_spec.pdf`
- **Reference design:** [chipsalliance/i3c-core](https://github.com/chipsalliance/i3c-core)
- **Protocol FSM & register map:** `docs/phase1_spec_v2.md`
- **Design decisions:** `docs/improvements.md`
