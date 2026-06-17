# Chapter 7 — UVM Verification Environment

> **Draft brief.** Walk the testbench bottom-up. Write the structure now; fill §7.8 results only after
> regressions are green. Format = component diagrams + waveform screenshots; avoid excessive SV listings.
> **Re-enumerate vseqs from disk at write time** and footnote that the 56-vseq suite is a WIP snapshot
> (~105-case testplan target). Sources: `tb_i3c_top.sv`, `i3c_scoreboard.sv`, `i3c_driver.sv`,
> `i3c_monitor.sv`, `i3c_base_vseq.sv`, `i3c_vseq_list.sv`, `Makefile`, `i3c_vseqs/**`, `sva/**`,
> verification specs 06–09.

## 7.1 TB top & interfaces

**Brief.** `tb_i3c_top` instantiates the DUT + reg/i3c interfaces, clock/reset, the 100 ms watchdog
`uvm_fatal`, SHM dump gated by `+DUMP_WAVES`, and the SVA binds. Note reduced TB FIFO depths vs RTL to
shrink sim time.

## 7.2 Register agent

**Brief.** `dv_reg/` agent driving the 32-bit addr/wen/ren bus (driver/monitor/sequencer/cfg).

> ┌─ FIGURE F7.2 — register agent ──────────────────────────────────────────────────────────
> │ Shows:  reg agent driver/monitor/sequencer on the 32-bit bus
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 7.3 I3C device-mode agent (driver + monitor)

**Brief.** `dv_i3c/` device-mode responder: `i3c_driver` with 13 device-only phases
(`i3c_drv_phase_e`), CCC-aware `i3c_monitor` capturing protocol events. Describe the phase FSM and the
monitor's protocol state machine.

> ┌─ FIGURE F7.3 — I3C agent (device-mode driver + monitor) ────────────────────────────────
> │ Shows:  driver 13-phase FSM + monitor protocol capture
> │ Source: dv_i3c/i3c_agent_pkg.sv, i3c_driver.sv, i3c_monitor.sv · Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> [TABLE T7.2 — driver 13-phase table (DrvIdle…DrvDAA) · source: i3c_agent_pkg.sv]  (NOT YET FILLED)

## 7.4 Env / vseqr / scoreboard class hierarchy

**Brief.** `i3c_env` (reg agent + i3c agent + scoreboard + virtual sequencer), the class hierarchy, and
`uvm_config_db` wiring. Reference the scoreboard checks from Ch.6 §6.5.

> ┌─ FIGURE F7.1 — env class hierarchy ─────────────────────────────────────────────────────
> │ Shows:  i3c_base_test→i3c_env→{reg_agent, i3c_agent, scoreboard, virtual_sequencer}
> │ Render: TikZ (redraw from print_topology) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> [TABLE T7.3 — scoreboard check list · source: i3c_scoreboard.sv]  (NOT YET FILLED)

## 7.5 Vseq library

**Brief.** Re-enumerate from disk. Snapshot at planning time: **56 vseqs** —
csr 14 / fifo 5 / bus 12 / sdrw 9 / sdrr 10 / resp 4 / ccc 1 / imm 1. CCC vseq is ad-hoc only
(`make sim SEQ=i3c_ccc_broadcast_enec_vseq`). Footnote the WIP snapshot vs ~105-case testplan.

> [TABLE T7.1 — vseq library by category (count = re-enumerate at write time) · source: i3c_vseqs/**]  (NOT YET FILLED)

## 7.6 Build/run flow

**Brief.** Makefile targets: `compile`, `sim SEQ=…`, the 8 category regression targets (smoke,
regression, csr/fifo/bus/sdrw/sdrr/sdr regressions), `COV=1` coverage, `DUMP_WAVES=1`, and the
`fifo_non_power_of_two_elaboration` (FIFO_005) elaboration-fail-as-pass guard. Note the env must be
sourced (`XCELIUM1803.sh`) first.

> [TABLE T7.4 — regression targets + SEQ lists · source: Makefile]  (NOT YET FILLED)

## 7.7 Waveform & debug (SimVision)

**Brief.** SHM dump workflow, opening `waves/<SEQ>/waves.shm` in SimVision, the events worth annotating
(START/ACK/T-bit/OD→PP/STOP).

## 7.8 Regression results — *fill after sims green*

**Brief.** **BLOCKED on green regressions.** Insert the pass/fail matrix + representative waveforms once
`make regression` + category regressions pass. Placeholder figures:

> ┌─ FIGURE F7.4 — representative write waveform ─── SimVision · AFTER SIMS · NOT YET CAPTURED ┐
> ┌─ FIGURE F7.5 — representative read waveform  ─── SimVision · AFTER SIMS · NOT YET CAPTURED ┐

## 7.9 Phase-2 roadmap

**Brief.** Known gaps + next steps: fix monitor stub if present, ENTDAA/CCC test breadth, error
injection, multi-device, functional coverage. Cross-reference Ch.10 §10.3.

> ┌─ FIGURE F7.6 — SVA binding map ─────────────────────────────────────────────────────────
> │ Shows:  5 SVA modules → bound vs instantiated targets in tb_i3c_top
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> [TABLE T7.5 — 5 SVA modules (bind vs instantiate) · source: sva/**, tb_i3c_top.sv]  (NOT YET FILLED)
