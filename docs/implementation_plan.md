# I3C Master Controller — Full Implementation Plan

## Overview

Implementing a simplified MIPI I3C Basic v1.1.1 master controller in SystemVerilog, derived from the CHIPS Alliance i3c-core reference with ~92% code reduction. Reference at `/Users/minhuy/Workspace/hcmus/graduated_thesis/i3c-core`.

**Scope:** SDR mode only (12.5 MHz), I2C FM backward compatibility (400 kHz), DAA via ENTDAA. No HDR, IBI, Hot-Join, multi-master, or target mode.

**Current status:** 0 / 16 source files written.

---

## File Structure

All RTL under `src/`, verification under `verification/uvm/`:

```text
src/
  i3c_pkg.sv              # Shared types — adapt from reference
  controller_pkg.sv       # Controller types — simplify from reference
  i3c_phy.sv              # PHY — adapt (replace Caliptra 2FF sync)
  edge_detector.sv        # Edge detector — direct copy
  stable_high_detector.sv # Stable-high detector — direct copy
  bus_monitor.sv          # START/STOP/Sr detection — direct copy
  bus_tx.sv               # TX bit-level engine — direct copy
  bus_tx_flow.sv          # TX byte/bit flow — direct copy
  bus_rx_flow.sv          # RX deserializer — minor adapt
  scl_generator.sv        # SCL clock gen — new (13-state FSM)
  sync_fifo.sv            # Generic FIFO primitive — new
  hci_queues.sv           # 4-FIFO wrapper — new
  csr_registers.sv        # Register file + DAT — new (replaces 14K auto-gen)
  entdaa_fsm.sv           # ENTDAA FSM — rewrite for master perspective
  entdaa_controller.sv    # ENTDAA loop manager — rewrite (master-side, ENEC/DISEC in flow_active)
  flow_active.sv          # Command FSM — rewrite (all 13 states)
  controller_active.sv    # Controller wrapper — rewrite (new architecture)
  i3c_controller_top.sv   # Top-level integration — new
```

---

## Phase 0: Packages

No dependencies. Can be written and reviewed in one session.

### 0.1 `src/i3c_pkg.sv` — ADAPT

**Source:** `i3c-core/src/i3c_pkg.sv`

- Remove `` `include `` directives — inline all needed constants
- Replace `` `DAT_DEPTH `` / `` `DCT_DEPTH `` macros with `parameter int DatDepth = 16` and `localparam int DatAw = $clog2(DatDepth)`
- Remove: `dat_mem_sink_t`, `dat_mem_src_t`, `dct_mem_*` (auto-gen CSR ports), `i3c_tti_*` (target mode), `internal_control_desc_t`, `mipi_cmd_e`, `target_dev_*`
- Keep: `signal_state_t`, `bus_state_t`, `i3c_resp_err_status_e`, `i3c_response_desc_t`, `i3c_cmd_attr_e`, all 4 command descriptor typedefs
- Add: `localparam logic [6:0] I3C_RSVD_ADDR = 7'h7E`

### 0.2 `src/controller_pkg.sv` — ADAPT

**Source:** `i3c-core/src/ctrl/controller_pkg.sv`

- Remove: All I2C ACQ FIFO types, FIFO width/depth parameters, `i3c_err_t`, `i3c_irq_t`
- Keep: `cmd_transfer_dir_e` (Write/Read enum)
- Replace: 64-bit `dat_entry_t` with simplified 32-bit version per spec 07

---

## Phase 1: Leaf Modules

Parallelizable — no inter-module dependencies beyond packages.

### 1.1 `src/i3c_phy.sv` — ADAPT

**Source:** `i3c-core/src/phy/i3c_phy.sv`

- Replace both `caliptra_prim_flop_2sync` instantiations with inline 2FF: `always_ff` chain `d → ff1 → ff2`
- Remove all `` `ifndef DISABLE_INPUT_FF `` conditionals
- Add `parameter bit ResetValue = 1'b1`

### 1.2 `src/edge_detector.sv` — DIRECT COPY

**Source:** `i3c-core/src/ctrl/edge_detector.sv`

### 1.3 `src/stable_high_detector.sv` — DIRECT COPY

**Source:** `i3c-core/src/ctrl/stable_high_detector.sv`

### 1.4 `src/bus_monitor.sv` — DIRECT COPY

**Source:** `i3c-core/src/ctrl/bus_monitor.sv`

Depends on: `i3c_pkg`, `edge_detector`, `stable_high_detector`

### 1.5 `src/bus_tx.sv` — DIRECT COPY

**Source:** `i3c-core/src/ctrl/bus_tx.sv`

### 1.6 `src/bus_tx_flow.sv` — DIRECT COPY

**Source:** `i3c-core/src/ctrl/bus_tx_flow.sv`

Instantiates `bus_tx`.

### 1.7 `src/bus_rx_flow.sv` — MINOR ADAPT

**Source:** `i3c-core/src/ctrl/bus_rx_flow.sv`

- Replace `` `I3C_ASSERT `` macro with standard SVA: `assert property (@(posedge clk_i) ...)`

### 1.8 `src/scl_generator.sv` — NEW

**Source:** `docs/module_specs/03_scl_generator_spec.md`

13-state FSM:

```text
Idle → GenerateStart → SdaFall → HoldStart → DriveLow → DriveHigh → WaitCmd
     → GenerateRstart → SclHigh → RstartSdaFall
     → GenerateStop → SclHighForStop → SdaRise → Idle
```

Key design points:

- Single `tcount` countdown counter; load value is state-dependent
- `scl_o` defaults HIGH, driven LOW only in `DriveLow` / `WaitCmd`
- `sda_o` defaults HIGH, driven LOW only for START/STOP/Sr conditions
- `done_o` pulses 1 cycle on: `HoldStart→DriveLow` (START complete) and `SdaRise→Idle` (STOP complete)
- `busy_o = (state != Idle)`
- Control inputs: `gen_start_i`, `gen_rstart_i`, `gen_stop_i`, `gen_clock_i`, `gen_idle_i`, `sel_i3c_i2c_i`
- Timing inputs: `t_low_i`, `t_high_i`, `t_su_sta_i`, `t_hd_sta_i`, `t_su_sto_i`, `t_r_i`, `t_f_i` (all 20-bit)

---

## Phase 2: Infrastructure

Parallelizable with late Phase 1.

### 2.1 `src/sync_fifo.sv` — NEW

Based on spec 06 §5.1.

- Parameters: `Width`, `Depth`
- Circular buffer with `wptr`, `rptr`, `depth_o`
- `wready_o = ~full_o`, `rvalid_o = ~empty_o`
- Combinational read: `rdata_o = mem[rptr]`
- `flush_i` resets pointers (not memory contents)

### 2.2 `src/hci_queues.sv` — NEW

Wrapper instantiating 4 `sync_fifo` instances:

| Queue | Width | Depth |
| ----- | ----- | ----- |
| CMD   | 64    | 64    |
| TX    | 32    | 64    |
| RX    | 32    | 64    |
| RESP  | 32    | 64    |

### 2.3 `src/csr_registers.sv` — NEW

Based on spec 07. Replaces the PeakRDL-generated CSR.

**Register map:**

| Address     | Name           | Access | Description                                |
| ----------- | -------------- | ------ | ------------------------------------------ |
| `0x000`     | HC_CONTROL     | RW     | [0]=ENABLE, [1]=SW_RESET (self-clear)      |
| `0x004`     | HC_STATUS      | RO     | [0]=FSM_IDLE, [1]=CMD_FULL, [2]=RESP_EMPTY |
| `0x010-030` | Timing (×9)    | RW     | 20-bit timing registers                    |
| `0x100`     | CMD_QUEUE_PORT | WO     | 64-bit staging via 2× 32-bit writes        |
| `0x104`     | TX_DATA_PORT   | WO     | Push to TX FIFO                            |
| `0x108`     | RX_DATA_PORT   | RO     | Pop from RX FIFO                           |
| `0x10C`     | RESP_PORT      | RO     | Pop from RESP FIFO                         |
| `0x110`     | QUEUE_STATUS   | RO     | 8-bit FIFO flags                           |
| `0x200-23C` | DAT[0..15]     | RW     | 32-bit device address table entries        |

**Key implementation details:**

- CMD staging: first write latches DWORD0, second write pushes `{wdata, dword0}` as 64-bit command
- RX/RESP reads assert `rready` to pop FIFO on read access
- DAT hardware read port: 1-cycle registered latency via `dat_index_i` / `dat_rdata_o`
- Timing register defaults (at 333 MHz → I3C 12.5 MHz): `t_r=4`, `t_f=4`, `t_low=8`, `t_high=8`, `t_su_sta=8`, `t_hd_sta=8`, `t_su_sto=4`, `t_su_dat=1`, `t_hd_dat=4`

---

## Phase 3: Protocol Modules

Depends on Phases 0–2.

### 3.1 `src/entdaa_fsm.sv` — REWRITE (master perspective)

**Source:** `i3c-core/src/ctrl/ccc_entdaa.sv` — **target-side, TX/RX roles must be reversed**

The reference module is target-side: it _sends_ PID/BCR/DCR and _receives_ an address. For master: we _receive_ PID/BCR/DCR and _send_ an address.

**Master-perspective FSM:**

| State        | Action                                                                              |
| ------------ | ----------------------------------------------------------------------------------- |
| `Idle`       | Wait `start_daa_i`                                                                  |
| `WaitStart`  | Wait `bus_rstart_det_i` (Sr already generated by `flow_active`)                     |
| `ReceivePID` | `bus_rx_req_bit_o = 1`; receive 64 bits (48 PID + 8 BCR + 8 DCR), decrement counter |
| `SendAddr`   | `bus_tx_req_byte_o = 1`; send `{7-bit addr, odd_parity}`                            |
| `WaitAck`    | `bus_rx_req_bit_o = 1`; read ACK from target                                        |
| `Done`       | Pulse `done_daa_o`; output `daa_pid_o`, `daa_bcr_o`, `daa_dcr_o`                    |
| `Error`      | On NACK or timeout                                                                  |

**Ports vs reference:**

- Remove: `id_i`, `dcr_i`, `bcr_i`, `virtual_*`, `process_virtual_i` (all target-side identity)
- Add: `daa_address_i[6:0]` (address to assign, from `flow_active`)
- Add outputs: `daa_pid_o[47:0]`, `daa_bcr_o[7:0]`, `daa_dcr_o[7:0]`

### 3.2 `src/entdaa_controller.sv` — REWRITE (master-side, ENTDAA only)

**Source concept:** `i3c-core/src/ctrl/ccc.sv` (target-side, 40+ CCCs) — complete rewrite

Handles only: ENTDAA (0x07). ENEC (0x00/0x80) and DISEC (0x01/0x81) are handled by `flow_active`.

The broadcast header (0x7E+W) and START are sent by `flow_active` before delegating here. This module handles from the CCC code byte onward.

**Master-side FSM:**

| State            | Action                                          |
| ---------------- | ----------------------------------------------- |
| `Idle`           | Wait `ccc_valid_i`                              |
| `SendCCCCode`    | Send CCC code byte via `bus_tx_flow`, wait done |
| `WaitCCCAck`     | Read ACK bit via `bus_rx_flow`                  |
| `EntdaaActive`   | Assert `start_daa_o`, wait `done_daa_i`         |
| `SendDefByte`    | Send defining byte (ENEC/DISEC), wait done      |
| `WaitDefByteAck` | Read ACK bit                                    |
| `Done`           | Pulse `ccc_done_o`                              |

**Key ports:** `daa_valid_i`, `dev_count_i[3:0]`, `dev_idx_i[4:0]`, `done_o`, `req_restart_o`. Instantiates `entdaa_fsm` internally; passes through `daa_*` outputs.

### 3.3 `src/flow_active.sv` — REWRITE (all 13 states)

**Source:** `i3c-core/src/ctrl/flow_active.sv` — 8/13 states are TODO stubs in the reference

This is the **most critical module**. The reference implements only 5 states. We implement all 13.

**Major architectural changes vs reference:**

- **Remove** I2C Controller FSM interface (`fmt_fifo_*`, `host_enable_o`, `i2c_controller_fsm` signals)
- **Remove** IBI queue and DCT interfaces, threshold signals
- **Add** SCL generator control: `gen_start_o`, `gen_rstart_o`, `gen_stop_o`, `gen_clock_o`
- **Add** CCC delegation: `ccc_valid_o`, `ccc_i[7:0]`, `ccc_done_i`
- **Add** OD/PP switching: `sel_od_pp_o`
- **Add** direct bus_tx/rx interfaces: `tx_req_byte_o`, `tx_req_value_o`, `rx_req_byte_o`, `rx_data_i`
- **Change** DAT from 64-bit to 32-bit `dat_entry_t`

**All 13 states:**

| State               | Status in reference | Implementation notes                                     |
| ------------------- | ------------------- | -------------------------------------------------------- |
| `Idle`              | Done                | Wait `cmd_queue_valid_i`, assert `fsm_idle_o`            |
| `WaitForCmd`        | Done                | Pop CMD FIFO, decode descriptor                          |
| `FetchDAT`          | Done                | `dat_index_o` → wait 1 cycle → `dat_rdata_i`             |
| `I2CWriteImmediate` | Done (partial)      | OD START + static addr + data (see below)                |
| `I3CWriteImmediate` | **TODO**            | PP START + broadcast header + dynamic addr + inline data |
| `FetchTxData`       | **TODO**            | Pop TX FIFO; stall if empty → `StallWrite`               |
| `FetchRxData`       | **TODO**            | Accumulate RX bytes; stall if RESP full → `StallRead`    |
| `InitI2CWrite`      | **TODO**            | OD START + `{static_addr, 0}` + read ACK                 |
| `InitI2CRead`       | **TODO**            | OD START + `{static_addr, 1}` + read ACK                 |
| `StallWrite`        | **TODO**            | Deassert `gen_clock_o`, wait TX FIFO non-empty           |
| `StallRead`         | **TODO**            | Deassert `gen_clock_o`, wait RX FIFO space available     |
| `IssueCmd`          | **TODO**            | Main data transfer workhorse (see below)                 |
| `WriteResp`         | Done                | Push response descriptor to RESP FIFO                    |

**State implementation details for the 8 TODO states:**

`I3CWriteImmediate`: Assert `gen_start_o`, wait `scl_gen_done_i`. If `cmd.cp` (CCC present): send `{0x7E, W}` via `bus_tx_flow`, read ACK, generate Sr. Send `{dynamic_addr, RnW}`, switch to PP after ACK. Send inline data bytes with T-bit (odd parity). Assert `gen_stop_o` if `cmd.toc`.

`FetchTxData`: Assert `tx_queue_rready_o`. On `tx_queue_rvalid_i`, latch 32-bit DWORD → go to `IssueCmd`. If FIFO empty → go to `StallWrite`.

`FetchRxData`: Accumulate received bytes; when 4 bytes collected, assert `rx_queue_wvalid_o`. If `rx_queue_full_i` → go to `StallRead`.

`InitI2CWrite` / `InitI2CRead`: Assert `gen_start_o` (OD), send `{static_addr, dir_bit}`, read ACK. ACK → `IssueCmd`, NACK → `WriteResp` with `err=Nack`.

`StallWrite`: Hold clock (deassert `gen_clock_o`). Poll `tx_queue_empty_i`; when data arrives → `FetchTxData`.

`StallRead`: Hold clock. Poll `rx_queue_full_i`; when space opens → `FetchRxData`.

`IssueCmd`: Internal `issue_phase` sub-counter.

- _Write:_ For each byte in `tx_dword`, send via `bus_tx_flow` with T-bit. When DWORD exhausted and more data needed → `FetchTxData`. When all done → STOP → `WriteResp`.
- _Read:_ Receive bytes via `bus_rx_flow`. ACK each byte until last, then NACK. Accumulate into DWORD → push to RX FIFO when full.
- _ENTDAA:_ Assert `ccc_valid_o`, wait `ccc_done_i`.

**OD/PP switching rule:** OD during address phase and ACK sampling; PP during I3C data bytes; always OD for I2C. Switch only when `bus_tx_idle` is asserted (never mid-byte).

---

## Phase 4: Integration

Depends on all preceding phases.

### 4.1 `src/controller_active.sv` — REWRITE

**Source concept:** `i3c-core/src/ctrl/controller_active.sv` — complete rewrite

The reference instantiates separate `i2c_controller_fsm` and `i3c_controller_fsm`. Our design uses a single `flow_active` driving `bus_tx_flow`/`bus_rx_flow` directly.

**Sub-module instances:** `flow_active`, `bus_tx_flow`, `bus_rx_flow`, `bus_monitor`, `scl_generator`, `entdaa_controller`

**Key combinational logic (not just wiring):**

- **SDA MUX:** `scl_gen.sda_o` when `scl_gen_busy` (START/STOP phases); `bus_tx.sda_o` during data; default `1'b1`
- **TX/RX MUX:** Route CCC module's TX/RX control signals when `ccc_active`; otherwise `flow_active`'s
- **Arbitration detection:** `arbitration_lost = tx_sda_driven & ~bus_state.sda.value`
- **OD/PP:** `sel_od_pp_o` driven from `flow_active.sel_od_pp_o` (not hardcoded `1'b0` as in reference)
- Unpack `bus_state_t` struct to feed individual `scl`/`sda` value/stable signals to sub-modules

### 4.2 `src/i3c_controller_top.sv` — NEW

Based on spec 11. Purely structural — no combinational logic, only instantiation and wiring.

```text
i3c_controller_top
├── csr_registers     (u_csr)     ← register bus interface
├── hci_queues        (u_queues)  ← CMD/TX/RX/RESP FIFOs
├── controller_active (u_ctrl)    ← timing params from CSR, data from queues
└── i3c_phy           (u_phy)     ← PHY pins ↔ controller signals
```

**Signal routing:**

- External register bus → `u_csr`
- `u_csr` timing outputs → `u_ctrl` timing inputs
- `u_csr` queue ports ↔ `u_queues` (FIFO read/write interfaces)
- `u_queues` CMD/TX read ports → `u_ctrl`; `u_ctrl` RX/RESP write ports → `u_queues`
- `u_ctrl` SCL/SDA/OD-PP outputs → `u_phy` controller inputs
- `u_phy` synchronized SCL/SDA → `u_ctrl` bus state inputs
- `u_phy` ↔ external `scl_io`, `sda_io` pins

---

## Phase 5: Verification

### Framework

- **Simulator:** QuestaSim or VCS (UVM-capable)
- **Framework:** UVM in SystemVerilog
- **Directory:** `verification/uvm/`

### Testbench Structure

```text
verification/uvm/
  tb_top.sv                    # DUT instantiation + clock/reset generation
  i3c_if.sv                    # SystemVerilog interface (SCL, SDA, register bus)
  i3c_env.sv                   # UVM environment (agent + scoreboard + coverage)
  i3c_agent.sv                 # UVM agent (sequencer + driver + monitor)
  i3c_driver.sv                # Drives SCL/SDA and register bus
  i3c_monitor.sv               # Samples bus transactions
  i3c_scoreboard.sv            # Checks responses vs expected
  i3c_coverage.sv              # Functional coverage groups
  sequences/
    i3c_base_seq.sv
    i3c_entdaa_seq.sv
    i3c_private_write_seq.sv
    i3c_private_read_seq.sv
    i3c_i2c_write_seq.sv
    i3c_enec_disec_seq.sv
  tests/
    i3c_base_test.sv
    i3c_entdaa_test.sv
    i3c_private_rw_test.sv
    i3c_i2c_test.sv
    i3c_error_test.sv
```

### Test Priority

1. `i3c_entdaa_test` — ENTDAA with I3C target BFM (full dynamic address assignment flow)
2. `i3c_private_rw_test` — I3C private read/write (immediate and regular)
3. `i3c_i2c_test` — I2C FM legacy device read/write
4. `i3c_enec_disec_test` — ENEC/DISEC broadcast and direct
5. `i3c_error_test` — NACK, parity error, FIFO overflow/underflow

### Key UVM Components

- **I3C target BFM** — reactive agent; responds to DAA, ACKs private transfers, drives T-bit
- **I2C target BFM** — responds to static address, ACKs data bytes
- **Register model** — `uvm_reg_block` mirroring the CSR register map
- **Scoreboard** — checks `resp_queue` descriptors against expected `err_status` and `data_length`
- **Coverage** — FSM state transitions, all CCC types exercised, OD/PP transitions, FIFO boundary conditions

---

## Dependency Graph & Sequencing

```text
Phase 0 (packages, no deps):
  i3c_pkg.sv, controller_pkg.sv
  ↓
Phase 1 (leaf modules, parallel):
  i3c_phy  edge_detector  stable_high_detector  bus_monitor
  bus_tx   bus_tx_flow    bus_rx_flow           scl_generator ← new
  ↓ (overlapping)
Phase 2 (infrastructure, parallel):
  sync_fifo  hci_queues  csr_registers ← new
  ↓
Phase 3 (protocol, sequential within):
  entdaa_fsm        ← master rewrite (depends on bus_rx/tx)
  entdaa_controller ← master rewrite (depends on entdaa_fsm)
  flow_active       ← most critical: 13 states implementation
  ↓
Phase 4 (integration):
  controller_active  →  i3c_controller_top
  ↓
Phase 5 (verification):
  UVM testbench + BFMs + sequences + tests
```

**Critical path:** `flow_active` depends on every other module for meaningful simulation and has the most original logic (8 new states).

---

## Risks & Mitigations

| Risk                                                                  | Mitigation                                                                                                 |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `flow_active` complexity — 8 states with no reference implementation  | Implement incrementally: `InitI2CWrite` first (simplest), then `I3CWriteImmediate`, then regular transfers |
| `entdaa_fsm` role reversal — protocol is the inverse of the reference | Draw a bus trace for master ENTDAA (who sends what in each bit) before writing a single line of RTL        |
| SDA MUX glitch — `scl_gen_busy` boundary must be clean                | Simulate START/STOP sequences in isolation; verify no glitch on the `scl_gen_busy` edge                    |
| OD/PP mid-byte switch — corrupts current bit                          | Gate `sel_od_pp_o` update behind `bus_tx_idle`; add assertion in simulation                                |
| FIFO stall deadlock — `StallWrite`/`StallRead` never exit             | Add timeout counter per stall state; drive `WriteResp` with timeout error if exceeded                      |
