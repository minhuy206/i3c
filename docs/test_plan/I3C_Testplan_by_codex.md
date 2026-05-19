# I3C Controller Verification Test Plan

## 1. Repository Architecture Summary

The repository implements a simplified MIPI I3C Basic active controller in SystemVerilog. The design scope is SDR/private transfer oriented with I2C legacy support and limited CCC/DAA support.

| Area | Implementation Summary |
|---|---|
| Top | `i3c_controller_top` integrates CSR, HCI queues, controller core, and PHY. External interfaces are a simple 32-bit register bus and SCL/SDA pins. |
| CSR / DAT | `csr_registers` implements `HC_CONTROL`, `HC_STATUS`, timing registers, CMD/TX/RX/RESP queue ports, `QUEUE_STATUS`, and 16-entry 32-bit DAT. |
| Queues | `hci_queues` wraps four `sync_fifo` instances: CMD 64-bit, TX/RX/RESP 32-bit. |
| Controller core | `controller_active` wires `flow_active`, `scl_generator`, `bus_monitor`, `bus_tx_flow`, `bus_rx_flow`, and `entdaa_controller`. |
| Main FSM | `flow_active` is the central 13-state command FSM for command fetch, DAT lookup, immediate/regular transfer, DAA dispatch, FIFO movement, and response generation. |
| PHY | `i3c_phy` provides 2FF input synchronization and direct SCL/SDA/OD-PP pass-through. |
| DAA | `entdaa_controller` + `entdaa_fsm` implement master-side ENTDAA rounds using pre-programmed DAT dynamic addresses. |
| UVM | `tb_i3c_top`, `reg_agent`, `i3c_agent` in device mode, virtual sequencer, scoreboard, and three current vseqs: `i3c_smoke_vseq`, `i3c_write_vseq`, `i3c_read_vseq`. |

Supported by repo intent and code: SDR private read/write, I2C legacy transfers, immediate transfers, regular transfers, ENTDAA, broadcast/direct ENEC and DISEC frame generation, register/DAT/FIFO access, response FIFO status.

Out of scope or not implemented: IBI, Hot-Join, HDR modes, multi-master, target mode, bus recovery, full HCI compliance, interrupt pins/IRQ controller, functional coverage collectors.

## 2. I2C Testplan Structure Summary

`docs/test_plan/I2C_Testplan.xlsx` has four sheets:

| Sheet | Structure / Style |
|---|---|
| `TestCase` | Columns: `Category`, `No`, `Test Item`, `Test Name`, `Description`, `Test flow`, `Pass Condition`, `Priority`. Category is filled on the first row of each group. Test names are concise lowercase names with feature prefixes. |
| `Coverage` | Simple coverpoint list followed by cross coverage list. |
| `Performance` | High-level performance metric guidance: latency, throughput, wait sensitivity, back-to-back efficiency, long-run stability. |
| `Performance test` | Columns: `Category`, `No`, `Test Name`, `Description`, `Main Metric`, using `P1...P25` IDs. |

The I3C plan below keeps the same concise testcase style and priority scheme, but replaces APB/I2C-bridge content with I3C controller, CSR, HCI queue, SDR, CCC, and DAA content.

## 3. Gaps, Assumptions, and Non-Applicable Features

| Item | Status |
|---|---|
| Compile readiness | `xrun` is not available on PATH in this environment, so simulation was not run. Static inspection found `i3c_monitor` calls `wait_for_device_ack_or_nack()`, but `i3c_if.sv` does not define it. |
| Existing tests | Only smoke, regular write, and regular read vseqs exist. No existing ENTDAA, CCC, I2C legacy, reset, error, stress, or coverage vseqs. |
| Functional coverage | Deferred in current specs; no covergroups found. |
| Assertions | Only one RTL SVA found: `bus_rx_flow` mutual exclusion for bit/byte receive requests. |
| Interrupts | No IRQ output or interrupt CSR exists. Verification is limited to `HC_STATUS`, `QUEUE_STATUS`, and RESP descriptors. |
| IBI / Hot-Join | Explicitly out of scope and no RTL/UVM support exists. No positive tests should be written until the feature is added. |
| Push-pull electrical modeling | `tb_i3c_top` leaves `sel_od_pp_o` unconnected and models DUT SCL/SDA as open-drain. OD/PP phase can be checked by signal observation, but not as true pad-level push-pull behavior. |
| DAA readback | RTL exposes `daa_pid/bcr/dcr` internally, but current public software-visible RX path appears to store assigned dynamic address bytes only. PID/BCR/DCR software readback needs specification or implementation. |
| Known RTL risk targets | Test plan intentionally covers known issues: immediate transfer clocking, I3C regular START generation, RX partial DWORD flush, same-cycle TX/RX dependencies, SW reset CMD staging, missing abort/timeout path, static I3C T-bit parity check. |

Global precondition for tests unless overridden: reset released, register bus active, controller enabled through `HC_CONTROL[0]`, DAT programmed for target type, and UVM device response sequence configured.

## 4. Testcase Matrix

| ID | Test Name | Objective / Preconditions | Stimulus / Actions | Expected / Pass Condition | Related Modules | Pri / Cov |
|---|---|---|---|---|---|---|
| CSR_001 | `csr_reset_defaults` | Verify reset defaults. | Assert/deassert `rst_ni`, read control/status/timing/DAT/queue status. | Registers match RTL reset values; queues empty; DAT zero. | `csr_registers`, `hci_queues` | High / `cp_csr_reset` |
| CSR_002 | `csr_enable_disable` | Verify controller enable behavior. | Toggle `HC_CONTROL[0]` with no command, then with queued command. | FSM enable follows CSR; no bus activity before enable. | `csr_registers`, `flow_active` | High / `cp_ctrl_enable` |
| CSR_003 | `csr_timing_rw` | Verify timing registers. | Write/read all timing CSRs with min/default/random legal values. | Readback matches; SCL timing changes accordingly in timing tests. | `csr_registers`, `scl_generator` | High / `cp_timing_regs` |
| CSR_004 | `csr_dat_rw_all_entries` | Verify 16-entry DAT. | Write static/dynamic/device fields for entries 0..15; read back. | DAT fields preserve bit layout `[31]`, `[22:16]`, `[6:0]`. | `csr_registers`, `controller_pkg` | High / `cp_dat_idx` |
| CSR_005 | `csr_cmd_queue_2dw_staging` | Verify CMD descriptor staging. | Write DWORD0 then DWORD1 to `ADDR_CMD_QUEUE`. | One 64-bit CMD FIFO entry is pushed as `{DWORD1,DWORD0}`. | `csr_registers`, `hci_queues` | High / `cp_cmd_staging` |
| CSR_006 | `csr_sw_reset_flush_queues` | Verify SW reset. | Fill CMD/TX/RX/RESP, write `HC_CONTROL[1]`. | FIFOs flush; `SW_RESET` self-clears; no stale queue data remains. | `csr_registers`, `hci_queues` | High / `cp_sw_reset` |
| CSR_007 | `csr_sw_reset_clears_cmd_staging` | Target known staging risk. | Write only CMD DWORD0, issue SW reset, then write a new full command. | New command is not paired with stale DWORD0. | `csr_registers` | High / `cp_reset_point` |
| CSR_008 | `csr_queue_status_flags` | Verify full/empty flags. | Drive each FIFO to empty/non-empty/full boundaries. | `QUEUE_STATUS` bits match FIFO state. | `hci_queues`, `sync_fifo` | High / `cp_fifo_state` |
| CSR_009 | `csr_rx_resp_read_pop` | Verify RX/RESP read ports. | Create RX/RESP entries, read `RX_DATA`/`RESP`; read empty ports. | Valid reads pop once; empty reads return zero/no pop. | `csr_registers`, `hci_queues` | Medium / `cp_port_pop` |
| CSR_010 | `csr_invalid_addr_no_side_effect` | Verify unmapped register behavior. | Read/write unmapped addresses. | Reads return zero; no queue/DAT/control side effects. | `csr_registers` | Medium / `cp_invalid_reg` |
| FIFO_001 | `fifo_basic_push_pop` | Verify FIFO primitive. | Push/pop single and multiple entries. | Ordering preserved; depth/full/empty correct. | `sync_fifo` | High / `cp_fifo_depth` |
| FIFO_002 | `fifo_simultaneous_rw` | Verify concurrent read/write. | Drive `wvalid` and `rready` together at middle/full/empty boundaries. | No data loss; depth updates correctly. | `sync_fifo` | Medium / `cp_fifo_rw_cross` |
| BUS_001 | `phy_sync_reset_pass` | Verify PHY sync and pass-through. | Toggle SCL/SDA inputs and ctrl outputs around reset. | Inputs reach controller after 2 clocks; outputs pass combinationally. | `i3c_phy` | Medium / `cp_phy_sync` |
| BUS_002 | `busmon_start_stop_rstart` | Verify bus condition detection. | Generate legal START, STOP, repeated START, simultaneous edge noise. | `start_det`, `rstart_det`, `stop_det` pulse only on legal conditions. | `bus_monitor` | High / `cp_bus_event` |
| BUS_003 | `scl_start_stop_timing` | Verify START/STOP timing. | Program timing regs; request START then STOP. | SDA/SCL sequence and `done_o` meet programmed counter values. | `scl_generator` | High / `cp_timing` |
| BUS_004 | `scl_clock_waitcmd_stall` | Verify clock generation and controller stall. | Generate clocks, pause `gen_clock_i`, then resume. | SCL holds low in `WaitCmd`; resumes without extra START/STOP. | `scl_generator`, `flow_active` | High / `cp_stall` |
| BUS_005 | `scl_rstart_from_waitcmd` | Target known RSTART gap. | Request repeated START while generator is in `WaitCmd`. | Sr is generated or issue is captured as failing gap. | `scl_generator` | Medium / `cp_rstart_state` |
| BUS_006 | `bus_tx_byte_bit_order` | Verify TX serialization. | Send byte `A5`, single ACK/T bits, OD and PP modes. | MSB-first bits, correct `bus_tx_done`, correct `sel_od_pp_o`. | `bus_tx`, `bus_tx_flow` | High / `cp_tx_bit_order` |
| BUS_007 | `bus_rx_byte_bit_order` | Verify RX sampling. | Drive byte `A5` and single-bit responses at SCL posedge. | MSB-first reconstruction; bit/byte mutual exclusion SVA passes. | `bus_rx_flow` | High / `cp_rx_bit_order` |
| BUS_008 | `od_pp_phase_switch` | Verify OD/PP control. | Run address, ACK, data, T-bit phases. | OD during address/ACK/DAA; PP during I3C SDR data where implemented. | `controller_active`, `flow_active` | High / `cp_odpp_phase` |
| SDR_001 | `i3c_smoke_imm_write_2b` | Baseline existing smoke. | Run `i3c_smoke_vseq`: immediate private write 2 bytes to DAT[0]. | Bus write observed; RESP `Success`. | Full DUT/UVM | High / `cp_existing_smoke` |
| SDR_002 | `i3c_imm_write_1_4b` | Immediate private writes. | Issue `ImmediateDataTransfer`, `cp=0`, `dtt=1..4`. | START, dynamic address+W, ACK, data+T, optional STOP; RESP length equals bytes. | `flow_active`, `bus_tx_flow` | High / `cp_imm_dtt` |
| SDR_003 | `i3c_imm_write_toc` | Verify terminate-on-completion. | Repeat immediate write with `toc=0` and `toc=1`. | STOP only when `toc=1`; no deadlock when `toc=0`. | `flow_active`, `scl_generator` | Medium / `cp_toc` |
| SDR_004 | `i3c_regular_write_4b` | Existing write regression. | Run `i3c_write_vseq`, TX word `DEAD_BEEF`. | Bus data bytes match little-endian TX FIFO order; RESP length 4. | Full DUT/UVM | High / `cp_reg_write` |
| SDR_005 | `i3c_regular_write_len_sweep` | Verify TX FIFO packing. | Regular writes of 1,2,3,4,5,8,16 bytes. | Correct byte order and word fetch count; no overrun. | `flow_active`, `hci_queues` | High / `cp_len_bins` |
| SDR_006 | `i3c_regular_write_tx_underflow` | Verify write stall. | Issue write length > available TX data, later provide TX data. | Controller stalls clock/flow until TX data available; completes without corruption. | `flow_active`, `scl_generator` | High / `cp_tx_empty_stall` |
| SDR_007 | `i3c_regular_read_4b` | Existing read regression. | Run `i3c_read_vseq`, target sends `CA FE BA BE`. | RX word equals `BEBA_FECA`; RESP length 4. | Full DUT/UVM | High / `cp_reg_read` |
| SDR_008 | `i3c_regular_read_partial_dword` | Target known partial RX risk. | Read 1,2,3,5,6,7 bytes. | All trailing bytes are available in RX FIFO; no data loss. | `flow_active`, `hci_queues` | High / `cp_rx_partial` |
| SDR_009 | `i3c_regular_read_rx_full` | Verify read stall. | Fill RX FIFO, issue read, then drain RX. | Controller stalls safely while RX full and resumes. | `flow_active`, `hci_queues` | High / `cp_rx_full_stall` |
| SDR_010 | `i3c_private_back_to_back` | Verify command sequencing. | Queue W-W, R-R, W-R, R-W with DAT[0]. | No stale state; each RESP TID/length correct. | `flow_active`, `hci_queues` | High / `cross_seq_type` |
| SDR_011 | `i3c_addr_nack_response` | Address error handling. | Target NACKs dynamic address. | Controller stops/recovers; RESP error is `AddrHeader`. | `flow_active`, `bus_rx_flow` | High / `cp_err_status` |
| SDR_012 | `i3c_read_tbit_parity_error` | Verify T-bit parity handling. | Target returns bad T-bit during read. | RESP reports `Parity`; controller recovers. | `flow_active` | High / `cp_parity_err` |
| I2C_001 | `i2c_legacy_imm_write` | Verify I2C DAT device path. | DAT `device=1`, immediate write to static address. | OD-only START, static address+W, ACK, data ACKs, STOP, RESP success. | `flow_active`, `bus_tx_flow` | High / `cp_i2c_imm` |
| I2C_002 | `i2c_legacy_regular_write` | Verify I2C write path. | Configure I2C timing, regular write 1/4/5 bytes. | Static address+W, OD data, ACK per byte, correct RESP. | `flow_active`, `scl_generator` | High / `cp_i2c_write` |
| I2C_003 | `i2c_legacy_regular_read` | Verify I2C read path. | Configure I2C timing, target sends 1/4/5 bytes. | Master ACKs intermediate bytes and NACKs final byte; RX data correct. | `flow_active`, `bus_rx_flow` | High / `cp_i2c_read` |
| I2C_004 | `i2c_legacy_data_nack` | Verify data NACK. | Target ACKs address then NACKs a write data byte. | RESP reports `Nack`; next transfer succeeds. | `flow_active` | High / `cp_data_nack` |
| I2C_005 | `i2c_legacy_timing_od_only` | Verify timing/mode. | Use 400 kHz-equivalent timing at TB clock; run read/write. | OD mode throughout; timing within programmed counters. | `scl_generator`, `i3c_phy` | Medium / `cp_i2c_timing` |
| CCC_001 | `ccc_bcast_enec` | Verify broadcast ENEC frame. | Immediate command `cp=1`, `cmd=0x00`, event byte as data. | `[S][7E+W][ACK][00][ACK][data][ACK][P]`; RESP success. | `flow_active` | High / `cp_ccc_enec` |
| CCC_002 | `ccc_bcast_disec` | Verify broadcast DISEC frame. | Immediate command `cp=1`, `cmd=0x01`. | Broadcast DISEC frame observed; no DAA engine activation. | `flow_active` | High / `cp_ccc_disec` |
| CCC_003 | `ccc_direct_enec` | Verify direct ENEC frame. | `cmd=0x80`, DAT dynamic address valid. | Broadcast header + CCC + Sr + target addr+W + data/T + STOP. | `flow_active`, `scl_generator` | High / `cp_ccc_direct` |
| CCC_004 | `ccc_direct_disec` | Verify direct DISEC frame. | `cmd=0x81`, target ACKs all phases. | Direct DISEC frame observed; RESP success. | `flow_active` | High / `cp_ccc_direct` |
| CCC_005 | `ccc_nack_broadcast_header` | Verify CCC address NACK handling. | Target NACKs `7E+W` for CCC. | Controller reports/recover behavior per spec; flag gap if not implemented. | `flow_active` | High / `cp_ccc_nack` |
| CCC_006 | `ccc_unsupported_opcode` | Define unsupported behavior. | Issue unsupported CCC opcode through immediate `cp=1`. | Expected behavior must be specified; current RTL likely sends opcode without validation. | `flow_active`, `i3c_pkg` | Medium / `cp_unsupported` |
| DAA_001 | `daa_entdaa_single_device` | Verify basic ENTDAA. | AddressAssignment command, one DAT dynamic address, target drives PID/BCR/DCR and ACKs address. | `[S][7E+W][07][Sr][7E+R]...`; assigned address parity correct; RESP success; RX/readback per implemented policy. | `flow_active`, `entdaa_controller`, `entdaa_fsm` | High / `cp_daa_single` |
| DAA_002 | `daa_entdaa_no_device` | Verify no-device exit. | Target NACKs `7E+R`. | DAA loop exits, STOP generated, no assigned-address RX entry. | `entdaa_fsm` | High / `cp_daa_no_dev` |
| DAA_003 | `daa_entdaa_multi_device` | Verify loop over `dev_count`. | Configure multiple DAT entries and multiple target responders. | Repeated START per round; DAT index increments; all expected addresses assigned. | `entdaa_controller` | High / `cp_daa_count` |
| DAA_004 | `daa_address_parity_ack_nack` | Verify assigned address byte. | Sweep dynamic addresses; target ACKs and NACKs assigned address. | Odd parity bit correct; ACK produces valid assignment; NACK reports no valid assignment/recovery. | `entdaa_fsm` | High / `cp_daa_parity` |
| DAA_005 | `daa_dat_index_boundary` | Verify DAT boundary handling. | Use `dev_idx` near 15 and `dev_count>1`. | Behavior matches RTL/spec decision; no out-of-range read corruption. | `entdaa_controller`, `csr_registers` | Medium / `cp_dat_boundary` |
| DAA_006 | `daa_pid_bcr_dcr_visibility` | Clarify PID/BCR/DCR handling. | Target drives nonzero PID/BCR/DCR. | Internal outputs match target; software-visible storage is verified or gap recorded. | `entdaa_fsm`, `flow_active` | Medium / `cp_daa_id` |
| DAA_007 | `daa_arbitration_two_targets` | Verify wired-AND arbitration if env supports it. | Two target models drive different PID bits and losing target stops participating. | Master assigns first arbitration winner, then next round assigns remaining target. | Bus/UVM agent, `entdaa_fsm` | Future-High / `cp_daa_arb` |
| ERR_001 | `resp_tid_length_mapping` | Verify response descriptor. | Run successful/failed commands with distinct TIDs and lengths. | RESP `[31:28]`, `[27:24]`, `[15:0]` match expected. | `flow_active`, `i3c_pkg` | High / `cp_resp_desc` |
| ERR_002 | `resp_fifo_full_stall` | Verify RESP backpressure. | Fill RESP FIFO, complete transfer, then drain. | FSM waits in `WriteResp`; no response lost. | `flow_active`, `hci_queues` | High / `cp_resp_full` |
| ERR_003 | `reset_during_transfer_phases` | Verify async reset recovery. | Reset during address, data TX, data RX, DAA, and WriteResp. | Bus released, queues/registers reset as defined, next legal transfer passes. | Full DUT | High / `cp_reset_point` |
| ERR_004 | `bus_stuck_or_abort_timeout` | Identify missing recovery. | Hold SCL/SDA preventing progress. | Current design has no timeout/`gen_idle` recovery; test documents hang/gap. | `scl_generator`, `flow_active` | High / `cp_abort_gap` |
| ERR_005 | `invalid_descriptor_attr_mode` | Verify unsupported descriptors. | Issue `ComboTransfer`, HDR modes, reserved modes. | Behavior must be specified; expect no illegal bus sequence or lockup. | `flow_active`, `i3c_pkg` | Medium / `cp_invalid_cmd` |
| ERR_006 | `queue_write_when_full_policy` | Verify full queue software policy. | Write CMD/TX when full. | Write is dropped or blocked exactly as RTL/spec states; status warns software. | `csr_registers`, `hci_queues` | Medium / `cp_queue_full` |
| STRESS_001 | `stress_random_private_rw` | Random SDR private transfers. | Random DAT entry, direction, length, data pattern, ACK/NACK injection. | No scoreboard mismatch, no timeout, all RESP legal. | Full DUT/UVM | High / crosses |
| STRESS_002 | `stress_ccc_daa_mix` | Mixed management traffic. | Random ENEC/DISEC/ENTDAA/private commands. | Correct frame ordering and recovery between command types. | Full DUT/UVM | High / `cross_ccc_daa` |
| STRESS_003 | `stress_fifo_boundaries` | Queue robustness. | Random fills/drains near empty/full while commands run. | No overflow/underflow data corruption. | `hci_queues`, `flow_active` | High / `cross_fifo_dir` |
| PERF_001 | `perf_sdr_rw_latency` | Measure SDR transfer latency. | Measure command write to RESP for 1/4/16/64-byte reads/writes. | Report min/avg/max latency and throughput. | Full DUT | Medium / metric |
| PERF_002 | `perf_i2c_legacy_latency` | Measure I2C path latency. | Run I2C write/read at configured 400 kHz-equivalent timing. | Report read/write latency; compare against programmed timing. | Full DUT | Medium / metric |
| PERF_003 | `perf_back_to_back_gap` | Measure inter-command efficiency. | Queue W-W, R-R, W-R, R-W. | Report idle gap between STOP/next START or no-STOP continuation. | `flow_active`, `scl_generator` | Medium / metric |
| PERF_004 | `perf_long_run` | Long-run stability. | 1k/10k constrained random transfers. | No hang, no memory/queue leak, stable latency distribution. | Full DUT/UVM | Medium / metric |

## 5. Feature to Test and Coverage Mapping

| Feature | Test IDs | Coverage Goals |
|---|---|---|
| CSR/control/status | `CSR_001..010` | Register reset/read/write, enable, status, invalid access. |
| HCI FIFOs | `FIFO_001..002`, `CSR_008..009`, `STRESS_003` | Empty/full/depth, simultaneous R/W, flush, queue status. |
| PHY/bus events | `BUS_001..008` | START/STOP/Sr, OD/PP, TX/RX bit order, timing bins. |
| SDR private write/read | `SDR_001..012` | Attr, RnW, length bins, data patterns, T-bit/parity, ACK/NACK. |
| I2C legacy | `I2C_001..005` | DAT device bit, static address, OD-only, ACK/NACK, 400 kHz timing config. |
| CCC ENEC/DISEC | `CCC_001..006` | Broadcast/direct, opcode, defining/data byte, ACK/NACK, unsupported opcode. |
| ENTDAA | `DAA_001..007` | Device count, DAT index, no-device, address parity, PID/BCR/DCR, arbitration. |
| Error handling | `ERR_001..006` | `Success`, `AddrHeader`, `Nack`, `Parity`, invalid descriptor, reset point. |
| Reset/recovery | `CSR_006..007`, `ERR_003` | Reset during idle/address/TX/RX/DAA/response. |
| Stress/performance | `STRESS_001..003`, `PERF_001..004` | Random crosses, latency, throughput, back-to-back gap, long-run stability. |

## 6. Coverage Model

Recommended coverpoints:

| Coverpoint | Bins |
|---|---|
| `cp_cmd_attr` | Regular, Immediate, AddressAssignment, Combo/unsupported |
| `cp_dir` | Write, Read |
| `cp_dat_device` | I3C target, I2C legacy |
| `cp_len` | 0,1,2,3,4,5-8,9-16,large, multiple-of-4, non-multiple-of-4 |
| `cp_ccc` | ENEC, DISEC, DIR_ENEC, DIR_DISEC, ENTDAA, unsupported |
| `cp_daa` | dev_count 0/1/2/max, no_device, addr_ack, addr_nack |
| `cp_fifo_state` | empty, non-empty, almost-full, full |
| `cp_resp_err` | Success, AddrHeader, Nack, Parity, NotSupported if implemented |
| `cp_bus_event` | START, repeated START, STOP, START-after-STOP |
| `cp_odpp` | OD address, OD ACK, PP data, DAA OD |
| `cp_reset_point` | idle, command fetch, address, data TX, data RX, DAA, response |
| `cp_data_pattern` | zero, all-one, alternating A/5, walking-one, random |

Recommended crosses: `cmd_attr x dir x dat_device`, `len x dir x rx_partial`, `ccc x broadcast/direct`, `daa_count x no_device`, `resp_err x phase`, `fifo_state x command_type`, `reset_point x command_type`, `timing_bin x mode`.

## 7. Regression Organization

| Regression | Contents |
|---|---|
| Smoke | `CSR_001`, `SDR_001`, `SDR_004`, `SDR_007`. |
| Basic nightly | All CSR/FIFO/BUS tests plus SDR/I2C basic transfer tests. |
| Protocol nightly | SDR, I2C, CCC, ENTDAA, ACK/NACK, parity, reset mid-transfer. |
| Stress weekly | Random private RW, CCC/DAA mix, FIFO boundary stress, long-run performance. |
| Coverage closure | Constrained-random plus directed holes from coverage model. |

## 8. Future Verification Expansion

1. Add missing `i3c_if.wait_for_device_ack_or_nack()` or update monitor calls before UVM compile.
2. Add functional coverage component and connect it to monitor/scoreboard analysis ports.
3. Add dedicated vseqs for I2C legacy, CCC, ENTDAA, reset, negative, and stress tests.
4. Improve bus model to verify true push-pull electrical behavior using `sel_od_pp_o`.
5. Add multi-target UVM support for ENTDAA arbitration.
6. Define unsupported descriptor/CCC behavior before checking `NotSupported`.
7. Add timeout/abort recovery specification before writing pass/fail checks for stuck-bus scenarios.
8. Add IBI and Hot-Join tests only after RTL/DV support is added.
