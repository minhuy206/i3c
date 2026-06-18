# Chapter 10 — Conclusion and Future Work

> **Draft brief.** Write last; quick if Ch.9 is solid. Sources: all chapters, `phase1_spec_v2.md`
> out-of-scope list, master plan §7.9 Phase-2 roadmap.

## 10.1 Summary of contributions

**Brief.** Recap the four headline contributions: all 14 `flow_active` states completed; ~92% LoC
reduction with SDR + I²C + ENTDAA preserved; working dual-agent UVM 1.2 environment with scoreboard +
SVA; first ENTDAA-capable master in the lab. Tie each back to its chapter.

## 10.2 Lessons learned

**Brief.** Reflective notes: spec-vs-code drift (code-wins policy); educational value of a hand-written
CSR vs auto-gen; value of directed-first bring-up; single-counter SCL timing tradeoff; FSM-diagram-first
documentation workflow.

## 10.3 Future work

**Brief.** Prioritised roadmap: (1) Phase-2 verification — constrained-random + functional coverage,
broader CCC/ENTDAA/I²C/error-injection vseqs toward the ~105-case testplan; (2) protocol features — IBI,
HDR, multi-master, target mode, bus recovery; (3) `scl_generator` `req_restart_i`/`ack_o` cleanup;
(4) **FPGA validation on a target board is left as future work** (the single FPGA line, per settled
decision).

> [TABLE T10.1 — future-work roadmap · source: master plan §7.9]  (NOT YET FILLED)
