# Chapter 4 — Overall Architecture Design

> **Draft brief.** Give the system-level mental model before Ch.5's module detail. Stay at block-diagram
> resolution — all sub-module internals live in Ch.5. Format = block diagrams + 1–2 paragraphs per block.
> Sources: specs 11/10, `improvements.md`, `CLAUDE.md` block diagram, `i3c_pkg.sv`, `controller_pkg.sv`.

## 4.1 Three-layer architecture

**Brief.** Present the design as three layers: (1) **PHY** (`i3c_phy` — 2FF metastability sync + OD/PP
output drivers); (2) **controller/protocol** (`controller_active` wrapping `flow_active`, the bus
serializers, `scl_generator`, `bus_monitor`, ENTDAA); (3) **host/register** (`csr_register` + 4 sync
FIFOs in `hci_queues`). Explain the separation of concerns and the design philosophy (simplify, keep one
clock domain, make the FSM the single command authority).

> ┌─ FIGURE F4.1 — three-layer architecture ────────────────────────────────────────────────
> │ Shows:  PHY · controller_active · CSR+HCI layers and their boundaries
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 4.2 Top module & block diagram

**Brief.** `i3c_controller_top` instantiates: `u_csr` (csr_register), `u_queues` (hci_queues: CMD64 +
TX/RX/RESP 32), `u_ctrl` (controller_active and its children), `u_phy` (i3c_phy). Show the full
instance hierarchy (top → 4 children → grandchildren), and the top-level port groups.

> ┌─ FIGURE F4.2 — top-level block diagram ─────────────────────────────────────────────────
> │ Shows:  i3c_controller_top → {csr, hci_queues, controller_active(→flow_active, scl_gen,
> │         bus_tx_flow→bus_tx, bus_rx_flow, bus_monitor, entdaa_controller→entdaa_fsm), phy}
> │ Source: src/rtl/i3c_controller_top.sv · Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 4.3 Transaction dataflow

**Brief.** Narrate the canonical write and read paths.
- **Write:** SW → CSR CMD staging (DWORD0 then DWORD1 → 64-bit push) → CMD FIFO → `flow_active` pops →
  fetches DAT entry → drives `bus_tx_flow`+`scl_generator` via `controller_active` → `i3c_phy` → pads →
  RESP FIFO.
- **Read:** same until `flow_active` enables `bus_rx_flow`, which samples SDA on SCL posedge, packs
  bytes into 32-bit words → RX FIFO → SW read.

> ┌─ FIGURE F4.3 — transaction dataflow (write + read) ─────────────────────────────────────
> │ Shows:  Host→CMD FIFO→flow_active→bus_tx/rx→PHY→pads→RESP/RX, both directions
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 4.4 Clock/reset & signal conventions

**Brief.** Single clock domain; async-assert active-low `rst_ni`; 2FF sync in `i3c_phy` (+1 capture flop
in `bus_monitor` = 3 flops before edge detection); synchronous SW-reset flushing FIFOs + CMD staging.
Restate signal conventions: `_i`/`_o`, `*_valid_i`/`*_ready_o`, active-low open-drain `scl_o`/`sda_o`,
`sel_od_pp_o` (1 = push-pull data, 0 = open-drain addr/ACK).

> ┌─ FIGURE F4.4 — clock/reset & 2FF sync ──────────────────────────────────────────────────
> │ Shows:  single clock domain, async-low reset, 2FF input synchronizer chain
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 4.5 CHIPS-Alliance comparison (~92% LoC reduction)

**Brief.** The simplification story: ~25k → ~2k lines. Per-subsystem comparison (hand-written CSR vs
PeakRDL auto-gen; 32-entry vs larger DAT; no IBI/HDR/multi-master machinery; folded restart). Attribute
the reference (commit SHA) here and in captions.

> [TABLE T4.1 — per-subsystem LoC comparison · source: improvements.md]  (NOT YET FILLED)

## 4.6 FIFO/DAT/descriptor formats

**Brief.** Summarise (full bitfields go to Appendix A/B): 4 sync FIFOs (CMD 64-bit, TX/RX/RESP 32-bit),
32-entry DAT (`dat_entry_t`), the CMD descriptor variants and the RESP descriptor (`i3c_pkg.sv`,
`controller_pkg.sv`). Keep to format-overview tables here.

> [TABLE T4.2 — FIFO / DAT / descriptor format overview · source: i3c_pkg.sv, controller_pkg.sv]  (NOT YET FILLED)

## 4.7 Error-handling model

**Brief.** How errors flow: detection points → `flow_active` consolidation → RESP descriptor
`err_status` field. Reference the generated error-code set (0x0/0x4/0x5/0x6/0x7/0x8/0xA).

> [TABLE T4.3 — error-status encoding · source: phase1_spec_v2.md §9.4]  (NOT YET FILLED)
