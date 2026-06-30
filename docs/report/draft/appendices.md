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
| H | Glossary of I3C and HCI terms | MIPI/HCI specifications | mechanical — NOT YET FILLED |
| I | Virtual-sequence inventory | `i3c_vseqs/**`, Makefile | mechanical — NOT YET FILLED |

## Appendix A — CSR register map
**Brief.** Full bitfield tables for all 26 registers + 32-entry DAT, `longtable`. Reset defaults included.

## Appendix B — Descriptor formats
**Brief.** Command Descriptor variants, Response Descriptor (incl. `err_status`), DAT entry (`dat_entry_t`).

## Appendix C — FSM state tables
**Brief.** Transition tables for `flow_active` (13), `scl_generator` (14), `entdaa_controller` (7),
`entdaa_fsm` (8), `bus_tx` (5), `bus_tx_flow` (4), `bus_rx_flow` (4). Mirrors the Ch.3 diagrams.
Primary release valve for the Ch.3 page budget (full state tables T3.3/T-scl live here).

## Appendix D — CCC subset
**Brief.** ENTDAA (0x07), ENEC/DISEC Broadcast CCC + Direct CCC — opcode + frame diagram per entry.

## Appendix E — Regression log excerpts
**Brief.** **AFTER SIMS.** Trimmed `sim.log` for representative vseqs per category.

## Appendix G — Build & run instructions
**Brief.** Makefile target reference (compile/sim/regressions/coverage), env-sourcing note.

## Appendix H — Glossary of I3C and HCI terms
**Brief.** Definitions and specification clauses for I3C/HCI terms. The front-matter List of Abbreviations
owns acronym expansions; this appendix must add definitions rather than reproduce that list.

## Appendix I — Virtual-sequence inventory
**Brief.** Generate the complete per-sequence list from source, grouped by category, with the verification
objective and owning regression target. Exclude `i3c_base_vseq` from the runnable-scenario total and record
the commit used to generate the inventory. The bibliography is separate back matter, not an appendix.
