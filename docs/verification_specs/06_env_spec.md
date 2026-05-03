# Component: UVM Environment (i3c_core/)

> Status: New (structure adapted from reference)
> Location: `verification/uvm_i3c/i3c_core/`
> Reference: `i3c-core/verification/uvm_i3c/i3c_core/` (env, cfg, vseq, scoreboard)
> Estimated LoC: ~400 lines (5 files)

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
1. Commands written via register agent → bus activity observed by I3C monitor
2. Data sent via TX queue → data observed on I3C bus
3. Data from I3C device → data read from RX queue
4. Response descriptors → expected outcomes

### 5.2. Class Hierarchy

```
uvm_scoreboard → i3c_scoreboard
```

### 5.3. Analysis Ports (Input)

| Port | Type | Source | Description |
|------|------|--------|-------------|
| `reg_fifo` | `uvm_tlm_analysis_fifo#(reg_seq_item)` | `reg_monitor.ap` | All register bus transactions |
| `i3c_fifo` | `uvm_tlm_analysis_fifo#(i3c_item)` | `i3c_monitor.ap` | All I3C bus transactions |

### 5.4. Internal State

| Field | Type | Description |
|-------|------|-------------|
| `cmd_queue` | `i3c_response_desc_t [$]` | Expected commands in-flight |
| `tx_data_queue` | `bit [31:0] [$]` | TX data written by SW |
| `expected_i3c_addr` | `bit [6:0]` | Expected target address from CMD |
| `expected_rnw` | `bit` | Expected R/W direction |
| `expected_data_len` | `int` | Expected data length |
| `pass_cnt` | `int` | Passed check count |
| `fail_cnt` | `int` | Failed check count |

### 5.5. Checking Logic

**Phase 1 (basic checking):**

```
run_phase() forks:
  ├── process_reg_items()   — track CMD, TX writes, RESP reads
  └── process_i3c_items()   — compare observed bus activity
```

**process_reg_items():**
```
forever begin
  reg_fifo.get(item);
  case (item.addr)
    ADDR_CMD_QUEUE: begin
      // Track CMD descriptor staging
      // After both DWORDs: decode cmd_attr, dev_idx, rnw, data_length
      // Push expected transaction info
    end
    ADDR_TX_DATA: begin
      // Push TX data to tx_data_queue
      tx_data_queue.push_back(item.wdata);
    end
    ADDR_RESP: begin
      // Check response: err_status should be Success
      if (item.rdata[31:28] != 4'b0000)
        `uvm_error("SCB", $sformatf("Non-zero error status: %0h", item.rdata[31:28]))
    end
  endcase
end
```

**process_i3c_items():**
```
forever begin
  i3c_fifo.get(item);
  // Check address matches expected
  `DV_CHECK_EQ(item.addr, expected_i3c_addr, "Address mismatch")
  // Check direction
  `DV_CHECK_EQ(item.bus_op, expected_rnw ? BusOpRead : BusOpWrite, "Direction mismatch")
  // For writes: compare data bytes against tx_data_queue
  // For reads: data will be checked when SW reads RX queue
  pass_cnt++;
end
```

### 5.6. End-of-Test Checks

```systemverilog
function void check_phase(uvm_phase phase);
  // Verify no unmatched commands
  // Verify no unconsumed TX data
  // Report pass/fail counts
  `DV_EOT_PRINT_TLM_FIFO_CONTENTS(reg_seq_item, reg_fifo)
  `DV_EOT_PRINT_TLM_FIFO_CONTENTS(i3c_item, i3c_fifo)
endfunction
```

### 5.7. Phase 2 Enhancements

- Full command descriptor decode and field-by-field comparison
- CCC-specific checking
- Data integrity CRC verification
- Coverage collection from scoreboard observations

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
| `m_scoreboard` | `i3c_scoreboard` | Scoreboard |

### 6.3. build_phase

```systemverilog
function void build_phase(uvm_phase phase);
  super.build_phase(phase);

  // Get environment config
  if (!uvm_config_db#(i3c_env_cfg)::get(this, "", "cfg", cfg))
    `uvm_fatal(`gfn, "Failed to get i3c_env_cfg")

  // Create virtual sequencer
  if (cfg.is_active) begin
    m_vsequencer = i3c_virtual_sequencer::type_id::create("m_vsequencer", this);
    m_vsequencer.cfg = cfg;
  end

  // Create register agent
  m_reg_agent = reg_agent::type_id::create("m_reg_agent", this);
  uvm_config_db#(reg_agent_cfg)::set(this, "m_reg_agent", "cfg", cfg.m_reg_agent_cfg);

  // Create I3C agent (Device mode)
  m_i3c_agent = i3c_agent::type_id::create("m_i3c_agent", this);
  uvm_config_db#(i3c_agent_cfg)::set(this, "m_i3c_agent", "cfg", cfg.m_i3c_agent_cfg);
  cfg.m_i3c_agent_cfg.en_monitor = 1'b1;

  // Create scoreboard
  if (cfg.en_scb)
    m_scoreboard = i3c_scoreboard::type_id::create("m_scoreboard", this);
endfunction
```

### 6.4. connect_phase

```systemverilog
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  // Connect sequencer handles
  m_vsequencer.m_reg_sequencer = m_reg_agent.sequencer;
  m_vsequencer.m_i3c_sequencer = m_i3c_agent.sequencer;

  // Connect analysis ports to scoreboard
  if (cfg.en_scb) begin
    m_reg_agent.monitor.ap.connect(m_scoreboard.reg_fifo.analysis_export);
    m_i3c_agent.monitor.ap.connect(m_scoreboard.i3c_fifo.analysis_export);
  end
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
  `include "i3c_scoreboard.sv"
  `include "i3c_env.sv"

  // Virtual sequences
  `include "i3c_vseqs/i3c_vseq_list.sv"
endpackage
```

---

## 8. Implementation Notes

- The environment creates exactly **one register agent** and **one I3C agent** (single device)
- The scoreboard in Phase 1 performs basic CMD→bus correlation; full protocol checking is Phase 2
- The environment does NOT create coverage collectors in Phase 1
- The `i3c_env_cfg.initialize()` method sets up default device configuration; tests can override before `build_phase`
- Analysis port connections use `uvm_tlm_analysis_fifo` to decouple producers from consumers and prevent blocking
