# Prompt: Generate Thesis Writing Plan with Doc↔Implementation Cross-Check

This prompt is retained for regenerating the current six-chapter plan. The existing
`thesis_writing_plan.md` remains authoritative; generated output must preserve its chapter-ownership rule.

---

## TASK

You are helping write a graduation thesis titled **"Design of an I3C Communication Controller"** for **Vo Minh Huy (22207042)**, supervised by Nguyen Duy Manh Thi at HCMUS.

The project implements a simplified MIPI I3C Basic v1.1.1 Active Controller in SystemVerilog, derived from
the CHIPS Alliance `i3c-core` reference. Do not assume a line-count reduction: recompute both source trees
with a disclosed method. The thesis covers RTL design and UVM 1.2 functional verification; FPGA validation
is omitted and appears only as future work.

Your job is to:

1. **Read every document** listed in the [Documents to Read] section below.
2. **Cross-check each document** against the actual RTL (`src/rtl/`) and UVM (`src/verification/uvm_i3c/`) implementation.
3. **Produce an updated, chapter-by-chapter thesis writing plan** using the structure in [Required Output Format].
4. **Flag every mismatch** you find between a document's claim and the real code with a `⚠️ MISMATCH` marker and a short note. Mark it `[TO DISCUSS]` if it is ambiguous or needs a design decision. Do not silently ignore discrepancies.

---

## DOCUMENTS TO READ

Read these files in order. They are the canonical references for the thesis plan.

### Thesis structure & plan
- `docs/report/thesis_writing_plan.md` — the existing canonical plan (may be stale; treat as a baseline to verify, not ground truth)
- `docs/Vo_Minh_Huy_Graduation_Thesis_Outline.pdf` — supervisor-approved outline (authoritative for chapter order)

### Protocol & architecture specs
- `docs/phase1_spec_v2.md`
- `docs/improvements.md`
- `docs/dut_i3c_write_immediate_flow.md`

### Module specs (docs/module_specs/)
- `01_i3c_phy_spec.md`
- `02_bus_monitor_spec.md`
- `03_scl_generator_spec.md`
- `04_bus_tx_spec.md`
- `05_bus_rx_flow_spec.md`
- `06_hci_queues_spec.md`
- `07_csr_registers_spec.md`
- `08_entdaa_controller_spec.md`
- `08b_entdaa_fsm_spec.md`
- `09_flow_active_spec.md`
- `10_controller_active_spec.md`
- `11_i3c_controller_top_spec.md`

### Verification specs (docs/verification_specs/)
- `00_uvm_implementation_plan.md`
- `03_reg_agent_spec.md`
- `04_i3c_agent_spec.md`
- `05_i3c_seq_lib_spec.md`
- `08_tests_and_vseqs_spec.md`
- `09_build_infrastructure_spec.md`

### Test plan
- `docs/test_plan/I3C_Testplan.md`

---

## RTL FILES TO READ (cross-check source)

Read the following RTL files to verify that module specs match the actual implementation:

```
src/rtl/i3c_pkg.sv
src/rtl/i3c_controller_top.sv
src/rtl/ctrl/controller_pkg.sv
src/rtl/ctrl/controller_active.sv
src/rtl/ctrl/flow_active.sv          ← flagship; read in full
src/rtl/ctrl/scl_generator.sv
src/rtl/ctrl/entdaa_controller.sv
src/rtl/ctrl/entdaa_fsm.sv
src/rtl/ctrl/bus_tx_flow.sv
src/rtl/ctrl/bus_tx.sv
src/rtl/ctrl/bus_rx_flow.sv
src/rtl/ctrl/bus_monitor.sv
src/rtl/csr/csr_registers.sv
src/rtl/hci/hci_queues.sv
src/rtl/hci/sync_fifo.sv
src/rtl/phy/i3c_phy.sv
```

For each module spec, check:
- **Port list** — does the spec match the module's actual `input`/`output` declarations?
- **FSM states** — does the spec list the same states as the `typedef enum` in the RTL? Count them.
- **State transitions** — are the described transitions consistent with the RTL `always_comb`/`case`?
- **Parameters / constants** — do default values match?
- **Any logic described in the spec that does not exist in RTL**, or vice versa.

---

## UVM FILES TO READ (cross-check source)

```
src/verification/uvm_i3c/i3c_core/i3c_scoreboard.sv
src/verification/uvm_i3c/i3c_core/i3c_base_test.sv
src/verification/uvm_i3c/i3c_core/i3c_vseqs/i3c_base_vseq.sv
src/verification/uvm_i3c/i3c_core/i3c_vseqs/i3c_vseq_list.sv
src/verification/uvm_i3c/dv_i3c/i3c_driver.sv
src/verification/uvm_i3c/dv_i3c/i3c_monitor.sv
src/verification/uvm_i3c/dv_inc/i3c_csr_addr_pkg.sv
src/verification/Makefile
```

Also list every `.sv` file found under `src/verification/uvm_i3c/i3c_core/i3c_vseqs/` — the test library may have grown since the specs were written.

For each verification spec, check:
- **Test/vseq list** — does the spec's test inventory match the actual files on disk?
- **Regression targets** — does the Makefile have all targets the spec claims?
- **Scoreboard checks** — does the spec describe checks that are actually implemented?
- **Driver phases** — does the spec's `i3c_drv_phase_e` table match the enum in the driver?
- **CSR addresses** — does `i3c_csr_addr_pkg.sv` match addresses in the CSR spec / RTL?

---

## REQUIRED OUTPUT FORMAT

Produce the plan in the following sections. Use the exact headings.

---

### SECTION 0 — SNAPSHOT SUMMARY

A table of the current implementation state across all modules and vseqs. One row per RTL module / one row per vseq category. Columns:

| Item | Spec Doc | Doc State | RTL/UVM State | Match? | Notes |
|---|---|---|---|---|---|

Use ✅ for match, ⚠️ for mismatch, ❓ for ambiguous/missing.

---

### SECTION 1 — MISMATCHES & DISCUSSION ITEMS

List every discrepancy found. Group by:
- **RTL vs module spec mismatches**
- **UVM vs verification spec mismatches**
- **Thesis plan vs actual repo state mismatches** (e.g., features claimed as "TODO Phase 2" that are now implemented, or vice versa)

For each item use this format:

```
⚠️ MISMATCH [or ❓ TO DISCUSS]: <short title>
  Spec claims: ...
  RTL/UVM shows: ...
  Impact on thesis: ...
  Suggested action: ...
```

---

### SECTION 2 — UPDATED CHAPTER WRITING PLAN

For every chapter (1–6 + Appendices), produce a sub-section with:

1. **Status**: `Ready to write` / `Blocked on: <what>` / `Partially writable`
2. **Primary sources**: exact file paths the writer should read while drafting that chapter
3. **Key figures to produce**: numbered, one line each
4. **Key tables to produce**: numbered, one line each
5. **Mismatch warnings**: any ⚠️ from Section 1 that affects this chapter (by reference)
6. **Suggested writing order priority** (1 = write first)

---

### SECTION 3 — RECOMMENDED WRITING ORDER

A single prioritised list of chapters/appendices, taking into account:
- Which chapters have zero dependency on blocked items (write first)
- Which chapters depend on simulation waveforms (write after `make regression` is green)
- Only Chapter 5 depends on completed simulation evidence; FPGA validation is out of scope

---

### SECTION 4 — IMMEDIATE ACTION ITEMS

A short punch-list of things that must be done BEFORE the relevant chapter can be written. Format:

```
[ ] ACTION: <what to do>
    Blocks: Chapter X
    Effort: <rough estimate>
```

---

### SECTION 5 — OPEN QUESTIONS (TO DISCUSS)

List all `[TO DISCUSS]` items from the cross-check that require a design or scope decision before the thesis can be written accurately. Number them Q1, Q2, … for easy reference.

---

## CROSS-CHECK PRIORITIES

When reading RTL vs docs, pay special attention to:

1. **`flow_active.sv`** — the flagship module. Verify the actual state enum (`flow_fsm_state_e`) against the spec (`09_flow_active_spec.md`). Note: HC abort handling is present (`abort_i` input, `HcAborted` response), but the interrupt-status events explored on the earlier `feat/hc-abort-intr-sdrw-flow` branch (`hc_seq_cancel_event_o`, `hc_err_cmd_seq_timeout_event_o`) and the `INTR_STATUS` CSR have since been removed — a `toc=0` transfer with no available continuation now simply emits STOP and returns a `Success` response.

2. **`scl_generator.sv`** — the spec (`03_scl_generator_spec.md`) describes 13 states. Check if the SDRW flow changes affected the state count or transitions.

3. **`csr_registers.sv`** — the spec (`07_csr_registers_spec.md`) describes the register map. Verify every register address against `i3c_csr_addr_pkg.sv`.

4. **Vseq list** — the verification spec (`08_tests_and_vseqs_spec.md`) and the test plan (`I3C_Testplan.md`) describe which test sequences exist. Compare against actual files on disk under `src/verification/uvm_i3c/i3c_core/i3c_vseqs/`. New files added since the spec was written should be flagged.

5. **Regression targets** — check `src/verification/Makefile` for targets. The plan mentions `make regression`, `make sdrw_regression`, `make sdrr_regression`, etc. Verify each target exists and maps to the described set of tests.

6. **Bug status** — `docs/bug_analysis_report.md` lists 3 CRITICAL bugs (BUG-001/002/003). Check whether any have been fixed in the current RTL by reading the relevant code paths. The thesis validity depends on knowing which bugs are still open.

7. **SVA checkers** — the plan mentions `sva/` directory under `i3c_core/`. Check whether `flow_active_sva.sv`, `csr_registers_sva.sv`, etc. actually exist and are bound in `tb_i3c_top.sv`.

---

## REFERENCE THESIS FORMAT

The supervisor (ThS. Nguyễn Duy Mạnh Thi) has previously accepted a thesis from the same lab with the following structure. Treat this as the **formatting and depth template** — your plan must produce a thesis that follows the same conventions.

**Reference**: *"Thiết kế và kiểm thử bộ nhớ đệm L2 thực hiện MESI protocol trong Coherence model"* — Lê Minh Thông (21200356), HCMUS 2025, same supervisor.

### Front matter observed in reference
- Title page (Vietnamese), cover page with supervisor/committee fields, acknowledgements, declaration of authenticity
- Abstract: **Vietnamese first**, then English — ≈150 words each, concise
- Mục lục (Table of Contents) — chapter + sub-section numbered (e.g. 1.1, 2.1.1)
- Danh mục từ vựng chuyên ngành (Glossary of technical terms) — bilingual table
- Danh sách hình ảnh (List of Figures) with page numbers
- Danh sách bảng (List of Tables) with page numbers

### Chapter structure observed in reference

| Chapter | Vietnamese title | Content pattern |
|---|---|---|
| 1 | Giới thiệu đề tài | Motivation → problem → idea/objective (≈3 pages) |
| 2 | Cơ sở lý thuyết | Background theory for all tech used; UVM section included (≈12 pages) |
| 3 | Thiết kế + kiểm định | Combined RTL design **and** UVM verification in one long chapter (≈40 pages) |
| 4 | Kết luận | Results evaluation (pros/cons) + future work (≈2 pages) |

The reference used **only 4 chapters** and merged design+verification into Chapter 3. `thesis_writing_plan.md` adopts a compact **6-chapter** model in the same spirit — this structural decision is already settled there.

### Chapter 3 breakdown observed in reference (design + verification combined)
- 3.1 Thiết kế phần cứng
  - 3.1.1 Tham số cấu hình
  - 3.1.2 Mở rộng protocol
  - 3.1.3 Thực hiện protocol
  - 3.1.4 Danh sách tín hiệu (port table)
  - 3.1.5 Sơ đồ mạch (block diagram)
  - 3.1.6–3.1.7 Two processor sub-modules (FSM + algorithm per sub-module)
  - 3.1.8 Replacement algorithm
- 3.2 Kiểm định chức năng
  - 3.2.1 Môi trường UVM (diagram + component descriptions)
  - 3.2.2 Dạng sóng tín hiệu (representative waveform)
  - 3.2.3 Kế hoạch kiểm thử (test plan table: valid + invalid scenarios)
  - 3.2.4 Mô phỏng kịch bản hợp lệ (annotated waveform per valid scenario)
  - 3.2.5 Mô phỏng kịch bản không mong muốn (error/edge-case waveforms)
  - 3.2.6 Kết quả và đánh giá (coverage + scoreboard summary)

### Figure and table density observed
- ~49 figures in ≈56 body pages (~0.9 figures/page) — mostly waveforms and FSM diagrams
- ~8 tables — port list, state list, test plan list, coverage list
- Waveform captures were per-scenario, not global — each test scenario got its own waveform screenshot pair (request channel + response channel)
- FSM diagrams were drawn as flowchart-style (not `tikz automata`) — simpler boxes with arrows, labelled transitions

### Writing style observed
- Vietnamese throughout body text; technical terms kept in English inline (e.g. "các Block", "bộ nhớ đệm L2")
- Scoreboard described with a reference-model pattern (SV model mirrors hardware; scoreboard compares outputs)
- Coverage results shown as screenshot from simulator coverage tool (not re-typed tables)
- Section on "kịch bản không mong muốn" (invalid/error scenarios) — explicitly tested, not just noted

---

## CONSTRAINTS

- Do **not** silently skip a discrepancy because it seems minor. Every mismatch, even a typo in a state name, must appear in Section 1 so the thesis writer can decide whether to update the doc or the code.
- Do **not** fabricate information about files you cannot read. If a file is missing, say so.
- Where a spec says something is "Phase 2 / not implemented" but you find the implementation on disk, that is a `⚠️ MISMATCH` — it may mean the plan is outdated.
- Keep the plan actionable: each section should help the writer make a concrete next decision.
- In Section 2 (chapter plan), explicitly flag whether each proposed chapter/section aligns with the reference thesis's 4-chapter compact model or departs from it, and why.
