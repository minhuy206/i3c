# Chapter 1 — Introduction

> **Draft brief.** Keep to ~4 pages (per the compliant page budget). Frame the topic, justify it, declare
> scope, preview structure. State the official Introduction items — *objectives, scope, results achieved,
> methods*. Defer all architectural detail to Ch.3. Attribute CHIPS Alliance `i3c-core` (with commit SHA).
> Sources: outline PDF §1–4, `improvements.md`, `phase1_spec_v2.md` §1.

## 1.1 I3C in SoC trends & motivation

**Brief.** Establish why I3C matters: modern SoCs aggregate dozens of sensors/peripherals over slow
two-wire buses; I²C is ubiquitous but limited (Open Drain (OD) speed ceiling, Static Address only, no
In-Band Interrupt, pull-up power). MIPI I3C Basic answers these (Push-Pull (PP) SDR up to 12.5 MHz here,
Dynamic Address Assignment, In-Band Interrupt (IBI) in the full spec) while staying backward-compatible
with legacy I²C Targets on the same bus. Motivate a *simplified single-Controller design* as a meaningful,
self-contained front-end digital-IC design exercise (RTL → UVM).

> ┌─ FIGURE F1.1 — I3C in an SoC context ───────────────────────────────────────────────────
> │ Shows:  application processor + I3C Controller driving mixed I3C/I²C Target devices on one bus
> │ Render: TikZ block diagram · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 1.2 Problem statement & objectives

**Brief.** Problem: the CHIPS Alliance `i3c-core` reference is a full-featured HCI-compliant design whose
production scope is hard to study and whose `flow_active` command issue paths include TODO stubs. Objective:
derive a substantially simplified single-Controller design that completes all 13 `flow_active` states,
then verify it in a dual-agent UVM 1.2 environment. State the concrete deliverables:
working SDR write/read/immediate + I²C-FM + ENTDAA + ENEC/DISEC, plus a regression suite. End with a
one-sentence **methods** statement (spec study → RTL → UVM verification, FPGA omitted) and a one-sentence
**results-achieved** preview, both required by the official Introduction rule. Leave quantitative comparison
and regression counts to Ch.5.

## 1.3 Scope and constraints

**Brief.** State only the high-level boundary: one Active Controller implementing the SDR data path,
selected CCCs, ENTDAA, and legacy I²C interoperability. Point to Ch.2 for the canonical functional,
performance, and out-of-scope requirements. Do not reproduce their detailed lists or tables here.

## 1.4 Contributions

**Brief.** Headline contributions, to be refined after Ch.5 numbers settle. Lead with the *design*
contribution, not the size figure:
1. **All 13 `flow_active` states implemented** — completing the issue paths the reference leaves as TODO.
2. **A compact, studyable single-Controller design** spanning the PHY → protocol → register layers in
   a deliberately bounded scope, retaining SDR + I²C-FM + ENTDAA. The reproducible size comparison belongs
   only in Ch.5.
3. **Dual-agent UVM 1.2 environment** (register agent + I3C Target agent) with scoreboard + SVA.
4. First ENTDAA-capable Active Controller built in the lab.

> [TABLE T1.1 — contributions summary · refine numbers after Ch.5]  (NOT YET FILLED)

## 1.5 Thesis organisation

**Brief.** One short paragraph per chapter (2→6) mapping the reading path: Background & Requirements →
Architecture & RTL Design → Verification Methodology & UVM Environment → Results → Conclusion. Note the
former FPGA chapter is omitted and appears only as one future-work line in §6.4.

> ┌─ FIGURE F1.2 — thesis-organisation roadmap ─────────────────────────────────────────────
> │ Shows:  chapter dependency/reading-order flow (Background→Design→Verification→Results)
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
