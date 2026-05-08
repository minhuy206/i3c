# Thesis Master Plan
## "Design of an I3C Communication Controller"

**Author:** Vo Minh Huy (22207042)  
**Supervisor:** Nguyen Duy Manh Thi  
**Project Type:** M.S. Thesis (Graduation Thesis)  
**Document Version:** 1.0  
**Last Updated:** May 7, 2026

---

## Table of Contents

1. [Project Scope Summary](#1-project-scope-summary)
2. [Proposed Thesis Outline](#2-proposed-thesis-outline-latex-ready-structure)
3. [Detailed Chapter-by-Chapter Breakdown](#3-detailed-chapter-by-chapter-breakdown)
4. [Consolidated Figures, Tables, and Diagrams](#4-consolidated-figures-tables-and-diagrams-to-produce)
5. [LaTeX Writing Suggestions](#5-latex-writing-suggestions-per-section)
6. [Suggested Writing Order and Priority](#6-suggested-writing-order-and-first-drafts-priority)
7. [Missing Information Required](#7-missing-information-that-still-needs-to-be-prepared)

---

## 1. Project Scope Summary

### 1.1 Project Overview

A simplified, synthesizable **MIPI I3C Basic v1.1.1 Master ("Active") Controller** written in SystemVerilog, derived from the **CHIPS Alliance `i3c-core`** reference using a *study-and-improve* methodology with approximately 92% code reduction.

### 1.2 In-Scope Features

From `phase1_spec_v2.md` §1:

- **SDR mode** (target ~12.5 MHz)
- **Dynamic Address Assignment** via **ENTDAA**
- **Private Read/Write transfers**
- **I2C backward compatibility** (Fast Mode, 400 kHz)
- **Three CCCs only:**
  - ENTDAA (0x07)
  - ENEC (0x00 broadcast / 0x80 direct)
  - DISEC (0x01 broadcast / 0x81 direct)

### 1.3 Out-of-Scope Features

Explicitly excluded:

- In-Band Interrupts (IBI)
- Hot-Join
- HDR modes (DDR/TSL/TSP)
- Multi-master / secondary controller operation
- Target (slave) mode
- Bus recovery protocol
- Full HCI compliance

### 1.4 Architecture Overview

**16 RTL files organized across 5 implementation phases:**

| Phase | Modules | Count | Status |
|-------|---------|-------|--------|
| 0 — Packages | `i3c_pkg`, `controller_pkg` | 2 | Adapt |
| 1 — Leaf | `i3c_phy`, `edge_detector`, `stable_high_detector`, `bus_monitor`, `bus_tx`, `bus_tx_flow`, `bus_rx_flow`, `scl_generator` | 8 | Reuse/Copy/NEW |
| 2 — Infrastructure | `sync_fifo`, `hci_queues`, `csr_registers` | 3 | NEW |
| 3 — Protocol | `entdaa_fsm`, `entdaa_controller`, `flow_active` | 3 | Rewrite/NEW |
| 4 — Integration | `controller_active`, `i3c_controller_top` | 2 | NEW |
| **Total** | | **16** | |

### 1.5 Key Original Contributions

Compared to the reference design:

1. **Master-side rewrite of ENTDAA engine** — the reference (`i3c-core`) implements ENTDAA from the target perspective; this thesis reverses the roles for master operation.
2. **Implementation of all 8 TODO states in `flow_active`** — the reference implements only 5 of 13 states; this design completes all 13.
3. **New `scl_generator` module** — consolidates SCL/START/STOP generation logic scattered across two ~900-line FSMs in the reference.
4. **Proper OD/PP phase-based switching** — the reference hardcodes open-drain mode (`'0`); this design implements correct push-pull switching during I3C data phases.
5. **Hand-written 300-line CSR** — replaces the reference's 14,342-line auto-generated `I3CCSR` (PeakRDL output).
6. **Simplified HCI queues** — 2,500 lines → ~250 lines; IBI FIFO removed (IBI out of scope).
7. **Flattened top-level integration** — single bus (no AXI/AHB adapters), no `ifdef` matrix, clear signal routing.

### 1.6 Code Reduction Summary

**Quantitative simplification per module:**

| Module | Reference | This Design | Reduction |
|--------|-----------|-------------|-----------|
| `i3c_pkg` | Macro-heavy | ~150 lines | ~40% |
| CSR | 14,342 lines | ~300 lines | ~98% |
| HCI queues | 2,500 lines | ~250 lines | ~90% |
| `flow_active` | 580 lines (5/13 states) | ~500 lines (13/13 states) | —(expanded but complete) |
| `controller_active` | 292 lines | ~210 lines | ~28% |
| Top-level | 1,279 lines | ~150 lines | ~88% |
| **Total** | **~35,000 lines** | **~3,000 lines** | **~92%** |

---

## 2. Proposed Thesis Outline (LaTeX-Ready Structure)

### 2.1 Document Class and Format

**Recommended LaTeX setup:**

```
\documentclass[12pt,a4paper,oneside]{report}
```

**Language:** Vietnamese (front matter) + English (technical content)

### 2.2 Complete Document Structure

```
Front Matter
├── Cover page (Trang bìa)
├── Declaration of authorship
├── Acknowledgments (Lời cảm ơn)
├── Abstract — Vietnamese (Tóm tắt)
├── Abstract — English
├── Table of contents
├── List of figures
├── List of tables
├── List of acronyms / abbreviations
└── List of symbols (timing parameters, etc.)

Main Content
├── Chapter 1 — Introduction (~6–8 pages)
├── Chapter 2 — Theoretical Background: The MIPI I3C Protocol (~15–20 pages)
├── Chapter 3 — Reference Design Analysis and Thesis Methodology (~10–14 pages)
├── Chapter 4 — System Architecture (~12–18 pages)
├── Chapter 5 — Module-Level RTL Design (~50–70 pages)
├── Chapter 6 — UVM Verification (~25–35 pages)
├── Chapter 7 — FPGA Implementation and On-Board Verification (~15–22 pages)
└── Chapter 8 — Conclusion and Future Work (~5–7 pages)

Back Matter
├── References (IEEE style)
├── Appendix A — Full Register Map
├── Appendix B — Command and Response Descriptor Formats
├── Appendix C — Timing Parameter Computations
├── Appendix D — Selected UVM Source Listings
├── Appendix E — Synthesis Reports
└── Appendix F — User Guide and Build Instructions
```

**Estimated total page count:** 180–240 pages (including all figures, tables, and appendices)

---

## 3. Detailed Chapter-by-Chapter Breakdown

### Chapter 1: Introduction (~6–8 pages)

**Purpose:** Frame the problem, motivate the work, declare scope, preview contributions.

**Section outline:**

| Section | Content | Source | Length |
|---------|---------|--------|--------|
| 1.1 Background and motivation | Why I3C replaces I2C/SPI; 12.5× speed, dynamic addressing, low power, I2C compatibility | phase1_spec_v2.md §3 | 1.5 pp |
| 1.2 Problem statement | Lack of simplified, didactic I3C master IP; reference designs are over-engineered | — | 0.5 pp |
| 1.3 Thesis objectives | 4 in-scope features + 3 CCCs + key design decisions | phase1_spec_v2.md §1, §10 | 1 p |
| 1.4 Scope and limitations | Explicit out-of-scope list (IBI, Hot-Join, HDR, multi-master, target, recovery) | phase1_spec_v2.md §1 | 0.5 pp |
| 1.5 Methodology overview | 4-step "study-and-improve" approach | phase1_spec_v2.md §1.1 | 1 p |
| 1.6 Original contributions | 7 specific contributions vs. reference | §1.5 above | 1 p |
| 1.7 Thesis organization | One-paragraph preview of chapters 2–8 | — | 0.5 pp |
| 1.8 Thesis artifacts | Code repository, simulation logs, FPGA bitstream, user guide | — | 0.5 pp |

**Key content:**
- Motivate I3C: cite MIPI adoption by ARM, Qualcomm, etc.; sensor integration use cases.
- Set reader expectations: this is a master-level engineering thesis, not production-grade.
- Clearly separate the design/spec work (already complete in the provided docs) from implementation/verification (to be completed after thesis outline).

**No figures required for this chapter.**

---

### Chapter 2: Theoretical Background — The MIPI I3C Protocol (~15–20 pages)

**Purpose:** Provide protocol theory needed to read all subsequent design chapters.

**Detailed section outline:**

| Section | Content | Source | Length | Figures/Tables |
|---------|---------|--------|--------|---|
| 2.1 I3C overview | 2-wire SCL/SDA, single master (in this thesis), target devices, internal pull-up | phase1 §2.1–2.2 | 1.5 pp | F1 (topology) |
| 2.2 SDR mode | Encoding, NRZ, MSB-first, 8-bit data + T-bit | phase1 §2.3 | 1 p | — |
| 2.3 Frame format and bus conditions | START, Repeated START, STOP; definitions; waveforms | phase1 §2.4–2.5 | 1.5 pp | F2 (frames), F3 (address byte), F4 (waveforms) |
| 2.4 Reserved address and broadcast | 0x7E role in CCC and ENTDAA | phase1 §2.6 | 0.5 pp | — |
| 2.5 I3C vs I2C comparison | Full feature table; signaling differences (OD vs OD+PP) | phase1 §3 | 1 p | T1 (comparison table) |
| 2.6 Common Command Codes (CCC) | Frame formats for broadcast / direct CCC; the 3 CCCs implemented | phase1 §4 | 2 pp | T2 (CCC list) |
| 2.7 Dynamic Address Assignment (ENTDAA) | Target identity (PID 48-bit + BCR + DCR); ENTDAA protocol sequence; arbitration mechanism | phase1 §5 | 2.5 pp | F5 (identity layout), F6 (ENTDAA sequence), T3 (BCR fields) |
| 2.8 Private Read/Write transactions | Frame walkthrough; OD/PP transitions; T-bit semantics during read | phase1 §6 | 2 pp | F7 (Private Write seq), F8 (Private Read seq) |
| 2.9 I3C SDR and I2C FM timing parameters | Both timing tables; system-clock derivation (333 MHz minimum) | phase1 §7 | 1.5 pp | T4 (I3C timing), T5 (I2C timing) |

**Must-have figures (with sources):**

| # | Title | Source | Format | Notes |
|---|-------|--------|--------|-------|
| F1 | I3C bus topology | phase1 §2.2 mermaid | Redraw as TikZ | Master + I3C/I2C targets + pull-up |
| F2 | SDR frame format | phase1 §2.4 | ASCII → TikZ timing | [START] [Addr 9-bit] [Data 9-bit] [STOP] |
| F3 | 9-bit address byte breakdown | phase1 §2.4 | Box diagram | A[6:0] + RnW + T-bit |
| F4 | Bus conditions waveform | New, from §2.5 description | wavedrom/tikz-timing | START, Sr, STOP signals |
| F5 | PID + BCR + DCR identity | phase1 §5.1 block-beta | TikZ rectangle | 48-bit PID + 8-bit BCR + 8-bit DCR |
| F6 | ENTDAA sequence diagram | phase1 §5.2 sequenceDiagram | Convert mermaid or redraw | Master ↔ Targets |
| F7 | Private Write sequence | phase1 §6.1 sequenceDiagram | Convert mermaid | M → T: [S] [Addr] [Data...] [P] |
| F8 | Private Read sequence | phase1 §6.2 sequenceDiagram | Convert mermaid | M ← T: [S] [Addr] [Data with T-bit] [P] |

**Must-have tables:**

| # | Title | Source | Content |
|---|-------|--------|---------|
| T1 | I3C vs I2C features | phase1 §3 | Frequency, signaling, addressing, etc. |
| T2 | CCCs supported in this design | phase1 §4.2 | Code, mnemonic, description |
| T3 | BCR (Bus Characteristics Register) fields | phase1 §5.1 | Bits [7:0] and meanings |
| T4 | I3C SDR timing parameters | phase1 §7.1 | All timing symbols, min/max, units |
| T5 | I2C FM timing parameters | phase1 §7.2 | All timing symbols, min/max, units |

**Writing tips:**
- Use consistent notation: `SCL`, `SDA` (monospace); timing values in `\SI{}{}` (siunitx) e.g. `\SI{12.5}{\MHz}`, `\SI{24}{\ns}`.
- Include waveform diagrams for START/STOP/Sr to make the visual transitions clear.
- Keep technical accuracy — reference the MIPI I3C Basic v1.1.1 spec where possible.
- This chapter should be readable by someone unfamiliar with I3C; it is the foundation for all design chapters.

---

### Chapter 3: Reference Design Analysis and Thesis Methodology (~10–14 pages)

**Purpose:** Justify the study-and-improve approach; document exactly what was reused, simplified, rewritten, or discarded.

**Detailed section outline:**

| Section | Content | Source | Length | Figures/Tables |
|---------|---------|--------|--------|---|
| 3.1 CHIPS Alliance `i3c-core` overview | Repository, target use case (Caliptra RoT), key statistics (LoC, modules) | phase1 §8.1 | 2 pp | F9 (reference hierarchy) |
| 3.2 Reference top-level hierarchy | 3-level wrapper structure; AXI4 + AHB-Lite adapters; `ifdef` matrix | phase1 §8.1 | 1.5 pp | — |
| 3.3 Modules relevant to basic master | Table of 9 key modules | phase1 §8.2 | 1 p | T6 (relevant modules) |
| 3.4 Reuse/Simplify/Rewrite/Improve classification | Full action table; discussion of *why* each decision | phase1 §8.3, improvements.md | 2 pp | T7 (classification table) |
| 3.5 Out-of-scope reference modules | Why each is excluded (target FSM, IBI, recovery, HDR, standby) | phase1 §8.4 | 1.5 pp | T8 (excluded modules) |
| 3.6 Methodology process | 4-step pipeline per module | — | 1 p | — |
| 3.7 Quantitative simplification summary | Before/after LoC across all modules | §1.6 above | 1.5 pp | T9 (LoC reduction), F10 (hierarchy comparison) |

**Must-have figures:**

| # | Title | Source | Format |
|---|-------|--------|--------|
| F9 | Reference design hierarchy | phase1 §8.1 ASCII | TikZ tree diagram |
| F10 | Thesis design hierarchy (side-by-side with reference) | New | Two TikZ trees for visual contrast |

**Must-have tables:**

| # | Title | Source | Content |
|---|-------|--------|---------|
| T6 | 9 key modules in reference design | phase1 §8.2 | Module name, file, role |
| T7 | Reuse/Simplify/Rewrite/Improve classification | phase1 §8.3 | All 16 modules with rationale |
| T8 | Out-of-scope reference modules | phase1 §8.4 | Why excluded (9 modules) |
| T9 | Quantitative LoC reduction per module | Aggregated from "Changes from Reference Design" in all spec files | Module, reference, thesis, reduction % |

---

### Chapter 4: System Architecture (~12–18 pages)

**Purpose:** Give the top-down view before diving into individual modules.

**Detailed section outline:**

| Section | Content | Source | Length | Figures/Tables |
|---------|---------|--------|--------|---|
| 4.1 Top-level block diagram | 4-block layout: CSR + HCI queues + controller_active + PHY | phase1 §9.1, spec 11 §5.1 | 1.5 pp | F11 (top-level diagram) |
| 4.2 Module hierarchy and dependencies | Tree/DAG showing parent-child; shared packages | implementation_plan Phase 0-4 | 1.5 pp | F12 (dependency tree) |
| 4.3 Software/hardware interface | Register bus model; 4 HCI queues (CMD/TX/RX/RESP) specs | spec 06 §1; spec 07 §4 | 1 p | T10 (HCI queue inventory) |
| 4.4 Data path — write transaction | SW → CMD/TX FIFO → flow_active → bus_tx → SDA | phase1 §9.3.1 | 1.5 pp | F13 (write data flow) |
| 4.5 Data path — read transaction | SDA → PHY → bus_rx → RX/RESP FIFO → SW | phase1 §9.3.2 | 1 p | F14 (read data flow) |
| 4.6 Control path — ENTDAA | flow_active → entdaa_controller → entdaa_fsm; DAT pre-population | spec 08 §5.1, 5.6 | 1.5 pp | F15 (ENTDAA control flow) |
| 4.7 Bus signal multiplexing | SDA MUX (scl_gen vs bus_tx); TX/RX MUX (flow_active vs entdaa) | spec 10 §5.3, §5.6 | 1 p | F16 (SDA MUX diagram) |
| 4.8 Command and response descriptors | 64-bit CMD formats (Immediate/Regular/AddressAssign); 32-bit RESP | phase1 §9.4; spec 06 §5.2 | 1 p | F17 (RESP layout), T11 (descriptor formats) |
| 4.9 Configurable parameters | Default values table | phase1 §10.1 | 0.5 pp | T12 (parameters) |
| 4.10 Design decisions | Single clock, hand-written CSR, simple reg bus, reduced DAT | phase1 §10.2 | 1 p | T13 (design decisions) |

**Must-have figures:**

| # | Title | Source | Format |
|---|-------|--------|--------|
| F11 | Top-level block diagram (4 boxes) | phase1 §9.1 + spec 11 §5.1 | TikZ blocks |
| F12 | Module dependency tree | Synthesize from "Dependencies" in specs 01–11 | TikZ tree |
| F13 | Write transaction data path | phase1 §9.3.1 | Flow diagram (TikZ arrows) |
| F14 | Read transaction data path | phase1 §9.3.2 | Flow diagram |
| F15 | ENTDAA control flow | spec 08 §5.1 ASCII | Flow diagram with signal names |
| F16 | SDA multiplexing diagram | spec 10 §5.3 | TikZ MUX with sources |
| F17 | Response descriptor 32-bit layout | phase1 §9.4 block-beta | Box showing bit fields |

**Must-have tables:**

| # | Title | Source | Content |
|---|-------|--------|---------|
| T10 | HCI queue inventory | spec 06 §1 | Queue name, width, depth, direction |
| T11 | Command descriptor formats | spec 06 §5.2 + phase1 §9.2.6 | Immediate, Regular, AddressAssign |
| T12 | Configurable parameters | phase1 §10.1 | Parameter, default, description |
| T13 | Design decisions and rationale | phase1 §10.2 | Decision, choice, rationale |

**Writing tips:**
- Each data-path section should start with a simple sentence, then a figure, then prose explanation.
- Use consistent signal naming throughout (e.g., `cmd_queue_rvalid_i` always in monospace/`\texttt{}`).
- This chapter sets up all subsequent module-by-module descriptions; clarity here pays dividends.

---

### Chapter 5: Module-Level RTL Design (~50–70 pages — Largest Chapter)

**Purpose:** Describe each of 16 RTL modules in enough detail for a competent SystemVerilog engineer to re-implement.

**Organization:** Five sub-chapters (one per implementation phase), each with uniform template per module.

#### **5.1 Phase 0: Shared Packages** (~3 pages)

**Modules:** `i3c_pkg`, `controller_pkg`

**Content per package:**
- Purpose
- Key type definitions (`signal_state_t`, `bus_state_t`, command/response descriptors, `dat_entry_t`)
- Enum definitions (`i3c_resp_err_status_e`, `cmd_transfer_dir_e`, `i3c_cmd_attr_e`)
- Constants (`I3C_RSVD_ADDR = 7'h7E`, etc.)
- Parameter definitions (DatDepth, etc.)

**Source:** implementation_plan.md Phase 0; specs 01–11 §2 (Packages).

---

#### **5.2 Phase 1: Physical Layer and Bus Monitoring** (~8 pages)

**Modules:** `i3c_phy`, `edge_detector`, `stable_high_detector`, `bus_monitor`

**Template per module:**
1. Purpose (2–3 sentences)
2. Dependencies / parent modules
3. Parameters table
4. Port table (Clock/Reset, inputs, outputs)
5. Block diagram (if applicable)
6. Functional description (pseudo-code, state machine, or algorithm)
7. Key implementation details
8. Timing requirements
9. Changes from reference design (table)
10. Error handling
11. Test scenarios (list)

**Module details:**

| Module | Pages | Key Content | FSM States | Figures |
|--------|-------|---|---|---|
| `i3c_phy` | 1.5 | 2FF sync (inline); OD/PP pass-through; ResetValue | — | Block diagram of 2FF chain |
| `edge_detector` | 1 | Sub-module of bus_monitor; parameterized rising/falling; delay counter | — | Timing diagram |
| `stable_high_detector` | 1 | Counter-based level detection | — | Pseudo-code / timing |
| `bus_monitor` | 4.5 | Instantiates 4 edge + 3 stable detectors; produces `bus_state_t`; START vs Sr discrimination | — | Block diagram; timing tables |

**Figures needed:**
- F18: `i3c_phy` block (2FF + MUX)
- F19: `bus_monitor` internal layout (4 + 3 detector array)
- F20: Timing diagram for edge_detector operation

**Source:** specs 01–02.

---

#### **5.3 Phase 1 (continued): SCL Clock Generation** (~8 pages)

**Module:** `scl_generator`

**Content:**
1. Purpose: 13-state FSM for START/STOP/Sr/continuous clock
2. Parameters: CounterWidth
3. Ports: Control (gen_start, gen_rstart, gen_stop, gen_clock, gen_idle), Timing (t_low, t_high, t_su_sta, t_hd_sta, t_su_sto, t_r, t_f), Bus (scl_i), Outputs (scl_o, sda_o, done_o, busy_o)
4. **13-state FSM diagram** (mandatory figure)
5. State descriptions (table with each state's SCL/SDA values and transitions)
6. Timing counter operation
7. Output logic rules (combinational)
8. Done signal generation rules
9. I3C vs I2C timing derivation (example: I3C 12.5 MHz calculation)
10. Changes from reference (new module)
11. Test scenarios

**Figures needed:**
- F21: `scl_generator` block diagram (FSM + counter + output logic)
- F22: 13-state FSM state diagram
- F23: START/STOP/Sr generation waveforms (timing proof)

**Source:** spec 03.

---

#### **5.4 Phase 1 (continued): Bus Serializer/Deserializer** (~10 pages)

**Modules:** `bus_tx`, `bus_tx_flow`, `bus_rx_flow`

| Module | Pages | Content | FSM States | Figures |
|--------|-------|---------|---|---|
| `bus_tx` | 3 | Bit-level timing engine; Idle/AwaitClockNegedge/SetupData/TransmitData/HoldData | 5 | FSM + timing waveform |
| `bus_tx_flow` | 4 | Byte/bit FSM; shift register; one-hot req error | 4 | FSM + bit-timing diagram |
| `bus_rx_flow` | 3 | Single deserializer; SCL-edge sampling; 7-bit shift + combinational last bit | 4 | FSM + sampling diagram |

**Figures needed:**
- F24: `bus_tx_flow` FSM (Idle/DriveByte/DriveBit/NextTaskDecision)
- F25: `bus_tx` FSM (5 states with timing labels)
- F26: Bit-level transmit timing (SCL/SDA with t_su_dat, t_hd_dat)
- F27: `bus_rx_flow` FSM
- F28: Receive bit sampling on SCL posedge

**Source:** specs 04–05.

---

#### **5.5 Phase 2: Storage Infrastructure** (~6 pages)

**Modules:** `sync_fifo`, `hci_queues`, `csr_registers`

| Module | Pages | Content | Features |
|--------|-------|---------|----------|
| `sync_fifo` | 2 | Circular buffer; extra-MSB full/empty detection; flush; valid/ready handshake | Parameterized width/depth |
| `hci_queues` | 1.5 | Wrapper of 4 sync_fifo instances; signal routing table | CMD 64×64, TX/RX/RESP 32×64 |
| `csr_registers` | 2.5 | Register map; read/write logic; DAT hardware port; CMD staging for 64-bit two-write protocol | 15 registers + 16 DAT entries |

**Content details for CSR:**
- Register map table (offset, name, R/W, reset, description)
- Bit-field definitions per register (HC_CONTROL, HC_STATUS, timing regs, queue ports, QUEUE_STATUS, DAT)
- Write logic (pseudo-code for staging, self-clear of SW_RESET)
- Read logic (case statement per address)
- DAT hardware read port (1-cycle latency)
- Queue port routing (example: TX_DATA_PORT write → tx_wvalid_o + tx_wdata_o)

**Figures needed:**
- F29: sync_fifo block (write pointer, read pointer, memory, full/empty logic)
- F30: csr_registers register map visual (address space diagram)
- F31: hci_queues instantiation (4 FIFOs with signal names)

**Source:** specs 06–07.

---

#### **5.6 Phase 3: Protocol Layer — ENTDAA Engine** (~12 pages)

**Modules:** `entdaa_fsm`, `entdaa_controller`

| Module | Pages | Content | FSM States | Figures |
|--------|-------|---------|---|---|
| `entdaa_fsm` | 5 | Per-device ENTDAA round; 64-bit `id_shift_q`; odd-parity; STOP override | 8 | FSM diagram |
| `entdaa_controller` | 7 | Loop manager; `dev_round_q` counter; DAT lookup; entdaa_fsm dispatch | 7 | FSM diagram |

**ENTDAA-specific content:**
- Division of work between `entdaa_controller` (loop) and `entdaa_fsm` (per-device round) — section 5.1 of spec 08
- entdaa_fsm state descriptions (SendRsvdByte, ReadRsvdAck, ReceiveIDBit=64 cycles, SendAddr, ReadAddrAck, Done, NoDev) with pseudo-code for each
- entdaa_controller state descriptions (Idle, StartLoop, RequestRestart, WaitRestart, ReadDAT, RunEntdaa, Done) with `dev_round_q` counter logic
- Parity calculation: `parity = ~^daa_addr_i` (odd parity)
- DAT lookup during WaitRestart: `dat_index_o = dev_idx_i + dev_round_q`
- DAA result routing to `flow_active` (PID/BCR/DCR + address_valid)
- STOP override in both FSMs

**Figures needed:**
- F32: `entdaa_fsm` 8-state FSM diagram
- F33: `entdaa_controller` 7-state FSM diagram
- F34: Waveform showing one complete ENTDAA device round ([0x7E+R] [ACK] [64 bits] [Addr+P] [ACK])

**Source:** spec 08.

---

#### **5.7 Phase 3 (continued): Command Flow FSM** (~15 pages)

**Module:** `flow_active`

**Largest sub-section; structure:**

1. Purpose (2 paragraphs)
2. Dependency overview
3. Parameters (5 listed)
4. Port interface (organized by functional group: CMD/TX/RX/RESP queues, DAT, bus TX/RX, SCL gen, ENTDAA, OD/PP, status)
5. **13-state FSM diagram** (mandatory, complex)
6. State descriptions (table + prose for each):
   - **Implemented in reference (5 states):** Idle, WaitForCmd, FetchDAT, I2CWriteImmediate, WriteResp
   - **NEW in this thesis (8 states):** I3CWriteImmediate (3 sub-cases), FetchTxData, FetchRxData, InitI2CWrite, InitI2CRead, StallWrite, StallRead, IssueCmd
7. Command descriptor parsing (how the 64-bit descriptor is split into fields based on `attr`)
8. Sub-case details for `I3CWriteImmediate`:
   - Sub-case A: Private I3C write (START + addr + data with T-bit + STOP)
   - Sub-case B: Broadcast CCC (ENEC/DISEC)
   - Sub-case C: Direct CCC (Sr + target addr)
9. Error accumulation logic (first-error-wins register)
10. OD/PP switching logic (Open-Drain by default; Push-Pull for I3C data phase)
11. ENTDAA orchestration within `IssueCmd` (broadcast header, CCC code, activate entdaa_controller, poll ccc_req_restart, collect DAA results)
12. Timing requirements
13. Changes from reference (table)
14. Test scenarios (16 listed in spec §9)
15. Implementation notes (no I2C FSM sub-module; direct bus_tx/rx control; transfer_cnt semantics)

**Figures needed:**
- F35: `flow_active` 13-state FSM diagram (complex; consider breaking into two figures: states 0–6, states 7–12)
- F36: Waveform showing Private Write frame (START, addr 9-bit, data with T-bit, STOP)
- F37: Waveform showing I3C+Broadcast CCC (ENEC)
- F38: Waveform showing ENTDAA portion of `IssueCmd`

**Source:** spec 09.

---

#### **5.8 Phase 4: Integration** (~6 pages)

**Modules:** `controller_active`, `i3c_controller_top`

| Module | Pages | Content | Purpose |
|--------|-------|---------|---------|
| `controller_active` | 3.5 | Structural wrapper; sub-module instances and signal routing; SDA MUX; TX/RX MUX for ENTDAA; OD/PP routing; bus_state_t unpacking; dual DAT ports | Glue logic |
| `i3c_controller_top` | 2.5 | Purely structural; 4-block integration (CSR + HCI + controller_active + PHY); complete signal map | Top-level IP |

**Content for controller_active:**
- Sub-module instances (flow_active, bus_tx_flow, bus_rx_flow, bus_monitor, scl_generator, entdaa_controller)
- Signal routing diagram (connectivity of all sub-modules)
- SDA output MUX: prioritize scl_gen (START/STOP) > tx_flow (data) > idle (HIGH)
- TX/RX MUX for CCC: select entdaa_controller when daa_valid_i, else flow_active
- OD/PP control: passed through from flow_active
- Bus monitor connection: unpack bus_state_t struct to individual signals routed to sub-modules
- DAT read ports: two independent (flow_active in FetchDAT; entdaa_controller during rounds)
- I3C/I2C mode selection: from flow_active to scl_generator
- Controller enable gating

**Content for i3c_controller_top:**
- Sub-module instances (4: csr_registers, hci_queues, controller_active, i3c_phy)
- External port interface (register bus, SCL/SDA pins, sel_od_pp)
- Internal signal routing (clock, reset, all queue signals, timing config, bus interconnect)
- Parameter pass-through

**Figures needed:**
- F39: `controller_active` connectivity diagram (block-and-arrow showing all sub-modules and major signal paths)
- F40: `i3c_controller_top` 4-block integration diagram

**Source:** specs 10–11.

---

### Chapter 6: UVM Verification (~25–35 pages)

**Purpose:** Document verification strategy, UVM environment, and per-test methodology.

**Section outline:**

| Section | Content | Length | Figures/Tables |
|---------|---------|--------|---|
| 6.1 Verification strategy | Goals, levels, why UVM, tools | 2 pp | — |
| 6.2 UVM testbench architecture | Hierarchical layout: tb_top + i3c_if + env/agent/driver/monitor | 2 pp | F41 (testbench block) |
| 6.3 Agents, drivers, monitors, sequencers | Role of each; register-bus driver, SCL/SDA driver, monitor | 3 pp | — |
| 6.4 Reactive I3C/I2C target BFMs | Target behavior: respond to broadcast, drive PID bits, ACK/NACK | 2 pp | F42 (target BFM FSM) |
| 6.5 Sequences and tests | 6 sequences, 5 tests; test priority | 2 pp | T14 (test list) |
| 6.6 Scoreboard and reference model | RESP descriptor checking, RX data cross-check | 1.5 pp | — |
| 6.7 Assertions | SVA properties (req exclusivity, OD/PP stability, glitch avoidance) | 1.5 pp | — |
| 6.8 Functional coverage | Coverpoints per FSM, error codes, transitions, FIFO boundaries | 2 pp | T15 (coverage groups) |
| 6.9 Consolidated test scenarios | Master list from all module specs | 3 pp | T16 (scenario summary) |
| 6.10 Regression methodology | Seed strategy, pass criterion, log triage | 1 pp | — |
| 6.11 Verification results | *Placeholder section* | 2 pp | T17 (regression results) |

**Must-have figures:**

| # | Title | Source | Format |
|---|-------|--------|--------|
| F41 | UVM testbench block diagram | Standard UVM | TikZ (env → agent → driver → DUT → monitor) |
| F42 | I3C target BFM state machine | Spec 08 entdaa_fsm reversed | FSM diagram (reactive perspective) |
| F43 | Example simulation waveform: full ENTDAA round | New | wavedrom/tikz-timing (annotated) |
| F44 | Example simulation waveform: Private Write with OD→PP | New | wavedrom/tikz-timing |
| F45 | Example simulation waveform: Private Read with T-bit | New | wavedrom/tikz-timing |
| F46 | Example simulation waveform: I2C 400 kHz write | New | wavedrom/tikz-timing |
| F47 | Coverage report screenshot | New | PNG from QuestaSim/VCS |

**Must-have tables:**

| # | Title | Content | Source |
|---|-------|---------|--------|
| T14 | Test list with priority and status | Test name, priority (1–5), status (Not started/In progress/Pass/Fail) | implementation_plan §5 |
| T15 | Coverage groups with targets | FSM states, transitions, error codes, FIFO conditions, target % | New |
| T16 | Consolidated test scenario summary | Module, scenario count, key assertions | Aggregated from all specs §10 "Test Plan" |
| T17 | Regression results | Test name, seeds, pass/fail counts, assertions | *Placeholder* |

**Key sections to detail:**

**6.7 Assertions:** Include concrete SVA examples:
```systemverilog
// Mutually exclusive request
assert property (@(posedge clk_i) 
  ~(bus_tx_req_byte_i & bus_tx_req_bit_i))
  else $fatal("Both TX byte and bit requested!");

// OD/PP stable during byte
assert property (@(posedge clk_i) disable iff (!bus_tx_idle_i)
  $stable(sel_od_pp_o))
  else $warning("OD/PP changed while TX active!");
```

**6.8 Coverage:** Define key coverpoints:
- All 13 flow_active states visited (13 points)
- All 8 entdaa_fsm states visited (8 points)
- All 7 entdaa_controller states visited (7 points)
- All 13 scl_generator states visited (13 points)
- OD/PP transitions per phase (×3 phases = 3 points)
- All 6 error status codes triggered (6 points)
- FIFO full/empty/simultaneous (3 points)
- ENTDAA 3 sub-cases of I3CWriteImmediate (3 points)

---

### Chapter 7: FPGA Implementation and On-Board Verification (~15–22 pages)

**Purpose:** Document synthesis, PnR, on-board validation, and simulation vs hardware comparison.

**Section outline:**

| Section | Content | Length | Figures/Tables |
|---------|---------|--------|---|
| 7.1 FPGA implementation flow | RTL → synthesis → PnR → bitstream → board | 1 pp | F48 (flow pipeline) |
| 7.2 Target platform | *MISSING — to be supplied* Board name, FPGA device, speed grade | 0.5 pp | T18 (platform specs) |
| 7.3 Top-level integration for FPGA | sel_od_pp to pad driver (IOBUF); SCL/SDA bidirectional; register bus exposure | 1.5 pp | — |
| 7.4 Synthesis and place-and-route | Tool (Vivado/Quartus); constraints (XDC/SDC); 333 MHz target | 2 pp | — |
| 7.5 Resource utilization | LUT/FF/BRAM/DSP per module and total | 1 pp | F49 (utilization chart), T19 (utilization table) |
| 7.6 Timing closure | WNS/TNS/WHS/THS; critical paths; derating if needed | 1 pp | T20 (timing summary) |
| 7.7 On-board test setup | DUT + target I3C/I2C device; power-up; SW driver | 1.5 pp | F50 (hardware setup photo) |
| 7.8 Logic analyzer / waveform capture | Vivado ILA or external (Saleae); capture scenarios | 2 pp | F51–54 (ILA captures) |
| 7.9 Simulation vs hardware comparison | Same stimulus; compare frequencies, timing, OD/PP edges, error behavior | 2 pp | F55 (sim vs HW overlay) |
| 7.10 Performance results | Achieved SCL frequency, throughput, latency | 1 pp | T21 (performance metrics) |
| 7.11 Pass/fail criteria and results | Functional, timing, resource, compliance; summary of pass/fail | 2 pp | T22 (on-board test matrix) |

**Must-have figures:**

| # | Title | Source | Format |
|---|-------|--------|--------|
| F48 | FPGA implementation flow | New | Flow diagram (Vivado/Quartus stages) |
| F49 | Resource utilization bar chart | New | pgfplots bar chart per module |
| F50 | Hardware test setup photo | Author-supplied | JPG/PNG of board + target + probes |
| F51 | ILA capture: START + first data byte | New | Screenshot with annotations |
| F52 | ILA capture: full ENTDAA device round | New | Screenshot |
| F53 | ILA capture: I3C Private Write OD→PP transition | New | Screenshot showing glitch-free switch |
| F54 | ILA capture: I2C write sequence | New | Screenshot at 400 kHz |
| F55 | Simulation vs ILA overlay | New | Two waveforms side-by-side (tikz-timing or screenshot overlay) |

**Must-have tables:**

| # | Title | Content | Source |
|---|-------|---------|--------|
| T18 | Target FPGA specifications | Device name, package, speed grade, LUT/FF/BRAM counts | *Missing* |
| T19 | Resource utilization per module | Module name, LUT, FF, BRAM, DSP, totals | New (placeholder) |
| T20 | Timing summary | Clock period, WNS, WHS, TNS, THS, device grade | New (placeholder) |
| T21 | Performance metrics | SCL frequency (I3C/I2C), throughput (bytes/sec), latency (μs) | New (placeholder) |
| T22 | On-board test matrix | Test scenario, pass/fail, notes | New (placeholder) |

**Key missing information (§7 below):**
- FPGA board choice (Artix-7 / Zynq / Cyclone-V / etc.)
- Synthesizer (Vivado / Quartus version)
- Register-bus bridge (UART / JTAG-AXI / MicroBlaze / etc.)
- Target sensor/device for on-board test
- Actual achieved clock frequency
- Logic analyzer used

---

### Chapter 8: Conclusion and Future Work (~5–7 pages)

**Section outline:**

| Section | Content | Length |
|---------|---------|--------|
| 8.1 Summary of work performed | List what was designed, specified, implemented, verified | 1 pp |
| 8.2 Achievements vs. objectives | Map back to Chapter 1 §1.3 | 1 p |
| 8.3 Quantitative outcomes | 92% LoC reduction, SCL frequency, coverage %, resources | 0.5 pp |
| 8.4 Limitations | Restate out-of-scope features; acknowledge any remaining constraints | 1 pp |
| 8.5 Lessons learned | Critical insights: flow_active complexity, ENTDAA role reversal, OD/PP MUX glitches | 1 pp |
| 8.6 Future work | 10 concrete enhancements (IBI, Hot-Join, HDR, multi-master, additional CCCs, etc.) | 1.5 pp |

**Future work roadmap (to include in Chapter 8 or as optional figure):**

1. Add IBI handler (`ibi.sv` from reference)
2. Add Hot-Join detection
3. Add HDR-DDR / HDR-TSL / HDR-TSP modes
4. Add multi-master arbitration support
5. Add additional CCCs: SETDASA (0x87), GETPID (0x8D), GETBCR (0x8E), GETDCR (0x8F), SETMWL/SETMRL, GETSTATUS, RSTACT
6. Add full HCI compliance (target controller, recovery handler)
7. Replace simple register bus with AXI4 / AHB-Lite adapter
8. Add interrupt-driven FIFO threshold support
9. Add timeout counters for StallWrite/StallRead deadlock prevention
10. Tape-out: real silicon implementation in 7 nm or 5 nm process

---

## 4. Consolidated Figures, Tables, and Diagrams to Produce

**Complete inventory of all figures and tables called for in the thesis outline.**

### 4.1 Figures Inventory

| ID | Chapter | Title | Type | Source | Priority |
|----|---------|-------|------|--------|----------|
| F1 | 2 | I3C bus topology | Block diagram | phase1 §2.2 | Must |
| F2 | 2 | SDR frame format | Timing diagram | phase1 §2.4 | Must |
| F3 | 2 | 9-bit address byte | Box diagram | phase1 §2.4 | Must |
| F4 | 2 | Bus conditions (START/Sr/STOP) | Waveform | New from phase1 §2.5 | Must |
| F5 | 2 | PID + BCR + DCR identity | Rectangle layout | phase1 §5.1 | Must |
| F6 | 2 | ENTDAA sequence diagram | Sequence | phase1 §5.2 | Must |
| F7 | 2 | Private Write sequence | Sequence | phase1 §6.1 | Must |
| F8 | 2 | Private Read sequence | Sequence | phase1 §6.2 | Must |
| F9 | 3 | Reference design hierarchy | Tree diagram | phase1 §8.1 | Must |
| F10 | 3 | Thesis design hierarchy (vs. reference) | Two trees | New | Must |
| F11 | 4 | Top-level (4 blocks) | Block diagram | phase1 §9.1 | Must |
| F12 | 4 | Module dependency tree | DAG/tree | Synthesized | Must |
| F13 | 4 | Write data path | Flow diagram | phase1 §9.3.1 | Must |
| F14 | 4 | Read data path | Flow diagram | phase1 §9.3.2 | Must |
| F15 | 4 | ENTDAA control flow | Flow diagram | spec 08 §5.1 | Must |
| F16 | 4 | SDA multiplexing | MUX diagram | spec 10 §5.3 | Must |
| F17 | 4 | RESP descriptor layout | Bit-field box | phase1 §9.4 | Must |
| F18 | 5.2 | `i3c_phy` block (2FF + driver) | Block diagram | spec 01 §5 | Should |
| F19 | 5.2 | `bus_monitor` internal layout | Block diagram | spec 02 §5 | Should |
| F20 | 5.2 | Timing diagram for edge_detector | Waveform | spec 02 §6.2 | Should |
| F21 | 5.3 | `scl_generator` block diagram | Block diagram | spec 03 §5 | Should |
| F22 | 5.3 | `scl_generator` 13-state FSM | FSM diagram | spec 03 §6.1 | Must |
| F23 | 5.3 | START/STOP/Sr generation waveforms | Waveform proof | spec 03 §6.4 | Must |
| F24 | 5.4 | `bus_tx_flow` FSM | FSM diagram | spec 04 §5.1 | Must |
| F25 | 5.4 | `bus_tx` 5-state FSM | FSM diagram | spec 04 §5.2 | Must |
| F26 | 5.4 | Bit-level transmit timing | Waveform | spec 04 §5.2 | Must |
| F27 | 5.4 | `bus_rx_flow` FSM | FSM diagram | spec 05 §5.1 | Must |
| F28 | 5.4 | Receive bit sampling timing | Waveform | spec 05 §5.1 | Should |
| F29 | 5.5 | `sync_fifo` block | Block diagram | spec 06 §5.1 | Should |
| F30 | 5.5 | CSR register map visual | Address space diagram | spec 07 §5 | Should |
| F31 | 5.5 | `hci_queues` instantiation | Block diagram | spec 06 §5.3 | Should |
| F32 | 5.6 | `entdaa_fsm` 8-state FSM | FSM diagram | spec 08 §5.3 | Must |
| F33 | 5.6 | `entdaa_controller` 7-state FSM | FSM diagram | spec 08 §5.2 | Must |
| F34 | 5.6 | One complete ENTDAA device round waveform | Waveform | spec 08 §5.1 | Must |
| F35 | 5.7 | `flow_active` 13-state FSM (part 1) | FSM diagram | spec 09 §5.1 | Must |
| F35b | 5.7 | `flow_active` 13-state FSM (part 2) | FSM diagram | spec 09 §5.1 | Must |
| F36 | 5.7 | Private Write frame waveform | Waveform | spec 09 §5.3 | Must |
| F37 | 5.7 | Broadcast CCC (ENEC) frame waveform | Waveform | spec 09 §5.3 | Should |
| F38 | 5.7 | ENTDAA portion within `IssueCmd` | Waveform | spec 09 §5.3 | Should |
| F39 | 5.8 | `controller_active` connectivity | Block-and-arrow | spec 10 §5.1 | Must |
| F40 | 5.8 | `i3c_controller_top` 4-block integration | Block diagram | spec 11 §5.1 | Must |
| F41 | 6.2 | UVM testbench block diagram | UVM architecture | New | Must |
| F42 | 6.4 | I3C target BFM state machine | FSM diagram | New (inverse of entdaa_fsm) | Should |
| F43 | 6.9 | Sim waveform: full ENTDAA round | wavedrom/timing | New | Should |
| F44 | 6.9 | Sim waveform: Private Write OD→PP | wavedrom/timing | New | Should |
| F45 | 6.9 | Sim waveform: Private Read T-bit | wavedrom/timing | New | Should |
| F46 | 6.9 | Sim waveform: I2C 400 kHz write | wavedrom/timing | New | Should |
| F47 | 6.8 | Coverage report screenshot | PNG/screenshot | New | Should |
| F48 | 7.1 | FPGA implementation flow | Flow pipeline | New | Should |
| F49 | 7.5 | Resource utilization bar chart | pgfplots bar | New | Should |
| F50 | 7.7 | Hardware test setup photo | JPG/PNG | New (author-supplied) | Should |
| F51 | 7.8 | ILA capture: START + first data byte | Screenshot | New | Should |
| F52 | 7.8 | ILA capture: full ENTDAA | Screenshot | New | Should |
| F53 | 7.8 | ILA capture: OD→PP transition | Screenshot | New | Should |
| F54 | 7.8 | ILA capture: I2C write | Screenshot | New | Should |
| F55 | 7.9 | Sim vs ILA overlay | Dual waveform | New | Should |

**Total figures:** ~55 (47 Must/Should, 8 Nice-to-have optional)

### 4.2 Tables Inventory

| ID | Chapter | Title | Content | Source | Priority |
|----|---------|-------|---------|--------|----------|
| T1 | 2 | I3C vs I2C features | Frequency, signaling, addressing, etc. | phase1 §3 | Must |
| T2 | 2 | CCCs supported | Code, mnemonic, description (3 rows) | phase1 §4.2 | Must |
| T3 | 2 | BCR fields | Bits [7:0], field names, meanings | phase1 §5.1 | Should |
| T4 | 2 | I3C SDR timing parameters | Symbols, min/max, units, notes | phase1 §7.1 | Must |
| T5 | 2 | I2C FM timing parameters | Symbols, min/max, units | phase1 §7.2 | Must |
| T6 | 3 | 9 key modules in reference design | Name, file, role (3 cols) | phase1 §8.2 | Should |
| T7 | 3 | Reuse/Simplify/Rewrite/Improve classification | All 16 modules with action + rationale (3 cols) | phase1 §8.3 | Must |
| T8 | 3 | Out-of-scope reference modules | Name, reason for exclusion (9 modules) | phase1 §8.4 | Should |
| T9 | 3 | LoC reduction summary | Module, reference, thesis, reduction % (4 cols) | Aggregated specs | Must |
| T10 | 4 | HCI queue inventory | Queue name, width, depth, direction (4 cols) | spec 06 §1 | Must |
| T11 | 4 | Command descriptor formats | Immediate / Regular / AddressAssign layout (3 rows) | spec 06 §5.2 | Should |
| T12 | 4 | Configurable parameters | Parameter, default, description (3 cols) | phase1 §10.1 | Should |
| T13 | 4 | Design decisions and rationale | Decision, choice, rationale (3 cols) | phase1 §10.2 | Should |
| T14 | 5 | Module port table (×16) | Signal name, direction, width, description | Each spec §4 | Must |
| T15 | 5 | Module FSM state/output table (per FSM) | State, outputs, transitions | Each spec §5–6 | Must |
| T16 | 6 | Test list with priority | Name, priority (1–5), status | implementation_plan §5 | Should |
| T17 | 6 | Coverage groups with targets | Coverpoint, target % | New | Should |
| T18 | 6 | Assertions summary | Assertion name, property, severity | New | Should |
| T19 | 6 | Regression results | Test name, seeds, pass/fail counts | New (*placeholder*) | Optional |
| T20 | 7 | Target FPGA specifications | Device, package, speed, LUT/FF/BRAM | New (*missing*) | Must-supply |
| T21 | 7 | Resource utilization per module | LUT, FF, BRAM, DSP per module + total | New (*placeholder*) | Must-fill |
| T22 | 7 | Timing summary | Clock period, WNS, WHS, etc. | New (*placeholder*) | Must-fill |
| T23 | 7 | On-board test matrix | Scenario, pass/fail, notes | New (*placeholder*) | Must-fill |
| T24 | A | Full register map | Offset, name, R/W, reset, bits, description | spec 07 §5.1 | Appendix |
| T25 | B | Descriptor formats (bit-level) | All three CMD types + RESP (5 tables) | spec 06 §5.2 + spec 09 §5.3 | Appendix |
| T26 | C | Timing register computations | Parameter, I3C value, I2C value, derivation | spec 03 §7 | Appendix |

**Total tables:** ~26 (16 in main chapters, 10 in appendices)

---

## 5. LaTeX Writing Suggestions per Section

### 5.1 Document Class and Packages

**Basic template:**

```latex
\documentclass[12pt,a4paper,oneside]{report}
\usepackage[utf8]{inputenc}
\usepackage[T5]{fontenc}              % Vietnamese support
\usepackage[vietnamese,english]{babel}

\usepackage{geometry}
\geometry{a4paper,margin=2.5cm,bindingoffset=1cm}

% Figures and diagrams
\usepackage{graphicx}
\usepackage{tikz, pgfplots}
\usetikzlibrary{positioning, arrows.meta, shapes.geometric, fit, automata}

% Tables
\usepackage{booktabs, longtable, array, multirow, multicolumn}

% Captions and references
\usepackage{caption, subcaption}
\usepackage{hyperref}
\usepackage{cleveref}

% Acronyms
\usepackage{glossaries}

% Units (timing, frequency)
\usepackage{siunitx}
\sisetup{detect-all=true}

% Waveforms
\usepackage{tikz-timing}  % or wavedrom package

% Source code (SystemVerilog)
\usepackage{listings}
\lstset{
  language=Verilog,
  basicstyle=\ttfamily\small,
  breaklines=true,
  columns=fullflexible,
  commentstyle=\color{gray},
  keywordstyle=\color{blue},
  stringstyle=\color{red}
}

\usepackage{color}
\usepackage{xcolor}

% Bibliography
\usepackage[vietnamese,english]{babel}
```

### 5.2 Chapter-Specific Writing Guidelines

#### Chapter 2 (Theory)
- Use `\SI{}{}` for all timing values: `\SI{12.5}{\MHz}`, `\SI{24}{\ns}`
- Render mermaid sequence diagrams to PDF and embed with `\includegraphics`
- Use `tikz-timing` or `wavedrom` for waveforms
- Define consistent notation: `\texttt{SCL}`, `\texttt{SDA}`, `\texttt{I3C\_RSVD\_ADDR}`
- Cross-reference timing tables when deriving system clock requirement

#### Chapter 3 (Methodology)
- Use `longtable` for LoC reduction table (spans pages)
- Use `\cref{tab:loc_reduction}` for cross-references
- Side-by-side comparison figures: `subfigure` environment
- Include rationale column in classification table for clarity

#### Chapter 4 (Architecture)
- Define a `tikzset` style for consistency:
  ```latex
  \tikzset{
    block/.style={rectangle, draw, minimum width=2cm, minimum height=1cm},
    fifo/.style={trapezium, trapezium left angle=70, trapezium right angle=110, draw}
  }
  ```
- Use consistent signal naming in figures: `\texttt{cmd_queue_rvalid_i}` etc.
- Cross-reference architecture elements in subsequent chapters

#### Chapter 5 (RTL Design)
- Define SystemVerilog `lstdefinelanguage` with I3C-specific keywords
- Keep code snippets short (≤10 lines in main text); full listings in Appendix D
- FSM diagrams: use TikZ `automata` library for consistency
- Tables for ports, FSM states, parameters: use `booktabs` for professional appearance
- State description prose should match FSM node labels exactly

#### Chapter 6 (UVM)
- Simulation waveforms: PNG/PDF exports from QuestaSim/VCS
- Coverage tables: use bar charts with `pgfplots` for visual clarity
- Test matrix table: use `\checkmark` and `\times` symbols for pass/fail
- Assertions: show one or two exemplary SVA properties in main text

#### Chapter 7 (FPGA)
- Resource utilization: bar chart with `pgfplots` imported from CSV
- Timing summary table: highlight critical paths with `\textbf{}`
- Hardware photos: use `figure` environment with detailed captions
- ILA captures: annotate with arrows/boxes to highlight key signals
- Sim-vs-HW waveform overlay: use transparent layers or dual y-axes

#### Chapter 8 (Conclusion)
- Future work: consider a roadmap diagram showing 10 enhancements and their dependencies
- Limitations: be honest about trade-offs made vs. the reference design

### 5.3 Acronym and Symbol Management

**Define glossary early:**

```latex
\newacronym{i3c}{I3C}{Improved Inter-Integrated Circuit}
\newacronym{scl}{SCL}{Serial Clock Line}
\newacronym{sda}{SDA}{Serial Data Line}
\newacronym{od}{OD}{Open-Drain}
\newacronym{pp}{PP}{Push-Pull}
% ... 25+ more
```

**Use throughout:** `\gls{i3c}` (first use: "I3C (Improved Inter-Integrated Circuit)"), then `\glspl{i3c}` for plurals.

### 5.4 Bibliography Setup

**IEEE style recommended:**

```latex
\bibliographystyle{IEEEtran}
\bibliography{references.bib}
```

**Key references to include:**
1. MIPI Alliance. "Specification for I3C Basic, Version 1.1.1 (with Errata 01)." 2022.
2. CHIPS Alliance. "i3c-core — Open-source I3C controller/target reference implementation." [GitHub](https://github.com/chipsalliance/i3c-core)
3. NXP Semiconductors. "UM10204 I2C-bus specification and user manual, Rev. 7.0." 2021.
4. ARM. "Cortex-M0 Devices Generic User Guide." (for background on microcontroller integration)

### 5.5 Naming Conventions in Prose

- **Signal names:** `\texttt{signal_name}` (monospace)
- **Module names:** `\texttt{module\_name}`
- **Register names:** `\texttt{HC\_CONTROL}`, `\texttt{T\_LOW\_REG}`
- **Numeric constants:** hex as `0x7E` or `\texttt{8'h07}`; decimal as bare numbers or in `\SI{}`
- **Acronyms:** `\gls{i3c}` (defined in glossary)

### 5.6 Cross-Referencing

Use `\label` and `\cref` consistently:

```latex
\section{Bus Topology}
\label{sec:bus_topology}

As described in \cref{sec:bus_topology}, ...

\begin{figure}
  \centering
  \includegraphics{bus_topology.pdf}
  \caption{I3C bus topology.}
  \label{fig:bus_topology}
\end{figure}

\cref{fig:bus_topology} shows...
```

---

## 6. Suggested Writing Order and First-Drafts Priority

### 6.1 Recommended Writing Sequence

**Phase 1: Foundational (Weeks 1–2)**
1. **Chapter 2 — Theory.** Write from `phase1_spec_v2.md` §§2–7. This chapter is entirely specification-driven and has no dependencies on design choices. Getting the protocol right first ensures subsequent chapters rest on solid ground.
2. **Front matter.** Abstract, table of contents, list of abbreviations. These can be updated later but help structure the document.

**Phase 2: Design Justification (Weeks 2–3)**
3. **Chapter 3 — Reference & Methodology.** Build on Chapter 2. Explain why we study the reference, what we extract, and what we improve. Use the "Changes from Reference Design" tables from every spec.
4. **Chapter 4 — Architecture.** Still top-down; depends on Chapter 2 (protocol) and Chapter 3 (reference choices) but not on detailed module descriptions.

**Phase 3: RTL Deep Dive (Weeks 4–8 — Longest phase)**
5. **Chapter 5 — Module-Level RTL.** Write in Phase order (0 → 4):
   - **5.1 (Packages):** Shortest, easiest — 3 pages. Write first for quick confidence boost.
   - **5.2–5.3 (Phases 1):** Leaf modules; write in dependency order (PHY → edge_detector/stable → bus_monitor → scl_generator → TX/RX). Each sub-section is ~1–4 pages; 16 pages total. *Risk: scl_generator FSM diagram is complex; allocate extra time.*
   - **5.5 (Phase 2):** 6 pages. FIFOs and CSR are simpler than FSMs; lower risk.
   - **5.6–5.7 (Phase 3):** ENTDAA + flow_active = 27 pages. **Highest risk section.** Schedule this for a dedicated review with supervisor. flow_active is the most complex module (13 states, 3 sub-cases of I3CWriteImmediate). Recommend: draft skeleton first, get feedback, then fill details.
   - **5.8 (Phase 4):** Structural wiring; 6 pages. Lower risk after others are clear.

**Phase 4: Verification (Weeks 8–10)**
6. **Chapter 6 — UVM Verification.** Depends on Chapter 5 (need to understand what's being tested). Structure can be drafted now; results filled in after sims run.
   - *Note:* Simulation runs may happen in parallel (Weeks 6–10); don't wait for completion to start writing.

**Phase 5: Implementation (Weeks 10–14)**
7. **Chapter 7 — FPGA Implementation.** Methodology sections can be drafted early; results (Sec. 7.5–7.11) depend on FPGA bring-up. *Much of this is placeholder until on-board validation is complete.*

**Phase 6: Closing (Weeks 14–16)**
8. **Chapter 1 — Introduction.** Write *after* body chapters are done. It's easier to introduce a completed design than to anticipate one. Takes 1–2 days.
9. **Chapter 8 — Conclusion.** Also written near the end; builds on earlier chapters. Takes 1 day.
10. **Back matter.** Appendices, references. Ongoing as document develops.

### 6.2 First-Draft Priority

**If supervisor requests early check-in:**

- **Tier 1 (submit first):** Chapters 2 + 3 + 4. These form a coherent "design rationale" document (40 pages) and don't require implementation to be complete.
- **Tier 2 (after implementation starts):** Chapter 5 §§5.1–5.5 (Phases 0–2). These modules are lower-risk and can be finalized early.
- **Tier 3 (after protocol logic is working):** Chapter 5 §§5.6–5.7 (Phases 3). Critical review point.
- **Tier 4 (after full sim passes):** Chapter 6. Requires verification results.
- **Tier 5 (after FPGA bring-up):** Chapter 7. Requires hardware results.

### 6.3 Sections Requiring Diagrams (Non-Negotiable)

**Must include figures:**
- All FSM descriptions in Chapter 5 — without state diagrams, prose is unreadable
- Chapter 2 §§2.4–2.8 — sequence diagrams and protocol waveforms are essential for protocol chapters
- Chapter 4 §§4.1, 4.4–4.7 — data/control paths are communicated via block diagrams
- Chapter 6 §§6.2, 6.9 — testbench and simulation results need visual reference
- Chapter 7 §§7.8–7.9 — ILA captures and sim-vs-hardware comparison require waveforms

**Delay only if necessary:**
- F50 (hardware photo) — can substitute with description or placeholder if board testing is very late
- F47–F55 (ILA captures, coverage screenshots) — reserve until verification is far enough along
- F49 (resource util chart) — reserve until synthesis completes

### 6.4 Sections Suitable for Appendices

**Keep these out of main flow to improve readability:**
- **Appendix A:** Full register map (spec 07 §5.1–5.2) — too detailed for Chapter 4; reference as "See Appendix A"
- **Appendix B:** Descriptor bit layouts — specialized; include in Appendix, not main text
- **Appendix C:** Timing register derivations (worked examples) — useful for reproducibility but not essential for understanding architecture
- **Appendix D:** Long UVM source listings — select a few key BFM or sequence files; full code goes here, not in Chapter 6
- **Appendix E:** Synthesis reports (Vivado reports, timing summaries) — reference in Chapter 7 with key numbers in main text
- **Appendix F:** User guide (build instructions, simulation commands, FPGA programming steps) — critical for reproducibility but not part of the narrative

---

## 7. Missing Information That Still Needs to Be Prepared

**The provided documents are detailed specifications and plans; several critical pieces required for final thesis chapters are not present and must be supplied by the author.**

### 7.1 Hard-Required Information (No Thesis Possible Without)

| # | Information | Why Needed | Source | Impact |
|---|---|---|---|---|
| 1 | **Full name, ID, institution** | Front matter, title page | Author | Cannot submit without |
| 2 | **Supervisor full name + institution** | Title page, signature page | Author | Cannot submit without |
| 3 | **Defense date / submission deadline** | Front matter, timeline | Author | Cannot submit without |
| 4 | **FPGA board name and device** | Chapter 7, synthesis constraints | *Missing* | Chapter 7 incomplete |
| 5 | **Synthesizer (Vivado / Quartus version)** | Chapter 7 §7.4 | *Missing* | Cannot detail flow |
| 6 | **Simulator (QuestaSim / VCS)** | Chapter 6 §6.2 | *Missing* | Cannot document UVM setup |
| 7 | **Register-bus bridge technology** | Chapter 7 §7.3 (UART / JTAG-AXI / etc.) | *Missing* | Cannot describe SW access |
| 8 | **Actual achieved clock frequency** | Chapter 7 §7.6 (may not be 333 MHz) | *Missing* | Timing register values depend on this |

### 7.2 Data Required for Chapter 7 (FPGA) Tables

| Table | Data Needed | Unit | Source | Placeholder OK? |
|-------|---|---|---|---|
| T20 | FPGA device specs (LUT/FF/BRAM counts) | Device-specific | Tool manual | No — affects resource util |
| T21 | Actual resource utilization | LUT, FF, BRAM, DSP | Post-synthesis tool report | Yes (for draft) |
| T22 | Timing closure (WNS, TNS, WHS, THS) | Time (ns) | Timing report | Yes (for draft) |
| T23 | On-board test results (pass/fail matrix) | Pass/fail per scenario | Regression runs | Yes (for draft) |
| T21 | Performance metrics (SCL freq, throughput) | Measured values | Logic analyzer capture | Yes (for draft) |

### 7.3 Soft-Required Information (Nice-to-Have; Thesis Works Without)

| # | Information | Used In | Impact If Missing |
|---|---|---|---|
| 1 | SystemVerilog coding style guide | Chapter 5, Appendix D | Use default industry style; acceptable |
| 2 | License statement (Apache 2.0 attribution) | Front matter | Thesis should cite i3c-core origin; recommended |
| 3 | Author access to MIPI I3C spec PDF | Chapter 2, References | Cite spec if accessible; use phase1_spec_v2.md as proxy |
| 4 | Formal Verification Plan (V-Plan) document | Preamble to Chapter 6 | Not required; referenced test scenarios suffice |
| 5 | Coverage closure plan with numerical goals | Chapter 6 §6.8 | Can state qualitative goals instead (100% functional, ≥90% FSM coverage) |
| 6 | Regression test log (full pass/fail history) | Chapter 6 §6.11 | Can summarize final results without historical log |

### 7.4 Items Requiring Author Effort (Not in Provided Specs)

| # | Item | Effort | Timeline | Priority |
|---|---|---|---|---|
| 1 | All FSM diagram renderings (TikZ or mermaid→PDF) | ~4 hours per FSM × 7 = 28 hours total | Start week 4 | High |
| 2 | All waveform diagrams (tikz-timing or wavedrom) | ~2 hours per waveform × 10 = 20 hours | Weeks 5–6 | High |
| 3 | Synthesis flow setup and first runs | ~16 hours | Week 10 | High |
| 4 | FPGA board bring-up and on-board testing | ~24 hours | Weeks 11–14 | High |
| 5 | Logic analyzer capture and annotation | ~8 hours | Week 13 | Medium |
| 6 | Coverage report generation and analysis | ~4 hours | Week 9 | Medium |
| 7 | Hardware setup photo and setup writeup | ~2 hours | Week 11 | Low |

### 7.5 Information Status Checklist

Print and update weekly:

```
Metadata:
  [ ] Author name confirmed
  [ ] Supervisor name confirmed
  [ ] Institution name confirmed
  [ ] Defense date set
  
RTL Implementation:
  [ ] All 16 modules coded
  [ ] All modules synthesize (no errors)
  [ ] Module LoC counted and verified
  
Simulation (UVM):
  [ ] UVM testbench built
  [ ] All 5 tests run
  [ ] Coverage data collected
  [ ] All assertions pass
  [ ] Regression stable (seed 1–100)
  
FPGA Implementation:
  [ ] Board selected (device name: _______)
  [ ] Synthesizer installed (Vivado / Quartus: _______)
  [ ] Clock frequency determined (achieved: _____ MHz)
  [ ] Timing registers computed for actual clock
  [ ] Resource utilization known (LUT: _____, FF: _____)
  [ ] Timing closure met (WNS: _____ ns)
  [ ] On-board test passed (_____ scenarios)
  [ ] ILA captures collected (_____ waveforms)
  
Documentation:
  [ ] Chapter 1 (Intro) drafted
  [ ] Chapter 2 (Theory) completed
  [ ] Chapter 3 (Methodology) completed
  [ ] Chapter 4 (Architecture) completed
  [ ] Chapter 5 (RTL) completed
  [ ] Chapter 6 (UVM) completed
  [ ] Chapter 7 (FPGA) completed
  [ ] Chapter 8 (Conclusion) completed
  [ ] All figures rendered
  [ ] All tables filled
  [ ] References complete
  [ ] Appendices written
  
Final:
  [ ] Spell-check & grammar pass
  [ ] Supervisor review
  [ ] Final edits
  [ ] PDF compiled
  [ ] Printed & bound
```

---

## Appendix: Quick Reference

### A. Source Document Map

| Spec File | Purpose | Chapters Ref |
|-----------|---------|---|
| `phase1_spec_v2.md` | High-level design, architecture, protocol | 1, 2, 3, 4 |
| `implementation_plan.md` | RTL phases, sequencing, risks | 5, 6 |
| `01_i3c_phy_spec.md` | PHY module | 5.2 |
| `02_bus_monitor_spec.md` | Bus monitor | 5.2 |
| `03_scl_generator_spec.md` | SCL generator | 5.3 |
| `04_bus_tx_spec.md` | TX serializer | 5.4 |
| `05_bus_rx_flow_spec.md` | RX deserializer | 5.4 |
| `06_hci_queues_spec.md` | HCI queues & FIFO | 5.5 |
| `07_csr_registers_spec.md` | CSR register interface | 5.5 |
| `08_ccc_processor_spec.md` | ENTDAA engine | 5.6 |
| `09_flow_active_spec.md` | Command FSM | 5.7 |
| `10_controller_active_spec.md` | Controller wrapper | 5.8 |
| `11_i3c_controller_top_spec.md` | Top-level integration | 5.8 |
| `improvements.md` | Design decisions & simplifications vs. reference (quantitative + rationale) | 3, 5 |
| `Vo_Minh_Huy_Graduation_Thesis_Outline.pdf` | Original submitted thesis outline; reference for structure and front matter | 1, 2 |

### B. Key Figures by Chapter

| Chapter | # Figs | Key Diagrams |
|---------|--------|---|
| 1 | 0 | — |
| 2 | 8 | Protocol waveforms (F4, F6, F7, F8) |
| 3 | 2 | Hierarchy comparison (F9, F10) |
| 4 | 7 | Data paths (F13, F14), MUX (F16) |
| 5 | 25 | FSM diagrams (F22, F24, F25, F27, F32, F33, F35), timing (F23, F26, F34) |
| 6 | 7 | UVM arch (F41), sim waveforms (F43–F46) |
| 7 | 8 | Resource chart (F49), ILA (F51–F54), sim-vs-HW (F55) |
| 8 | 0 | — |

### C. Estimated Thesis Statistics

| Metric | Estimate |
|--------|----------|
| Total pages | 180–240 |
| Main text pages | 150–180 |
| Appendices pages | 30–60 |
| Figures | ~55 |
| Tables | ~26 |
| Module spec files | 11 |
| Total LoC in thesis (content only) | 8,000–12,000 lines of LaTeX |
| Recommended writing time | 10–14 weeks full-time |

---

**End of Master Plan**

*This document serves as the complete, structured roadmap for writing the thesis "Design of an I3C Communication Controller" by Vo Minh Huy. Each section, chapter, figure, and table is mapped to source material or identified as placeholder requiring author input. Use this plan to drive chapter-by-chapter writing, prioritize efforts, and coordinate with supervisor for reviews.*
