# Chapter 5 — Results and Evaluation

> **Draft brief.** ~7 pages. **BLOCKED — write after green regressions** (`make regression` + category
> regressions; optional `COV=1`). This is the official "implementation/experimental results" chapter.
> Format = tables + annotated waveforms; avoid prose padding. Do not present results before fixing any
> outstanding critical issues and re-running. Sources: sim logs/coverage, `improvements.md`.

## 5.1 Verified baseline and measurement method

**Brief.** Record the branch, commit, tool versions, regression seed policy, and exact file-selection rules
used for all counts. Distinguish the 75 runnable scenario vseqs from the base vseq and authored RTL from
generated or third-party source. This is the canonical snapshot for volatile facts.

## 5.2 Quantitative implementation metrics

**Brief.** Recompute line counts per subsystem for this design and a pinned CHIPS Alliance revision.
Derive any percentage from disclosed counts and explain that scope exclusions make this a design-boundary
comparison, not automatically a code-density achievement. The two metrics tables moved from Ch.3 live here.

> ┌─ FIGURE F5.3 — implementation-size comparison chart ────────────────────────────────────
> │ Shows:  per-subsystem LoC this design vs reference · Render: TikZ/pgfplots · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 5.3 Regression results

**Brief.** **AFTER SIMS.** Pass/fail matrix across the verified runnable-scenario inventory with seeds.
Quote trimmed `sim.log` excerpts (Appendix E).

> [TABLE T5.4 — regression pass/fail matrix · source: sim logs]  (NOT YET FILLED — AFTER SIMS)

## 5.4 Waveform evidence

**Brief.** **AFTER SIMS.** Annotated waveforms for write, read, immediate, and CCC, cropped ≤5 µs with
TikZ overlay arrows on START/ACK/T-Bit/OD→PP/STOP.

> ┌─ FIGURE F5.1 — annotated waveforms (write + read) ── SimVision · AFTER SIMS · NOT YET CAPTURED ┐

## 5.5 Functional coverage

**Brief.** Report the implemented functional coverage: run `COV=1` and present the covergroup results
(per-coverpoint + cross hit percentages) with the Xcelium IMC screenshot. State that this is the implemented
subset and full-protocol coverage closure is the planned extension (§6.4).

> ┌─ FIGURE F5.2 — coverage screenshot ── Xcelium IMC · AFTER COV RUN · NOT YET CAPTURED ┐

## 5.6 Comparison with CHIPS Alliance reference

**Brief.** Evaluate the Chapter 3 qualitative decisions with the metrics and verified feature evidence in
this chapter. State that all 13 `flow_active` states are implemented and attribute the pinned reference SHA.

> [TABLE T5.5 — reference comparison · source: pinned sources + results]  (NOT YET FILLED)

## 5.7 Evaluation against requirements

**Brief.** Mark each Chapter 2 functional, performance, and verification requirement met, partially met,
or not demonstrated, citing evidence in this chapter. Defer interpretation of limitations and the roadmap
to Ch.6.
