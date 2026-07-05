# Component: UVM Environment (i3c_core/)

> Status: New (structure adapted from reference)
> Location: `src/verification/uvm_i3c/i3c_core/`
> Reference: `i3c-core/verification/uvm_i3c/i3c_core/` (env, cfg, vseq, scoreboard)
> Current scope: environment/config/sequencer, scoreboard shell + 6 `.svh` files, and correlated coverage model (~4300 lines across 13 core files)

## 1. Purpose

The UVM environment instantiates and connects all verification components: register agent, I3C bus agent, virtual sequencer, and scoreboard. It is the central coordination layer between agents and checking logic.

## 2. Dependencies

### Packages

- `uvm_pkg`
- `reg_agent_pkg`
- `i3c_agent_pkg`
- `i3c_csr_addr_pkg`
- `i3c_pkg` (for command/response descriptor types)
- `dv_macros.svh`

### Instantiated By

- `i3c_base_test`

---

## 3. File: i3c_env_cfg.sv

### 3.1. Purpose

Configuration object for the entire environment. Holds sub-agent configs and global settings.

### 3.2. Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `is_active` | `bit` | `1` | Active mode (create virtual sequencer) |
| `en_scb` | `bit` | `1` | Enable scoreboard |
| `under_reset` | `bit` | `0` | Reset status |
| `is_initialized` | `bit` | `0` | Set after initialize() |
| `m_reg_agent_cfg` | `reg_agent_cfg` | - | Register agent configuration |
| `m_i3c_agent_cfg` | `i3c_agent_cfg` | - | I3C agent configuration |

### 3.3. UVM Field Macros

```systemverilog
`uvm_object_utils_begin(i3c_env_cfg)
  `uvm_field_int   (is_active,        UVM_DEFAULT)
  `uvm_field_int   (en_scb,           UVM_DEFAULT)
  `uvm_field_object(m_reg_agent_cfg,   UVM_DEFAULT)
  `uvm_field_object(m_i3c_agent_cfg,   UVM_DEFAULT)
`uvm_object_utils_end
```

### 3.4. initialize() Method

```systemverilog
virtual function void initialize();
  is_initialized = 1'b1;

  // Register agent: active, with driver
  m_reg_agent_cfg = reg_agent_cfg::type_id::create("m_reg_agent_cfg");
  m_reg_agent_cfg.is_active = 1;
  m_reg_agent_cfg.has_driver = 1;

  // I3C agent: active, device mode, single target
  m_i3c_agent_cfg = i3c_agent_cfg::type_id::create("m_i3c_agent_cfg");
  m_i3c_agent_cfg.is_active = 1;
  m_i3c_agent_cfg.if_mode = Device;
  m_i3c_agent_cfg.has_driver = 1;
  m_i3c_agent_cfg.en_monitor = 1;

  // Configure single I3C target device
  m_i3c_agent_cfg.i3c_target0.dynamic_addr = 7'h08;
  m_i3c_agent_cfg.i3c_target0.dynamic_addr_valid = 1;
  m_i3c_agent_cfg.i3c_target0.static_addr = 7'h50;
  m_i3c_agent_cfg.i3c_target0.static_addr_valid = 1;
  m_i3c_agent_cfg.i3c_target0.bcr = 8'h00;
  m_i3c_agent_cfg.i3c_target0.dcr = 8'h00;
  m_i3c_agent_cfg.i3c_target0.pid = 48'h0000_0000_0001;
endfunction
```

---

## 4. File: i3c_virtual_sequencer.sv

### 4.1. Purpose

Virtual sequencer that holds handles to all sub-agent sequencers. Virtual sequences use this to coordinate multi-agent activity.

### 4.2. Fields

| Field | Type | Description |
|-------|------|-------------|
| `cfg` | `i3c_env_cfg` | Environment configuration |
| `m_reg_sequencer` | `reg_sequencer` | Register agent sequencer handle |
| `m_i3c_sequencer` | `i3c_sequencer` | I3C agent sequencer handle |

### 4.3. Implementation

```systemverilog
class i3c_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(i3c_virtual_sequencer)

  i3c_env_cfg    cfg;
  reg_sequencer  m_reg_sequencer;
  i3c_sequencer  m_i3c_sequencer;

  function new(string name="", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction
endclass
```

### 4.4. Connection

Sequencer handles are assigned in `i3c_env.connect_phase`:
```systemverilog
m_vsequencer.m_reg_sequencer = m_reg_agent.sequencer;
m_vsequencer.m_i3c_sequencer = m_i3c_agent.sequencer;
```

---

## 5. File: i3c_scoreboard.sv

### 5.1. Purpose

Verifies correct DUT behavior by comparing:
1. Commands written via register agent (CMD queue DWORDs, DAT writes, HC_CONTROL/RESET_CONTROL) → bus activity observed by the I3C monitor
2. Data sent via the TX queue → data observed on the I3C bus (regular, immediate, and CCC payloads)
3. Data from the I3C device → data read back from the RX queue (including ENTDAA PID/BCR/DCR/address results)
4. Response descriptors (error status, length, TID) → a full reference model of the expected response, including abort/recovery/stall-recovery/WROC-completion policy
5. Publishes derived, protocol-level observations (`i3c_correlated_item`) to `i3c_correlated_coverage` for functional coverage (§5.5)

This is a full reference-model scoreboard, not a basic CMD↔bus correlation check.

### 5.2. Class Hierarchy

```
uvm_scoreboard → i3c_scoreboard
```

The class body declares the analysis ports and internal model `typedef`s/state (§5.4), implements UVM lifecycle and top-level input dispatch inline (`new`, `build_phase`, `run_phase`, `process_req_items()`, `process_i3c_items()`, `process_hard_reset()`, `check_phase`), and then `extern`-declares the remaining helper methods; those helpers are implemented out-of-line across six `` `include``d `.svh` files (§5.5), each covering one grouping.

### 5.3. Analysis Ports

| Port | Direction | Type | Source / Sink | Description |
|------|-----------|------|--------|-------------|
| `reg_fifo` | Input | `uvm_tlm_analysis_fifo#(reg_seq_item)` | `reg_agent.monitor.analysis_port` | All register bus transactions |
| `i3c_fifo` | Input | `uvm_tlm_analysis_fifo#(i3c_item)` | `i3c_agent.monitor.analysis_port` | All I3C bus transactions |
| `correlated_ap` | Output | `uvm_analysis_port#(i3c_correlated_item)` | → `i3c_correlated_coverage.analysis_export` (`i3c_env`, §6.4) | Derived per-transaction observations for cross-coverage, published from inside the checking logic itself (not a passive tap) |

### 5.4. Internal State (representative)

The scoreboard carries a full expected-transaction model rather than a handful of scalars. Key `typedef`s and queues:

| Type / field | Description |
|-------|-------------|
| `exp_txn_t` | One expected command: attr/opcode, address, R/W, `toc`/`wroc`/`sre`, data length, TID, DAT index, CCC/ENTDAA fields, immediate-data bytes, broadcast-header eligibility |
| `dat_model_entry_t` | Shadow copy of one DAT entry (`valid`, `device`, static/dynamic address) — built from observed register writes (§ `handle_dat_write()`) |
| `exp_rx_data_t` | One expected RX FIFO DWORD (read-back correlation id, TID, data length, word index, integrity-pattern classification) |
| `exp_resp_t` / `exp_resp_seed_t` | Expected response descriptor state: status, length, command class, CCC/DAA result, address-result context, and (for `exp_resp_t`) abort/recovery/stall-recovery context. Command-history boundary is maintained separately in `previous_command_boundary` |
| `daa_scan_state_t` | Per-ENTDAA-round scratch state (devices joined, rejected PID/BCR/DCR/address, terminating NACK) |
| `exp_txn_queue`, `tx_data_queue`, `exp_rx_data_queue`, `exp_resp_queue` | In-flight expectation queues, one per model above |
| `dat_model[DAT_DEPTH]` | Full shadow DAT array |
| `pending_abort_*`, `recovery_*`, `stall_recovery_*`, `*_history_*` | Cross-transaction state carried between commands for abort/recovery/stall/command-boundary checking and coverage |

### 5.5. Checking Logic — scoreboard shell + 6 include files

```
run_phase() forks (join):
  ├── process_req_items()    — register-bus writes/reads: CMD DWORDs, DAT writes,
  │                            HC_CONTROL/RESET_CONTROL, PIO_DATA_PORT TX push,
  │                            RESP/PIO_DATA_PORT reads → check_resp()/check_rx_data()
  ├── process_i3c_items()    — i3c_fifo.get() → check_i3c_txn() for every observed frame
  └── process_hard_reset()   — on DUT reset: flush both FIFOs, handle_hard_reset()
```

The class declares its full method surface as `extern` in `i3c_scoreboard.sv`, then closes with six `` `include``s — each file implements exactly the group of `extern` methods declared under its matching comment header in the class body:

| Include file | Method group (per the `extern` table of contents) | Responsibility |
|---|---|---|
| `i3c_scoreboard_refmodel.svh` | "Reference model" | HC_CONTROL/RESET_CONTROL/DAT-write handling, SW/hard reset, command-descriptor validation, DAT lookups |
| `i3c_scoreboard_bus.svh` | "Bus transaction checking" | Matches an observed `i3c_item` to its `exp_txn_t`, checks read/write data, ACK/T-bit sequencing, RX-word enqueue, TX-byte/ACK expectation building |
| `i3c_scoreboard_ccc.svh` | "CCC and ENTDAA checking" | Broadcast/direct-CCC opcode and payload checking, ENTDAA per-round arbitration and DAT-assignment checking |
| `i3c_scoreboard_resp.svh` | "RX/response and recovery modeling" | RX FIFO word checking, response-descriptor checking against the full expected-response model, abort/recovery/stall-recovery context tracking |
| `i3c_scoreboard_cov.svh` | "Correlated coverage" | Classifies outcomes (length/NACK-position/short-boundary/data-pattern/DAA-span) and publishes `i3c_correlated_item`s + response/abort/recovery/DAA/CCC coverage events to `correlated_ap` |
| `i3c_scoreboard_fmt.svh` | "Diagnostic formatting" | `` `uvm_error``/log message formatting helpers (byte/bit/ACK lists, optional-field printers) — no checking logic |

### 5.6. End-of-Test Checks (`check_phase`)

Reports (as `` `uvm_error``) any expected command, TX data word, or expected-response/RX-data-word that was never observed by end of test, then prints both analysis FIFOs' remaining contents via `` `DV_EOT_PRINT_TLM_FIFO_CONTENTS``.

### 5.7. Status

CCC-specific checking, full command-descriptor decode, abort/recovery/stall-recovery modeling, and coverage collection from scoreboard observations (§5.5, `i3c_scoreboard_cov.svh`) are all implemented — none of this is deferred future work.

---

## 6. File: i3c_env.sv

### 6.1. Purpose

Top-level UVM environment. Instantiates agents, virtual sequencer, and scoreboard.

### 6.2. Key Members

| Member | Type | Description |
|--------|------|-------------|
| `cfg` | `i3c_env_cfg` | Environment configuration |
| `m_reg_agent` | `reg_agent` | Register bus agent |
| `m_i3c_agent` | `i3c_agent` | I3C bus agent (Device mode) |
| `m_vsequencer` | `i3c_virtual_sequencer` | Virtual sequencer |
| `m_scoreboard` | `i3c_scoreboard` | Scoreboard (§5) |
| `m_i3c_coverage` | `i3c_coverage` | I3C-bus-item covergroups (subscriber on the I3C monitor directly, always created) |
| `m_reg_coverage` | `reg_coverage` | Register-bus covergroups (subscriber on the reg monitor directly, always created) |
| `m_correlated_coverage` | `i3c_correlated_coverage` | Cross-domain covergroups fed only by the scoreboard's `correlated_ap` (created only when `cfg.en_scb`) |

### 6.3. build_phase

```systemverilog
function void build_phase(uvm_phase phase);
  super.build_phase(phase);

  if (!uvm_config_db#(i3c_env_cfg)::get(this, "", "cfg", cfg))
    `uvm_fatal(`gfn, "Failed to get i3c_env_cfg")

  if (cfg.is_active) begin
    m_vsequencer = i3c_virtual_sequencer::type_id::create("m_vsequencer", this);
    m_vsequencer.cfg = cfg;
  end

  m_reg_agent = reg_agent::type_id::create("m_reg_agent", this);
  uvm_config_db#(reg_agent_cfg)::set(this, "m_reg_agent", "cfg", cfg.m_reg_agent_cfg);

  m_i3c_agent = i3c_agent::type_id::create("m_i3c_agent", this);
  uvm_config_db#(i3c_agent_cfg)::set(this, "m_i3c_agent", "cfg", cfg.m_i3c_agent_cfg);
  cfg.m_i3c_agent_cfg.en_monitor = 1'b1;

  m_i3c_coverage = i3c_coverage::type_id::create("m_i3c_coverage", this);
  m_reg_coverage = reg_coverage::type_id::create("m_reg_coverage", this);

  if (cfg.en_scb) begin
    m_scoreboard = i3c_scoreboard::type_id::create("m_scoreboard", this);
    m_scoreboard.cfg = cfg;
    m_correlated_coverage =
        i3c_correlated_coverage::type_id::create("m_correlated_coverage", this);
  end
endfunction
```

### 6.4. connect_phase

```systemverilog
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  m_vsequencer.m_reg_sequencer = m_reg_agent.sequencer;
  m_vsequencer.m_i3c_sequencer = m_i3c_agent.sequencer;

  if (cfg.en_scb) begin
    m_reg_agent.monitor.analysis_port.connect(m_scoreboard.reg_fifo.analysis_export);
    m_i3c_agent.monitor.analysis_port.connect(m_scoreboard.i3c_fifo.analysis_export);
    m_scoreboard.correlated_ap.connect(m_correlated_coverage.analysis_export);
  end

  // Coverage subscribers tap the raw monitors directly, independent of en_scb
  m_i3c_agent.monitor.analysis_port.connect(m_i3c_coverage.analysis_export);
  m_reg_agent.monitor.analysis_port.connect(m_reg_coverage.analysis_export);
endfunction
```

---

## 7. File: i3c_env_pkg.sv

### 7.1. Purpose

Package bundling all environment source files.

### 7.2. Structure

```systemverilog
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
  `include "i3c_correlated_item.sv"
  `include "i3c_coverage.sv"
  `include "reg_coverage.sv"
  `include "i3c_correlated_coverage.sv"
  `include "i3c_scoreboard.sv"
  `include "i3c_env.sv"

  // Virtual sequences
  `include "i3c_vseqs/i3c_vseq_list.sv"
endpackage
```

`i3c_correlated_item.sv`/`i3c_coverage.sv`/`reg_coverage.sv`/`i3c_correlated_coverage.sv` must precede `i3c_scoreboard.sv` and `i3c_env.sv` because both reference these types (`i3c_scoreboard.correlated_ap` is typed `uvm_analysis_port#(i3c_correlated_item)`; `i3c_env` instantiates `i3c_coverage`/`reg_coverage`/`i3c_correlated_coverage` directly, §6.2/6.3).

---

## 8. Implementation Notes

- The environment creates exactly **one register agent** and **one I3C agent** (single device, though `i3c_agent_cfg` carries config slots for a second target — `i3c_target1`, `04_i3c_agent_spec.md` §11.2 — that this env does not populate)
- The scoreboard performs full protocol/response/CCC/ENTDAA/abort/recovery reference-model checking, split across the scoreboard shell + 6 include files (§5.5); this is not deferred Phase-2 work
- The environment always creates `i3c_coverage`/`reg_coverage` (raw per-domain coverage), and additionally creates `i3c_correlated_coverage` when `cfg.en_scb` (cross-domain coverage fed by the scoreboard, §6.2/6.4)
- The `i3c_env_cfg.initialize()` method sets up default device configuration; tests can override before `build_phase`
- Analysis port connections use `uvm_tlm_analysis_fifo` (scoreboard inputs) to decouple producers from consumers and prevent blocking; the scoreboard's `correlated_ap` and the coverage subscribers' exports are plain `uvm_analysis_port`/`uvm_subscriber` connections instead
