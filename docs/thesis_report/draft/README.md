# Thesis Draft — "Design of an I3C Communication Controller"

**Author:** Vo Minh Huy (22207042) · **Supervisor:** ThS. Nguyễn Duy Mạnh Thi · HCMUS · 10 credits
**Status:** Section-level *draft brief*. Each chapter file gives a short brief per section plus
**figure/table placeholders** (what they show, their RTL/spec source, where they go). **No figures are
drawn yet** — the placeholders are the authoring spec for the later TikZ/WaveDrom/SimVision pass.

This draft follows `../thesis_writing_plan.md` (the execution guide) and `../thesis_master_plan.md`
(canonical structure). Ground-truth = current RTL (`src/rtl/**`) + module specs + current UVM. Where
older planning text disagrees, the code wins.

## Chapter files

| File | Chapter | Sim-result dependency |
|---|---|---|
| `ch01_introduction.md` | 1 — Introduction | none |
| `ch02_background.md` | 2 — Theoretical Background | none |
| `ch03_requirements.md` | 3 — System Requirements & Specifications | none |
| `ch04_architecture.md` | 4 — Overall Architecture Design | none |
| `ch05_rtl_design.md` | 5 — RTL Design & Implementation ★ flagship | none |
| `ch06_verification_methodology.md` | 6 — Verification Methodology | none |
| `ch07_uvm_environment.md` | 7 — UVM Verification Environment | §7.8 only |
| `ch09_results.md` | 9 — Results & Evaluation | **all** (green regressions) |
| `ch10_conclusion.md` | 10 — Conclusion & Future Work | none |
| `appendices.md` | Appendices A–I (F dropped) | E after sims |

> Chapter 8 (FPGA) is **omitted** per settled decision. FPGA appears only as one future-work line in §10.3.

## Placeholder conventions

Figures and tables are referenced by the F-/T- numbers fixed in the writing plan. Inline markers:

```
> ┌─ FIGURE F5.1 — flow_active 14-state FSM  (flagship · full-page landscape) ─────────────
> │ Shows:  Idle…WriteResp; happy-path edges + abort→WriteResp override
> │ Source: src/rtl/ctrl/flow_active.sv  (flow_fsm_state_e)
> │ Render: TikZ automata · NOT YET DRAWN
> └────────────────────────────────────────────────────────────────────────────────────────
```

```
> [TABLE T5.1 — flow_active 14-state transition table · source: flow_active.sv]  (NOT YET FILLED)
```

## Master figure list (≈ first-pass priority + deferred)

### FSM diagrams — TikZ `automata` (source of truth = RTL enums)
| F# | Figure | RTL source | Status |
|---|---|---|---|
| F5.1 | `flow_active` 14-state (flagship, landscape) | `ctrl/flow_active.sv` | not drawn |
| F5.2 | `scl_generator` 14-state | `ctrl/scl_generator.sv` | not drawn |
| F5.3a | `entdaa_controller` 7-state | `ctrl/entdaa_controller.sv` | not drawn |
| F5.3b | `entdaa_fsm` 8-state | `ctrl/entdaa_fsm.sv` | not drawn |
| F5.4a | `bus_tx` 5-state | `ctrl/bus_tx.sv` | not drawn |
| F5.4b | `bus_tx_flow` 4-state | `ctrl/bus_tx_flow.sv` | not drawn |
| F5.4c | `bus_rx_flow` 4-state | `ctrl/bus_rx_flow.sv` | not drawn |

### Bus-format / timing — WaveDrom (source of truth = `phase1_spec_v2.md`)
| F# | Figure | Shows | Status |
|---|---|---|---|
| F2.2 | OD vs PP phases | OD addr/ACK vs PP data; `sel_od_pp` boundary | not drawn |
| F2.3 | Bus conditions | START / repeated-START / STOP | not drawn |
| F2.4 | ENTDAA arbitration | 7E+W·CCC·Sr·7E+R·64-bit PID/BCR/DCR·addr+parity·ACK | not drawn |
| (Ch.2) | address byte | A6..A0 + RnW + ACK (MSB first) | not drawn |
| (Ch.2/5) | SDR write frame | S·addr+W·ACK·{data+T}×N·P | not drawn |
| (Ch.2/5) | SDR read frame | S·addr+R·ACK·{data,T=1}…{data,T=0}·P | not drawn |
| (Ch.2) | CCC frame | broadcast + direct CCC | not drawn |

### Block / topology — TikZ (later pass)
F1.1 SoC context · F1.2 thesis roadmap · F3.1 reg-bus protocol · F4.1 three-layer · F4.2 top block ·
F4.3 transaction dataflow · F4.4 clock/reset · F5.5 OD/PP switching · F6.1 directed-vs-random ·
F6.2 layered test stack · F6.3 TLM path · F7.1 env class hierarchy · F7.2 reg agent · F7.3 I3C agent.

### Waveform screenshots — SimVision (after sims)
F7.4 write waveform · F7.5 read waveform · F7.6 SVA binding map · F9.1 annotated write+read ·
F9.2 coverage screenshot · F9.3 LoC-reduction bar chart.

Target ≈30 figures, ≈23 tables (per master plan §8).
