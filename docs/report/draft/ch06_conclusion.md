# Chapter 6 — Conclusion and Future Work

> **Draft brief.** ~4 pages. Write last; quick if Ch.5 is solid. The official Conclusion must cover **all
> five** items: *results achieved, knowledge gained, skills gained, future direction, limitations* —
> §6.1–6.4 below cover them. Sources: all chapters, `phase1_spec_v2.md` out-of-scope list, `improvements.md`
> Phase-2 notes.

## 6.1 Summary of results achieved & contributions

**Brief.** Recap the four headline contributions, led by the design result (not the size figure): all 13
`flow_active` states completed; a compact, studyable controller (PHY → protocol → register) that retains
SDR + I²C + ENTDAA; working dual-agent UVM 1.2 environment with scoreboard + SVA; first ENTDAA-capable
Active Controller in the lab. Refer to the quantitative comparison in Ch.5 without copying its volatile
counts or percentage. Tie each contribution back to its chapter and the Ch.5 results.

## 6.2 Knowledge gained & skills gained

**Brief.** *(NEW section — required by the official Conclusion rule.)* Knowledge: the MIPI I3C SDR/ENTDAA
protocol, the OD↔PP electrical model, UVM 1.2 component/factory/TLM methodology. Skills: SystemVerilog RTL
FSM design, building a dual-agent UVM environment + scoreboard + SVA, EDA-tool flow (Xcelium/SimVision),
and the spec-vs-code discipline (code-wins policy, FSM-diagram-first documentation).

## 6.3 Limitations

**Brief.** *(NEW section — required by the official Conclusion rule.)* State the evidenced limits once,
separating implementation limits from evaluation limits: verified scenario/coverage boundary, remaining
assertion or stimulus gaps, single-Target assumptions, excluded protocol features, and no FPGA validation.
Use the frozen Ch.5 baseline rather than copying changing counts.

## 6.4 Future work

**Brief.** Prioritised roadmap: (1) verification breadth — broader constrained-random stimulus and
extending the existing functional-coverage model to full-protocol closure, broader CCC/ENTDAA/I²C/error-injection
vseqs toward the ~105-case testplan; (2) protocol features —
In-Band Interrupt (IBI), HDR, Secondary Controller, Target mode, bus recovery;
(3) **FPGA validation on a target board is left as future work** (the single FPGA line, per settled
decision).

> [TABLE T6.1 — future-work roadmap · source: `phase1_spec_v2.md` out-of-scope list]  (NOT YET FILLED)
