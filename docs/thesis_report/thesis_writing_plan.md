# Thesis Writing Plan — "Design of an I3C Communication Controller"

**Author:** Vo Minh Huy (22207042) · **Supervisor:** ThS. Nguyễn Duy Mạnh Thi · HCMUS · 10 credits
**Branch:** `feat/sdr-multi-dat-idx-restart-flow` (HEAD `11e29d0`) · **Re-verified against RTL+UVM:** 2026-06-16

## 0. How to use this plan

This is the execution guide for writing the LaTeX thesis. Companion docs:
- `thesis_master_plan.md` — canonical chapter/appendix structure, LaTeX setup, contributions narrative.
- Reference exemplar — `082025 BC KL ... MESI ... Thông Lê.pdf` (formatting/structure model).
- Supervisor outline — `../Vo_Minh_Huy_Graduation_Thesis_Outline.pdf`.

**Ground-truth policy:** the current RTL (`src/rtl/**`) + module specs (`docs/module_specs/**`) and
the current UVM (`src/verification/uvm_i3c/**`) are authoritative. Where `phase1_spec_v2.md`,
`I3C_Testplan.md`, the supervisor outline PDF, or older spec text disagree, **the code wins** and the
planning doc is treated as stale. `bug_analysis_report.md` does not exist in the repo — do not cite it.

**Settled decisions:**
- **10-chapter expanded model** (per master plan), not the compact 4-chapter exemplar shape.
- **FPGA omitted** — Chapter 8 dropped; Results carries no FPGA data; FPGA noted only as future work.
- **Tooling = Cadence Xcelium + UVM 1.2 + SimVision** (supervisor outline §6's ModelSim/Quartus/GTKWave is stale).

---

## 1. Ground-truth facts (cite these verbatim)

| Fact | Value | Source of truth |
|---|---|---|
| `flow_active` FSM | 14 states (Idle…WriteResp) | `src/rtl/ctrl/flow_active.sv` `flow_fsm_state_e` |
| `scl_generator` FSM | 14 states (Idle…BusFree) | `src/rtl/ctrl/scl_generator.sv` `state_e` |
| `entdaa_controller` / `entdaa_fsm` | 7 / 8 states; `DatDepth`=32 | specs 08 / 08b |
| `bus_tx_flow` / `bus_rx_flow` | 4 states `[2:0]` each | specs 04 / 05 |
| `bus_tx` | 5 states | spec 04 |
| CSR map | 30 regs + 32-entry DAT | `csr_registers.sv`, spec 07 |
| Error codes generated | 0x0, 0x4, 0x5, 0x6, 0x7, 0x8, 0xA | `phase1_spec_v2.md` §9.4 |
| Vseq suite | 56: csr14/fifo5/bus12/sdrw9/sdrr10/resp4/ccc1/imm1 | `i3c_vseqs/**` (snapshot) |
| Driver phases | 13 device-only (`i3c_drv_phase_e`) | `dv_i3c/i3c_agent_pkg.sv` |
| SVA | 5 files: 4 bound + `tb_pad_model_sva` instantiated | `i3c_core/sva/**`, `tb_i3c_top.sv` |
| LoC reduction | ~25k → ~2k (~92%) | `improvements.md` |

> The vseq count is a **work-in-progress snapshot** (testplan defines ~105 cases). Re-enumerate from
> disk when writing Ch.7/Appendix B and add a footnote. CCC has 1 vseq, run ad-hoc (`make sim SEQ=…`).

---

## 2. Chapter writing plan (section-level)

Each chapter entry lists: **Sources · Sections · Figures · Tables · Notes**.

### Chapter 1 — Introduction · Priority 2 · Independent

- **Sources:** outline PDF §1–4; `improvements.md`; `phase1_spec_v2.md` §1.
- **Sections:**
  - 1.1 I3C in SoC trends & motivation
  - 1.2 Problem statement & objectives
  - 1.3 Scope and constraints (SDR 12.5 MHz + I2C-FM 400 kHz; no IBI/HDR/multi-master/target)
  - 1.4 Contributions (all 14 `flow_active` states vs 8 left TODO in reference; ~92% LoC cut; dual-agent UVM env; first ENTDAA-capable master in lab)
  - 1.5 Thesis organisation
- **Figures:** F1.1 I3C in an SoC context; F1.2 thesis-organisation roadmap.
- **Tables:** T1.1 contributions; T1.2 in-scope vs out-of-scope.
- **Notes:** refine numbers after Ch.9 exists. Always attribute CHIPS Alliance `i3c-core` (commit SHA).

---

### Chapter 2 — Theoretical Background · Priority 3 · Independent

- **Sources:** `phase1_spec_v2.md` §2–7; MIPI I3C Basic v1.1.1; UVM 1.2 (Context7); specs 02, 03.
- **Sections:**
  - 2.1 I²C recap
  - 2.2 MIPI I3C Basic v1.1.1 (SDR, frame format)
  - 2.3 Bus conditions (START/STOP/Sr)
  - 2.4 Open-drain vs push-pull
  - 2.5 Dynamic address assignment (ENTDAA)
  - 2.6 CCC overview
  - 2.7 I3C-vs-I²C comparison
  - 2.8 UVM 1.2 methodology overview
- **Figures:** F2.1 I²C vs I3C bus; F2.2 OD vs PP phases; F2.3 START/STOP/Sr; F2.4 ENTDAA arbitration; F2.5 UVM testbench layering.
- **Tables:** T2.1 I3C-vs-I²C matrix; T2.2 SDR + I2C-FM timing parameters.

---

### Chapter 3 — System Requirements and Specifications · Priority 4 · Independent

- **Sources:** `phase1_spec_v2.md` §1/§7/§9–10; outline §3–4; spec 07.
- **Sections:**
  - 3.1 Functional requirements
  - 3.2 Out-of-scope features
  - 3.3 Performance targets (12.5 MHz / 400 kHz / ≥333 MHz sys clk)
  - 3.4 SW-visible interface (32-bit register bus)
  - 3.5 Verification requirements
- **Figures:** F3.1 register-bus read/write protocol.
- **Tables:** T3.1 functional requirements; T3.2 performance targets; T3.3 out-of-scope.
- **Notes:** error-code table from `phase1_spec_v2.md` §9.4 (generated set only: 0x0/0x4/0x5/0x6/0x7/0x8/0xA).

---

### Chapter 4 — Overall Architecture Design · Priority 5 · Independent

- **Sources:** specs 11, 10; `improvements.md`; `CLAUDE.md` block diagram; `i3c_pkg.sv`, `controller_pkg.sv`.
- **Sections:**
  - 4.1 Three-layer architecture
  - 4.2 Top module & block diagram
  - 4.3 Transaction dataflow (Host → CMD FIFO → `flow_active` → bus → RESP/RX)
  - 4.4 Clock/reset & signal conventions
  - 4.5 CHIPS-Alliance comparison (~92% LoC reduction)
  - 4.6 FIFO/DAT/descriptor formats
  - 4.7 Error-handling model
- **Figures:** F4.1 three-layer architecture; F4.2 top-level block diagram; F4.3 transaction dataflow; F4.4 clock/reset.
- **Tables:** T4.1 per-subsystem LoC comparison (from `improvements.md`); T4.2 FIFO/DAT/descriptor formats; T4.3 error-status encoding (= `phase1_spec_v2.md` §9.4).

---

### Chapter 5 — RTL Design and Implementation ★ flagship · Priority 6 · Independent

- **Sources:** read RTL directly — `flow_active.sv`, `scl_generator.sv`, `entdaa_controller.sv` + `entdaa_fsm.sv`, `csr_registers.sv`, `hci_queues.sv`/`sync_fifo.sv`, `bus_tx*.sv`/`bus_rx_flow.sv`, `bus_monitor.sv`, `i3c_phy.sv`, `controller_active.sv`, `edge_detector.sv`, `stable_high_detector.sv`. Cross-ref specs 01–11.
- **Sections:**
  - 5.1 PHY (2FF metastability sync + OD/PP output drivers)
  - 5.2 CSR register file + 32-entry DAT
  - 5.3 HCI queues (CMD/TX/RX/RESP sync FIFOs; power-of-2 elaboration assert)
  - 5.4 `bus_monitor` (START/STOP/Sr edge detection)
  - 5.5 SCL generator (14-state FSM; OD-low/bus-free timing ports; DAA restart via `gen_rstart_i`)
  - 5.6 TX/RX serializers (`bus_tx`, `bus_tx_flow`, `bus_rx_flow`)
  - 5.7 ENTDAA subsystem (7-state controller + 8-state FSM; master perspective)
  - 5.8 **`flow_active` 14-state FSM (flagship)** — SDR/I2C write+read+immediate, ENTDAA, abort/intr event ports
  - 5.9 `controller_active` wrapper + OD/PP switching
  - 5.10 Design decisions vs CHIPS Alliance reference
- **Figures:** F5.1 `flow_active` 14-state FSM (full-page rotated); F5.2 `scl_generator` 14-state FSM; F5.3 `entdaa_controller` 7-state + `entdaa_fsm` 8-state; F5.4 `bus_tx`/`bus_rx_flow` FSMs; F5.5 OD/PP switching logic.
- **Tables:** T5.1 `flow_active` 14-state table; T5.2 full CSR map (30 regs + DAT); T5.3 per-module port lists; T5.4 module LoC summary.
- **Notes:** start FSM diagrams early — they are the long pole. §5.5: note `req_restart_i/ack_o` in `scl_generator` as documented future cleanup (RTL folds restart into `gen_rstart_i`).

---

### Chapter 6 — Verification Methodology · Priority 7 · Independent

- **Sources:** verification specs 00, 03, 04, 05; `i3c_scoreboard.sv`; UVM 1.2 (Context7).
- **Sections:**
  - 6.1 Verification goals & Phase split
  - 6.2 Directed-vs-constrained-random rationale
  - 6.3 Why UVM 1.2 + Xcelium (note deviation from outline's ModelSim/Verilator)
  - 6.4 Layered test stack (reg agent + I3C device agent + env + vseqr)
  - 6.5 TLM analysis path & scoreboard strategy (read/write data, T-bit, RX/TX packing, CCC, DAT, SW-reset, resp-priority, end-of-test residue)
  - 6.6 SVA checkers (5 files: 4 bound + `tb_pad_model_sva` instantiated)
  - 6.7 Coverage strategy
  - 6.8 Limitations / Phase-2 gaps
- **Figures:** F6.1 directed-vs-random rationale; F6.2 layered test stack; F6.3 TLM path (monitor → scoreboard).
- **Tables:** T6.1 verification goals; T6.2 tool/methodology choices.
- **Notes:** write scoreboard and SVA descriptions from source (`i3c_scoreboard.sv`, `sva/`) — never use the stale "minimal" label.

---

### Chapter 7 — UVM Verification Environment · Priority 8 · Structure now; results after sims

- **Sources:** `tb_i3c_top.sv`, `i3c_scoreboard.sv`, `i3c_driver.sv`, `i3c_monitor.sv`, `i3c_base_vseq.sv`, `i3c_vseq_list.sv`, `i3c_csr_addr_pkg.sv`, `Makefile`, `i3c_vseqs/**`, `sva/**`; verification specs 06, 07, 08, 09.
- **Sections:**
  - 7.1 TB top & interfaces
  - 7.2 Register agent
  - 7.3 I3C device-mode agent (driver 13 phases + monitor)
  - 7.4 Env / vseqr / scoreboard class hierarchy
  - 7.5 Vseq library (56 vseqs by category; CCC ad-hoc only)
  - 7.6 Build/run flow (8 category regression targets + `coverage` COV=1 + `fifo_non_power_of_two_elaboration` FIFO_005)
  - 7.7 Waveform & debug (SimVision)
  - 7.8 Regression results *(fill after sims green)*
  - 7.9 Phase-2 roadmap
- **Figures:** F7.1 env class hierarchy; F7.2 register agent; F7.3 I3C agent (device-mode driver + monitor); F7.4 representative write waveform; F7.5 representative read waveform; F7.6 SVA binding map.
- **Tables:** T7.1 56-vseq library by category; T7.2 driver 13-phase table (`DrvIdle`…`DrvDAA`); T7.3 scoreboard check list; T7.4 8 regression targets + SEQ lists; T7.5 5 SVA modules (bind vs instantiate).
- **Notes:** re-enumerate vseqs from disk at write time; add footnote that the 56-vseq suite is a WIP snapshot (~105 target). CCC vseq exists but is ad-hoc only (`make sim SEQ=i3c_ccc_broadcast_enec_vseq`).

---

### Chapter 8 — FPGA Implementation ❌ OMITTED

Dropped per user decision. Remove from TOC. Keep one line in Ch.10.3 future work: "FPGA validation on [board] is left as future work."

---

### Chapter 9 — Results and Evaluation · Priority 9 · After green regressions

- **Sources:** sim logs/coverage from `make regression` + category regressions; `improvements.md`.
- **Sections:**
  - 9.1 Effort metrics (LoC, ≈2k vs 25k reference)
  - 9.2 Phase-1 regression results (pass/fail matrix)
  - 9.3 Waveform evidence (write / read / immediate / CCC)
  - 9.4 Functional coverage (if `COV=1` run available)
  - 9.5 Comparison with CHIPS Alliance reference
  - 9.6 Unimplemented-feature discussion
- **Figures:** F9.1 annotated waveforms (write + read); F9.2 coverage screenshot; F9.3 LoC-reduction bar chart.
- **Tables:** T9.1 regression pass/fail matrix (56 vseqs); T9.2 reference comparison.

---

### Chapter 10 — Conclusion and Future Work · Priority 10 · Last

- **Sources:** all chapters; `phase1_spec_v2.md` out-of-scope list; master plan §7.9 Phase-2 roadmap.
- **Sections:**
  - 10.1 Summary of contributions
  - 10.2 Lessons learned
  - 10.3 Future work (IBI, HDR, target mode, multi-device, functional coverage, FPGA validation, ENTDAA/CCC/I2C test gaps)
- **Tables:** T10.1 future-work roadmap (from master plan §7.9).

---

### Appendices (per master plan; FPGA appendix dropped)

| App | Title | Source | Notes |
|---|---|---|---|
| A | CSR register map (full bitfield tables) | `csr_registers.sv`, spec 07 | Mechanical |
| B | Command / Response / DAT descriptor formats | `i3c_pkg.sv`, `controller_pkg.sv` | Mechanical |
| C | Complete FSM state tables (all RTL FSMs) | specs 03–09 | Mechanical |
| D | CCC subset opcode/frame table | `phase1_spec_v2.md` §4 | 5 entries |
| E | Regression log excerpts | sim logs | After sims green |
| F | ~~Synthesis/utilisation/timing~~ | — | **DROP** (FPGA omitted) |
| G | Build & run instructions (Makefile reference) | `src/verification/Makefile` | Mechanical |
| H | Glossary & abbreviations | — | Mechanical |
| I | Bibliography | `references.bib` | IEEEtran |

Interleave appendices with parent chapters as each becomes final.

---

## 3. Recommended writing order

Chapters 1–6 have **zero dependency** on simulation results:

1. Ch.2 Theory — fully independent
2. Ch.1 Introduction — independent (refine figures/numbers after Ch.9)
3. Ch.3 Requirements — independent
4. Ch.4 Architecture — independent
5. **Ch.5 RTL Design** (flagship) — independent of sims; **start FSM diagrams (F5.1–F5.4) first** — they are the long pole
6. Ch.6 Verification Methodology — independent
7. Ch.7 UVM Environment — write structure now; fill §7.8 results once regressions are green
8. **Ch.9 Results** — after `make regression` + category regressions pass
9. Ch.10 Conclusion — last
10. Appendices — interleave; finalize with Ch.9

**Ch.8 FPGA — skip.**

Gate: only Ch.7 §7.8 and Ch.9 depend on green regressions. All other chapters can be written now.

---

## 4. LaTeX conventions (from `thesis_master_plan.md` §12)

- **Document class:** `\documentclass[12pt,a4paper,oneside]{report}` (or HCMUS-mandated template). Master file `report.tex` with subdirs `chapters/`, `appendices/`, `figures/`, `listings/`, `references.bib`.
- **Required packages:** `inputenc` (utf8), `babel`, `geometry`, `graphicx`, `caption`, `subcaption`, `booktabs`, `xcolor`, `hyperref`, `cleveref`, `tikz` (+ `automata`, `arrows.meta`, `positioning`, `shapes`, `chains`), `listings`/`minted`, `siunitx`, `glossaries`, `longtable`, `pdflscape`, `pdfpages`.
- **FSM figures:** TikZ `automata` library. Flagship `flow_active` 14-state diagram → full-page `\begin{figure}[!p]` rotated with `pdflscape`. All other FSMs at `width=0.95\textwidth`. Target ~30 figures, ~23 tables.
- **Code listings:** custom `listings` style `sv` (SystemVerilog 2017, `\footnotesize`, line numbers, single frame). Snippets ≤30 lines only — no full file dumps. Prefer state tables + FSM diagrams + pseudocode.
- **Citations:** BibTeX `IEEEtran` style. Mandatory references: MIPI I3C Basic v1.1.1 (Errata 01, 2022), Accellera UVM 1.2 Reference, CHIPS Alliance `i3c-core` (with commit SHA), OpenTitan `dv_macros.svh`.
- **Waveforms:** export SimVision as vector PDF or 300 dpi PNG, cropped to ≤5 µs window, annotated with TikZ overlay arrows.
- **Attribution:** always credit CHIPS Alliance `i3c-core` in captions/footnotes wherever simplified RTL is shown (license + README requirement).

---

## 5. Figure asset plan (priority set)

The thesis figures will be authored as **source files** under a new `figures/` tree (rendered later
when the LaTeX build is set up — no renderer installed yet). **Hybrid toolchain:**

- **Bus-format / timing diagrams → WaveDrom** (datasheet-style waveforms, the MIPI-spec look; JSON
  source → SVG/PDF via `wavedrom-cli` or the VS Code / online editor).
- **FSM & state diagrams → TikZ `automata`** (compiles natively into the thesis; each a `standalone`
  `.tex` that also `\input{}`s directly; flagship `flow_active` is landscape per §4).

Proposed layout: `figures/fsm/*.tex` (TikZ) and `figures/bus/*.json` (WaveDrom) + `figures/README.md`
(render commands + this F-number map). State/edge data comes from the named RTL; frame/bit data from
`phase1_spec_v2.md`. First pass = ~13 figures below; block/UVM/waveform-screenshot figures deferred.

### FSM diagrams (TikZ) — source of truth = RTL enums

| File | Thesis fig | What it shows | RTL source |
|---|---|---|---|
| `fsm/flow_active_fsm.tex` | F5.1 (flagship, landscape) | 14-state command FSM (Idle…WriteResp); happy-path edges + abort→WriteResp override | `ctrl/flow_active.sv` |
| `fsm/scl_generator_fsm.tex` | F5.2 | 14-state SCL/START/STOP/Sr generator (Idle…BusFree) | `ctrl/scl_generator.sv` |
| `fsm/entdaa_controller_fsm.tex` | F5.3a | 7-state ENTDAA loop manager; `bus_stop_det_i`→Done | `ctrl/entdaa_controller.sv` |
| `fsm/entdaa_fsm.tex` | F5.3b | 8-state per-device DAA arbitration; `bus_stop_det_i`→NoDev | `ctrl/entdaa_fsm.sv` |
| `fsm/bus_tx_fsm.tex` | F5.4a | 5-state TX bit engine (Idle…HoldData) | `ctrl/bus_tx.sv` |
| `fsm/bus_tx_flow_fsm.tex` | F5.4b | 4-state TX byte/bit serializer | `ctrl/bus_tx_flow.sv` |
| `fsm/bus_rx_flow_fsm.tex` | F5.4c | 4-state RX deserializer | `ctrl/bus_rx_flow.sv` |

### Bus-format diagrams (WaveDrom) — source of truth = `phase1_spec_v2.md`

| File | Thesis fig | What it shows |
|---|---|---|
| `bus/bus_conditions.json` | F2.3 | START / repeated-START / STOP (SDA edge while SCL high) |
| `bus/od_vs_pp.json` | F2.2 | Open-drain (addr/ACK) vs push-pull (data); OD→PP boundary; `sel_od_pp` |
| `bus/address_byte.json` | (Ch.2) | 9-bit address byte: A6..A0 + RnW + ACK (MSB first) |
| `bus/sdr_write_frame.json` | (Ch.2/5) | SDR private write: S · addr+W · ACK · {data+T}×N · P (T = odd parity) |
| `bus/sdr_read_frame.json` | (Ch.2/5) | SDR private read: S · addr+R · ACK · {data,T=1}… {data,T=0} · P |
| `bus/entdaa_arbitration.json` | F2.4 | ENTDAA: 7E+W·ACK·CCC·Sr·7E+R · 64-bit PID+BCR+DCR · dyn-addr+parity · ACK |
| `bus/ccc_frame.json` | (Ch.2) | Broadcast + direct CCC frame format |

> These cover the per-chapter **Figures** lines above for F2.2/F2.3/F2.4 and F5.1–F5.4. Remaining
> figures (block diagrams F4.x, UVM env F7.x, SimVision waveforms, LoC chart F9.3) are a later pass.

---

## 6. Remaining action items

- [ ] **Run full regression sweep** — source `XCELIUM1803.sh` first (local `.relr.dyn` link may fail but elaboration/sim still validates). Capture logs + optional `COV=1` coverage run.
  *Blocks:* Ch.7 §7.8, Ch.9. *Effort:* 1–2 h compute.

- [ ] **Re-enumerate vseq inventory from disk** when writing Ch.7 / Appendix B. The 56-vseq count is a snapshot; the suite will grow toward the ~105-case testplan.

- [ ] *(out of scope, optional)* `CLAUDE.md` line `docs/bug_analysis_report.md` references a file that does not exist in the repo — remove or correct that line to avoid confusion.
