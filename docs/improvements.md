# Improvement Analysis: CHIPS Alliance i3c-core Reference Design

This document analyzes improvement opportunities from the CHIPS Alliance i3c-core reference design for the thesis project. The reference design is heavily coupled to the Caliptra Root of Trust platform, creating significant complexity that can be eliminated for a standalone I3C controller implementation.

---

## 1. CSR/Register Interface — **98% reduction possible**

**Problem:** Auto-generated via PeakRDL toolchain → **14,342 lines** across 3 files (`I3CCSR.sv`, `I3CCSR_pkg.sv`, `I3CCSR_uvm.sv`) for what is fundamentally ~20-30 registers. The generated code is unreadable and unmaintainable.

**Specific issues:**

- `src/csr/I3CCSR.sv` (7,710 lines) — machine-generated, no human can review
- `src/csr/I3CCSR_pkg.sv` (2,640 lines) — 531 typedef structs/enums
- `src/ctrl/configuration.sv` line 80: deeply nested access like `hwif_out_i.I3C_EC.StdbyCtrlMode.STBY_CR_CONTROL.STBY_CR_ENABLE_INIT.value`
- Includes Caliptra-specific registers: secure firmware recovery, standby controller, SoC management

**Improvement:** Hand-written manual register file (~200 lines). Direct `ctrl_reg[31]` access instead of 5-level struct navigation. Clearer, auditable, synthesizable.

---

## 2. Bus Interface — **88% reduction possible**

**Problem:** Dual AXI4 + AHB-Lite adapters with Caliptra security features (AXI ID filtering for privilege enforcement).

**Specific issues:**

- `src/hci/axi_adapter.sv` (285 lines) — includes AXI_ID_FILTERING for Caliptra privilege
- `src/hci/ahb_if.sv` (133 lines) — double-wrapped (ahb_slv_sif → ahb_if)
- `src/i3c_wrapper.sv` (298 lines) — exists purely for Caliptra integration, uses `prim_ram_1p_adv` primitives

**Improvement:** Simple 32-bit register bus interface (~50 lines): address + data + write_enable + request/acknowledge. No ID filtering, no bursts, no wrappers.

---

## 3. Top-Level Integration — **Caliptra entanglement**

**Problem:** Heavy use of `ifdef` conditional compilation and 50+ parameters at top level.

**Specific issues:**

- `src/i3c.sv` (1,279 lines): `ifdef CONTROLLER_SUPPORT`, `ifdef TARGET_SUPPORT`, `ifdef AXI_ID_FILTERING` throughout
- `src/i3c_wrapper.sv`: pass-through wrapper that adds no logic, just Caliptra SRAM instantiation
- Module naming confusion: file `i3c.sv` contains module `i3c` which instantiates itself

**Improvement:** Single clean top-level module, no `ifdef`, ~10 parameters max. Flat hierarchy without unnecessary wrapper layers.

---

## 4. Controller Core FSMs — **~42% reduction possible**

### 4a. `ccc.sv` (1,406 lines, 23 FSM states) — **Highest priority**

- Handles BOTH controller AND target CCCs (thesis only needs controller)
- Virtual device support adds ~15% complexity (Caliptra security feature)
- HDR mode outputs (8 `ent_hdr_*` signals, 52-line detection block) — dead for SDR-only
- Magic address constants without comments (line 473: `8'h7C, 8'hBC, 8'hDC...`)
- Redundant states: `RxDefByte` vs `RxDefByteOrBusCond` nearly identical
- GET CCC handler (95 lines) could be 5 lines with bit-slicing
- **Improvement:** Split into `ccc_basic.sv` (~800 lines) with only 3 CCCs; use named constants; hierarchical sub-FSMs per CCC category

### 4b. `flow_active.sv` (580 lines, 13 states)

- **8 states completely unimplemented** (TODO placeholders at lines 453-557)
- IBI queue interface (8 ports) wired but permanently disabled (`ibi_queue_wvalid_o = '0`)
- RX queue disabled (`rx_queue_wvalid_o = '0`)
- Error handling stub: always returns `Success` (line 344)
- 9 HCI width parameters could be hardcoded for SDR-only
- **Improvement:** Implement all 8 TODO states to complete the 13-state FSM; remove HDR mode paths; remove dead IBI/RX interfaces; add real error handling

### 4c. `controller_active.sv` (292 lines)

- 8 I2C event signals explicitly marked `unused_*` (lines 213-220)
- All I2C timing parameters hardcoded to `16'd1` or `16'd10` (lines 250-258)
- I2C controller always disabled: `host_enable_i('0)` (line 232)
- OD/PP driver switching not implemented: hardcoded to open-drain (lines 289-291)
- **Improvement:** Enable I2C FSM with hardcoded 400 kHz Fast Mode timing (no CSR configurability); implement OD/PP driver switching in active controller for proper push-pull signaling during I3C SDR data phases

---

## 5. HCI Queue System — **84% reduction possible**

**Problem:** Elaborate threshold system with complex queue management across 2,500+ lines of submodules.

**Specific issues:**

- `src/hci/queues.sv` and submodules: threshold triggers, depth indicators, reset control per queue
- `src/hci/tti.sv` (600+ lines): Target Transaction Interface — Caliptra-only
- `src/hci/csri.sv` (74 lines): unnecessary CSR interface wrapper

**Improvement:** 4 simple synchronous FIFOs with empty/full flags and a single interrupt threshold. ~400 lines total.

---

## 6. TX/RX Flow — **Minor improvements only (already clean)**

**`bus_tx_flow.sv`** (214 lines, 4 states):

- Cryptic one-hot check from StackOverflow (line 73): `~(~|(reqs & (reqs - 1)))`
- Bus error output permanently `'0` (line 75, TODO)
- `sel_od_pp_i` input exists but only passes through, no logic uses it

**`bus_rx_flow.sv`** (169 lines, 4 states):

- Unused `rx_req_bit` latch (stored but direct input used instead)
- Minor: output recalculated every cycle instead of registered

**Assessment:** These modules are well-designed. Keep mostly as-is with minor cleanup.

---

## 7. Verification Infrastructure — **Approach improvement**

**Current:** Hybrid UVM with 24 block-level test dirs and full UVM environment.

**Issues:**

- No dedicated unit test for `ccc_entdaa.sv`
- UVM environment is Caliptra-coupled
- Some tests are minimal

**Improvement:** Focus on UVM. Add missing tests for ENTDAA. Create focused testbenches for the simplified modules.

---

## 8. Configuration & Parameterization

**Problem:** Auto-generated defines via `py2svh.py`, JSON schema with 16+ required properties, conditional parameters with `ifdef`.

**Improvement:** 5-6 tunable `localparam` values directly in source. No tool-generated config.

---

## Summary: Thesis Improvement Contributions

| Area              | Reference Design                | Thesis Improvement                      | Type            |
| ----------------- | ------------------------------- | --------------------------------------- | --------------- |
| Register file     | 14,342 LoC (auto-gen)           | ~200 LoC (manual, readable)             | **Simplify**    |
| Bus interface     | AXI4 + AHB adapters             | Simple register bus                     | **Simplify**    |
| Top-level         | 50+ params, `ifdef`             | Clean, flat hierarchy                   | **Improve**     |
| CCC processor     | 1,406 LoC, 23 states            | ~800 LoC, hierarchical FSMs             | **Improve**     |
| Command FSM       | 8 unimplemented TODO states     | All 13 states implemented (minimal I2C) | **Improve**     |
| OD/PP switching   | Hardcoded to open-drain         | Proper OD/PP driver switching           | **Improve**     |
| HCI queues        | 2,500+ LoC, complex thresholds  | 4 simple FIFOs                          | **Simplify**    |
| TX/RX flow        | Clean (214+169 LoC)             | Reuse with minor fixes                  | **Reuse**       |
| Verification      | UVM (Caliptra-coupled)          | Focused UVM tests                       | **Improve**     |
| Configuration     | Tool-generated, 16+ params      | 5-6 clean parameters                    | **Simplify**    |
| **Total**         | **~25,000 LoC**                 | **~2,000 LoC**                          | **92% smaller** |
