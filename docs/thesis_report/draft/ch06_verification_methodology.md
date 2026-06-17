# Chapter 6 — Verification Methodology

> **Draft brief.** Explain *how* the design was verified before Ch.7 shows *what* exists. Format =
> pseudocode + UVM topology diagram; avoid raw UVM source. Write scoreboard/SVA descriptions from source
> — never use the stale "minimal" label. Sources: verification specs 00/03/04/05, `i3c_scoreboard.sv`,
> UVM 1.2 (Context7).

## 6.1 Verification goals & phase split

**Brief.** State closure goals: functional correctness of SDR write/read/immediate + I²C-FM + ENTDAA +
ENEC/DISEC, scoreboard self-checking, SVA silent. Phase-1 = directed vseqs + scoreboard + SVA;
Phase-2 = constrained-random + functional coverage + broader CCC/error injection (future work).

> [TABLE T6.1 — verification goals vs evidence · source: spec 00]  (NOT YET FILLED)

## 6.2 Directed-vs-constrained-random rationale

**Brief.** Justify directed-first: protocol bring-up needs deterministic, debuggable stimulus to pin
each FSM path before randomization adds value. Constrained-random + coverage deferred to Phase 2.

> ┌─ FIGURE F6.1 — directed-vs-random rationale ────────────────────────────────────────────
> │ Shows:  coverage-vs-effort tradeoff; where directed stops and CRV begins
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 6.3 Why UVM 1.2 + Xcelium

**Brief.** Justify the toolchain explicitly (do not merely state it): UVM 1.2 (CDNS-1.2 bundle) for the
standard component/factory/TLM model; Xcelium (`xrun`) + SimVision for sim/debug. Note the deviation from
the supervisor outline's ModelSim/Verilator/GTKWave (stale). Justify a custom register agent over
`uvm_reg` given the simple addr/wen/ren bus.

> [TABLE T6.2 — tool/methodology choices + rationale]  (NOT YET FILLED)

## 6.4 Layered test stack

**Brief.** test → virtual sequence → {reg sequences, I3C device sequences} → DUT, with the register
agent driving the 32-bit bus and the I3C device-mode agent responding on the bus. Pseudocode for a
representative vseq.

> ┌─ FIGURE F6.2 — layered test stack ──────────────────────────────────────────────────────
> │ Shows:  test→vseq→reg/i3c seqs→agents→DUT layering
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 6.5 TLM analysis path & scoreboard strategy

**Brief.** Describe (from `i3c_scoreboard.sv`) the analysis path monitor→scoreboard and the cross-checks:
read/write data, T-bit parity, RX/TX byte packing, CCC, DAT entries, SW-reset, response-priority, and
end-of-test residue. Emphasise it is a substantive scoreboard, not a stub.

> ┌─ FIGURE F6.3 — TLM path (monitor → scoreboard) ─────────────────────────────────────────
> │ Shows:  monitor analysis ports → scoreboard checkers
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 6.6 SVA checkers

**Brief.** 5 SVA files in `i3c_core/sva/`: 4 bound (`flow_active_sva`, `csr_registers_sva`,
`sync_fifo_sva`, `i3c_controller_top_sva`) + `tb_pad_model_sva` instantiated. Summarise the properties
each asserts; full list/binding map in Ch.7 §7.x.

## 6.7 Coverage strategy

**Brief.** Phase-1 deferral stated honestly; Phase-2 blueprint: covergroups for CCC×direction,
cmd-attr×direction×length, T-bit×r/w, err_status, CSR addr×access, FIFO occupancy, DAT index×is_i2c.
If a `COV=1` run is available, point forward to Ch.9 §9.4.

## 6.8 Limitations / Phase-2 gaps

**Brief.** Honest gaps: CRV + functional coverage not yet closed; CCC suite has 1 ad-hoc vseq;
multi-device + error-injection breadth limited; vseq suite is a WIP snapshot toward the ~105-case
testplan. Frame all as future work.
