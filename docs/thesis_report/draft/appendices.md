# Appendices

> **Draft brief.** Interleave with parent chapters as each becomes final. Most are mechanical (generated
> from source). Appendix F (synthesis/FPGA) is **dropped** — FPGA omitted. Use `longtable` for the big
> register/descriptor tables.

| App | Title | Source | Status |
|---|---|---|---|
| A | CSR register map (full bitfield tables) | `csr_register.sv`, spec 07 | mechanical — NOT YET FILLED |
| B | Command / Response / DAT descriptor formats | `i3c_pkg.sv`, `controller_pkg.sv` | mechanical — NOT YET FILLED |
| C | Complete FSM state tables (all RTL FSMs) | specs 03–09 / RTL | mechanical — NOT YET FILLED |
| D | CCC subset opcode/frame table (5 entries) | `phase1_spec_v2.md` §4 | mechanical — NOT YET FILLED |
| E | Regression log excerpts | sim logs | **AFTER SIMS GREEN** |
| F | ~~Synthesis / utilisation / timing~~ | — | **DROPPED (FPGA omitted)** |
| G | Build & run instructions (Makefile reference) | `src/verification/Makefile` | mechanical — NOT YET FILLED |
| H | Glossary & abbreviations | — | mechanical — NOT YET FILLED |
| I | Bibliography (IEEEtran) | `references.bib` | NOT YET FILLED |

## Appendix A — CSR register map
**Brief.** Full bitfield tables for all 30 registers + 32-entry DAT, `longtable`. Reset defaults included.

## Appendix B — Descriptor formats
**Brief.** CMD descriptor variants, RESP descriptor (incl. `err_status`), DAT entry (`dat_entry_t`).

## Appendix C — FSM state tables
**Brief.** Transition tables for `flow_active` (14), `scl_generator` (14), `entdaa_controller` (7),
`entdaa_fsm` (8), `bus_tx` (5), `bus_tx_flow` (4), `bus_rx_flow` (4). Mirrors the Ch.5 diagrams.

## Appendix D — CCC subset
**Brief.** ENTDAA (0x07), ENEC/DISEC broadcast + direct — opcode + frame diagram per entry.

## Appendix E — Regression log excerpts
**Brief.** **AFTER SIMS.** Trimmed `sim.log` for representative vseqs per category.

## Appendix G — Build & run instructions
**Brief.** Makefile target reference (compile/sim/regressions/coverage/FIFO_005), env-sourcing note.

## Appendix H — Glossary & abbreviations
**Brief.** I3C, IBI, ENTDAA, BCR, DCR, PID, OD, PP, SDR, HDR, CCC, DAT, HCI, UVM, TLM, SVA, FSM, CSR.

## Appendix I — Bibliography
**Brief.** Mandatory: MIPI I3C Basic v1.1.1 (Errata 01, 2022); Accellera UVM 1.2 Reference; CHIPS
Alliance `i3c-core` (commit SHA); OpenTitan `dv_macros.svh`.
