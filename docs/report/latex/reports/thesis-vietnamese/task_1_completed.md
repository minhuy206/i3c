# Task 1 — Vietnamese thesis: pilot (Chapter 2) — COMPLETED

## Chat Interface Output

Created a **parallel Vietnamese build** of the thesis (English version untouched).
`report_vi.tex` → `report_vi.pdf` (55 pages, clean build, 0 undefined references).

This first pass is the **Chapter 2 pilot** to lock Vietnamese technical terminology:
- **Chapter 2** is fully translated (~4,000 words: I²C recap, I3C SDR frame format,
  bus conditions, OD/PP signalling, ENTDAA, CCC, I3C-vs-I²C matrix, UVM, and Part B
  requirements/spec). The Figure 2.1 frame diagram and all 7 tables are localized.
- **Chapters 1, 3–6 and the appendices** are lightweight Vietnamese **stubs**
  (title + label only) so chapter numbering and cross-references resolve cleanly.
- **Furniture** is Vietnamese (MỤC LỤC, CHƯƠNG, Hình, Bảng, DANH MỤC TỪ VIẾT TẮT…);
  front-matter pages translated (LỜI CẢM ƠN, LỜI CAM ĐOAN, TÓM TẮT–ABSTRACT with the
  Vietnamese abstract first); cover headers stay Vietnamese (official university name).
- **Terminology policy applied:** technical terms kept in English (I3C, SDR, push-pull,
  open-drain, FSM, CSR, FIFO, START/STOP, T-Bit, RnW, ENTDAA, CCC…), prose in Vietnamese.

Next pass (your call): translate Chapter 1 (~2,500 words) and flesh out the Ch.3–6
stubs as the English skeletons mature.

## Task Overview

- **Objective:** produce a Vietnamese-language version of the graduation thesis.
- **Decisions (locked via AskUserQuestion):**
  1. Architecture — **parallel files** (`report_vi.tex` + `chapters_vi/` + `appendices_vi/`),
     non-destructive; the English `report.tex`/`chapters/` are unchanged.
  2. Scope this pass — **pilot Chapter 2 only** to agree on terminology before bulk work.
  3. Terminology — **keep English technical terms** inside Vietnamese prose.
- **Parent context:** HCMUS KLTN, "Thiết kế bộ điều khiển giao tiếp I3C".

## Execution Timeline

1. Read the English master (`report.tex`) and `chapters/02_background_requirements.tex`
   to mirror structure exactly.
2. Extracted chapter/appendix titles + labels (`ch:intro-full`, `ch:architecture-rtl`,
   `ch:verif-method`, `ch:uvm-env`, `ch:results`, `ch:conclusion`, `app:*`) so stubs
   carry the labels Chapter 2 cross-references.
3. Wrote `report_vi.tex`: Vietnamese furniture, algorithm labels, cleveref names,
   `\figph`/`\tabph`/`\brief` macros, front matter, abstract order (TÓM TẮT → ABSTRACT),
   `\tenKL` Vietnamese, body includes `chapters_vi/` + `appendices_vi/`.
4. Created 5 chapter stubs + 1 appendix stub (titles + labels + a Vietnamese note).
5. Translated `chapters_vi/02_background_requirements.tex` in full — prose, captions,
   table headers and descriptive cells localized; labels, citations, `\cref`, the TikZ
   figure structure, signal names, and CSR/opcode tokens preserved.
6. Built: `pdflatex → bibtex → makeglossaries → pdflatex × 2`. All passes exit 0.
7. Verified visually by rendering pages to PNG (Ghostscript).

## Inputs / Outputs

**Inputs (read only):** `report.tex`, `chapters/02_background_requirements.tex`,
chapter/appendix headers, `myacronyms.sty`.

**Outputs (new files):**
- `report_vi.tex` — Vietnamese master.
- `chapters_vi/01_introduction_full.tex`, `03_architecture_rtl.tex`,
  `04_verification.tex`, `05_results.tex`, `06_conclusion.tex` — stubs.
- `chapters_vi/02_background_requirements.tex` — full translation (pilot).
- `appendices_vi/appendices.tex` — appendix stubs (7 chapters).
- `report_vi.pdf` — 55 pages (build artifact).

**Unchanged:** the entire English thesis (`report.tex`, `chapters/`, `appendices/`).

## Error Handling

- No build errors. Final pass: **0 undefined references, 0 undefined citations,
  0 multiply-defined labels.**
- Vietnamese diacritics render via the T5/vntex fonts already in the preamble — verified
  on cover, front matter, Ch.2 prose, the TikZ figure, and the error-code table.
- Cross-references into the not-yet-translated chapters resolve because the stubs carry
  the original `\label{}`s (e.g. `chương 3`, `hình 2.1`, `mục 2.4`, `Bảng 2.7`).

## Final Status

- **Done & verified:** clean parallel Vietnamese build; Chapter 2 fully localized;
  terminology policy applied consistently.
- **Known limitation (by design):** Ch.1 and Ch.3–6 + appendices are stubs this pass.
- **Build note:** `report_vi.*` aux artifacts (`.aux/.toc/.bbl/.bcf/.glo/…`) are produced
  on build; same gitignore policy as `report.*` applies.
- **Follow-up (user's call):** Pass 2 — Chapter 1 translation + Ch.3–6 stub fill-out.
