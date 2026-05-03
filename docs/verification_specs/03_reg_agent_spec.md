# Component: Register Agent (dv_reg/)

> Status: New
> Location: `verification/uvm_i3c/dv_reg/`
> Reference: Custom (no equivalent in i3c-core — replaces AXI agent placeholder)
> Estimated LoC: ~350 lines total (8 files)

## 1. Purpose

A lightweight UVM agent that drives and monitors the DUT's simple register bus interface (`addr_i`, `wdata_i`, `wen_i`, `ren_i` → `rdata_o`, `ready_o`). This agent replaces the AXI agent that the ChipAlliance reference planned but left as TODO.

The agent supports both Active mode (drives CSR transactions from test sequences) and Passive mode (monitor only, for visibility without driving).

## 2. Dependencies

### Packages

- `uvm_pkg`
- `dv_macros.svh` (included)

### Used By

- `i3c_env` — instantiates one `reg_agent` instance
- `i3c_virtual_sequencer` — holds handle to `reg_sequencer`
- All virtual sequences — use the register agent to configure DUT

---

## 3. File: reg_if.sv

### 3.1. Purpose

SystemVerilog interface encapsulating the DUT's register bus signals. Provides clocking block for synchronous drive/sample and helper tasks.

### 3.2. Ports

| Signal | Direction (from agent) | Width | Description |
|--------|----------------------|-------|-------------|
| `clk_i` | Input (modport) | 1 | System clock |
| `rst_ni` | Input (modport) | 1 | Active-low reset |
| `addr` | Output | 12 | Register address |
| `wdata` | Output | 32 | Write data |
| `wen` | Output | 1 | Write enable |
| `ren` | Output | 1 | Read enable |
| `rdata` | Input | 32 | Read data from DUT |
| `ready` | Input | 1 | DUT ready signal |

### 3.3. Clocking Block

```systemverilog
clocking cb @(posedge clk_i);
  output addr, wdata, wen, ren;
  input  rdata, ready;
endclocking
```

### 3.4. Helper Tasks

```systemverilog
// Drive a single register write
task automatic write(input bit [11:0] a, input bit [31:0] d);
  @(cb);
  cb.addr  <= a;
  cb.wdata <= d;
  cb.wen   <= 1'b1;
  cb.ren   <= 1'b0;
  @(cb);
  cb.wen   <= 1'b0;
endtask

// Drive a single register read, return data
task automatic read(input bit [11:0] a, output bit [31:0] d);
  @(cb);
  cb.addr <= a;
  cb.wen  <= 1'b0;
  cb.ren  <= 1'b1;
  @(cb);
  d = cb.rdata;
  cb.ren <= 1'b0;
endtask
```

### 3.5. Reset Behavior

On `negedge rst_ni`, all outputs default to idle: `wen = 0`, `ren = 0`, `addr = 0`, `wdata = 0`.

### 3.6. Connection to DUT

In `tb_i3c_top.sv`:
```systemverilog
reg_if reg_bus(.clk_i(clk), .rst_ni(rst_n));

i3c_controller_top dut (
  .reg_addr_i  (reg_bus.addr),
  .reg_wdata_i (reg_bus.wdata),
  .reg_wen_i   (reg_bus.wen),
  .reg_ren_i   (reg_bus.ren),
  .reg_rdata_o (reg_bus.rdata),
  .reg_ready_o (reg_bus.ready),
  ...
);
```

---

## 4. File: reg_seq_item.sv

### 4.1. Purpose

UVM sequence item representing a single register bus transaction (read or write).

### 4.2. Fields

| Field | Type | Rand | Description |
|-------|------|------|-------------|
| `addr` | `bit [11:0]` | Yes | Register address |
| `wdata` | `bit [31:0]` | Yes | Write data (used for writes) |
| `is_write` | `bit` | Yes | 1 = write, 0 = read |
| `rdata` | `bit [31:0]` | No | Read data (filled by driver) |

### 4.3. UVM Field Macros

```systemverilog
`uvm_object_utils_begin(reg_seq_item)
  `uvm_field_int(addr,     UVM_DEFAULT)
  `uvm_field_int(wdata,    UVM_DEFAULT)
  `uvm_field_int(is_write, UVM_DEFAULT)
  `uvm_field_int(rdata,    UVM_DEFAULT | UVM_NOCOMPARE)
`uvm_object_utils_end
```

### 4.4. Constraints

```systemverilog
// Ensure addr is 4-byte aligned
constraint addr_aligned_c {
  addr[1:0] == 2'b00;
}
```

---

## 5. File: reg_driver.sv

### 5.1. Purpose

Drives `reg_if` signals based on `reg_seq_item` transactions received from the sequencer.

### 5.2. Class Hierarchy

```
uvm_driver#(reg_seq_item) → reg_driver
```

### 5.3. Key Members

| Member | Type | Description |
|--------|------|-------------|
| `cfg` | `reg_agent_cfg` | Agent configuration handle |
| `vif` | `virtual reg_if` | Interface handle (from config_db) |

### 5.4. Behavior

**run_phase:**
```
fork
  reset_signals();    // Monitor reset and idle outputs
  get_and_drive();    // Main drive loop
join_none
```

**get_and_drive():**
```
forever begin
  seq_item_port.get_next_item(req);
  if (req.is_write) begin
    vif.write(req.addr, req.wdata);
  end else begin
    vif.read(req.addr, req.rdata);
  end
  seq_item_port.item_done(req);
end
```

**reset_signals():**
```
forever begin
  @(negedge vif.rst_ni);
  // Idle all outputs
  @(posedge vif.rst_ni);
end
```

### 5.5. Timing

- Single-cycle write: assert `wen` for 1 clock
- Single-cycle read: assert `ren` for 1 clock, sample `rdata` on same or next cycle
- DUT `ready_o` is always HIGH (per CSR spec) — no stall handling needed initially
- For future-proofing, the driver should wait for `ready` before completing

---

## 6. File: reg_monitor.sv

### 6.1. Purpose

Passively observes `reg_if` and broadcasts observed transactions via analysis port. Does not drive any signals.

### 6.2. Class Hierarchy

```
uvm_monitor → reg_monitor
```

### 6.3. Analysis Port

```systemverilog
uvm_analysis_port#(reg_seq_item) ap;
```

### 6.4. Behavior

**run_phase:**
```
forever begin
  @(posedge vif.clk_i);
  if (vif.wen) begin
    // Capture write transaction
    item.addr = vif.addr;
    item.wdata = vif.wdata;
    item.is_write = 1;
    ap.write(item);
  end
  if (vif.ren) begin
    // Capture read transaction
    item.addr = vif.addr;
    item.is_write = 0;
    @(posedge vif.clk_i);  // Sample rdata one cycle later
    item.rdata = vif.rdata;
    ap.write(item);
  end
end
```

### 6.5. Reset Handling

During reset (`!rst_ni`), the monitor ignores all bus activity.

---

## 7. File: reg_sequencer.sv

### 7.1. Purpose

Standard UVM sequencer parameterized with `reg_seq_item`.

### 7.2. Implementation

```systemverilog
class reg_sequencer extends uvm_sequencer#(reg_seq_item);
  `uvm_component_utils(reg_sequencer)

  reg_agent_cfg cfg;

  function new(string name="", uvm_component parent=null);
    super.new(name, parent);
  endfunction
endclass
```

Minimal — inherits all behavior from `uvm_sequencer`.

---

## 8. File: reg_agent_cfg.sv

### 8.1. Purpose

Configuration object for the register agent.

### 8.2. Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `is_active` | `bit` | `1'b1` | 1 = active (driver + sequencer), 0 = passive (monitor only) |
| `has_driver` | `bit` | `1'b1` | 1 = create driver |

### 8.3. UVM Field Macros

```systemverilog
`uvm_object_utils_begin(reg_agent_cfg)
  `uvm_field_int(is_active,  UVM_DEFAULT)
  `uvm_field_int(has_driver, UVM_DEFAULT)
`uvm_object_utils_end
```

---

## 9. File: reg_agent.sv

### 9.1. Purpose

Top-level agent class. Builds and connects driver, sequencer, and monitor.

### 9.2. Class Hierarchy

```
uvm_agent → reg_agent
```

### 9.3. Key Members

| Member | Type | Description |
|--------|------|-------------|
| `cfg` | `reg_agent_cfg` | Configuration |
| `driver` | `reg_driver` | Bus driver (active mode only) |
| `sequencer` | `reg_sequencer` | Sequencer (active mode only) |
| `monitor` | `reg_monitor` | Bus monitor (always created) |

### 9.4. build_phase

```systemverilog
function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  // Get config from config_db
  if (!uvm_config_db#(reg_agent_cfg)::get(this, "", "cfg", cfg))
    `uvm_fatal(`gfn, "Failed to get reg_agent_cfg")

  // Always create monitor
  monitor = reg_monitor::type_id::create("monitor", this);

  // Create driver and sequencer in active mode
  if (cfg.is_active) begin
    sequencer = reg_sequencer::type_id::create("sequencer", this);
    if (cfg.has_driver)
      driver = reg_driver::type_id::create("driver", this);
  end

  // Get interface handle
  if (!uvm_config_db#(virtual reg_if)::get(this, "", "vif", ...))
    `uvm_fatal(`gfn, "Failed to get reg_if")
endfunction
```

### 9.5. connect_phase

```systemverilog
function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  if (cfg.is_active && cfg.has_driver)
    driver.seq_item_port.connect(sequencer.seq_item_export);
endfunction
```

---

## 10. File: reg_agent_pkg.sv

### 10.1. Purpose

Package that bundles all register agent source files with proper compilation order.

### 10.2. Structure

```systemverilog
package reg_agent_pkg;
  import uvm_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  // Forward declarations
  typedef class reg_seq_item;
  typedef class reg_agent_cfg;

  // Source files (order matters)
  `include "reg_seq_item.sv"
  `include "reg_agent_cfg.sv"
  `include "reg_monitor.sv"
  `include "reg_driver.sv"
  `include "reg_sequencer.sv"
  `include "reg_agent.sv"
endpackage
```

---

## 11. Test Plan (Agent-Level)

| # | Scenario | Description |
|---|----------|-------------|
| 1 | Write single register | Write timing reg, verify on monitor analysis port |
| 2 | Read single register | Read HC_STATUS, verify rdata captured |
| 3 | Write-then-read | Write T_LOW, read it back, compare |
| 4 | Back-to-back writes | Multiple writes without gaps |
| 5 | Reset during transaction | Assert reset mid-write, verify agent recovers |
| 6 | Passive mode | Instantiate agent passive, verify no driving |

Agent-level tests are run as part of the environment smoke test (`i3c_smoke_vseq`), not as standalone agent unit tests in Phase 1.

## 12. Implementation Notes

- The interface uses `logic` types (not `wire`) since it is driven from a clocking block
- The `ready_o` signal from DUT is always 1 in current CSR implementation, but the driver should be written to handle stalls for forward compatibility
- Transaction ordering: the driver processes items sequentially (no pipelining)
- The monitor's analysis port is connected to the scoreboard in `i3c_env.connect_phase`
