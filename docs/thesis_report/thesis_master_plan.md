# Master Plan — LaTeX Graduation Thesis: "Design of an I3C Communication Controller"

**Author**: Vo Minh Huy (22207042) · **Supervisor**: Nguyen Duy Manh Thi · HCMUS · 10 credits
**Prepared**: 2026-05-13 (Phase 3, UVM verification window)
**Repository**: `/Users/minhuy/Workspaces/i3c`

---

## Context

This document is the consolidated *master plan* for writing the LaTeX graduation report describing the MIPI I3C Basic v1.1.1 Master Controller in this repository. It is based on a direct, evidence-based survey of:

- `docs/` — all specs, module specs, verification specs, bug analysis, improvements
- `src/rtl/` — 18 SystemVerilog files, 4,072 lines total
- `src/verification/uvm_i3c/` — dual-agent UVM 1.2 environment (Phase 1 complete)
- `src/verification/Makefile`, `filelist.f`, `xrun.args` — Xcelium build flow
- `docs/Vo_Minh_Huy_Graduation_Thesis_Outline.pdf` — supervisor-approved outline

The thesis demonstrates the complete frontend digital IC design pipeline (RTL → UVM → optional FPGA) by taking the ~25 K-line CHIPS Alliance `i3c-core` reference, simplifying it to ~2 K lines (~92% reduction), and completing the 8 of 13 `flow_active` FSM states the reference left as TODO. Today's status is *end of Phase 1*: smoke/write/read vseqs pass; ENTDAA/CCC/error-inject/coverage deferred to Phase 2; FPGA validation not yet started (outline §7 tags it optional, Phase 4: 08/06–28/06/2026).

---

# 1. PROJECT SCOPE SUMMARY

## 1.1 Project objective

Design, RTL-implement, and UVM-verify a single-master MIPI I3C Basic v1.1.1 Controller, derived by aggressive simplification from `chipsalliance/i3c-core`. Optional FPGA prototyping closes the loop.
Sources: `docs/Vo_Minh_Huy_Graduation_Thesis_Outline.pdf` §3, `README.md`.

## 1.2 Implemented protocol features (evidence in `src/rtl/`)

| Feature | Evidence |
|---|---|
| SDR mode push-pull data, ≤12.5 MHz SCL | `scl_generator.sv` (13-state), `bus_tx.sv`, OD/PP mux in `controller_active.sv` |
| I2C Fast Mode 400 kHz (legacy) | `flow_active.sv` `InitI2CWrite`/`InitI2CRead` paths; `dat_entry_t.device` flag |
| START / Sr / STOP / Bus Idle | `bus_monitor.sv`, `scl_generator.sv` `GenerateStart`/`GenerateRstart`/`GenerateStop` |
| Private I3C Write (0x7E+W → Sr → dyn-addr+W → N bytes + T-bit) | `flow_active.sv` `IssueCmd` Write path |
| Private I3C Read (dyn-addr+R → N bytes + T-bit) | `flow_active.sv` `IssueCmd` Read path |
| Immediate Data Transfer (≤4 inline bytes in CMD descriptor) | `flow_active.sv` `I3CWriteImmediate` / `I2CWriteImmediate` |
| ENTDAA multi-device DAA loop | `entdaa_controller.sv` (7-state) + `entdaa_fsm.sv` (8-state) |
| CCC: ENTDAA (0x07), ENEC/DISEC broadcast & direct (5 frame variants) | `flow_active.sv`, `i3c_pkg.sv` |
| 16-entry DAT; 12-bit/32-bit reg bus; 4×64-deep FIFOs (CMD64, TX/RX/RESP 32) | `csr_register.sv`, `hci_queues.sv`, `sync_fifo.sv` |
| Single-clock domain, ≥333 MHz target (meets tSCO=12 ns) | `CLAUDE.md`, `i3c_phy.sv` 2-FF sync |

## 1.3 Out of scope (deliberately)

IBI, Hot-Join, HDR (DDR/TSL/TSP), I2C FM+ (1 MHz), multi-master, Target (slave) mode, bus recovery, DCT, clock stretching, all CCCs outside ENEC/DISEC/ENTDAA, full HCI compliance.
Sources: `docs/phase1_spec_v2.md`, `docs/i3c_scope_analysis.md`, `README.md`.

## 1.4 Verification scope

| Element | Status |
|---|---|
| Dual-agent UVM env (reg + i3c-Device), virtual sequencer, base test | **Implemented** |
| `i3c_smoke_vseq`, `i3c_write_vseq`, `i3c_read_vseq` | **Implemented** |
| Scoreboard: CMD/TX/RESP correlation, addr/dir/byte/err-status checks | **Implemented (basic)** |
| ENTDAA, CCC, multi-device, error-injection, I2C legacy tests | **Phase 2 — not implemented** |
| Functional coverage (covergroups) | **Phase 2 — not implemented** |
| TB SVA | **None** (one SVA inside RTL `bus_rx_flow.sv`) |
| Host-mode `i3c_driver` | Enum declared; Device-only implemented |
| Monitor calls `wait_for_device_ack_or_nack` not defined in `i3c_if.sv` | Pre-Phase-2 fix required |

Source: `docs/verification_specs/00_uvm_implementation_plan.md`, `src/verification/uvm_i3c/`.

## 1.5 FPGA validation scope

**Not started.** Zero FPGA artefacts in the repository (no `.xdc`/`.sdc`/`.tcl`/`.qsf`, no `fpga/`/`syn/` directories, no top wrapper, no constraints). Outline §4 labels it "optional". The supervisor-approved timeline allocates Phase 4 (08/06–28/06/2026) for it.

---

# 2. OVERALL REPOSITORY STRUCTURE

## 2.1 Directory tree (HEAD `906c1a2`)

```
i3c/
├── CLAUDE.md, README.md, LICENSE, .gitignore
├── docs/
│   ├── phase1_spec_v2.md              ← authoritative protocol / architecture spec
│   ├── i3c_scope_analysis.md          ← 10-section feature scope matrix
│   ├── improvements.md                ← 92% LoC-reduction analysis vs reference
│   ├── implementation_plan.md         ← phase plan with ADAPT/REUSE/NEW module tags
│   ├── architecture_qa_session.md     ← Q&A on CSR ↔ FIFO ↔ ctrl data flow
│   ├── bug_analysis_report.md         ← 22 bugs: 3 CRITICAL, 8 HIGH, 7 MED, 4 LOW
│   ├── mipi_i3c_spec.pdf              ← primary protocol reference
│   ├── Vo_Minh_Huy_Graduation_Thesis_Outline.pdf
│   ├── module_specs/   01–11_*.md     ← per-RTL-module specs (ports, FSMs, LoC)
│   ├── verification_specs/ 00–09_*.md ← per-UVM-component specs
│   └── thesis_report/                 ← THIS folder (thesis output artefacts)
└── src/
    ├── rtl/
    │   ├── i3c_pkg.sv, i3c_controller_top.sv, scl_generator.sv
    │   ├── phy/i3c_phy.sv
    │   ├── ctrl/  controller_pkg.sv, controller_active.sv, flow_active.sv,
    │   │          entdaa_controller.sv, entdaa_fsm.sv, bus_tx_flow.sv, bus_tx.sv,
    │   │          bus_rx_flow.sv, bus_monitor.sv, edge_detector.sv,
    │   │          stable_high_detector.sv
    │   ├── csr/csr_register.sv
    │   └── hci/hci_queues.sv, sync_fifo.sv
    └── verification/
        ├── Makefile
        └── uvm_i3c/
            ├── filelist.f, xrun.args
            ├── dv_inc/    dv_macros.svh, i3c_csr_addr_pkg.sv
            ├── dv_reg/    reg_{if,seq_item,driver,monitor,sequencer,agent,agent_cfg,agent_pkg}.sv
            ├── dv_i3c/    i3c_{if,timing_pkg,agent_pkg,item,seq_item,driver,monitor,
            │              sequencer,agent,agent_cfg}.sv + seq_lib/
            └── i3c_core/  tb_i3c_top.sv, i3c_{env,env_cfg,env_pkg,scoreboard,
                           virtual_sequencer,base_test,test_pkg}.sv + i3c_vseqs/
```

## 2.2 Folder roles and thesis chapters fed

| Folder | Role | Feeds |
|---|---|---|
| `src/rtl/phy/` | 2-FF synchronizer + OD/PP pass-through | Chap. 5 (PHY) |
| `src/rtl/ctrl/` | Protocol engine: FSMs, DAA, TX/RX, bus monitor | Chap. 5, Chap. 4 |
| `src/rtl/csr/` | Hand-written register file + DAT | Chap. 5, Appendix A |
| `src/rtl/hci/` | Generic FIFO + 4-instance wrapper | Chap. 5 |
| `docs/module_specs/` | Per-module specs — directly quotable | Chap. 4, Chap. 5 |
| `docs/verification_specs/` | UVM plan — directly quotable | Chap. 6, Chap. 7 |
| `src/verification/uvm_i3c/` | Live UVM testbench | Chap. 7 |
| (none yet) | FPGA wrapper, constraints, scripts | Chap. 8 — *to be created* |

## 2.3 Key diagrams to produce for the opening pages

1. **Engineering pipeline** (Theory → RTL → UVM → FPGA → Thesis) — Chap. 1.
2. **Three-layer architecture overview** (PHY · controller_active · CSR + HCI) — Chap. 4.
3. **Repository organisation** (folder-level box diagram) — Chap. 1 or Chap. 4.

---

# 3. PROPOSED THESIS OUTLINE

Structure extends the supervisor-approved outline (PDF §5) with sub-sections grounded in the repo.

```
Front matter
  • Title page · Acknowledgements · Abstract (VN + EN) · TOC · List of Figures
  • List of Tables · List of Abbreviations · List of Listings

Chapter 1 — Introduction
  1.1  Motivation: I3C in modern SoC / embedded systems
  1.2  Problem statement and thesis objectives
  1.3  Scope and constraints
  1.4  Contributions of this thesis
  1.5  Thesis organisation

Chapter 2 — Theoretical Background
  2.1  I²C protocol recap (electrical, framing, ACK/NACK)
  2.2  MIPI I3C Basic v1.1.1 overview
  2.3  Bus conditions: START / Sr / STOP / Bus Available
  2.4  Open-Drain vs Push-Pull and the OD↔PP transition
  2.5  Dynamic Address Assignment (ENTDAA)
  2.6  Common Command Codes (CCC): broadcast vs direct
  2.7  I3C vs I²C feature matrix comparison
  2.8  UVM 1.2 methodology overview

Chapter 3 — System Requirements and Specifications
  3.1  Functional requirements (in-scope feature list)
  3.2  Out-of-scope features and rationale
  3.3  Performance targets (12.5 MHz / 400 kHz / ≥333 MHz fSYS)
  3.4  Software-visible interface requirements
  3.5  Verification requirements (Phase 1 closure criteria)
  3.6  FPGA-prototype requirements (optional)

Chapter 4 — Overall Architecture Design
  4.1  Three-layer architecture and design philosophy
  4.2  Comparison with CHIPS Alliance reference (92% LoC reduction)
  4.3  Top-level module: i3c_controller_top
  4.4  Data flow: CSR write → bus transaction → RESP
  4.5  Clock and reset strategy
  4.6  Interface conventions
  4.7  FIFO descriptor formats (CMD64, TX/RX/RESP 32)
  4.8  DAT entry format and lookup flow
  4.9  Error handling and response-descriptor encoding

Chapter 5 — RTL Design and Implementation
  5.1  PHY layer (i3c_phy: 2-FF sync + OD/PP output strategy)
  5.2  Register interface and command staging (csr_register)
  5.3  HCI queue subsystem (sync_fifo + hci_queues)
  5.4  Bus monitor and signal-edge detection
        (bus_monitor + edge_detector + stable_high_detector)
  5.5  Bus serializers
        (bus_tx_flow 4-state + bus_tx 5-state + bus_rx_flow 4-state)
  5.6  SCL generator (scl_generator — 13-state, single-counter strategy)
  5.7  ENTDAA subsystem
        (entdaa_controller 7-state + entdaa_fsm 8-state)
  5.8  Main protocol FSM: flow_active (13-state — flagship RTL contribution)
        5.8.1  State architecture and the five issue-phase counters
        5.8.2  Six branch decisions out of FetchDAT
        5.8.3  I3CWriteImmediate sub-cases A/B/C
        5.8.4  Regular Transfer Write path
        5.8.5  Regular Transfer Read path
        5.8.6  AddressAssignment path (ENTDAA invocation)
        5.8.7  Error consolidation and WriteResp formatting
  5.9  controller_active integration and flow/DAA arbitration
  5.10 Design decisions vs reference design

Chapter 6 — Verification Methodology
  6.1  Verification goals and Phase 1/2 split
  6.2  Directed vs constrained-random: Phase 1 rationale
  6.3  Why UVM 1.2 (CDNS-1.2) + Xcelium
  6.4  Layered test stack: test → vseq → reg/i3c sequences → DUT
  6.5  TLM analysis paths and scoreboard architecture
  6.6  Coverage strategy (Phase 1 deferred; Phase 2 blueprint)
  6.7  Bug discovery and fix loop (from bug_analysis_report.md)
  6.8  Limitations of current scope

Chapter 7 — UVM Verification Environment
  7.1  Testbench top (tb_i3c_top): clock/reset/vif wiring
  7.2  Register agent (dv_reg/)
  7.3  I3C agent (dv_i3c/) — Device-mode responder
        (i3c_if · i3c_driver 9-phase FSM · i3c_monitor CCC-aware)
  7.4  Environment, virtual sequencer, scoreboard (i3c_core/)
  7.5  Virtual sequence library (i3c_vseqs/)
  7.6  Build and run flow (Makefile · filelist.f · xrun.args)
  7.7  Waveform and debug methodology (SimVision SHM)
  7.8  Regression results (smoke / write / read)
  7.9  Phase-2 roadmap and known gaps

Chapter 8 — FPGA Implementation and Hardware Validation [OPTIONAL]
  8.1  Target board and toolchain (Quartus per outline)
  8.2  FPGA top-wrapper: IOBUF from sel_od_pp_o
  8.3  Clocking constraints (≥333 MHz core, SCL pad timing)
  8.4  Resource utilisation and timing-closure report
  8.5  Bring-up bench (UART-bridge MCU or ILA)
  8.6  Logic-analyser captures (START / SDR write / ENTDAA)
  8.7  Simulation-vs-hardware comparison
  8.8  Pass/fail criteria and observed limitations

Chapter 9 — Results and Evaluation
  9.1  Engineering effort metrics (LoC, modules, reuse vs new)
  9.2  Phase-1 regression pass/fail summary
  9.3  Waveform evidence of canonical transactions
  9.4  Bug-discovery yield from UVM
  9.5  FPGA utilisation/timing results (or synthesis-only estimate)
  9.6  Comparison with CHIPS Alliance reference
  9.7  Discussion of unimplemented features

Chapter 10 — Conclusion and Future Work
  10.1 Summary of contributions
  10.2 Lessons learned
  10.3 Future work (bug fixes, Phase 2 verification, IBI, HDR, Target mode)
  10.4 Closing remarks

Appendices
  A.  CSR register map (full bitfield tables)
  B.  Command / Response / DAT descriptor formats
  C.  Complete FSM state tables (all 7 RTL FSMs)
  D.  CCC subset opcode and frame table (5 entries)
  E.  Regression log excerpts
  F.  Synthesis / utilisation / timing reports (if FPGA)
  G.  Build and run instructions (Makefile reference)
  H.  Glossary and abbreviations
  I.  Bibliography
```

---

# 4. DETAILED BREAKDOWN OF EACH CHAPTER

## Chapter 1 — Introduction

**Purpose**: Frame the thesis, justify the topic, declare scope, preview structure.

**Content**: I3C in SoC trends; I²C limitations; MIPI I3C backward-compatibility imperative; why a simplified Master controller is a meaningful frontend-design exercise; objectives from outline §3; scope table; chapter map.

**Repo references**: `docs/Vo_Minh_Huy_Graduation_Thesis_Outline.pdf`, `README.md`, `docs/phase1_spec_v2.md` §1.

**Figures**: engineering pipeline diagram (Theory → RTL → UVM → FPGA → Report).

**Tables**: objectives ↔ chapters; in-scope vs out-of-scope summary.

**Notes**: keep under 8 pages; defer architectural detail to Chap. 4.

---

## Chapter 2 — Theoretical Background

**Purpose**: Protocol and methodology grounding so Chaps. 4–7 do not re-explain basics.

**Content**: I²C basics (open-drain, START/STOP, ACK/NACK); I3C electrical changes (LV-CMOS PP, 1.8 V); SDR frames; T-bit semantics (parity in write, end-of-data in read); ENTDAA algorithm; CCC categories and frame shapes (broadcast vs direct); UVM 1.2 component model (test → env → agent {driver/monitor/sequencer} → sequence; TLM; `uvm_config_db`).

**Repo references**: `docs/phase1_spec_v2.md` §§2–6, `docs/mipi_i3c_spec.pdf` (primary citations), `docs/verification_specs/00_uvm_implementation_plan.md` §1.

**Figures**: I²C vs I3C frame comparison; ENTDAA timing skeleton; UVM component stack diagram.

**Tables**: I²C vs I3C feature matrix (speed, electrical, IBI, addressing, CCCs, etc.).

**Notes**: Easiest chapter to write first — no RTL dependency. Use `docs/mipi_i3c_spec.pdf` + `phase1_spec_v2.md` as primary sources.

---

## Chapter 3 — System Requirements and Specifications

**Purpose**: Concrete, testable spec that Chaps. 4–5 satisfy and Chaps. 6–7 verify.

**Content**: in/out feature list with rationale; performance budget (≥333 MHz sysclk → 4-cycle CSR counts → 12.5 MHz SCL via T_LOW=T_HIGH=13 defaults); CSR-interface contract (12-bit addr, 32-bit data, single-cycle ready); FIFO depths; DAT depth; reset behaviour; error codes.

**Repo references**: `docs/phase1_spec_v2.md` §§7–10, `docs/i3c_scope_analysis.md` (10-section scope matrix), `docs/improvements.md` §1 (333 MHz rationale).

**Figures**: CSR transaction timing diagram; FIFO/DAT depth sizing diagram.

**Tables**: full feature support matrix; timing-CSR default-value table; Phase-1 pass/fail criteria.

---

## Chapter 4 — Overall Architecture Design

**Purpose**: System-level mental model before §5's module-level detail.

**Content**: three-layer model; module-hierarchy tree; `i3c_controller_top` port groups; data-flow narrative for a write and a read; design decisions vs CHIPS Alliance (the 92% reduction story); clock/reset; signal conventions.

**Repo references**: `src/rtl/i3c_controller_top.sv`, `docs/module_specs/11_i3c_controller_top_spec.md`, `docs/improvements.md`, `docs/architecture_qa_session.md`.

**Figures** (critical):
1. Three-level hierarchy block diagram (top → 4 children → 8 grandchildren).
2. Data-flow diagram for a write transaction (SW → CSR → CMD FIFO → flow_active → bus_tx_flow → bus_tx → PHY).
3. Data-flow diagram for a read transaction.
4. Clock/reset-domain diagram showing 2-FF sync.

**Tables**: top-level port table; LoC-reduction comparison (from `improvements.md`).

**Notes**: Stay at block-diagram resolution — all sub-module detail lives in Chap. 5.

---

## Chapter 5 — RTL Design and Implementation

**Purpose**: For each major module, give purpose, interface, FSM, and design rationale.

**Content**: per-module write-up using this template — *purpose / interface / FSM or datapath / key implementation choice / verification touch-points*.

**Module-to-file mapping**:

| Section | Source file | Spec doc | LoC |
|---|---|---|---|
| 5.1 i3c_phy | `src/rtl/phy/i3c_phy.sv` | `docs/module_specs/01_i3c_phy_spec.md` | 52 |
| 5.2 csr_register | `src/rtl/csr/csr_register.sv` | `docs/module_specs/07_csr_registers_spec.md` | 266 |
| 5.3.1 sync_fifo | `src/rtl/hci/sync_fifo.sv` | inside `06_hci_queues_spec.md` | 84 |
| 5.3.2 hci_queues | `src/rtl/hci/hci_queues.sv` | `docs/module_specs/06_hci_queues_spec.md` | 142 |
| 5.4 bus_monitor | `src/rtl/ctrl/bus_monitor.sv` | `docs/module_specs/02_bus_monitor_spec.md` | 227 |
| 5.4 edge_detector + stable_high_detector | `src/rtl/ctrl/*.sv` | inside `02_*` | 39 + 44 |
| 5.5 bus_tx_flow | `src/rtl/ctrl/bus_tx_flow.sv` | `docs/module_specs/04_bus_tx_spec.md` | 193 |
| 5.5 bus_tx | `src/rtl/ctrl/bus_tx.sv` | `docs/module_specs/04_bus_tx_spec.md` | 185 |
| 5.5 bus_rx_flow | `src/rtl/ctrl/bus_rx_flow.sv` | `docs/module_specs/05_bus_rx_flow_spec.md` | 166 |
| 5.6 scl_generator | `src/rtl/scl_generator.sv` | `docs/module_specs/03_scl_generator_spec.md` | 257 |
| 5.7 entdaa_controller | `src/rtl/ctrl/entdaa_controller.sv` | `docs/module_specs/08_ccc_processor_spec.md` | 241 |
| 5.7 entdaa_fsm | `src/rtl/ctrl/entdaa_fsm.sv` | `docs/module_specs/08_ccc_processor_spec.md` | 234 |
| 5.8 flow_active | `src/rtl/ctrl/flow_active.sv` | `docs/module_specs/09_flow_active_spec.md` | 1166 |
| 5.9 controller_active | `src/rtl/ctrl/controller_active.sv` | `docs/module_specs/10_controller_active_spec.md` | 323 |

**Figures** (critical — one FSM bubble chart per FSM):
- `flow_active` 13-state — **flagship figure, span a full landscape page**
- `scl_generator` 13-state
- `entdaa_controller` 7-state
- `entdaa_fsm` 8-state
- `bus_tx` 5-state
- `bus_tx_flow` 4-state
- `bus_rx_flow` 4-state
- Timing diagram: `I3CWriteImmediate` sub-case C phases 0..10
- Timing diagram: OD→PP boundary

**Tables** (from RTL analysis):
- `flow_active` state-transition table (verbatim from `flow_active.sv` lines 328–480)
- `scl_generator` state-transition table
- `flow_active` issue-phase decode (I3CWriteImmediate sub-case C)
- DAT entry bitfield
- All four CMD descriptor packed-struct formats
- Response-descriptor and error-code enum

**Key implementation choices to narrate**:
1. Single 20-bit counter strategy in `scl_generator` (area win vs N parallel timers).
2. Wired-AND of `scl_gen_sda & tx_flow_sda` in `controller_active` for open-drain modelling.
3. `bus_rx_flow` emitting 7 stored bits + live SDA on cycle 8 — aligned byte on `rx_done_o`.
4. `entdaa_fsm` re-written from target-side (reference) to master perspective.
5. 16-entry vs 128-entry DAT (scope reduction decision).
6. Hand-written CSR (~300 LoC) vs PeakRDL auto-gen (~14 K LoC).
7. All 13 `flow_active` states implemented — reference left 8 as TODO (**headline RTL contribution**).

---

## Chapter 6 — Verification Methodology

**Purpose**: Explain *how* the design was verified before showing *what* exists in the env.

**Content**: closure goals; directed-first/random-later choice rationale; why UVM 1.2 + CDNS bundle + Xcelium; why custom `reg_agent` over `uvm_reg` (simple addr/wen/ren bus); analysis-port architecture; scoreboard role; bug-loop methodology; coverage blueprint for Phase 2.

**Repo references**: `docs/verification_specs/00_uvm_implementation_plan.md`, `docs/bug_analysis_report.md`, all `01–09_*.md` verification specs.

**Figures**: UVM block diagram (TB top + two agents + virtual sequencer + scoreboard + analysis paths); bug-severity bar chart (from `bug_analysis_report.md`).

**Tables**: verification goals vs evidence; Phase 1 vs Phase 2 split; bug severity summary (3+8+7+4).

**Notes**: Keep methodology-only here; concrete classes go in Chap. 7.

---

## Chapter 7 — UVM Verification Environment

**Purpose**: Walk through the testbench bottom-up.

**UVM component map**:

| Component | Class | File |
|---|---|---|
| Test | `i3c_base_test` | `i3c_core/i3c_base_test.sv` |
| Env | `i3c_env` | `i3c_core/i3c_env.sv` |
| Virtual sequencer | `i3c_virtual_sequencer` | `i3c_core/i3c_virtual_sequencer.sv` |
| Scoreboard | `i3c_scoreboard` | `i3c_core/i3c_scoreboard.sv` |
| Reg agent | `reg_agent` | `dv_reg/reg_agent.sv` |
| I3C agent (Device) | `i3c_agent` | `dv_i3c/i3c_agent.sv` |
| Device-response seq | `i3c_device_response_seq` | `dv_i3c/seq_lib/` |
| Vseqs | smoke / write / read | `i3c_core/i3c_vseqs/` |

**Figures**: UVM topology tree (from `print_topology`; redrawn as TikZ); i3c_driver Device-mode FSM (9 of 16 phases); sequence-of-events timeline for `i3c_smoke_vseq`.

**Tables**: Phase-1 test list; `i3c_drv_phase_e` table (16 phases, 9 reachable); CCC enum (5); pre-Phase-2 gap list.

**Key implementation points to discuss**:
- Reduced FIFO depths (8 in TB vs 64 in RTL) to shrink sim time.
- `+UVM_TEST_SEQ` plusarg-driven vseq dispatch via `factory.create_object_by_name`.
- 100 ms watchdog `uvm_fatal` in `tb_i3c_top.sv`.
- SHM dump gated by `+DUMP_WAVES`.
- Today's `regression` target writes a single shared `sim.log` (limitation; document honestly).
- Monitor calls `wait_for_device_ack_or_nack` not defined in `i3c_if.sv` — pre-Phase-2 fix required.

**Phase-2 roadmap for §7.9**:

| Item | New files | Effort |
|---|---|---|
| Fix monitor stub | `dv_i3c/i3c_if.sv` | 30 min |
| ENTDAA test | `i3c_entdaa_vseq.sv` + scoreboard CCC decode | 1 day |
| ENEC/DISEC broadcast + direct | 4 × vseq + scoreboard CCC decode | 1 day |
| Error injection (NACK/abort/overflow) | extend agent + 2 vseqs | 1 day |
| Multi-device | extend `i3c_env_cfg` to N targets | 1–2 days |
| Functional coverage | new `i3c_cov.sv` | 1 day |

---

## Chapter 8 — FPGA Implementation and Hardware Validation [OPTIONAL]

**Purpose**: Validate on real silicon-fabric; produce utilisation + timing-closure; capture waveforms.

**Status**: No FPGA work exists — this chapter is fully greenfield, contingent on Phase 4 (08/06–28/06/2026).

**Two paths**:
- **Path A (preferred)**: full bring-up — wrapper + constraints + LA captures.
- **Path B (fallback)**: synthesis-only run — utilisation estimate + timing report; no hardware.

**FPGA wrapper to create** (`src/fpga/i3c_fpga_top.sv`): wraps `i3c_controller_top`; routes `sel_od_pp_o` to the `T` pin of `IOBUF` (Xilinx) or `ALT_IOBUF` (Intel) for bidirectional SCL/SDA pads; includes PLL/MMCM for ≥333 MHz core clock and a UART-to-reg-bridge.

**Constraints**: `create_clock` on PLL output (≤3 ns period); `set_input/output_delay` on SCL/SDA with PCB margins; `false_path` on UART.

**Figures**: FPGA top-wrapper block diagram; IOBUF/sel_od_pp_o tri-state schematic; LA screenshots of START, SDR byte, STOP, ENTDAA.

**Tables**: utilisation (LUT/FF/BRAM, % device); timing (WNS, TNS).

**References**: architectural hints in `docs/module_specs/01_i3c_phy_spec.md` (IOBUF discussion) and `docs/module_specs/11_i3c_controller_top_spec.md` line 285 (FPGA loopback note).

---

## Chapter 9 — Results and Evaluation

**Purpose**: Quantitative summary of all work.

**Content**: LoC per module; UVM regression pass/fail with seeds; waveform evidence; bug yield from UVM; FPGA utilisation/timing; functional comparison with reference; unimplemented feature cost estimate.

**Repo references**: `sim.log` (post-regression), `docs/bug_analysis_report.md`, synthesis reports.

**Figures**: annotated waveform of `i3c_smoke_vseq`; annotated waveform of Regular Read; annotated waveform of OD↔PP transition.

**Tables**: regression matrix; LoC by module; bug summary; FPGA utilisation (if done).

---

## Chapter 10 — Conclusion and Future Work

**Content**: contributions (all 13 `flow_active` states; clean simplified architecture; working dual-agent UVM; first ENTDAA-capable master in this lab); lessons learned (spec-vs-code drift, hand-written CSR educational value); future work prioritised — (1) fix 3 CRITICAL bugs, (2) ENTDAA/CCC/coverage Phase 2, (3) IBI/Hot-Join, (4) Target mode.

---

# 5. ARCHITECTURE AND MODULE ANALYSIS

## 5.1 Module hierarchy

```
i3c_controller_top
├── u_csr     : csr_registers   (CSR file + DAT + CMD/TX staging)
├── u_queues  : hci_queues      (4 × sync_fifo: CMD64, TX32, RX32, RESP32)
├── u_ctrl    : controller_active
│     ├── u_bus_mon  : bus_monitor
│     │     ├── 4 × edge_detector (scl/sda pos/neg)
│     │     └── 3 × stable_high_detector (sda_high, scl_high, scl_low)
│     ├── u_scl_gen  : scl_generator
│     ├── u_tx_flow  : bus_tx_flow → bus_tx
│     ├── u_rx_flow  : bus_rx_flow
│     ├── u_flow_fsm : flow_active           [13-state command FSM]
│     └── u_daa_ctrl : entdaa_controller → entdaa_fsm
└── u_phy     : i3c_phy          (2-FF sync + output bypass)
```

## 5.2 FSM inventory

| FSM | File | States | Role |
|---|---|---:|---|
| `flow_active.flow_fsm_state_e` | `flow_active.sv` | 13 | Command dispatch |
| `scl_generator.state_e` | `scl_generator.sv` | 13 | Bus event sequencer |
| `entdaa_controller.state_e` | `entdaa_controller.sv` | 7 | DAA loop manager |
| `entdaa_fsm.state_e` | `entdaa_fsm.sv` | 8 | Per-device DAA handshake |
| `bus_tx_flow.tx_state_e` | `bus_tx_flow.sv` | 4 | Byte/bit serializer |
| `bus_tx.tx_state_e` | `bus_tx.sv` | 5 | Per-bit timing FSM |
| `bus_rx_flow.rx_state_e` | `bus_rx_flow.sv` | 4 | RX deserializer |

## 5.3 Data paths

**Write**: SW → `csr_register` (CMD staging: DWORD0 then DWORD1 → 64-bit push) → CMD FIFO → `flow_active` pops CMD → fetches DAT → drives `bus_tx_flow` + `scl_generator` via `controller_active` → `i3c_phy` → pads.

**Read**: same until `flow_active` enables `bus_rx_flow` → samples SDA on SCL posedge → accumulates 8-bit → packs 4 bytes into 32-bit → RX FIFO push → SW reads `0x108`.

**ENTDAA**: `flow_active` reaches `IssueCmd` with `attr=AddressAssignment` → asserts `ccc_valid` → `entdaa_controller` takes bus; outer loop reads DAT[round] → inner `entdaa_fsm` sends 0x7E, shifts 64-bit PID/BCR/DCR, sends `{addr, parity}` → returns `addr_valid` → outer loop increments round until `no_device` or `bus_stop_det`.

## 5.4 Clock / reset

Single clock domain. Async-assert active-low `rst_ni`. `i3c_phy` provides 2-FF synchronizer on SCL/SDA inputs. `bus_monitor` adds one additional capture flop → total 3 flops before edge-detection. Synchronous SW-reset (`HC_CONTROL.SW_RESET=1`, auto-clearing) flushes all 4 FIFOs and CMD-staging.

---

# 6. VERIFICATION METHODOLOGY PLAN

## 6.1 Strategy

Simulation-driven, no formal. Directed-first in Phase 1. Functional coverage and constrained-random deferred to Phase 2 (explicitly documented in `00_uvm_implementation_plan.md`).

## 6.2 Assertions

- **RTL**: one `assert property` in `bus_rx_flow.sv` lines 164–165 (no simultaneous bit+byte request).
- **TB**: none (only 100 ms watchdog `uvm_fatal`).
- **Recommended additions for Phase 2**: START only when bus idle; T-bit parity matches write data; Sr only after previous START; `sel_od_pp_o` deasserts before STOP.

## 6.3 Functional coverage blueprint (Phase 2)

Covergroups to design:
- CCC opcode × direction (broadcast/direct)
- `i3c_cmd_attr_e` × direction × data-length bucket
- T-bit value (0/1) × read/write
- RESP `err_status` enum
- CSR address × access-type matrix
- Queue occupancy buckets per FIFO
- DAT index × is_i2c

## 6.4 Regression flow

```bash
cd src/verification
make clean && make compile
make regression    # smoke → write → read
make waves DUMP_WAVES=1 TEST=i3c_base_test SEQ=i3c_smoke_vseq
```

> **Known limitation**: the `regression` target overwrites `sim.log`. Per-test log files should be added before presenting results in Chap. 9.

## 6.5 Required waveform captures

| # | Waveform | Source |
|---|---|---|
| W1 | Reset + CSR boot-up | sim |
| W2 | `i3c_smoke_vseq` end-to-end | sim |
| W3 | `i3c_write_vseq` 4-byte payload | sim |
| W4 | `i3c_read_vseq` 4-byte payload | sim |
| W5 | OD↔PP transition close-up | sim (zoomed) |
| W6 | Scoreboard mismatch debug-loop | sim (manual inject) |
| W7 | LA: I3C START + SDR byte + STOP | FPGA Path A |
| W8 | LA: ENTDAA arbitration | FPGA Path A |

---

# 7. FPGA VALIDATION PLAN

> **Critical**: no FPGA artefacts exist in the repository. This plan is entirely forward-looking.

## 7.1 Scope decision

| Path | Description | When |
|---|---|---|
| **A — Full bring-up** | FPGA wrapper + constraints + LA captures | 08/06–28/06/2026 |
| **B — Synthesis-only** | Utilisation + timing report; no board | fallback |

## 7.2 Files to create

| File | Description |
|---|---|
| `src/fpga/i3c_fpga_top.sv` | FPGA wrapper with PLL, IOBUF, UART-to-reg bridge |
| `src/fpga/constraints.xdc` (Vivado) or `constraints.sdc` (Quartus) | Clock + IO timing |
| `src/fpga/build.tcl` or Quartus `.qsf` | Build script |

## 7.3 IOBUF strategy

```systemverilog
// sel_od_pp_o = 1 → push-pull (data phase)
// sel_od_pp_o = 0 → open-drain (address/ACK phase: drive 0 or release)
assign scl_t = 1'b0;               // master always drives SCL
assign sda_t = sel_od_pp_o ? !sda_o : (sda_o ? 1'b1 : 1'b0);
// sda_t = 1: high-Z (release); sda_t = 0: drive sda_o
IOBUF sda_buf (.IO(sda_io), .O(sda_i), .I(1'b0), .T(sda_t));
```

## 7.4 Pass/fail criteria

Bytes on LA capture match bytes in corresponding simulation trace; SCL period within ±10% of `(T_LOW + T_HIGH) × Tsys`.

## 7.5 Honest fallback

If neither real I3C target nor working host bridge is available by 28/06/2026, Chap. 8 reports synthesis-only metrics and documents the architecture for what hardware test would look like.

---

# 8. SUGGESTED FIGURES, TABLES, AND WAVEFORMS

## 8.1 Figures (~30 target)

| # | Figure | How to produce |
|---|---|---|
| F1 | Engineering pipeline | TikZ |
| F2 | I²C vs I3C frame side-by-side | TikZ |
| F3 | ENTDAA timing skeleton | TikZ |
| F4 | UVM stack overview | TikZ |
| F5 | Repository organisation | TikZ |
| F6 | Three-layer hierarchy block diagram | TikZ |
| F7 | Data-flow: write transaction | TikZ |
| F8 | Data-flow: read transaction | TikZ |
| F9 | Clock/reset/sync diagram | TikZ |
| F10 | CSR command-staging diagram | TikZ |
| F11 | sync_fifo pointer / full / empty | TikZ |
| F12 | bus_monitor START/Sr/STOP logic | TikZ + waveform |
| F13 | **scl_generator FSM (13 states)** | TikZ `automata` |
| F14 | bus_tx_flow FSM (4 states) | TikZ |
| F15 | bus_tx FSM (5 states) | TikZ |
| F16 | bus_rx_flow FSM (4 states) | TikZ |
| F17 | entdaa_controller FSM (7 states) | TikZ |
| F18 | entdaa_fsm FSM (8 states) | TikZ |
| F19 | **flow_active FSM (13 states) — flagship, landscape** | TikZ |
| F20 | flow_active issue-phase diagram (I3CWriteImmediate sub-case C) | TikZ |
| F21 | OD↔PP boundary timing | Annotated SimVision capture |
| F22 | controller_active arbitration wired-AND | TikZ |
| F23 | UVM topology (redrawn from print_topology) | TikZ |
| F24 | i3c_driver Device-mode FSM (9 reachable phases) | TikZ |
| F25 | `i3c_smoke_vseq` sequence-of-events waveform | SimVision capture |
| F26 | Regular Read waveform | SimVision capture |
| F27 | FPGA top-wrapper block diagram | TikZ |
| F28 | IOBUF / sel_od_pp_o tri-state schematic | TikZ |
| F29 | LA capture: I3C SDR write | LA screenshot (Path A) |
| F30 | LA capture: ENTDAA arbitration | LA screenshot (Path A) |

## 8.2 Tables (~23 target)

| # | Table | Source |
|---|---|---|
| T1 | Objectives ↔ chapters | Outline |
| T2 | I²C vs I3C feature matrix | MIPI spec |
| T3 | In-scope vs out-of-scope | `i3c_scope_analysis.md` |
| T4 | Performance budget | `improvements.md` |
| T5 | CSR register map (full bitfields) | `csr_register.sv` |
| T6 | Timing-register reset defaults | `csr_register.sv` |
| T7 | DAT entry bitfield | `controller_pkg.sv` |
| T8 | CMD descriptor formats (4 types) | `i3c_pkg.sv` |
| T9 | Response descriptor and error codes | `i3c_pkg.sv` |
| T10 | Per-module LoC (18 files) | filesystem |
| T11 | Instance hierarchy | top SV |
| T12 | `flow_active` state-transition table | `flow_active.sv` L328–480 |
| T13 | `scl_generator` state-transition table | `scl_generator.sv` L137–238 |
| T14 | `entdaa_fsm` state-transition table | `entdaa_fsm.sv` L162–217 |
| T15 | Reference vs this project simplification | `improvements.md` |
| T16 | UVM file inventory | filesystem |
| T17 | Phase-1 test list (smoke/write/read) | `i3c_vseqs/` |
| T18 | `i3c_drv_phase_e` table (16 phases, 9 active) | `i3c_agent_pkg.sv` |
| T19 | CCC subset opcode table (5 entries) | `i3c_agent_pkg.sv` |
| T20 | Bug severity summary (3/8/7/4) | `bug_analysis_report.md` |
| T21 | Regression result matrix | `sim.log` post-run |
| T22 | FPGA utilisation (LUT/FF/BRAM) | Synth report |
| T23 | FPGA timing (WNS/TNS) | Synth report |

---

# 9. RECOMMENDED THESIS WRITING ORDER

> Today: 2026-05-13 (Phase 3). Report-writing window per outline: 29/06–05/07/2026 (≈7 days). **Start writing now in parallel with verification work.**

| Priority | Chapter | Why | Start | Dependency |
|---|---|---|---|---|
| 1 | Chap. 2 Background + Glossary | No RTL dependency; pure literature | Now | none |
| 2 | Chap. 1 Introduction | From outline + README | May 13–18 | none |
| 3 | Chap. 3 Requirements | Direct rewrite of `phase1_spec_v2.md` + `i3c_scope_analysis.md` | May 18–22 | docs |
| 4 | Chap. 4 Architecture | From `module_specs/11_*` + `architecture_qa_session.md` | May 22–28 | repo stable |
| 5 | Chap. 5 RTL (module specs already ~80% drafted) | Draw FSM figures while verifying | May 25 – Jun 10 | RTL stable ✓ |
| 6 | Chap. 6 Verif Methodology | After Phase-1 regression is green | Jun 1–7 | tests passing |
| 7 | Chap. 7 UVM Environment | Needs waveforms W1–W5 first | Jun 5–15 | sim run + screenshots |
| 8 | Chap. 8 FPGA | After synthesis / LA captures | Jun 22–28 | Path A or B done |
| 9 | Chap. 9 Results | Aggregates regression log + FPGA | Jun 28 – Jul 2 | all earlier results |
| 10 | Chap. 10 + Appendices | Quick if Chap. 9 is solid | Jul 2–4 | Chap. 9 frozen |
| 11 | Final polish, references, figures list | Last 24 hours | Jul 4–5 | all chapters |

**Immediately writable without hardware/simulation**: Chaps. 1, 2, 3, 4, all FSM figures in Chap. 5, methodology half of Chap. 6.

**Blocked on simulation results**: Chap. 7 (waveforms), Chap. 9 (regression matrix).

**Blocked on hardware**: Chap. 8 only (Path A).

---

# 10. APPENDIX RECOMMENDATIONS

| Appendix | Content | Source |
|---|---|---|
| A. CSR register map | Full bit-field tables (HC_CONTROL → DAT) using `longtable` | `csr_register.sv`, `i3c_csr_addr_pkg.sv` |
| B. Descriptor formats | CMD (4 types), RESP, DAT entry | `i3c_pkg.sv`, `controller_pkg.sv` |
| C. FSM state tables | All 7 RTL FSMs in transition-table form | RTL files |
| D. CCC subset | ENTDAA/ENEC/DISEC opcode + frame diagrams | `i3c_agent_pkg.sv` + MIPI spec |
| E. Regression log excerpts | Trimmed `sim.log` for smoke/write/read | post-`make regression` |
| F. Synthesis / utilisation reports | Verbatim from toolchain (Path A or B) | synth output |
| G. Build reference | Makefile target reference | `Makefile` |
| H. Glossary | I3C, IBI, ENTDAA, BCR, DCR, PID, OD, PP, SDR, HDR, CCC, DAT, HCI, UVM, TLM | standard |
| I. Bibliography | MIPI I3C Basic v1.1.1; UVM 1.2 Ref; CHIPS Alliance i3c-core; OpenTitan dv_macros | BibTeX |

---

# 11. MISSING INFORMATION

Items required by a complete thesis **not yet present** in the repository:

| # | Missing | Needed for | Severity |
|---|---|---|---|
| M1 | FPGA wrapper, constraints, project files, scripts | Chap. 8 (entire) | HIGH — blocks Path A |
| M2 | Synthesis / utilisation / timing reports | Chap. 8, App. F | HIGH |
| M3 | Logic-analyser captures | Chap. 8, F29/F30 | HIGH (Path A only) |
| M4 | Functional coverage report | Chap. 6, Chap. 9 | MEDIUM (Phase-2 deferral disclosed) |
| M5 | ENTDAA / CCC / error-injection tests | Chap. 6, Chap. 7, Chap. 9 | MEDIUM (Phase-2 deferral disclosed) |
| M6 | Predictor / reference model class | Chap. 6 | MEDIUM |
| M7 | High-value SVAs in TB | Chap. 6 | LOW |
| M8 | Architecture diagrams as image files (only ASCII/Mermaid today) | every chapter | HIGH — all must be drawn in TikZ |
| M9 | Per-test regression logs (current `make regression` overwrites `sim.log`) | Chap. 9 | LOW — fix before final run |
| M10 | `wait_for_device_ack_or_nack` task in `i3c_if.sv` (monitor stub gap) | prerequisite for all sims with monitor enabled | MEDIUM |
| M11 | Resolution of 3 CRITICAL bugs (BUG-001 syntax / BUG-002 immediate hang / BUG-003 RX partial DWORD) | Chap. 9 validity | HIGH if presenting results |
| M12 | `src/verification/README.md` (spec calls for it) | not strictly required | LOW |

---

# 12. LATEX WRITING RECOMMENDATIONS

## 12.1 Document structure

```
report.tex                   ← master file
chapters/
  01_intro.tex … 10_conclusion.tex
appendices/
  A_csr.tex … I_bibliography.tex
figures/                     ← TikZ sources + image files
listings/                    ← SV snippets
references.bib
```

Use `\documentclass[12pt,a4paper,oneside]{report}` (or HCMUS-mandated template).

**Required packages**: `inputenc utf8`, `babel`, `geometry`, `graphicx`, `caption`, `subcaption`, `booktabs`, `xcolor`, `hyperref`, `cleveref`, `tikz` (+ `automata`, `arrows.meta`, `positioning`, `shapes`, `chains`), `listings` or `minted`, `siunitx`, `glossaries`, `longtable`, `pdflscape`, `pdfpages`.

## 12.2 FSM figures

Use `tikz` `automata` library: nodes as `state, initial, accepting`; transitions via `edge`. The `flow_active` 13-state diagram should be a `\begin{figure}[!p]` full-page figure rotated with `pdflscape`. All other FSM diagrams fit `\begin{figure}[!htb]` at `width=0.95\textwidth`.

## 12.3 Code formatting

Configure `listings`:
```latex
\lstdefinestyle{sv}{language={[2017]Verilog}, basicstyle=\ttfamily\footnotesize,
  keywordstyle=\bfseries, numbers=left, numberstyle=\tiny, frame=single,
  breaklines=true, tabsize=2,
  morekeywords={logic,always_ff,always_comb,typedef,struct,packed,enum,
                interface,module,endmodule,package,endpackage,import}}
```

**Do not** dump RTL files into the body. Quote ≤30-line snippets only: port declarations, FSM state enums, key `always_comb` cases. Prefer **state-transition tables** + **FSM diagrams** over raw `always_comb` blocks. Prefer **pseudocode** for UVM sequences in Chap. 6.

## 12.4 Waveform inclusion

Export SimVision waveforms as PDF (vector) or PNG at 300 dpi. Crop to a ≤5 µs window. Annotate key events (START, ACK, T-bit, OD→PP, STOP) with TikZ `\begin{tikzpicture}[overlay]` arrows and text labels.

## 12.5 Bibliography

Use BibTeX with `IEEEtran` style. Mandatory citations:
- MIPI I3C Basic v1.1.1 (with Errata 01, 2022)
- Accellera UVM 1.2 Reference
- CHIPS Alliance `i3c-core` repository (with commit SHA)
- OpenTitan `dv_macros.svh`

## 12.6 Per-chapter style guidance

| Chapter | Dominant format | Avoid |
|---|---|---|
| Chap. 2 | Narrative + citation + 1 feature-matrix table | Code listings |
| Chap. 3 | Bullet lists + tables | Long prose |
| Chap. 4 | Block diagrams + 1–2 paragraph per block | Sub-module detail |
| Chap. 5 | FSM diagrams + state-transition tables + ≤30-line snippets | Full file listings |
| Chap. 6 | Pseudocode + UVM topology diagram | Raw UVM source |
| Chap. 7 | Component diagrams + waveform screenshots | Excessive SV listings |
| Chap. 8 | Schematics + LA screenshots | Bare tool logs |
| Chap. 9 | Tables + annotated waveforms | Prose padding |

## 12.7 Critical pitfalls to avoid

1. **Do not present results before fixing the 3 CRITICAL bugs** (BUG-001/002/003) and the monitor stub. Re-run regression post-fix and quote those logs.
2. **Do not claim Phase-2 features** anywhere without clearly labelling them "future work".
3. **Always attribute the CHIPS Alliance i3c-core** in captions or footnotes wherever simplified RTL appears — the license and README attribution are mandatory.
4. **Do not pad with auto-generated content** — the supervisor will recognise the reference code patterns.
5. **Justify UVM and directed-first** explicitly in Chap. 6 — do not simply state "we use UVM".

---

# Verification of this Plan — Pre-Writing Checklist

Before starting Chap. 5 in earnest, run from `src/verification/` to produce baseline logs:

```bash
make clean
make compile
make smoke
make sim TEST=i3c_base_test SEQ=i3c_write_vseq
make sim TEST=i3c_base_test SEQ=i3c_read_vseq
make waves DUMP_WAVES=1 TEST=i3c_base_test SEQ=i3c_smoke_vseq
```

Open `waves.shm` in SimVision and capture waveforms W1–W5 (§6.5). Once smoke regression is green and W2 is in hand, **Chapters 1–4 and all FSM figures of Chapter 5 are fully unblocked**.

---

# Critical File Reference (quick look-up while writing)

| Writing | Read these |
|---|---|
| Chap. 1 | `docs/Vo_Minh_Huy_Graduation_Thesis_Outline.pdf`, `README.md` |
| Chap. 2 | `docs/phase1_spec_v2.md` §§1–6, `docs/mipi_i3c_spec.pdf` |
| Chap. 3 | `docs/phase1_spec_v2.md` §§7–10, `docs/i3c_scope_analysis.md`, `docs/improvements.md` |
| Chap. 4 | `src/rtl/i3c_controller_top.sv`, `docs/module_specs/11_*.md`, `docs/architecture_qa_session.md` |
| Chap. 5 | every file in `src/rtl/`; every file in `docs/module_specs/` |
| Chap. 6 | `docs/verification_specs/00_*.md`, `docs/bug_analysis_report.md` |
| Chap. 7 | every file in `src/verification/uvm_i3c/`, `docs/verification_specs/01_*…09_*.md` |
| Chap. 8 | `docs/module_specs/01_*.md` L132+L205 (IOBUF hint), `docs/module_specs/11_*.md` L285 |
| Chap. 9 | `sim.log` (post-regression), synthesis reports, `docs/bug_analysis_report.md` |
| Chap. 10 | `docs/bug_analysis_report.md` open-issue list |
