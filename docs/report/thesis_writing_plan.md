# Thesis Writing Plan — "Design of an I3C Communication Controller"

## Metadata

- **Title (VN):** Thiết kế bộ điều khiển truyền thông I3C
- **Author:** Vo Minh Huy (22207042)
- **Supervisor:** ThS. Nguyễn Duy Mạnh Thi
- **University / Faculty:** HCMUS, Khoa Điện Tử – Viễn Thông · 10 credits
- **Branch / verified commit:** `refactor/flow-active-error-coverage` · exact commit to be confirmed · re-verified against RTL+UVM 2026-06-28
- **Structure:** six chapters, design/verification split (Ch.3 design, Ch.4 verification)

### Chapter structure

| Ch. | LaTeX file | Vietnamese title |
|---|---|---|
| 1 | `chapters/01_introduction_full` | Giới thiệu |
| 2 | `chapters/02_background_requirements` | Cơ sở lý thuyết và Yêu cầu hệ thống |
| 3 | `chapters/03_architecture_rtl` | Kiến trúc và Thiết kế RTL |
| 4 | `chapters/04_verification` | Phương pháp kiểm chứng và Môi trường UVM |
| 5 | `chapters/05_results` | Kết quả và Đánh giá |
| 6 | `chapters/06_conclusion` | Kết luận và Hướng phát triển |

---

## Core writing rules

**Chapter ownership rule (prevents cross-chapter duplication):**

> **Ch.2 defines it → Ch.3 implements it → Ch.4 verifies it → Ch.5 measures it → Ch.6 reflects on it.**

- **Ch.1 frames** motivation, objective, high-level boundary, contributions. Points to Ch.2 for detailed scope, Ch.5 for changing counts/metrics.
- **Ch.2 owns** protocol theory and the complete requirements/out-of-scope lists. UVM introduction = vocabulary only.
- **Ch.3 owns** architecture and RTL decisions. One qualitative CHIPS Alliance comparison; LoC/percentages → Ch.5.
- **Ch.4 owns** verification methodology and environment structure. Results/coverage/waveforms → Ch.5; limitations/future work → Ch.6.
- **Ch.5 owns** the verified commit, count methodology, all volatile metrics, regression evidence, coverage, implementation metrics, evaluation against Ch.2 requirements.
- **Ch.6 owns** limitations and the future-work roadmap.

Before adding a section, table, or figure, identify its owner. Other chapters use one-sentence pointers only.

**Settled decisions:**
- **Language = Vietnamese.** All prose, section titles, figure/table/appendix captions, the primary TÓM TẮT abstract, and all front-/back-matter titles are Vietnamese. The required bilingual English ABSTRACT follows the TÓM TẮT (VN first).
- **Vietnamese structural labels** throughout: CHƯƠNG, Hình, Bảng, MỤC LỤC, DANH MỤC HÌNH, DANH MỤC BẢNG, DANH MỤC TỪ VIẾT TẮT, PHỤ LỤC, TÀI LIỆU THAM KHẢO, Thuật toán, Đầu vào, Đầu ra. Write "CHƯƠNG 1: Giới thiệu", "Hình 4.5", "Bảng 4.1" — never `CHAPTER`/`Figure`/`Table`.
- **Established English technical terms are retained, never translated** (full policy + list: §9.3).
- **FPGA is not completed work** — it appears only as future work (Ch.6); Results carries no FPGA data. Appendix F (FPGA) is dropped.
- **Design and verification stay split** into Ch.3 and Ch.4.
- **Scope details live in Ch.2, not Ch.1** — Ch.1 §1.2 gives one framing paragraph and forward-references Ch.2.
- **Tooling = Cadence Xcelium + UVM 1.2 + SimVision.**
- **Engine = pdfLaTeX + `extreport`** (template default).

---

## 0. Ground-truth and correctness rules

**Ground-truth policy:** the current RTL (`src/rtl/**`), module specs (`docs/module_specs/**`), and UVM (`src/verification/uvm_i3c/**`) are authoritative for **what the design implements**. Where `phase1_spec_v2.md`, `I3C_Testplan.md`, the supervisor outline, or older spec text disagree, **the code wins**. `bug_analysis_report.md` does not exist — do not cite it.

**MIPI-compliance gate (BLOCKING — runs before any protocol-asserting chapter).** The official **MIPI I3C Basic v1.1.1** spec (`docs/mipi_i3c_spec.pdf`; OCR extract `docs/mipi_i3c_spec.md` has mangled tables — verify numerics against the PDF) is the **authority for protocol correctness**. Before writing any section that asserts a protocol fact, cross-check the RTL and project specs against it.

- The MIPI gate sits **above** the ground-truth policy: code-wins governs *what the design does*; the MIPI gate governs *whether that behaviour is protocol-correct*.
- **On any mismatch: STOP.** List every mismatch (claim · what the RTL/spec says · what MIPI says · spec clause · severity), terminate the session, and surface the list. Do not edit the thesis to hide a deviation.
- **On clean:** append a one-line PASS entry to the gate log and proceed. Protocol-asserting chapters are Ch.2, Ch.3, Ch.4.

**Gate log:**

| Date | Scope | Result |
|---|---|---|
| 2026-06-24 | Protocol theory (Ch.2) | PASS — 12.5 MHz SDR PP ceiling; Table 87 minimums (tLOW/tHIGH 24 ns, tSU_PP 3 ns, tSCO max 12 ns); broadcast `7'h7E`; three bus conditions (§5.1.3.2.1–.3); ENEC 0x00/0x80, DISEC 0x01/0x81, ENTDAA 0x07 (Table 17); ENTDAA 48-bit PID + 8-bit BCR + 8-bit DCR then dyn-addr+parity ACK loop; T-Bit roles; OD addr/ACK vs PP data. No contradiction. |
| 2026-06-28 | Architecture (Ch.3) | PASS — broadcast `7'h7E` (`I3C_RSVD_ADDR`), `CCC_ENTDAA=8'h07`, ENTDAA per-Target sequence in `entdaa_fsm.sv`, immediate-CCC set, write T-Bit odd parity, OD/PP phasing all match MIPI. Note: Response-Descriptor `ERR_STATUS` (0x0–0xA) is an HCI/TCRI interface convention (TCRI 7.1.3 Table 11), not a MIPI clause — presented as the implementation's interface error model. |
| 2026-06-28 | Verification (Ch.4) | PASS — introduces no new protocol assertion; every protocol fact is a subset of the Ch.2/Ch.3 verified sets and is exercised, not redefined. |
| 2026-07-07 | Results + Conclusion (Ch.5, Ch.6) | PASS — chapters report measured results and roadmap only; protocol mentions (OD address/ACK vs PP payload, T-Bit, START/STOP, ENTDAA loop) are subsets of the Ch.2/Ch.3 verified sets; IBI/Hot-Join/HDR appear as feature names without protocol claims. |

---

## 1. Ground-truth facts (cite verbatim)

| Fact | Value | Source of truth |
|---|---|---|
| `flow_active` FSM | 13 states (Idle…WriteResp) | `src/rtl/ctrl/flow_active.sv` `flow_fsm_state_e` |
| `scl_generator` FSM | 13 states (Idle…BusFree) | `src/rtl/ctrl/scl_generator.sv` `state_e` |
| `entdaa_controller` / `entdaa_fsm` | 7 / 8 states; `DatDepth`=32 | specs 08 / 08b |
| `bus_tx_flow` / `bus_rx_flow` | 4 states `[2:0]` each | specs 04 / 05 |
| `bus_tx` | 5 states | spec 04 |
| CSR map | 26 regs + 32-entry DAT | `csr_registers.sv`, spec 07 |
| Error codes generated | 0x0, 0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xA (0x5=DAA double-reject, 0x9=I2C data NACK/bus abort) | `flow_active.sv` `map_resp_err_status()`; `phase1_spec_v2.md` §9.4 |
| Runnable vseq scenarios | 75: bus12/ccc5/csr15/daa6/fifo5/imm4/resp13/sdr_read6/sdr_write5/i2c4; + one non-runnable base vseq | `i3c_vseqs/**` (snapshot 2026-06-28) |
| Driver phases | 14 device-only (`i3c_drv_phase_e`, `DrvIdle`…`DrvDAA`) | `dv_i3c/i3c_agent_pkg.sv` |
| SVA | 10 files: 9 bound checkers + `tb_pad_model_sva` instantiated | `i3c_core/sva/**`, `tb_i3c_top.sv` |
| Implementation size | **Not frozen.** Current raw `src/rtl/**/*.sv` = 5,080 lines; Ch.5 must define exclusions and reproduce both project/reference counts before stating a reduction %. | filesystem snapshot 2026-06-28 |

Testplan defines ~105 cases; the 75-vseq count is a WIP snapshot. Re-enumerate from disk when writing Ch.5 / Appendix I.

---

## 2. Template / format requirements

Format authority = **HCMUS KLTN template** (`~/Workspaces/Thesis_Template_latex`). Department slides govern content quotas (length, ≥10 references, abstracts, English-writing). Where the faculty slide conflicts with the template on typography, the faculty slide wins.

### 2.1 Global format contract

| Item | Setting |
|---|---|
| Document class | `\documentclass[twoside,a4paper,14pt,openright]{extreport}` |
| Body font size | `\usepackage[fontsize=13pt]{scrextend}` → 13 pt |
| Body font family | **Times New Roman via `\usepackage{tgtermes}`** (TeX Gyre Termes, `qtm`; T5-Vietnamese-safe). NOT `mathptmx`/`newtx`/bare `times` (drop T5 diacritics); NOT XeLaTeX/`fontspec`. |
| Heading sizes | `titlesec`: Chapter 16 pt / Section 14 pt / Subsection 13 pt |
| Encoding | `\usepackage[T5]{fontenc}` + `\usepackage[utf8]{inputenc}` + `\DeclareTextSymbolDefault{\DH}{T1}`; compiles on pdfLaTeX |
| Line spacing | `setspace` + `\onehalfspacing` (1.5) |
| First-line indent | `indentfirst` |
| Margins | `geometry`: `twoside, top=20mm, bottom=20mm, left=25mm, right=20mm, footskip=15mm, includefoot` |
| Page numbering | `fancyhdr`, bottom-right (`\fancyfoot[R]{\thepage}`); roman front matter, arabic body |
| Bibliography | `\usepackage[sorting=nty,backend=bibtex,defernumbers=true]{biblatex}` + `\addbibresource{References/references.bib}` |
| Hyperlinks | `\usepackage[unicode]{hyperref}` |
| Graphics root | `graphicx` + `\graphicspath{{Images/}}` |
| Author macros | `\tenSV` `\mssv` `\tenKL` `\tenGVHD` `\tenBM` (fill once in `report.tex`) |

### 2.2 Document page sequence

```
\input{Title/title.tex}                 % HCMUS faculty cover (2 title pages)
\pagenumbering{roman}
\include{Appendix/editComfirmation}      % XÁC NHẬN CHỈNH SỬA (post-defense)
\include{Appendix/thanks}                % LỜI CẢM ƠN
\include{Appendix/reassurances}          % LỜI CAM ĐOAN
\include{Appendix/tomtat}                % TÓM TẮT (VN, primary) + ABSTRACT (EN) — VN first
\tableofcontents                         % MỤC LỤC
\printglossary[type=\acronymtype, …]     % DANH MỤC TỪ VIẾT TẮT
\listoffigures                           % DANH MỤC HÌNH
\listoftables                            % DANH MỤC BẢNG
\pagenumbering{arabic}
\include{chapters/01_introduction_full}  % CHƯƠNG 1
\include{chapters/02_background_requirements}
\include{chapters/03_architecture_rtl}
\include{chapters/04_verification}
\include{chapters/05_results}
\include{chapters/06_conclusion}
\include{Appendix/publish}               % DANH MỤC CÔNG TRÌNH (optional — omit if none)
\printbibheading + \printbibliography    % TÀI LIỆU THAM KHẢO
\include{Appendix/appendixA}             % PHỤ LỤC A
...
\include{Appendix/appendixI}             % PHỤ LỤC I
```

### 2.3 Front-/back-matter checklist

Legend: ☐ not started · ◑ drafted · ☑ final. All ☐.

| # | Item (file) | Language | Notes |
|---|---|---|---|
| FM-1 | Title page (`Title/title.tex`) | VN | Fill `\tenSV`/`\mssv`/`\tenKL`/`\tenGVHD`/`\tenBM` |
| FM-2 | Xác nhận chỉnh sửa (`editComfirmation.tex`) | VN | Filled post-defense |
| FM-3 | Lời cảm ơn (`thanks.tex`) | VN | Acknowledgements |
| FM-4 | Lời cam đoan (`reassurances.tex`) | VN | Declaration of authorship |
| FM-5 | TÓM TẮT + ABSTRACT (`tomtat.tex`) | VN + EN | VN first; Background/Purpose/Method/Results/Evaluation; <1 page; keywords both |
| FM-6 | Mục lục (`\tableofcontents`) | auto | — |
| FM-7 | Danh mục từ viết tắt | VN | `\printglossary` via `myacronyms.sty`; populate from §9 |
| FM-8 | Danh mục hình (`\listoffigures`) | auto | — |
| FM-9 | Danh mục bảng (`\listoftables`) | auto | — |
| BM-1 | Danh mục công trình (`publish.tex`) | VN | Optional — omit (no publications) |
| BM-2 | Tài liệu tham khảo (`references.bib`) | EN sources | `biblatex`, single bibliography; see §2.5 |
| BM-3…10 | Phụ lục A–I | VN prose | See §Appendices |

### 2.4 Heading, caption, float & label conventions

- `\setcounter{secnumdepth}{3}`.
- **Chapter:** `[block]` `\filcenter\bfseries\fontsize{16}{19}\selectfont`, prefix "CHƯƠNG \thechapter :", `\titlespacing*{\chapter}{0pt}{-10pt}{10pt}` → centered, bold, 16 pt.
- **Section:** `\bfseries\fontsize{14}{17}` → 14 pt. **Subsection/Subsubsection:** `\bfseries\fontsize{13}{16}` → 13 pt. Keep decimal numbering + 1em gaps.
- **Labels (Vietnamese):** keep `\chaptername=CHƯƠNG`, `\figurename=Hình`, `\tablename=Bảng`, `\contentsname=MỤC LỤC`, `\listfigurename=DANH MỤC HÌNH`, `\listtablename=DANH MỤC BẢNG`, `\appendixname=PHỤ LỤC`; abbreviations/references headings via `\printglossary[title=DANH MỤC TỪ VIẾT TẮT]` / `\printbibheading[title=TÀI LIỆU THAM KHẢO]`; algorithm labels Thuật toán / Đầu vào / Đầu ra. English technical terms *inside* a heading are retained (§9.3).
- **Numbering:** figures/tables by chapter (Hình 4.5, Bảng 4.3).
- **Captions:** `caption` package; below figures, above tables. Every figure/table has a caption and is referenced in the body.

### 2.5 References — `biblatex`, ≥10, cited-in-body

```latex
\usepackage[sorting=nty,backend=bibtex,defernumbers=true]{biblatex}
\addbibresource{References/references.bib}
\printbibheading[title={TÀI LIỆU THAM KHẢO}]
\DeclareNameAlias{sortname}{last-first}\DeclareNameAlias{default}{last-first}
\printbibliography[resetnumbers=1]      % single list (English-language sources)
```

- All sources are English-language → one numbered list; only the heading is Vietnamese.
- **Build (release):** delete aux artifacts → pdflatex → bibtex → makeglossaries → pdflatex → pdflatex (`bibtex` backend, not `biber`).

**Candidate source list (12 → ≥10):**

| # | Reference | `biblatex` type | Identifier | Cited in |
|---|---|---|---|---|
| R1 | MIPI Alliance, *MIPI I3C Basic Specification v1.1.1* (incl. Errata 01) | `@manual`/`@techreport` | spec no. / year | Ch.2–4 |
| R2 | NXP, *I²C-bus Specification* (UM10204, Rev. 7.0) | `@manual` | doc no. / year | Ch.3 |
| R3 | IEEE Std 1800-2017 — SystemVerilog LRM | `@manual`/`@techreport` | DOI 10.1109/IEEESTD.2018.8299595 *(verify)* | Ch.4 |
| R4 | Accellera, *UVM 1.2 User's Guide* | `@manual` | year | Ch.3/Ch.4 |
| R5 | Accellera, *UVM 1.2 Class Reference* | `@manual` | year | Ch.4 |
| R6 | S. Palnitkar, *Verilog HDL*, 2nd ed. | `@book` | ISBN 978-0132599702 *(verify)* | Ch.4 |
| R7 | C. Spear & G. Tumbush, *SystemVerilog for Verification*, 3rd ed. | `@book` | ISBN 978-1461407140 *(verify)* | Ch.4 |
| R8 | S. Harris & D. Harris, *Digital Design and Computer Architecture*, 2nd ed. | `@book` | ISBN 978-0123944245 *(verify)* | Ch.3/Ch.4 |
| R9 | CHIPS Alliance, *i3c-core* (GitHub) | `@online` | commit SHA, accessed date | Ch.1/Ch.3/Ch.5 |
| R10 | lowRISC OpenTitan, *DV framework / `dv_macros.svh`* | `@online` | commit/version | Ch.4 |
| R11 | **TO SOURCE:** conference paper on I3C controller design/verification | `@inproceedings` | ISBN + DOI | Ch.1/Ch.2 |
| R12 | **TO SOURCE:** journal paper on UVM-based functional verification | `@article` | ISSN + DOI | Ch.2/Ch.4 |

**Content rules:** (1) ≥10 entries; (2) ISBN on conference proceedings, ISSN on journals, DOI where available; (3) every entry `\cite`d at least once (orphan-check); (4) internet-only limited to R9/R10; (5) R11/R12 must be real sourced papers.

### 2.6 Acronyms / glossary (`myacronyms.sty`)

`\usepackage{myacronyms}` → `\RequirePackage[acronym,toc]{glossaries}` + `\makeglossaries`; printed as DANH MỤC TỪ VIẾT TẮT after the TOC. Define via `\newacronym{key}{SHORT}{Long}`; use `\acrshort`/`\acrlong`/`\acrfull`. Populate from §9 (Controller, Target, DAA, ENTDAA, CCC, OD, PP, SDR, HDR, Sr, T-Bit, RnW, IBI, Hot-Join, PID, BCR, DCR, DAT, DCT, HCI, UVM, TLM, SVA, FSM, CSR). Build chain needs `makeglossaries`.

### 2.7 Listing / algorithm / table styles

- **Code listings:** template `listings` `mystyle` (coloured, `\footnotesize`, `breaklines`, `numbers=left`, `tabsize=2`). Add `morekeywords={logic,always_ff,always_comb,typedef,struct,packed,enum,interface,module,endmodule,package,endpackage,import}`. Snippets ≤30 lines; `\lstinputlisting` from `SourceCode/` for longer.
- **Algorithms:** `algorithm` + `algpseudocode`, Vietnamese captions — `\floatname{algorithm}{Thuật toán}`, `\renewcommand{\algorithmicrequire}{\textbf{Đầu vào:}}`, `\renewcommand{\algorithmicensure}{\textbf{Đầu ra:}}`.
- **Tables:** column types `L{w}`/`C{w}`/`R{w}` (via `array`), `multirow`, `diagbox`, `xcolor[table,xcdraw]`, `pmboxdraw` tree glyphs. `booktabs`/`longtable` may be added for long appendix tables.

### 2.8 Directory layout & build

```
docs/report/latex/
  report.tex                       % template preamble + body order (main.tex role)
  Title/title.tex                  % faculty cover (currently inline in report.tex)
  chapters/01_introduction_full.tex … 06_conclusion.tex
  Appendix/  editComfirmation.tex thanks.tex reassurances.tex tomtat.tex appendixA..I.tex
  references.bib                   % ≥10 sources (§2.5)
  Images/                          % rendered figures
  SourceCode/                      % SV snippets for \lstinputlisting
  myacronyms.sty                   % acronyms from §9
```

Use the `chapters/0X_*.tex` scheme (not `Content/chapterN.tex`). **Build (release):** delete aux → `pdflatex` → `bibtex` → `makeglossaries` → `pdflatex` → `pdflatex`. `latexmk -pdf report.tex` is fine for drafting.

```bash
pdflatex report.tex
bibtex report
makeglossaries report
pdflatex report.tex
pdflatex report.tex
```

Optional tidy-ups (not blockers): add `Title/title.tex`, split `appendices/appendices.tex` into `Appendix/appendixA..I.tex`, add `Images/`/`SourceCode/`.

---

## 3. Page budget

The 40–50 pp rule is the department quota and applies to the **main body only** (Ch.1→Ch.6). Front matter, references, appendices are uncounted and unlimited.

| Chapter | Title | Est. pages | Risk |
|---|---|---:|---|
| Ch.1 | Giới thiệu | 2.5–3 | prose-only, no figures/tables; scope framed briefly (canonical → Ch.2) |
| Ch.2 | Cơ sở lý thuyết và Yêu cầu hệ thống | 5.5–6.5 | concise + requirements-driven; Part A = minimum background only; UVM = vocabulary only |
| Ch.3 | Kiến trúc và Thiết kế RTL | 15 | **highest risk** (full RTL) — relocate full CSR map/state tables/port lists/descriptor layouts to Appendices A–C |
| Ch.4 | Phương pháp kiểm chứng và Môi trường UVM | 8–9 | 11 sections; tools = one paragraph; relocate full vseq inventory → App. I, regression command list → App. G |
| Ch.5 | Kết quả và Đánh giá | 7 | owns all evidence and volatile metrics |
| Ch.6 | Kết luận và Hướng phát triển | 4 | owns limitations and roadmap |
| | **Body subtotal** | **≈42–44.5** | within 40–50 |

Uncounted: front matter ~8–10 pp · references ~2 pp · Appendices A–E,G–I ~12–18 pp. Total ≈ 64–74 pp — expected and acceptable.

**Content-preservation directive (overrides any page-trimming pass):**
1. Within budget → write it fully; no padding, no trimming.
2. Body would exceed 50 → **RELOCATE, never delete.** Move reference material (large tables, full FSM enumerations, complete CSR maps, long listings, vseq inventory, regression dumps) to appendices; leave a short pointer + representative excerpt.
3. Still over → tighten wording only.
4. Never drop a figure, table, finding, or mismatch item to save space.

**Relocation plan:** full CSR map (T3.4) → App. A; CMD/RESP/DAT descriptor layouts (T3.1) → App. B; full FSM state-transition tables (T3.3 + per-module) → App. C; per-module port lists (T3.5) → App. B/C; full vseq inventory (T4.x) → App. I; regression-target + SEQ lists → App. G. Keep inline: flagship `flow_active` 13-state FSM, top-level + dataflow block diagrams (Ch.3), UVM topology diagrams (Ch.4), one representative state table, key ports only, ≤30-line snippets, compact by-category vseq counts.

---

## 4. Chapter writing plan

Each entry: **Sections · Figures · Tables · essential constraints.** Page targets per §3.

### Chapter 1 — Giới thiệu (`01_introduction_full`) · ~2.5–3 pp · prose-only, no figures/tables

- **Sources:** outline PDF §1–4; `improvements.md`; `phase1_spec_v2.md` §1.
- **Sections:**
  - **1.1 Động lực và phát biểu bài toán** — I3C in SoC trends; the gap; short results-preview + one methodology sentence.
  - **1.2 Mục tiêu và phạm vi** — objectives + contributions + one concise scope-framing paragraph (no scope table).
  - **1.3 Bố cục khóa luận**.
- **Scope framing (§1.2):** one paragraph — the thesis targets an **I3C Active Controller** supporting **SDR private transfer**, **selected CCC operations**, **ENTDAA**, and **I²C-FM compatibility**; one sentence noting **HDR, IBI, Hot-Join, Secondary Controller, Target mode, and FPGA validation are out of scope**. End with a forward reference to Ch.2. Do not reproduce the detailed requirements here.
- **Notes:** no volatile counts. Name the CHIPS Alliance `i3c-core` baseline in one framing paragraph; point to Ch.3/Ch.5 for comparisons. Contributions stated qualitatively; volatile metrics → Ch.5. Fold Xcelium + UVM 1.2 + SimVision tooling into §1.1 or §1.2 (no standalone Tools section).
- **Terminology (§9.3):** VN prose; keep in English: SoC, System-on-Chip, Internet of Things, IoT, I²C, I3C, MIPI I3C, Hot-Join, In-Band Interrupt, IBI. English term first, VN explanation after.

### Chapter 2 — Cơ sở lý thuyết và Yêu cầu hệ thống (`02_background_requirements`) · ~5.5–6.5 pp · MIPI gate applies

- **Sources:** `phase1_spec_v2.md` §1/§2–7/§9–10; MIPI I3C Basic v1.1.1; Accellera UVM 1.2 User's Guide + Class Reference; specs 02, 03, 07, 11.
- **Part A · Theoretical Background (brief):**
  - Tổng quan I²C
  - MIPI I3C Basic v1.1.1: chế độ SDR và định dạng khung (frame format)
  - Các điều kiện bus: START / Repeated START / STOP (prose, no figure)
  - Tín hiệu Open-drain và Push-pull
  - Gán địa chỉ động (Dynamic Address Assignment) qua ENTDAA
  - Tổng quan Common Command Code (CCC): Broadcast / Direct
  - So sánh I3C và I²C
  - Tổng quan thuật ngữ UVM 1.2 (max half a page; project topology → Ch.4)
- **Part B · System Requirements (canonical owner of scope):**
  - Yêu cầu chức năng — full list (SDR private transfer, selected CCC, ENTDAA, I²C-FM)
  - Các tính năng ngoài phạm vi — full list (HDR, IBI, Hot-Join, Secondary Controller, Target mode, FPGA)
  - Chỉ tiêu hiệu năng (12.5 MHz / 400 kHz / ≥333 MHz sys clk)
  - Giao diện phần mềm (32-bit register bus; register protocol in prose)
  - Yêu cầu kiểm chứng
- **Figures (4):** F2.1 I²C vs I3C bus signalling; F2.2 Open Drain vs Push-Pull phases; F2.3 SDR frame format; F2.4 ENTDAA arbitration.
- **Tables:** T2.1 I3C-vs-I²C feature matrix; T2.2 SDR + I²C-FM timing parameters; T2.3 CCC subset overview (full → App. D); T2.4 functional requirements; T2.5 performance targets; T2.6 out-of-scope features.
- **Notes:** concise, requirements-driven; Part A is minimum background only, not a textbook. Error-code table belongs to Ch.3, not here. No separate related-work chapter — CHIPS Alliance framed in Ch.1, interpreted in Ch.3, measured in Ch.5.
- **Terminology (§9.3):** keep in English: Controller, Target, Active/Secondary Controller, SDR, HDR, Open-drain, Push-pull, T-Bit, ACK/NACK, CCC, DAA, ENTDAA, Hot-Join, IBI, and all UVM terms (Testbench, Agent, Driver, Monitor, Sequencer, Scoreboard, Functional Coverage, Assertion, SVA, Regression).

### Chapter 3 — Kiến trúc và Thiết kế RTL (`03_architecture_rtl`) ★ · ~15 pp · highest risk · MIPI gate applies

- **Sources:** specs 00–11; `improvements.md`; `CLAUDE.md` block diagram; `i3c_pkg.sv`, `controller_pkg.sv`; and read RTL directly — `flow_active.sv`, `scl_generator.sv`, `entdaa_controller.sv`+`entdaa_fsm.sv`, `csr_registers.sv`, `hci_queues.sv`/`sync_fifo.sv`, `bus_tx*.sv`/`bus_rx_flow.sv`, `bus_monitor.sv`, `i3c_phy.sv`, `controller_active.sv`, `edge_detector.sv`, `stable_high_detector.sv`.
- **Sections — architecture:** three-layer architecture · top module + block diagram · transaction dataflow (Host → CMD FIFO → `flow_active` → bus → RESP/RX) · clock/reset + signal conventions (2FF sync) · reference-derived design boundary (single qualitative CHIPS-Alliance comparison) · queue/DAT/descriptor formats · error-handling model.
- **Sections — RTL:** PHY (`i3c_phy`) · CSR + 32-entry DAT (`csr_register`) · HCI queues (`hci_queues`/`sync_fifo`; power-of-2 elaboration assert) · `bus_monitor` · `scl_generator` (13-state; DAA restart via `gen_rstart_i`) · TX/RX serializers (`bus_tx`, `bus_tx_flow`, `bus_rx_flow`) · ENTDAA subsystem (`entdaa_controller` 7-state + `entdaa_fsm` 8-state, Controller perspective) · **`flow_active` 13-state FSM (flagship)** — SDR/I²C write+read, private immediate merged into `IssueCmd`, CCC immediate (`cp=1`) via `IssueImmediateCcc`, ENTDAA, abort · `controller_active` wrapper + OD/PP switching.
- **Figures:** F3.1 three-layer architecture · F3.2 top-level block diagram · F3.3 transaction dataflow · F3.4 clock/reset & 2FF sync · F3.5 CHIPS Alliance `i3c-core` reference architecture · **F3.6 `flow_active` 13-state FSM (landscape, flagship)** · F3.7 `scl_generator` 13-state FSM · F3.8 `entdaa_controller` 7-state + `entdaa_fsm` 8-state · F3.9 `bus_tx`/`bus_tx_flow`/`bus_rx_flow` FSMs · F3.10 OD/PP switching · F3.11 `flow_active` command-issue algorithm flowchart · F3.12 ENTDAA per-Target loop algorithm flowchart.
- **Tables:** T3.1 queue/DAT/descriptor formats (→ App. B) · T3.2 error-status encoding · T3.3 `flow_active` 13-state table (→ App. C) · T3.4 full CSR map (→ App. A) · T3.5 per-module port lists (→ App. B/C). Per-module LoC tables → Ch.5.
- **Notes:** start FSM diagrams early (long pole). `scl_generator` restart/handoff driven by `gen_rstart_i` + `takeover_i` (fast-path `SdaFall` read takeover); use RTL names only. `flow_active` = 13 states (indices 0–12).

**Page-budget management (Ch.3 — manage, do not trim):**

| Block | Inline content | ~pp |
|---|---|---:|
| Architecture narrative | three-layer model, top block diagram, dataflow, clock/reset, error model, qualitative reference boundary (F3.1–F3.5; T3.2) | ~4 |
| RTL walkthrough — supporting modules | PHY, CSR+DAT, HCI queues, `bus_monitor`, `scl_generator`, TX/RX serializers, ENTDAA (one tight pass each; F3.7–F3.9) | ~6 |
| Flagship `flow_active` FSM | F3.6 (landscape) + F3.11 flowchart + deepest narrative | ~4 |
| `controller_active` + OD/PP | F3.10 + integration summary | ~1 |

- **Preferred inline:** F3.1–F3.3, F3.4, T3.2, flagship F3.6 + F3.11, one state diagram per supporting FSM (F3.7–F3.9), F3.10, F3.12; key ports only (3–6/module); ≤30-line snippets. The **non-relocatable core figures** are F3.1 (three-layer architecture), F3.2 (top-level block diagram), F3.3 (transaction dataflow), F3.6 (`flow_active` 13-state FSM), F3.10 (OD/PP switching logic), F3.11 (`flow_active` command-issue flowchart), F3.12 (ENTDAA per-Target loop flowchart). F3.7–F3.9 are preferred inline but may be combined into plates or moved to Appendix C if Ch.3 exceeds the page budget.
- **Relocated to appendices:** T3.4 → App. A; T3.1 + T3.5 → App. B; T3.3 + per-module state tables → App. C. Each inline mention leaves a one-line pointer + representative excerpt.
- **Per-supporting-module pattern (≤½ page):** (1) one-sentence role, (2) one diagram or key-port/state excerpt, (3) the single design decision vs CHIPS Alliance, (4) "full table → App. X". Reserve depth for `flow_active` only.
- **Overflow escalation (never delete):** (1) tighten wording; (2) relocate next-largest table, leave excerpt; (3) combine F3.7–F3.9 into plates or move to App. C; (4) demote a supporting-module subsection to a paragraph + pointer.

### Chapter 4 — Phương pháp kiểm chứng và Môi trường UVM (`04_verification`) ★ · ~8–9 pp · MIPI gate applies

- **Sources:** `i3c_scoreboard.sv`, `tb_i3c_top.sv`, `i3c_driver.sv`, `i3c_monitor.sv`, `i3c_base_vseq.sv`, `i3c_vseq_list.sv`, `i3c_csr_addr_pkg.sv`, `Makefile`, `i3c_vseqs/**`, `sva/**`; Accellera UVM 1.2 docs.
- **Sections (11):**
  - **4.1 Mục tiêu và phạm vi kiểm chứng** — verifies RTL vs Ch.2 requirements; targets: SDR private write/read, I²C-FM, CCC immediate, ENTDAA, CSR access, FIFO/queue, response/error reporting, reset/abort/corner cases. Put the short tools paragraph here.
  - **4.2 Chiến lược kiểm chứng** — directed + constrained-random, coordinated through Virtual Sequences; justify fit for the I3C Controller.
  - **4.3 Kiến trúc tổng thể của Testbench** — Test → Virtual Sequence → Virtual Sequencer → Register Agent / I3C Target Agent → Driver / Monitor → DUT interface → Scoreboard / Coverage / SVA; mention `tb_i3c_top`, clock/reset, DUT instantiation, virtual interfaces. **One UVM topology figure (F4.1).**
  - **4.4 Luồng TLM và cơ chế Scoreboard** — Monitor → Scoreboard via TLM analysis ports; checks address, RnW, payload, ACK/NACK, T-Bit, response descriptor, error status, FIFO/register side effects. Scoreboard = transaction-level; SVA = signal/protocol-property.
  - **4.5 Kiểm tra bằng SVA** — property groups: START/Sr/STOP, OD/PP phase, legal FSM transitions, FIFO handshake, CSR access, abort/error, pad-model. No pass/fail here (→ Ch.5).
  - **4.6 Chiến lược Functional Coverage** — the coverage model: transaction type, address, payload length, ACK/NACK, response/error status, FIFO state, driver phase, corner cases. Percentages → Ch.5.
  - **4.7 Register Agent** — host-side access: write CMD/TX FIFO, configure DAT, read RX/RESP FIFO, check CSR side effects.
  - **4.8 I3C Target Agent** — Target ACK/NACK, read data response, ENTDAA participation, SCL/SDA monitoring; driver phases (idle, address, ACK/NACK, data, T-Bit, DAA). Keep driver-phase table compact.
  - **4.9 Virtual Sequencer và Virtual Sequence Library** — how the Virtual Sequencer coordinates both agents; describe the vseq library **by category only** (bus, CSR, CCC, DAA, FIFO, immediate data, response, SDR read, SDR write, I²C). Full inventory → App. I.
  - **4.10 Quy trình build, run và debug** — merged build/run + waveform/debug:
    ```bash
    make sim TEST=i3c_base_test SEQ=<sequence_name> SEED=<seed>
    make sim TEST=i3c_base_test SEQ=<sequence_name> SEED=<seed> COV=1
    ```
    Debug: log → assertion failure → SimVision waveform → trace vseq → driver → DUT → monitor → scoreboard. Full regression list → App. G.
  - **4.11 Tổng kết chương** — environment = Register Agent + I3C Target Agent + Virtual Sequencer + Scoreboard + SVA + Functional Coverage + Vseq Library; forward-point to Ch.5.
- **Tools paragraph (in 4.1 opening):** one short paragraph naming SystemVerilog, UVM 1.2, Cadence Xcelium, SimVision. No standalone "Why UVM/Xcelium" section or tool-comparison table.
- **Figures (3):** F4.1 UVM Testbench topology (§4.3) · F4.2 TLM flow Monitor → Scoreboard (§4.4) · F4.3 SVA binding / checker map (§4.5, if useful).
- **Tables (3):** T4.1 compact vseq category table (§4.9; full → App. I) · T4.2 driver-phase table (compact; §4.8) · T4.3 requirement-to-verification mapping (§4.11, if useful).
- **Notes:** write scoreboard/SVA from source. Re-enumerate vseqs from disk at Ch.5/App. I write time. No regression results, waveforms, coverage %, LoC metrics, limitations, or future-work here (→ Ch.5/Ch.6).

### Chapter 5 — Kết quả và Đánh giá (`05_results`) · ~7 pp · after green regressions

- **Sources:** sim logs/coverage from `make regression` + category regressions; `improvements.md`.
- **Sections:** verified baseline + measurement method (branch/commit/tools/seeds/file-selection) · quantitative implementation metrics (reproducible LoC; no pre-baked %) · regression results (pass/fail matrix) · waveform evidence (write/read/immediate/CCC) · functional coverage (implemented covergroups, `COV=1`) · comparison with CHIPS Alliance · evaluation against Ch.2 requirements.
- **Figures:** F5.1 annotated write + read waveforms · F5.2 functional-coverage screenshot · F5.3 implementation-size comparison chart.
- **Tables:** T5.1 verified baseline/count rules · T5.2 per-subsystem implementation metrics · T5.3 module LoC summary · T5.4 regression pass/fail matrix · T5.5 reference comparison · T5.6 requirements-evidence matrix.

### Chapter 6 — Kết luận và Hướng phát triển (`06_conclusion`) · ~4 pp · last

- **Sources:** all chapters; `phase1_spec_v2.md` out-of-scope list; `improvements.md` future-work notes.
- **Sections:** summary of contributions · knowledge, skills, lessons learned · **limitations** (single canonical list, implementation + evaluation) · future work (IBI, HDR, Target mode, multi-Target, full-protocol coverage closure, FPGA validation, ENTDAA/CCC/I²C test gaps).
- **Tables:** T6.1 future-work roadmap.
- **Notes:** single FPGA line here; no earlier chapter repeats this roadmap or limitation list.

### Appendices (A–I; F dropped)

| Phụ lục | Title | Source | Offloads |
|---|---|---|---|
| A | CSR register map (full bitfield tables) | `csr_registers.sv`, spec 07 | Ch.3 T3.4 |
| B | Command / Response / DAT descriptor formats | `i3c_pkg.sv`, `controller_pkg.sv` | Ch.3 T3.1/T3.5 |
| C | Complete FSM state tables (all RTL FSMs) | specs 03–09 | Ch.3 T3.3/T3.5 |
| D | CCC subset opcode/frame table | `phase1_spec_v2.md` §4 | Ch.2 T2.3 |
| E | Regression log excerpts | sim logs | Ch.5 evidence |
| F | ~~Synthesis/utilisation/timing~~ | — | **DROP** (FPGA omitted) |
| G | Build & run instructions (Makefile reference) | `src/verification/Makefile` | Ch.4 §4.10 |
| H | Glossary of I3C and HCI terms | §9 | definitions + spec pointers (not a duplicate acronym list) |
| I | Vseq inventory (75 runnable scenarios by category) | `i3c_vseqs/**` | Ch.4 T4.1 |

Render as `\chapter` blocks under `\appendix` with label PHỤ LỤC; English technical terms stay in titles. Finalise A–C with Ch.3, G/I with Ch.4, E with Ch.5.

---

## 5. Figure & table master list

Per-chapter numbering; every entry has a caption and a body-text reference. Chapter 1 has no figures/tables — numbering starts at F2.1 / T2.1.

### Figures

| ID | Caption | Body ref | Source |
|---|---|---|---|
| F2.1 | I²C vs I3C bus signalling | Ch.2 | MIPI/phase1 |
| F2.2 | Open Drain vs Push-Pull phases | Ch.2 | WaveDrom `bus/od_vs_pp` |
| F2.3 | SDR frame format (addr + data + T-Bit) | Ch.2 | WaveDrom `bus/sdr_*` |
| F2.4 | ENTDAA arbitration | Ch.2 | WaveDrom `bus/entdaa_arbitration` |
| F3.1 | Three-layer architecture | Ch.3 | spec 11 |
| F3.2 | Top-level block diagram | Ch.3 | `CLAUDE.md`/spec 11 |
| F3.3 | Transaction dataflow | Ch.3 | spec 11 |
| F3.4 | Clock/reset & 2FF sync | Ch.3 | `i3c_phy.sv` |
| F3.5 | CHIPS Alliance `i3c-core` reference architecture | Ch.3 | `improvements.md`/`CLAUDE.md` |
| F3.6 | `flow_active` 13-state FSM (landscape, flagship) | Ch.3 | `flow_active.sv` |
| F3.7 | `scl_generator` 13-state FSM | Ch.3 | `scl_generator.sv` |
| F3.8 | `entdaa_controller` 7-state + `entdaa_fsm` 8-state | Ch.3 | `entdaa_*.sv` |
| F3.9 | `bus_tx`/`bus_tx_flow`/`bus_rx_flow` FSMs | Ch.3 | `bus_tx*.sv`, `bus_rx_flow.sv` |
| F3.10 | OD/PP switching logic | Ch.3 | `controller_active.sv` |
| F3.11 | `flow_active` command-issue algorithm flowchart | Ch.3 | `flow_active.sv` |
| F3.12 | ENTDAA per-Target loop algorithm flowchart | Ch.3 | `entdaa_*.sv` |
| F4.1 | Overall UVM Testbench topology | Ch.4 §4.3 | `tb_i3c_top.sv`, `i3c_env.sv` |
| F4.2 | TLM flow (Monitor → Scoreboard) | Ch.4 §4.4 | `i3c_scoreboard.sv` |
| F4.3 | SVA binding / checker map | Ch.4 §4.5 | `sva/**`, `tb_i3c_top.sv` |
| F5.1 | Annotated write + read waveforms | Ch.5 | sim |
| F5.2 | Functional-coverage screenshot | Ch.5 | sim (COV=1) |
| F5.3 | Implementation-size comparison chart | Ch.5 | reproducible count output |

### Tables

| ID | Caption | Body ref | Source |
|---|---|---|---|
| T2.1 | I3C-vs-I²C feature matrix | Ch.2 | MIPI spec |
| T2.2 | SDR + I²C-FM timing parameters | Ch.2 | phase1 spec |
| T2.3 | CCC subset overview | Ch.2 (→ App. D) | phase1 §4 |
| T2.4 | Functional requirements | Ch.2 | phase1 spec |
| T2.5 | Performance targets | Ch.2 | `improvements.md` |
| T2.6 | Out-of-scope features | Ch.2 | scope analysis |
| T3.1 | Queue/DAT/descriptor formats | Ch.3 (→ App. B) | `i3c_pkg.sv` |
| T3.2 | Error-status encoding | Ch.3 | phase1 §9.4 |
| T3.3 | `flow_active` 13-state table | Ch.3 (→ App. C) | `flow_active.sv` |
| T3.4 | Full CSR map (26 regs + DAT) | Ch.3 (→ App. A) | `csr_registers.sv` |
| T3.5 | Per-module port lists | Ch.3 (→ App. B/C) | RTL |
| T4.1 | Compact vseq category table | Ch.4 §4.9 (→ App. I) | `i3c_vseqs/**` |
| T4.2 | Driver-phase table (compact) | Ch.4 §4.8 | `i3c_agent_pkg.sv` |
| T4.3 | Requirement-to-verification mapping | Ch.4 §4.11 | spec 00 + Ch.2 reqs |
| T5.1 | Verified baseline and count rules | Ch.5 | source revisions/tool versions |
| T5.2 | Per-subsystem implementation metrics | Ch.5 | reproducible count output |
| T5.3 | Module LoC summary | Ch.5 | reproducible count output |
| T5.4 | Regression pass/fail matrix | Ch.5 | sim logs |
| T5.5 | Reference comparison | Ch.5 | pinned sources + results |
| T5.6 | Requirements-evidence matrix | Ch.5 | Ch.2 + evidence |
| T6.1 | Future-work roadmap | Ch.6 | `phase1_spec_v2.md` out-of-scope list |

**Counts:** ~22 figures, ~21 tables (F4.3, T4.3 optional). Full bitfield/state/port/vseq tables migrate to Appendices A–C/G/I.

### Figure asset toolchain

Source files under `figures/`, rendered to `Images/`:
- **Bus-format / timing → WaveDrom** (JSON → SVG/PDF): source of truth `phase1_spec_v2.md`.
- **FSM & state diagrams → TikZ `automata`**: source of truth = RTL enums. Flagship F3.6 → full-page `\begin{landscape}`; others `width=0.95\textwidth`.
- **Algorithm flowcharts → TikZ `chains`/`shapes`** (F3.11, F3.12).

| File | Fig | RTL source |
|---|---|---|
| `fsm/flow_active_fsm.tex` | F3.6 (landscape) | `ctrl/flow_active.sv` |
| `fsm/scl_generator_fsm.tex` | F3.7 | `ctrl/scl_generator.sv` |
| `fsm/entdaa_controller_fsm.tex` | F3.8a | `ctrl/entdaa_controller.sv` |
| `fsm/entdaa_fsm.tex` | F3.8b | `ctrl/entdaa_fsm.sv` |
| `fsm/bus_tx_fsm.tex` | F3.9a | `ctrl/bus_tx.sv` |
| `fsm/bus_tx_flow_fsm.tex` | F3.9b | `ctrl/bus_tx_flow.sv` |
| `fsm/bus_rx_flow_fsm.tex` | F3.9c | `ctrl/bus_rx_flow.sv` |
| `flow/flow_active_issue.tex` | F3.11 | `ctrl/flow_active.sv` |
| `flow/entdaa_loop.tex` | F3.12 | `entdaa_controller.sv`, `entdaa_fsm.sv` |
| `bus/od_vs_pp.json` | F2.2 | — |
| `bus/address_byte.json`, `bus/sdr_write_frame.json`, `bus/sdr_read_frame.json` | F2.3 | — |
| `bus/entdaa_arbitration.json` | F2.4 | — |
| `bus/ccc_frame.json` | Ch.2/App. D | — |

Waveforms: export SimVision as vector PDF or 300 dpi PNG to `Images/`, cropped ≤5 µs, TikZ-annotated. Credit CHIPS Alliance `i3c-core` in captions wherever simplified RTL is shown.

---

## 6. Recommended writing order

1. **Ch.2** — independent; keep theory brief (run MIPI gate first).
2. **Ch.1** — independent; prose-only, 3 sections, no figures/tables.
3. **Ch.3** (flagship) — independent of sims; start FSM diagrams (F3.6–F3.9) + flowcharts (F3.11/F3.12) first (run MIPI gate first).
4. **Ch.4** — independent of sims; results stay in Ch.5.
5. **Ch.5** — after `make regression` + category regressions pass.
6. **Ch.6** — last.
7. **Appendices A–I** — interleave: A–C with Ch.3, G/I with Ch.4, E with Ch.5.

Only Ch.5 depends on green regressions; all other chapters can be written now.

---

## 7. Remaining action items

**LaTeX setup:**
- [ ] Fill the five info macros (`\tenSV` Vo Minh Huy · `\mssv` 22207042 · `\tenKL` title · `\tenGVHD` ThS. Nguyễn Duy Mạnh Thi · `\tenBM` specialisation).
- [ ] Populate `myacronyms.sty` from §9.
- [ ] Replace `References/references.bib` with the ≥10 sources (§2.5); confirm BibTeX + `makeglossaries` build chain.
- [ ] Apply the two typography overrides: Times New Roman body via `tgtermes` (keep 13 pt via `scrextend`); heading sizes 16/14/13 pt via `titlesec`.
- [ ] Ensure `report.tex` uses Vietnamese labels (CHƯƠNG/Hình/Bảng/MỤC LỤC/PHỤ LỤC/TÀI LIỆU THAM KHẢO + Thuật toán/Đầu vào/Đầu ra), `cleveref` set to Vietnamese names, and TÓM TẮT before ABSTRACT in `tomtat.tex`. Translate `chapters/01_introduction_full.tex` to Vietnamese (English terms retained, §9.3).

**Technical / content:**
- [ ] Run the MIPI-compliance gate before each protocol-asserting chapter (Ch.2, Ch.3, Ch.4). On mismatch: list all, do not write, terminate. On clean: append a dated PASS.
- [ ] Run full regression sweep — source `XCELIUM1803.sh` first. Capture logs + optional `COV=1`. Blocks Ch.5 only.
- [ ] Re-enumerate vseq inventory from disk at Ch.5 / App. I write time (75 snapshot → ~105 testplan target).
- [ ] Author the two algorithm flowcharts F3.11 and F3.12.
- [ ] Write VN TÓM TẮT + EN ABSTRACT (<1 page, VN first); run the EN abstract through Grammarly + QuillBot.
- [ ] Source 2 real peer-reviewed papers (R11 conference w/ ISBN, R12 journal w/ ISSN); fill exact ISBN/ISSN/DOI for all references; verify R3/R6/R7/R8 identifiers.
- [ ] Citation-completeness pass: every reference `\cite`d; no uncited claims; every quoted/paraphrased source carries in-body `\cite` + matching references entry.
- [ ] Page-budget tracking: checkpoint Ch.3 against ~15 pp right after its draft; then the whole body against ~42–44.5 pp (40–50 cap). If over, relocate to appendices (never delete).
- [ ] Expand Ch.6 to include knowledge gained, skills gained, limitations.
- [ ] Final polish: spelling, float placement (no large blanks), consistent captions, regenerate TOC/LoF/LoT/abbreviations.
- [ ] *(optional)* `CLAUDE.md` references `docs/bug_analysis_report.md` (nonexistent) — correct/remove.

**Writing quality:** Vietnamese body must be formal/academic, consistent tense/voice, English technical terms retained (§9.3). Only the EN ABSTRACT goes through Grammarly + QuillBot.

Spec-vs-RTL drift is tracked in `docs/spec_rtl_audit.md`; the code-wins policy governs any conflict.

---

## 8. Compliance checklist (department A–D + template)

Legend: ✅ structurally specified in this plan and independent of unfinished writing/repo/bibliography/glossary/build work · ⚠️ specified/planned but pending writing, sourcing, implementation, `.tex`/`.bib`/glossary update, regression, or build verification · ☑ implemented and build-verified.

**A. Format:** A1 length 40–50 pp body ✅ · A2 Times New Roman 13 pt ⚠️ (`tgtermes` override not yet applied/build-verified) · A3 line spacing 1.5 ✅ · A4 justified ✅ · A5 headings 16/14/13 pt ⚠️ (`titlesec` override not yet applied) · A6 figures/tables by chapter, captioned, referenced ✅ · A7 clean, no blanks ⚠️ (final polish).

**B. Structure:** B1 TOC/LoF/LoT/abbreviations ⚠️ (glossary/abbreviations pending build) · B2 VN abstract + EN title + EN abstract ⚠️ (VN first; abstracts pending) · B3 acknowledgments ⚠️ (front matter pending) · B4 introduction ⚠️ (Vietnamese rewrite pending) · B5 theory/methods/architecture in 1–2 chapters ✅ (2 chapters) · B6 block diagrams + algorithm flowcharts ⚠️ (F3.11/F3.12 pending) · B7 results chapter ⚠️ (regression results pending) · B8 conclusion ⚠️ (expansion pending) · B9 references ⚠️ (`references.bib`, R11/R12, identifiers, and citation checks pending).

**C. References:** C1 ≥10 ✅ (12 candidates) · C2 book/journal/conference ✅ · C3 limit internet links ⚠️ · C4 ISBN/ISSN/DOI ⚠️ · C5 every reference cited ⚠️.

**D. Writing quality:** D1 formal VN body + correct EN abstract, English terms retained ⚠️ · D2 Grammarly + QuillBot on EN abstract ⚠️ · D3 every quoted/paraphrased source cited + entry ⚠️.

**Template fidelity:** E1 `extreport`+`scrextend` (pdfLaTeX) ⚠️ · E2 front-/back-matter page sequence ⚠️ · E3 6-chapter design/verification map ✅ · E4 `biblatex` single bibliography + `myacronyms` ⚠️ · E5 template styles + Vietnamese labels ⚠️ (Vietnamese labels in `report.tex` pending verification).

No known requirements are missing from the plan; several items remain pending execution.

---

## 9. Terminology & Abbreviations (canonical MIPI I3C vocabulary)

All prose, captions, and abstracts use the canonical terms below. RTL identifiers stay verbatim in `code font`; on first mention, map the identifier to the spec term (e.g. "the Repeated START request (RTL: `gen_rstart_i`)"). Unless tagged **HCI**, every term is defined in the MIPI I3C Basic Specification v1.1.1 (with Errata 01, 2022). HCI queue/descriptor terms come from MIPI I3C HCI v1.2 + `docs/module_specs/06_hci_queues_spec.md`. This table is the source for the front-matter List of Abbreviations (FM-7). Appendix H provides definitions/spec pointers, not a duplicate expansion list.

### 9.1 Canonical term substitutions

| Was (forbidden) | Now (canonical) | Spec clause | Notes |
|---|---|---|---|
| master / current master | Controller / Active Controller | §2.2 | literal file/doc names keep spelling |
| slave / Target-slave mode | Target / Target mode | §2.2 | — |
| multi-master | Secondary Controller | §2.2 | reworded, not dropped |
| device (as addressed target); per-device; multi-device | Target; per-Target; multi-Target | §2.2 | generic "I3C Device" umbrella kept |
| open-drain / push-pull | Open Drain (OD) / Push-Pull (PP) | §2.2 | Title Case; expand on 1st use |
| repeated-START / restart | Repeated START (Sr) | §2.2 | RTL `*_rstart_*` / `takeover_i` kept |
| bus-idle / bus-free (vague) | Bus Free Condition | §5.1.3.2.1 | Available/Idle are distinct |
| T-bit / parity bit / 9th bit | T-Bit (Transition Bit) | §2.2 | "odd-parity value" kept as description |
| command byte/code | Common Command Code (CCC) | §2.2, §5.1.9 | — |
| broadcast/direct command | Broadcast CCC / Direct CCC | §5.1.9.3 | — |
| CMD/RESP FIFO; TX/RX FIFO; descriptor | Command/Response Queue; TX/RX Data Buffer; Descriptor | HCI v1.2 / spec 06 | "FIFO" kept only for RTL `sync_fifo` |
| PID/BCR/DCR/DAT/DCT/IBI (unexpanded) | expanded on first mention per chapter | — | reused freely thereafter |

### 9.2 Canonical table

| Term | Abbr. | Definition | Spec clause | Avoid |
|---|---|---|---|---|
| Controller | — | I3C Device that controls the Bus | §2.2 | master, host |
| Active Controller | — | The Controller presently in control | §2.2 | current master |
| Target | — | Device that responds to a Controller | §2.2 | slave, device |
| I3C Device | — | Umbrella term; Controller/Target are Roles | §2.2 | — |
| Dynamic Address | — | Address assigned during Bus init | §2.2 | assigned address |
| Static Address | — | Fixed Device Address | §2.2 | fixed addr, I²C address |
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
| START / Repeated START / STOP | Sr | Bus framing conditions | §2.2 | restart, begin/end |
| Bus Free Condition | — | Period after STOP, before START (tCAS/tBUF) | §5.1.3.2.1 | idle/free bus |
| Bus Available Condition | — | Bus Free sustained tAVAL | §5.1.3.2.2 | idle bus |
| Bus Idle Condition | — | SDA+SCL High for tIDLE (Hot-Join) | §5.1.3.2.3 | idle bus |
| Transition Bit | T-Bit | Per-word bit (parity in write, end-of-data in read) | §2.2 | parity/9th bit |
| Acknowledge / Not-Acknowledge | ACK/NACK | Address-phase acknowledgement | §2.2 | — |
| Read/Write bit | RnW | Direction bit in the Address Header | §5.1.2 | direction bit |
| Address Header | — | Address byte + RnW on the Bus | §5.1.2.2 | addressing phase |
| In-Band Interrupt | IBI | Target emits its address to interrupt the Controller | §2.2 | interrupt, async event |
| Hot-Join | — | Target joins an already-running Bus | §2.2 | hot-plug, late attach |
| Provisioned ID | PID | 48-bit Target identifier used in DAA | §5.1.4.1.1 | device ID, UID |
| Bus Characteristics Register | BCR | 8-bit Target capability register | §5.1.1.2.1 | — |
| Device Characteristics Register | DCR | 8-bit Target type register | §5.1.1.2.2 | — |
| Command / Response Descriptor | — | HCI command and completion descriptors | HCI v1.2 / spec 06 | paraphrases |
| Device Address Table | DAT | HCI per-Target address/config table | HCI v1.2 / spec 06 | — |
| Device Characteristics Table | DCT | HCI DAA result table (unused here) | HCI v1.2 / spec 06 | — |
| Command / Response Queue | — | HCI SW→HW / HW→SW queues | HCI v1.2 / spec 06 | CMD/RESP FIFO |
| TX / RX Data Buffer | — | HCI SW↔HW data queues | HCI v1.2 / spec 06 | TX/RX FIFO |

*Verification (non-MIPI): UVM, TLM, SVA, FSM, CSR — standard EDA/Accellera terms, used as-is.*

Concepts with no spec-defined term (left as-is, do not invent): "three-layer architecture", "command-issue algorithm flowchart"; UVM/Accellera terms; the `abort` control input on `flow_active` (generic abort request, **not** the spec IBI); all RTL module/signal names. "Host" is kept for the software/CPU side (HCI sense), not the bus Controller.

### 9.3 English-term retention policy (no Vietnamese translation)

The thesis body is Vietnamese; established English technical terms are kept in English everywhere (prose, captions, tables, TÓM TẮT) and **never translated or calqued**. §9.1/§9.2 fix *which* English term is canonical; §9.3 fixes that it stays English inside the Vietnamese text.

**Do-not-translate list (keep verbatim, non-exhaustive):** Internet of Things · IoT · SoC · System-on-Chip · I²C (I2C) · I3C · MIPI I3C · SDR · HDR · Hot-Join · In-Band Interrupt · IBI · Common Command Code · CCC · Dynamic Address Assignment · DAA · ENTDAA · Controller · Target · Active Controller · Secondary Controller · Open-drain · Push-pull · T-Bit · ACK/NACK · UVM · SystemVerilog · RTL · FSM · CSR · FIFO · DAT · HCI · Scoreboard · Functional Coverage · Assertion · SVA · Testbench · Regression · Coverage · Waveform · Simulation · FPGA.

**Style — English term first, Vietnamese explanation after** (never a translated head-term):
- Correct: "SoC (System-on-Chip) là hệ thống tích hợp nhiều IP trên cùng một chip." — Incorrect: "Hệ thống trên chip là…"
- Correct: "Hot-Join là cơ chế cho phép Target tham gia bus sau khi hệ thống đã hoạt động."
- Correct: "In-Band Interrupt (IBI) cho phép Target gửi interrupt trên chính bus I3C."

Structural labels stay Vietnamese (§2.4); only established technical terms stay English.
