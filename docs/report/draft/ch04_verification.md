# Chapter 4 — Verification Methodology and UVM Environment

> **Draft brief.** ~9 pages ⚠️ — consolidated implementation-block chapter 2. Part A explains *how* the
> design was verified (methodology); Part B walks *what* exists (the environment), bottom-up. Write the
> structure independently of simulation results. Format = pseudocode + topology/component diagrams; avoid raw
> UVM source dumps. Write scoreboard/SVA descriptions from source — never use the stale "minimal" label.
> Re-enumerate vseqs for Ch.5/App. I, while this chapter keeps only compact categories. Sources: verification
> specs 00/03/04/05 + 06–09, `i3c_scoreboard.sv`, `tb_i3c_top.sv`, `i3c_driver.sv`, `i3c_monitor.sv`,
> `i3c_base_vseq.sv`, `i3c_vseq_list.sv`, `Makefile`, `i3c_vseqs/**`, `sva/**`, UVM 1.2 (Context7).

---
## Part A — Verification methodology
---

## 4.1 Verification goals & scope

**Brief.** State the closure criteria: functional correctness of SDR write/read/immediate + I²C-FM +
ENTDAA + ENEC/DISEC, scoreboard self-checking, zero SVA failures, and functional coverage collected under
`COV=1`. State the method plainly — directed virtual sequences + a self-checking scoreboard + bound SVA +
functional covergroups. This chapter defines the method; Ch.5 owns the evidence and Ch.6 owns limitations.

> [TABLE T4.1 — verification goals vs evidence · source: spec 00]  (NOT YET FILLED)

## 4.2 Directed-vs-constrained-random rationale

**Brief.** Justify directed-first: protocol bring-up needs deterministic, debuggable stimulus to pin
each FSM path before randomization adds value. Functional coverage is collected on top of the directed
stimulus through covergroups sampled under `COV=1`.

> ┌─ FIGURE F4.1 — directed-vs-random rationale ────────────────────────────────────────────
> │ Shows:  coverage-vs-effort tradeoff; where directed stops and CRV begins
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 4.3 Why UVM 1.2 + Xcelium

**Brief.** Justify the toolchain explicitly (do not merely state it): UVM 1.2 (CDNS-1.2 bundle) for the
standard component/factory/TLM model; Xcelium (`xrun`) + SimVision for sim/debug. Justify a custom register
agent over `uvm_reg` given the simple addr/wen/ren bus.

> [TABLE T4.2 — tool/methodology choices + rationale]  (NOT YET FILLED)

## 4.4 Layered test stack

**Brief.** test → virtual sequence → {reg sequences, I3C device sequences} → DUT, with the register
agent driving the 32-bit bus and the I3C Target agent responding on the bus. Pseudocode for a
representative vseq.

> ┌─ FIGURE F4.2 — layered test stack ──────────────────────────────────────────────────────
> │ Shows:  test→vseq→reg/i3c seqs→agents→DUT layering
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 4.5 TLM analysis path & scoreboard strategy

**Brief.** Describe (from `i3c_scoreboard.sv`) the analysis path monitor→scoreboard and the cross-checks:
read/write data, T-Bit (Transition Bit), RX/TX byte packing, Common Command Code (CCC), Device Address
Table (DAT) entries, SW-reset, response-priority, and end-of-test residue. Emphasise it is a substantive
scoreboard, not a stub.

> ┌─ FIGURE F4.3 — TLM path (monitor → scoreboard) ─────────────────────────────────────────
> │ Shows:  monitor analysis ports → scoreboard checkers
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 4.6 SVA checkers

**Brief.** Describe the 10 checker files in `i3c_core/sva/`: nine are bound to RTL modules and
`tb_pad_model_sva` is instantiated on the pad model. Summarise their property families and identify design
modules without a dedicated checker. This section owns the SVA structure; Ch.5 owns assertion outcomes.

> ┌─ FIGURE F4.7 — SVA binding map ─────────────────────────────────────────────────────────
> │ Shows:  9 bound checker modules + 1 instantiated pad-model checker
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> [TABLE T4.7 — 10 SVA modules (bind vs instantiate) · source: sva/**, tb_i3c_top.sv]  (NOT YET FILLED)

## 4.7 Coverage strategy

**Brief.** Functional coverage is implemented, not deferred: functional covergroups (coverpoints + crosses)
are sampled in the directed sequences and collected under `COV=1`. Define the implemented coverpoints,
crosses, sampling events, and exclusions here; report measured hit percentages only in Ch.5.

---
## Part B — UVM verification environment
---

> **Brief (part).** Walk the testbench bottom-up. Format = component diagrams + concise pseudocode;
> avoid excessive SV listings.

## 4.8 TB top & interfaces

**Brief.** `tb_i3c_top` instantiates the DUT + reg/i3c interfaces, clock/reset, the 100 ms watchdog
`uvm_fatal`, SHM dump gated by `+DUMP_WAVES`, and the SVA binds. Note reduced TB FIFO depths vs RTL to
shrink sim time.

## 4.9 Register agent

**Brief.** `dv_reg/` agent driving the 32-bit addr/wen/ren bus (driver/monitor/sequencer/cfg).

> ┌─ FIGURE F4.5 — register agent ──────────────────────────────────────────────────────────
> │ Shows:  reg agent driver/monitor/sequencer on the 32-bit bus
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 4.10 I3C Target agent (driver + monitor)

**Brief.** `dv_i3c/` Target-mode responder: `i3c_driver` with 14 Target-only phases
(`i3c_drv_phase_e`), CCC-aware `i3c_monitor` capturing protocol events. Describe the phase FSM and the
monitor's protocol state machine. The RTL-side ENTDAA loop is owned by the Chapter 3 algorithm flowchart.

> ┌─ FIGURE F4.6 — I3C Target agent (driver + monitor) ─────────────────────────────────────
> │ Shows:  driver 14-phase FSM + monitor protocol capture
> │ Source: dv_i3c/i3c_agent_pkg.sv, i3c_driver.sv, i3c_monitor.sv · Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> [TABLE T4.4 — driver 14-phase table (DrvIdle…DrvDAA) · source: i3c_agent_pkg.sv]  (NOT YET FILLED)

## 4.11 Env / vseqr / scoreboard class hierarchy

**Brief.** `i3c_env` (reg agent + i3c agent + scoreboard + virtual sequencer), the class hierarchy, and
`uvm_config_db` wiring. Reference the scoreboard checks from §4.5.

> ┌─ FIGURE F4.4 — env class hierarchy ─────────────────────────────────────────────────────
> │ Shows:  i3c_base_test→i3c_env→{reg_agent, i3c_agent, scoreboard, virtual_sequencer}
> │ Render: TikZ (redraw from print_topology) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> [TABLE T4.5 — scoreboard check list · source: i3c_scoreboard.sv]  (NOT YET FILLED)

## 4.12 Vseq library

**Brief.** Present only the compact current category summary: 75 runnable scenarios — bus 12 / CCC 5 /
CSR 15 / DAA 6 / FIFO 5 / I²C 4 / immediate 4 / response 13 / SDR read 6 / SDR write 5. Put the complete
per-sequence inventory in Appendix I; Ch.5 freezes the evidence baseline.

> [TABLE T4.3 — vseq library by category (count = re-enumerate at write time) · source: i3c_vseqs/**]  (NOT YET FILLED)

## 4.13 Build/run flow

**Brief.** Makefile targets: `compile`, `sim SEQ=…`, the 8 category regression targets (smoke,
regression, csr/fifo/bus/sdrw/sdrr/sdr regressions), `COV=1` coverage, and `DUMP_WAVES=1`; the
FIFO depth contract is covered by the RTL elaboration assertion. Note the env must be sourced
(`XCELIUM1803.sh`) first.

> [TABLE T4.6 — regression targets + SEQ lists · source: Makefile]  (NOT YET FILLED)

## 4.14 Waveform & debug (SimVision)

**Brief.** SHM dump workflow, opening `waves/<SEQ>/waves.shm` in SimVision, the events worth inspecting
(START/ACK/T-Bit/OD→PP/STOP), and the annotation procedure. The selected waveforms and interpretation belong
only in Ch.5.

## 4.15 Chapter summary and evidence hand-off

**Brief.** Map each verification requirement to its mechanism: stimulus, monitor, scoreboard, SVA, or
covergroup. Point to Ch.5 for measured evidence and Ch.6 for limitations/future work; repeat neither list.
