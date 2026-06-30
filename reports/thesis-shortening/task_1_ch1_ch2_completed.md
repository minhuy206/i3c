# Task 1 — Shorten thesis Chapters 1 & 2 (completed)

## Chat Interface Output

Reviewed an accepted 2025 same-department thesis as a length benchmark (intro = 3 pp, theory
= ~12 pp), diagnosed the fat in our Ch.1/Ch.2, and applied the approved cuts.

Result (clean build, 0 undefined refs):

| Chapter | Before | After | Saved |
|---|---|---|---|
| Ch.1 Introduction | 6 pp | 4 pp | −2 |
| Ch.2 Theory + Requirements | 12 pp | 10 pp | −2 |
| Body (Ch.1–6) | ~54 pp | ~50 pp | −4 |
| Total document | 91 pp | 87 pp | −4 |

The body now sits at ~50 pp, but Ch.5/Ch.6 are still scaffolds that will grow, so the next
lever is Ch.3 (18 pp — relocate more to Appendices A/B/C).

## Task Overview

- **Objective:** the thesis body exceeds the ~50-page limit; shorten it, starting with Ch.1 and Ch.2.
- **Constraints:** report ground-truth policy (code wins; never cite planning docs); MIPI gate
  (no new protocol assertions introduced — cuts only remove/relocate, so gate not re-triggered).
- **Benchmark:** `docs/report/082025 BC KL 21200356 ... - Thông Lê.pdf` (accepted 2025 HCMUS
  thesis, same department/template) → intro 3 pp, theory ~12 pp, body ~56 pp / 4 chapters.

## Execution Timeline

1. Extracted the benchmark PDF text with `gs -sDEVICE=txtwrite` (no `pdftotext`/`pdfinfo`/python-pdf available).
2. Read its TOC: Ch.1 = 3 pp, Ch.2 = ~12 pp, Ch.3 (design+verification merged) = ~40 pp, Ch.4 = ~2 pp.
3. Read current Ch.1 (215 lines) and Ch.2 (520 lines, already full prose — memory note "Ch.2 not written" was stale).
4. Regenerated `report.toc` to get exact pre-cut page spans (body = 54 pp; Ch.1 = 6, Ch.2 = 12).
5. Proposed the plan; user chose "apply to both now."
6. Checked cross-refs to the three tables slated for removal (all confined to the two chapters).
7. Applied Ch.1 edits (4) and Ch.2 edits (5).
8. Full rebuild (pdflatex → bibtex → makeglossaries → 2× pdflatex); verified 0 errors / 0 undefined refs; re-measured.

## Inputs / Outputs

**Edited files**
- `docs/report/latex/chapters/01_introduction_full.tex`
  - Trimmed §1.1 motivation ~30 %; added `\cref{sec:bg-i2c}` instead of re-listing I²C limits.
  - Folded the standalone §1.3 "Scope and Constraints" into §1.2 Objectives (forward-ref to `ch:background-requirements`).
  - Deleted the contributions table `tab:contrib`; kept the enumerated C1–C3 list.
  - Collapsed §1.5 "Thesis Organisation" from 5 per-chapter paragraphs to one paragraph (`\cref` to each chapter).
- `docs/report/latex/chapters/02_background_requirements.tex`
  - Deleted duplicate timing table `tab:timing-params`; key spec numbers (tLOW/tHIGH ≥ 24 ns, tSU,DAT ≥ 3 ns,
    tSCO ≤ 12 ns) inlined into §2.10 prose; kept `tab:perf-targets`.
  - Deleted duplicate error-code table `tab:err-codes`; §2.13 now cross-refs Ch.3 `tab:err-status` and keeps the
    Nack(0x5)-vs-I2cDataNack(0x9) nuance in prose.
  - Trimmed §2.4 OD/PP RTL-detail paragraph (Sr boundary / broadcast-disabled mode → Ch.3).

**Build artifacts:** `docs/report/latex/report.pdf` regenerated (87 pp, 464,600 bytes); aux files cleaned.

**Memory:** added `thesis-length-benchmark.md`; updated `thesis-chapter-structure.md` + `MEMORY.md`.

## Error Handling

- No LaTeX errors. The three removed table labels (`tab:timing-params`, `tab:err-codes`, `tab:contrib`) had all
  their `\cref`/`\Cref` references rewritten or removed in the same pass; post-build grep confirms no dangling refs.
- Minor pre-existing overfull `\hbox` warnings unchanged; none introduced by these edits.

## Final Status

- **Success.** Ch.1 6→4 pp, Ch.2 12→10 pp, body ~54→~50 pp, total 91→87 pp. Clean full-chain build, 0 undefined refs.
- **Guiding rule applied:** define-once / reference-elsewhere — RTL behaviour → Ch.3, verification → Ch.4, Ch.2 keeps theory + requirement tables.
- **Follow-up (not yet done):** Ch.3 (18 pp) is the next shortening target — relocate full CSR map / descriptor / FSM tables to Appendices A–C; Ch.5/Ch.6 still to be written (will add pages).
