# I3C Controller Design Bug Analysis Report

**Date:** April 27, 2026
**Scope:** All 18 SystemVerilog files in `src/`
**Severity Levels:** CRITICAL (blocks synthesis or causes total functional failure), HIGH (incorrect protocol/logic behavior), MEDIUM (potential issues or timing inconsistencies), LOW (style/maintainability)

---

## Summary

| Severity | Count | Resolved |
| -------- | ----- | -------- |
| CRITICAL | 3     | 3        |
| HIGH     | 8     | 8        |
| MEDIUM   | 7     | 7        |
| LOW      | 4     | 4        |

**All 22 bugs resolved.**

---

## CRITICAL Issues

### BUG-001: Stray Character in Parameter List (csr_register.sv)

**File:** `src/csr/csr_register.sv`
**Line:** 15
**Severity:** CRITICAL — Will fail synthesis/compilation
**Status:** RESOLVED — Stray `/` removed from the parameter list.

**Description:**
A stray `/` character appears after the comma in the parameter list, causing a parse error.

**Current Code:**

```systemverilog
  parameter int unsigned CmdDataWidth = 64,/
  localparam int unsigned DatAw    = $clog2(DatDepth)
```

**Fix:**

```systemverilog
  parameter int unsigned CmdDataWidth = 64,
  localparam int unsigned DatAw    = $clog2(DatDepth)
```

---

### BUG-002: Missing SCL Clock Generation for Immediate Transfers (flow_active.sv)

**File:** `src/ctrl/flow_active.sv`
**States:** `I2CWriteImmediate`, `I3CWriteImmediate`
**Severity:** CRITICAL — All immediate transfers are non-functional
**Status:** RESOLVED — `gen_clock = 1'b1` added at the top of both `I2CWriteImmediate` and `I3CWriteImmediate` states.

**Description:**
In the `I2CWriteImmediate` and `I3CWriteImmediate` states, `gen_clock_q` is never set to `1`. After the START condition (phase 0), the `scl_generator` transitions through `HoldStart` → `DriveLow` → `WaitCmd` with SCL stuck LOW, because `gen_clock_i` is `0`. The `bus_tx` module enters `TransmitData` (via `scl_stable_low_i`) but then waits indefinitely for `scl_negedge_i` that never arrives, since SCL never toggles again.

**Signal trace:**

```
scl_generator: HoldStart → DriveLow (t_low+t_f countdown) → WaitCmd (stuck, gen_clock=0)
bus_tx:        Idle → SetupData (scl_stable_low) → TransmitData (hangs forever)
```

**Impact:**
Every `ImmediateDataTransfer` command (both I2C and I3C) hangs after the START condition. Data bytes, address bytes, and ACK/NACK bits are never clocked out.

**Recommended Fix:**
Set `gen_clock_q = 1'b1` at the top of `I2CWriteImmediate` and `I3CWriteImmediate`, similar to how `IssueCmd` does it:

```systemverilog
I2CWriteImmediate: begin
  gen_clock_q = 1'b1;       // <-- ADD THIS
  sel_i3c_i2c_q = 1'b0;
  sel_od_pp_q = 1'b0;
  // ...
```

---

### BUG-003: RX Partial DWORD Data Loss on Read Transfers (flow_active.sv)

**File:** `src/ctrl/flow_active.sv`
**States:** `IssueCmd` (read paths), `FetchRxData`
**Severity:** CRITICAL — Silent data loss on most read transfers
**Status:** RESOLVED — Removed `rx_byte_idx_q == 0` guard in `FetchRxData`; now flushes `rx_dword_q` unconditionally and resets `rx_byte_idx_d = 0` on acceptance so the FSM exits cleanly to `WriteResp`.

**Description:**
Received bytes are accumulated into `rx_dword_q` four at a time and flushed to the RX queue only when `rx_byte_idx_q` wraps to `0` (i.e., a full 32-bit DWORD). When a read transfer completes (`remaining_len_q == 0`), the FSM transitions to `WriteResp` without flushing any partial DWORD remaining in `rx_dword_q`.

**Example:** Reading 5 bytes:

- Bytes 0–3 fill `rx_dword_q` → flushed to RX queue (4 bytes).
- Byte 4 goes into `rx_dword_q[7:0]`, `rx_byte_idx_q = 1`.
- `remaining_len_q` reaches 0 → FSM goes to `WriteResp`.
- The 5th byte is never written to the RX queue.

**Impact:**
Any read transfer whose length is not a multiple of 4 bytes loses 1–3 trailing bytes.

**Recommended Fix:**
Before transitioning to `WriteResp`, flush the partial DWORD if `rx_byte_idx_q != 0`:

```systemverilog
// In the transition to WriteResp for read commands:
if (rx_byte_idx_q != 2'h0) begin
  rx_queue_wvalid_q = 1'b1;
  rx_queue_wdata_q = rx_dword_q;
end
```

---

## HIGH Severity Issues

### BUG-004: Same-Cycle TX/RX Dependency in I2C Write Path (flow_active.sv)

**File:** `src/ctrl/flow_active.sv`
**Lines:** 997–1011
**Severity:** HIGH — Incorrect I2C write protocol
**Status:** RESOLVED — `issue_phase_q[0]` separates TX byte (even phase) from RX ACK (odd phase), eliminating the same-cycle dependency.

**Description:**
In the `IssueCmd` state for I2C writes (`dat_entry.device`), the code asserts `bus_rx_req_bit_q` inside the `bus_tx_done_i` condition, then immediately checks `bus_rx_done_i` in the same combinational block. Since `bus_tx_done_i` is a single-cycle pulse, `bus_rx_req_bit_q` is only asserted for that one cycle. On the next cycle `bus_tx_done_i` deasserts, causing `bus_rx_req_bit_q` to drop back to 0, which makes `bus_rx_flow` abort via its `~req` guard.

Additionally, `bus_tx_req_byte_q` remains asserted at the top of the block, so `bus_tx_flow` (in `NextTaskDecision`) sees an ongoing request and starts another byte instead of waiting for ACK.

**Current Code:**

```systemverilog
bus_tx_req_byte_q = 1'b1;
bus_tx_req_value_q = current_tx_byte;
if (bus_tx_done_i) begin
  bus_rx_req_bit_q = 1'b1;        // Only 1 cycle!
  if (bus_rx_done_i) begin         // Impossible same cycle
    nack_detected_d = bus_rx_data_i[0];
    // ...
  end
end
```

**Impact:**
ACK/NACK is never received for I2C write transfers. The TX flow immediately starts sending the next byte, corrupting the I2C protocol sequence.

**Recommended Fix:**
Use `issue_phase_q` to separate TX byte and RX ACK into distinct phases:

```systemverilog
if (issue_phase_q[0] == 1'b0) begin
  bus_tx_req_byte_q = 1'b1;
  bus_tx_req_value_q = current_tx_byte;
  if (bus_tx_done_i) issue_phase_d = issue_phase_q + 1;
end else begin
  bus_rx_req_bit_q = 1'b1;
  if (bus_rx_done_i) begin
    nack_detected_d = bus_rx_data_i[0];
    issue_phase_d = 8'h0;
    // update counters...
  end
end
```

---

### BUG-005: Same-Cycle TX/RX Dependency in I2C Read Path (flow_active.sv)

**File:** `src/ctrl/flow_active.sv`
**Lines:** 1056–1074
**Severity:** HIGH — Incorrect I2C read protocol
**Status:** RESOLVED — `issue_phase_q[0]` separates RX byte (even phase) from TX master ACK/NACK (odd phase).

**Description:**
In the I2C read path, `bus_tx_req_bit_q` (for ACK/NACK) is set inside the `bus_rx_done_i` block, then `bus_tx_done_i` is checked in the same combinational block. The TX request only lasts one cycle (gated by `bus_rx_done_i`), and the TX done check can never be true in that same cycle.

**Current Code:**

```systemverilog
if (bus_rx_done_i) begin
  // store received data...
  bus_tx_req_bit_q = 1'b1;       // ACK/NACK
  bus_tx_req_value_q = ...;
  if (bus_tx_done_i) begin        // Cannot be true same cycle
    // update indices...
  end
end
```

**Impact:**
Master ACK/NACK is never transmitted for I2C read transfers.

---

### BUG-006: Same-Cycle TX/RX Dependency in I3C Read Path (flow_active.sv)

**File:** `src/ctrl/flow_active.sv`
**Lines:** 1089–1114
**Severity:** HIGH — Incorrect I3C read protocol
**Status:** RESOLVED — T-bit phase redesigned using `(issue_phase_q - 3)[0]` parity; RX byte (even) and RX T-bit (odd) are in separate phases with no cross-dependency.

**Description:**
In the I3C read odd-phase (T-bit), after receiving the parity bit via `bus_rx_done_i`, the code sets `bus_tx_req_bit_q` for the T-bit response and immediately checks `bus_tx_done_i`. Same one-cycle pulse issue as BUG-004/005.

**Impact:**
I3C read T-bit (ACK/End-of-data) is never transmitted.

---

### BUG-007: Missing START Condition for I3C Regular Transfers (flow_active.sv)

**File:** `src/ctrl/flow_active.sv`
**Lines:** 991–1037 (IssueCmd, `cmd_dir == Write`, `!dat_entry.device`)
**Severity:** HIGH — Protocol violation
**Status:** RESOLVED — `IssueCmd` now includes phases 0–2 (START + address byte + ACK) for both I3C regular write and read paths before entering data phases.

**Description:**
For `RegularTransfer` commands targeting I3C devices (not I2C legacy), the FSM path is:

- Write: `FetchDAT` → `FetchTxData` → `IssueCmd`
- Read: `FetchDAT` → `IssueCmd`

The `IssueCmd` state immediately starts sending/receiving data bytes without generating a START condition or transmitting an address byte. Compare with `I3CWriteImmediate` (phases 0–2) and `IssueCmd` for `AddressAssignment` (phases 0–4), both of which correctly generate START + address.

**Impact:**
All I3C regular write/read transfers produce illegal bus activity (data without START/address).

**Recommended Fix:**
Add initial phases in `IssueCmd` for I3C regular transfers that generate START and send the address byte, similar to the `AddressAssignment` path.

---

### BUG-008: SW Reset Doesn't Clear CMD Staging Register (csr_register.sv)

**File:** `src/csr/csr_register.sv`
**Lines:** 162–179
**Severity:** HIGH — Command corruption after software reset
**Status:** RESOLVED — `cmd_staging_valid_q` is now cleared in the `sw_reset_q` branch, preventing a stale DWORD0 from being paired with the next post-reset write.

**Description:**
The `cmd_write` always_ff block clears `cmd_wvalid_q` on `sw_reset_q`, but does not clear `cmd_staging_valid_q` or `cmd_dword0_q`. If software writes DWORD0 to `ADDR_CMD_QUEUE` and then issues a software reset, `cmd_staging_valid_q` remains `1`. The next write to `ADDR_CMD_QUEUE` after reset will be interpreted as DWORD1, paired with the stale DWORD0 data.

**Current Code:**

```systemverilog
end else if (sw_reset_q || (cmd_wvalid_q && cmd_wready_i)) begin
  cmd_wvalid_q <= '0;
  // cmd_staging_valid_q NOT cleared!
  // cmd_dword0_q NOT cleared!
end
```

**Recommended Fix:**

```systemverilog
end else if (sw_reset_q || (cmd_wvalid_q && cmd_wready_i)) begin
  cmd_wvalid_q <= '0;
  cmd_staging_valid_q <= '0;
  cmd_dword0_q <= '0;
end
```

---

### BUG-009: gen_idle_o Never Asserted (flow_active.sv)

**File:** `src/ctrl/flow_active.sv`
**Severity:** HIGH — No bus abort mechanism
**Status:** RESOLVED — `gen_idle = 1'b1` asserted in the `Idle` FSM state of `flow_active`.

**Description:**
`gen_idle_q` defaults to `1'b0` at the top of the `compute_fsm_outputs` block and is never set to `1` in any state. The `gen_idle_o` signal drives `scl_generator`'s `gen_idle_i`, which is a priority override to force the SCL state machine back to `Idle`.

**Impact:**
There is no way to abort an in-progress SCL generation sequence. If the bus gets into an unexpected state (e.g., target clock-stretching indefinitely), the controller has no recovery path.

**Recommended Fix:**
Assert `gen_idle_o` when the FSM transitions to `Idle` or when a software reset occurs.

---

### BUG-010: bus_rx_flow Shift Register Data Race (bus_rx_flow.sv)

**File:** `src/ctrl/bus_rx_flow.sv`
**Lines:** 54, 78
**Severity:** HIGH — Potential data corruption
**Status:** RESOLVED — Both the shift register update and the combinational output now use `rx_bit` (the registered SCL-edge sample) instead of `sda_i`.

**Description:**
The byte shift register (`read_byte_from_bus`) and the combinational output (`update_output_data_value`) both use `sda_i` directly:

```systemverilog
// Line 54: shift register
if (rx_done) rx_data[6:0] <= {rx_data[5:0], sda_i};

// Line 78: output mux
rx_data_o = {rx_data[6:0], sda_i};
```

`rx_done` is asserted one clock cycle after `scl_posedge_i` (registered in `read_bit_from_bus`). By that time, `sda_i` may have changed (the target could be driving the next bit). The correct value was captured in `rx_bit` at the time of `scl_posedge_i`.

**Recommended Fix:**
Use `rx_bit` (the registered sample) instead of `sda_i`:

```systemverilog
if (rx_done) rx_data[6:0] <= {rx_data[5:0], rx_bit};
// ...
rx_data_o = {rx_data[6:0], rx_bit};
```

---

### BUG-011: FIFO Power-of-2 Depth Requirement (sync_fifo.sv)

**File:** `src/hci/sync_fifo.sv`
**Severity:** HIGH — Silent malfunction with non-power-of-2 depths
**Status:** RESOLVED — `initial` block with `$fatal` assertion added to enforce power-of-2 depth at elaboration time.

**Description:**
The FIFO uses extra-MSB pointer comparison for full/empty detection:

```systemverilog
assign full_o  = (rptr_q == {~wptr_q[PtrW], wptr_q[PtrW-1:0]});
assign empty_o = (wptr_q == rptr_q);
```

This technique only works correctly when `Depth` is a power of 2. For non-power-of-2 depths, the write pointer wraps at `2^(PtrW+1)` instead of at `Depth`, causing the full/empty flags to be incorrect and potential data corruption.

**Impact:**
The default depths (64) are safe. But any instantiation with a non-power-of-2 depth will silently malfunction.

**Recommended Fix:**
Add a compile-time assertion:

```systemverilog
initial begin
  assert (Depth == (1 << PtrW))
    else $fatal("sync_fifo: Depth must be a power of 2");
end
```

---

## MEDIUM Severity Issues

### BUG-012: Off-by-One in edge_detector.sv

**File:** `src/ctrl/edge_detector.sv`
**Line:** 31
**Severity:** MEDIUM — Timing one cycle longer than specified
**Status:** RESOLVED — Changed `>=` to `>` to match `stable_high_detector`; both detectors now use identical comparison semantics.

**Description:**
Counter starts at 0 on trigger and increments each cycle. The comparison `count >= delay_count` fires when count equals `delay_count`, meaning the actual delay is `delay_count + 1` cycles (0, 1, ..., delay_count). This is one cycle longer than a naive interpretation of "delay N cycles."

**Impact:**
Edge detection takes one extra cycle. May be intentional but should be documented.

---

### BUG-013: Off-by-One in stable_high_detector.sv

**File:** `src/ctrl/stable_high_detector.sv`
**Line:** 39
**Severity:** MEDIUM — Timing inconsistent with edge_detector
**Status:** RESOLVED — `edge_detector` updated to use `count > delay_count`; both modules now use identical `>` comparison.

**Description:**
Uses `count > delay_count_i` (strictly greater) vs edge_detector's `count >= delay_count`. The stable detection therefore takes one MORE cycle than edge detection for the same `delay_count` value, creating an inconsistency between the two timing modules.

---

### BUG-014: Missing gen_rstart_i Handling in WaitCmd (scl_generator.sv)

**File:** `src/scl_generator.sv`
**Lines:** 198–204
**Severity:** MEDIUM — Incomplete feature
**Status:** RESOLVED — `gen_rstart_i` handling added to `WaitCmd`, symmetrical with `DriveHigh`.

**Description:**
`WaitCmd` handles `gen_stop_i` and `gen_clock_i` but not `gen_rstart_i`. The `DriveHigh` state handles all three. If a repeated START is requested while SCL is held LOW in `WaitCmd`, it will be ignored.

**Recommended Fix:**

```systemverilog
WaitCmd: begin
  if (gen_stop_i) begin
    state_d = GenerateStop;
  end else if (gen_rstart_i) begin
    state_d = GenerateRstart;
  end else if (gen_clock_i) begin
    state_d = DriveLow;
  end
end
```

---

### BUG-015: Dead CCC Ports on flow_active (ccc_code_o, ccc_def_byte_o, ccc_invalid_i)

**File:** `src/rtl/ctrl/flow_active.sv`, `src/rtl/ctrl/controller_active.sv`
**Severity:** LOW — Dead ports / spec-RTL drift (no functional impact)
**Status:** RESOLVED — ports removed.

**Description:**
Three CCC-related ports on `flow_active` were carried over from an earlier architecture that planned a separate external CCC decoder/dispatcher module:

- `ccc_code_o [7:0]` — driven by `ccc_code_q`, which defaulted to `8'h00` and was never assigned in any FSM state.
- `ccc_def_byte_o [7:0]` — driven by `ccc_def_byte_q`, same condition (always zero).
- `ccc_invalid_i` — declared as an input but never read in the module body; tied to `1'b0` at the only instantiation site.

The simplified Phase 1 design folds all CCC byte emission directly into `flow_active`'s own FSM (`imm_desc.cmd` is placed on the bus inline at `flow_active.sv` L732/L830). `entdaa_controller` handles only ENTDAA and does not need a CCC code input. Consequently the three ports had no producer or consumer.

Spec `docs/module_specs/08_ccc_processor_spec.md` (§10, Implementation Notes) already declared these ports removed from the `flow_active` spec (`09_flow_active_spec.md`), but the RTL had not been updated to match.

**Impact:**
None at runtime — `controller_active.sv` left `ccc_code_o` / `ccc_def_byte_o` unconnected and tied `ccc_invalid_i` to `0`. The bug was a spec-RTL drift / dead-port cleanup item, not a functional defect.

**Fix Applied:**
- Removed port declarations, internal `_q` signals, default assignments, and continuous assigns for `ccc_code_o` and `ccc_def_byte_o` from `flow_active.sv`.
- Removed `ccc_invalid_i` port declaration from `flow_active.sv`.
- Removed the three corresponding lines from the `flow_active` instantiation in `controller_active.sv`.

**Follow-up:**
`docs/test_plan/I3C_Testplan_by_claude.md:599` still lists test 6.9 as "ccc_code_o verification" for BUG-015 — that mapping is now stale and should be removed or rewritten to verify bus-level CCC byte transmission instead.

---

### BUG-016: Misuse of Read T-bit as Parity Check (flow_active.sv)

**File:** `src/ctrl/flow_active.sv`
**Line:** 1136 (original)
**Severity:** MEDIUM — Spurious parity-error reporting on normal end-of-read

**Description:**
On the SDR Private Read path, the FSM sampled the T-bit and flagged a parity error whenever it was not `1`:

```systemverilog
parity_error_d = (bus_rx_data_i[0] != 1'b1);
```

This is incorrect. Per MIPI I3C Basic v1.1.1, the T-bit has two distinct meanings depending on direction:

| Direction | T-bit meaning |
|---|---|
| SDR Write (controller→target) | Odd parity of the preceding data byte |
| SDR Read  (target→controller) | Continuation indicator: `1`=more data, `0`=end of read |

On reads there is **no parity check** — the T-bit is purely a flow-control signal. The same code block already interprets the T-bit correctly in the lines immediately following the buggy assignment (`short_read_d` when target ends early, `abort_d` when target wants more than requested). The `parity_error_d` assignment additionally raised the `Parity` response status every time the target legitimately ended the read with T-bit=0, corrupting the RESP FIFO completion code.

**Fix Applied:**
Removed the bogus `parity_error_d` assignment along with the now-unused `parity_error_q` register, its reset/update flip-flop, its hold assignment in the combinational defaults, its clear in the `Idle` state, and the `resp_err_status_q <= Parity` branch that depended on it. The surrounding `short_read`/`abort` logic already encodes the correct semantics of the read T-bit.

Parity checking belongs on the write path, where the controller is the parity *generator*, not a checker, so no additional logic is required in Phase 1 scope.

---

### BUG-017: Bitwise AND Instead of Logical AND (bus_tx.sv)

**File:** `src/ctrl/bus_tx.sv`
**Line:** 176
**Severity:** MEDIUM — Code clarity / potential synthesis mismatch
**Status:** RESOLVED — Changed to logical `&&`.

**Description:**

```systemverilog
if (tcount_q == 20'd0 & scl_stable_low_i)
```

Uses bitwise `&` instead of logical `&&`. For single-bit operands the result is identical, but bitwise AND on a comparison result is unusual and can confuse readers or static analysis tools.

---

### BUG-018: Inconsistent rx_req_bit Registration (bus_rx_flow.sv)

**File:** `src/rtl/ctrl/bus_rx_flow.sv`
**Severity:** MEDIUM — Timing asymmetry
**Status:** RESOLVED — register removed; `rx_req_bit_i` used directly.

**Description:**
`rx_req_bit_i` was registered into `rx_req_bit` (1-cycle delay) and used for the `Idle` → `ReadBit` and `NextTaskDecision` → `ReadBit` transitions. But the abort logic used the unregistered `req = rx_req_bit_i | rx_req_byte_i`. This created a window where `rx_req_bit_i` deasserts, the abort fires immediately (`~req`), but the registered `rx_req_bit` hasn't updated yet.

**Impact:**
The `ReadBit` state could be entered and immediately aborted due to the timing mismatch between the registered and unregistered versions of the same signal. The register also added an unnecessary one-cycle entry latency vs. the `rx_req_byte_i` path, which was never registered.

**Fix Applied:**
Removed the `ff_bit_request` register block and the `rx_req_bit` signal. Replaced both `rx_req_bit` uses in the FSM next-state logic (Idle and NextTaskDecision branches) with `rx_req_bit_i` directly, making the bit and byte request paths symmetric.

---

## LOW Severity Issues

### BUG-019: Counter Underflow in entdaa_fsm.sv

**File:** `src/ctrl/entdaa_fsm.sv`
**Lines:** 123–125
**Severity:** LOW — Benign in practice
**Status:** RESOLVED — decrement guarded with `bit_cnt_q != 0`.

**Description:**
In `ReceiveIDBit`, `bit_cnt_d = bit_cnt_q - 1` underflows to 63 when `bit_cnt_q == 0`. The FSM transitions to `SendAddr` at the same time, so the underflowed value doesn't cause harm in the current design. However, if the module is reused or the FSM is modified, the stale wrapped value could cause issues.

**Fix Applied:**

```systemverilog
if (bit_cnt_q != 6'd0)
  bit_cnt_d = bit_cnt_q - 1;
```

---

### BUG-020: Inconsistent Signal Naming Convention (flow_active.sv)

**File:** `src/ctrl/flow_active.sv`
**Severity:** LOW — Readability
**Status:** RESOLVED — Combinational output signals renamed to remove `_q` suffix (e.g., `gen_start`, `gen_clock`, `bus_tx_req_byte`).

**Description:**
Many signals use the `_q` suffix but are assigned combinationally (e.g., `i3c_fsm_idle_q`, `gen_start_q`, `bus_tx_req_byte_q`). Per the project convention in AGENTS.md, `_q` denotes registered (sequential) values and `_d` denotes next-state. These are purely combinational signals driving output ports.

---

### BUG-021: Use of `wire` Keyword (controller_active.sv)

**File:** `src/ctrl/controller_active.sv`
**Lines:** 98, 116
**Severity:** LOW — Style inconsistency
**Status:** RESOLVED — Both declarations changed to `logic`.

**Description:**
Uses Verilog-2001 `wire` declarations instead of SystemVerilog `logic`:

```systemverilog
wire daa_active = flow_ccc_valid;
wire gen_rstart_combined = flow_gen_rstart | daa_req_restart | daa_restart_pending_q;
```

---

### BUG-022: Hardcoded CCC Code (flow_active.sv)

**File:** `src/ctrl/flow_active.sv`
**Line:** 953
**Severity:** LOW — Maintainability
**Status:** RESOLVED — `CCC_ENTDAA` constant added to `i3c_pkg.sv`; hardcoded literal replaced.

**Description:**
The ENTDAA CCC command code is hardcoded as `8'h07` instead of using a named constant from `i3c_pkg.sv`.

**Fix Applied:**
Added to `i3c_pkg.sv`:

```systemverilog
localparam logic [7:0] CCC_ENTDAA = 8'h07;
```

Replaced `8'h07` in `flow_active.sv` with `CCC_ENTDAA` (resolved via the existing `import i3c_pkg::*`).

---

## Recommendations

1. **Immediate:** Fix BUG-001 (syntax error) to unblock compilation.

2. **Critical priority:** Fix BUG-002 (missing SCL clock) and BUG-003 (RX data loss) — these make immediate transfers and non-aligned reads completely non-functional.

3. **High priority:** Address BUG-004 through BUG-007 (same-cycle TX/RX dependencies and missing START condition) as they break both I2C and I3C protocol state machines. Fix BUG-008 (SW reset staging) to prevent command corruption.

4. **Architectural:** Address BUG-009 (gen_idle) and BUG-011 (FIFO constraint) to improve robustness.

5. **Verification:** Create testbenches covering:
   - Immediate data transfer (I2C and I3C)
   - Regular transfer (I3C write and read, including non-4-byte-aligned lengths)
   - I2C write with ACK/NACK detection
   - I2C read with master ACK/NACK transmission
   - Software reset mid-command
   - ENTDAA sequence

---

## Files Analyzed

| File                               | Issues Found                                                                                      |
| ---------------------------------- | ------------------------------------------------------------------------------------------------- |
| `src/i3c_pkg.sv`                   | None                                                                                              |
| `src/ctrl/controller_pkg.sv`       | None                                                                                              |
| `src/i3c_controller_top.sv`        | None                                                                                              |
| `src/scl_generator.sv`             | BUG-014                                                                                           |
| `src/phy/i3c_phy.sv`               | None                                                                                              |
| `src/ctrl/controller_active.sv`    | BUG-021                                                                                           |
| `src/ctrl/flow_active.sv`          | BUG-002, BUG-003, BUG-004, BUG-005, BUG-006, BUG-007, BUG-009, BUG-015, BUG-016, BUG-020, BUG-022 |
| `src/ctrl/bus_tx.sv`               | BUG-017                                                                                           |
| `src/ctrl/bus_tx_flow.sv`          | None                                                                                              |
| `src/ctrl/bus_rx_flow.sv`          | BUG-010, BUG-018                                                                                  |
| `src/ctrl/bus_monitor.sv`          | None                                                                                              |
| `src/ctrl/edge_detector.sv`        | BUG-012                                                                                           |
| `src/ctrl/stable_high_detector.sv` | BUG-013                                                                                           |
| `src/ctrl/entdaa_controller.sv`    | None                                                                                              |
| `src/ctrl/entdaa_fsm.sv`           | BUG-019                                                                                           |
| `src/csr/csr_register.sv`          | BUG-001, BUG-008                                                                                  |
| `src/hci/sync_fifo.sv`             | BUG-011                                                                                           |
| `src/hci/hci_queues.sv`            | None                                                                                              |
