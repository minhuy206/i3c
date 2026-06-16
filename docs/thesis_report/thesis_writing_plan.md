# Thesis Writing Plan — "Design of an I3C Communication Controller"

**Author:** Vo Minh Huy (22207042) · **Supervisor:** ThS. Nguyễn Duy Mạnh Thi · HCMUS
**Branch cross-checked:** `feat/hc-abort-intr-sdrw-flow` (HEAD `f132752`) · **Date:** 2026-06-15
**Re-verified against RTL+specs:** 2026-06-16 — M2, M3, M5, M7 resolved by user edits; M6/M8/M9 updated below.

## Context

This is a documentation-vs-implementation cross-check used to drive thesis writing.
Three parallel reads were done: (1) RTL `src/rtl/**` vs `docs/module_specs/**`, (2) UVM
`src/verification/uvm_i3c/**` vs `docs/verification_specs/**` + Makefile, (3) thesis-structure
docs (`thesis_master_plan.md`, supervisor outline PDF, `phase1_spec_v2.md`, `improvements.md`,
`I3C_Testplan.md`). Every claim below was verified against source files.

**Ground-truth policy (2026-06-15):**
- **The current RTL (`src/rtl/**`) and the module specs (`docs/module_specs/**`) are the
  authoritative source.** Where `phase1_spec_v2.md`, `thesis_master_plan.md`, or `I3C_Testplan.md`
  disagree, the RTL + module specs win and the planning docs are treated as stale.
- **`bug_analysis_report.md` is excluded** from this plan. No BUG-xxx status is asserted; the
  thesis is written from the code as it stands, not from a historical bug log.

**Two user decisions made (2026-06-15):**
- **Chapter model: Expanded 10-chapter** (per `thesis_master_plan.md`), NOT the compact 4-chapter reference shape.
- **FPGA: OMITTED entirely.** Chapter 8 is dropped; Results (Ch.9) carries no FPGA data. (Supervisor outline §4/§5.4 marks FPGA optional, and the repo has zero FPGA artifacts.)

> ⚠️ The deliverable of *this* file is the writing plan itself (Sections 0–5 below). It is the only file edited; no code or doc was modified.

---

## SECTION 0 — SNAPSHOT SUMMARY

Legend: ✅ match · ⚠️ mismatch · ❓ ambiguous/missing

### RTL modules

| Item | Spec Doc | Doc State | RTL State | Match? | Notes |
|---|---|---|---|---|---|
| flow_active FSM | 09 | 14 states (§5.1) | 14 states (`flow_fsm_state_e`) | ✅ | Spec 09 & RTL agree on 14; phase1_spec_v2 + master plan now updated to 14 (M1 resolved). Abort/intr added as behavior + 2 event ports, no new states. |
| scl_generator FSM | 03 | 14 states (+`BusFree`); OD-low/bus-free timing ports | 14 states; same timing ports | ✅ | Aligned (M2 resolved). Spec still lists `req_restart_i/ack_o` but now explicitly flags them "Consider later" — RTL folds restart into `gen_rstart_i`. |
| csr_registers map | 07 | 30 regs + DAT | identical offsets/resets/INTR bits | ✅ | Every address + reset value matches. |
| entdaa_fsm | 08b | 8 states | 8 states | ✅ | Names/encodings identical. |
| entdaa_controller | 08 | 7 states; `DatDepth` default 32 | 7 states; `DatDepth` default 32 | ✅ | M3 resolved — spec 08 default now 32. |
| bus_tx_flow | 04 | 4 states `[2:0]` | 4 states `[2:0]` | ✅ | M4 resolved — spec 04 `tx_flow_state_e` now `[2:0]`. (`tcount_sel_e` at `[1:0]` in bus_tx is correct.) |
| bus_rx_flow | 05 | 4 states `[2:0]` | 4 states `[2:0]` | ✅ | M4 resolved — spec 05 `rx_state_e` now `[2:0]`. |
| bus_tx | 04 | 5 states | 5 states | ✅ | Names/encodings identical. |
| bus_monitor / phy / hci_queues / sync_fifo / controller_active / top | 01,02,06,10,11 | structural | matches | ✅ | sync_fifo has power-of-2 elaboration assert. Top has harmless ×4 duplicate import. |
| Error-code set | phase1_spec_v2 | full TCRI Table 11 (0x0–0xA) + Generated? col | priority fn generates 0x0/0x4/0x5/0x6/0x7/0x8/0xA | ✅ | M5 resolved — phase1 §9.4 now matches RTL/spec-09 taxonomy. |

### UVM / verification

| Item | Spec Doc | Doc State | UVM State | Match? | Notes |
|---|---|---|---|---|---|
| Vseq inventory | 00, 08 | ~5–8 vseqs | 55 vseqs across 8 subdirs | ⚠️ | Specs predate bulk of suite (M6). Verification still in development — vseq count expected to grow toward testplan count. Treat current suite as in-progress snapshot. |
| `csr_dat_hw_read_selection_vseq` | — | n/a | registered in `i3c_vseq_list.sv` | ✅ | M7 resolved — `\`include\`d` now. |
| `i3c_read_addr_nack_vseq` | — | in `sdrr_regression` SEQ list | file removed; addr-NACK now in `resp_vseqs` + `err_regression` | ✅ | M8 resolved (2026-06-16) — stale line removed from `SDRR_REGRESSION_SEQS`. |
| Makefile targets | 09 | compile/sim/smoke/regression | + csr/fifo/bus/sdrw/sdrr/sdr/**err** regressions, COV, FIFO_005 | ⚠️ | Makefile far ahead of spec 09 (M9). `err_regression` target now added (4 resp vseqs); still no ccc/daa/i2c/imm. |
| Driver phases | 04 | 10-state device table | 13 phases (+`DrvAddrPushPull`,`DrvWaitStopOrRStart`); host mode removed | ⚠️ | Superset for bcast-header; subset for host (M10). |
| Scoreboard checks | I3C_Testplan §1 | "Minimal / basic" | rich: read+write data, T-bit, RX/TX packing, CCC, DAT, resp-priority | ⚠️ | "Minimal" characterization stale (M11). |
| CSR addr pkg | 07 | DAT 16 entries | `DAT_DEPTH=32` | ✅ | All docs updated to 32 (M12 resolved). |
| SVA | master plan | "1 SVA in bus_rx_flow" | 5 SVA files: 4 bound + `tb_pad_model_sva` instantiated | ⚠️ | SVA infra far beyond "minimal" (M13). |

### Thesis structure & misc

| Item | Source | Claim | Reality | Match? | Notes |
|---|---|---|---|---|---|
| `data_byte_idx` immediate-write behavior | dut_i3c_write_immediate_flow.md | RTL sends `0xAA,0xAA` not `0xAA,0xBB` | needs re-check vs current `flow_active.sv` | ❓ | Write from current RTL as-is (M14). |
| Chapter model | master plan vs outline | 10-ch vs 5-phase | outline = 5-phase work plan, mandates no chapters | ❓ | User chose 10-ch (M15 resolved). |
| FPGA | master plan Ch.8 | optional / greenfield | zero artifacts | ✅ | User chose to OMIT. |
| Tooling | outline PDF §6 | ModelSim/Verilator/Quartus/GTKWave | repo uses Xcelium + SimVision | ⚠️ | Outline tooling ≠ reality (M16). |

---

## SECTION 1 — MISMATCHES & DISCUSSION ITEMS

### RTL vs module spec

```
✅ RESOLVED M1: flow_active / scl_generator state count = 14 (2026-06-16)
  Fixed: thesis_master_plan.md now says "14" for both flow_active and scl_generator (11 mechanical
    refs + 3 narrative refs). phase1_spec_v2 was already corrected. The contribution narrative now
    reads "8 of 14 states the reference left as TODO" — consistent with spec 09 §line 23
    ("reference has 8 out of 14 states unimplemented; this design implements all 14").
  RTL ground truth: flow_fsm_state_e has 14 states; scl_generator state_e has 14 (Idle…BusFree).
  flow_active states: Idle, WaitForCmd, FetchDAT, WaitDAT, I3CBcastHeader, I3CWriteImmediate,
    I2CWriteImmediate, FetchTxData, InitI3CWrite, InitI3CRead, InitI2CWrite, InitI2CRead,
    IssueCmd, WriteResp.
  Note: docs/improvements.md still says "13 states" (lines 62/64/69/142) describing the reference
    flow_active — stale vs spec 09's count of 14. Fix if quoted in Ch.1/Ch.4 (see §4).
```
```
✅ RESOLVED M2: scl_generator spec aligned to RTL (2026-06-16)
  Fixed: spec 03 now documents the 14-state FSM (Idle…BusFree = 4'd13), and the timing-port
    table now matches RTL: t_low_od_i, t_bus_free_i, scl_use_od_low_i added; STOP/Sr now
    serviced from low-phase states (DriveLow/WaitCmd), DriveHigh exits by counter only.
  Remaining (documented, not a silent mismatch): spec still lists req_restart_i / req_restart_ack_o
    in the ENTDAA-restart port table, but two "Consider later" callouts now state explicitly that
    the current RTL has no such ports and folds DAA restart into gen_rstart_i (controller_active's
    daa_restart_pending_q latch).
  Impact on thesis: Ch.5 scl_generator section — write the 14-state FSM + real port list; mention
    the restart mechanism via gen_rstart_i and note the explicit-handshake ports as future cleanup.
```
```
✅ RESOLVED M3: entdaa_controller DatDepth default (2026-06-16)
  Fixed: spec 08 §3 now lists DatDepth default = 32, matching RTL (top instantiates 32).
```
```
✅ RESOLVED M4: bus_tx_flow / bus_rx_flow enum width (2026-06-16)
  Fixed: spec 04 `tx_flow_state_e` and spec 05 `rx_state_e` now declare `logic [2:0]` with
    `3'dN` encoding, matching RTL. Note: `tcount_sel_e` in bus_tx (spec 04 §6.5) correctly
    remains `[1:0]` — that's the RTL value.
```
```
✅ RESOLVED M5: error-code taxonomy (2026-06-16)
  Fixed: phase1_spec_v2 §9.4 now carries the full TCRI HCI Table 11 enum (0x0–0xA) with a
    "Generated?" column. Codes actually produced by current_resp_err_status(): 0x0 Success,
    0x4 AddrHeader, 0x5 Nack, 0x6 Ovl, 0x7 I3cShortReadErr, 0x8 HcAborted, 0xA NotSupported.
    0x1 Crc / 0x2 Parity / 0x3 Frame / 0x9 I2cDataNackOrI3cBusAborted are declared but not generated.
  Impact: Ch.4 error-encoding table + Ch.5 resp descriptor can be written directly from phase1 §9.4
    (now == RTL == spec 09 §8).
```
```
❓ TO DISCUSS M14: immediate-write data_byte_idx behavior
  RTL note: dut_i3c_write_immediate_flow.md describes I3CWriteImmediate deriving data_byte_idx
    from transfer_cnt_q → potentially sending 0xAA,0xAA instead of 0xAA,0xBB.
  Status: NOT acted on in this plan. Write Ch.5/Ch.9 from current RTL as-is.
```

### UVM vs verification spec

```
✅ RESOLVED M7: csr_dat_hw_read_selection_vseq now registered (2026-06-16)
  Fixed: i3c_vseq_list.sv now \`include\`s csr_vseqs/csr_dat_hw_read_selection_vseq.sv, so the
    csr_regression SEQ reference resolves and the vseq is factory-registered.
```
```
✅ RESOLVED M8: stale SDRR_REGRESSION_SEQS line removed (2026-06-16)
  Fixed: i3c_read_addr_nack_vseq line deleted from SDRR_REGRESSION_SEQS in src/verification/Makefile.
    addr-NACK coverage lives in resp_vseqs/i3c_addr_header_nack_resp_vseq, run via err_regression.
    New abort/intr vseqs (i3c_write_abort_vseq, i3c_read_abort_vseq, i3c_read_tbit_no_parity_resp_vseq)
    are registered and folded into sdrw/sdrr/err targets.
  Result: `make sdrr_regression` should now elaborate without missing-vseq errors.
```
```
⚠️ MISMATCH M6: vseq inventory in-development (will change)
  Spec claims: specs 00/08 list ~5–8 vseqs (Phase-1 set).
  UVM shows: 55 vseqs across csr(14)/fifo(5)/bus(12)/sdrw(9)/sdrr(9)/resp(4)/ccc(1)/imm(1).
    Verification is still actively under development — the suite is expected to keep growing
    toward the testplan count (~105 test cases). Treat the 55-vseq count as an in-progress
    snapshot, not a final inventory.
  Impact: Ch.7 vseq-library section — enumerate the real suite from disk at time of writing;
    note that additional vseqs covering ENTDAA/CCC/I2C/error scenarios are planned.
  Suggested action: regenerate inventory from disk when writing Ch.7; do NOT copy the stale
    spec 00/08 lists. Add a footnote that the suite is a work-in-progress snapshot.
```
```
⚠️ MISMATCH M9: Makefile far ahead of spec 09
  Spec claims: 09 documents compile/sim/smoke/regression only.
  UVM shows (2026-06-16): csr/fifo/bus/sdrw/sdrr/sdr + err_regression (4 resp vseqs), COV vars,
    FIFO_005 negative-elaboration target. Abort vseqs folded into sdrw/sdrr.
  Policy (2026-06-16): No ccc/daa/i2c/imm Makefile targets will be added for now. CCC vseq
    (i3c_ccc_broadcast_enec_vseq) stays registered but ad-hoc only — run with `make sim SEQ=...`.
    As verification develops, all regression-ready vseqs will be added to the appropriate Makefile
    category target (not left ad-hoc).
  Impact: Ch.7 build/run section — document the 7 active category targets; note CCC exists but
    has not yet been promoted to a regression target (ad-hoc only).
```
```
⚠️ MISMATCH M10: driver phase table
  Spec claims: 04 device table = 10 phases; host mode "retained"; DrvAck uses device_i3c_od_send_bit.
  UVM shows: 13 phases incl. DrvAddrPushPull + DrvWaitStopOrRStart (bcast-header preamble);
    host mode fully removed (device-only); DrvAck calls device_i3c_send_addr_ack.
  Impact: Ch.7 agent/driver section.
  Suggested action: use the 13-phase implementation table; drop host-mode claim.
```
```
⚠️ MISMATCH M11/M13: scoreboard + SVA described as "minimal"
  Spec claims: I3C_Testplan §1 "Minimal" scoreboard; master plan "1 SVA in bus_rx_flow".
  UVM shows: scoreboard checks read+write data, T-bit parity, RX/TX packing, CCC frames, DAT,
    SW-reset flush, resp-priority, end-of-test residue. 5 SVA files: csr/flow_active/top/sync_fifo
    bound via `bind`, tb_pad_model_sva instantiated in tb_i3c_top.sv.
  Impact: Ch.6/Ch.7 strongly understate current capability if specs followed verbatim.
  Suggested action: write these chapters from the code, not the stale "minimal" wording.
```
```
✅ RESOLVED M12: DAT depth — all docs updated to 32
  Was: phase1_spec_v2, I3C_Testplan, entdaa_controller_spec, impl_plan, csr_addr_pkg_spec all said 16.
  Fixed: All planning/spec/test docs updated to DAT_DEPTH=32, matching RTL/UVM ground truth.
```

### Thesis plan vs actual repo

```
⚠️ MISMATCH M15: chapter model (RESOLVED by user → 10-chapter)
  master plan = 10 chapters; supervisor outline PDF = 5-phase work plan (no chapter mandate);
  reference thesis = compact 4 chapters. User chose 10-chapter expanded.
```
```
⚠️ MISMATCH M16: outline tooling vs reality
  Outline PDF §6: ModelSim/Verilator + Quartus + GTKWave.  Repo: Cadence Xcelium + SimVision; FPGA omitted.
  Impact: Ch.6 (methodology) must state actual tools; note deviation from proposal.
  Suggested action: one sentence in Ch.6 explaining the Xcelium/UVM-1.2 choice.
```
```
⚠️ MISMATCH M-plan: master plan stale metadata
  Repo root listed as /Users/minhuy/... (macOS); actual /home/minhuy/Workspaces/i3c.
  Plan dated 2026-05-13 "end of Phase 1"; FPGA now chosen omitted.
  Suggested action: refresh master-plan status block before quoting it in the thesis.
```

---

## SECTION 2 — UPDATED CHAPTER WRITING PLAN (10-chapter model, FPGA omitted)

Every chapter is tagged against the chosen **10-chapter expanded model**. Chapter 8 is **dropped**
(FPGA omitted); chapters keep their original numbers to match `thesis_master_plan.md` references,
with Ch.8 marked OMITTED.

### Chapter 1 — Introduction
1. **Status:** Ready to write.
2. **Primary sources:** outline PDF §1–§4, `improvements.md` (motivation/LoC story), `phase1_spec_v2.md` §1 (scope).
3. **Figures:** F1.1 I3C in an SoC context; F1.2 thesis-organization roadmap.
4. **Tables:** T1.1 contributions list; T1.2 in-scope vs out-of-scope features.
5. **Mismatch warnings:** none blocking.
6. **Priority:** 2.

### Chapter 2 — Theoretical Background
1. **Status:** Ready to write.
2. **Primary sources:** `phase1_spec_v2.md` §7 (timing), MIPI I3C Basic v1.1.1 concepts, UVM 1.2 (use Context7 for UVM/SV refs). `02_bus_monitor_spec`, `03_scl_generator_spec` for bus conditions.
3. **Figures:** F2.1 I2C vs I3C bus; F2.2 OD vs PP phases; F2.3 START/STOP/Sr; F2.4 ENTDAA arbitration; F2.5 UVM testbench layering.
4. **Tables:** T2.1 I3C-vs-I2C comparison matrix; T2.2 I3C SDR + I2C-FM timing parameters.
5. **Mismatch warnings:** none.
6. **Priority:** 3.

### Chapter 3 — System Requirements and Specifications
1. **Status:** Ready to write.
2. **Primary sources:** `phase1_spec_v2.md` §1/§7/§9–10, outline §3–§4, `07_csr_registers_spec.md`.
3. **Figures:** F3.1 simple register-bus interface protocol.
4. **Tables:** T3.1 functional requirements; T3.2 performance targets (12.5 MHz / 400 kHz / ≥333 MHz); T3.3 out-of-scope features.
5. **Mismatch warnings:** none blocking — M5 (error codes) resolved; write error table from phase1 §9.4.
6. **Priority:** 4.

### Chapter 4 — Overall Architecture Design
1. **Status:** Ready to write.
2. **Primary sources:** `11_i3c_controller_top_spec.md`, `10_controller_active_spec.md`, `improvements.md`, `CLAUDE.md` block diagram, `i3c_pkg.sv`/`controller_pkg.sv`.
3. **Figures:** F4.1 three-layer architecture; F4.2 top-level block diagram (mirror CLAUDE.md tree); F4.3 transaction dataflow (Host→CMD FIFO→flow_active→bus→RESP/RX); F4.4 clock/reset.
4. **Tables:** T4.1 CHIPS-Alliance-vs-thesis LoC comparison (from improvements.md); T4.2 FIFO/DAT/descriptor formats; T4.3 error-status encoding (use RTL taxonomy = phase1 §9.4).
5. **Mismatch warnings:** none — M5 resolved.
6. **Priority:** 5.

### Chapter 5 — RTL Design and Implementation  ★ flagship
1. **Status:** Ready to write (code is stable; specs mostly accurate).
2. **Primary sources:** read RTL directly: `flow_active.sv` (full), `scl_generator.sv`, `entdaa_controller.sv`+`entdaa_fsm.sv`, `csr_registers.sv`, `hci_queues.sv`/`sync_fifo.sv`, `bus_tx*.sv`/`bus_rx_flow.sv`, `bus_monitor.sv`, `i3c_phy.sv`, `controller_active.sv`. Cross-ref specs 01–11. `dut_i3c_write_immediate_flow.md` for the worked example.
3. **Figures:** F5.1 flow_active **14-state** FSM diagram; F5.2 scl_generator 14-state FSM; F5.3 entdaa_controller 7-state + entdaa_fsm 8-state; F5.4 bus_tx/bus_rx flow FSMs; F5.5 OD/PP switching logic; F5.6 worked immediate-write phase timeline (from dut_i3c_write_immediate_flow.md).
4. **Tables:** T5.1 flow_active 14-state table; T5.2 full CSR register map (30 regs + DAT, from csr_registers.sv); T5.3 per-module port lists; T5.4 module LoC summary.
5. **Mismatch warnings:** none — M1–M5, M12 all resolved. Only open for Ch.5: note `req_restart_i/ack_o` in scl_generator as future-cleanup (documented in spec 03).
6. **Priority:** 6 (largest chapter; start its FSM diagrams early).

### Chapter 6 — Verification Methodology
1. **Status:** Ready to write.
2. **Primary sources:** `00_uvm_implementation_plan.md`, `03_reg_agent_spec.md`, `04_i3c_agent_spec.md`, `05_i3c_seq_lib_spec.md`, scoreboard source. UVM 1.2 refs via Context7.
3. **Figures:** F6.1 directed-vs-constrained-random rationale; F6.2 layered test stack; F6.3 TLM analysis path (monitor→scoreboard).
4. **Tables:** T6.1 verification goals; T6.2 tool/methodology choices (note Xcelium+UVM 1.2 vs outline's ModelSim — M16).
5. **Mismatch warnings:** ⚠️ M11/M13 (do not call scoreboard/SVA "minimal"), M16 (tooling).
6. **Priority:** 7.

### Chapter 7 — UVM Verification Environment
1. **Status:** Partially writable now; results portion depends on green regressions (M7 resolved; M8 = one stale Makefile SEQ line — see §5 Q3).
2. **Primary sources:** `tb_i3c_top.sv`, `i3c_scoreboard.sv`, `i3c_driver.sv`, `i3c_monitor.sv`, `i3c_base_vseq.sv`, `i3c_vseq_list.sv`, `i3c_csr_addr_pkg.sv`, `Makefile`, all `i3c_vseqs/**`, `sva/**`.
3. **Figures:** F7.1 env class hierarchy; F7.2 register agent; F7.3 I3C agent (device-mode driver+monitor); F7.4 representative write waveform; F7.5 representative read waveform; F7.6 SVA binding map.
4. **Tables:** T7.1 full 55-vseq library by category; T7.2 driver 13-phase table; T7.3 scoreboard check list; T7.4 8 regression targets + SEQ lists (incl. err_regression); T7.5 5 SVA modules + bind/instantiate.
5. **Mismatch warnings:** ⚠️ M6 (count→55), M8 (stale SDRR line), M9 (targets), M10 (driver phases), M11, M13 — all land in this chapter. M7 resolved.
6. **Priority:** 8.

### Chapter 8 — FPGA Implementation  ❌ OMITTED
1. **Status:** Dropped per user decision. Remove from TOC, or keep a one-line note in Ch.10 future work that FPGA validation is left as future work.
2–6. N/A.

### Chapter 9 — Results and Evaluation
1. **Status:** Blocked on green regressions. M8 (stale SDRR Makefile line) is open (deferred to §5 Q3) and will break `sdrr_regression` until trimmed; M7 resolved.
2. **Primary sources:** simulation logs/coverage after `make regression` + category regressions; `improvements.md` LoC metrics.
3. **Figures:** F9.1 per-scenario annotated waveforms (write/read/immediate/CCC); F9.2 coverage screenshot (if COV enabled); F9.3 LoC-reduction bar chart.
4. **Tables:** T9.1 regression pass/fail matrix (55 vseqs); T9.2 reference comparison.
5. **Mismatch warnings:** ⚠️ M8 (trim stale SDRR line so regressions run — §5 Q3).
6. **Priority:** 9 (after sims green).

### Chapter 10 — Conclusion and Future Work
1. **Status:** Ready to write last.
2. **Primary sources:** all chapters; `phase1_spec_v2.md` out-of-scope list; master plan §7.9 Phase-2 roadmap.
3. **Figures:** none required.
4. **Tables:** T10.1 future work (IBI, HDR, target mode, functional coverage, FPGA, ENTDAA/CCC/I2C test gaps).
5. **Mismatch warnings:** none required.
6. **Priority:** 10.

### Appendices (A–I, per master plan; drop FPGA-related ones)
- **Keep:** A register map, B full test-case list (I3C_Testplan 105 cases), C FSM state tables, D Makefile/regression reference, E glossary.
- **Drop/skip:** any FPGA constraints/utilization/timing appendix.
- **Status:** Ready (mechanical, generated from code/docs). **Priority:** interleave with parent chapters.

---

## SECTION 3 — RECOMMENDED WRITING ORDER

Write in this order; the first block has zero dependency on simulation results.

1. **Ch.2 Theory** — fully independent.
2. **Ch.1 Introduction** — independent (refine after Ch.9 numbers exist).
3. **Ch.3 Requirements** — independent (M5 now settled).
4. **Ch.4 Architecture** — independent.
5. **Ch.5 RTL Design** (flagship) — independent of sims; start FSM diagrams (F5.1–F5.4) early as they are the long pole.
6. **Ch.6 Verification Methodology** — independent.
7. **Ch.7 UVM Environment** — write structure now; fill regression results once sims are green.
8. **Ch.9 Results** — **after** `make regression` + category regressions are green.
9. **Ch.10 Conclusion** — last.
10. **Appendices** — interleave; finalize with Ch.9.
- **Ch.8 FPGA — skip.**

Gate: nothing in chapters 1–6 depends on a green sim. Chapters 7 (results portion) and 9 depend on green regressions; M7 and M8 are both resolved — all category regression targets should now elaborate cleanly.

---

## SECTION 4 — IMMEDIATE ACTION ITEMS

> RTL + module specs are ground truth: these items align the stale planning docs to the code.

```
[x] ACTION: Correct "13-state" → "14-state" wording. DONE (2026-06-16) — thesis_master_plan.md
            updated for BOTH flow_active and scl_generator (14 refs incl. "8 of 14" narrative);
            phase1_spec_v2 already fixed. M1 resolved.
    Follow-up (optional): docs/improvements.md still says "13 states" (lines 62/64/69/142) for the
            reference flow_active — update to 14 if quoted in Ch.1/Ch.4.
```
```
[x] ACTION: Align planning-doc DAT depth to RTL/module-spec value (32). DONE — updated
            phase1_spec_v2, I3C_Testplan, I3C_Testplan_by_claude, entdaa_controller_spec,
            csr_addr_pkg_spec, implementation_plan, thesis_master_plan.
    Blocks: resolved. M12.
```
```
[x] ACTION: Align error-code taxonomy in phase1_spec_v2 to the RTL/spec-09 set. DONE (2026-06-16) —
            §9.4 now carries the full TCRI Table 11 (0x0–0xA) with a Generated? column.
    Blocks: resolved. M5.
```
```
[x] ACTION: Trim the stale `i3c_read_addr_nack_vseq` line from SDRR_REGRESSION_SEQS. DONE (2026-06-16)
            Deleted from src/verification/Makefile line 70. M8 resolved.
```
```
[ ] ACTION: Run full regression sweep with Xcelium env sourced; capture logs + (optional) coverage.
            (Source XCELIUM1803.sh first — see memory note; local link may fail on .relr.dyn
            but elaboration/sim validates.)
    Blocks: Chapter 9, Chapter 7 results.   M7+M8 resolved — all category targets should elaborate cleanly.
    Effort: 1–2 h compute.
```
```
[ ] ACTION: Refresh thesis_master_plan.md status block (paths, date, FPGA=omitted) before quoting it.
    Blocks: nothing hard; improves Ch.1/Ch.10 accuracy. M-plan.
    Effort: 15 min.
```

---

## SECTION 5 — OPEN QUESTIONS (TO DISCUSS)

- **Q1 (M9) — DECIDED (2026-06-16):** No `ccc_regression`/`misc_regression` Makefile target will be added. CCC vseq stays ad-hoc (`make sim SEQ=i3c_ccc_broadcast_enec_vseq`). Going forward: all regression-ready vseqs are added to the appropriate Makefile category target; any vseq not yet ready stays ad-hoc until promoted.
- **Q2 (scope):** I3C_Testplan defines **105** test cases but the current suite has ~55 vseqs. Verification is **still under development** — the count is expected to grow toward the testplan number. Ch.7 and Appendix B should present the current suite as a snapshot of the work-in-progress, not a finalized list. No action needed now; re-snapshot inventory from disk when writing Ch.7.
