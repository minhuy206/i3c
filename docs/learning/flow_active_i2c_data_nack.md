# Learning Checklist: flow_active I2C Data NACK

## 1. Problem Understanding
- [x] `data_nack_q` records that an I2C target NACKed a data byte.
- [x] A data NACK must stop the current I2C write transaction.
- [x] The normal transfer-complete path must not treat a NACKed transaction as success.
- [ ] Failure modes and edge cases are fully restated by the user.

## 2. Solution Understanding
- [x] The STOP request for `data_nack_q` is prioritized before normal completion.
- [x] The I2C write branch now uses explicit priority: data NACK, else data phase, else normal completion.
- [x] The I3C write path remains separate because it uses T-bit/parity behavior, not I2C data ACK/NACK.
- [x] The I3C write completion path remains separate so repeated-start continuation is still only available for I3C devices.
- [x] The I3C read completion path now owns `accept_continuation_cmd()`.
- [x] The I2C read completion path is separate and never calls `accept_continuation_cmd()`.
- [x] The I2C read data phase and completion path are mutually exclusive through `else if`.
- [x] The I3C write/read data phase and completion path are now mutually exclusive through `else if`.
- [x] Protocol branches now use `target_is_i3c` / `target_is_i2c` helpers instead of branching on `sel_i3c_i2c`.
- [x] `sel_i3c_i2c` remains an output/control signal derived from `target_is_i3c`.
- [ ] Alternatives and trade-offs are fully restated by the user.
- [x] Timing profile selection is split from OD/PP electrical-mode selection.
- [x] `scl_generator` stays policy-free: it consumes selected timing and does not hardcode I2C/I3C behavior.

## 3. Broader Context
- [x] Impacted module: `src/rtl/ctrl/flow_active.sv`.
- [x] Impacted behavior: regular write/read completion handling in `IssueCmd`.
- [x] Impacted modules: CSR timing registers, top-level timing wiring, active controller timing mux, and bus timing DV.
- [x] MIPI I3C guidance: legacy I2C transfers use Fm/Fm+ timing; this implementation starts with Fast Mode 400 kHz.
- [x] Verification impact is fully reviewed.

## 4. Verification
- [x] The control-flow change is localized.
- [x] `source /home/minhuy/EDA/cadence/xcelium/XCELIUM1803.sh && make compile` was rerun from `src/verification/` after the priority-chain restructure, I2C read `else if` cleanup, `target_is_*` helper refactor, and I3C write/read `else if` cleanup.
- [x] `flow_active.sv` compiled with 0 errors and 0 warnings.
- [x] Earlier flow-only smoke was clean before the later SVA/timing follow-up work; current smoke status is tracked below.
- [x] `source /home/minhuy/EDA/cadence/xcelium/XCELIUM1803.sh && make sim TEST=i3c_base_test SEQ=i3c_read_toc_zero_vseq SEED=1` was rerun after the I2C read `else if` cleanup and `target_is_*` helper refactor, and exited 0.
- [x] `i3c_read_toc_zero_vseq` UVM summary reported `UVM_ERROR: 0`, `UVM_FATAL: 0`, and scoreboard `pass=4 fail=0`.
- [x] `source /home/minhuy/EDA/cadence/xcelium/XCELIUM1803.sh && make sim TEST=i3c_base_test SEQ=i3c_write_toc_zero_vseq SEED=1` was rerun after the I3C write/read `else if` cleanup, and exited 0.
- [x] `i3c_write_toc_zero_vseq` UVM summary reported `UVM_ERROR: 0`, `UVM_FATAL: 0`, and scoreboard `pass=4 fail=0`.
- [x] `source /home/minhuy/EDA/cadence/xcelium/XCELIUM1803.sh && make sim TEST=i3c_base_test SEQ=i3c_read_toc_zero_vseq SEED=1` was rerun after the I3C write/read `else if` cleanup, and exited 0.
- [x] `i3c_read_toc_zero_vseq` UVM summary reported `UVM_ERROR: 0`, `UVM_FATAL: 0`, and scoreboard `pass=4 fail=0`.
- [x] `source /home/minhuy/EDA/cadence/xcelium/XCELIUM1803.sh && make sim TEST=i3c_base_test SEQ=csr_reset_defaults_vseq SEED=1` passed after the I2C timing CSR bank was added.
- [x] `source /home/minhuy/EDA/cadence/xcelium/XCELIUM1803.sh && make sim TEST=i3c_base_test SEQ=csr_timing_rw_vseq SEED=1` passed after the I2C timing CSR bank was added.
- [x] `source /home/minhuy/EDA/cadence/xcelium/XCELIUM1803.sh && make sim TEST=i3c_base_test SEQ=bus_od_pp_phase_switch_vseq SEED=1` passed after I2C timing auto-select and BFM stop handling; BUS_010 reported `UVM_ERROR: 0`, `UVM_FATAL: 0`, and scoreboard `pass=2 fail=0`.
- [x] `git diff --check` passed after the implementation changes.
- [ ] Current `source /home/minhuy/EDA/cadence/xcelium/XCELIUM1803.sh && make smoke` still reports two Xcelium assertion failures in `tb_pad_model_sva.sv` at 3655 ns and one scoreboard error: `1 expected command(s) never observed on I3C bus`.
- [ ] `i3c_read_toc_zero_vseq` still reports `tb_pad_model_sva.sv` assertion failures around repeated START/address timing.
- [ ] `i3c_write_toc_zero_vseq` still reports `tb_pad_model_sva.sv` assertion failures around address/repeated START timing.
- [ ] Simulator environment linker/DPI warnings are understood.
- [ ] The user can explain how to test the change.

## 5. Timing Auto-Select Follow-up
- [x] BUS_010 showed the I2C device BFM sampled/responded with I2C_400 timing while the DUT still generated fast I3C-style timing.
- [x] The observed data mismatch came from timing mismatch around ACK/data phases, not from DAT address selection.
- [x] Add a separate I2C timing bank with I2C Fast Mode 400 kHz reset defaults.
- [x] Keep the existing timing bank as the I3C timing bank for backward compatibility.
- [x] Select the active timing bank in `controller_active` based on whether the current DAT entry targets a legacy I2C device.
- [x] Verify that BUS_010 I2C write passes without programming the generic timing registers to I2C values by hand.
- [x] The old 1000-cycle device-response timeout is too short for I2C Fast Mode transfers.
- [x] Use an I2C timing-aware timeout for I2C bus vseq device-response waits.
- [x] The I2C BFM must not release ACK/data while SCL is still high, or it can create a false STOP condition.
- [x] The DV stop/rstart wait must handle a stable idle bus, because monitor/driver threads can start waiting just after STOP has already occurred.
- [x] The I2C BFM must not require a falling SCL edge after the final ACK, because a legal STOP can keep SCL high and then release SDA.
