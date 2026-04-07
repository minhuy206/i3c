# I3C Master Controller

A simplified MIPI I3C Basic v1.1.1 Active Controller implemented in SystemVerilog, developed as a graduation thesis at Ho Chi Minh City University of Science (HCMUS).

**Author:** Vo Minh Huy (22207042)
**Supervisor:** Nguyen Duy Manh Thi

---

## Overview

This project implements a minimal I3C Master Controller targeting SDR mode operation with I2C backward compatibility. The design is derived from the open-source [CHIPS Alliance i3c-core](https://github.com/chipsalliance/i3c-core) reference — studied, extracted, and significantly simplified to focus on core protocol features, reducing the codebase from ~25K to ~2K lines (~92% reduction).

### Supported Features

- **SDR mode** — up to 12.5 MHz
- **I2C backward compatibility** — 400 kHz Fast Mode (FM)
- **Dynamic Address Assignment (DAA)** — via ENTDAA
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

Three-layer design operating in a single clock domain (minimum 333 MHz system clock):

```
i3c_controller_top
├── controller_active       ← Protocol engine
│   ├── flow_active         ← 13-state command FSM (critical module)
│   ├── ccc                 ← CCC processor (ENTDAA, ENEC, DISEC)
│   │   └── ccc_entdaa      ← DAA arbitration sub-FSM
│   ├── bus_tx_flow         ← TX serializer (4-state)
│   ├── bus_rx_flow         ← RX deserializer (4-state)
│   ├── bus_monitor         ← START/STOP/Sr edge detection
│   └── scl_generator       ← SCL clock gen (12.5 MHz / 400 kHz)
├── i3c_phy                 ← 2FF sync + OD/PP output drivers
├── csr_registers           ← Hand-written register file + DAT (16 entries)
└── hci_queues              ← CMD/TX/RX/RESP FIFOs
```

| Layer | Modules | Role |
|---|---|---|
| PHY | `i3c_phy` | 2FF synchronization, Open-Drain/Push-Pull switching |
| Control | `controller_active` and sub-modules | I3C protocol engine |
| Register Interface | `csr_registers`, `hci_queues` | Software access, command/data buffering |

---

## Key Design Decisions

| Area | Reference Design | This Project |
|---|---|---|
| Register interface | AXI4 + AHB-Lite adapters (~700 lines) | Simple 32-bit addr/data/wen/ren (~50 lines) |
| CSR | 14K auto-generated via PeakRDL | Hand-written ~300 lines |
| Top-level | 50+ params, `ifdef` conditional compilation | Clean module, ~10 params, no `ifdef` |
| CCC support | 40+ CCCs, 1,406 lines | 3 CCCs only, ~800 lines |
| DAT entry | 64-bit Caliptra-specific struct | Simplified 32-bit struct |
| `flow_active` FSM | 8 of 13 states left as TODO | All 13 states implemented |

---

## Repository Structure

```
i3c/
├── src/
│   ├── i3c_pkg.sv              ← Shared types: bus_state_t, cmd/resp descriptors
│   ├── controller_pkg.sv       ← Controller types: dat_entry_t, cmd_transfer_dir_e
│   ├── i3c_controller_top.sv   ← Top-level integration
│   ├── scl_generator.sv        ← SCL clock gen (12.5 MHz SDR / 400 kHz I2C FM)
│   ├── sync_fifo.sv            ← Generic parameterized FIFO primitive
│   ├── hci_queues.sv           ← CMD (64-bit) / TX / RX / RESP (32-bit) FIFOs
│   ├── csr_registers.sv        ← Hand-written register file + DAT (16 entries)
│   ├── phy/
│   │   └── i3c_phy.sv          ← 2FF sync + Open-Drain/Push-Pull output drivers
│   └── ctrl/
│       ├── controller_active.sv ← Structural wrapper + OD/PP switching
│       ├── flow_active.sv       ← 13-state command FSM (most critical module)
│       ├── ccc.sv               ← CCC processor: ENTDAA, ENEC, DISEC
│       ├── ccc_entdaa.sv        ← 9-state DAA arbitration sub-FSM
│       ├── bus_tx_flow.sv       ← 4-state TX serializer
│       ├── bus_rx_flow.sv       ← 4-state RX deserializer
│       ├── bus_monitor.sv       ← START/STOP/Sr edge detection
│       ├── bus_tx.sv
│       ├── edge_detector.sv
│       └── stable_high_detector.sv
├── docs/
│   ├── phase1_spec_v2.md       ← Protocol details, FSM definitions, register maps
│   ├── improvements.md         ← Simplification analysis vs reference design
│   ├── implementation_plan.md
│   └── module_specs/           ← Per-module specs (ports, FSMs, timing, LoC)
│       ├── 01_i3c_phy_spec.md
│       ├── 02_bus_monitor_spec.md
│       ├── 03_scl_generator_spec.md
│       ├── 04_bus_tx_spec.md
│       ├── 05_bus_rx_flow_spec.md
│       ├── 06_hci_queues_spec.md
│       ├── 07_csr_registers_spec.md
│       ├── 08_ccc_processor_spec.md
│       ├── 09_flow_active_spec.md      ← Most critical module
│       ├── 10_controller_active_spec.md
│       └── 11_i3c_controller_top_spec.md
└── verification/
    └── uvm/                    ← UVM testbench: BFMs, register model, scoreboard, coverage
```

---

## Signal Conventions

- Inputs: `signal_i`, Outputs: `signal_o`
- Active-low asynchronous reset: `rst_ni`
- Clock: `clk_i`
- FIFO handshake: `*_valid_i` / `*_ready_o`

---

## Reference

- **Specification:** MIPI I3C Basic v1.1.1 with Errata 01 (2022)
- **Reference design:** [chipsalliance/i3c-core](https://github.com/chipsalliance/i3c-core)
- **Thesis documentation:** `docs/phase1_spec_v2.md`
