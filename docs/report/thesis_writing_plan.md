# Thesis Writing Plan — "Design of an I3C Communication Controller" (HCMUS KLTN — format-compliant; design/verification 6-chapter structure)

**Author:** Vo Minh Huy (22207042) · **Supervisor:** ThS. Nguyễn Duy Mạnh Thi · HCMUS, Khoa Điện Tử – Viễn Thông · 10 credits
**Branch:** `refactor/flow-active-error-coverage` (HEAD `79ff416`) · **Re-verified against RTL+UVM:** 2026-06-28

> ## ✅ CURRENT & AUTHORITATIVE STRUCTURE (2026-06-27) — follow this; ignore older chapter-map wording
>
> **This is the only chapter structure to follow.** Where this banner and *any* earlier dated text (esp. the
> 2026-06-25 notes below) disagree on chapters/structure, **this wins** — treat the older wording as history,
> not instruction. The body follows the **current drafted LaTeX** (`docs/report/latex/`): a **design/verification
> split**, *not* the template's single merged "Triển khai hệ thống" chapter, and with **no separate Research
> Overview / related-work chapter**. Author directive: **keep the theory brief and foreground what the thesis
> built.** The six chapters are:
>
> **1 Introduction · 2 Theoretical Background & System Requirements (theory kept brief) · 3 Architecture & RTL
> Design · 4 Verification Methodology & UVM Environment · 5 Results & Evaluation · 6 Conclusion & Future Work.**
>
> Only the *format* layer of the 2026-06-25 template revision still stands (engine, page sequence, `biblatex`,
> labels, captions); its **chapter map (§2.3) and chapter plan (§3) were rewritten** to match the LaTeX. Related
> work shrinks to a framing section (CHIPS Alliance `i3c-core` baseline) in Ch.1/Ch.3. *(Ch.2 theory prose is to
> be written next session.)*

**Format baseline (2026-06-25 — FORMAT layer only, still in force).** The thesis follows the **official HCMUS Faculty of Electronics & Telecommunications KLTN LaTeX template** at `~/Workspaces/Thesis_Template_latex` for *format*: document class/engine, front-/back-matter page sequence, `biblatex` references, heading/caption/label conventions. **The chapter-map proposal from this revision was reverted** — for the structure actually used, follow the **CURRENT & AUTHORITATIVE STRUCTURE** banner above; everything dated 2026-06-25 here is format/policy only and asserts nothing about the chapter structure.

> **Language policy (author decision; label-language RESOLVED 2026-06-27): "follow the template's *format*, but render the thesis as a fully English technical document — English structural labels throughout; Vietnamese only where an institution mandate requires it."**
> - **Vietnamese — institution-mandated only (exactly two places):** (1) the **faculty cover page** headings (ĐẠI HỌC QUỐC GIA…/TRƯỜNG ĐẠI HỌC KHOA HỌC TỰ NHIÊN/KHOA ĐIỆN TỬ – VIỄN THÔNG and the KHÓA LUẬN… lines — the official title page), and (2) the **Vietnamese ABSTRACT (TÓM TẮT)** content that must accompany the English ABSTRACT (the required bilingual abstract). Nothing else is Vietnamese.
> - **English — everything else, including ALL structural labels:** every chapter's prose, section titles, figure/table/appendix captions, the **ABSTRACT** (the `tomtat` page places the English abstract *before* the Vietnamese one for an EN thesis), all technical material, **and the structural label words** — use **Chapter, Figure, Table, Table of Contents, List of Figures, List of Tables, List of Abbreviations, Appendix, References, Algorithm, Input, Output**, plus English front-/back-matter page titles (Acknowledgements, Declaration of Authorship, Confirmation of Completed Revisions). The template's Vietnamese label `\renewcommand`s are **overridden to English** (exact strings + casing in §2.6, preamble in §6). **No mixed labels** — never "CHƯƠNG 1: INTRODUCTION" or "Hình 4.5"; write the English word ("Chapter 1: Introduction", "Figure 4.5", "Table 4.1"). *(Already implemented in `report.tex`.)*
> - The drafted English Chapter 1 and the two existing figures (F1.1 SoC context, F1.2 thesis-organisation roadmap) are kept in the report's `chapters/` tree (`docs/report/latex/chapters/`) — no English content is discarded.

> **[HISTORICAL CHANGELOG of the 2026-06-25 revision — record only; do NOT follow its chapter-map item.]** This
> note records what the 2026-06-25 template revision touched. Its **chapter-map / chapter-plan items (§2.3, §3,
> §4) are SUPERSEDED** by the 2026-06-27 structure above — read them here as history. The still-valid *format*
> items it introduced: the global LaTeX contract (§2.1), document structure & page sequence (§2.2), the page
> budget (§2.4), the front-/back-matter checklist (§2.5), heading/caption/label conventions (§2.6), the
> **`biblatex` references plan** replacing BibTeX `IEEEtran` (§2.7), acronyms/glossary (§2.8), listing/algorithm/
> table styles (§2.9), the concrete template preamble reference (§6), and the compliance checklist (§9).
> ~~The template-exact 6-chapter map (§2.3) and per-chapter re-homing (§3)~~ — **reverted 2026-06-27.** **No
> factual / ground-truth content was altered** — the BLOCKING MIPI-compliance gate (§0), the ground-truth facts
> table (§1), the "RTL + module specs are authoritative" policy, the FPGA-omitted decision, the verification
> snapshot, and the canonical Terminology table (§10) are preserved verbatim.

## 0. How to use this plan

This is the **canonical** execution guide for writing the LaTeX thesis (chapter/appendix
structure, LaTeX setup, contributions narrative all live here). Companion docs:
- **Format/structure authority — the HCMUS KLTN template** at `~/Workspaces/Thesis_Template_latex` (`main.tex`,
  `Title/`, `Content/`, `Appendix/`, `References/`, `myacronyms.sty`). This template governs *every* **format**
  decision; where this plan and the template disagree on format, **the template wins**. *(Exception — file
  organisation, not format: the template ships chapters as `Content/chapterN.tex`, but **this project uses the
  descriptive `chapters/0X_*.tex` scheme** in `report.tex` — see §2.12. The template's generic names are not adopted.)*
- Reference exemplar — `082025 BC KL ... MESI ... Thông Lê.pdf` (a completed KLTN, secondary style model).
- Supervisor outline — `../Vo_Minh_Huy_Graduation_Thesis_Outline.pdf`.
- Department content rules — supervisor's four requirement slides (length, references, abstracts, English-writing;
  enforced in §2.4/§2.7/§2.10 as *content* rules separate from the template's *format*).

**Ground-truth policy:** the current RTL (`src/rtl/**`) + module specs (`docs/module_specs/**`) and
the current UVM (`src/verification/uvm_i3c/**`) are authoritative. Where `phase1_spec_v2.md`,
`I3C_Testplan.md`, the supervisor outline PDF, or older spec text disagree, **the code wins** and the
planning doc is treated as stale. `bug_analysis_report.md` does not exist in the repo — do not cite it.

> **⚠️ MIPI-compliance gate — BLOCKING, runs before any writing.** The official **MIPI I3C Basic
> v1.1.1** specification (`docs/mipi_i3c_spec.pdf`; OCR extract `docs/mipi_i3c_spec.md` — its tables are
> mangled, so verify every numeric against the PDF) is the **authority for protocol correctness**. Before
> writing any chapter/section that asserts a protocol fact, cross-check the relevant claims in the **RTL**
> (`src/rtl/**`) **and** the **project specs** (`phase1_spec_v2.md`, `docs/module_specs/**`) against it.
> The RTL and the project specs **must align with the official MIPI spec.**
>
> - This sits **above** the ground-truth policy. "Code wins over stale planning docs" governs *what the
>   design does* (state counts, ports, register map). The MIPI gate governs *whether that behaviour is
>   protocol-correct*. If the RTL or a project spec genuinely **contradicts** the official spec (wrong CCC
>   code, wrong frame order, a timing value below a spec minimum, a misused error code, etc.), that is a
>   **flagged mismatch / suspected design bug** — never paper over it by editing the thesis to match the
>   deviation.
> - **On any mismatch: STOP.** Do **not** write or continue the report. **List every mismatch caught**
>   (claim · what the project/RTL says · what the official MIPI spec says · spec clause/table · severity),
>   then **terminate the session** and surface the list to the author. Writing resumes only after the
>   author resolves each item.
> - If the cross-check is **clean**, record a one-line entry in the gate log below (date + what was
>   checked) and proceed. Scope each gate to the protocol facts the current chapter asserts, and re-run it
>   for every chapter that makes protocol claims. **Under the current design/verification map the
>   protocol-asserting chapters are Ch.2 (Theoretical Background & System Requirements), Ch.3 (Architecture &
>   RTL Design) and Ch.4 (Verification Methodology & UVM Environment).**
> - **This template-compliance revision writes no protocol-asserting body prose** (it only restructures the
>   plan), so the gate is **not triggered by this revision**. It remains armed for the chapter-writing passes.
>
> **Gate log:**
> - **2026-06-24 — Protocol-theory scope: PASS.** Verified vs official spec: 12.5 MHz SDR push-pull ceiling;
>   Table 87 minimums (`tLOW`/`tHIGH` 24 ns, `tSU_PP` 3 ns, `tSCO` max 12 ns); broadcast address `7'h7E`;
>   the three distinct bus conditions (§5.1.3.2.1–.3); `ENEC` 0x00/0x80, `DISEC` 0x01/0x81, `ENTDAA` 0x07
>   (Table 17); ENTDAA 48-bit PID + 8-bit BCR + 8-bit DCR then dyn-addr+parity ACK loop; T-Bit roles
>   (write=odd parity, read=end-of-data); OD addr/ACK vs PP data. **No contradiction.** (`phase1_spec_v2.md`
>   §7.1 "f_SCL Max 12.9 MHz" was reviewed and is **not** a violation — Table 87 lists 12.5 MHz as
>   *typical*, not a hard ceiling, and its period minimums permit slightly above 12.5.)
>   *(This PASS covered the protocol theory now homed in **Ch.2 Theoretical Background & System Requirements**.
>   The PASS still covers the same protocol facts — re-confirm scope when the Ch.2/Ch.3/Ch.4 prose is written.)*
> - **2026-06-28 — Ch.3 (Architecture & RTL Design) scope: PASS.** Re-confirmed the Ch.3 protocol-asserting
>   claims against the current RTL and the official MIPI spec; all fall within the 2026-06-24 verified set, no new
>   protocol assertion, no contradiction. Verified vs RTL: broadcast/reserved address `7'h7E` (`i3c_pkg::I3C_RSVD_ADDR`);
>   `CCC_ENTDAA = 8'h07`; ENTDAA per-Target sequence in `entdaa_fsm.sv` (send `{7E, R}` → ACK → shift 64 ID bits
>   MSB-first = 48-bit PID + 8-bit BCR + 8-bit DCR → send `{7-bit dyn addr, odd-parity P}` → ACK), matching MIPI;
>   immediate-CCC set `{ENEC 0x00, DISEC 0x01, direct ENEC 0x80, direct DISEC 0x81}` (`supported_immediate_ccc`);
>   write T-Bit = odd parity (`~^byte`), read T-Bit handled via the RX handoff path; OD address/ACK (`sel_od_pp=0`)
>   vs PP data (`sel_od_pp=1`). **Note:** the Response-Descriptor `ERR_STATUS` encoding (0x0…0xA) is an HCI/TCRI
>   *interface* convention (cited in `i3c_pkg.sv` as TCRI 7.1.3 Table 11), **not** a MIPI I3C Basic protocol clause;
>   it is presented in Ch.3 as the implementation's controller-interface error model (code-wins), not as a MIPI
>   protocol-correctness claim. **No contradiction — writing proceeds.**
> - **2026-06-28 — Ch.4 (Verification Methodology & UVM Environment) scope: PASS.** Ch.4 describes the
>   verification methodology and the UVM environment; it introduces **no new protocol assertion**. Every
>   protocol fact it references — SDR private write/read + immediate, \iic{}-FM legacy, ENTDAA, ENEC/DISEC,
>   write odd-parity / read end-of-data T-Bit, broadcast `0x7E`, OD/PP phasing — is a subset of the 2026-06-24
>   theory set and the 2026-06-28 Ch.3 set, and is *exercised* (by stimulus, scoreboard, and SVA), not
>   *redefined*. The scoreboard's `ERR_STATUS` comparisons reuse the same HCI/TCRI interface convention already
>   classified under the Ch.3 entry (code-wins interface model, not a MIPI clause). **No contradiction —
>   writing proceeds.**

**Settled decisions:**
- **Design/verification split 6-chapter model** (2026-06-27 directive; **SUPERSEDES** the 2026-06-25
  template-exact merge) — 1 Introduction / 2 Theoretical Background & System Requirements / 3 Architecture &
  RTL Design / 4 Verification Methodology & UVM Environment / 5 Results & Evaluation / 6 Conclusion & Future
  Work. The implementation block is **two chapters (Ch.3 design, Ch.4 verification)**, which still satisfies
  the department's "1–2 implementation chapters" rule and keeps the dual-agent UVM work as a first-class
  chapter. **Theory is kept brief** and folded into Ch.2 (no separate "Cơ sở lý thuyết" chapter); there is
  **no separate Research Overview / related-work chapter** — related work shrinks to a framing section (CHIPS
  Alliance `i3c-core` baseline). Matches the current drafted LaTeX (`docs/report/latex/`). *(See §2.3/§3.)*
- **FPGA omitted** — Results carries no FPGA data; FPGA noted only as future work (Ch.6).
- **Tooling = Cadence Xcelium + UVM 1.2 + SimVision.**
- **Engine = pdfLaTeX + `extreport` (template default).** *Not* XeLaTeX/`fontspec` (the previous revision's
  assumption is superseded by the template — see §2.10 for the Times-New-Roman reconciliation).

### Chapter ownership rule (prevents cross-chapter duplication)

Use one canonical owner for each kind of material:

> **Ch.2 defines it → Ch.3 implements it → Ch.4 verifies it → Ch.5 measures it → Ch.6 reflects on it.**

- **Ch.1 frames** the motivation, objective, high-level boundary, and contributions. It points to Ch.2 for
  the detailed scope and to Ch.5 for all changing counts and result metrics.
- **Ch.2 owns** protocol theory and the complete requirements/out-of-scope lists. Its UVM introduction is
  vocabulary only; the project topology belongs to Ch.4.
- **Ch.3 owns** architecture and RTL decisions. It contains one qualitative CHIPS Alliance comparison;
  line counts and reduction percentages belong to Ch.5.
- **Ch.4 owns** verification methodology and environment structure. Regression outcomes, waveform evidence,
  and coverage percentages belong to Ch.5; limitations and future work belong to Ch.6.
- **Ch.5 owns** the verified commit, count methodology, all volatile inventory/result numbers, regression
  evidence, coverage, implementation metrics, and evaluation against Ch.2 requirements.
- **Ch.6 owns** limitations and the future-work roadmap. Earlier chapters use short forward references only.

Before adding a section, table, or figure, identify its owner above. Other chapters may provide a one-sentence
pointer but must not reproduce the same list, table, metric, waveform, or roadmap.

---

## 1. Ground-truth facts (cite these verbatim)

| Fact | Value | Source of truth |
|---|---|---|
| `flow_active` FSM | 13 states (Idle…WriteResp) | `src/rtl/ctrl/flow_active.sv` `flow_fsm_state_e` |
| `scl_generator` FSM | 14 states (Idle…BusFree) | `src/rtl/ctrl/scl_generator.sv` `state_e` |
| `entdaa_controller` / `entdaa_fsm` | 7 / 8 states; `DatDepth`=32 | specs 08 / 08b |
| `bus_tx_flow` / `bus_rx_flow` | 4 states `[2:0]` each | specs 04 / 05 |
| `bus_tx` | 5 states | spec 04 |
| CSR map | 26 regs + 32-entry DAT | `csr_registers.sv`, spec 07 |
| Error codes generated | 0x0, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xA (0x5=DAA double-reject, 0x9=I2C data NACK/bus abort) | `flow_active.sv` `map_resp_err_status()`; `phase1_spec_v2.md` §9.4 (corrected) |
| Runnable vseq scenarios | 75: bus12/ccc5/csr15/daa6/fifo5/imm4/resp13/sdr_read6/sdr_write5/i2c4; plus one non-runnable base vseq | `i3c_vseqs/**` (snapshot, re-verified 2026-06-28) |
| Driver phases | 14 device-only (`i3c_drv_phase_e`, `DrvIdle`…`DrvDAA`) | `dv_i3c/i3c_agent_pkg.sv` |
| SVA | 10 files: 9 bound checkers + `tb_pad_model_sva` instantiated | `i3c_core/sva/**`, `tb_i3c_top.sv` (re-verified 2026-06-28) |
| Implementation size | **Not frozen.** Current raw `src/rtl/**/*.sv` count is 5,080 lines; Ch.5 must define exclusions and reproduce both project/reference counts before stating a reduction percentage. | filesystem snapshot, 2026-06-28 |

> The vseq count is a **work-in-progress snapshot** (testplan defines ~105 cases; re-verified against disk
> 2026-06-28, supersedes the earlier 56/78-vseq snapshots). Re-enumerate from disk again when writing Ch.5/Appendix I.
> CCC now has 5 vseqs (no longer ad-hoc-only); the I2C-specific (`i2c_vseqs/`, 4) and DAA (`daa_vseqs/`, 6)
> categories did not exist in the earlier snapshot and must be folded into the by-category breakdown.

---

## 2. Template compliance layer

This section maps the **HCMUS KLTN template** (`~/Workspaces/Thesis_Template_latex`) onto the plan. The template
is the authority for **format**; the department slides remain the authority for **content quotas** (length,
≥10 references, abstracts, English-writing), reconciled here.

### 2.1 Source template & global format contract (copy exactly)

Read straight from the template's `main.tex`. Adopt all of it verbatim:

| Item | Template setting | Notes |
|---|---|---|
| Document class | `\documentclass[twoside,a4paper,14pt,openright]{extreport}` | two-sided, right-opening chapters |
| Body font size | `\usepackage[fontsize=13pt]{scrextend}` → **13 pt** | the `14pt` class option + `scrextend` yields a 13 pt body |
| Encoding | `\usepackage[T5]{fontenc}` + `\usepackage[utf8]{inputenc}` + `\DeclareTextSymbolDefault{\DH}{T1}` | **T5 = Vietnamese**; compiles on **pdfLaTeX** |
| Line spacing | `\usepackage{setspace}` + `\onehalfspacing` | 1.5 spacing |
| First-line indent | `\usepackage{indentfirst}` | indent first paragraph too |
| Margins | `geometry`: `twoside, top=20mm, bottom=20mm, left=25mm, right=20mm, footskip=15mm, includefoot` | asymmetric (binding side = left 25 mm) |
| Page numbering | `fancyhdr`: number at **bottom-right** (`\fancyfoot[R]{\thepage}`), no header rule; `plain` style overridden to match | roman front matter, arabic body (set in `main.tex`) |
| Bibliography | `\usepackage[sorting=nty,backend=bibtex,defernumbers=true]{biblatex}` + `\addbibresource{References/references.bib}` | **`biblatex`**, *not* IEEEtran BibTeX (see §2.7) |
| Hyperlinks | `\usepackage[unicode]{hyperref}` | Unicode bookmarks |
| Graphics root | `\usepackage{graphicx}` + `\graphicspath{{Images/}}` | assets live in **`Images/`** |
| Author macros | `\tenSV` (name), `\mssv` (ID), `\tenKL` (title), `\tenGVHD` (advisor), `\tenBM` (specialisation) | fill once in `main.tex`; propagate to all front pages |

> **The template targets pdfLaTeX.** The previous revision's XeLaTeX + `fontspec` + Times-New-Roman plan is
> **superseded** — do not reintroduce it. Times-New-Roman vs the template's default font is reconciled in §2.10.

### 2.2 Document structure — exact page sequence

Reproduce the order in the template's `main.tex` exactly:

```
\input{Title/title.tex}                 % full HCMUS faculty cover (2 title pages)
\pagenumbering{roman}                    % i, ii, iii … (front matter)
\include{Appendix/editComfirmation}      % CONFIRMATION OF COMPLETED REVISIONS (EN, post-defense)
\include{Appendix/thanks}                % ACKNOWLEDGEMENTS                    (EN)
\include{Appendix/reassurances}          % DECLARATION OF AUTHORSHIP           (EN)
\include{Appendix/tomtat}                % ABSTRACT (EN) + TÓM TẮT (VN, required bilingual) — EN first
\tableofcontents                         % TABLE OF CONTENTS
\printglossary[type=\acronymtype, …]     % LIST OF ABBREVIATIONS
\listoffigures                           % LIST OF FIGURES
\listoftables                            % LIST OF TABLES
\pagenumbering{arabic}                   % 1, 2, 3 … (body)
\include{chapters/01_introduction_full}      % Ch.1 Introduction
\include{chapters/02_background_requirements}% Ch.2 Theoretical Background & System Requirements
\include{chapters/03_architecture_rtl}       % Ch.3 Architecture & RTL Design
\include{chapters/04_verification}           % Ch.4 Verification Methodology & UVM Environment
\include{chapters/05_results}                % Ch.5 Results & Evaluation
\include{chapters/06_conclusion}             % Ch.6 Conclusion & Future Work
\include{Appendix/publish}               % LIST OF AUTHOR'S PUBLICATIONS (optional — see §2.5)
\printbibheading + \printbibliography[…] % REFERENCES (single English bibliography)
\include{Appendix/appendix1..N}          % APPENDICES (the I3C appendices)
```

### 2.3 Six-chapter map (current LaTeX: design/verification split)

**Author decision (2026-06-27): follow the drafted LaTeX structure** in `docs/report/latex/chapters/`. This
keeps Design and Verification as separate first-class chapters, keeps theory brief in Ch.2, and drops the
template's single merged implementation chapter and its standalone Research Overview chapter. The chapter
*names* are rendered in English with **English structural labels** (the body is English; the template's Vietnamese label `\renewcommand`s are overridden to English per §2.6).
**No technical content is dropped** — only re-homed; related work is a framing section, not a chapter.

| Ch. | LaTeX file / Title | Content homed here | Was (2026-06-25 map) |
|---|---|---|---|
| **Ch.1** | `01_introduction_full` — Introduction | motivation, problem, objectives, high-level boundary, contributions, tools/EDA environment, thesis organisation; one framing paragraph names the CHIPS Alliance baseline; detailed scope and changing metrics are cross-references only | Ch.1 |
| **Ch.2** | `02_background_requirements` — Theoretical Background & System Requirements | **Part A (theory, kept brief):** I²C recap, MIPI I3C Basic SDR + frame format, bus conditions, OD vs PP, DAA/ENTDAA, CCC, I3C-vs-I²C, short UVM vocabulary. **Part B (requirements):** canonical functional, out-of-scope, performance, SW-interface, and verification requirements | merged 2026-06-25 Ch.2 (requirements) + Ch.3 (theory); **Research Overview chapter dropped** |
| **Ch.3** | `03_architecture_rtl` — Architecture & RTL Design ★ | architecture, dataflow, formats, error model, full RTL walkthrough, and **one qualitative** reference-derived design-boundary section; no LoC/result tables | first half of 2026-06-25 Ch.4 (arch + RTL) |
| **Ch.4** | `04_verification` — Verification Methodology & UVM Environment ★ | goals, directed-vs-CRV rationale, UVM/Xcelium choice, test stack, TLM/scoreboard, SVA and coverage models; TB top, agents, hierarchy, compact vseq categories, build/debug flow; no regression results or future-work sections | second half of 2026-06-25 Ch.4 (methodology + environment) |
| **Ch.5** | `05_results` — Results & Evaluation | verified baseline/count method, implementation metrics, regression matrix, waveform evidence, coverage, reference comparison, and evaluation against Ch.2 requirements | Ch.5 |
| **Ch.6** | `06_conclusion` — Conclusion & Future Work | summary/contributions, knowledge & skills gained, canonical limitations, future work (incl. FPGA) | Ch.6 |
| Appendix A–I | Appendices | back matter; **F dropped** (FPGA) — page-budget release valve for Ch.3/Ch.4 | App. A–I |

> **Consequence to manage.** Splitting design (Ch.3) and verification (Ch.4) keeps each chapter balanced
> (no 20-page mega-chapter), but Ch.3 still carries the full RTL and is the new highest-risk chapter for the
> page budget. Relocation to appendices (§2.4) still applies: the flagship 13-state `flow_active` FSM, the
> top-level/dataflow block diagrams (Ch.3) and the UVM topology diagrams (Ch.4) stay inline; full CSR maps,
> full state-transition tables, full port lists, full descriptor layouts, the full vseq inventory and
> regression SEQ lists move to Appendices A–C/G/I. **The full Ch.3 two-tier management strategy — page
> sub-budget, the inline core-narrative spine vs. relocated reference material, the per-module writing
> pattern, and the overflow escalation order — is consolidated in the Chapter 3 entry of §3; treat that as
> the authoritative plan for keeping this chapter within budget.**

### 2.4 Page budget (40–50 pp = MAIN BODY only; redistributed onto the current map)

The template imposes **no** page cap; the 40–50 pp rule is the **department** content quota and still applies to
the **main body only** (Ch.1→Ch.6). Front matter, references, and appendices are **uncounted and unlimited**.

**Group 1 — MAIN BODY (subject to the 40–50 cap):**

| Chapter | Title | Est. pages | Risk |
|---|---|---:|---|
| Ch.1 | Introduction | 4 | — |
| Ch.2 | Theoretical Background & System Requirements | 8 | ⚠️ **keep theory (Part A) brief**; UVM is vocabulary only; canonical requirements stay here |
| Ch.3 | Architecture & RTL Design | 15 | ⚠️ **highest risk** (full RTL) — relocate full CSR map/state tables/port lists/descriptor layouts to Appendices A–C; no quantitative result tables |
| Ch.4 | Verification Methodology & UVM Environment | 9 | ⚠️ relocate full vseq inventory + regression SEQ lists to Appendices G/I; no result waveforms or future-work lists |
| Ch.5 | Results & Evaluation | 7 | Owns all evidence and volatile metrics moved from Ch.3/Ch.4 |
| Ch.6 | Conclusion & Future Work | 4 | Owns limitations and roadmap |
| | **Body subtotal** | **47** | ✅ within 40–50 |

**Group 2 — UNCOUNTED / UNLIMITED:** front matter (title, edit-confirmation, acknowledgments, declaration,
abstracts, TOC, abbreviations, LoF, LoT) ~8–10 pp · references (≥10) ~2 pp · Appendices A–E,G–I ~12–18 pp.
**Estimated TOTAL ≈ 69–77 pp — expected and acceptable;** only the **47 pp body** is measured.

> #### ⛔ Content-preservation note (PRIMARY DIRECTIVE — overrides any later page-trimming pass)
>
> **Do not cut, truncate, compress, or omit main-body content to hit a page number.** Priority order:
> 1. **Within budget → write it fully.** No padding, no trimming.
> 2. **Body would exceed 50 → RELOCATE, never delete.** Move reference material (large tables, full FSM state
>    enumerations, complete CSR maps, long listings, the vseq inventory, regression dumps) into **appendices**
>    (uncounted). Leave a short in-body pointer + representative excerpt.
> 3. **Still over → tighten wording only.** Never remove substantive technical content or findings.
> 4. **Never drop a figure, table, finding, or mismatch item to save space.**

**Ch.3/Ch.4 relocation plan (move-to-appendix, never delete):** full CSR bitfield/register map (T3.4) → **App.
A**; CMD/RESP/DAT descriptor layouts (T3.1) → **App. B**; full FSM state-transition tables (T3.3 + per-module)
→ **App. C**; per-module port lists (T3.5) → **App. C** (or trim to key ports); full vseq inventory (T4.x)
→ **App. I**; full regression-target + SEQ lists (T4.x) → **App. G**. Keep inline: flagship `flow_active`
13-state FSM (Ch.3), top-level + dataflow block diagrams (Ch.3), UVM topology diagrams (Ch.4), one
representative state table, key ports only, ≤30-line snippets, compact by-category vseq counts.

> **Ch.3 is the single highest-risk chapter for this budget (15 of the 47 body pages, full RTL).** This
> §2.4 rule sets the *policy* (relocate, never delete); the **Chapter 3 entry of §3 carries the concrete
> execution plan** — a page sub-budget, the inline core-narrative spine, the per-module writing pattern, and
> an overflow escalation order. Apply that strategy when drafting Ch.3.

### 2.5 Front-/back-matter checklist (matched to the template's actual pages)

Status legend: ☐ not started · ◑ drafted · ☑ final. Owner = author unless noted; supervisor reviews all.
File names are the template's (`Title/`, `Appendix/`).

| # | Item (template file) | Language | Required? | Spec | Status |
|---|---|---|---|---|---|
| FM-1 | Title page (`Title/title.tex`) | **VN** (institutional cover) | Yes | Fill `\tenSV`/`\mssv`/`\tenKL`/`\tenGVHD`/`\tenBM`; the faculty cover headings stay Vietnamese (the one mandated VN page) | ☐ |
| FM-2 | Confirmation of Completed Revisions (`editComfirmation.tex`) | EN | Per HCMUS | Committee edit-confirmation; filled post-defense | ☐ |
| FM-3 | Acknowledgements (`thanks.tex`) | EN | Template includes | Acknowledgements | ☐ |
| FM-4 | Declaration of Authorship (`reassurances.tex`) | EN | Yes | Declaration of authorship | ☐ |
| FM-5 | ABSTRACT + TÓM TẮT (`tomtat.tex`) | **EN + VN** (required bilingual) | Yes | **EN abstract first** (EN-written thesis); the VN tóm tắt is the mandated bilingual half; structure Background/Purpose/Method/Results/Evaluation; **<1 page**; keywords both | ☐ |
| FM-6 | Table of Contents — TOC | auto | Yes | `\tableofcontents` | ☐ |
| FM-7 | List of Abbreviations | EN | Yes | `\printglossary[type=\acronymtype, title=LIST OF ABBREVIATIONS]` via `myacronyms.sty`; **populate from §10** | ☐ |
| FM-8 | List of Figures — LoF | auto | Yes | `\listoffigures` (`\listfigurename=LIST OF FIGURES`) | ☐ |
| FM-9 | List of Tables — LoT | auto | Yes | `\listoftables` (`\listtablename=LIST OF TABLES`) | ☐ |
| BM-1 | List of Author's Publications (`publish.tex`) | EN | **Optional** | Author has no publications → **omit** (comment the two `report.tex` lines) unless one exists | ☐ |
| BM-2 | References (`references.bib`) | EN | Yes | `biblatex`; heading **REFERENCES**; single English bibliography (no Vietnamese subbibliography); see §2.7 | ☐ |
| BM-3 | Appendix A — CSR register map | EN | Recommended | Offloads Ch.3 T3.4 | ☐ |
| BM-4 | Appendix B — CMD/RESP/DAT descriptor formats | EN | Recommended | Offloads Ch.3 T3.1 | ☐ |
| BM-5 | Appendix C — Full FSM state tables | EN | Recommended | Offloads Ch.3 T3.3/T3.5 | ☐ |
| BM-6 | Appendix D — CCC subset opcode/frame table | EN | Recommended | 5 entries | ☐ |
| BM-7 | Appendix E — Regression log excerpts | EN | After sims | Ch.5 evidence | ☐ |
| BM-8 | Appendix G — Build & run instructions | EN | Recommended | `src/verification/Makefile` reference; Appendix F intentionally skipped | ☐ |
| BM-9 | Appendix H — Glossary of I3C and HCI terms | EN | Recommended | Definitions and spec clauses only; FM-7 remains the acronym expansion list | ☐ |
| BM-10 | Appendix I — Vseq inventory | EN | Recommended | Offloads Ch.4 T4.3 | ☐ |

### 2.6 Heading, caption, float & label conventions (template `titlesec` + renames)

Adopt the template's `titlesec` and `\renewcommand`s verbatim:

- **`\setcounter{secnumdepth}{3}`** — number down to subsubsection.
- **Chapter:** `[block]` `\filcenter\normalfont\bfseries\normalsize`, prefix "**CHAPTER \thechapter :**", spacing
  `\titlespacing*{\chapter}{0pt}{-10pt}{10pt}`. → centered, bold, **normalsize**.
- **Section / Subsection / Subsubsection:** `\normalfont\bfseries\normalsize` with the decimal number, `1em` gap.
  → all bold **normalsize** (the template does **not** use 16/14/13 pt — see §2.10 reconciliation).
- **Label renames (English — RESOLVED 2026-06-27; override the template's Vietnamese furniture):**
  `\chaptername=CHAPTER`, `\figurename=Figure`, `\tablename=Table`, `\contentsname=TABLE OF CONTENTS`,
  `\listfigurename=LIST OF FIGURES`, `\listtablename=LIST OF TABLES`, `\appendixname=APPENDIX`; the
  abbreviations / references headings are set to **LIST OF ABBREVIATIONS** / **REFERENCES** via
  `\printglossary[title=…]` / `\printbibheading[title=…]`; algorithm labels to **Algorithm / Input / Output**
  (§2.9). *(This is exactly what `report.tex` already does.)* The resolved point is **English, not Vietnamese**;
  the major structural headings are set **UPPERCASE** to mirror the template's uppercase furniture (CHAPTER /
  TABLE OF CONTENTS / LIST OF … / APPENDIX / REFERENCES), with title-case inline float names (Figure, Table).
  Title-case heading variants (Chapter, Table of Contents) are equally valid English — casing is cosmetic, never
  a language mix. **No `CHƯƠNG`/`Hình`/`Bảng`.**
- **Numbering:** figures/tables **by chapter** (Figure 4.5, Table 4.3); decimal section numbers (template default).
- **Captions:** `caption` package; **below figures, above tables** (as in the template's `chapter2.tex`
  examples). **Every** figure/table carries a caption and is **referenced in the body** — enforced by §4.
  *(`report.tex` loads `cleveref[capitalise]`, so `\cref`/`\Cref` yield English names ("Figure 3.2", "Table 4.1",
  "Chapter 3"); plain `Figure~\ref{…}`/`Table~\ref{…}` also work.)*

### 2.7 References plan — `biblatex` (template engine), ≥10, identifiers, cited-in-body

The template uses **`biblatex` (`backend=bibtex`, `sorting=nty`, `defernumbers=true`)**, not BibTeX `IEEEtran`.
The heading is **REFERENCES** and, since all sources are English, there is a **single English bibliography** (no
Vietnamese subbibliography). Match it:

```latex
% preamble (already in template main.tex)
\usepackage[sorting=nty,backend=bibtex,defernumbers=true]{biblatex}
\addbibresource{References/references.bib}
% back matter — English heading (label-language resolved 2026-06-27)
\printbibheading[title={REFERENCES}]
\DeclareNameAlias{sortname}{last-first}\DeclareNameAlias{default}{last-first}
% Single English bibliography (all sources are English; no Vietnamese subbibliography)
\printbibliography[heading=subbibliography, title={English}, notkeyword=Viet, resetnumbers=1]
```

- For an English thesis with English-only sources, **all entries form one English list** (none tagged
  `keyword={Viet}`); the bibliography heading is **REFERENCES** and the single list is titled "English"
  (`resetnumbers=1`). No Vietnamese subbibliography is printed.
- **Build order (template note):** delete previous build artifacts, then **BibTeX → pdfLaTeX → pdfLaTeX**
  (`bibtex` backend, not `biber`). Re-run the same way after editing `references.bib`.

**Candidate source list (12 → comfortably ≥10).** Content unchanged from the prior revision; only the BibTeX
entry *types* matter now (`@misc`/`@manual`/`@techreport` for standards, `@book`, `@article`, `@inproceedings`,
`@online`):

| # | Reference | `biblatex` type | Identifier to capture | Cited in |
|---|---|---|---|---|
| R1 | MIPI Alliance, *MIPI I3C Basic Specification v1.1.1* (incl. Errata 01) | `@manual`/`@techreport` | spec no. / year | Ch.2–4 |
| R2 | NXP, *I²C-bus Specification and User Manual* (UM10204, Rev. 7.0) | `@manual` | doc no. / year | Ch.3 |
| R3 | IEEE, *IEEE Std 1800-2017 — SystemVerilog LRM* | `@manual`/`@techreport` | DOI 10.1109/IEEESTD.2018.8299595 *(verify)* | Ch.4 |
| R4 | Accellera, *UVM 1.2 User's Guide* | `@manual` | year | Ch.3/Ch.4 |
| R5 | Accellera, *UVM 1.2 Class Reference* | `@manual` | year | Ch.4 |
| R6 | S. Palnitkar, *Verilog HDL*, 2nd ed. | `@book` | ISBN 978-0132599702 *(verify)* | Ch.4 |
| R7 | C. Spear & G. Tumbush, *SystemVerilog for Verification*, 3rd ed. | `@book` | ISBN 978-1461407140 *(verify)* | Ch.4 |
| R8 | S. Harris & D. Harris, *Digital Design and Computer Architecture*, 2nd ed. | `@book` | ISBN 978-0123944245 *(verify)* | Ch.3/Ch.4 |
| R9 | CHIPS Alliance, *i3c-core* (GitHub, commit SHA) | `@online` | commit SHA, accessed date | Ch.2/Ch.4/Ch.5 |
| R10 | lowRISC OpenTitan, *DV framework / `dv_macros.svh`* | `@online` | commit/version | Ch.4 |
| R11 | **TO SOURCE:** IEEE/IEICE **conference** paper on I3C controller design/verification | `@inproceedings` | **ISBN** + DOI | Ch.1/Ch.2 |
| R12 | **TO SOURCE:** IEEE/IEICE **journal** paper on UVM-based functional verification | `@article` | **ISSN** + DOI | Ch.2/Ch.4 |

> **Content rules (department, retained):** (1) ≥10 entries; (2) ISBN on conference proceedings, ISSN on
> journals, DOI wherever one exists; (3) **every** entry `\cite`d at least once in the body — final orphan-check;
> (4) limit internet-only entries to R9/R10. **R11/R12 must be real, sourced papers** (IEEE Xplore / IEICE / ACM
> DL); verify every identifier against the source.

### 2.8 Acronyms / glossary (`myacronyms.sty`)

The template loads `\usepackage{myacronyms}` → `\RequirePackage[acronym,toc]{glossaries}` + `\makeglossaries`,
and prints the list as **LIST OF ABBREVIATIONS** right after the TOC. Define each acronym with
`\newacronym{key}{SHORT}{Long form}` and use `\acrshort`/`\acrlong`/`\acrfull`. **Populate `myacronyms.sty` from
the canonical §10 table** (Controller, Target, DAA, ENTDAA, CCC, OD, PP, SDR, HDR, Sr, T-Bit, RnW, IBI, Hot-Join,
PID, BCR, DCR, DAT, DCT, HCI, UVM, TLM, SVA, FSM, CSR). The glossary build needs `makeglossaries` in the chain.

### 2.9 Listing / algorithm / table styles (template)

- **Code listings:** the template's `listings` `mystyle` (coloured: `backcolour` background, green comments,
  magenta keywords, gray line numbers, purple strings; `\footnotesize`, `breaklines`, `numbers=left`, `tabsize=2`).
  Add SystemVerilog keywords via `morekeywords={logic,always_ff,always_comb,typedef,struct,packed,enum,interface,
  module,endmodule,package,endpackage,import}` (replacing the old standalone `sv` style). Snippets **≤30 lines**;
  use `\lstinputlisting` from a `SourceCode/` file for longer excerpts.
- **Algorithms / pseudocode:** the template's `algorithm` + `algpseudocode` with **English** captions
  ("Algorithm", "Input:", "Output:") — override any template Vietnamese names via `\floatname{algorithm}{Algorithm}`
  (or `\renewcommand{\ALG@name}{Algorithm}`), `\renewcommand{\algorithmicrequire}{\textbf{Input:}}`,
  `\renewcommand{\algorithmicensure}{\textbf{Output:}}` (as in `report.tex`). Use this for any pseudocode; the two **algorithm flowcharts** (F3.11,
  F3.12) remain TikZ figures, optionally paired with an `algorithm`-env listing.
- **Tables:** the template's column types `L{w}`/`C{w}`/`R{w}` (via `array`), `multirow`, `diagbox`,
  `\usepackage[table,xcdraw]{xcolor}`, and the `pmboxdraw` tree glyphs (`\SFii`/`\SFviii`/`\SFx`/`\SFxi`) for
  hierarchical config tables. `booktabs`/`longtable` may be **added** for long appendix tables (additive, format
  unchanged).

### 2.10 Template-vs-department reconciliations (two open; label language resolved)

Points where the **template format** and the **department slides** differ. The template wins for format
(author's "follow the format" instruction). **Two remain open for a one-line supervisor confirmation; the third
(label language) is RESOLVED — no confirmation needed:**

1. **Body font.** *(open — confirm.)* Template default = its `T5`/pdfLaTeX font (Latin Modern family), **not
   Times New Roman**. The slide says "Times New Roman 13". *Default: keep the template font* (following the
   template). If TNR is strictly required, that is a deviation from the template requiring a font-package swap.
2. **Heading sizes.** *(open — confirm.)* Template `titlesec` = bold **`\normalsize`** for chapter/section/
   subsection. The slide says 16/14/13 pt. *Default: keep the template's `\normalsize` headings.* Confirm whether
   the slide's sizes override.
3. **Label language — RESOLVED DECISION (2026-06-27; author decision, not pending confirmation).** The thesis
   follows the HCMUS template for formatting, but **all structural labels are converted to English** to avoid
   mixing Vietnamese labels with English technical content. Use **Chapter, Figure, Table, Table of Contents,
   List of Figures, List of Tables, List of Abbreviations, Appendix, References, Algorithm, Input, and Output.**
   The template's Vietnamese label `\renewcommand`s are overridden to English (§2.6/§6); algorithm names too
   (§2.9). The only Vietnamese retained is the institutional cover page and the required Vietnamese ABSTRACT
   (§ Language policy). No "CHƯƠNG 1: INTRODUCTION" / "Hình 4.5"; use "Chapter 1: Introduction" / "Figure 4.5".

### 2.11 English-writing requirements (department block D)

Applies to the **English ABSTRACT** (FM-5) and all English body prose (i.e. everything authored).

- Correct English grammar; **formal/academic** vocabulary; consistent tense/voice (past for completed work,
  present for the design's behaviour).
- Run the **EN abstract** through **Grammarly** (grammar) + **QuillBot** (style) before submission.
- **Citation completeness (supervisor instruction, verbatim intent):** since the report is written in English,
  grammar and wording must be checked carefully (per the rule above) — *and* whenever a paper, book, or standard
  is quoted or paraphrased, it **must carry a full citation in-body (`\cite{...}`) and a matching, fully-formatted
  entry in the references** (§2.7 `biblatex` list). No quoted/paraphrased source-material sentence may appear
  without both halves of that pairing. This is stronger than the general "every reference cited in body" rule
  (checklist C5) — it specifically targets borrowed text/claims (MIPI I3C Basic spec, UVM 1.2 LRM, papers, books,
  any standard), not just any work mentioned in passing.

### 2.12 Directory layout & build (project `chapters/` scheme — NOT `Content/`)

**Resolved (2026-06-27): the thesis follows the HCMUS template for formatting and document order, but uses the
project-specific `chapters/` directory with descriptive chapter filenames.** This improves maintainability while
preserving the template's visual and structural requirements. **Do NOT migrate chapter files to
`Content/chapter1..6.tex`.** Use only one chapter-file convention: `chapters/01_introduction_full.tex` through
`chapters/06_conclusion.tex`. The repo already uses this scheme in `report.tex` (which plays the template's
`main.tex` role — the project keeps the descriptive `report.tex` filename, by the same reasoning that keeps
`chapters/` over the template's generic `Content/`).

**Official chapter include sequence (in `report.tex`):**

```latex
\include{chapters/01_introduction_full}
\include{chapters/02_background_requirements}
\include{chapters/03_architecture_rtl}
\include{chapters/04_verification}
\include{chapters/05_results}
\include{chapters/06_conclusion}
```

**Target layout:**

```
docs/report/latex/
  report.tex                       % top file = template preamble + body order (the template's main.tex role)
  Title/title.tex                  % faculty cover (currently kept inline in report.tex)
  chapters/                        % descriptive chapter files (NOT Content/chapterN.tex)
    01_introduction_full.tex
    02_background_requirements.tex
    03_architecture_rtl.tex
    04_verification.tex
    05_results.tex
    06_conclusion.tex
  Appendix/                        % front/back-matter + appendices
    editComfirmation.tex
    thanks.tex
    reassurances.tex
    tomtat.tex
    appendixA.tex … appendixI.tex
  references.bib                   % the ≥10 I3C/UVM sources (§2.7)
  Images/                          % rendered figures
  SourceCode/                      % SV snippets for \lstinputlisting
  myacronyms.sty                   % acronyms from §10
```

> **Current repo state vs this target:** `report.tex` + `chapters/0X_*.tex` already exist and build; the cover is
> currently inline in `report.tex` (no `Title/` yet); the appendices are currently one file
> (`appendices/appendices.tex`) rather than split `Appendix/appendixA..I.tex`; `references.bib` and
> `myacronyms.sty` sit at the `latex/` root. Splitting appendices and adding `Title/`/`Images/`/`SourceCode/` are
> optional tidy-ups, **not** blockers, and **no chapter files move to `Content/`.**

- **Build:** `latexmk -pdf report.tex` is fine for drafting, **but** because of `biblatex(backend=bibtex)` +
  `glossaries`, a clean release build is: delete aux artifacts → `pdflatex` → `bibtex` → `makeglossaries` →
  `pdflatex` → `pdflatex` (the template's "BIB > PDF > PDF" note, plus the glossary pass).

---

## 3. Chapter writing plan (current LaTeX: design/verification split)

Each entry lists the **LaTeX file · Sections (as drafted) · Figures · Tables · Notes**, aligned to
`docs/report/latex/chapters/`. Page targets per §2.4. Figures/tables are renumbered by chapter under the new
map (see §4). Items tagged **⟦discuss⟧** are known content mismatches deferred to a later session.

### Chapter 1 — Introduction (`01_introduction_full`) · ~4 pp · Priority 2 · Independent

- **Sources:** outline PDF §1–4; `improvements.md`; `phase1_spec_v2.md` §1.
- **Sections (as drafted):**
  - 1.1 I3C in SoC Trends and Motivation
  - 1.2 Problem Statement and Objectives *(fold in a short results-preview + methodology sentence)*
  - 1.3 Scope and Constraints (SDR 12.5 MHz + I²C-FM 400 kHz; no IBI/HDR/Secondary-Controller/Target mode)
  - 1.4 Contributions (lead with the design result: all 13 `flow_active` states vs 8 left TODO in the reference; a compact, studyable controller retaining SDR + I²C-FM + ENTDAA; dual-agent UVM env; first ENTDAA-capable Active Controller in lab) — all volatile metrics stay in Ch.5
  - 1.5 Thesis Organisation
  - ⟦discuss⟧ **Tools & Development Environment** (Xcelium + UVM 1.2 + SimVision) — the plan wants a dedicated §1.5/1.6; the LaTeX currently has no standalone Tools section. Decide: add a section vs. fold into 1.1/1.2.
- **Figures:** **F1.1** I3C in an SoC context *(drawn)*; **F1.2** thesis-organisation roadmap *(drawn)*.
- **Tables:** **T1.1** contributions. The detailed in-scope/out-of-scope table exists only in Ch.2.
- **Notes:** use no volatile counts here. Name the CHIPS Alliance `i3c-core` baseline in one framing paragraph
  and point to Ch.3/Ch.5 for qualitative/quantitative comparisons.

---

### Chapter 2 — Theoretical Background & System Requirements (`02_background_requirements`) · ~9 pp ⚠️ · Priority 3 · Independent

*(Part A theory **kept brief** + Part B requirements. Protocol-asserting → MIPI gate applies. **Ch.2 theory prose
to be written next session.**)*

- **Sources:** `phase1_spec_v2.md` §2–7/§1/§9–10; MIPI I3C Basic v1.1.1; UVM 1.2 (Context7); specs 02, 03, 07, 11.
- **Sections — Part A · Theoretical Background (brief — just enough to follow the design):**
  - I²C recap *(short — overflow control)*
  - MIPI I3C Basic v1.1.1 (SDR mode & frame format)
  - Bus conditions (START / Repeated START / STOP)
  - Open-drain versus push-pull signalling
  - Dynamic Address Assignment via ENTDAA
  - Common Command Codes (CCC) overview (Broadcast / Direct)
  - I3C-versus-I²C comparison
  - UVM 1.2 vocabulary overview (maximum half a page; no project topology)
- **Sections — Part B · System Requirements and Specifications:**
  - Functional requirements
  - Out-of-scope features
  - Performance targets (12.5 MHz / 400 kHz / ≥333 MHz sys clk)
  - Software-visible interface (32-bit register bus)
  - Verification requirements
- **Figures:** **F2.1** I²C vs I3C bus signalling; **F2.2** Open Drain vs Push-Pull phases; **F2.3** START / Sr / STOP; **F2.4** SDR frame format (address byte + data + T-Bit); **F2.5** ENTDAA arbitration; **F2.6** register-bus read/write protocol (SW-visible interface). The project-specific UVM topology exists only in Ch.4.
- **Tables:** **T2.1** I3C-vs-I²C feature matrix; **T2.2** SDR + I²C-FM timing parameters; **T2.3** CCC subset overview (short; full table → App. D); **T2.4** functional requirements; **T2.5** performance targets; **T2.6** out-of-scope features.
- **Notes:** ⚠️ **Keep Part A brief** — prefer figures/tables over prose; short I²C recap; this is background, not a
  textbook. Error-code table belongs to the implementation (Ch.3 error-handling) — do not duplicate here. No
  separate Research Overview chapter: the CHIPS Alliance baseline is framed in Ch.1, interpreted qualitatively
  once in Ch.3, and measured in Ch.5.

---

### Chapter 3 — Architecture & RTL Design (`03_architecture_rtl`) ★ flagship · ~15 pp ⚠️ highest risk · Priority 6 · Independent of results

*(= architecture + full RTL design. Protocol-asserting → MIPI gate applies.)*

- **Sources:** specs 00–11; `improvements.md`; `CLAUDE.md` block diagram; `i3c_pkg.sv`, `controller_pkg.sv`; and **read RTL directly** — `flow_active.sv`, `scl_generator.sv`, `entdaa_controller.sv`+`entdaa_fsm.sv`, `csr_registers.sv`, `hci_queues.sv`/`sync_fifo.sv`, `bus_tx*.sv`/`bus_rx_flow.sv`, `bus_monitor.sv`, `i3c_phy.sv`, `controller_active.sv`, `edge_detector.sv`, `stable_high_detector.sv`.
- **Sections — architecture (system block diagrams):**
  - Three-layer architecture
  - Top module and block diagram
  - Transaction dataflow (Host → CMD FIFO → `flow_active` → bus → RESP/RX)
  - Clock/reset and signal conventions (2FF sync)
  - Reference-derived design boundary and decisions (the single qualitative CHIPS-Alliance comparison)
  - Queue/DAT/descriptor formats
  - Error-handling model
- **Sections — RTL implementation:**
  - PHY (`i3c_phy`: 2FF metastability sync + OD/PP drivers)
  - CSR register file + 32-entry DAT (`csr_register`)
  - HCI queues (`hci_queues` / `sync_fifo`; CMD/TX/RX/RESP; power-of-2 elaboration assert)
  - `bus_monitor` (START / Repeated START / STOP edge detection)
  - SCL generator (`scl_generator`, 14-state FSM; OD-low/bus-free timing; DAA restart via `gen_rstart_i`)
  - TX/RX serializers (`bus_tx`, `bus_tx_flow`, `bus_rx_flow`)
  - ENTDAA subsystem (`entdaa_controller` 7-state + `entdaa_fsm` 8-state; Controller perspective)
  - **`flow_active` 13-state FSM (flagship)** — SDR/I²C write+read; private immediate data merged into the shared `IssueCmd` path; CCC immediate (`cp=1`) via `IssueImmediateCcc`; ENTDAA; abort handling
  - `controller_active` wrapper + OD/PP switching
- **Figures:** **F3.1** three-layer architecture; **F3.2** top-level block diagram; **F3.3** transaction dataflow; **F3.4** clock/reset & 2FF sync; **F3.5** CHIPS Alliance `i3c-core` reference architecture (what is simplified); **F3.6** `flow_active` 13-state FSM (full-page landscape, flagship); **F3.7** `scl_generator` 14-state FSM; **F3.8** `entdaa_controller` 7-state + `entdaa_fsm` 8-state; **F3.9** `bus_tx`/`bus_tx_flow`/`bus_rx_flow` FSMs; **F3.10** OD/PP switching logic; **F3.11** `flow_active` command-issue algorithm flowchart *(algorithm-flowchart rule)*; **F3.12** ENTDAA per-Target loop algorithm flowchart *(algorithm-flowchart rule)*.
- **Tables:** **T3.1** queue/DAT/descriptor formats *(→ App. B)*; **T3.2** error-status encoding (`phase1_spec_v2.md` §9.4 corrected); **T3.3** `flow_active` 13-state table *(→ App. C)*; **T3.4** full CSR map (26 regs + DAT) *(→ App. A)*; **T3.5** per-module port lists *(→ App. B/C)*. Per-subsystem and module LoC tables move to Ch.5.
- **Notes:** start FSM diagrams early — long pole. `scl_generator` restart/handoff is driven by `gen_rstart_i`
  (request Repeated START) + `takeover_i` (fast-path handoff to `RstartSdaFall` for read takeover);
  use only these RTL names and omit old spec-only aliases. `flow_active` is **13 states** (confirmed vs RTL
  `flow_fsm_state_e`, indices 0–12). ⚠️ **Highest
  overflow risk now** — relocate T3.1/T3.3/T3.4/T3.5 to Appendices A–C (§2.4); keep the flagship FSM + key
  diagrams + ≤30-line snippets inline.

#### ⚠️ Page-budget management strategy (Ch.3 is the highest-risk chapter — manage, do NOT trim)

Ch.3 alone is **~15 of the 47 body pages** and carries the full RTL, so it is the single chapter most likely
to overflow. It is kept readable and within budget **without losing content** by writing it in two tiers — an
inline **core design narrative** (the spine) and relocated **reference material** (full content preserved in
appendices, cross-referenced) — governed by a per-module writing pattern. This is the execution of the §2.4
PRIMARY DIRECTIVE (*relocate, never delete*); nothing here cuts substantive content.

**Page sub-budget (~15 pp) — keeps the chapter balanced:**

| Block | Inline content | ~pp |
|---|---|---:|
| Architecture narrative | three-layer model, top block diagram, dataflow, clock/reset, error model, qualitative reference boundary (F3.1–F3.5; T3.2) | ~4 |
| RTL walkthrough — supporting modules | PHY, CSR+DAT, HCI queues, `bus_monitor`, `scl_generator`, TX/RX serializers, ENTDAA subsystem — one tight pass each (F3.7–F3.9) | ~6 |
| **Flagship `flow_active` 13-state FSM** | F3.6 (landscape) + F3.11 issue flowchart + the deepest narrative in the chapter | ~4 |
| `controller_active` + OD/PP | F3.10 + integration summary | ~1 |

**Tier 1 — inline core design narrative (the spine; never relocated):** the architecture story (F3.1–F3.3),
clock/reset & 2FF sync (F3.4), the error-status model (T3.2); the **flagship 13-state `flow_active` FSM (F3.6)
plus its command-issue flowchart (F3.11)** as the centerpiece given the most depth; one representative state
diagram per supporting FSM (F3.7–F3.9); the OD/PP switching figure (F3.10); **key ports only** (3–6 per
module) and **≤30-line snippets** (longer source via `\lstinputlisting` from `SourceCode/`).

**Tier 2 — reference material relocated to appendices (full content preserved + cross-referenced):** full CSR
bitfield/register map (T3.4) → **App. A**; CMD/RESP/DAT descriptor layouts (T3.1) + full per-module port lists
(T3.5) → **App. B**; full FSM state-transition tables (T3.3 + per-module) → **App. C**. Each inline mention
leaves a **one-line pointer** ("the complete register map is in Appendix A") **plus a representative excerpt** —
the reader is never sent away empty-handed, and no table is deleted.

**Per-module writing pattern (applies to every *supporting* module so none sprawls):** one ≤½-page pass =
(1) one-sentence role, (2) **one** diagram *or* key-port/state excerpt, (3) the single design decision that
matters (vs. the CHIPS Alliance reference), (4) "full table → App. X". Reserve multi-page depth for the
flagship `flow_active` **only** — that asymmetry is deliberate and is what keeps the chapter focused.

**Overflow escalation order (if the draft still exceeds its sub-budget — never delete, §2.4):**
1. tighten wording (no substantive content removed);
2. relocate the next-largest inline table to its appendix, leaving only an excerpt;
3. combine related figures (F3.9a/b/c → one TX/RX-serializer plate; F3.8a/b → one ENTDAA plate);
4. demote a supporting-module subsection to a single paragraph + appendix pointer.
**Do NOT** split Ch.3 into two chapters — the 6-chapter design/verification map (§2.3) is fixed — and **do NOT**
drop any figure, table, finding, or the flagship's depth to save pages.

---

### Chapter 4 — Verification Methodology & UVM Environment (`04_verification`) ★ · ~9 pp ⚠️ · Priority 7 · Independent of results

*(= verification methodology + UVM environment — the second first-class implementation chapter.)*

- **Sources:** `i3c_scoreboard.sv`, `tb_i3c_top.sv`, `i3c_driver.sv`, `i3c_monitor.sv`, `i3c_base_vseq.sv`, `i3c_vseq_list.sv`, `i3c_csr_addr_pkg.sv`, `Makefile`, `i3c_vseqs/**`, `sva/**`; UVM 1.2 (Context7).
- **Sections — methodology:**
  - Verification goals and scope
  - Directed-vs-constrained-random rationale
  - Why UVM 1.2 + Xcelium
  - Layered test stack (reg agent + I3C device agent + env + vseqr)
  - TLM analysis path and scoreboard strategy
  - SVA checkers (10 files: 9 bound + `tb_pad_model_sva` instantiated)
  - Coverage strategy (implemented covergroups, sampling, crosses, and exclusions; no percentages)
- **Sections — UVM environment:**
  - TB top and interfaces
  - Register agent
  - I3C Target agent (driver 14 phases + monitor)
  - Env / vseqr / scoreboard class hierarchy
  - Vseq library (compact current categories only; full 75-scenario inventory → App. I)
  - Build/run flow (category regression targets + combined `sdr`/`full` + `coverage`)
  - Waveform/debug procedure (evidence → Ch.5)
  - Chapter summary mapping verification requirements to mechanisms
- **Figures:** **F4.1** directed-vs-random rationale; **F4.2** layered UVM test stack; **F4.3** TLM path (monitor → scoreboard); **F4.4** env class hierarchy; **F4.5** register agent; **F4.6** I3C Target agent (driver + monitor); **F4.7** SVA binding map.
- **Tables:** **T4.1** verification goals; **T4.2** tool/methodology choices; **T4.3** compact vseq categories *(full inventory → App. I)*; **T4.4** driver 14-phase table (`DrvIdle`…`DrvDAA`); **T4.5** scoreboard check list; **T4.6** regression targets + SEQ lists *(→ App. G)*; **T4.7** 10 SVA modules (bind vs instantiate).
- **Notes:** write scoreboard/SVA from source — never the stale "minimal" label. Re-enumerate vseqs from disk at
  Ch.5/App. I write time. Ch.4 contains no pass/fail matrix, evidence waveform, measured coverage, limitation
  list, or future-work list.

---

### Chapter 5 — Results & Evaluation (`05_results`) · ~7 pp · Priority 8 · After green regressions

- **Sources:** sim logs/coverage from `make regression` + category regressions; `improvements.md`.
- **Sections (as drafted):**
  - Verified baseline and measurement method (branch/commit/tools/seeds/file-selection rules)
  - Quantitative implementation metrics (reproducible LoC counts; no pre-baked percentage)
  - Regression results (pass/fail matrix)
  - Waveform evidence (write / read / immediate / CCC)
  - Functional coverage (implemented covergroups, `COV=1`; full-protocol closure = planned extension)
  - Comparison with CHIPS Alliance reference
  - Evaluation against Ch.2 requirements
- **Figures:** **F5.1** annotated write + read waveforms; **F5.2** functional-coverage screenshot; **F5.3** implementation-size comparison chart.
- **Tables:** **T5.1** verified baseline/count rules; **T5.2** per-subsystem implementation metrics; **T5.3** module LoC summary; **T5.4** regression pass/fail matrix; **T5.5** reference comparison; **T5.6** requirements-evidence matrix.

---

### Chapter 6 — Conclusion & Future Work (`06_conclusion`) · ~4 pp · Priority 9 · Last

- **Sources:** all chapters; `phase1_spec_v2.md` out-of-scope list; `improvements.md` future-work notes.
- **Sections (as drafted):**
  - Summary of contributions
  - Knowledge, skills, and lessons learned
  - **Limitations** — the single canonical limitation list, separated into implementation and evaluation limits
  - Future work (IBI, HDR, Target mode, multi-Target, full-protocol coverage closure, FPGA validation, ENTDAA/CCC/I²C test gaps)
- **Tables:** **T6.1** future-work roadmap *(source: `phase1_spec_v2.md` out-of-scope list)*.
- **Notes:** keep the single FPGA line here. No earlier chapter repeats this roadmap or limitation list.

---

### Appendices (Appendix; FPGA appendix dropped)

| Appendix | Title | Source | Offloads |
|---|---|---|---|
| A | CSR register map (full bitfield tables) | `csr_registers.sv`, spec 07 | Ch.3 T3.4 |
| B | Command / Response / DAT descriptor formats | `i3c_pkg.sv`, `controller_pkg.sv` | Ch.3 T3.1/T3.5 |
| C | Complete FSM state tables (all RTL FSMs) | specs 03–09 | Ch.3 T3.3/T3.5 |
| D | CCC subset opcode/frame table | `phase1_spec_v2.md` §4 | Ch.2 T2.3 |
| E | Regression log excerpts | sim logs | Ch.5 evidence |
| ~~F~~ | ~~Synthesis/utilisation/timing~~ | — | **DROP** (FPGA omitted) |
| G | Build & run instructions (Makefile reference) | `src/verification/Makefile` | Ch.4 T4.6 |
| H | Glossary of I3C and HCI terms | §10 | Definitions and spec pointers; not a duplicate acronym list |
| I | Vseq inventory (75 runnable scenarios by category) | `i3c_vseqs/**` | Ch.4 T4.3 |

Appendices A–C release the **Ch.3** page budget; G/I release **Ch.4**. Render as `\chapter` blocks under
`\appendix` (label "APPENDIX"), interleaved/finalised as each parent chapter is completed.

---

## 4. Renumbered figure & table master list

Per-chapter numbering under the **current design/verification map**; **every entry has a caption and a
body-text reference**. "Prev ID" = the 2026-06-25 template-map ID, for traceability. Two algorithm flowcharts
(F3.11, F3.12) satisfy the "algorithm flowchart" rule and now live in Ch.3 alongside the RTL.

### Figures

| New ID | Caption (short) | Prev ID | Body ref | Source |
|---|---|---|---|---|
| F1.1 | I3C in an SoC context | F1.1 | Ch.1 · Motivation | `improvements.md` |
| F1.2 | Thesis-organisation roadmap | F1.2 | Ch.1 · Organisation | — |
| F2.1 | I²C vs I3C bus signalling | F3.1 | Ch.2 · I²C/I3C | MIPI/phase1 |
| F2.2 | Open Drain vs Push-Pull phases | F3.2 | Ch.2 · OD/PP | WaveDrom `bus/od_vs_pp` |
| F2.3 | START / Repeated START / STOP | F3.3 | Ch.2 · Bus conditions | WaveDrom `bus/bus_conditions` |
| F2.4 | SDR frame format (addr + data + T-Bit) | F3.4 | Ch.2 · SDR frame | WaveDrom `bus/sdr_*` |
| F2.5 | ENTDAA arbitration | F3.5 | Ch.2 · ENTDAA | WaveDrom `bus/entdaa_arbitration` |
| F2.6 | Register-bus read/write protocol | F2.2 | Ch.2 · SW interface | spec 07 |
| F3.1 | Three-layer architecture | F4.1 | Ch.3 · Architecture | spec 11 |
| F3.2 | Top-level block diagram | F4.2 | Ch.3 · Top module | `CLAUDE.md`/spec 11 |
| F3.3 | Transaction dataflow | F4.3 | Ch.3 · Dataflow | spec 11 |
| F3.4 | Clock/reset & 2FF sync | F4.4 | Ch.3 · Clock/reset | `i3c_phy.sv` |
| F3.5 | CHIPS Alliance `i3c-core` reference architecture | F2.1 | Ch.3 · CHIPS comparison | `improvements.md`/`CLAUDE.md` |
| F3.6 | `flow_active` 13-state FSM (landscape, flagship) | F4.5 | Ch.3 · `flow_active` | `flow_active.sv` |
| F3.7 | `scl_generator` 14-state FSM | F4.6 | Ch.3 · SCL generator | `scl_generator.sv` |
| F3.8 | `entdaa_controller` 7-state + `entdaa_fsm` 8-state | F4.7 | Ch.3 · ENTDAA subsystem | `entdaa_*.sv` |
| F3.9 | `bus_tx`/`bus_tx_flow`/`bus_rx_flow` FSMs | F4.8 | Ch.3 · TX/RX serializers | `bus_tx*.sv`,`bus_rx_flow.sv` |
| F3.10 | OD/PP switching logic | F4.9 | Ch.3 · `controller_active` | `controller_active.sv` |
| F3.11 | `flow_active` command-issue algorithm flowchart | F4.10 | Ch.3 · `flow_active` | `flow_active.sv` |
| F3.12 | ENTDAA per-Target loop algorithm flowchart | F4.18 | Ch.3 · ENTDAA subsystem | `entdaa_*.sv` |
| F4.1 | Directed-vs-random rationale | F4.11 | Ch.4 · CRV rationale | — |
| F4.2 | Layered UVM test stack | F4.12 | Ch.4 · Test stack | spec 00 |
| F4.3 | TLM path (monitor → scoreboard) | F4.13 | Ch.4 · TLM/scoreboard | `i3c_scoreboard.sv` |
| F4.4 | Env class hierarchy | F4.14 | Ch.4 · Env hierarchy | `i3c_env.sv` |
| F4.5 | Register agent | F4.15 | Ch.4 · Register agent | `dv_reg/**` |
| F4.6 | I3C Target agent (driver + monitor) | F4.16 | Ch.4 · Target agent | `dv_i3c/**` |
| F4.7 | SVA binding map | F4.17 | Ch.4 · SVA checkers | `sva/**`,`tb_i3c_top.sv` |
| F5.1 | Annotated write + read waveforms | F5.1 | Ch.5 · Waveform evidence | sim |
| F5.2 | Functional-coverage screenshot | F5.2 | Ch.5 · Coverage | sim (COV=1) |
| F5.3 | Implementation-size comparison chart | F5.3 | Ch.5 · Quantitative metrics | reproducible count output |

### Tables

| New ID | Caption (short) | Prev ID | Body ref | Source |
|---|---|---|---|---|
| T1.1 | Contributions | T1.1 | Ch.1 · Contributions | — |
| T2.1 | I3C-vs-I²C feature matrix | T2.1 | Ch.2 · I3C/I²C comparison | MIPI spec |
| T2.2 | SDR + I²C-FM timing parameters | T3.1 | Ch.2 · SDR frame | phase1 spec |
| T2.3 | CCC subset overview | T3.2 | Ch.2 · CCC (→ App. D) | phase1 §4 |
| T2.4 | Functional requirements | T2.2 | Ch.2 · Functional reqs | phase1 spec |
| T2.5 | Performance targets | T2.3 | Ch.2 · Performance | `improvements.md` |
| T2.6 | Out-of-scope features | T2.4 | Ch.2 · Out-of-scope | scope analysis |
| T3.1 | Queue/DAT/descriptor formats | T4.2 | Ch.3 · descriptor formats (→ App. B) | `i3c_pkg.sv` |
| T3.2 | Error-status encoding | T4.3 | Ch.3 · Error model | phase1 §9.4 |
| T3.3 | `flow_active` 13-state table | T4.4 | Ch.3 · `flow_active` (→ App. C) | `flow_active.sv` |
| T3.4 | Full CSR map (26 regs + DAT) | T4.5 | Ch.3 · CSR file (→ App. A) | `csr_registers.sv` |
| T3.5 | Per-module port lists | T4.6 | Ch.3 · RTL modules (→ App. B/C) | RTL |
| T4.1 | Verification goals | T4.8 | Ch.4 · Goals | spec 00 |
| T4.2 | Tool/methodology choices | T4.9 | Ch.4 · Why UVM/Xcelium | — |
| T4.3 | Compact vseq categories | T4.10 | Ch.4 · Vseq library (full inventory → App. I) | `i3c_vseqs/**` |
| T4.4 | Driver 14-phase table | T4.11 | Ch.4 · Target agent | `i3c_agent_pkg.sv` |
| T4.5 | Scoreboard check list | T4.12 | Ch.4 · Scoreboard | `i3c_scoreboard.sv` |
| T4.6 | Regression targets + SEQ lists | T4.13 | Ch.4 · Build/run (→ App. G) | `Makefile` |
| T4.7 | 10 SVA modules (bind vs instantiate) | T4.14 | Ch.4 · SVA checkers | `sva/**` |
| T5.1 | Verified baseline and count rules | — | Ch.5 · Measurement method | source revisions/tool versions |
| T5.2 | Per-subsystem implementation metrics | T4.1 | Ch.5 · Quantitative metrics | reproducible count output |
| T5.3 | Module LoC summary | T4.7 | Ch.5 · Quantitative metrics | reproducible count output |
| T5.4 | Regression pass/fail matrix | T5.1 | Ch.5 · Regression results | sim logs |
| T5.5 | Reference comparison | T5.2 | Ch.5 · CHIPS comparison | pinned sources + results |
| T5.6 | Requirements-evidence matrix | — | Ch.5 · Evaluation against requirements | Ch.2 + evidence |
| T6.1 | Future-work roadmap | T6.1 | Ch.6 · Future work | `phase1_spec_v2.md` out-of-scope list |

**Counts:** ~30 figures, ~27 tables. All carry captions and are cross-referenced; full bitfield/state/port/vseq
tables migrate to Appendices A–C/G/I to protect the Ch.3/Ch.4 budget.

---

## 5. Recommended writing order

Chapters with **zero dependency** on simulation results can be written immediately:

1. **Ch.2** Theoretical Background & System Requirements — independent; **keep theory brief** *(run MIPI gate first)* — **next session**
2. **Ch.1** Introduction — independent once its prose contains no volatile metrics; F1.1/F1.2 already drawn
3. **Ch.3** Architecture & RTL Design (flagship) — independent of sims; **start FSM diagrams (F3.6–F3.9) and the
   F3.11/F3.12 flowcharts first** — long pole *(run MIPI gate first)*
4. **Ch.4** Verification Methodology & UVM Environment — independent of sims; all results stay in Ch.5
5. **Ch.5** Results & Evaluation — after `make regression` + category regressions pass
6. **Ch.6** Conclusion & Future Work — last
7. **Appendices (Appendix A–I)** — interleave; finalise A–C with Ch.3, G/I with Ch.4, E with Ch.5.

**FPGA — skip.** Gate: only Ch.5 depends on green regressions; all other chapters can be written now.

---

## 6. LaTeX conventions — template preamble reference

The thesis preamble **is** the template's `main.tex` preamble (§2.1). Reproduce it verbatim, then add only the
figure-drawing packages the I3C content needs (additive — they do not change the template's format):

**From the template (verbatim):** `extreport[twoside,a4paper,14pt,openright]` · `scrextend[fontsize=13pt]` ·
`fontenc[T5]`+`inputenc[utf8]`+`\DeclareTextSymbolDefault{\DH}{T1}` · `biblatex[sorting=nty,backend=bibtex,
defernumbers=true]`+`\addbibresource{References/references.bib}` · `hyperref[unicode]` · `graphicx`+
`\graphicspath{{Images/}}` · `caption` · `adjustbox[export]` · `listings`+`color` (`mystyle`) · `amsmath`+
`algorithm`+`algpseudocode[noend]` (**English** names: Algorithm/Input/Output) · `multirow`+`array` (L/C/R)+`diagbox`+`xcolor[table,xcdraw]`+
`pmboxdraw` · label `\renewcommand`s **overridden to English** (CHAPTER/Figure/Table/TABLE OF CONTENTS/LIST OF FIGURES/LIST OF TABLES/APPENDIX — see §2.6) · `titlesec` (secnumdepth 3; chapter centered
bold normalsize; section/subsection/subsubsection bold normalsize) · `setspace`+`\onehalfspacing` · `indentfirst`
· `fancyhdr` (page no. bottom-right) · `geometry[twoside,top=20mm,bottom=20mm,left=25mm,right=20mm,footskip=15mm,
includefoot]` · `tikz`+`\usetikzlibrary{calc}`+`\HRule` · `myacronyms` · `ifthen` · `\myemptypage` · the five info
macros (`\tenSV`/`\mssv`/`\tenKL`/`\tenGVHD`/`\tenBM`).

**Add for the I3C figures (additive):** `\usetikzlibrary{automata,arrows.meta,positioning,shapes,chains,fit}`
(FSMs + flowcharts), `\usepackage{pdflscape}` (flagship `flow_active` landscape F3.6), `\usepackage{siunitx}`
(timing units), `\usepackage{booktabs}`+`\usepackage{longtable}` (long appendix tables). Extend the `mystyle`
listing with SystemVerilog `morekeywords` (§2.9).

- **FSM figures:** TikZ `automata`. Flagship F3.6 → full-page `\begin{landscape}\begin{figure}[p]…`; others at
  `width=0.95\textwidth`. Algorithm flowcharts F3.11/F3.12 via TikZ `chains`/`shapes`.
- **Code listings:** `mystyle` (SystemVerilog), ≤30 lines; `\lstinputlisting` from `SourceCode/` for longer.
- **Citations:** `\cite` (biblatex). Mandatory: MIPI I3C Basic v1.1.1, Accellera UVM 1.2, CHIPS Alliance
  `i3c-core` (commit SHA), OpenTitan `dv_macros.svh` — plus the ≥10 set in §2.7.
- **Cross-refs:** `\cref`/`\Cref` (`report.tex` loads `cleveref[capitalise]` → English "Figure 3.2"/"Table 4.1"/
  "Chapter 3"); plain `Figure~\ref{…}`/`Table~\ref{…}` also work.
- **Waveforms:** export SimVision as vector PDF or 300 dpi PNG into `Images/`, cropped to ≤5 µs, TikZ-annotated.
- **Attribution:** credit CHIPS Alliance `i3c-core` in captions/footnotes wherever simplified RTL is shown.

---

## 7. Figure asset plan (priority set)

Figures authored as **source files** under `figures/` (TikZ/WaveDrom), rendered to PDF/PNG into the template's
`Images/` tree. **Hybrid toolchain:**

- **Bus-format / timing diagrams → WaveDrom** (JSON → SVG/PDF).
- **FSM & state diagrams → TikZ `automata`** (flagship `flow_active` landscape per §6).
- **Algorithm flowcharts → TikZ `chains`/`shapes`** (F3.11, F3.12).

Layout: `figures/fsm/*.tex`, `figures/flow/*.tex`, `figures/bus/*.json` + `figures/README.md` (render commands +
the F-number map). State/edge data from the named RTL; frame/bit data from `phase1_spec_v2.md`.

### FSM diagrams (TikZ) — source of truth = RTL enums

| File | Thesis fig | What it shows | RTL source |
|---|---|---|---|
| `fsm/flow_active_fsm.tex` | **F3.6** (flagship, landscape) | 13-state command FSM (Idle…WriteResp); happy-path + abort→WriteResp | `ctrl/flow_active.sv` |
| `fsm/scl_generator_fsm.tex` | **F3.7** | 14-state SCL/START/STOP/Sr generator (Idle…BusFree) | `ctrl/scl_generator.sv` |
| `fsm/entdaa_controller_fsm.tex` | **F3.8a** | 7-state ENTDAA loop manager | `ctrl/entdaa_controller.sv` |
| `fsm/entdaa_fsm.tex` | **F3.8b** | 8-state per-Target DAA arbitration | `ctrl/entdaa_fsm.sv` |
| `fsm/bus_tx_fsm.tex` | **F3.9a** | 5-state TX bit engine | `ctrl/bus_tx.sv` |
| `fsm/bus_tx_flow_fsm.tex` | **F3.9b** | 4-state TX byte/bit serializer | `ctrl/bus_tx_flow.sv` |
| `fsm/bus_rx_flow_fsm.tex` | **F3.9c** | 4-state RX deserializer | `ctrl/bus_rx_flow.sv` |

### Algorithm flowcharts (TikZ) — satisfy the "algorithm flowchart" rule

| File | Thesis fig | What it shows | Source |
|---|---|---|---|
| `flow/flow_active_issue.tex` | **F3.11** | command-issue decision flow (FetchDAT → write/read/immediate/DAA → WriteResp) | `ctrl/flow_active.sv` |
| `flow/entdaa_loop.tex` | **F3.12** | ENTDAA per-Target loop (7E+R → PID/BCR/DCR → addr+parity → ACK → next/stop) | `ctrl/entdaa_controller.sv`, `entdaa_fsm.sv` |

### Bus-format diagrams (WaveDrom) — source of truth = `phase1_spec_v2.md`

| File | Thesis fig | What it shows |
|---|---|---|
| `bus/bus_conditions.json` | **F2.3** | START / Repeated START (Sr) / STOP |
| `bus/od_vs_pp.json` | **F2.2** | Open Drain (addr/ACK) vs Push-Pull (data); `sel_od_pp` |
| `bus/address_byte.json` | F2.4 | 9-bit address byte: A6..A0 + RnW + ACK (MSB first) |
| `bus/sdr_write_frame.json` | F2.4 | SDR private write: S · addr+W · ACK · {data+T}×N · P |
| `bus/sdr_read_frame.json` | F2.4 | SDR private read: S · addr+R · ACK · {data,T=1}…{data,T=0} · P |
| `bus/entdaa_arbitration.json` | **F2.5** | ENTDAA: 7E+W·ACK·CCC·Sr·7E+R · PID+BCR+DCR · dyn-addr+parity · ACK |
| `bus/ccc_frame.json` | (Ch.2/App. D) | Broadcast + Direct CCC frame format |

> Remaining figures (architecture F3.1–F3.5, UVM environment F4.1–F4.7, Ch.5 evidence F5.1–F5.3) are a later pass.

---

## 8. Remaining action items

**LaTeX tree (mostly done — repo already on `report.tex` + `chapters/`):**
- [ ] **Keep the project `chapters/` scheme (§2.12) — do NOT migrate to `Content/`.** The repo already has
  `report.tex` (template preamble + body order) and `chapters/01_introduction_full.tex … 06_conclusion.tex` with
  the official include sequence; Ch.1 (with F1.1/F1.2) already lives in `chapters/01_introduction_full.tex`.
  Optional tidy-ups (not blockers): add `Title/title.tex` (cover currently inline in `report.tex`), split
  `appendices/appendices.tex` into `Appendix/appendixA..I.tex`, add `Images/`/`SourceCode/` as needed. **No
  chapter file is renamed to `Content/chapterN.tex`.**
- [ ] **Fill the five info macros** (`\tenSV` Vo~Minh~Huy · `\mssv` 22207042 · `\tenKL` thesis title · `\tenGVHD`
  ThS.~Nguyễn~Duy~Mạnh~Thi · `\tenBM` specialisation).
- [ ] **Populate `myacronyms.sty`** from §10 (replace the template's `hdl`/`soc` samples).
- [ ] **Replace `References/references.bib`** with the ≥10 I3C/UVM sources (§2.7); confirm `biblatex(backend=
  bibtex)` + `makeglossaries` build chain works (BIB→PDF→PDF + glossary pass).
- [ ] **Confirm the two open template-vs-department reconciliations** (§2.10: font, heading sizes). *(Label
  language is RESOLVED 2026-06-27 — English labels throughout; no confirmation needed.)*

**Technical / content:**
- [ ] **Run the MIPI-compliance gate before each protocol-asserting chapter** (Ch.2, Ch.3, Ch.4) — §0 BLOCKING
  gate + log. On any mismatch: list all, do not write, terminate, surface. On clean: append a dated PASS line.
  *(Protocol-theory scope done — PASS, 2026-06-24, now homed in Ch.3.)*
- [ ] **Run full regression sweep** — source `XCELIUM1803.sh` first (local `.relr.dyn` link may fail; elaboration/
  sim still validates). Capture logs + optional `COV=1`. *Blocks:* Ch.5 only.
- [ ] **Re-enumerate vseq inventory from disk** at Ch.5 / App. I write time (75 runnable-scenario snapshot → ~105 testplan target).
- [ ] *(optional)* `CLAUDE.md` references `docs/bug_analysis_report.md`, which does not exist — correct/remove.

**Compliance (content):**
- [ ] **Author the two algorithm flowcharts** F3.11 (`flow_active` issue) and F3.12 (ENTDAA loop).
- [ ] **Write VN TÓM TẮT + EN ABSTRACT (<1 page, EN first)** in `Appendix/tomtat.tex`; run the EN abstract through
  **Grammarly** + **QuillBot**.
- [ ] **Source 2 real peer-reviewed papers** (R11 conference w/ ISBN, R12 journal w/ ISSN); fill exact ISBN/ISSN/
  DOI for all references; verify R3/R6/R7/R8 identifiers.
- [ ] **Citation-completeness pass:** every reference `\cite`d; no uncited claims.
- [ ] **Page-budget tracking:** Ch.3 is the highest-risk chapter — **checkpoint it against its ~15 pp
  sub-budget right after the Ch.3 draft** (not only after Ch.4), applying the two-tier management strategy in
  the §3 Chapter 3 entry (core-narrative spine inline; T3.1/T3.3/T3.4/T3.5 → Appendices A–C; per-module
  pattern; escalation order). Then check the whole body against 47 pp; if over, **relocate** to Appendices
  A–C/G/I (never delete — §2.4). Total length uncapped.
- [ ] **Expand Ch.6** to include *knowledge gained, skills gained, limitations* (6.2/6.3).
- [ ] **Final polish:** spelling, no large blank areas (float placement), consistent captions, regenerate
  TOC/LoF/LoT/abbreviations.

---

## 9. Compliance checklist (department A–D + template)

Legend: ✅ enforced · ⚠️ planned, needs decision/action/execution · ❌ not addressed.

### A. Document format
| # | Requirement | Status | Where / note |
|---|---|---|---|
| A1 | Length 40–50 pages (main body only) | ✅ | §2.4 body subtotal = 47 pp; front matter/refs/appendices uncounted; overflow → relocate (never delete) |
| A2 | Times New Roman, size 13 | ⚠️ | §2.10 — template gives 13 pt via `scrextend` but its own (non-TNR) font; confirm whether TNR overrides the template |
| A3 | Line spacing 1.5 | ✅ | template `\onehalfspacing` |
| A4 | Justified alignment | ✅ | LaTeX default |
| A5 | Chapter 16 / section 14 / subsection 13 pt | ⚠️ | §2.10 — template `titlesec` uses bold `\normalsize`; confirm whether slide sizes override |
| A6 | Figures/tables numbered by chapter, captioned, referenced | ✅ | §2.6 + §4 master list (per-chapter, caption + body ref each) |
| A7 | Clean, no spelling errors, no large blanks | ⚠️ | §8 final polish pass; float placement |

### B. Required structure
| # | Requirement | Status | Where / note |
|---|---|---|---|
| B1 | TOC, LoF, LoT, list of abbreviations | ✅ | §2.2/§2.5 — template prints all four (abbreviations after TOC) |
| B2 | VN abstract + EN title + EN abstract | ✅ | §2.5 FM-5 (`tomtat.tex`, EN first); EN title on abstract page |
| B3 | Acknowledgments | ✅ | §2.5 FM-3 (`thanks.tex`) |
| B4 | Introduction (objectives, scope, results, methods) | ✅ | Ch.1 §1.2–1.4 |
| B5 | Theory/methods/architecture in 1–2 chapters | ✅ | §2.3 — implementation block = **2 chapters** (Ch.3 design + Ch.4 verification); within the "1–2" rule |
| B6 | System block diagrams + algorithm flowcharts | ✅ | block diagrams F3.1–F3.3; flowcharts F3.11/F3.12 |
| B7 | Implementation/experimental results chapter | ✅ | Ch.5 |
| B8 | Conclusion (results, knowledge, skills, future, limitations) | ✅ | Ch.6 §6.1–6.4 |
| B9 | References | ✅ | §2.7 (`biblatex`, single English bibliography, heading REFERENCES) |

### C. References
| # | Requirement | Status | Where / note |
|---|---|---|---|
| C1 | Minimum 10, fully formatted | ✅ | §2.7 lists 12 candidates |
| C2 | Book/Journal/Conference handled | ✅ | §2.7 `biblatex` entry types (`@book`/`@article`/`@inproceedings`) |
| C3 | Limit internet links | ⚠️ | §2.7 — online-only kept to R9/R10 |
| C4 | ISBN (conf) / ISSN (journal) / DOI where available | ⚠️ | §2.7 — provided w/ verify notes; R11/R12 to source |
| C5 | Every reference cited in body | ⚠️ | §8 citation-completeness pass |

### D. English writing
| # | Requirement | Status | Where / note |
|---|---|---|---|
| D1 | Correct grammar, formal/academic vocabulary | ⚠️ | §2.11 — EN abstract + all body prose; execution pending |
| D2 | Grammarly + QuillBot | ⚠️ | §2.11/§8 action item |
| D3 | Every quoted/paraphrased paper, book, or standard carries a full in-body citation + matching references entry | ⚠️ | §2.11 — stronger than C5; targets borrowed text/claims specifically |

### Template fidelity
| # | Requirement | Status | Where / note |
|---|---|---|---|
| E1 | `extreport`+`scrextend` engine (pdfLaTeX) | ⚠️ | §2.1 — adopt on migration (§8); supersedes prior XeLaTeX plan |
| E2 | Exact front-/back-matter page sequence | ⚠️ | §2.2/§2.5 — create template `Title/`+`Appendix/` files on migration |
| E3 | 6-chapter map (design/verification split, current LaTeX) | ✅ | §2.3 (2026-06-27, supersedes the template-exact merge); within dept "1–2 implementation chapters" |
| E4 | `biblatex` single English bibliography, `myacronyms` glossary | ⚠️ | §2.7/§2.8 — wired on migration |
| E5 | Template `titlesec`/labels/listings/table styles | ✅ | §2.6/§2.9 (documented; applied on migration) |

**No ❌ items** — every requirement is enforced or captured as a tracked action/decision.

---

> **Note:** this plan intentionally has no separate "known mismatches / missing-info" section. Spec-vs-RTL drift
> is tracked in `docs/spec_rtl_audit.md`, and the code-wins policy governs any conflict.

---

## 10. Terminology & Abbreviations (canonical MIPI I3C vocabulary)

All thesis prose, section/figure/table captions, and abstracts use the canonical terms below. RTL
identifiers stay verbatim in `code font`; on first mention, map the identifier to the spec term (e.g.
"the Repeated START request (RTL: `gen_rstart_i`)"). Unless tagged **HCI**, every term is defined in the
**MIPI I3C Basic Specification v1.1.1 (with Errata 01, 2022)** — clause given in the table. HCI
queue/descriptor terms come from **MIPI I3C HCI v1.2** (externally cited in `phase1_spec_v2.md`; not in
repo) + internal `docs/module_specs/06_hci_queues_spec.md`. This table is the source for the front-matter
**List of Abbreviations** (FM-7, via `myacronyms.sty`). Appendix H is distinct: it provides definitions and
specification pointers rather than duplicating the front-matter expansion list.

### 10.1 Term-by-term change list applied (representative; spec clause)

| Was (forbidden) | Now (canonical) | Spec clause | Notes |
|---|---|---|---|
| master / single-master / current master | Controller / single-Controller / Active Controller | §2.2 (deprecates "Master") | literal file/doc names (e.g. "master list") keep their spelling |
| slave / Target-slave mode | Target / Target mode | §2.2 (deprecates "Slave") | — |
| multi-master | Secondary Controller (multiple Controllers) | §2.2 | entrenched term reworded, not dropped |
| device (as addressed target); per-device; multi-device; device-mode agent | Target; per-Target; multi-Target; Target agent | §2.2 | generic "I3C Device" / "device" (umbrella) kept |
| open-drain / push-pull (lowercase) | Open Drain (OD) / Push-Pull (PP) | §2.2 | Title Case; expand acronym on 1st use |
| repeated-START / restart | Repeated START (Sr) | §2.2 | RTL `*_rstart_*` / `gen_rstart_i` / `takeover_i` kept |
| bus-idle / bus-free (vague) | Bus Free Condition (this design's case) | §5.1.3.2.1 | Available/Idle are distinct (§5.1.3.2.2/.3) |
| T-bit / parity bit / 9th bit | T-Bit (Transition Bit) | §2.2 | "odd-parity value" kept as a *description* |
| command byte / command code | Common Command Code (CCC) | §2.2, §5.1.9 | — |
| broadcast/direct command | Broadcast CCC / Direct CCC | §5.1.9.3 | — |
| CMD/RESP FIFO; TX/RX FIFO; CMD/RESP descriptor | Command/Response Queue; TX/RX Data Buffer; Command/Response Descriptor | HCI v1.2 / spec 06 | "FIFO" kept only for the RTL `sync_fifo` impl |
| PID/BCR/DCR/DAT/DCT/IBI (unexpanded) | expanded on first mention per chapter | see table | acronym reused freely thereafter |

### 10.2 Canonical table

| Term | Abbr. | Definition | Spec clause | Avoid |
|---|---|---|---|---|
| Controller | — | I3C Device that controls the Bus | §2.2 | master, host |
| Active Controller | — | The Controller presently in control of the Bus | §2.2 | current master |
| Target | — | Device that responds to a Controller | §2.2 | slave, device (as target) |
| I3C Device | — | Umbrella term; Controller and Target are Roles | §2.2 | — |
| Dynamic Address | — | Address assigned during Bus initialization | §2.2 | assigned address |
| Static Address | — | Fixed, unchangeable Device Address | §2.2 | fixed addr, I²C address |
| Dynamic Address Assignment | DAA | Process of assigning Dynamic Addresses | §5.1.4 | address-assignment process |
| Enter DAA (CCC) | ENTDAA | CCC `0x07` that starts DAA | §5.1.9.3.4 | enter-DAA, DAA command |
| Common Command Code | CCC | Standard command issued to Targets | §2.2, §5.1.9 | command byte/code |
| Broadcast CCC / Direct CCC | — | CCC to all Targets / to one Target | §5.1.9.3 | global/targeted command |
| I3C Broadcast Address | — | `7'h7E`; addresses all Targets | §2.2 | general call |
| Defining Byte | — | Optional byte qualifying a CCC | §5.1.9.3 | sub-command byte |
| Single Data Rate Mode | SDR | Data on one clock edge | §2.2 | normal/base mode |
| High Data Rate Mode | HDR | Higher-speed modes (DDR/TSP/TSL) | §2.2 | high-speed/fast mode |
| Open Drain | OD | High-Z output with active pull-down | §2.2 | open-collector |
| Push-Pull | PP | Active pull-up and pull-down driver | §2.2 | driven, totem-pole |
| START / Repeated START / STOP | Sr | Bus framing conditions | §2.2 | restart, begin/end condition |
| Bus Free Condition | — | Period after STOP, before START (tCAS/tBUF) | §5.1.3.2.1 | idle/free bus |
| Bus Available Condition | — | Bus Free sustained tAVAL (Target may START) | §5.1.3.2.2 | idle bus |
| Bus Idle Condition | — | SDA+SCL High for tIDLE (Hot-Join) | §5.1.3.2.3 | idle bus |
| Transition Bit | T-Bit | Per-word bit (parity in write, end-of-data in read) replacing ACK in SDR data | §2.2 | parity/9th bit |
| Acknowledge / Not-Acknowledge | ACK/NACK | Address-phase acknowledgement | §2.2 | — |
| Read/Write bit | RnW | Direction bit in the Address Header | §5.1.2 | direction bit |
| Address Header | — | Address byte + RnW on the Bus | §5.1.2.2 | addressing phase, header byte |
| In-Band Interrupt | IBI | Target emits its address to interrupt the Controller | §2.2 | interrupt, async event |
| Hot-Join | — | Target joins an already-running Bus | §2.2 | hot-plug, late attach |
| Provisioned ID | PID | 48-bit Target identifier used in DAA | §5.1.4.1.1 | device ID, UID |
| Bus Characteristics Register | BCR | 8-bit Target capability register | §5.1.1.2.1 | (singular "Characteristic") |
| Device Characteristics Register | DCR | 8-bit Target type register | §5.1.1.2.2 | (singular "Characteristic") |
| Command / Response Descriptor | — | **HCI:** command and completion descriptors | HCI v1.2 / spec 06 | paraphrases |
| Transfer Command / Immediate Data Transfer / Regular Transfer | — | **HCI:** command-descriptor transfer types | HCI v1.2 / spec 06 | paraphrases |
| Device Address Table | DAT | **HCI:** per-Target address/config table | HCI v1.2 / spec 06 | — |
| Device Characteristics Table | DCT | **HCI:** DAA result table (unused here) | HCI v1.2 / spec 06 | — |
| Command / Response Queue | — | **HCI:** SW→HW command, HW→SW response queues | HCI v1.2 / spec 06 | CMD/RESP FIFO |
| TX / RX Data Buffer | — | **HCI:** SW↔HW data queues | HCI v1.2 / spec 06 | TX/RX FIFO |

*Verification (non-MIPI): UVM, TLM, SVA, FSM, CSR — standard EDA/Accellera terms, used as-is.*

### 10.3 Concepts with NO spec-defined term — left as-is (do not invent)

"Three-layer architecture", "command-issue algorithm flowchart" (design labels); UVM/Accellera terms
(scoreboard, virtual sequence/vseq, TLM, agent/driver/monitor/sequencer, coverage); the `abort` control
input on `flow_active` (a generic abort request — **not** the spec In-Band Interrupt); and all RTL
module/signal names. "Host" is kept where it means the software/CPU side (the canonical HCI sense), not the
bus Controller.
