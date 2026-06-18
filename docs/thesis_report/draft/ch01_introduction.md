# Chapter 1 — Introduction

> **Draft brief.** Keep under ~8 pages. Frame the topic, justify it, declare scope, preview structure.
> Defer all architectural detail to Ch.4. Attribute CHIPS Alliance `i3c-core` (with commit SHA).
> Sources: outline PDF §1–4, `improvements.md`, `phase1_spec_v2.md` §1.

## 1.1 I3C in SoC trends & motivation

**Brief.** Establish why I3C matters: modern SoCs aggregate dozens of sensors/peripherals over slow
two-wire buses; I²C is ubiquitous but limited (open-drain speed ceiling, static addressing, no
in-band interrupts, pull-up power). MIPI I3C Basic answers these (push-pull SDR up to 12.5 MHz here,
dynamic addressing, IBI in the full spec) while staying backward-compatible with legacy I²C devices on
the same bus. Motivate a *simplified single-master controller* as a meaningful, self-contained
front-end digital-IC design exercise (RTL → UVM).

> ┌─ FIGURE F1.1 — I3C in an SoC context ───────────────────────────────────────────────────
> │ Shows:  application processor + I3C controller driving mixed I3C/I²C sensor devices on one bus
> │ Render: TikZ block diagram · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 1.2 Problem statement & objectives

**Brief.** Problem: the CHIPS Alliance `i3c-core` reference is a full-featured (~25k-line) HCI-compliant
design that is hard to study and leaves several `flow_active` FSM states as TODO. Objective: derive an
aggressively simplified (~2k-line, ~92% reduction) single-master controller that *completes* all 14
`flow_active` states, then verify it in a dual-agent UVM 1.2 environment. State the concrete deliverables:
working SDR write/read/immediate + I²C-FM + ENTDAA + ENEC/DISEC, plus a regression suite.

## 1.3 Scope and constraints

**Brief.** In scope: SDR private write/read, immediate (≤4 inline bytes) transfers, I²C Fast-Mode
400 kHz legacy traffic, START/Sr/STOP/bus-idle handling, OD↔PP switching, ENTDAA dynamic addressing,
ENEC/DISEC CCCs, 32-bit register interface, 32-entry DAT, 4 sync FIFOs. Out of scope (deliberate):
IBI, Hot-Join, HDR (DDR/TSP/TSL), I²C FM+ (1 MHz), multi-master, Target/slave mode, bus recovery, full
HCI/DCT, all other CCCs. Constraint: single clock domain, ≥333 MHz system clock to meet SCL timing.

> [TABLE T1.2 — in-scope vs out-of-scope summary · source: `phase1_spec_v2.md`, scope analysis]  (NOT YET FILLED)

## 1.4 Contributions

**Brief.** Headline contributions, to be refined after Ch.9 numbers settle:
1. **All 14 `flow_active` states implemented** — the reference leaves several issue paths as TODO.
2. **~92% LoC reduction** (~25k → ~2k) while preserving SDR + I²C + ENTDAA functionality.
3. **Dual-agent UVM 1.2 environment** (register agent + I3C device-mode agent) with scoreboard + SVA.
4. First ENTDAA-capable master controller built in the lab.

> [TABLE T1.1 — contributions summary · refine numbers after Ch.9]  (NOT YET FILLED)

## 1.5 Thesis organisation

**Brief.** One short paragraph per chapter (2→10) mapping the reading path: Background → Requirements →
Architecture → RTL → Verification methodology → UVM environment → Results → Conclusion. Note Ch.8 (FPGA)
is omitted and appears only as future work.

> ┌─ FIGURE F1.2 — thesis-organisation roadmap ─────────────────────────────────────────────
> │ Shows:  chapter dependency/reading-order flow (Theory→RTL→UVM→Results)
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
