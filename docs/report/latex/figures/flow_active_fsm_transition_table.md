# FLOW_ACTIVE FSM extraction and redraw audit

Source inspected: `flow_active_fsm.drawio` (editable draw.io XML). The raster rendering was not used as the reconstruction source.

## State inventory

| Number | State name | Description |
|---:|---|---|
| 0 | `Idle` | bus free / clear context |
| 1 | `WaitForCmd` | wait for CMD FIFO |
| 2 | `FetchDAT` | validate descriptor |
| 3 | `WaitDAT` | latch DAT / dispatch CMD |
| 4 | `I3C BCAST HEADER` | START + 7'h7E/W |
| 5 | `Issue Immediate CCC` | ENEC / DISEC |
| 6 | `FetchTxData` | fetch TX FIFO DWORD |
| 7 | `InitWrite` | START/RSTART + Addr/W + ACK |
| 8 | `InitRead` | START/RSTART + Addr/R + ACK |
| 9 | `IssueDAA` | ENTDAA operation |
| 10 | `I3C Write` | TX byte + T-bit |
| 11 | `I²C Write` | TX byte + ACK/NACK |
| 12 | `I3C Read` | RX byte + T-bit |
| 13 | `I²C Read` | RX byte + ACK/NACK |
| 14 | `WriteResp` | hold RESP valid until ready |

No state text was unreadable; no `UNCLEAR` entries were required.

## Transition table

| Source | Condition | Destination | Transition type | Notes |
|---|---|---|---|---|
| external reset | `reset` | `0 · Idle` | Reset | Source is an incoming reset arrow, not an RTL state. |
| `0 · Idle` | `i3c_fsm_en_i` | `1 · WaitForCmd` | Primary | Solid arrow. |
| `1 · WaitForCmd` | `disable` | `0 · Idle` | Disable | Solid return path. |
| `1 · WaitForCmd` | `CMD valid & !abort` | `2 · FetchDAT` | Primary | Solid arrow. |
| `2 · FetchDAT` | `descriptor valid; DAT available` | `3 · WaitDAT` | Primary | Solid arrow. |
| `3 · WaitDAT` | `I3C: broadcast header required` | `4 · I3C BCAST HEADER` | Primary | Bus-driving transition. |
| `3 · WaitDAT` | `private write / immediate` | `7 · InitWrite` | Primary | Bus-driving transition. |
| `3 · WaitDAT` | `private read` | `8 · InitRead` | Primary | Bus-driving transition. |
| `4 · I3C BCAST HEADER` | `broadcast / direct CCC` | `5 · Issue Immediate CCC` | Primary | Bus-driving transition. |
| `4 · I3C BCAST HEADER` | `ENTDAA` | `9 · IssueDAA` | Primary | Bus-driving transition. |
| `4 · I3C BCAST HEADER` | `private write` | `7 · InitWrite` | Primary | Bus-driving transition. |
| `4 · I3C BCAST HEADER` | `private read` | `8 · InitRead` | Primary | Bus-driving transition. |
| `7 · InitWrite` | `regular transfer; payload remains` | `6 · FetchTxData` | Primary | Fetches a TX FIFO DWORD. |
| `7 · InitWrite` | `I3C immediate / len=0` | `10 · I3C Write` | Primary | Preserved wording from the source. |
| `7 · InitWrite` | `I²C immediate` | `11 · I²C Write` | Primary | Solid arrow. |
| `6 · FetchTxData` | `DWORD valid; I3C` | `10 · I3C Write` | Primary | Solid arrow. |
| `6 · FetchTxData` | `DWORD valid; I²C` | `11 · I²C Write` | Primary | Solid arrow. |
| `10 · I3C Write` | `next DWORD required` | `6 · FetchTxData` | Primary return | Local data-fetch return. |
| `11 · I²C Write` | `next DWORD required` | `6 · FetchTxData` | Primary return | Local data-fetch return. |
| `8 · InitRead` | `target I3C` | `12 · I3C Read` | Primary | Solid arrow. |
| `8 · InitRead` | `target I²C` | `13 · I²C Read` | Primary | Solid arrow. |
| `12 · I3C Read` | `HC abort: wait for T-bit takeover` | `12 · I3C Read` | Self-loop | The only explicitly drawn state self-loop. |
| `5 · Issue Immediate CCC` | `done` | completion junction | Completion convergence | Junction is graphical, not an RTL state. |
| `10 · I3C Write` | `done` | completion junction | Completion convergence | Junction is graphical, not an RTL state. |
| `11 · I²C Write` | `done` | completion junction | Completion convergence | Junction is graphical, not an RTL state. |
| `12 · I3C Read` | `done` | completion junction | Completion convergence | Junction is graphical, not an RTL state. |
| `13 · I²C Read` | `done` | completion junction | Completion convergence | Junction is graphical, not an RTL state. |
| completion junction | `WROC=1` | `14 · WriteResp` | Response completion | Solid response path. |
| `9 · IssueDAA` | `DAA stopped / stop request` | `14 · WriteResp` | Response completion | Direct response path. |
| `2 · FetchDAT` | `descriptor invalid` | error / abort junction | Error / abort | Red dashed arrow. |
| `4 · I3C BCAST HEADER` | `7E/W NACK` | error / abort junction | Error / abort | Red dashed arrow. |
| `7 · InitWrite` | `address NACK / TX underflow` | error / abort junction | Error / abort | Red dashed arrow. |
| `8 · InitRead` | `address NACK / abort` | error / abort junction | Error / abort | Red dashed arrow. |
| error / abort junction | `error status` | `14 · WriteResp` | Error response | Red dashed response path. |
| `10 · I3C Write` | `toc=0; next CMD supported` | `2 · FetchDAT` | Chained I3C command | Purple dashed outer return. |
| `12 · I3C Read` | `toc=0; next CMD supported` | `2 · FetchDAT` | Chained I3C command | Purple dashed outer return. |
| completion junction | `success; WROC=0` | `0 · Idle` | Success without response | Green dashed outer return. |
| `14 · WriteResp` | `resp_queue_wready_i` | `0 · Idle` | Response queue completion | Long outer return path. |

FSM/reset path count: **38**: 37 labeled state/junction paths plus the incoming reset arrow. The four sample arrows inside the legend are illustrative symbols and are not included in this count.

## Junctions, legend, and notes

- Completion junction: one outlined orange dot labeled `complete`; it converges five `done` paths, then selects `WROC=1` to `WriteResp` or `success; WROC=0` to `Idle`.
- Error/abort junction: one outlined red dot labeled `error / abort`; it converges four distinct error paths, then follows `error status` to `WriteResp`.
- Legend entries: `Bus-driving state`, `Internal control / data state`, `Primary state transition`, `Error / abort → response`, `Chained I3C command (toc=0)`, and `Successful return without response`.
- Completion policy note:
  - `success + WROC=1 → WriteResp`
  - `success + WROC=0 → Idle`
  - `any error / abort → WriteResp`
  - `I3C + toc=0 → FetchDAT`
- Original clarity note: `Handshake wait self-loops are omitted for clarity. Convergence dots are graphical junctions, not RTL states.`

## Semantic-completeness check

- Visible RTL states: 15/15 inventoried.
- FSM/reset arrows: 38/38 have an explicit source and destination (the reset source is an explicit external point).
- Transition labels: 38/38 preserved, including the unlabeled reset arrow whose adjacent text is `reset`.
- Explicit self-loops: 1/1 preserved.
- Completion junctions: 1/1 preserved.
- Error/abort junctions: 1/1 preserved.
- Reset, disable, response queue, chained-command, success-without-response, and long return paths: preserved.
- Ambiguities in the previous rendering: 15 edge crossings and 3 edge-through-node warnings. These were routing ambiguities only; they were resolved by moving states and adding outer routing corridors without changing endpoints or conditions.

## Cross-check and discrepancy report

State count, state identities, state descriptions, transition count, conditions, destinations, junctions, legend semantics, and completion policy were compared against the editable source before redraw.

**Discrepancies: none.**

## Visual-only changelog

- Repositioned the existing states into the five requested visual regions.
- Routed normal execution primarily from top to bottom.
- Moved chained-command, success-without-response, and response-ready returns to dedicated outer corridors.
- Rerouted error/abort edges to the existing error junction without combining conditions.
- Kept the completion and error junctions visually distinct from RTL states.
- Increased spacing between write/read and I3C/I²C paths.
- Moved labels away from state borders and applied consistent label backgrounds.
- Standardized typography, state sizing, line widths, arrowheads, and dark-background contrast.
