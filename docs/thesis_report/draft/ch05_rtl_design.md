# Chapter 5 — RTL Design and Implementation ★ flagship

> **Draft brief.** Per-module write-up using the template: *purpose / interface / FSM or datapath / key
> implementation choice / verification touch-points*. Format = FSM diagrams + state-transition tables +
> ≤30-line snippets; **no full file dumps**. **Start the FSM diagrams first — they are the long pole.**
> Read RTL directly; cross-ref module specs 01–11. Always attribute CHIPS Alliance `i3c-core`.

## 5.1 PHY (`i3c_phy`)

**Brief.** Purpose: 2FF metastability synchronizer on SCL/SDA inputs + OD/PP output drivers (active-low
open-drain modelling). Interface and the bypass/output-select behaviour. Key choice: minimal PHY, no pad
primitives (FPGA IOBUF deferred to future work). ~52 LoC. Spec 01.

## 5.2 CSR register file + 32-entry DAT (`csr_register`)

**Brief.** Purpose: hand-written 32-bit register file + DAT + CMD/TX staging. Interface = the 12-bit/
32-bit reg bus. Key choice: hand-written ~300 LoC vs PeakRDL auto-gen (~14k) — educational + tiny. List
the register map at overview level (full bitfields → Appendix A). Spec 07.

> [TABLE T5.2 — full CSR map (30 registers + 32-entry DAT) · source: csr_register.sv]  (NOT YET FILLED — or defer full table to Appendix A and keep a summary here)

## 5.3 HCI queues (`hci_queues` / `sync_fifo`)

**Brief.** Purpose: 4 sync FIFOs (CMD 64-bit, TX/RX/RESP 32-bit) built from one generic `sync_fifo`.
Interface = `*_valid`/`*_ready` handshakes. Key choice: power-of-2 depth enforced by an elaboration-time
assertion (`Depth must be a power of 2`) — exercised by test FIFO_005. Spec 06.

## 5.4 `bus_monitor` (START/STOP/Sr edge detection)

**Brief.** Purpose: detect START/STOP/repeated-START and bus-idle from synchronized SCL/SDA using
`edge_detector` × N + `stable_high_detector` × N. Interface + the +1 capture flop. Spec 02.

## 5.5 SCL generator (`scl_generator`, 14-state FSM)

**Brief.** Purpose: generate SCL plus START/Sr/STOP/bus-free timing via a single-counter strategy (area
win vs N parallel timers). 14 states (Idle…BusFree). Key choice: DAA restart folded into `gen_rstart_i`.

> **Note (future cleanup):** `req_restart_i`/`ack_o` ports exist but the RTL routes restart through
> `gen_rstart_i` — document this as a known cleanup, not a bug.

> ┌─ FIGURE F5.2 — scl_generator 14-state FSM ──────────────────────────────────────────────
> │ Shows:  Idle…BusFree; START/Sr/STOP generation + OD-low/bus-free timing edges
> │ Source: src/rtl/ctrl/scl_generator.sv (state_e) · Render: TikZ automata · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> [TABLE T-scl — scl_generator 14-state transition table · source: scl_generator.sv]  (NOT YET FILLED)

## 5.6 TX/RX serializers (`bus_tx`, `bus_tx_flow`, `bus_rx_flow`)

**Brief.** `bus_tx_flow` (4-state byte/bit serializer) feeds `bus_tx` (5-state per-bit timing engine);
`bus_rx_flow` (4-state) deserializes. Key choice: `bus_rx_flow` emits 7 stored bits + live SDA on cycle 8
so the aligned byte is valid on `rx_done_o`. Specs 04/05.

> ┌─ FIGURE F5.4a — bus_tx 5-state FSM ─────────────────────────────────────────────────────
> │ Shows:  Idle…HoldData per-bit timing · Source: ctrl/bus_tx.sv · TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> ┌─ FIGURE F5.4b — bus_tx_flow 4-state FSM ────────────────────────────────────────────────
> │ Shows:  byte/bit serialization · Source: ctrl/bus_tx_flow.sv · TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> ┌─ FIGURE F5.4c — bus_rx_flow 4-state FSM ────────────────────────────────────────────────
> │ Shows:  RX deserialize; 7 stored + live SDA on bit 8 · Source: ctrl/bus_rx_flow.sv · TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 5.7 ENTDAA subsystem (`entdaa_controller` 7-state + `entdaa_fsm` 8-state)

**Brief.** Master-perspective rewrite of the reference's target-side logic. Outer `entdaa_controller`
(7-state) manages the DAA loop: reads DAT[round], invokes the inner FSM, increments round until
`no_device`/`bus_stop_det_i`→Done. Inner `entdaa_fsm` (8-state) does the per-device handshake: send 0x7E,
shift 64-bit PID/BCR/DCR, send {addr, parity}, return `addr_valid`; `bus_stop_det_i`→NoDev. Spec 08/08b;
`DatDepth`=32.

> ┌─ FIGURE F5.3a — entdaa_controller 7-state FSM ──────────────────────────────────────────
> │ Shows:  DAA loop manager; bus_stop_det_i→Done · Source: ctrl/entdaa_controller.sv · TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> ┌─ FIGURE F5.3b — entdaa_fsm 8-state FSM ─────────────────────────────────────────────────
> │ Shows:  per-device DAA arbitration; bus_stop_det_i→NoDev · Source: ctrl/entdaa_fsm.sv · TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 5.8 `flow_active` 14-state FSM (flagship)

**Brief.** The command-dispatch FSM and headline RTL contribution — all 14 states implemented
(Idle…WriteResp), where the reference left several issue paths TODO. Cover: state architecture; the branch
decisions out of FetchDAT (write / read / immediate / I²C / address-assignment); `I3CWriteImmediate` /
`I2CWriteImmediate` sub-cases; regular write path; regular read path; AddressAssignment (ENTDAA
invocation); abort/interrupt event ports; error consolidation and WriteResp formatting. Use the
state-transition table + the flagship diagram + ≤30-line snippets (state enum, one key `always_comb` case)
— not the full 1166-line file. Spec 09.

> ┌─ FIGURE F5.1 — flow_active 14-state FSM (FLAGSHIP · full-page landscape) ────────────────
> │ Shows:  Idle…WriteResp; happy-path edges for write/read/immediate/I²C/ENTDAA + abort→WriteResp override
> │ Source: src/rtl/ctrl/flow_active.sv (flow_fsm_state_e) · Render: TikZ automata, pdflscape · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> [TABLE T5.1 — flow_active 14-state transition table · source: flow_active.sv]  (NOT YET FILLED)
> ┌─ FIGURE F5.x — I3CWriteImmediate phase timing (optional) ───────────────────────────────
> │ Shows:  issue-phase decode for an immediate sub-case · Render: WaveDrom/TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 5.9 `controller_active` wrapper + OD/PP switching

**Brief.** Integration glue: instantiates the protocol children, arbitrates flow vs DAA for the bus,
and forms the OD/PP output (wired-AND of `scl_gen_sda & tx_flow_sda` for open-drain modelling) plus
`sel_od_pp_o` switching. Spec 10.

> ┌─ FIGURE F5.5 — OD/PP switching logic ───────────────────────────────────────────────────
> │ Shows:  wired-AND + sel_od_pp_o mux selecting OD (addr/ACK) vs PP (data)
> │ Source: ctrl/controller_active.sv · Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 5.10 Design decisions vs CHIPS Alliance reference

**Brief.** Consolidate the key choices: single-counter SCL timing; wired-AND OD modelling; RX bit-8
live-SDA alignment; master-perspective ENTDAA rewrite; 32-entry DAT; hand-written CSR; **all 14
`flow_active` states completed**. One table summarising per-module LoC + the reuse/adapt/new tag.

> [TABLE T5.3 — per-module port lists · source: RTL]  (NOT YET FILLED — or push to Appendix)
> [TABLE T5.4 — module LoC summary · source: filesystem]  (NOT YET FILLED)
