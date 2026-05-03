# Component: Tests & Virtual Sequences

> Status: New (structure adapted from reference)
> Location: `verification/uvm_i3c/i3c_core/`
> Reference: `i3c-core/verification/uvm_i3c/i3c_core/i3c_base_test.sv`, `i3c_vseqs/`
> Estimated LoC: ~500 lines (7 files)

## 1. Purpose

Test and virtual sequence layer that orchestrates DUT configuration and multi-agent coordination. Tests create the environment; virtual sequences drive traffic through the virtual sequencer.

## 2. Dependencies

- `i3c_env_pkg`, `i3c_csr_addr_pkg`, `i3c_pkg`, `reg_agent_pkg`, `i3c_agent_pkg`

---

## 3. File: i3c_test_pkg.sv

Package including base test:
```systemverilog
package i3c_test_pkg;
  import uvm_pkg::*;
  import i3c_env_pkg::*;
  `include "uvm_macros.svh"
  `include "i3c_base_test.sv"
endpackage
```

---

## 4. File: i3c_base_test.sv

### 4.1. Purpose

Base UVM test. Creates environment and config, launches virtual sequence selected by plusarg.

### 4.2. Class Hierarchy

```
uvm_test → i3c_base_test
```

### 4.3. Key Members

| Member | Type | Description |
|--------|------|-------------|
| `env` | `i3c_env` | Environment instance |
| `cfg` | `i3c_env_cfg` | Environment configuration |

### 4.4. build_phase

```systemverilog
virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);
  env = i3c_env::type_id::create("env", this);
  cfg = i3c_env_cfg::type_id::create("cfg", this);
  cfg.initialize();
  `DV_CHECK_RANDOMIZE_FATAL(cfg)
  uvm_config_db#(i3c_env_cfg)::set(this, "env", "cfg", cfg);
endfunction
```

### 4.5. end_of_elaboration_phase

```systemverilog
virtual function void end_of_elaboration_phase(uvm_phase phase);
  uvm_top.print_topology();
endfunction
```

### 4.6. run_phase

```systemverilog
virtual task run_phase(uvm_phase phase);
  string test_seq_s = "i3c_smoke_vseq";  // Default
  void'($value$plusargs("UVM_TEST_SEQ=%0s", test_seq_s));

  uvm_factory factory = uvm_factory::get();
  uvm_object obj = factory.create_object_by_name(test_seq_s, "", test_seq_s);
  // Cast to uvm_sequence, set sequencer, randomize, start
  phase.raise_objection(this);
  test_seq.start(env.m_vsequencer);
  phase.drop_objection(this);
endtask
```

Follows the reference pattern exactly — virtual sequence name is passed via `+UVM_TEST_SEQ=`.

---

## 5. File: i3c_vseqs/i3c_vseq_list.sv

Include file for all virtual sequences:
```systemverilog
`include "i3c_vseqs/i3c_base_vseq.sv"
`include "i3c_vseqs/i3c_smoke_vseq.sv"
`include "i3c_vseqs/i3c_write_vseq.sv"
`include "i3c_vseqs/i3c_read_vseq.sv"
```

---

## 6. File: i3c_vseqs/i3c_base_vseq.sv

### 6.1. Purpose

Base virtual sequence with helper tasks for DUT configuration via register agent. All test-specific sequences inherit from this.

### 6.2. Class Hierarchy

```
uvm_sequence → i3c_base_vseq
```

### 6.3. Key Members

| Member | Type | Description |
|--------|------|-------------|
| `p_sequencer` | `i3c_virtual_sequencer` | Set via `set_sequencer()` |
| `cfg` | `i3c_env_cfg` | Environment config (from p_sequencer) |

### 6.4. Helper Tasks

#### reg_write(addr, data)
```systemverilog
virtual task reg_write(bit [11:0] addr, bit [31:0] data);
  reg_seq_item req = reg_seq_item::type_id::create("req");
  req.addr = addr;
  req.wdata = data;
  req.is_write = 1;
  start_item(req, .sequencer(p_sequencer.m_reg_sequencer));
  finish_item(req);
endtask
```

#### reg_read(addr, output data)
```systemverilog
virtual task reg_read(bit [11:0] addr, output bit [31:0] data);
  reg_seq_item req = reg_seq_item::type_id::create("req");
  req.addr = addr;
  req.is_write = 0;
  start_item(req, .sequencer(p_sequencer.m_reg_sequencer));
  finish_item(req);
  data = req.rdata;
endtask
```

#### configure_dut()
```systemverilog
virtual task configure_dut();
  // Use default timing values (already set by reset)
  // Just enable the controller
  reg_write(ADDR_HC_CONTROL, 32'h0000_0001); // ENABLE=1
endtask
```

#### write_dat_entry(index, static_addr, dynamic_addr, is_i2c)
```systemverilog
virtual task write_dat_entry(int index, bit [6:0] static_addr,
                              bit [6:0] dynamic_addr, bit is_i2c);
  bit [31:0] dat_val;
  dat_val[6:0]   = static_addr;
  dat_val[22:16] = dynamic_addr;
  dat_val[31]    = is_i2c;
  reg_write(dat_addr(index), dat_val);
endtask
```

#### write_cmd(dword0, dword1)
```systemverilog
virtual task write_cmd(bit [31:0] dword0, bit [31:0] dword1);
  reg_write(ADDR_CMD_QUEUE, dword0);  // Stage DWORD0
  reg_write(ADDR_CMD_QUEUE, dword1);  // Trigger 64-bit write
endtask
```

#### write_tx_data(data)
```systemverilog
virtual task write_tx_data(bit [31:0] data);
  reg_write(ADDR_TX_DATA, data);
endtask
```

#### read_rx_data(output data)
```systemverilog
virtual task read_rx_data(output bit [31:0] data);
  reg_read(ADDR_RX_DATA, data);
endtask
```

#### read_response(output data)
```systemverilog
virtual task read_response(output bit [31:0] data);
  reg_read(ADDR_RESP, data);
endtask
```

#### poll_idle(timeout_cycles)
```systemverilog
virtual task poll_idle(int timeout = 10000);
  bit [31:0] status;
  for (int i = 0; i < timeout; i++) begin
    reg_read(ADDR_HC_STATUS, status);
    if (status[0]) return;  // FSM_IDLE
    repeat(10) @(posedge p_sequencer.cfg.m_reg_agent_cfg.vif.clk_i);
  end
  `uvm_fatal("POLL_IDLE", "Timeout waiting for FSM idle")
endtask
```

---

## 7. File: i3c_vseqs/i3c_smoke_vseq.sv

### 7.1. Purpose

First test to bring up. Performs a minimal Immediate Data Transfer (1-2 byte write).

### 7.2. Sequence Body

```
1. configure_dut()                         — Enable controller
2. write_dat_entry(0, 7'h50, 7'h08, 0)   — DAT[0] = I3C device, dynamic addr 0x08
3. Build ImmediateDataTransfer CMD descriptor:
   - DWORD0: attr=001, tid=0, cmd=0, cp=0, dev_idx=0, rnw=0, mode=SDR0, dtt=2, toc=1, wroc=1
   - DWORD1: {def_or_data_byte1=0xAA, data_byte2=0xBB, 0, 0}
4. write_cmd(dword0, dword1)
5. Fork: start i3c_device_response_seq on I3C sequencer
   - target_addr = 7'h08, ack_address = 1, is_i3c = 1
6. poll_idle()
7. read_response(resp)
8. Check resp[31:28] == 4'b0000 (Success)
```

### 7.3. Pass Criteria

- DUT generates START, address 0x08+W, 2 data bytes, STOP on I3C bus
- I3C agent ACKs address and receives data
- Response descriptor shows `err_status = Success`
- No UVM errors or fatals

---

## 8. File: i3c_vseqs/i3c_write_vseq.sv

### 8.1. Purpose

Test Regular Transfer write with data from TX queue.

### 8.2. Sequence Body

```
1. configure_dut()
2. write_dat_entry(0, 7'h50, 7'h08, 0)
3. Build RegularTransfer CMD descriptor:
   - DWORD0: attr=000, tid=1, cmd=0, cp=0, dev_idx=0, rnw=0, mode=SDR0, toc=1, wroc=1
   - DWORD1: data_length=4, def_byte=0
4. write_cmd(dword0, dword1)
5. Write TX data: write_tx_data(32'hDEAD_BEEF)
6. Fork: start i3c_device_response_seq
   - target_addr = 7'h08, data_cnt = 4, ack all
7. poll_idle()
8. read_response(resp)
9. Check resp[31:28] == Success
10. Check resp[15:0] == 4 (data_length)
```

### 8.3. Scoreboard Checks

- I3C monitor observes 4 data bytes matching TX queue content (0xEF, 0xBE, 0xAD, 0xDE — LSB first per TCRI)
- Response matches expected data length

---

## 9. File: i3c_vseqs/i3c_read_vseq.sv

### 9.1. Purpose

Test Regular Transfer read with data to RX queue.

### 9.2. Sequence Body

```
1. configure_dut()
2. write_dat_entry(0, 7'h50, 7'h08, 0)
3. Build RegularTransfer CMD descriptor:
   - DWORD0: attr=000, tid=2, cmd=0, cp=0, dev_idx=0, rnw=1, mode=SDR0, toc=1, wroc=1
   - DWORD1: data_length=4, def_byte=0
4. write_cmd(dword0, dword1)
5. Fork: start i3c_device_response_seq
   - target_addr = 7'h08, read_data = {8'hCA, 8'hFE, 8'hBA, 8'hBE}
6. poll_idle()
7. read_response(resp)
8. Check resp[31:28] == Success
9. read_rx_data(rx)
10. Check rx == 32'hBEBAFECA (packed LSB first)
```

### 9.3. Scoreboard Checks

- I3C monitor observes read transaction to addr 0x08
- RX data matches device-driven data
- Response shows correct data_length

---

## 10. Implementation Notes

- All virtual sequences import `i3c_csr_addr_pkg` for symbolic register addresses
- The `p_sequencer` handle is set automatically by UVM when `start()` is called with the virtual sequencer
- The base_vseq helper tasks use `start_item`/`finish_item` to drive items through the register agent's sequencer
- Device response sequence MUST be forked BEFORE the CMD is written, because the DUT may start bus activity immediately after CMD FIFO becomes non-empty
- The `poll_idle` task uses a polling loop — in Phase 2, an interrupt or event-based mechanism may replace this
- Command descriptor construction uses bit manipulation matching `i3c_pkg` struct layouts
