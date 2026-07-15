# Thesis Draft — "Design of an I3C Communication Controller"

**Author:** Vo Minh Huy (22207042) · **Supervisor:** ThS. Nguyễn Duy Mạnh Thi · HCMUS · 10 credits
**Status:** Section-level *draft brief*, **restructured to the department-compliant 6-chapter layout**
(see `../thesis_writing_plan.md`). Each chapter file gives a short brief per section plus **figure/table
placeholders** (what they show, their RTL/spec source, where they go). **No figures are drawn yet** — the
placeholders are the authoring spec for the later TikZ/WaveDrom/SimVision pass.

This draft follows `../thesis_writing_plan.md` (the canonical execution guide and source inventory, now
compliant with the official KLTN format: 40–50 pp, 1–2 implementation chapters, mandated front/back matter,
≥10 references, Times New Roman 13 / 1.5 spacing). Ground-truth = current RTL
(`src/rtl/**`) + module specs + current UVM. Where older planning text disagrees, the code wins.

## Chapter files (compliant 6-chapter layout)

| File | New chapter | Folds in (old) | Sim-result dependency |
|---|---|---|---|
| `ch01_introduction.md` | 1 — Introduction | Ch.1 | none |
| `ch02_background_requirements.md` | 2 — Theoretical Background & System Requirements | Ch.2 + Ch.3 | none |
| `ch03_architecture_rtl.md` | 3 — Architecture & RTL Design ★ flagship | Ch.4 + Ch.5 | none |
| `ch04_verification.md` | 4 — Verification Methodology & UVM Environment | Ch.6 + Ch.7 | none |
| `ch05_results.md` | 5 — Results & Evaluation | Ch.9 | **all** (green regressions) |
| `ch06_conclusion.md` | 6 — Conclusion & Future Work | Ch.10 | none |
| `appendices.md` | Appendices A–E, G–I (F dropped) | App. A–I | E after sims |

> The former Chapter 8 (FPGA) is **omitted** per settled decision. FPGA appears only as one future-work
> line in §6.4. The implementation block = Ch.3 + Ch.4 = **2 chapters** (compliant with the "1–2 chapters"
> rule); theoretical basis is its own Ch.2. See the decision flag in `../thesis_writing_plan.md` §2.1.

## Page budget (main body, target 40–50 pp)

Ch.1 ≈ 4 · Ch.2 ≈ 8 ⚠️ · Ch.3 ≈ 15 ⚠️ (highest risk) · Ch.4 ≈ 9 ⚠️ · Ch.5 ≈ 7 · Ch.6 ≈ 4 → **body ≈ 47**.
Front matter, references, and appendices sit outside the cap. Appendices A–C are the
release valve for Ch.3 (full CSR map → A, descriptors → B, full FSM state tables → C).

## Placeholder conventions

Figures and tables are referenced by the F-/T- numbers fixed in the (compliant) writing plan. Inline markers:

```
> ┌─ FIGURE F3.6 — flow_active 13-state FSM  (flagship · full-page landscape) ─────────────────
> │ Shows:  Idle…WriteResp; happy-path edges + abort→WriteResp override
> │ Source: src/rtl/ctrl/flow_active.sv  (flow_fsm_state_e)
> │ Render: TikZ automata · NOT YET DRAWN
> └────────────────────────────────────────────────────────────────────────────────────────
```

```
> [TABLE T3.3 — flow_active 13-state transition table · source: flow_active.sv]  (NOT YET FILLED)
```

## Master figure list (renumbered to the 6-chapter layout)

### FSM diagrams — TikZ `automata` (source of truth = RTL enums)
| F# | Figure | RTL source | Status |
|---|---|---|---|
| F3.6 | `flow_active` 13-state (flagship, landscape) | `ctrl/flow_active.sv` | not drawn |
| F3.7 | `scl_generator` 13-state | `ctrl/scl_generator.sv` | drawn |
| F3.8a | `entdaa_controller` 7-state | `ctrl/entdaa_controller.sv` | not drawn |
| F3.8b | `entdaa_fsm` 8-state | `ctrl/entdaa_fsm.sv` | not drawn |

### Algorithm flowcharts — TikZ (NEW · satisfy the official "algorithm flowchart" rule)
| F# | Figure | Source | Status |
|---|---|---|---|
| F3.11 | `flow_active` command-issue flowchart | `ctrl/flow_active.sv` | not drawn |
| F3.12 | ENTDAA per-Target loop flowchart | `ctrl/entdaa_controller.sv`, `entdaa_fsm.sv` | not drawn |

### Bus-format / timing — WaveDrom (source of truth = `phase1_spec_v2.md`)
| F# | Figure | Shows | Status |
|---|---|---|---|
| F2.2 | OD vs PP phases | OD addr/ACK vs PP data; `sel_od_pp` boundary | not drawn |
| F2.3 | Bus conditions | START / Repeated START (Sr) / STOP | not drawn |
| F2.5 | ENTDAA arbitration | 7E+W·CCC·Sr·7E+R·64-bit PID/BCR/DCR·addr+parity·ACK | not drawn |
| F2.6 | register-bus protocol | single-cycle write + read-with-ready timing | not drawn |
| (Ch.2) | address byte | A6..A0 + RnW + ACK (MSB first) | not drawn |
| (Ch.2/3) | SDR write frame | S·addr+W·ACK·{data+T}×N·P | not drawn |
| (Ch.2/3) | SDR read frame | S·addr+R·ACK·{data,T=1}…{data,T=0}·P | not drawn |
| (Ch.2) | CCC frame | Broadcast CCC + Direct CCC | not drawn |

### Block / topology — TikZ (later pass)
F1.1 SoC context · F1.2 thesis roadmap · F3.1 three-layer · F3.2 top block · F3.3 transaction dataflow ·
F3.4 clock/reset · F4.1 directed-vs-random · F4.2 layered test stack ·
F4.3 TLM path · F4.4 env class hierarchy · F4.5 reg agent · F4.6 I3C agent.

### Waveform screenshots — SimVision (after sims)
F4.7 SVA binding map · F5.1 annotated write+read · F5.2 coverage screenshot ·
F5.3 implementation-size comparison chart.

Target ≈30 figures, ≈25 tables (per the compliant writing plan §4). Every figure/table must carry a
caption and be cross-referenced in the body (official format rule A6).
