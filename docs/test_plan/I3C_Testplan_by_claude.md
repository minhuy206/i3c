# I3C Phase-1 Verification Test Plan

---

## 1. Document Control

| Field | Value |
|---|---|
| Title | I3C Basic v1.1.1 Master Controller — Phase-1 Verification Test Plan |
| Version | 1.0 |
| Date | 2026-05-14 |
| Author | Vo Minh Huy (22207042) |
| Supervisor | Nguyen Duy Manh Thi |
| Simulator | Xcelium (`xrun`) with UVM 1.2 (CDNS-1.2) |
| Target spec | MIPI I3C Basic v1.1.1 (Errata 01, 2022) |
| Reference plan | `docs/test_plan/I2C_Testplan.xlsx` |

### 1.1 Scope

This test plan covers functional, performance, and coverage verification of the I3C Phase-1 master controller RTL located in `src/rtl/`. The design is an active-controller-only implementation supporting SDR mode (12.5 MHz), ENTDAA, five Phase-1 CCCs, and I2C Fast Mode (400 kHz) backward compatibility. It does **not** implement IBI, Hot-Join, HDR modes, multi-master, or target/slave mode (see Section 8 for the complete deferred list).

### 1.2 References

| Document | Path |
|---|---|
| Phase-1 architecture spec | `docs/phase1_spec_v2.md` |
| Bug analysis report | `docs/bug_analysis_report.md` |
| flow_active module spec | `docs/module_specs/09_flow_active_spec.md` |
| UVM implementation plan | `docs/verification_specs/00_uvm_implementation_plan.md` |
| I2C reference test plan | `docs/test_plan/I2C_Testplan.xlsx` |

---

## 2. DUT Summary

### 2.1 Top-Level Ports

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk_i` | In | 1 | System clock (min 333 MHz) |
| `rst_ni` | In | 1 | Active-low async reset |
| `reg_addr_i` | In | 12 | Register bus address |
| `reg_wdata_i` | In | 32 | Register write data |
| `reg_wen_i` | In | 1 | Register write enable |
| `reg_ren_i` | In | 1 | Register read enable |
| `reg_rdata_o` | Out | 32 | Register read data |
| `reg_ready_o` | Out | 1 | Register access ready (tied 1) |
| `scl_i` / `scl_o` | In/Out | 1 | I3C/I2C clock |
| `sda_i` / `sda_o` | In/Out | 1 | I3C/I2C data |
| `sel_od_pp_o` | Out | 1 | 0=Open-Drain, 1=Push-Pull (to pad) |

### 2.2 Register Map

| Offset | Name | Key Fields |
|---|---|---|
| 0x000 | HC_CONTROL | `[0]=hc_enable`, `[1]=sw_reset` |
| 0x004 | HC_STATUS | `[0]=i3c_fsm_idle`, `[1]=cmd_full`, `[2]=resp_empty` |
| 0x010 | T_R | Rise time cycles (reset 4) |
| 0x014 | T_F | Fall time cycles (reset 4) |
| 0x018 | T_LOW | SCL low period (reset 13) |
| 0x01C | T_HIGH | SCL high period (reset 13) |
| 0x020 | T_SU_STA | START setup (reset 13) |
| 0x024 | T_HD_STA | START hold (reset 13) |
| 0x028 | T_SU_STO | STOP setup (reset 13) |
| 0x02C | T_SU_DAT | Data setup (reset 1) |
| 0x030 | T_HD_DAT | Data hold (reset 4) |
| 0x100 | CMD_QUEUE | Two consecutive 32-bit writes = one 64-bit CMD descriptor |
| 0x104 | TX_DATA | 32-bit TX payload write |
| 0x108 | RX_DATA | 32-bit RX payload read |
| 0x10C | RESP | 32-bit response descriptor read |
| 0x110 | QUEUE_STATUS | `[7:0]` = resp_empty/full, rx_empty/full, tx_empty/full, cmd_empty/full |
| 0x200–0x23C | DAT[0..15] | 32-bit device address table entries |

### 2.3 Phase-1 Feature Matrix

| Feature | Status | Notes |
|---|---|---|
| SDR private write (RegularTransfer) | Implemented | BUG-007: missing START; requires fix |
| SDR private read (RegularTransfer) | Implemented | BUG-007 + BUG-003 + BUG-006/010; require fixes |
| Immediate data transfer | Implemented | BUG-002: missing gen_clock; requires fix |
| ENTDAA dynamic address assignment | Implemented | entdaa_controller + entdaa_fsm |
| Broadcast CCC (ENEC 0x00, DISEC 0x01, ENTDAA 0x07) | Implemented | via ImmediateDataTransfer with cp=1 |
| Direct CCC (DIR_ENEC 0x80, DIR_DISEC 0x81) | Implemented | via ImmediateDataTransfer with cp=1, cmd[7]=1 |
| I2C FM backward compat (400 kHz) | Implemented | BUG-004/005: ACK never received; require fixes |
| SCL timing programmability | Implemented | T_R, T_F, T_LOW, T_HIGH, T_SU_STA, T_HD_STA, T_SU_STO, T_SU_DAT, T_HD_DAT |
| HCI CMD/TX/RX/RESP FIFOs | Implemented | depth=8 in TB (depth=64 in RTL default) |
| 16-entry DAT | Implemented | 32-bit simplified entry; HW-readonly dynamic-addr update |
| OD/PP switching (sel_od_pp_o) | Implemented | Address phase=OD, data phase=PP |

### 2.4 Not-Implemented / Out-of-Scope

| Feature | Reason |
|---|---|
| In-Band Interrupts (IBI) | Phase-1 scope exclusion; no HW support |
| Hot-Join | Phase-1 scope exclusion |
| HDR-DDR / HDR-TS | Phase-1 scope exclusion; enums defined but silently ignored |
| Multi-master / secondary controller | Phase-1 scope exclusion |
| Target (slave) mode | Phase-1 scope exclusion |
| Non-Phase-1 CCCs (SETDASA, GETPID, GETBCR, GETDCR, SETMWL, SETMRL, GETSTATUS, RSTACT, etc.) | Not implemented |
| ComboTransfer offset bytes | BUG in FetchDAT (no Combo branch) |
| Threshold IRQs / almost-full/empty flags | Not wired |
| IRQ output pin | Not present on top-level |
| Error codes: Crc, Frame, Ovl, ShortRead, HcAborted, NotSupported | Unreachable in current RTL |
| bus_error_o | Hard-tied to 0 (TODO in bus_tx_flow.sv) |
| gen_idle recovery | BUG-009: never asserted |

---

## 3. Verification Environment Summary

### 3.1 Existing UVM Components (Phase 1 baseline)

| Component | File | Status |
|---|---|---|
| `i3c_base_test` | `i3c_core/i3c_base_test.sv` | Implemented |
| `i3c_env` + `i3c_env_cfg` | `i3c_core/i3c_env*.sv` | Implemented |
| `i3c_scoreboard` | `i3c_core/i3c_scoreboard.sv` | Partial (CMD+RESP err check + TX byte match; no RX check, no CCC/ENTDAA check) |
| `i3c_virtual_sequencer` | `i3c_core/i3c_virtual_sequencer.sv` | Implemented |
| `i3c_base_vseq` | `i3c_core/i3c_vseqs/i3c_base_vseq.sv` | Implemented (helpers: reg_write, reg_read, write_dat_entry, write_cmd, write_tx_data, read_rx_data, read_response) |
| `i3c_smoke_vseq` | `i3c_core/i3c_vseqs/i3c_smoke_vseq.sv` | Implemented |
| `i3c_write_vseq` | `i3c_core/i3c_vseqs/i3c_write_vseq.sv` | Implemented |
| `i3c_read_vseq` | `i3c_core/i3c_vseqs/i3c_read_vseq.sv` | Implemented |
| `i3c_agent` (Device-mode monitor+driver) | `dv_i3c/` | Implemented |
| `i3c_device_response_seq` | `dv_i3c/seq_lib/` | Implemented (single parameterized responder) |
| `reg_agent` (custom) + `reg_if` | `dv_reg/` | Implemented |
| Functional coverage | — | **None** (deferred to Phase 2) |

### 3.2 UVM Components Required for New Test Cases

The following additions are implied by the new test categories but are not yet implemented. They are listed here to guide Phase-2 UVM development.

| New Component | Purpose | Required by Category |
|---|---|---|
| `i3c_entdaa_vseq` | Issue ENTDAA command + multi-round DAA dance | Cat. 7 |
| `i3c_ccc_vseq` | Issue broadcast/direct CCC with cp=1 descriptors | Cat. 6 |
| `i3c_error_inject_vseq` | Force NACK/parity responses from device side | Cat. 11, 15 |
| `i3c_i2c_device_vseq` | Drive I2C-mode device (ACK each byte, NACK last) | Cat. 8 |
| Scoreboard RX-data check | Match received bytes in RX FIFO vs device-driven data | Cat. 4, 7 |
| `i3c_timing_check_vseq` | Measure SCL period using `$time` assertions in i3c_if | Cat. 2, 12 |
| `i3c_reset_inject_vseq` | Toggle `rst_ni` mid-transaction in each FSM state | Cat. 13 |

---

## 4. Test Plan — Functional Test Cases

> **Table columns:** No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags
>
> **TB constraints:** TB clock = 100 MHz (10 ns cycle); FIFO depths = 8; DatDepth = 16. Adjust test counts accordingly.
>
> **Bug annotations:** Tests marked `[BUG-NNN required]` need the referenced bug fix before they can pass. See Section 9 for the full bug list.

---

### 4.1 Category 1 — Register Interface Tests

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 1.1 | HC_CONTROL | csr_hc_enable_set_clear | Verify hc_enable bit writes and reads back correctly | Write 0x1 to HC_CONTROL; read back; write 0x0; read back | Readback matches written value on both transitions | High | csr_register.sv | — |
| 1.2 | HC_CONTROL | csr_sw_reset_self_clear | Verify sw_reset bit is self-clearing (pulse only) | Write 0x2 to HC_CONTROL; read back after one cycle | sw_reset bit reads 0 on second access; FIFO pointers reset | High | csr_register.sv | cp_reset_point.Idle |
| 1.3 | HC_STATUS | csr_hc_status_idle | Verify i3c_fsm_idle reads 1 when hc_enable=1 and no command pending | Enable DUT; read HC_STATUS | HC_STATUS[0]=1 (fsm_idle) | High | csr_register.sv, flow_active.sv | — |
| 1.4 | HC_STATUS | csr_hc_status_cmd_full | Verify cmd_full bit reflects CMD FIFO full condition | Write CMD_QUEUE 9 times (4 DWORDs = 4 CMDs beyond depth-8) | QUEUE_STATUS[0]=0 (cmd_empty), HC_STATUS[1]=1 when full | High | csr_register.sv, hci_queues.sv | cp_fifo_state.cmd_full |
| 1.5 | HC_STATUS | csr_hc_status_resp_empty | Verify resp_empty bit after reset before any command | After reset and enable; read HC_STATUS | HC_STATUS[2]=1 (resp_empty), QUEUE_STATUS[7]=1 | High | csr_register.sv, hci_queues.sv | cp_fifo_state.all_empty |
| 1.6 | QUEUE_STATUS | csr_queue_status_all_bits | Verify all 8 QUEUE_STATUS bits toggled by FIFOs | Fill each FIFO to full; drain each FIFO; observe status bits | Each full flag and empty flag transitions correctly for all 4 FIFOs | High | csr_register.sv, hci_queues.sv | cp_fifo_state.cmd_full, cp_fifo_state.tx_empty, cp_fifo_state.rx_full, cp_fifo_state.resp_full |
| 1.7 | Timing reg | csr_timing_tr_tf_rw | Verify T_R and T_F registers write and read back correctly | Write non-default values (e.g., T_R=8, T_F=6) to 0x010 and 0x014; read back | Readback matches written values; no side effects | High | csr_register.sv | cp_timing_reg.min |
| 1.8 | Timing reg | csr_timing_tlow_thigh_rw | Verify T_LOW and T_HIGH registers programmability | Write T_LOW=8, T_HIGH=10; read back | Readback correct; SCL period changes accordingly when command issued | High | csr_register.sv, scl_generator.sv | cp_timing_reg.min, cp_timing_reg.max |
| 1.9 | Timing reg | csr_timing_all_rw | Verify all 9 timing registers accept writes and read back | Write distinct non-default values to T_R, T_F, T_LOW, T_HIGH, T_SU_STA, T_HD_STA, T_SU_STO, T_SU_DAT, T_HD_DAT | All 9 registers read back the written values | Medium | csr_register.sv | cp_timing_reg.typ |
| 1.10 | DAT | csr_dat_entry0_rw | Verify DAT entry 0 (0x200) write and read back | Write DAT[0] with I3C device (device=0, dyn_addr=0x0A, static_addr=0x00); read back | Readback matches written value | High | csr_register.sv | cp_dat_index.0 |
| 1.11 | DAT | csr_dat_entry15_rw | Verify DAT entry 15 (last, 0x23C) write and read back | Write DAT[15] with I3C device (dyn_addr=0x7F); read back | Readback matches; no overflow into unmapped space | High | csr_register.sv | cp_dat_index.15 |
| 1.12 | DAT | csr_dat_all_entries_rw | Verify all 16 DAT entries write/read independently | Write distinct values to DAT[0..15]; read all back | All 16 entries correct; no aliasing | Medium | csr_register.sv | cp_dat_index.0, cp_dat_index.15, cp_dat_index.mid |
| 1.13 | HC_CONTROL | csr_sw_reset_clears_staging | Verify sw_reset clears CMD staging register (BUG-008 regression) | Write DWORD0 to CMD_QUEUE; assert sw_reset; write new DWORD0 + DWORD1; issue enable | New CMD dispatches correctly; no mix with stale DWORD0 | High | csr_register.sv | cp_reset_point.Idle |

---

### 4.2 Category 2 — I3C Bus Primitive Tests

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 2.1 | START cond | bus_start_condition_detect | Verify bus_monitor detects START condition correctly | Trigger any command; observe scl_generator entering GenerateStart state; monitor SDA-falls-SCL-HIGH | bus_monitor asserts start_det; no false positive in idle | High | bus_monitor.sv, scl_generator.sv | — |
| 2.2 | Repeated START | bus_rstart_condition_detect | Verify repeated-START detection during directed CCC or multi-round DAA | Issue directed CCC (cp=1, cmd[7]=1); observe Sr before target address phase | bus_monitor asserts rstart_det between CCC header and target address | High | bus_monitor.sv, scl_generator.sv | — |
| 2.3 | STOP cond | bus_stop_condition_detect | Verify bus_monitor detects STOP condition correctly | Issue command with toc=1; observe SDA-rises-SCL-HIGH after last bit | bus_monitor asserts stop_det; DUT returns to Idle; HC_STATUS[0]=1 | High | bus_monitor.sv, flow_active.sv | cp_toc.STOP |
| 2.4 | Bus idle | bus_idle_after_stop | Verify DUT reports bus idle after STOP | Issue command with toc=1; poll HC_STATUS after STOP | HC_STATUS[0]=1 (i3c_fsm_idle=1) within bounded cycles | High | flow_active.sv, csr_register.sv | — |
| 2.5 | OD/PP switch | bus_od_pp_switch | Verify sel_od_pp_o transitions 0→1 at correct phase boundary | Issue SDR write; sample sel_od_pp_o at address phase and data phase | sel_od_pp_o=0 during address/ACK; sel_od_pp_o=1 during data bytes | High | flow_active.sv, bus_tx.sv | — |
| 2.6 | SCL timing | bus_scl_low_period | Verify SCL LOW period ≥ 24 ns at 12.5 MHz with default T_LOW=13 at 333 MHz | Issue SDR transfer with default timing regs; measure SCL LOW duration | t_LOW ≥ 24 ns (≥ 8 cycles at 333 MHz; 13 cycles gives ~39 ns) | High | scl_generator.sv | cp_timing_reg.typ |
| 2.7 | SCL timing | bus_scl_high_period | Verify SCL HIGH period ≥ 24 ns with default T_HIGH=13 | Issue SDR transfer with default timing; measure SCL HIGH duration | t_HIGH ≥ 24 ns | High | scl_generator.sv | cp_timing_reg.typ |
| 2.8 | START timing | bus_start_hold_setup | Verify t_SU_STA and t_HD_STA timing with default register values | Issue transfer; measure time from SCL-HIGH to SDA-fall (t_HD_STA) and SDA-fall to SCL-fall (t_SU_STA) | Both intervals ≥ programmed register values in clock cycles | Medium | scl_generator.sv | cp_timing_reg.typ |

---

### 4.3 Category 3 — SDR Private Write

> **Note:** All RegularTransfer SDR write tests require BUG-007 fix (missing START+address phase in IssueCmd). Tests are authored against expected post-fix behavior.

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 3.1 | SDR write | i3c_sdr_write_1byte | Verify SDR write of 1 byte to I3C target completes successfully [BUG-007 required] | Set DAT[0] to I3C device dyn_addr=0x08; write RegularTransfer cmd (rnw=0, data_length=1, toc=1); write 1 TX byte; poll RESP | RESP err_status=Success; bus shows START+address(OD)+1 data byte+T-bit+STOP | High | flow_active.sv, bus_tx_flow.sv | cp_cmd_attr.RegularTransfer, cp_dir.Write, cp_data_length.[1], cp_toc.STOP, cp_resp_err.Success |
| 3.2 | SDR write | i3c_sdr_write_4bytes | Verify SDR write of 4 bytes (one DWORD) [BUG-007 required] | RegularTransfer rnw=0, data_length=4, toc=1; write 1 TX DWORD | RESP err_status=Success, data_length=4; bus shows 4 data bytes each with correct T-bit | High | flow_active.sv, bus_tx_flow.sv | cp_cmd_attr.RegularTransfer, cp_dir.Write, cp_data_length.[2:4], cp_resp_err.Success |
| 3.3 | SDR write | i3c_sdr_write_16bytes | Verify SDR write of 16 bytes (4 DWORDs) [BUG-007 required] | RegularTransfer rnw=0, data_length=16; write 4 TX DWORDs; device ACKs each addr; device samples T-bit | RESP err_status=Success, data_length=16; all 16 bytes delivered in order | High | flow_active.sv, bus_tx_flow.sv | cp_data_length.[5:16], cp_dir.Write, cp_resp_err.Success |
| 3.4 | SDR write | i3c_sdr_write_64bytes | Verify SDR write of 64 bytes at FIFO depth limit [BUG-007 required] | RegularTransfer data_length=64; fill TX FIFO with 16 DWORDs; process until done | RESP Success, data_length=64; no StallWrite timeout during transfer | Medium | flow_active.sv, hci_queues.sv | cp_data_length.[17:64] |
| 3.5 | SDR write | i3c_sdr_write_non4aligned | Verify SDR write of 5 bytes (non-DWORD-aligned length) [BUG-007 required] | RegularTransfer data_length=5; write 2 TX DWORDs (padded) | RESP Success, data_length=5; bus shows exactly 5 data bytes (not 8) | High | flow_active.sv | cp_data_length.[2:4] |
| 3.6 | SDR write | i3c_sdr_write_backtoback | Verify back-to-back SDR writes to same device [BUG-007 required] | Queue 2 RegularTransfer write CMDs; process both sequentially | Both RESPs show Success; no bus corruption between transfers | High | flow_active.sv | cp_cmd_attr.RegularTransfer, cp_dir.Write |
| 3.7 | SDR write | i3c_sdr_write_diff_devs | Verify SDR writes to two different DAT entries (different dynamic addresses) [BUG-007 required] | DAT[0]=0x08, DAT[1]=0x12; queue write to dev_idx=0 then dev_idx=1 | Each bus frame shows correct dynamic address; both RESPs Success | High | flow_active.sv, csr_register.sv | cp_dat_index.0, cp_dat_index.mid |
| 3.8 | SDR write | i3c_sdr_write_toc1_stop | Verify STOP is generated at end of write when toc=1 | RegularTransfer rnw=0, toc=1, data_length=2 | Bus shows STOP condition after last T-bit; bus_monitor stop_det asserted | High | scl_generator.sv, flow_active.sv | cp_toc.STOP |
| 3.9 | SDR write | i3c_sdr_write_toc0_nostop | Verify no STOP is generated when toc=0 (Repeated START for chaining) [BUG-007 required] | RegularTransfer rnw=0, toc=0, data_length=2; follow with second CMD | Bus shows no STOP after first frame; Sr before second frame | Medium | scl_generator.sv, flow_active.sv | cp_toc.no_STOP |
| 3.10 | SDR write | i3c_sdr_write_tbit_parity | Verify T-bit is odd parity of each write data byte | RegularTransfer write with known data pattern (e.g., 0x55, 0xAA, 0xFF, 0x00) | T-bit sampled by monitor matches odd parity of each preceding byte | High | bus_tx.sv, bus_tx_flow.sv | cp_dir.Write |
| 3.11 | SDR write | i3c_sdr_write_fifo_stall | Verify StallWrite state when TX FIFO is empty mid-transfer [BUG-007 required] | Start RegularTransfer data_length=4; pre-load only 1 TX DWORD; observe stall then refill | flow_active enters StallWrite; resumes IssueCmd when TX data arrives; RESP Success | High | flow_active.sv, hci_queues.sv | cp_fifo_state.tx_empty, cp_flow_state.StallWrite |
| 3.12 | SDR write | i3c_sdr_write_addr_nack | Verify AddrHeader error when target NACKs the address byte [BUG-007 required] | Device driver configured to NACK address; issue RegularTransfer write | RESP err_status=AddrHeader (4); bus shows address byte + NACK; no data bytes clocked | High | flow_active.sv | cp_resp_err.AddrHeader, cp_dir.Write, cp_cmd_attr×cp_resp_err |
| 3.13 | SDR write | i3c_imm_write_1byte | Verify ImmediateDataTransfer write of 1 byte [BUG-002 required] | ImmediateDataTransfer cmd_attr=1, rnw=0, data in DWORD1[7:0], data_length=1 | RESP Success; bus shows 1 data byte; no TX FIFO access | High | flow_active.sv, csr_register.sv | cp_cmd_attr.ImmediateDataTransfer, cp_dir.Write, cp_data_length.[1] |
| 3.14 | SDR write | i3c_imm_write_4bytes | Verify ImmediateDataTransfer write of 4 bytes [BUG-002 required] | ImmediateDataTransfer cmd_attr=1, data_length=4, data in CMD DWORD1 | RESP Success; 4 bytes match CMD DWORD1 payload; TX FIFO unused | High | flow_active.sv | cp_cmd_attr.ImmediateDataTransfer, cp_data_length.[2:4] |

---

### 4.4 Category 4 — SDR Private Read

> **Note:** All RegularTransfer SDR read tests require BUG-007 (missing START), BUG-003 (partial DWORD data loss for non-4n lengths), BUG-006 (I3C read T-bit not transmitted), and BUG-010 (RX shift register data race) fixes.

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 4.1 | SDR read | i3c_sdr_read_1byte | Verify SDR read of 1 byte from I3C target [BUG-007, BUG-006, BUG-010 required] | Set DAT[0] I3C device; RegularTransfer cmd rnw=1, data_length=1; device drives 1 data byte + T-bit=0 | RESP Success, data_length=1; RX FIFO contains the device-driven byte | High | flow_active.sv, bus_rx_flow.sv | cp_cmd_attr.RegularTransfer, cp_dir.Read, cp_data_length.[1], cp_resp_err.Success |
| 4.2 | SDR read | i3c_sdr_read_4bytes | Verify SDR read of 4 bytes [BUG-007, BUG-006 required] | RegularTransfer rnw=1, data_length=4; device drives 4 bytes {0xCA, 0xFE, 0xBA, 0xBE} + T-bits | RESP Success, data_length=4; RX DWORD = 0xBEBAFECA (little-endian packing) | High | flow_active.sv, bus_rx_flow.sv | cp_cmd_attr.RegularTransfer, cp_dir.Read, cp_data_length.[2:4] |
| 4.3 | SDR read | i3c_sdr_read_16bytes | Verify SDR read of 16 bytes [BUG-007, BUG-006 required] | RegularTransfer rnw=1, data_length=16; device drives 16 bytes with T-bits | RESP Success, data_length=16; RX FIFO has 4 DWORDs with correct data | High | flow_active.sv | cp_data_length.[5:16], cp_dir.Read |
| 4.4 | SDR read | i3c_sdr_read_non4aligned | Verify SDR read of 5 bytes (partial DWORD flush) [BUG-003 regression + BUG-007 required] | RegularTransfer rnw=1, data_length=5; device drives 5 bytes | RESP Success, data_length=5; RX FIFO contains all 5 bytes (no trailing data loss) | High | flow_active.sv | cp_data_length.[2:4] |
| 4.5 | SDR read | i3c_sdr_read_backtoback | Verify back-to-back reads from same device [BUG-007 required] | Queue 2 RegularTransfer read CMDs back to back | Both RESPs Success; data matches in order; no RX FIFO corruption | High | flow_active.sv | cp_dir.Read |
| 4.6 | SDR read | i3c_sdr_read_toc1 | Verify STOP generated after last byte on read with toc=1 | RegularTransfer rnw=1, toc=1, data_length=4 | Bus shows STOP after T-bit of last byte; bus_monitor stop_det asserted | High | scl_generator.sv | cp_toc.STOP, cp_dir.Read |
| 4.7 | SDR read | i3c_sdr_read_tbit_semantics | Verify master observes T-bit=0 (end) and T-bit=1 (more data) correctly [BUG-006 required] | Device drives data with T-bit=1 for first N-1 bytes, T-bit=0 for last byte | Master reads exactly N bytes without timeout; last T-bit=0 terminates read | High | bus_rx_flow.sv, flow_active.sv | cp_dir.Read |
| 4.8 | SDR read | i3c_sdr_read_master_nack_last | Verify master drives T-bit (NACK/end indicator) after final byte [BUG-006 required] | RegularTransfer rnw=1 with known data_length; observe master T-bit output after last byte | Master drives T-bit=1 (end) on 9th clock of last byte cycle in push-pull | High | bus_tx.sv, flow_active.sv | cp_dir.Read |
| 4.9 | SDR read | i3c_sdr_read_parity_error | Verify Parity error reported when T-bit does not match expected parity [BUG-006, BUG-016 required] | Device drives data byte then deliberately drives wrong T-bit | RESP err_status=Parity (2); no additional bytes consumed | High | flow_active.sv | cp_resp_err.Parity, cp_dir×cp_resp_err |
| 4.10 | SDR read | i3c_sdr_read_rx_full_stall | Verify StallRead when RX FIFO is full [BUG-007 required] | Initiate read of 16 bytes into depth-8 RX FIFO without software draining | flow_active enters StallRead; resumes when software reads RX_DATA; RESP Success | High | flow_active.sv, hci_queues.sv | cp_fifo_state.rx_full, cp_flow_state.StallRead |
| 4.11 | SDR read | i3c_sdr_read_addr_nack | Verify AddrHeader error on read when target NACKs address [BUG-007 required] | Device driver configured to NACK address on read CMD | RESP err_status=AddrHeader (4); no RX data written; data_length=0 | High | flow_active.sv | cp_resp_err.AddrHeader, cp_dir.Read |

---

### 4.5 Category 5 — Immediate Data Transfer

> **Note:** All Immediate transfer tests require BUG-002 fix (gen_clock not set in I3CWriteImmediate / I2CWriteImmediate states).

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 5.1 | Immediate write | i3c_imm_write_cp0 | Verify ImmediateDataTransfer with cp=0 (private write, data in CMD DWORD1) [BUG-002 required] | ImmediateDataTransfer, cp=0, rnw=0, data_length=2, data bytes in DWORD1[15:0] | RESP Success; bus shows device addr + 2 data bytes; no TX FIFO access | High | flow_active.sv | cp_cmd_attr.ImmediateDataTransfer, cp_cp_bit.Regular, cp_dir.Write |
| 5.2 | Immediate write | i3c_imm_bcast_ccc | Verify ImmediateDataTransfer with cp=1, !cmd[7] generates broadcast CCC [BUG-002 required] | ImmediateDataTransfer, cp=1, cmd=0x01 (DISEC), data_length=1, defining byte in DWORD1 | Bus shows [S]+0x7E+W+ACK+0x01+ACK+defining_byte+ACK+[P]; RESP Success | High | flow_active.sv | cp_cmd_attr.ImmediateDataTransfer, cp_cp_bit.BroadcastCCC |
| 5.3 | Immediate write | i3c_imm_direct_ccc | Verify ImmediateDataTransfer with cp=1, cmd[7]=1 generates directed CCC [BUG-002 required] | ImmediateDataTransfer, cp=1, cmd=0x81 (DIR_DISEC), dev_idx=0 (target addr in DAT) | Bus shows 0x7E+W+0x81+[Sr]+target_addr+W+ACK+data+[P]; RESP Success | High | flow_active.sv | cp_cmd_attr.ImmediateDataTransfer, cp_cp_bit.DirectedCCC |
| 5.4 | Immediate write | i3c_imm_write_max4bytes | Verify 4-byte immediate payload fits fully in DWORD1 [BUG-002 required] | ImmediateDataTransfer, data_length=4, DWORD1=0xAABBCCDD | RESP Success; 4 bytes on bus match DWORD1 byte order | High | flow_active.sv | cp_data_length.[2:4], cp_cmd_attr.ImmediateDataTransfer |
| 5.5 | Immediate write | i3c_imm_vs_regular_short | Compare Immediate and Regular transfer for 1-byte payload [BUG-002 + BUG-007 required] | Issue ImmediateDataTransfer, then issue RegularTransfer both for 1 byte same device | Both generate identical bus frames; ImmediateDataTransfer skips TX FIFO access | Medium | flow_active.sv | cp_cmd_attr.ImmediateDataTransfer, cp_cmd_attr.RegularTransfer |
| 5.6 | Immediate write | i3c_imm_i2c_path | Verify ImmediateDataTransfer routes to I2CWriteImmediate when DAT.device=1 [BUG-002 required] | Set DAT[0].device=1 (I2C); issue ImmediateDataTransfer cmd with dev_idx=0 | FSM enters I2CWriteImmediate; bus uses open-drain, ACK polling per I2C; RESP Success | Medium | flow_active.sv | cp_cmd_attr.ImmediateDataTransfer |
| 5.7 | Immediate write | i3c_imm_data_length_zero | Verify ImmediateDataTransfer with data_length=0 (command only, no payload) [BUG-002 required] | ImmediateDataTransfer, cp=1, data_length=0 | Bus shows CCC code with no data bytes; RESP Success, data_length=0 | Medium | flow_active.sv | cp_data_length.[1], cp_cmd_attr.ImmediateDataTransfer |

---

### 4.6 Category 6 — CCC Tests

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 6.1 | Broadcast CCC | ccc_enec_broadcast | Verify broadcast ENEC (0x00) issued correctly to 0x7E [BUG-002 required] | ImmediateDataTransfer, cp=1, cmd=0x00 (ENEC), !cmd[7], defining_byte=0x01 | Bus shows [S]+0x7E+W+ACK+0x00+ACK+0x01+ACK+[P]; all targets respond | High | flow_active.sv | cp_ccc_code.ENEC, cp_cp_bit.BroadcastCCC |
| 6.2 | Broadcast CCC | ccc_disec_broadcast | Verify broadcast DISEC (0x01) issued correctly [BUG-002 required] | ImmediateDataTransfer, cp=1, cmd=0x01 (DISEC), defining_byte=0x00 | Bus shows 0x7E+W+0x01+defining_byte+P; RESP Success | High | flow_active.sv | cp_ccc_code.DISEC, cp_cp_bit.BroadcastCCC |
| 6.3 | Broadcast CCC | ccc_entdaa_dispatch | Verify ENTDAA (0x07) triggers ENTDAA engine via AddressAssignment cmd_attr | AddressAssignment cmd_attr=2, dev_idx=0, dev_count=1 | flow_active ccc_valid_q goes high; ENTDAA controller takes over bus; RESP issued after DAA completes | High | flow_active.sv, entdaa_controller.sv | cp_ccc_code.ENTDAA, cp_cmd_attr.AddressAssignment |
| 6.4 | Direct CCC | ccc_dir_enec | Verify directed ENEC (0x80) to specific target with Repeated START [BUG-002 required] | ImmediateDataTransfer, cp=1, cmd=0x80 (DIR_ENEC), cmd[7]=1, dev_idx=0 | Bus shows [S]+0x7E+W+0x80+[Sr]+target_addr+W+ACK+data; RESP Success | High | flow_active.sv, scl_generator.sv | cp_ccc_code.DIR_ENEC, cp_cp_bit.DirectedCCC |
| 6.5 | Direct CCC | ccc_dir_disec | Verify directed DISEC (0x81) to specific target [BUG-002 required] | ImmediateDataTransfer, cp=1, cmd=0x81 (DIR_DISEC), cmd[7]=1, dev_idx=0 | Bus shows 0x7E+W+0x81+Sr+target_addr; RESP Success | High | flow_active.sv | cp_ccc_code.DIR_DISEC, cp_cp_bit.DirectedCCC |
| 6.6 | CCC sequence | ccc_enec_disec_enec | Verify ENEC–DISEC–ENEC sequence does not leave FSM in bad state [BUG-002 required] | Issue broadcast ENEC, then DISEC, then ENEC sequentially | Each RESP shows Success; FSM returns to Idle between each; third ENEC bus frame correct | Medium | flow_active.sv | cp_ccc_code.ENEC, cp_ccc_code.DISEC, cp_cp_bit.BroadcastCCC |
| 6.7 | CCC | ccc_broadcast_no_defining_byte | Verify broadcast CCC with data_length=0 (no defining byte) [BUG-002 required] | ImmediateDataTransfer cp=1, cmd=0x00, data_length=0 | Bus shows only [S]+0x7E+W+0x00+[P]; RESP Success, no extra byte | Medium | flow_active.sv | cp_ccc_code.ENEC, cp_cp_bit.BroadcastCCC |
| 6.8 | CCC | ccc_direct_restart_gen | Verify scl_generator produces Repeated START for directed CCC [BUG-002 + BUG-014 required] | Directed CCC cmd (cmd[7]=1); observe gen_rstart_q pulse and scl_generator entering GenerateRstart | scl_generator state = GenerateRstart between CCC-byte and target-address; no stall | High | scl_generator.sv, flow_active.sv | cp_cp_bit.DirectedCCC |
| 6.9 | CCC | ccc_entdaa_code_on_bus | Verify ENTDAA CCC code 0x07 appears on the bus in the broadcast frame | AddressAssignment cmd_attr=2; observe bus byte after 0x7E+W | 0x07 byte visible on SDA after reserved-byte ACK | High | flow_active.sv, entdaa_fsm.sv | cp_ccc_code.ENTDAA |
| 6.10 | CCC | ccc_illegal_code_stability | Verify FSM does not lock up when unknown CCC code is issued [BUG-002 required] | ImmediateDataTransfer, cp=1, cmd=0xFF (unrecognized) | DUT completes transfer without hang; RESP issued (Success or error); FSM returns Idle | Medium | flow_active.sv | cp_ccc_code.illegal |

---

### 4.7 Category 7 — ENTDAA / Dynamic Address Assignment

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 7.1 | ENTDAA | i3c_entdaa_1_device | Verify ENTDAA assigns dynamic address to 1 device | Set DAT[0] dyn_addr=0x08; AddressAssignment cmd (dev_idx=0, dev_count=1); device responds with 64-bit ID; accepts 0x08 + parity | RESP Success; bus shows 64-bit PID/BCR/DCR shift then assigned address; RX FIFO has assigned addr | High | entdaa_controller.sv, entdaa_fsm.sv | cp_entdaa_dev_count.1, cp_resp_err.Success |
| 7.2 | ENTDAA | i3c_entdaa_2_devices | Verify ENTDAA assigns addresses to 2 devices in 2 rounds | DAT[0]=0x08, DAT[1]=0x12; dev_count=2; simulate 2 devices responding arbitration | Two RESP entries or accumulated RX data; both dynamic addresses assigned in 2 rounds | High | entdaa_controller.sv | cp_entdaa_dev_count.2 |
| 7.3 | ENTDAA | i3c_entdaa_no_device | Verify NoDev path when no device responds to ENTDAA | AddressAssignment dev_count=1; no device pulls SDA low for ACK after SendRsvdByte | entdaa_fsm reaches NoDev; entdaa_controller sets no_device; RESP issued normally | High | entdaa_fsm.sv | cp_entdaa_dev_count.0 |
| 7.4 | ENTDAA | i3c_entdaa_8_devices | Verify ENTDAA handles 8 device rounds | DAT[0..7] configured; dev_count=8; 8 simulated devices respond in turn | All 8 rounds complete; 8 addresses assigned; 8 restart cycles observed | Medium | entdaa_controller.sv | cp_entdaa_dev_count.8 |
| 7.5 | ENTDAA | i3c_entdaa_15_devices | Verify ENTDAA handles 15 devices (DatDepth-1) | DAT[0..14] configured; dev_count=15 | 15 rounds complete; no DAT index out-of-bounds error | Medium | entdaa_controller.sv | cp_entdaa_dev_count.15 |
| 7.6 | ENTDAA | i3c_entdaa_16_devices | Verify ENTDAA handles exactly DatDepth=16 devices | DAT[0..15] configured; dev_count=16 | All 16 rounds complete; dev_round cycles through 0..15; RESP Success | Medium | entdaa_controller.sv | cp_entdaa_dev_count.16 |
| 7.7 | ENTDAA | i3c_entdaa_stop_during_daa | Verify STOP condition during DAA terminates gracefully | Start ENTDAA; inject bus STOP mid-ID-shift (e.g., target releases bus) | entdaa_controller transitions to Done; no hang; RESP issued | High | entdaa_controller.sv | cp_entdaa_dev_count.1 |
| 7.8 | ENTDAA | i3c_entdaa_pid_shift_64bit | Verify 64-bit PID/BCR/DCR shift register captures correct value | Device drives known 64-bit ID = 0x12345678_9ABCDEF0; observe id_shift_q after ReceiveIDBit | PID[47:0]=0x123456789ABC, BCR=0xDE, DCR=0xF0 captured in entdaa_fsm id_shift_q | High | entdaa_fsm.sv | cp_entdaa_dev_count.1 |
| 7.9 | ENTDAA | i3c_entdaa_addr_parity | Verify dynamic address transmitted with correct odd parity bit | DAT[0].dynamic_address=0x08 (0b0001000); parity=~^0b0001000 | 7-bit address + parity bit transmitted on SDA; target samples correct parity | High | entdaa_fsm.sv | cp_entdaa_dev_count.1 |
| 7.10 | ENTDAA | i3c_entdaa_addr_ack | Verify addr_valid when target ACKs dynamic address (ACK=0) | ENTDAA round with device driving ACK on address; check addr_valid_o | entdaa_fsm reaches Done with addr_valid=1; entdaa_controller advances dev_round | High | entdaa_fsm.sv | cp_entdaa_dev_count.1 |
| 7.11 | ENTDAA | i3c_entdaa_devcount_clamp | Verify dev_idx + dev_round is clamped to DatDepth-1 when dev_count > remaining DAT entries | dev_idx=14, dev_count=4 (would require DAT[14..17]) | dev_idx + dev_round clamped at 15; no segfault; RESP issued | Medium | entdaa_controller.sv | cp_dat_index.15 |
| 7.12 | ENTDAA | i3c_entdaa_rx_fifo_addrs | Verify assigned dynamic addresses are written to RX FIFO | ENTDAA with 2 devices; read RX_DATA after completion | RX FIFO contains assigned addresses (as reported by daa_address_o from entdaa_controller) | High | flow_active.sv, entdaa_controller.sv | cp_entdaa_dev_count.2, cp_dir.Read |

---

### 4.8 Category 8 — I2C Legacy Compatibility

> **Note:** All I2C tests require BUG-004 fix (I2C write ACK never received) and BUG-005 fix (I2C read master ACK never sent).

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 8.1 | I2C write | i2c_fm_write_1byte | Verify I2C 400 kHz write of 1 byte to legacy device [BUG-004 required] | Set DAT[0].device=1, static_addr=0x50; RegularTransfer rnw=0, data_length=1; I2C device ACKs | RESP Success; bus shows [S]+0x50+W+ACK+0xNN+ACK+[P] in open-drain; I2C timing | High | flow_active.sv, bus_tx_flow.sv | cp_speed_mode.I2C_FM_400kHz, cp_dir.Write, cp_resp_err.Success |
| 8.2 | I2C write | i2c_fm_write_4bytes | Verify I2C write of 4 bytes with per-byte ACK [BUG-004 required] | DAT[0].device=1; RegularTransfer data_length=4; device ACKs each byte | RESP Success, data_length=4; 4 ACK bits observed on bus (one per byte) | High | flow_active.sv | cp_speed_mode.I2C_FM_400kHz, cp_data_length.[2:4] |
| 8.3 | I2C read | i2c_fm_read_1byte | Verify I2C 400 kHz read of 1 byte from legacy device [BUG-005 required] | DAT[0].device=1; RegularTransfer rnw=1, data_length=1; device drives byte; master sends NACK | RESP Success, data_length=1; correct byte in RX FIFO; master NACK terminates read | High | flow_active.sv, bus_rx_flow.sv | cp_speed_mode.I2C_FM_400kHz, cp_dir.Read |
| 8.4 | I2C read | i2c_fm_read_4bytes | Verify I2C read of 4 bytes (master ACKs first 3, NACKs last) [BUG-005 required] | DAT[0].device=1; RegularTransfer rnw=1, data_length=4; device drives 4 bytes | RESP Success, data_length=4; 3 ACKs then 1 NACK from master; all 4 bytes in RX FIFO | High | flow_active.sv | cp_data_length.[2:4], cp_speed_mode.I2C_FM_400kHz |
| 8.5 | I2C error | i2c_fm_write_addr_nack | Verify I2C write when device NACKs address [BUG-004 required] | DAT[0].device=1; device driver configured to NACK address on write | RESP err_status=AddrHeader (4); no data bytes transmitted | High | flow_active.sv | cp_resp_err.AddrHeader, cp_speed_mode.I2C_FM_400kHz |
| 8.6 | I2C error | i2c_fm_write_data_nack | Verify I2C write when device NACKs a data byte mid-transfer [BUG-004 required] | 4-byte I2C write; device ACKs address but NACKs byte 2 | RESP err_status=Nack (5); transfer aborted at NACK byte | High | flow_active.sv | cp_resp_err.Nack, cp_speed_mode.I2C_FM_400kHz |
| 8.7 | I2C error | i2c_fm_read_last_byte_nack | Verify master sends NACK on last I2C read byte to terminate read [BUG-005 required] | I2C read data_length=4; observe master ACK/NACK sequence | Bytes 0-2: master drives ACK; byte 3: master drives NACK; STOP follows | High | flow_active.sv, bus_tx.sv | cp_speed_mode.I2C_FM_400kHz, cp_dir.Read |
| 8.8 | I2C seq | i2c_fm_repeated_start_rw | Verify I2C Repeated START for read-after-write (direction change) | Issue I2C write with toc=0 followed by read CMD; expect Sr between them | Bus shows write frame + Sr + address+R + read frame; both RESPs Success | Medium | flow_active.sv, scl_generator.sv | cp_speed_mode.I2C_FM_400kHz, cp_toc.no_STOP |
| 8.9 | I2C timing | i2c_fm_400khz_timing | Verify I2C 400 kHz timing constraints (t_LOW≥1300ns, t_HIGH≥600ns) | Issue I2C write; measure SCL period at 100 MHz TB clock with I2C timing regs | SCL period ~2500 ns (400 kHz); t_LOW ≥ 130 cycles; t_HIGH ≥ 60 cycles at 100 MHz | High | scl_generator.sv, csr_register.sv | cp_speed_mode.I2C_FM_400kHz |
| 8.10 | I2C vs I3C | i2c_vs_i3c_dat_flag | Verify DAT.device flag correctly routes I2C vs I3C paths | Write two CMDs: one with DAT[0].device=0 (I3C), one with DAT[1].device=1 (I2C) | I3C cmd uses open-drain→push-pull; I2C cmd stays open-drain throughout | High | flow_active.sv, csr_register.sv | cp_speed_mode.I3C_SDR_12p5MHz, cp_speed_mode.I2C_FM_400kHz |
| 8.11 | I2C addr | i2c_fm_static_addr_in_frame | Verify 7-bit static address from DAT entry appears in I2C address phase | DAT[0].device=1, static_addr=0x50; issue I2C write | Bus address byte = {0x50, W} = 0xA0; NACK/ACK from device at correct position | High | flow_active.sv, csr_register.sv | cp_speed_mode.I2C_FM_400kHz |

---

### 4.9 Category 9 — Combo Transfer (Bug-Aware)

> **Note:** ComboTransfer (cmd_attr=3) has a known defect: `FetchDAT` lacks a Combo branch, so offset bytes are never emitted. Tests document current (broken) behavior and expected (fixed) behavior.

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 9.1 | Combo transfer | combo_attr_current_behavior | Verify ComboTransfer behaves like RegularTransfer (no offset bytes) — bug-aware | Issue cmd with cmd_attr=ComboTransfer(3); observe bus | No offset bytes on bus (same as Regular); RESP issued; no FSM hang | Medium | flow_active.sv | cp_cmd_attr.ComboTransfer |
| 9.2 | Combo transfer | combo_offset_not_emitted | Confirm offset bytes absent — regression test for BUG in FetchDAT | ComboTransfer with known offset data in DWORD1; monitor SDA for offset pattern | Offset bytes NOT observed on bus (confirming bug exists); RESP completes without hang | Medium | flow_active.sv | cp_cmd_attr.ComboTransfer |
| 9.3 | Combo transfer | combo_fsm_stability | Verify FSM does not hang or lock on ComboTransfer cmd_attr | Issue ComboTransfer; wait for RESP with timeout | RESP appears within 1000 cycles; FSM returns to Idle; no deadlock | High | flow_active.sv | cp_cmd_attr.ComboTransfer, cp_flow_state.WaitForCmd |

---

### 4.10 Category 10 — FIFO Behavior

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 10.1 | CMD FIFO | fifo_cmd_full | Verify CMD FIFO full condition (depth=8 in TB) | Write 8 complete CMDs (16 DWORD writes) without processing | QUEUE_STATUS.cmd_full=1; HC_STATUS.cmd_full=1; further writes ignored | High | hci_queues.sv, csr_register.sv | cp_fifo_state.cmd_full |
| 10.2 | CMD FIFO | fifo_cmd_empty | Verify CMD FIFO empty initially after reset | Reset DUT; enable; read QUEUE_STATUS | QUEUE_STATUS.cmd_empty=1 | High | hci_queues.sv | cp_fifo_state.all_empty |
| 10.3 | TX FIFO | fifo_tx_empty_stall | Verify StallWrite state entered when TX FIFO drains mid-write [BUG-007 required] | Start RegularTransfer data_length=8; load only 4 bytes in TX FIFO before CMD issued | Flow FSM enters StallWrite; gen_clock deasserted; StallWrite exits when TX refilled | High | flow_active.sv, hci_queues.sv | cp_fifo_state.tx_empty, cp_flow_state.StallWrite |
| 10.4 | TX FIFO | fifo_tx_stall_then_resume | Verify transfer resumes correctly after StallWrite exits [BUG-007 required] | Trigger StallWrite; then write remaining TX data; wait for RESP | RESP Success; all bytes in correct order on bus; no byte gap other than SCL stretch | High | flow_active.sv | cp_flow_state.StallWrite, cp_resp_err.Success |
| 10.5 | RX FIFO | fifo_rx_full_stall | Verify StallRead state entered when RX FIFO full [BUG-007 required] | Read 8+ bytes without software draining RX FIFO (depth=8) | FSM enters StallRead; SCL held low; resumes when software reads RX_DATA | High | flow_active.sv, hci_queues.sv | cp_fifo_state.rx_full, cp_flow_state.StallRead |
| 10.6 | RESP FIFO | fifo_resp_full | Verify RESP FIFO full condition (depth=8 in TB) | Issue 8 commands without reading RESP; check QUEUE_STATUS | QUEUE_STATUS.resp_full=1 after 8 completions; subsequent CMD stalls | Medium | hci_queues.sv, csr_register.sv | cp_fifo_state.resp_full |
| 10.7 | QUEUE_STATUS | fifo_queue_status_accuracy | Verify all 8 QUEUE_STATUS bits reflect accurate FIFO states | Systematically fill/drain each FIFO; check QUEUE_STATUS after each step | Each bit transitions at the correct threshold (full at 8, empty at 0) | High | csr_register.sv, hci_queues.sv | cp_fifo_state.cmd_full, cp_fifo_state.tx_empty, cp_fifo_state.rx_full, cp_fifo_state.resp_full |
| 10.8 | SW reset | fifo_sw_reset_clears_all | Verify sw_reset flushes all 4 FIFOs simultaneously | Partially fill CMD, TX, RX, RESP FIFOs; pulse sw_reset | All FIFOs empty after reset; QUEUE_STATUS shows all-empty | High | csr_register.sv, hci_queues.sv | cp_reset_point.Idle |
| 10.9 | CMD FIFO | fifo_cmd_multiple_queued | Verify multiple CMDs queued in CMD FIFO process in FIFO order | Queue 4 write CMDs with different dev_idx; observe bus sequence | CMDs processed in order (dev_idx 0,1,2,3); 4 RESPs in corresponding order | High | flow_active.sv, hci_queues.sv | cp_cmd_attr.RegularTransfer |
| 10.10 | FIFO depth | fifo_depth_boundary | Verify write of exactly depth entries and then read-back | Write 8 CMDs; process 8; queue 8 more | No data loss; second batch of 8 processes correctly | Medium | hci_queues.sv | cp_fifo_state.cmd_full, cp_fifo_state.all_empty |

---

### 4.11 Category 11 — Response and Error Reporting

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 11.1 | RESP success | resp_success_write | Verify err_status=Success (0) on valid SDR write [BUG-007 required] | Issue valid RegularTransfer write; device ACKs address | RESP[31:28]=4'h0 (Success); RESP valid in RESP FIFO | High | flow_active.sv | cp_resp_err.Success, cp_dir.Write |
| 11.2 | RESP success | resp_success_read | Verify err_status=Success on valid SDR read [BUG-007 required] | Issue valid RegularTransfer read; device drives data | RESP[31:28]=4'h0; data_length field = bytes actually received | High | flow_active.sv | cp_resp_err.Success, cp_dir.Read |
| 11.3 | RESP error | resp_addr_header_err | Verify err_status=AddrHeader (4) when address is NACKed | Device NACKs address byte on write or read | RESP[31:28]=4'h4 (AddrHeader); no data bytes in TX/RX processed | High | flow_active.sv | cp_resp_err.AddrHeader, cp_cmd_attr×cp_resp_err |
| 11.4 | RESP error | resp_nack_i2c_data | Verify err_status=Nack (5) when I2C device NACKs a data byte [BUG-004 required] | I2C write; device ACKs address but NACKs data byte 2 | RESP[31:28]=4'h5 (Nack); transfer aborted | High | flow_active.sv | cp_resp_err.Nack, cp_dir×cp_resp_err |
| 11.5 | RESP error | resp_parity_error | Verify err_status=Parity (2) on T-bit mismatch [BUG-006 + BUG-016 required] | I3C read; device drives data with intentionally wrong T-bit | RESP[31:28]=4'h2 (Parity); error detected at 9th bit of affected byte | High | flow_active.sv | cp_resp_err.Parity |
| 11.6 | RESP field | resp_tid_echo | Verify tid field in RESP matches tid in command descriptor | Issue write with tid=0x5 in CMD DWORD0[6:3] | RESP[27:24]=4'h5; tid echoed back correctly | High | flow_active.sv, csr_register.sv | — |
| 11.7 | RESP field | resp_data_length_read | Verify data_length in RESP equals bytes actually received on read [BUG-007 + BUG-003 required] | RegularTransfer rnw=1, data_length=5; device drives 5 bytes | RESP[15:0]=16'd5; matches actual bytes received | High | flow_active.sv | cp_dir.Read |
| 11.8 | RESP field | resp_data_length_error | Verify data_length=0 in RESP on AddrHeader error | Issue CMD; device NACKs address | RESP[15:0]=16'd0; no data transferred | Medium | flow_active.sv | cp_resp_err.AddrHeader |
| 11.9 | RESP NA codes | resp_unreachable_codes_na | Document unreachable error codes as N/A in current RTL | Code review only (no UVM test required) | Codes Crc(1), Frame(3), Ovl(6), ShortRead(7), HcAborted(8), NotSupported(10) have no production path; verified by inspection | Low | flow_active.sv (code paths not present) | — |

---

### 4.12 Category 12 — Timing Programmability

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 12.1 | T_R | timing_tr_min | Verify T_R=1 (minimum, 1 cycle) loads correctly and SCL rise measured | Write T_R=1 to 0x010; issue SDR transfer | scl_generator counts t_r=1 cycle on rising edge; no timing violation | Medium | scl_generator.sv, csr_register.sv | cp_timing_reg.min |
| 12.2 | T_R | timing_tr_max | Verify T_R=15 cycles (practical max) slows rise time correctly | Write T_R=15; issue SDR transfer; measure SCL cycle | SCL rise phase takes 15+13=28 cycles (DriveHigh state count) | Medium | scl_generator.sv | cp_timing_reg.max |
| 12.3 | T_F | timing_tf_range | Verify T_F register affects scl_generator DriveLow countdown | Write T_F=2 then T_F=8; measure SCL LOW phase | t_LOW effective = T_LOW + T_F cycles; changes proportionally | Medium | scl_generator.sv | cp_timing_reg.min, cp_timing_reg.max |
| 12.4 | T_LOW | timing_tlow_spec_min | Verify default T_LOW=13 meets I3C SDR ≥24ns at 333 MHz (≥8 cycles) | Use default T_LOW=13; issue SDR transfer; measure SCL LOW period | t_LOW = (13+T_F) cycles ≥ 8 at 333 MHz (~50 ns); meets spec | High | scl_generator.sv | cp_timing_reg.typ |
| 12.5 | T_HIGH | timing_thigh_spec_min | Verify default T_HIGH=13 meets I3C SDR ≥24ns at 333 MHz | Use default T_HIGH=13; issue SDR transfer; measure SCL HIGH period | t_HIGH = (13+T_R) cycles ≥ 8; meets spec | High | scl_generator.sv | cp_timing_reg.typ |
| 12.6 | T_SU_STA | timing_tsu_sta | Verify T_SU_STA programmed value reflected in START setup time | Write T_SU_STA=20; issue command; measure time from SCL-HIGH to SDA-fall | Measured interval = T_SU_STA cycles ± 1 (BUG-012 off-by-one) | Medium | scl_generator.sv, edge_detector.sv | cp_timing_reg.typ |
| 12.7 | T_HD_STA | timing_thd_sta | Verify T_HD_STA programmed value reflected in START hold time | Write T_HD_STA=15; issue command; measure SDA-fall to SCL-fall interval | Measured interval ≥ T_HD_STA cycles | Medium | scl_generator.sv | cp_timing_reg.typ |
| 12.8 | T_SU_STO | timing_tsu_sto | Verify T_SU_STO meets I3C ≥12ns (≥4 cycles at 333 MHz) with default=13 | Use default T_SU_STO=13; measure SCL-HIGH to SDA-rise interval | ≥ 13 cycles; meets ≥12ns spec | High | scl_generator.sv | cp_timing_reg.typ |
| 12.9 | T_SU_DAT | timing_tsu_dat | Verify T_SU_DAT controls data setup before SCL rising edge | Write T_SU_DAT=3; issue SDR write; measure SDA-stable to SCL-HIGH | SDA stable ≥ T_SU_DAT cycles before SCL rises | High | bus_tx.sv | cp_timing_reg.typ |
| 12.10 | T_HD_DAT | timing_thd_dat | Verify T_HD_DAT controls data hold after SCL falling edge | Write T_HD_DAT=4; issue SDR write; measure SDA change after SCL falls | SDA holds ≥ T_HD_DAT cycles after SCL negedge | High | bus_tx.sv | cp_timing_reg.typ |

---

### 4.13 Category 13 — Reset and Recovery

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 13.1 | Async reset | rst_ni_in_idle | Verify async rst_ni assertion in Idle state | Enable DUT; allow FSM to reach Idle; deassert rst_ni | FSM resets to Idle; all outputs deasserted; HC_STATUS shows fsm_idle=0 | High | flow_active.sv | cp_reset_point.Idle, cp_flow_state.Idle |
| 13.2 | Async reset | rst_ni_in_waitforcmd | Verify async rst_ni during WaitForCmd (CMD FIFO read) | Write CMD; immediately deassert rst_ni before CMD popped | FSM resets; CMD FIFO cleared by sw_reset; no partial CMD dispatched | High | flow_active.sv | cp_reset_point.WaitForCmd, cp_flow_state.WaitForCmd |
| 13.3 | Async reset | rst_ni_in_fetchdat | Verify async rst_ni during FetchDAT | Queue CMD; deassert rst_ni during DAT lookup cycle | FSM resets; no invalid bus activity; DUT recovers | High | flow_active.sv, csr_register.sv | cp_reset_point.FetchDAT, cp_flow_state.FetchDAT |
| 13.4 | Async reset | rst_ni_in_i3c_imm | Verify async rst_ni during I3CWriteImmediate bus activity | Issue Immediate CMD; deassert rst_ni mid-address-phase | Bus STOP or float; FSM returns to Idle; no data corruption | High | flow_active.sv | cp_reset_point.Imm_or_Regular |
| 13.5 | Async reset | rst_ni_in_i2c_imm | Verify async rst_ni during I2CWriteImmediate | Issue I2C Immediate CMD; deassert rst_ni mid-transmission | Clean abort; FSM Idle; no spurious ACK on bus | High | flow_active.sv | cp_reset_point.Imm_or_Regular |
| 13.6 | Async reset | rst_ni_in_fetch_fifo | Verify rst_ni during FetchTxData or FetchRxData [BUG-007 required] | Initiate RegularTransfer; deassert rst_ni during FIFO fetch | FIFOs flushed; FSM Idle; no partial FIFO transaction committed | Medium | flow_active.sv, hci_queues.sv | cp_reset_point.Imm_or_Regular |
| 13.7 | Async reset | rst_ni_in_init_i2c | Verify rst_ni during InitI2CWrite or InitI2CRead | Issue I2C write/read; deassert rst_ni during address phase | FSM resets; no partial address byte on bus; DUT recovers | Medium | flow_active.sv | cp_reset_point.IssueCmd_addr |
| 13.8 | Async reset | rst_ni_in_stallwrite | Verify rst_ni during StallWrite [BUG-007 required] | Trigger StallWrite; deassert rst_ni | FSM exits immediately; no indefinite SCL hold; FIFOs cleared | High | flow_active.sv | cp_reset_point.Stall, cp_flow_state.StallWrite |
| 13.9 | Async reset | rst_ni_in_stallread | Verify rst_ni during StallRead [BUG-007 required] | Trigger StallRead; deassert rst_ni | FSM exits; SCL released; FIFOs cleared | High | flow_active.sv | cp_reset_point.Stall, cp_flow_state.StallRead |
| 13.10 | Async reset | rst_ni_in_issuecmd_data | Verify rst_ni during data byte transmission in IssueCmd [BUG-007 required] | Mid-data-phase reset (after address, before last byte) | SCL halts; bus floats; FSM Idle after reset release | High | flow_active.sv | cp_reset_point.IssueCmd_data |
| 13.11 | Async reset | rst_ni_in_writeresp | Verify rst_ni during WriteResp (RESP FIFO write) | Deassert rst_ni at cycle when resp_wvalid goes high | RESP FIFO flushed; partial RESP not committed; FSM Idle | High | flow_active.sv | cp_reset_point.Imm_or_Regular, cp_flow_state.WriteResp |
| 13.12 | SW reset | sw_reset_mid_cmd | Verify sw_reset during active command sequence | Issue RegularTransfer; assert sw_reset while IssueCmd active | FIFOs cleared; FSM returns to Idle; subsequent CMD works normally | High | csr_register.sv, flow_active.sv | cp_reset_point.IssueCmd_data |
| 13.13 | SW reset | sw_reset_staging_clear | Verify sw_reset clears cmd_staging_valid_q (BUG-008 regression) | Write DWORD0 to CMD_QUEUE; issue sw_reset; write new CMD pair (DWORD0+DWORD1) | New CMD dispatches correctly; no pairing with stale DWORD0 | High | csr_register.sv | cp_reset_point.WaitForCmd |
| 13.14 | Recovery | rst_post_reset_transfer | Verify legal transfer completes after async reset | Assert rst_ni; release; re-enable hc_enable; issue valid SDR write | RESP Success; no hangs or stale state from pre-reset | High | flow_active.sv | cp_reset_point.Idle, cp_resp_err.Success |

---

### 4.14 Category 14 — UVM and Scoreboard Self-Checks

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 14.1 | Scoreboard | scb_cmd_dword_assembly | Verify scoreboard correctly pairs CMD DWORD0 and DWORD1 | Issue 3 CMDs with distinct TIDs; scoreboard processes 6 DWORD writes | Scoreboard pairs (DWORD0, DWORD1) correctly for all 3 CMDs; no mismatch | High | i3c_scoreboard.sv | — |
| 14.2 | Scoreboard | scb_tx_byte_order | Verify scoreboard checks TX data in correct bus byte order | Write TX DWORD=0x01020304; expect bus sends 0x04, 0x03, 0x02, 0x01 (little-endian FIFO) | No scoreboard TX mismatch; byte order consistent with protocol | High | i3c_scoreboard.sv, bus_tx_flow.sv | — |
| 14.3 | Scoreboard | scb_rx_data_check | Verify scoreboard RX data path (Phase-2 addition implied) | Device drives 4 known bytes; scoreboard checks RX FIFO content | RX DWORD read by SW matches device-driven bytes; scoreboard pass_cnt increments | High | i3c_scoreboard.sv | — |
| 14.4 | Scoreboard | scb_resp_tid_match | Verify scoreboard matches RESP TID to CMD TID | Issue CMD with tid=0xA; read RESP; scoreboard compares | No scoreboard mismatch on TID; pass_cnt increments | High | i3c_scoreboard.sv | — |
| 14.5 | Scoreboard | scb_eot_unconsumed_tx | Verify scoreboard flags leftover TX data at end-of-test | Write TX data without issuing matching CMD; let test end | DV_EOT_PRINT_TLM_FIFO_CONTENTS outputs unconsumed TX entries; testbench reports error | Medium | i3c_scoreboard.sv, dv_macros.svh | — |
| 14.6 | Scoreboard | scb_zero_fail_count | Verify fail_count=0 after clean smoke/write/read regression | Run i3c_smoke_vseq + i3c_write_vseq + i3c_read_vseq | i3c_scoreboard.fail_cnt=0; pass_cnt ≥ 3 | High | i3c_scoreboard.sv | cp_resp_err.Success |

---

### 4.15 Category 15 — Negative and Corner Cases

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 15.1 | Illegal CMD | neg_cmd_attr_undefined | Verify undefined cmd_attr=2'b11 does not crash FSM | Issue CMD DWORD with cmd_attr=2'b11 (undefined enum) | FSM issues RESP or stays Idle; no simulation deadlock within 5000 cycles | High | flow_active.sv | cp_cmd_attr.ComboTransfer |
| 15.2 | Illegal DAT | neg_dev_idx_out_of_range | Verify dev_idx > 15 does not cause out-of-bounds DAT access | Issue CMD with dev_idx=17 (> DatDepth-1=15) | DAT read clamped or wraps; no XMEM error; RESP issued; no crash | High | flow_active.sv, csr_register.sv | cp_dat_index.out_of_range |
| 15.3 | Protocol | neg_cmd_before_enable | Verify CMD written before hc_enable has no effect on bus | Write CMD DWORD without setting HC_CONTROL.hc_enable=1 | No bus activity; cmd_full may assert; no RESP generated until enable | High | csr_register.sv, flow_active.sv | — |
| 15.4 | Register | neg_write_to_ro_status | Verify write to read-only HC_STATUS has no effect | Write 0xFFFFFFFF to 0x004 (HC_STATUS); read back | HC_STATUS unchanged; read-back reflects hardware state | Medium | csr_register.sv | — |
| 15.5 | FIFO | neg_read_empty_rx_fifo | Verify read of empty RX_DATA does not assert rx_rready spuriously | Read 0x108 (RX_DATA) when QUEUE_STATUS.rx_empty=1 | Stale or zero data returned; rx_rready_o not pulsed spuriously; no protocol error | Medium | csr_register.sv, hci_queues.sv | cp_fifo_state.all_empty |
| 15.6 | HDR mode | neg_hdr_tsx_ignored | Verify HDR-TS mode descriptor does not cause FSM divergence | Issue CMD with mode=hdr_tsx (2'b110); observe bus | Bus activity same as SDR (mode field silently ignored); RESP issued; no hang | Medium | flow_active.sv | — |
| 15.7 | HDR mode | neg_hdr_ddr_ignored | Verify HDR-DDR mode descriptor treated as SDR | Issue CMD with mode=hdr_ddr (2'b111) | Same behavior as SDR; no HDR-DDR bus patterns; RESP issued normally | Medium | flow_active.sv | — |
| 15.8 | Data length | neg_data_length_zero_write | Verify write CMD with data_length=0 | Issue RegularTransfer rnw=0, data_length=0 | RESP issued (Success or AddrHeader); no TX FIFO popped; no hang | Medium | flow_active.sv | cp_data_length.[1] |
| 15.9 | Data length | neg_data_length_zero_read | Verify read CMD with data_length=0 | Issue RegularTransfer rnw=1, data_length=0 | RESP issued; no RX data expected; no StallRead hang | Medium | flow_active.sv | cp_data_length.[1], cp_dir.Read |

---

### 4.16 Category 16 — Stress and Random Regression

| No | Test Item | Test Name | Description | Test flow | Pass Condition | Priority | Related Module | Coverage Tags |
|---|---|---|---|---|---|---|---|---|
| 16.1 | Stress | stress_100_random_writes | Verify 100 randomized SDR writes complete without scoreboard errors [BUG-007 required] | Random dev_idx (0–3), random data_length (1–8), random data for 100 CMDs | All 100 RESPs Success; scoreboard fail_cnt=0; no bus lockup | High | flow_active.sv | cp_cmd_attr.RegularTransfer, cp_dir.Write |
| 16.2 | Stress | stress_100_random_reads | Verify 100 randomized SDR reads [BUG-007 required] | Random dev_idx, random data_length (1–8), device provides known data for 100 reads | All 100 RESPs Success; all RX data correct; scoreboard clean | High | flow_active.sv | cp_dir.Read |
| 16.3 | Stress | stress_mixed_rw_500 | Mixed write/read sequence of 500 transactions [BUG-007 required] | Randomly interleave write and read CMDs; random dev_idx and lengths | No scoreboard mismatch; no deadlock; pass_cnt=500 | High | flow_active.sv | cp_dir.Write, cp_dir.Read, cp_cmd_attr×cp_dir |
| 16.4 | Stress | stress_random_dat_entries | Random access to all 16 DAT entries | Configure DAT[0..15]; randomly issue CMDs with dev_idx 0..15 | Correct dynamic/static address used per dev_idx; no address collision | Medium | flow_active.sv, csr_register.sv | cp_dat_index.0, cp_dat_index.mid, cp_dat_index.15 |
| 16.5 | Stress | stress_random_data_length | Randomize data_length from 1 to 64 for write/read [BUG-007 + BUG-003 required] | Issue CMDs with random data_length 1–64; mix aligned and non-aligned | All RESP Success; data_length in RESP matches commanded length; no data loss | High | flow_active.sv | cp_data_length.[1], cp_data_length.[2:4], cp_data_length.[5:16], cp_data_length.[17:64] |
| 16.6 | Stress | stress_random_toc | Random toc=0 and toc=1 per transaction [BUG-007 required] | Alternate toc=0 (chain) and toc=1 (stop) across 50 CMDs | Chained frames generate no spurious STOP; independent frames generate STOP; no lockup | High | flow_active.sv, scl_generator.sv | cp_toc.STOP, cp_toc.no_STOP |
| 16.7 | Stress | stress_sw_reset_injection | Periodic sw_reset between random transactions | Issue CMD; randomly inject sw_reset; issue next CMD | Post-reset CMDs complete normally; staging register cleared; no stale CMD | High | csr_register.sv, flow_active.sv | cp_reset_point.Idle, cp_reset_point.IssueCmd_data |
| 16.8 | Long run | stress_longrun_1k | Run 1000 transactions with random parameters [BUG-007 required] | 1000 random CMDs (write/read/imm/CCC mix); random seeds | No scoreboard errors across 1000 transactions; no FSM deadlock; consistent throughput | High | flow_active.sv | cp_cmd_attr.RegularTransfer, cp_cmd_attr.ImmediateDataTransfer |
| 16.9 | Long run | stress_longrun_10k | 10,000-transaction stability run [BUG-007 required] | 10k random CMDs; monitor for avg/max latency degradation | No scoreboard mismatch; no latency degradation (max ≤ 2x average); no hang | Medium | flow_active.sv | cp_resp_err.Success |

---

## 5. Performance Plan

### 5.1 Performance Categories

| Category | What to Measure | Notes |
|---|---|---|
| A. I3C SDR write latency | Time from CMD DWORD1 write to RESP read; measured per data_length (1/4/16/64 bytes) | Use $time in UVM monitor; subtract cmd_issue_time from resp_ready_time |
| B. I3C SDR read latency | Time from CMD issue to last RX DWORD read | Break down by START→address→data→RESP phases |
| C. I2C FM write/read latency | Same latency metrics at 400 kHz; compare 10x vs SDR | Dominated by SCL period (2500 ns) vs I3C (77 ns) |
| D. ENTDAA round latency | Time per ENTDAA device round (64-bit shift + address assignment) | Scale with dev_count; plot latency vs N devices |
| E. FIFO stall sensitivity | Penalty for each StallWrite / StallRead insertion | Measure additional cycles vs no-stall baseline |
| F. Back-to-back efficiency | Inter-frame gap (last STOP/Sr to next START) | No unnecessary idle cycles beyond tCAS (≥38 ns) |
| G. Long-run throughput | Transactions/second sustained over 1k runs | Aggregate; check no degradation over time |

### 5.2 Performance Test Cases

| No | Category | Test Name | Description | Main Metric |
|---|---|---|---|---|
| P1 | SDR write latency | perf_sdr_write_1byte | Measure write latency for 1-byte payload at 12.5 MHz | avg/min/max cycles CMD→RESP |
| P2 | SDR write latency | perf_sdr_write_4bytes | Measure write latency for 4-byte payload | avg/min/max cycles |
| P3 | SDR write latency | perf_sdr_write_16bytes | Measure write latency for 16-byte payload | avg/min/max cycles; verify linear scaling |
| P4 | SDR write latency | perf_sdr_write_64bytes | Measure write latency for 64-byte payload; includes StallWrite risk | avg/min/max cycles; identify stall events |
| P5 | SDR read latency | perf_sdr_read_1byte | Measure read latency for 1-byte payload | avg/min/max cycles |
| P6 | SDR read latency | perf_sdr_read_4bytes | Measure read latency for 4-byte payload | avg/min/max cycles |
| P7 | I2C FM latency | perf_i2c_write_1byte | Measure I2C 400 kHz write latency for 1 byte | avg cycles; compare vs SDR (should be ~32x slower) |
| P8 | I2C FM latency | perf_i2c_read_4bytes | Measure I2C 400 kHz read latency for 4 bytes | avg cycles |
| P9 | FIFO stall penalty | perf_stall_write_penalty | Measure added latency from one StallWrite insertion | extra cycles beyond no-stall baseline |
| P10 | FIFO stall penalty | perf_stall_read_penalty | Measure added latency from one StallRead insertion | extra cycles |
| P11 | Back-to-back gap | perf_bb_write_write | Measure inter-frame gap for back-to-back writes (STOP→START) | gap in ns; must be ≥ tCAS = 38 ns |
| P12 | Back-to-back gap | perf_bb_write_read | Measure inter-frame gap for write-to-read transition | gap in ns |
| P13 | ENTDAA latency | perf_entdaa_1_device | Measure ENTDAA round time for 1 device | cycles per round |
| P14 | ENTDAA latency | perf_entdaa_8_devices | Measure total ENTDAA time for 8 devices | total cycles; 8 × single-round + restart overhead |
| P15 | CMD throughput | perf_cmd_to_start | Measure latency from CMD DWORD1 write to first SCL falling edge (START hold) | cycles; quantifies software→bus latency |
| P16 | Long-run stability | perf_longrun_1k_stability | Run 1k transactions; measure avg and max latency; check stability | avg/max ratio ≤ 1.5; no trend increase |

---

## 6. Coverage Plan

### 6.1 Coverpoints

| Coverpoint | Description | Bins |
|---|---|---|
| `cp_cmd_attr` | Command descriptor attribute field `cmd_attr[2:0]` | `RegularTransfer` (0), `ImmediateDataTransfer` (1), `AddressAssignment` (2), `ComboTransfer` (3) |
| `cp_dir` | Transfer direction | `Write` (rnw=0), `Read` (rnw=1) |
| `cp_speed_mode` | Effective bus speed mode | `I3C_SDR_12p5MHz` (I3C DAT entry, push-pull), `I3C_SDR_4MHz` (reduced-speed), `I2C_FM_400kHz` (DAT.device=1) |
| `cp_data_length` | Commanded data_length value | `[1]` (1 byte), `[2:4]` (2–4 bytes), `[5:16]` (5–16 bytes), `[17:64]` (17–64 bytes), `[65:256]` (65–256 bytes), `[>256]` (overflow test) |
| `cp_toc` | Transfer termination mode | `STOP` (toc=1), `no_STOP` (toc=0, chain/restart) |
| `cp_cp_bit` | CCC-present bit in immediate descriptor | `Regular` (cp=0, private transfer), `DirectedCCC` (cp=1, cmd[7]=1), `BroadcastCCC` (cp=1, cmd[7]=0) |
| `cp_ccc_code` | CCC command code in immediate descriptor | `ENEC` (0x00), `DISEC` (0x01), `ENTDAA` (0x07), `DIR_ENEC` (0x80), `DIR_DISEC` (0x81), `illegal` (any other value) |
| `cp_resp_err` | Response error status code | `Success` (0), `Parity` (2), `AddrHeader` (4), `Nack` (5) |
| `cp_dat_index` | DAT entry index used (dev_idx) | `0` (first), `mid` (1–14), `15` (last), `out_of_range` (>15) |
| `cp_entdaa_dev_count` | Number of devices in ENTDAA round | `0` (no device), `1`, `2`, `8`, `15`, `16`, `>16` (overflow) |
| `cp_fifo_state` | Observed FIFO condition during transfer | `cmd_full`, `tx_empty` (StallWrite trigger), `rx_full` (StallRead trigger), `resp_full`, `all_empty` (baseline) |
| `cp_flow_state` | flow_active FSM state visited | `Idle`, `WaitForCmd`, `FetchDAT`, `I3CWriteImmediate`, `I2CWriteImmediate`, `FetchTxData`, `FetchRxData`, `InitI2CWrite`, `InitI2CRead`, `StallWrite`, `StallRead`, `IssueCmd`, `WriteResp` |
| `cp_reset_point` | FSM state at time of reset assertion | `Idle`, `WaitForCmd`, `FetchDAT`, `Imm_or_Regular` (I3CWriteImm/I2CWriteImm), `Stall` (StallWrite/StallRead), `IssueCmd_addr`, `IssueCmd_data`, `IssueCmd_T_or_parity`, `DAA_mid` (entdaa_fsm ReceiveIDBit), `WriteResp` |
| `cp_timing_reg` | Timing register value range tested | `min` (1–4 cycles), `typ` (default: 4–13 cycles), `max` (>13 cycles) |

### 6.2 Cross Coverage

| Cross | Coverpoints | Purpose |
|---|---|---|
| `cp_cmd_attr × cp_dir` | `cp_cmd_attr`, `cp_dir` | Every transfer type in both directions |
| `cp_cmd_attr × cp_resp_err` | `cp_cmd_attr`, `cp_resp_err` | Error codes encountered per command type |
| `cp_dir × cp_resp_err` | `cp_dir`, `cp_resp_err` | Error distribution across read vs write |
| `cp_speed_mode × cp_data_length` | `cp_speed_mode`, `cp_data_length` | Short vs long transfers at each speed |
| `cp_cp_bit × cp_ccc_code` | `cp_cp_bit`, `cp_ccc_code` | CCC code usage per broadcast/directed path |
| `cp_entdaa_dev_count × cp_resp_err` | `cp_entdaa_dev_count`, `cp_resp_err` | ENTDAA outcome per device count |
| `cp_reset_point × cp_cmd_attr` | `cp_reset_point`, `cp_cmd_attr` | Reset in each FSM state for each command type |
| `cp_flow_state × cp_resp_err` | `cp_flow_state`, `cp_resp_err` | Error codes observed per FSM state |
| `cp_dat_index × cp_dir` | `cp_dat_index`, `cp_dir` | All DAT entries accessed in both read and write directions |

---

## 7. Feature ↔ Testcase ↔ Coverage Map

| Phase-1 Feature | Primary Tests | Secondary / Regression Tests | Key Coverpoints & Crosses |
|---|---|---|---|
| hc_enable / sw_reset | 1.1, 1.2, 1.13 | 10.8, 13.12, 13.13 | cp_reset_point.Idle |
| HC_STATUS / QUEUE_STATUS | 1.3, 1.4, 1.5, 1.6 | 10.7 | cp_fifo_state.* |
| Timing register programmability | 1.7, 1.8, 1.9, 12.1–12.10 | P1–P16 | cp_timing_reg.min, .typ, .max |
| DAT (16 entries) | 1.10, 1.11, 1.12, 3.7 | 16.4, 15.2 | cp_dat_index.0, .15, .mid, .out_of_range |
| START / Sr / STOP condition | 2.1, 2.2, 2.3, 2.4 | 3.8, 3.9, 8.8 | cp_toc.STOP, cp_toc.no_STOP |
| OD/PP switching (sel_od_pp) | 2.5 | 3.10, 4.8 | — |
| SCL timing (t_LOW, t_HIGH) | 2.6, 2.7, 12.4, 12.5 | P1–P8 | cp_timing_reg.typ |
| SDR private write (RegularTransfer) | 3.1–3.12 | 16.1, 16.3, 16.5, 16.6 | cp_cmd_attr.RegularTransfer, cp_dir.Write, cp_data_length.*, cp_toc.*, cp_resp_err.* |
| SDR private read (RegularTransfer) | 4.1–4.11 | 16.2, 16.3 | cp_dir.Read, cp_resp_err.Parity |
| ImmediateDataTransfer | 3.13, 3.14, 5.1–5.7 | 16.8 | cp_cmd_attr.ImmediateDataTransfer, cp_cp_bit.* |
| Broadcast CCC (ENEC/DISEC) | 6.1, 6.2, 6.6, 6.7 | 6.10 | cp_ccc_code.ENEC, cp_ccc_code.DISEC, cp_cp_bit×cp_ccc_code |
| Broadcast ENTDAA trigger | 6.3, 6.9, 7.1 | 7.2–7.12 | cp_ccc_code.ENTDAA, cp_cmd_attr.AddressAssignment |
| Direct CCC (DIR_ENEC/DIR_DISEC) | 6.4, 6.5, 6.8 | — | cp_ccc_code.DIR_ENEC, cp_ccc_code.DIR_DISEC, cp_cp_bit.DirectedCCC |
| ENTDAA single device | 7.1, 7.8, 7.9, 7.10 | 7.7 | cp_entdaa_dev_count.1, cp_resp_err.Success |
| ENTDAA multi-device | 7.2, 7.4, 7.5, 7.6 | 7.11 | cp_entdaa_dev_count.2, .8, .15, .16 |
| ENTDAA no-device path | 7.3 | — | cp_entdaa_dev_count.0 |
| ENTDAA RX FIFO output | 7.12 | — | cp_dir.Read, cp_entdaa_dev_count.2 |
| I2C FM write | 8.1, 8.2, 8.5, 8.6 | 8.10, 8.11 | cp_speed_mode.I2C_FM_400kHz, cp_dir.Write |
| I2C FM read | 8.3, 8.4, 8.7 | 8.8 | cp_speed_mode.I2C_FM_400kHz, cp_dir.Read |
| I2C 400 kHz timing | 8.9 | P7, P8 | cp_speed_mode.I2C_FM_400kHz, cp_timing_reg.typ |
| ComboTransfer (bug-aware) | 9.1, 9.2, 9.3 | — | cp_cmd_attr.ComboTransfer |
| CMD FIFO full / empty | 10.1, 10.2, 10.9, 10.10 | — | cp_fifo_state.cmd_full |
| TX FIFO stall (StallWrite) | 3.11, 10.3, 10.4 | 16.7 | cp_fifo_state.tx_empty, cp_flow_state.StallWrite |
| RX FIFO stall (StallRead) | 4.10, 10.5 | — | cp_fifo_state.rx_full, cp_flow_state.StallRead |
| RESP FIFO full | 10.6 | — | cp_fifo_state.resp_full |
| Error reporting (AddrHeader, Nack, Parity) | 11.3, 11.4, 11.5 | 3.12, 4.9, 4.11, 8.5, 8.6 | cp_resp_err.AddrHeader, .Nack, .Parity, cp_dir×cp_resp_err |
| RESP TID / data_length fields | 11.6, 11.7, 11.8 | — | — |
| Async reset (13 FSM states) | 13.1–13.11 | 13.14 | cp_reset_point.*, cp_flow_state.* |
| SW reset (mid-transfer) | 13.12, 13.13, 1.2 | 16.7 | cp_reset_point.Idle, cp_reset_point.IssueCmd_data |
| Stress / random regression | 16.1–16.9 | P16 | All coverpoints × all crosses |

---

## 8. Deferred / Phase-2 Features

The following features are **not implemented** in the current RTL and have **no test cases authored** in this plan. They are listed for completeness and to guide future development.

| Feature | Rationale for Deferral |
|---|---|
| In-Band Interrupts (IBI) | No HW support: no IBI FIFO, no IBI register, no IBI input pin. Phase-1 scope exclusion. |
| Hot-Join | No HW detection logic. Phase-1 scope exclusion. |
| HDR-DDR mode | Mode enum defined but no HDR data encoding in flow_active; no HDR framing. Phase-1 scope exclusion. |
| HDR-TS mode | Same as HDR-DDR. |
| Multi-master / secondary controller | No arbitration-loss detection. Active-controller-only design. |
| Target (I3C slave) mode | No target FSM, no CCC decode for incoming commands. |
| Target (I2C slave) mode | Same. |
| Bus recovery protocol | No `recovery_handler`, no `gen_idle` assertion path (BUG-009). |
| SETDASA (0x87) | CCC not in i3c_agent_pkg.sv enum; no RTL handling. |
| GETPID (0x8D) | Not implemented. |
| GETBCR (0x8E) / GETDCR (0x8F) | Not implemented. |
| SETMWL / SETMRL | Not implemented. |
| GETSTATUS (0x90) | Not implemented. |
| RSTACT (0x9A) | Not implemented. |
| All other non-Phase-1 CCCs | Not implemented. |
| ComboTransfer offset bytes | FetchDAT lacks Combo branch; offset bytes never emitted (BUG in flow_active). |
| Threshold IRQs / almost-full-empty flags | FIFO depth ports unconnected; no IRQ output pin on i3c_controller_top. |
| CRC error reporting (code 0x1) | CRC only relevant for HDR; not in SDR. |
| Short-Read error (0x7) | Not implemented in flow_active error path. |
| HC-Aborted error (0x8) | Not implemented. |
| I2C-Bus-Aborted error (0x9) | Not implemented. |
| NotSupported error (0xA) | Not implemented. |
| Full HCI compliance | Simplified register interface (no AXI/AHB), no threshold registers, no IRQ enable. |
| DCT (Device Characteristics Table) | Optional; not implemented. PID/BCR/DCR from ENTDAA available in RX FIFO. |
| UVM register model (uvm_reg / RAL) | Current design uses custom reg_agent. RAL adoption is Phase-2 improvement. |
| Functional coverage closure | No covergroups implemented. All deferred to Phase 2. |
| Formal property verification | SVA properties for FSM transitions and protocol compliance. Phase-2. |

---

## 9. Known Gaps and Bug Awareness

The following bugs from `docs/bug_analysis_report.md` affect specific test categories. Tests are authored against expected post-fix behavior; they will fail on the unfixed RTL.

| Bug ID | Severity | Affected Tests | Impact |
|---|---|---|---|
| BUG-001 | CRITICAL | All (compile blocker) | Stray `/` in csr_register.sv parameter list prevents compilation |
| BUG-002 | CRITICAL | Cat. 5 (all), Cat. 6 (CCC via Immediate) | `gen_clock_q` never set in I3CWriteImmediate / I2CWriteImmediate → all Immediate transfers hang after START |
| BUG-003 | CRITICAL | 4.4, 16.5 | Partial DWORD data loss for non-4n-byte read lengths (byte N % 4 != 0 dropped) |
| BUG-004 | HIGH | Cat. 8 write tests | Same-cycle TX/RX dependency in I2C write path; ACK/NACK never received |
| BUG-005 | HIGH | Cat. 8 read tests | Same-cycle TX/RX dependency in I2C read path; master ACK/NACK never transmitted |
| BUG-006 | HIGH | 4.7, 4.8, 4.9 | Same-cycle TX/RX dependency in I3C read T-bit path; T-bit never sent |
| BUG-007 | HIGH | All Cat. 3 + Cat. 4 RegularTransfer tests | Missing START condition and address byte for I3C regular write/read |
| BUG-008 | HIGH | 1.13, 13.13 | sw_reset does not clear cmd_staging_valid_q / cmd_dword0_q |
| BUG-009 | HIGH | 13.8, 13.9, error recovery | gen_idle_o never asserted; no bus abort mechanism |
| BUG-010 | HIGH | 4.1–4.11 | bus_rx_flow uses stale sda_i instead of registered rx_bit; data race on shift register |
| BUG-011 | HIGH | 10.1–10.10 (if depth≠power-of-2) | sync_fifo full/empty only correct for power-of-2 depths (current depths=8/64 are safe) |
| BUG-012 | MEDIUM | 12.6 | edge_detector off-by-one: actual delay = delay_count+1 cycles |
| BUG-013 | MEDIUM | 12.6 | stable_high_detector off-by-one inconsistency with edge_detector |
| BUG-014 | MEDIUM | 6.8, 13.x during DAA | scl_generator WaitCmd does not handle gen_rstart_i; Repeated START from WaitCmd ignored |
| BUG-015 | MEDIUM | 6.9 (ccc_code_o verification) | ccc_code_o always driven 0; external modules cannot read CCC code |
| BUG-016 | MEDIUM | 4.9, 11.5 | T-bit parity check is static (`!= 1'b1`) instead of computing odd parity over data byte |
| BUG-017 | MEDIUM | 2.6, 2.7 | bus_tx.sv uses bitwise `&` instead of `&&` (no functional impact for 1-bit operands) |
| BUG-018 | MEDIUM | 4.x read T-bit path | bus_rx_flow.sv rx_req_bit registration vs unregistered abort timing asymmetry |
| BUG-019 | LOW | 7.x (ENTDAA) | entdaa_fsm bit_cnt underflows to 63 when bit_cnt==0; benign in current FSM topology |
| BUG-020–022 | LOW | Style | Naming convention, wire keyword, hardcoded CCC constant; no functional test impact |

### Recommended Fix Priority Before Running Test Plan

1. **BUG-001** — Fix immediately (compile blocker).
2. **BUG-007** — Fix before running any Category 3 / 4 tests.
3. **BUG-002** — Fix before running any Category 5 / 6 CCC tests.
4. **BUG-004, BUG-005** — Fix before Category 8 I2C tests.
5. **BUG-003, BUG-006, BUG-010** — Fix before non-aligned reads and T-bit tests.
6. **BUG-008** — Fix before Category 13 sw_reset tests.

---

## 10. Future Verification Expansion

| Area | Suggestion |
|---|---|
| UVM Register Abstraction Layer | Replace custom `reg_agent` with a proper `uvm_reg_block` (RAL). Enables register access via `uvm_reg_sequence`; simplifies coverage and constraint-random stimulus. |
| Functional Coverage Closure | Implement the covergroups from Section 6 in a new `i3c_cov_pkg.sv`. Target 100% coverpoint hit and ≥90% cross-product coverage for Phase-1 features. |
| Formal Property Verification | Write SVA properties for: FSM no-deadlock (no unreachable dead states), FIFO overflow prevention, STOP always follows T-bit on last byte. Bind into RTL for formal proof. |
| Host-Mode UVC | Implement the `Host` mode driver path in `i3c_driver.sv` (currently gated off). Enables testing from a second-master stimulus perspective. |
| Additional Phase-2 CCCs | Add SETDASA, GETPID, GETBCR, GETDCR, SETMWL, SETMRL to `i3c_ccc_e` enum and implement directed-read CCC path in `flow_active`. |
| IBI/Hot-Join UVC | After RTL adds IBI support, add a target UVC that randomly asserts IBI. |
| Constrained-Random Test Generator | Write a `i3c_rand_vseq` that fully randomizes cmd_attr, dir, data_length, dev_idx, toc, ccc_code within legal constraints and runs 100k iterations with functional coverage feedback. |
| Waveform Regression | Automate `make regression DUMP_WAVES=1` and archive `.shm` files; tie to CI with a nightly regression budget. |
