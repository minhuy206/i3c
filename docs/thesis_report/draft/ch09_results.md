# Chapter 9 — Results and Evaluation

> **Draft brief.** **BLOCKED — write after green regressions** (`make regression` + category
> regressions; optional `COV=1`). Format = tables + annotated waveforms; avoid prose padding. Do not
> present results before fixing any outstanding critical issues and re-running. Sources: sim logs/coverage,
> `improvements.md`.

## 9.1 Effort metrics

**Brief.** Engineering-effort summary: LoC per module, ~2k vs ~25k reference (~92% reduction),
reuse/adapt/new breakdown. Mostly writable now from `improvements.md` + filesystem.

> ┌─ FIGURE F9.3 — LoC-reduction bar chart ─────────────────────────────────────────────────
> │ Shows:  per-subsystem LoC this design vs reference · Render: TikZ/pgfplots · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 9.2 Phase-1 regression results

**Brief.** **AFTER SIMS.** Pass/fail matrix across all vseqs (re-enumerate count at write time; 56 at
snapshot) with seeds. Quote trimmed `sim.log` excerpts (Appendix E).

> [TABLE T9.1 — regression pass/fail matrix · source: sim logs]  (NOT YET FILLED — AFTER SIMS)

## 9.3 Waveform evidence

**Brief.** **AFTER SIMS.** Annotated waveforms for write, read, immediate, and CCC, cropped ≤5 µs with
TikZ overlay arrows on START/ACK/T-bit/OD→PP/STOP.

> ┌─ FIGURE F9.1 — annotated waveforms (write + read) ── SimVision · AFTER SIMS · NOT YET CAPTURED ┐

## 9.4 Functional coverage

**Brief.** **AFTER `COV=1` RUN (if available).** Coverage summary + screenshot; otherwise state deferral
to Phase 2.

> ┌─ FIGURE F9.2 — coverage screenshot ── Xcelium IMC · AFTER COV RUN · NOT YET CAPTURED ┐

## 9.5 Comparison with CHIPS Alliance reference

**Brief.** Functional + size comparison table: what was kept, simplified, completed (all 14 `flow_active`
states), and dropped. Attribute reference commit SHA.

> [TABLE T9.2 — reference comparison · source: improvements.md]  (NOT YET FILLED)

## 9.6 Unimplemented-feature discussion

**Brief.** Honest cost/benefit of the out-of-scope features (IBI, HDR, multi-master, target mode) and
what completing them would entail — bridges to Ch.10 future work.
