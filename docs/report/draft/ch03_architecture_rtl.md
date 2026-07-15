# Chapter 3 — Architecture and RTL Design ★ flagship

> **Draft brief.** ~14 pages ⚠️ **highest page risk** — this is the consolidated implementation-block
> chapter 1 (system architecture + flagship RTL). Offload full CSR map → App. A, full state tables →
> App. C, full port lists → App. B/C; keep only the flagship state table + key ports inline; ≤30-line
> snippets only, **no full file dumps**. Part A stays at block-diagram resolution; Part B is the per-module
> write-up using the template: *purpose / interface / FSM or datapath / key implementation choice /
> verification touch-points*. **Start the FSM diagrams + the F3.11/F3.12 flowcharts first — they are the long
> pole.** Read RTL directly; cross-ref module specs 01–11. Always attribute CHIPS Alliance `i3c-core`.

---
## Part A — Overall architecture design
---

> **Brief (part).** Give the system-level mental model before the per-module RTL detail in Part B. Stay at
> block-diagram resolution. Format = block diagrams + 1–2 paragraphs per block. Sources: specs 11/10,
> `improvements.md`, `CLAUDE.md` block diagram, `i3c_pkg.sv`, `controller_pkg.sv`.

## 3.1 Three-layer architecture

**Brief.** Present the design as three layers: (1) **PHY** (`i3c_phy` — 2FF metastability sync + Open
Drain / Push-Pull (OD/PP) output drivers); (2) **controller/protocol** (`controller_active` wrapping
`flow_active`, the bus serializers, `scl_generator`, `bus_monitor`, ENTDAA); (3) **host/register**
(`csr_register` + 4 sync FIFOs in `hci_queues`). Explain the separation of concerns and the design
philosophy (simplify, keep one clock domain, make the FSM the single command authority).

> ┌─ FIGURE F3.1 — three-layer architecture ────────────────────────────────────────────────
> │ Shows:  PHY · controller_active · CSR+HCI layers and their boundaries
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 3.2 Top module & block diagram

**Brief.** `i3c_controller_top` instantiates: `u_csr` (csr_register), `u_queues` (hci_queues: CMD64 +
TX/RX/RESP 32), `u_ctrl` (controller_active and its children), `u_phy` (i3c_phy). Show the full
instance hierarchy (top → 4 children → grandchildren), and the top-level port groups.

> ┌─ FIGURE F3.2 — top-level block diagram ─────────────────────────────────────────────────
> │ Shows:  i3c_controller_top → {csr, hci_queues, controller_active(→flow_active, scl_gen,
> │         bus_tx_flow→bus_tx, bus_rx_flow, bus_monitor, entdaa_controller→entdaa_fsm), phy}
> │ Source: src/rtl/i3c_controller_top.sv · Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 3.3 Transaction dataflow

**Brief.** Narrate the canonical write and read paths.
- **Write:** SW → CSR Command Descriptor staging (DWORD0 then DWORD1 → 64-bit push) → Command Queue →
  `flow_active` pops → fetches DAT entry → drives `bus_tx_flow`+`scl_generator` via `controller_active` →
  `i3c_phy` → pads → Response Queue.
- **Read:** same until `flow_active` enables `bus_rx_flow`, which samples SDA on SCL posedge, packs
  bytes into 32-bit words → RX Data Buffer → SW read.

> ┌─ FIGURE F3.3 — transaction dataflow (write + read) ─────────────────────────────────────
> │ Shows:  Host→Command Queue→flow_active→bus_tx/rx→PHY→pads→Response Queue/RX Data Buffer, both directions
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 3.4 Clock/reset & signal conventions

**Brief.** Single clock domain; async-assert active-low `rst_ni`; 2FF sync in `i3c_phy` (+1 capture flop
in `bus_monitor` = 3 flops before edge detection); synchronous SW-reset flushing FIFOs + CMD staging.
Restate signal conventions: `_i`/`_o`, `*_valid_i`/`*_ready_o`, active-low Open Drain `scl_o`/`sda_o`,
`sel_od_pp_o` (1 = Push-Pull data, 0 = Open Drain addr/ACK).

> ┌─ FIGURE F3.4 — clock/reset & 2FF sync ──────────────────────────────────────────────────
> │ Shows:  single clock domain, async-low reset, 2FF input synchronizer chain
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 3.5 Reference-derived design boundary and decisions

**Brief.** Give the chapter's single qualitative comparison: what was retained, adapted, and excluded,
and consolidate the cross-cutting choices (single-counter timing, wired-AND Open Drain modelling,
live-SDA receive alignment, Controller-perspective ENTDAA, 32-entry DAT, hand-written CSR). Attribute the
reference commit here and in captions. Ch.5 owns all line-count tables and percentages.

## 3.6 Queue / DAT / descriptor formats

**Brief.** Summarise (full bitfields go to Appendix A/B): the four HCI queues — Command Queue (64-bit),
TX/RX Data Buffers and Response Queue (32-bit), each a synchronous FIFO — the 32-entry Device Address
Table (DAT, `dat_entry_t`), the Command Descriptor variants and the Response Descriptor (`i3c_pkg.sv`,
`controller_pkg.sv`). Keep to format-overview tables here.

> [TABLE T3.1 — Queue / DAT / descriptor format overview · source: i3c_pkg.sv, controller_pkg.sv]  (NOT YET FILLED)

## 3.7 Error-handling model

**Brief.** How errors flow: detection points → `flow_active` consolidation → Response Descriptor
`err_status` field. Reference the generated error-code set (0x0/0x4/0x5/0x6/0x7/0x8/0x9/0xA). *(Present the
error-code table once — here or in §2.13.)*

> [TABLE T3.2 — error-status encoding · source: phase1_spec_v2.md §9.4]  (NOT YET FILLED)

---
## Part B — RTL design and implementation
---

> **Brief (part).** Per-module write-up with FSM diagrams + state-transition tables + ≤30-line snippets.
> Read RTL directly; cross-ref module specs 01–11.

## 3.8 PHY (`i3c_phy`)

**Brief.** Purpose: 2FF metastability synchronizer on SCL/SDA inputs + OD/PP output drivers (active-low
Open Drain modelling). Interface and the bypass/output-select behaviour. Key choice: minimal PHY, no pad
primitives. Spec 01.

## 3.9 CSR register file + 32-entry DAT (`csr_register`)

**Brief.** Purpose: hand-written 32-bit register file + DAT + Command Descriptor / TX staging. Interface
= the 12-bit/32-bit reg bus. Key choice: a hand-written implementation keeps the software contract explicit. List
the register map at overview level (full bitfields → Appendix A). Spec 07.

> [TABLE T3.4 — full CSR map (26 registers + 32-entry DAT) · source: csr_register.sv]  (NOT YET FILLED — defer full table to Appendix A; keep a summary here)

## 3.10 HCI queues (`hci_queues` / `sync_fifo`)

**Brief.** Purpose: the four HCI queues — Command Queue (64-bit), TX/RX Data Buffers and Response Queue
(32-bit) — built from one generic `sync_fifo`. Interface = `*_valid`/`*_ready` handshakes. Key choice:
power-of-2 depth enforced by an elaboration-time
assertion (`Depth must be a power of 2`) — covered by the RTL parameter contract. Spec 06.

## 3.11 `bus_monitor` (START / Repeated START (Sr) / STOP edge detection)

**Brief.** Purpose: detect START / Repeated START (Sr) / STOP and the Bus Free Condition from
synchronized SCL/SDA using `edge_detector` × N + `stable_high_detector` × N. Interface + the +1 capture
flop. Spec 02.

## 3.12 SCL generator (`scl_generator`, 13-state FSM)

**Brief.** Purpose: generate SCL plus START / Repeated START (Sr) / STOP / Bus Free Condition timing via
a single-counter strategy (area win vs N parallel timers). 13 states (Idle…BusFree). Key choice: the DAA
Repeated START folded into `gen_rstart_i`.

Describe the implemented Repeated START request and handoff through `gen_rstart_i`; do not introduce
spec-only port names or a future-work item here.

> ┌─ FIGURE F3.7 — scl_generator 13-state FSM ──────────────────────────────────────────────
> │ Shows:  Idle…BusFree; START / Repeated START (Sr) / STOP generation + OD-low / Bus Free Condition timing edges
> │ Source: src/rtl/ctrl/scl_generator.sv (state_e) · Render: TikZ automata · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> [TABLE T-scl (→ App. C) — scl_generator 13-state transition table · source: scl_generator.sv]  (NOT YET FILLED)

## 3.13 TX/RX serializers (`bus_tx`, `bus_tx_flow`, `bus_rx_flow`)

**Brief.** `bus_tx_flow` (4-state byte/bit serializer) feeds `bus_tx` (5-state per-bit timing engine);
`bus_rx_flow` (4-state) deserializes. Key choice: `bus_rx_flow` emits 7 stored bits + live SDA on cycle 8
so the aligned byte is valid on `rx_done_o`. Specs 04/05.

## 3.14 ENTDAA subsystem (`entdaa_controller` 7-state + `entdaa_fsm` 8-state)

**Brief.** Controller-perspective rewrite of the reference's Target-side logic. Outer `entdaa_controller`
(7-state) manages the DAA loop: reads DAT[round], invokes the inner FSM, increments round until no Target
responds / `bus_stop_det_i`→Done. Inner `entdaa_fsm` (8-state) does the per-Target handshake: send 0x7E,
shift the 64-bit Provisioned ID (PID) / Bus Characteristics Register (BCR) / Device Characteristics
Register (DCR), send {addr, parity}, return `addr_valid`; `bus_stop_det_i`→NoDev. Spec 08/08b;
`DatDepth`=32.

> ┌─ FIGURE F3.8a — entdaa_controller 7-state FSM ──────────────────────────────────────────
> │ Shows:  DAA loop manager; bus_stop_det_i→Done · Source: ctrl/entdaa_controller.sv · TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> ┌─ FIGURE F3.8b — entdaa_fsm 8-state FSM ─────────────────────────────────────────────────
> │ Shows:  per-Target DAA arbitration; bus_stop_det_i→NoDev · Source: ctrl/entdaa_fsm.sv · TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> ┌─ FIGURE F3.12 — ENTDAA per-Target loop algorithm flowchart ──────────────────────────────
> │ Shows:  7E+R → PID/BCR/DCR → address+parity → ACK → next round / bus-stop
> │ Source: ctrl/entdaa_controller.sv, entdaa_fsm.sv · TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 3.15 `flow_active` 13-state FSM (flagship)

**Brief.** The command-dispatch FSM and headline RTL contribution — all 13 states implemented
(Idle…WriteResp), where the reference left several issue paths TODO. Cover: state architecture; the branch
decisions out of FetchDAT (write / read / immediate / I²C / address-assignment); `I3CWriteImmediate` /
`I2CWriteImmediate` sub-cases; regular write path; regular read path; AddressAssignment (ENTDAA
invocation); abort handling; error consolidation and WriteResp formatting. Use the
state-transition table + the flagship diagram + the F3.11 algorithm flowchart + ≤30-line snippets (state
enum, one key `always_comb` case) — not the full source file. Spec 09.

> ┌─ FIGURE F3.6 — flow_active 13-state FSM (FLAGSHIP · full-page landscape) ─────────────────
> │ Shows:  Idle…WriteResp; happy-path edges for write/read/immediate/I²C/ENTDAA + abort→WriteResp override
> │ Source: src/rtl/ctrl/flow_active.sv (flow_fsm_state_e) · Render: TikZ automata, pdflscape · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> ┌─ FIGURE F3.11 — flow_active command-issue algorithm flowchart (NEW · compliance: "algorithm flowchart") ┐
> │ Shows:  FetchDAT → {write / read / immediate / I²C / address-assignment} branch decisions → WriteResp
> │ Source: src/rtl/ctrl/flow_active.sv · Render: TikZ (flowchart) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> [TABLE T3.3 (→ App. C) — flow_active 13-state transition table · source: flow_active.sv]  (NOT YET FILLED)
> ┌─ FIGURE F3.x — I3CWriteImmediate phase timing (optional) ───────────────────────────────
> │ Shows:  issue-phase decode for an immediate sub-case · Render: WaveDrom/TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 3.16 `controller_active` wrapper + OD/PP switching

**Brief.** Integration glue: instantiates the protocol children, arbitrates flow vs DAA for the bus,
and forms the OD/PP output (wired-AND of `scl_gen_sda & tx_flow_sda` for Open Drain modelling) plus
`sel_od_pp_o` switching. Spec 10.

The cross-cutting design decisions are consolidated in §3.5. Full port lists belong in Appendix B/C;
per-module implementation metrics belong in Ch.5.
