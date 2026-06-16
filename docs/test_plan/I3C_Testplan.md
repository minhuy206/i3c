# I3C Controller Verification Test Plan

## 1. Current Repository Architecture Summary

This repository implements a simplified MIPI I3C Basic active controller in SystemVerilog. The actual implemented scope is a single active controller with SDR private transfers, I2C legacy transfer paths, ENTDAA-based dynamic address assignment, a simple CSR bus, and FIFO-based command/data/response queues.

| Area | Current implementation |
|---|---|
| Top level | `src/rtl/i3c_controller_top.sv` integrates CSR, HCI queues, protocol controller, and PHY. External interfaces are a 32-bit register bus, SCL/SDA pins, SDA output-enable, and OD/PP mode select. |
| CSR and DAT | `csr_registers.sv` implements `HC_CONTROL`, `HC_STATUS`, timing registers, CMD/TX/RX/RESP queue ports, `QUEUE_STATUS`, and 32 32-bit DAT entries. DAT fields are `device`, `dynamic_address`, and `static_address`. |
| Queues | `hci_queues.sv` wraps four `sync_fifo` instances: CMD 64-bit, TX 32-bit, RX 32-bit, RESP 32-bit. Default RTL depth is 64; UVM top instantiates depth 8. |
| Controller wrapper | `controller_active.sv` connects `flow_active`, `scl_generator`, `bus_monitor`, `bus_tx_flow`, `bus_rx_flow`, and `entdaa_controller`. It multiplexes bus ownership between normal command flow and ENTDAA. |
| Main command FSM | `flow_active.sv` is the central command processor. It fetches CMD descriptors, reads DAT, drives immediate/regular transfer states, handles I2C legacy paths, starts ENTDAA, moves RX/TX FIFO data, and writes RESP descriptors. |
| Bus timing and conditions | `scl_generator.sv` generates START, repeated START, STOP, SCL low/high phases, and clock stalls. `bus_monitor.sv` detects START/STOP/Sr from synchronized bus inputs. |
| TX/RX datapath | `bus_tx_flow.sv` and `bus_tx.sv` serialize bytes/bits. `bus_rx_flow.sv` deserializes bytes/bits and includes an SVA preventing simultaneous bit and byte RX requests. |
| ENTDAA | `entdaa_controller.sv` manages the multi-device loop and DAT lookup. `entdaa_fsm.sv` sends `7'h7E+R`, receives PID/BCR/DCR bits, sends assigned address plus parity, and samples target ACK/NACK. |
| PHY | `i3c_phy.sv` provides 2-flop input synchronization and routes controller outputs to bus outputs with SDA output-enable and OD/PP select propagation. |
| UVM environment | `tb_i3c_top.sv`, `reg_agent`, `i3c_agent` in device mode, `i3c_env`, virtual sequencer, scoreboard, and three virtual sequences are implemented. `tb_i3c_top` now uses `sda_oe_o` for SDA pad drive/release and exposes DUT pad signals through `i3c_if`. |
| Current regression | `make regression` from `src/verification` runs `i3c_imm_vseq`, `i3c_write_vseq`, and `i3c_read_vseq`. With `source ~/EDA/cadence/xcelium/XCELIUM1803.sh`, these existing sequences pass with zero `UVM_ERROR`/`UVM_FATAL`. |

### 1.1 Implemented Feature Scope

| Feature | Status | Evidence / notes |
|---|---|---|
| I3C SDR private write | Implemented | `flow_active` regular write path, `i3c_write_vseq`. |
| I3C SDR private read | Implemented | `flow_active` regular read path, `i3c_read_vseq`. |
| Immediate data transfer | Implemented for write-style immediate commands | `I3CWriteImmediate` and `I2CWriteImmediate` states. |
| I2C legacy read/write paths | Implemented in RTL, not yet covered by existing vseqs | DAT `device=1` selects static address and OD behavior. |
| Dynamic Address Assignment | RTL implemented; not yet covered by existing vseqs | `AddressAssignment` descriptor drives ENTDAA. |
| CCC ENTDAA | Implemented through `AddressAssignment` flow | Broadcast header and ENTDAA code are sent by `flow_active`; rounds are handled by `entdaa_controller`. |
| CCC ENEC/DISEC | Limited frame generation in immediate command path | No event state exists because IBI/Hot-Join are out of scope. Opcode validation is limited/underspecified. |
| Status and response reporting | Implemented | `HC_STATUS`, `QUEUE_STATUS`, RESP descriptor fields. No IRQ output exists. |
| Functional coverage | Not implemented | No covergroups found in current UVM sources. |
| Assertions/checkers | Minimal | One RTL SVA in `bus_rx_flow`; UVM scoreboard checks basic RESP, address, direction, and write data. |

### 1.2 Explicitly Missing or Out of Scope

| Feature / behavior | Repository status | Test-plan handling |
|---|---|---|
| IBI | Not implemented; no IBI queue, event arbitration, or IRQ output | No positive tests. Listed as future expansion only. |
| Hot-Join | Not implemented | No positive tests. Listed as future expansion only. |
| HDR-DDR / HDR-TSL / HDR-TSP | Not implemented; enum values exist but no HDR datapath | Negative descriptor tests should ensure no lockup or document undefined behavior. |
| Multi-master / secondary controller | Not implemented | No positive tests. |
| Target/slave mode | Not implemented in DUT | UVM I3C agent models a device only as a responder. |
| Full HCI compliance | Not implemented | Verify only the simplified CSR/FIFO interface. |
| Bus recovery / timeout | Not implemented as a complete protocol feature | Negative tests should identify hangs or required future recovery. |
| Interrupt controller / IRQ pin | Not implemented | Verify status and RESP only; IRQ tests are N/A. |
| Functional coverage collectors | Not implemented | Coverage plan below is a required implementation roadmap. |

## 2. Reference I2C Test Plan Structure Summary

The reference `docs/test_plan/I2C_Testplan.xlsx` uses a compact spreadsheet style with four sheets:

| Sheet | Structure and style |
|---|---|
| `TestCase` | Columns are `Category`, `No`, `Test Item`, `Test Name`, `Description`, `Test flow`, `Pass Condition`, and `Priority`. Test names are lowercase with feature prefixes. Category is filled once per group. |
| `Coverage` | A simple coverpoint list followed by cross-coverage rows. Coverpoint names use `cp_*`; crosses use `feature x feature`. |
| `Performance` | High-level metric guidance for transaction latency, throughput, wait-state sensitivity, back-to-back efficiency, and long-run stability. |
| `Performance test` | Performance test matrix with `P1`, `P2`, ... IDs, description, and main metric. |

This I3C plan keeps the same practical testcase style and priority scheme, but removes non-applicable APB bridge and multi-speed I2C content. It replaces them with I3C SDR, CCC, ENTDAA, DAT, FIFO, response/status, UVM environment, and protocol timing content that exists in this repository.

## 3. Verification Strategy

### 3.1 Verification Oracle

The purpose of these tests is to verify that the RTL conforms to the applicable specifications, not to make the testbench reproduce whatever the RTL currently does. Expected results must be derived from this order of authority:

1. MIPI I3C Basic v1.1.1 behavior for bus protocol, SDR transfers, CCC, ENTDAA, T-bit, ACK/NACK, START/Sr/STOP, OD/PP, and I2C compatibility.
2. Project scope and interface contracts in `docs/phase1_spec_v2.md`, `docs/module_specs/`, and `docs/verification_specs/` for the simplified controller, CSR map, command descriptor format, DAT layout, queue semantics, and supported feature subset.
3. The testcase's own programmed stimulus for data values, TID, length, and timing register values.

Current RTL behavior may be used to classify a feature as implemented, missing, or requiring clarification, but it must not be used as the pass/fail oracle. If RTL behavior differs from the spec, the test should fail or the gap should be recorded as a spec/RTL issue. If the project spec is missing or ambiguous, the testcase must be marked as a clarification/negative test and must not be counted as positive sign-off coverage until the expected behavior is specified.

### 3.2 Priorities

| Priority | Meaning |
|---|---|
| High | Required for minimum sign-off of the implemented feature scope against the spec. Failures block release. |
| Medium | Important robustness, corner, or stress coverage. Failures require triage but may be deferred with documented risk. |
| Low | Informational, performance, or future-facing coverage. |
| Future | Applies only after RTL or UVM support is added. It must not be counted as current pass/fail coverage. |

### 3.3 Global Preconditions

Unless a testcase states otherwise:

- Reset is released through `rst_ni`.
- The register bus agent is active.
- `HC_CONTROL[0]` is written to enable the controller.
- Timing registers use documented CSR reset defaults or testcase-specific values.
- DAT entries are explicitly programmed before issuing CMD descriptors.
- Device responses are driven through `i3c_device_response_seq` or a derived sequence.
- Completion is observed by polling `HC_STATUS[FSM_IDLE]` and reading `RESP_PORT`.

### 3.4 Existing UVM Regression

| Sequence | Current purpose | Coverage gap |
|---|---|---|
| `i3c_imm_vseq` | Immediate I3C write of two inline bytes | Single device, success path only. |
| `i3c_write_vseq` | I3C regular write of four bytes from TX FIFO | No length sweep, NACK, stall, or I2C path. |
| `i3c_read_vseq` | I3C regular read of four bytes into RX FIFO | No partial DWORD, short read, RX full, or I2C path. |

## 4. Complete Testcase Plan

### 4.1 CSR, DAT, and Register Bus

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| CSR_001 | `csr_reset_defaults` | Verify reset-visible register defaults. | Reset applied and released. | Read `HC_CONTROL`, `HC_STATUS`, all timing registers, `QUEUE_STATUS`, and DAT[0..31]. | Enable is 0; FSM idle/status reflects idle; queue flags show empty; DAT entries are 0; timing defaults match the CSR/module specification. | `csr_registers`, reg bus | High | `cp_reset`, `cp_csr_addr` |
| CSR_002 | `csr_enable_disable` | Verify controller enable gating. | CMD FIFO empty. | Toggle `HC_CONTROL[0]`; queue a command while disabled and then enable. | No bus transaction before enable; command starts after enable; status returns idle after completion. | `csr_registers`, `flow_active` | High | `cp_enable`, `cp_cmd_start` |
| CSR_003 | `csr_broadcast_header_control` | Verify broadcast-header control bit read/write behavior and both private-transfer bus-framing modes. | Controller idle and CMD FIFO empty; DAT[0] is I3C dynamic address `0x08`; device ACKs target address and, when enabled, broadcast header. | Read `HC_CONTROL[BROADCAST_ADDR_ENABLE]` after reset; set and clear the bit through `HC_CONTROL`; set only this bit without `HC_CONTROL[0]`; then issue one 4-byte SDR private write with `BROADCAST_ADDR_ENABLE=0` and one with `BROADCAST_ADDR_ENABLE=1`. | Reset value is 0; writable set/clear behavior is correct; setting `BROADCAST_ADDR_ENABLE` alone does not enable the controller and does not start a bus transaction; disabled write starts directly with `START + 0x08/W`; enabled write emits `START + 0x7e/W + ACK + Sr + 0x08/W + ACK + data/T-bit + STOP`; both RESPs report success with matching lengths. | `csr_registers`, `flow_active`, `scl_generator`, UVM scoreboard | High | `cp_broadcast_addr_enable`, `cp_enable`, `cp_private_start_prefix`, `cp_first_address` |
| CSR_004 | `csr_timing_rw` | Verify timing register read/write behavior. | Controller idle. | Write/read all I3C timing CSRs `T_R` through `T_BUS_FREE` and all I2C timing CSRs `I2C_T_R` through `I2C_T_BUF` using default, zero, minimum nonzero, maximum 20-bit, random legal, and reserved-upper-bit values. | Readback matches written `[19:0]` values; reserved upper bits read 0; writes to one timing CSR do not alter other timing CSRs. | `csr_registers`, reg bus | High | `cp_timing_reg`, `cp_timing_value`, `cr_timing_reg_value` |
| CSR_005 | `csr_dat_rw_all_entries` | Verify all DAT entries and field packing. | Controller idle. | Write DAT[0..31] with varied static address, dynamic address, and `device` bit; read back. | DAT bit fields match `[31]`, `[22:16]`, and `[6:0]`; no adjacent entry corruption. | `csr_registers`, `controller_pkg::dat_entry_t` | High | `cp_dat_idx`, `cp_device_type` |
| CSR_006 | `csr_cmd_queue_2dw_staging` | Verify 64-bit CMD staging from two 32-bit writes. | CMD FIFO not full. | Write DWORD0 then DWORD1 to `CMD_QUEUE_PORT`. | One CMD FIFO entry is pushed as `{DWORD1,DWORD0}`; no push after only DWORD0. | `csr_registers`, `hci_queues` | High | `cp_cmd_staging` |
| CSR_007 | `csr_cmd_partial_then_other_write` | Verify partial CMD staging is not disturbed by unrelated CSR writes. | CMD FIFO not full. | Write CMD DWORD0, write timing/DAT/TX registers, then write CMD DWORD1. | Final CMD is assembled from the original DWORD0 and final DWORD1 only. | `csr_registers` | Medium | `cp_cmd_staging`, `cp_csr_interleave` |
| CSR_008 | `csr_sw_reset_flush_queues` | Verify software reset flushes queues. | Queues contain at least one entry where possible. | Poll idle, write `HC_CONTROL[1]=1`, then read queue status and ports. | CMD/TX/RX/RESP queues are empty; `SW_RESET` self-clears. | `csr_registers`, `hci_queues` | High | `cp_sw_reset`, `cp_fifo_state` |
| CSR_009 | `csr_sw_reset_clears_cmd_staging` | Verify stale DWORD0 cannot corrupt a later command. | Controller idle. | Write one CMD DWORD0, assert SW reset, then write a complete different command. | Only the post-reset command executes; no stale descriptor fields appear. | `csr_registers` | High | `cp_sw_reset`, `cp_cmd_staging` |
| CSR_010 | `csr_queue_status_flags` | Verify full/empty status bits. | Controller idle or block-level FIFO access. | Fill and drain CMD, TX, RX, and RESP queues to empty/non-empty/full points. | `QUEUE_STATUS` bits match actual FIFO state. | `csr_registers`, `hci_queues`, `sync_fifo` | High | `cp_fifo_kind`, `cp_fifo_state` |
| CSR_011 | `csr_rx_resp_read_pop` | Verify RX/RESP port pop behavior. | RX/RESP entries exist. | Read `RX_DATA_PORT` and `RESP_PORT`; read again after empty. | Valid reads pop one entry; empty reads return 0 and do not underflow. | `csr_registers`, `hci_queues` | High | `cp_port_pop`, `cp_empty_read` |
| CSR_012 | `csr_unmapped_addr_no_side_effect` | Verify unmapped address behavior. | Snapshot relevant CSRs and queues. | Read/write unmapped aligned addresses. | Reads return 0; no DAT, timing, control, or queue side effects occur. | `csr_registers`, reg bus | Medium | `cp_invalid_reg_addr` |
| CSR_013 | `csr_hc_abort_control` | Verify `HC_CONTROL[3]` (HC abort) read/write and level-bit persistence. | Controller idle and CMD FIFO empty. | Read `HC_CONTROL[3]` after reset; set and clear the bit through `HC_CONTROL`; set only this bit without `HC_CONTROL[0]`; hold it set across several read cycles and a queued command. | Reset value is 0; writable set/clear behavior is correct; the bit is never auto-cleared by hardware and holds its written value until software clears it; setting it alone does not enable the controller. The abort effect on an active transfer and its response encoding are covered by `SDRW_009`, `SDRR_009`, and `ERR_012`. | `csr_registers`, reg bus | High | `cp_hc_abort`, `cp_csr_addr` |

### 4.2 FIFO and Queue Behavior

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| FIFO_001 | `fifo_basic_push_pop_order` | Verify FIFO ordering. | FIFO reset. | Push known sequence, pop all entries. | Data order is preserved; empty/full/depth are correct. | `sync_fifo` | High | `cp_fifo_depth`, `cp_fifo_data_pattern` |
| FIFO_002 | `fifo_full_empty_boundaries` | Verify boundary flags. | FIFO reset. | Fill exactly to depth, attempt one extra write, drain to empty, attempt extra read. | Full blocks extra write; empty blocks extra read; no pointer corruption. | `sync_fifo`, `hci_queues` | High | `cp_fifo_boundary` |
| FIFO_003 | `fifo_simultaneous_read_write` | Verify concurrent handshake. | FIFO partially filled. | Assert write valid and read ready in the same cycle across mid, near-full, and near-empty states. | Data is neither lost nor duplicated; depth updates correctly. | `sync_fifo` | Medium | `cross_fifo_state_x_rw` |
| FIFO_004 | `fifo_flush_during_activity` | Verify synchronous flush. | FIFO contains data and traffic is active. | Assert `flush_i` while read/write requests are present. | Pointers clear; subsequent traffic starts from empty; no stale valid entry is exposed. | `sync_fifo`, `hci_queues` | High | `cp_fifo_flush` |
| FIFO_005 | `fifo_non_power_of_two_elaboration` | Verify documented depth restriction. | Block-level elaboration. | Instantiate `sync_fifo` with non-power-of-two depth in a negative compile test. | Elaboration fails with the documented parameter-check fatal/assertion required by the FIFO contract. | `sync_fifo` | Low | `cp_param_illegal` |

### 4.3 PHY, Bus Conditions, and Timing

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| BUS_001 | `phy_reset_and_sync` | Verify PHY reset and 2FF synchronization. | Block-level PHY or top-level observation. | Toggle SCL/SDA inputs around reset. | Controller-side sampled inputs settle after synchronizer latency; reset values are high. | `i3c_phy` | Medium | `cp_phy_sync` |
| BUS_002 | `bus_start_stop_detect` | Verify START and STOP detection. | Bus monitor enabled. | Drive SDA falling/rising while SCL high with legal timing. | `start_det` and `stop_det` pulse only for legal conditions. | `bus_monitor`, `edge_detector`, `stable_high_detector` | High | `cp_bus_event` |
| BUS_003 | `bus_repeated_start_detect` | Verify repeated START detection. | A START has occurred without STOP. | Generate Sr before STOP. | `rstart_det` pulses; normal `start_det` is not confused with Sr. | `bus_monitor`, `scl_generator` | High | `cp_bus_event` |
| BUS_004 | `scl_start_stop_timing` | Verify generated START/STOP timing. | Timing CSRs programmed. | Request START and STOP through normal command flow or block-level control. | SDA/SCL sequence matches START/STOP definitions and programmed counter delays. | `scl_generator` | High | `cp_timing`, `cp_bus_event` |
| BUS_005 | `scl_clock_low_high_timing` | Verify SCL low/high periods. | Timing CSRs programmed to multiple values. | Run I3C SDR and I2C legacy transfers. | Measured low/high periods track `t_low`, `t_high`, `t_r`, and `t_f`. | `scl_generator`, `csr_registers` | High | `cp_timing_mode`, `cp_timing_value` |
| BUS_006 | `scl_waitcmd_stall_resume` | Verify clock stall behavior while waiting for commands or legal backpressure conditions. | Controller is idle or in a supported wait condition. | Hold the relevant wait condition, then release it. | SCL behavior remains legal and traffic resumes or terminates without data corruption. | `flow_active`, `scl_generator` | High | `cp_wait_state` |
| BUS_007 | `scl_repeated_start_from_waitcmd` | Verify repeated START while clock is held low. | ENTDAA or directed CCC flow active. | Request repeated START while generator is in low/wait state. | Sr is generated with legal timing; no bus hang. | `scl_generator`, `controller_active` | High | `cp_rstart_state` |
| BUS_008 | `bus_tx_byte_and_bit_order` | Verify TX serialization. | Block-level or top-level bus observation. | Send byte patterns `00`, `FF`, `A5`, `5A` and single-bit requests. | Bits are MSB-first; `bus_tx_done_o` pulses once per request; SDA setup/hold is respected. | `bus_tx`, `bus_tx_flow` | High | `cp_tx_pattern`, `cp_tx_req_type` |
| BUS_009 | `bus_rx_byte_and_bit_order` | Verify RX deserialization. | Block-level or device model drives SDA. | Receive byte patterns and ACK/NACK bits. | Data is reconstructed MSB-first; single-bit reads use bit[0]; mutual exclusion SVA passes. | `bus_rx_flow` | High | `cp_rx_pattern`, `cp_rx_req_type` |
| BUS_010 | `od_pp_phase_switch` | Verify OD/PP select by phase. | I3C write/read transfer. | Observe `sel_od_pp_o` through address, ACK, data, T-bit, START/STOP. | OD is used for START/address/ACK/STOP and ENTDAA; PP is used only for in-scope MIPI I3C SDR data phases. | `controller_active`, `flow_active`, `i3c_phy` | High | `cp_odpp_phase` |
| BUS_011 | `tb_pad_model_odpp_wiring` | Verify enhanced TB pad-model wiring for SDA drive/release and OD/PP visibility. | Top-level UVM TB with `sda_oe_o` and `sel_od_pp_o` connected. | Observe `sda_oe_o`, `sda_o`, `sel_od_pp_o`, and `sda_bus` during existing I3C write/read traffic; later extend with a dedicated OD/PP pad vseq. | `tb_i3c_top` drives SDA only when `sda_oe_o=1`, releases SDA when `sda_oe_o=0`, and exposes DUT pad signals through `i3c_if`; existing smoke/write/read regressions show no SDA contention. Dedicated phase-level PP checks remain future work. | `tb_i3c_top`, `i3c_if`, `i3c_phy`, `i3c_controller_top` | Medium | `cp_pad_model`, `cp_sda_oe`, `cp_tb_odpp_visibility` |

### 4.4 I3C SDR Private Write

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| SDRW_001 | `i3c_regular_write_4b_existing` | Verify baseline 4-byte SDR private write without broadcast-header preamble. | DAT[0] is I3C dynamic address `0x08`; `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0`; device ACKs. | Run `i3c_write_vseq` with TX word `DEAD_BEEF`. | Bus write starts with `START + 0x08/W + ACK`; no `0x7e` preamble is emitted; data byte order follows the project TX FIFO packing contract; RESP success length 4. | Full DUT, UVM scoreboard | High | `cp_cmd_attr`, `cp_dir`, `cp_len_4`, `cp_private_start_prefix` |
| SDRW_002 | `i3c_regular_write_len_sweep` | Verify write lengths, TX packing, zero-length behavior, large payloads, and broadcast-header private-write framing. | DAT[0] is I3C dynamic address `0x08`; device ACKs address and write data; run once with `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0` and once with it set. | Write lengths 0,1,2,3,4,5,7,8,16,64,256 using patterned TX words in both private-address modes. | Exact byte count transmitted; correct byte order and T-bit parity; RESP length equals bytes transferred. Length 0 ACKs address then STOPs with no data/T-bit and success length 0. Length 256 consumes 64 TX DWORDs in order and leaves queues empty. Disabled mode starts directly with `START + 0x08/W`; enabled mode emits `START + 0x7e/W + ACK + Sr + 0x08/W` before data. | `flow_active`, `hci_queues`, `bus_tx_flow`, UVM scoreboard | High | `cp_data_len`, `cp_len_zero`, `cp_len_large`, `cp_tx_word_boundary`, `cp_private_start_prefix` |
| SDRW_003 | `i3c_regular_write_data_patterns` | Verify data integrity over patterns. | Device ACKs all phases. | Send all-zero, all-one, walking-one, alternating, and random data. | Device monitor/scoreboard observes exact expected bytes and generated T-bits. | `bus_tx_flow`, `i3c_monitor`, scoreboard | Medium | `cp_data_pattern` |
| SDRW_004 | `i3c_write_tbit_parity_generation` | Verify SDR write T-bit generation. | I3C device target; bus monitor can sample T-bit. | Send data bytes with even and odd parity. | T-bit makes the 8-bit data byte plus T-bit odd parity, equivalent to `~^data_byte`, for every write byte. | `flow_active`, `bus_tx_flow` | High | `cp_tbit_write_parity` |
| SDRW_005 | `i3c_write_tx_fifo_underflow_ovl` | Verify TX underflow flow handling. | Write length exceeds available TX FIFO data or TX FIFO is empty at transfer start. | Issue an 8-byte write with only one TX DWORD available; issue 4-byte and 8-byte writes with no TX data; run both `toc=1` and `toc=0` in both private-address modes. Also write a late TX DWORD after an aborted underflow. | Controller transfers only available bytes, never transmits garbage, does not enter old `StallWrite`, and generates STOP. For `toc=0`, underflow still terminates with STOP and must not create a Repeated START/continuation. Late refill remains in TX FIFO until SW reset flushes queues. Response descriptor encoding is checked by `ERR_005`. | `flow_active`, `hci_queues`, `scl_generator` | High | `cp_tx_empty`, `cp_tx_late_refill` |
| SDRW_006 | `i3c_write_toc_zero` | Verify SDR regular write continuation when `toc=0`, including broadcast-header-enabled private continuation framing and missing-continuation policy. | I3C device ACKs; valid-continuation subcase has a second SDR regular I3C command already queued; run once with `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0` and once with it set. | Queue first write with `toc=0` and second write with `toc=1`; separately issue a `toc=0` write with no next supported command. | Valid case: first write completes data/T-bit then emits `Sr` instead of STOP; second command starts after `Sr`; final STOP occurs only after the `toc=1` command; both RESPs report success with matching TID/length. With broadcast-header enabled, only the first private transfer emits the `0x7e` preamble. Negative case: the first write data is transmitted, controller emits STOP instead of RSTART, and RESP is `NotSupported` with actual length transmitted. | `flow_active`, `scl_generator`, UVM scoreboard | Medium | `cp_broadcast_addr_enable`, `cp_toc`, `cp_rstart_continuation`, `cp_private_start_prefix`, `cp_unsupported_policy` |
| SDRW_007 | `i3c_write_back_to_back` | Verify write-to-write sequencing. | Multiple TX data words and commands queued. | Queue several write commands with unique TIDs and data. | Commands execute FIFO order; each RESP TID/length matches; no stale TX data. | `hci_queues`, `flow_active`, scoreboard | High | `cp_sequence_type`, `cross_tid_x_order` |
| SDRW_008 | `i3c_write_multi_dat_idx` | Verify SDR private write DAT index selection. | DAT[0] is I3C dynamic address `0x08`; DAT[1] is I3C dynamic address `0x12`; both targets ACK; `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0`. | Queue a write to `dev_idx=0` and a write to `dev_idx=1` with distinct TIDs and payloads. | Bus addresses are observed in order as `0x08/W` then `0x12/W`; each payload and generated T-bit sequence matches its TX FIFO data; RESP success TID/length fields match each command; queues empty afterward. Broadcast-header DAT[1] coverage is left as a future extension; broadcast-header framing is covered elsewhere with DAT[0]. | `csr_registers`, `flow_active`, `hci_queues`, UVM scoreboard | High | `cp_dat_idx`, `cross_dat_idx_x_tid` |
| SDRW_009 | `i3c_write_abort` | Verify HC abort during the SDR private write data phase. | DAT[0] is I3C dynamic address `0x08`; device ACKs address and data; a multi-byte write is in progress in the data phase (`abort_stop_required` true); run once with `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0` and once with it set. | Assert `HC_CONTROL[3]` (HC abort) while the FSM is in the write data phase. | Every byte already committed up to the abort point is transmitted on the bus with the correct T-bit and no garbage or extra byte; the in-flight byte plus its T-bit boundary completes, then STOP is generated and the FSM advances to `WriteResp`. This case checks only byte completeness and STOP-at-correct-state; response status/length correctness and all non-data-phase abort entry states are covered by `ERR_012`. | `flow_active`, `scl_generator`, `bus_tx_flow`, UVM scoreboard | High | `cp_hc_abort`, `cp_abort_stop_state`, `cp_private_start_prefix` |

Directed SDRW length coverage intentionally stops at 256 bytes. Full 65535-byte regular writes are documented as future stress/performance coverage because they make directed regressions materially longer without adding a new packing boundary beyond the 64-DWORD 256-byte case.

### 4.5 I3C SDR Private Read

All SDRR virtual sequences run each directed scenario in both private-address modes: once with `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0` and once with it set. Disabled mode starts directly with the dynamic address; enabled mode emits the private broadcast-header preamble before the dynamic-address read unless the test explicitly covers a continuation where the preamble must not repeat.

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| SDRR_001 | `i3c_regular_read_4b_existing` | Verify baseline 4-byte SDR private read in both private-address modes. | DAT[0] is I3C dynamic address `0x08`; target returns four bytes; run once with `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0` and once with it set. | Run `i3c_read_vseq`. | Disabled mode starts with `START + 0x08/R + ACK` and emits no `0x7e` preamble. Enabled mode emits `START + 0x7e/W + ACK + Sr + 0x08/R + ACK` before read data. In both modes, RX FIFO word matches the target bytes packed by the project RX FIFO contract, e.g. `32'hBEBA_FECA` for the existing stimulus; RESP success length 4. | Full DUT, UVM scoreboard | High | `cp_cmd_attr`, `cp_dir`, `cp_len_4`, `cp_private_start_prefix` |
| SDRR_002 | `i3c_regular_read_len_sweep` | Verify read lengths and RX packing in both private-address modes. | DAT[0] is I3C dynamic address `0x08`; device returns enough bytes. | Run `i3c_read_len_sweep_vseq` with lengths 1,2,3,4,5,7,8,16. | Each mode uses the expected private-address prefix; RX FIFO contains all bytes in little-endian DWORD packing; partial final DWORD is preserved; RESP success length matches the requested length. | `flow_active`, `hci_queues`, UVM scoreboard | High | `cp_data_len`, `cp_rx_partial_dword`, `cp_private_start_prefix` |
| SDRR_003 | `i3c_read_short_target_end` | Verify target early end handling in both private-address modes. | DAT[0] is I3C dynamic address `0x08`; target returns T-bit end before requested length. | Run `i3c_read_short_target_end_vseq` with requested length N and actual target length M<N. | Each mode uses the expected private-address prefix; controller does not read fake data after target early end; RX FIFO contains only transferred bytes; queues are cleaned up after the response is drained. Response descriptor encoding is checked by `ERR_004`. | `flow_active`, `bus_rx_flow`, RESP FIFO, UVM scoreboard | High | `cp_short_read`, `cp_private_start_prefix` |
| SDRR_004 | `i3c_read_target_more_than_requested` | Verify controller termination at requested length in both private-address modes. | DAT[0] is I3C dynamic address `0x08`; target can provide more bytes than requested. | Run `i3c_read_target_more_than_requested_vseq` with target data longer than the command length. | Each mode uses the expected private-address prefix; controller takes over after the requested byte count, stores no extra RX bytes, and reports RESP success with the requested length. | `flow_active`, `scl_generator`, UVM scoreboard | High | `cp_read_end_policy`, `cp_private_start_prefix` |
| SDRR_005 | `i3c_read_rx_fifo_full_overflow` | Verify RX FIFO full overflow flow handling in both private-address modes. | DAT[0] is I3C dynamic address `0x08`; RX FIFO is prefilled full before read data flush. | Run `i3c_read_rx_fifo_full_overflow_vseq`. | Each mode uses the expected private-address prefix; controller takes over the read before forced STOP, preserves prefilled RX FIFO words, and leaves queues empty after drain. Response descriptor encoding is checked by `ERR_005`. | `flow_active`, `hci_queues`, `scl_generator`, UVM scoreboard | High | `cp_rx_full`, `cp_stall_type`, `cp_private_start_prefix` |
| SDRR_006 | `i3c_read_data_patterns` | Verify read data integrity in both private-address modes. | DAT[0] is I3C dynamic address `0x08`; device sequence can drive arbitrary data. | Run `i3c_read_data_patterns_vseq` with all-zero, all-one, walking-one, alternating, and fixed-random patterns. | Each mode uses the expected private-address prefix; RX FIFO contents match target data exactly; RESP success length matches pattern length. | `i3c_driver`, `bus_rx_flow`, UVM scoreboard | Medium | `cp_data_pattern`, `cp_private_start_prefix` |
| SDRR_007 | `i3c_read_no_parity_error_on_end_tbit` | Verify read T-bit end semantics in both private-address modes. | DAT[0] is I3C dynamic address `0x08`; target ends transfer with T-bit=0 at the requested length. | Run `i3c_read_no_parity_error_on_end_tbit_vseq`. | Each mode uses the expected private-address prefix; T-bit=0 is treated as end-of-data, no extra RX byte is consumed, and queues drain cleanly. Detailed RESP field classification for this same legal end condition is covered by `ERR_013`. | `flow_active`, `bus_rx_flow`, UVM scoreboard | High | `cp_read_tbit`, `cp_private_start_prefix` |
| SDRR_008 | `i3c_read_toc_zero` | Verify SDR regular read continuation when `toc=0` in both private-address modes. | DAT[0] is I3C dynamic address `0x08`; I3C device returns requested read data; a second SDR regular I3C write command is already queued. | Run `i3c_read_toc_zero_vseq`: queue first read with `toc=0` and second write with `toc=1`. | Disabled mode starts the first read directly with dynamic address; enabled mode emits the broadcast-header preamble only before the first private read. In both modes, the first read ends with `Sr`, the continuation does not repeat the preamble, final STOP occurs only after the second command, and RX data plus both RESPs match expected length/TID. | `flow_active`, `scl_generator`, `bus_rx_flow`, UVM scoreboard | Medium | `cp_broadcast_addr_enable`, `cp_toc`, `cp_rstart_continuation`, `cp_dir_read_to_write`, `cp_private_start_prefix` |
| SDRR_009 | `i3c_read_abort` | Verify HC abort during the SDR private read data phase. | DAT[0] is I3C dynamic address `0x08`; target returns read data; a multi-byte read is in progress in the data phase (`abort_stop_required` true); run once with `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0` and once with it set. | Assert `HC_CONTROL[3]` (HC abort) while the FSM is in the read data phase. | Bytes already received up to the abort point are stored in the RX FIFO with correct packing and no fake bytes are read after abort; the controller completes the current byte boundary, then STOP is generated and the FSM advances to `WriteResp`. This case checks only byte completeness and STOP-at-correct-state; response status/length correctness and all non-data-phase abort entry states are covered by `ERR_012`. | `flow_active`, `scl_generator`, `bus_rx_flow`, UVM scoreboard | High | `cp_hc_abort`, `cp_abort_stop_state`, `cp_private_start_prefix` |

### 4.6 Immediate Data Transfer

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| IMM_001 | `i3c_immediate_write_smoke_existing` | Verify baseline immediate write descriptor flow. | DAT[0] I3C device; target ACKs. | Run `i3c_imm_vseq`. | Two inline data bytes are transmitted according to descriptor `dtt` and project packing rules; RESP success. | `flow_active`, `bus_tx_flow`, UVM | High | `cp_imm`, `cp_len_2` |
| IMM_002 | `i3c_immediate_write_dtt_sweep` | Verify inline data byte count. | DAT[0] I3C device. | Issue immediate commands with `dtt` values covering 0..4 valid bytes. | Correct number of inline bytes are transmitted; no TX FIFO access occurs. | `flow_active`, CMD descriptor | High | `cp_imm_dtt` |
| IMM_003 | `i3c_immediate_write_toc` | Verify immediate `toc` policy. | Target ACKs; immediate `toc=0` continuation policy is not specified for the current project descriptor set. | Repeat immediate command with `toc=1` and `toc=0`. | `toc=1` generates STOP and success. `toc=0` is a clarification/negative case until the project spec defines immediate continuation; acceptable sign-off behavior must be one specified policy such as reject/abort with error or forced STOP, and the bus must not hang without STOP or `Sr`. | `flow_active`, `scl_generator` | Medium | `cp_toc`, `cp_imm`, `cp_unsupported_policy` |
| IMM_004 | `i2c_immediate_write_basic` | Verify immediate path for legacy I2C DAT entry. | DAT[0].`device=1`; static address programmed. | Issue I2C immediate write with 1..4 bytes. | OD-only static address+W, data ACKs, RESP length equals bytes transferred. | `flow_active`, `bus_tx_flow` | High | `cp_i2c`, `cp_imm` |
| IMM_005 | `immediate_addr_nack` | Verify address NACK for immediate transfer. | Target NACKs the address ACK/NACK slot. | Issue I3C and I2C immediate writes. | Controller generates STOP immediately after address NACK; no inline data byte is transmitted; RESP error is `AddrHeader` with length 0. | `flow_active`, `bus_rx_flow` | High | `cp_resp_err`, `cross_imm_x_device_type` |
| IMM_006 | `immediate_data_nack_i2c` | Verify I2C immediate data NACK handling. | I2C target ACKs address and NACKs one data byte. | Issue multi-byte I2C immediate write. | Controller generates STOP after data NACK; no later inline data byte is transmitted; RESP error is `Nack`. | `flow_active` | High | `cp_data_ack`, `cp_resp_err` |

### 4.7 Common Command Codes

CCC broadcast-header use of `0x7e` is protocol-required and is not controlled by `HC_CONTROL[BROADCAST_ADDR_ENABLE]`, which applies only to private I3C regular transfers.

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| CCC_001 | `ccc_entdaa_opening_frame` | Verify ENTDAA broadcast opening frame. | AddressAssignment CMD queued; targets ACK the broadcast header. | Issue `AddressAssignment` with `cmd=0x07`. | Bus shows START, `7'h7E+W`, broadcast-header ACK, ENTDAA opcode `8'h07` with T-bit odd parity, then the ENTDAA `7'h7E+R` round sequence. | `flow_active`, `bus_tx_flow`, `bus_rx_flow` | High | `cp_ccc_opcode`, `cp_entdaa_phase` |
| CCC_002 | `ccc_broadcast_enec_frame` | Verify broadcast ENEC frame generation. | Immediate CMD with `cp=1`, `cmd=8'h00`; target ACKs only the broadcast header. | Send Target Events byte in `def_or_data_byte1` according to the immediate descriptor convention. | Bus shows START, `7'h7E+W` in open-drain, broadcast-header ACK in open-drain, ENEC opcode `8'h00` in push-pull, opcode T-bit `~^8'h00`, Target Events byte in push-pull, event-byte T-bit `~^event_byte`, and STOP. No target ACK is expected after the CCC opcode or event byte. | `flow_active`, `i3c_monitor` | High | `cp_ccc_opcode`, `cp_ccc_broadcast`, `cp_odpp_phase` |
| CCC_003 | `ccc_broadcast_disec_frame` | Verify broadcast DISEC frame generation. | Immediate CMD with `cp=1`, `cmd=8'h01`; target ACKs the broadcast header. | Send Target Events byte according to the project descriptor convention. | Bus frame follows the MIPI broadcast DISEC format: START, `7'h7E+W`, broadcast-header ACK, DISEC opcode `8'h01` with T-bit, Target Events byte with T-bit, then STOP; ENTDAA controller is not activated. | `flow_active` | High | `cp_ccc_opcode`, `cp_ccc_broadcast` |
| CCC_004 | `ccc_direct_enec_frame` | Verify direct ENEC frame. | DAT dynamic address valid; target ACKs broadcast header and direct address. | Immediate CMD with `cp=1`, `cmd=8'h80`, one data byte. | Bus shows broadcast header, CCC opcode/T-bit, Sr, target dynamic address+W, address ACK, data/T-bit, STOP. | `flow_active`, `scl_generator` | High | `cp_ccc_direct`, `cp_rstart` |
| CCC_005 | `ccc_direct_disec_frame` | Verify direct DISEC frame. | DAT dynamic address valid; target ACKs broadcast header and direct address. | Immediate CMD with `cp=1`, `cmd=8'h81`. | Direct DISEC frame is emitted with CCC opcode/T-bit, Sr, direct address ACK, optional data/T-bit as specified; RESP success if all required address ACKs are received. | `flow_active` | High | `cp_ccc_opcode`, `cp_ccc_direct` |
| CCC_006 | `ccc_broadcast_header_nack` | Verify CCC NACK recovery. | Device NACKs `7'h7E+W`. | Issue ENEC/DISEC/ENTDAA command. | Controller reports the specified address/header error, generates legal bus recovery, and does not send CCC payload after broadcast-header NACK. | `flow_active`, RESP FIFO | High | `cp_ccc_nack`, `cp_resp_err` |
| CCC_007 | `ccc_direct_target_nack` | Verify direct CCC target address NACK. | Target ACKs broadcast header, observes the direct CCC opcode/T-bit, and NACKs direct address. | Issue direct ENEC/DISEC. | No direct data byte is sent after address NACK; RESP and bus recovery match the address/header NACK policy in the project spec. | `flow_active` | High | `cp_ccc_direct`, `cp_addr_ack` |
| CCC_008 | `ccc_unsupported_opcode_policy` | Define behavior for unsupported CCC opcodes. | Immediate CMD `cp=1`, opcode outside ENEC/DISEC/ENTDAA. | Issue representative unsupported broadcast and direct opcodes. | This is a clarification/negative test until the project spec defines unsupported CCC handling. Required sign-off behavior should be a specified `NotSupported`/error response or software restriction; the controller must not emit an undefined successful CCC frame, corrupt queues, or lock up. | `flow_active`, `i3c_pkg` | Medium | `cp_unsupported_cmd` |

### 4.8 Dynamic Address Assignment / ENTDAA

ENTDAA rounds continue to use `0x7e` according to the ENTDAA protocol flow regardless of `HC_CONTROL[BROADCAST_ADDR_ENABLE]`.

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| DAA_001 | `entdaa_single_device_success` | Verify one successful ENTDAA round. | DAT[0] contains dynamic address; target can drive PID/BCR/DCR and ACK address. | Issue AddressAssignment with `dev_idx=0`, `dev_count=1`. | ENTDAA frame completes per MIPI sequence; assigned address byte uses correct parity; target ACKs the assignment; RESP success; any software-visible DAA result follows the documented project format. | `flow_active`, `entdaa_controller`, `entdaa_fsm` | High | `cp_daa_count`, `cp_daa_result` |
| DAA_002 | `entdaa_no_device` | Verify no-device exit. | No target ACKs `7'h7E+R`. | Issue AddressAssignment. | `entdaa_fsm` enters no-device path; STOP generated; response completes without assignment result. | `entdaa_fsm`, `entdaa_controller` | High | `cp_daa_no_device` |
| DAA_003 | `entdaa_fewer_devices_than_count` | Verify early exit when fewer devices respond than requested. | `dev_count` > actual responders. | First M rounds ACK; next `7'h7E+R` NACKs. | Loop exits after no-device NACK; no out-of-range extra assignment. | `entdaa_controller` | High | `cp_daa_count`, `cp_daa_no_device` |
| DAA_004 | `entdaa_multi_device_dat_loop` | Verify DAT index increment across rounds. | Multiple DAT entries programmed; multi-target UVM support available. | Issue `dev_idx=N`, `dev_count=K`. | DAT indices `N..N+K-1` are used; repeated START precedes each round; K addresses assigned if K targets respond. | `entdaa_controller`, `csr_registers` | High | `cp_daa_index`, `cp_rstart_count` |
| DAA_005 | `entdaa_address_parity_sweep` | Verify assigned address parity. | Target ACKs assigned addresses. | Sweep representative dynamic addresses including low, high, alternating patterns. | Sent address parity bit matches odd parity calculation. | `entdaa_fsm`, `bus_tx_flow` | High | `cp_daa_addr`, `cp_daa_parity` |
| DAA_006 | `entdaa_address_rejected` | Verify target NACK of assigned address. | Target ACKs `7'h7E+R`, drives PID/BCR/DCR, then NACKs address. | Issue AddressAssignment. | `addr_valid_o` is not asserted; loop continues or completes according to `dev_count`/no-device behavior. | `entdaa_fsm`, `entdaa_controller` | High | `cp_daa_addr_ack` |
| DAA_007 | `entdaa_pid_bcr_dcr_capture` | Verify identity capture. | Target drives known PID/BCR/DCR values. | Run successful ENTDAA. | Captured PID/BCR/DCR match the bits driven by the target in the MIPI ENTDAA order; software-visible RX data is checked only after its project format is specified. | `entdaa_fsm`, `flow_active`, RX FIFO | High | `cp_daa_pid`, `cp_daa_bcr`, `cp_daa_dcr` |
| DAA_008 | `entdaa_dat_boundary` | Verify DAT boundary behavior. | Program `dev_idx` near last DAT entry. | Run `dev_idx=15`, `dev_count=1`, then `dev_idx=15`, `dev_count>1`. | Single entry works; out-of-range `dev_idx+dev_count` is a clarification/negative case that must either produce a specified error or be forbidden by a documented software precondition. | `entdaa_controller`, `csr_registers` | Medium | `cp_dat_boundary` |
| DAA_009 | `entdaa_stop_mid_round` | Verify STOP/abort handling during DAA. | External/device model can force STOP-like bus condition or reset. | Interrupt during PID/BCR/DCR reception. | ENTDAA exits through a specified abort/recovery policy and controller returns to a legal idle/recoverable state; if no policy exists, this is a spec gap and not positive sign-off coverage. | `entdaa_fsm`, `entdaa_controller`, `bus_monitor` | Medium | `cp_daa_abort_point` |
| DAA_010 | `entdaa_two_target_arbitration` | Verify wired-AND arbitration across multiple targets. | UVM bus model supports simultaneous target driving. | Two unaddressed targets drive different PID bits; losing target stops participating. | Master assigns arbitration winner first, then remaining target in later round. | UVM I3C agent, bus, `entdaa_fsm` | Future | `cp_daa_arbitration` |

### 4.9 I2C Legacy Compatibility

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| I2C_001 | `i2c_regular_write_basic` | Verify I2C legacy write path. | DAT[0].`device=1`, static address programmed, target ACKs. | Issue RegularTransfer write of 1 and 4 bytes. | Static address+W is used; OD mode throughout; data bytes are ACKed; RESP success. | `flow_active`, `scl_generator`, `bus_tx_flow` | High | `cp_device_type`, `cp_i2c_dir` |
| I2C_002 | `i2c_regular_read_basic` | Verify I2C legacy read path. | DAT[0].`device=1`; target returns data. | Issue RegularTransfer read of 1 and 4 bytes. | Static address+R is used; master ACKs intermediate bytes and NACKs final byte; RX data correct. | `flow_active`, `bus_rx_flow`, `bus_tx_flow` | High | `cp_i2c_dir`, `cp_i2c_ack_seq` |
| I2C_003 | `i2c_broadcast_addr_enable_ignored` | Verify legacy I2C transfers ignore private-transfer broadcast-header control. | `HC_CONTROL[BROADCAST_ADDR_ENABLE]=1`; DAT[0].`device=1` with static address programmed; target ACKs. | Run representative I2C read and write commands. | First address remains the DAT static address for both directions; no `0x7e` preamble is emitted; OD-only behavior and I2C ACK/NACK sequencing are unchanged. | `flow_active`, `scl_generator`, `bus_tx_flow`, `bus_rx_flow` | High | `cp_broadcast_addr_enable`, `cp_first_address`, `cp_i2c_dir` |
| I2C_004 | `i2c_len_sweep_partial_rx` | Verify I2C read/write length behavior. | I2C target model active. | Run I2C writes and reads of 1,2,3,4,5,7,8 bytes. | Correct TX/RX packing; partial RX DWORD preserved; RESP length correct. | `flow_active`, `hci_queues` | High | `cp_data_len`, `cp_rx_partial_dword` |
| I2C_005 | `i2c_addr_nack` | Verify I2C address NACK. | Target NACKs static address. | Issue read and write commands. | No data phase; RESP error is `AddrHeader`; bus returns idle. | `flow_active`, `bus_rx_flow` | High | `cp_resp_err`, `cp_i2c_addr_ack` |
| I2C_006 | `i2c_data_nack_write` | Verify I2C data-byte NACK. | Target ACKs address and NACKs byte M. | Issue multi-byte write. | Transfer stops after the NACKed byte per I2C/project error policy; RESP error is `Nack`; next legal transfer passes. | `flow_active` | High | `cp_data_ack`, `cp_resp_err` |
| I2C_007 | `i2c_od_only_check` | Verify legacy transfers remain open-drain. | I2C read and write commands. | Observe `sel_od_pp_o` and SDA drive during address/data/ACK. | `sel_od_pp_o` remains OD for entire I2C transaction. | `controller_active`, `i3c_phy` | High | `cp_odpp_phase`, `cp_i2c` |
| I2C_008 | `i2c_timing_400k_equivalent` | Verify configured I2C timing path. | Timing registers programmed for I2C FM-equivalent values at TB clock. | Run representative I2C read/write. | SCL low/high and START/STOP timing match programmed counters. | `csr_registers`, `scl_generator` | Medium | `cp_timing_mode` |

### 4.10 Error Handling, Status, and Recovery

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| ERR_001 | `resp_success_tid_length` | Verify successful RESP descriptor fields. | Valid transactions with unique TIDs. | Run immediate, regular write, regular read, and ENTDAA success paths. | RESP `[31:28]=Success`, `[27:24]=TID`, `[15:0]=actual length`. | `flow_active`, RESP FIFO | High | `cp_resp_err`, `cp_tid`, `cp_resp_len` |
| ERR_002 | `resp_addr_header_error` | Verify address/header NACK response encoding. | Device NACKs address. | Run `i3c_addr_header_nack_resp_vseq` for I3C write/read address NACK; extend to I2C write/read and direct CCC address phases as those directed tests are added. | RESP status is `AddrHeader`, TID matches the command, reserved bits are zero, and length is 0 for every supported command class with address/header NACK. | `flow_active`, RESP FIFO | High | `cp_resp_err`, `cp_addr_ack`, `cp_tid`, `cp_resp_len` |
| ERR_003 | `resp_data_nack_error` | Verify data NACK error for I2C write-style phases. | Target NACKs data byte. | Run I2C write/immediate write with data NACK. | RESP error is `Nack`; transfer recovers. | `flow_active` | High | `cp_data_ack`, `cp_resp_err` |
| ERR_004 | `resp_short_read_error` | Verify short read response encoding. | Target ends I3C read early. | Run `i3c_short_read_resp_vseq`: request N bytes, target ends after M<N. | RESP status is `I3cShortReadErr`, TID matches the command, reserved bits are zero, and length reflects actual received bytes M. | `flow_active`, RESP FIFO | High | `cp_short_read`, `cp_resp_err`, `cp_tid`, `cp_resp_len` |
| ERR_005 | `resp_ovl_error` | Verify overflow response encoding. | TX FIFO underflow or RX FIFO full overflow condition. | Run `i3c_ovl_resp_vseq` for TX underflow with partial/empty TX FIFO and RX FIFO full during read. | RESP status is `Ovl`, TID matches the command, reserved bits are zero, and length equals the number of bytes actually processed. | `flow_active`, RESP FIFO | High | `cp_resp_err_ovl`, `cp_tid`, `cp_resp_len` |
| ERR_006 | `resp_fifo_full_backpressure` | Verify response write stalls safely. | RESP FIFO full before transaction completes. | Complete a transfer while RESP full, then drain RESP. | FSM waits in response write phase; exactly one response is eventually written. | `flow_active`, `hci_queues` | High | `cp_resp_full`, `cp_stall_type` |
| ERR_007 | `reset_during_idle` | Verify reset in idle. | DUT idle. | Assert/deassert `rst_ni`. | Registers/queues/FSM return to reset state; bus released. | Full DUT | High | `cp_reset_point` |
| ERR_008 | `reset_during_transfer_phases` | Verify reset during active operation. | Transfer in progress. | Reset during START, address ACK, data TX, data RX, DAA, and WriteResp phases. | Bus releases; no partial unintended queue pop/push after reset; next legal transfer passes. | Full DUT | High | `cp_reset_point`, `cross_reset_x_phase` |
| ERR_009 | `sw_reset_while_busy_policy` | Clarify SW reset during active transfer. | Transfer in progress. | Assert `HC_CONTROL[1]` while not idle. | If the spec leaves this undefined, the test records a spec gap and recommends SW only reset when `FSM_IDLE=1`; it is not positive sign-off coverage until a busy-reset policy is specified. | `csr_registers`, `hci_queues`, `flow_active` | Medium | `cp_sw_reset_busy` |
| ERR_010 | `bus_stuck_scl_low` | Identify bus recovery gap. | Device/bus model can hold SCL low or prevent progress. | Hold SCL low during transfer. | If no timeout/recovery requirement is specified in the project scope, this is a documented N/A/gap; it must not be treated as a functional pass merely because the controller waits forever. | `scl_generator`, `bus_monitor` | Medium | `cp_bus_stuck` |
| ERR_011 | `invalid_descriptor_attr` | Verify unsupported descriptor behavior. | CMD descriptors can be written directly. | Issue `ComboTransfer`, reserved attr, HDR mode values, and invalid mode encodings. | No unbounded hang or illegal queue corruption; expected protocol behavior must be specified before sign-off. | `flow_active`, CMD descriptor parsing | Medium | `cp_invalid_cmd` |
| ERR_012 | `resp_hc_abort_error` | Verify HC abort response encoding, status priority, and non-data-phase abort entry states. | Controller can be aborted from selectable FSM states via `HC_CONTROL[3]`; bus-error injection available; `HC_CONTROL[3]` is a level bit that is never auto-cleared by hardware. | Assert HC abort (a) during a data-phase transfer that terminates via STOP, (b) in a pre-bus state (`FetchDAT`, or `WaitDAT` with no pending continuation), (c) while idle (`Idle`/`WaitForCmd`), (d) after a bus error has already latched, and (e) leave the bit asserted across a following queued command. | (a) RESP status is `HcAborted`, TID matches the command, reserved bits zero, and length equals the bytes processed before abort. (b) No STOP and no bus activity occur; the FSM advances directly to `WriteResp` with `HcAborted`. (c) Abort is a no-op; the active/next command proceeds normally. (d) The previously latched bus error wins over `HcAborted` per the response-status priority. (e) Because the bit is not auto-cleared, the next command is also aborted until software clears `HC_CONTROL[3]`. | `flow_active`, `csr_registers`, RESP FIFO, UVM scoreboard | High | `cp_hc_abort`, `cp_resp_err`, `cp_abort_entry_state`, `cp_resp_err_priority` |
| ERR_013 | `i3c_read_tbit_no_parity_resp` | Verify response classification for a legal SDR read final T-bit. | DAT[0] is I3C dynamic address `0x08`; target ends transfer with T-bit=0 at the requested length. | Run `i3c_read_tbit_no_parity_resp_vseq`. | Final T-bit=0 at the requested length is not classified as `Parity`; RESP is `Success`, TID matches the command, reserved bits are zero, and length matches the requested length. | `flow_active`, RESP FIFO, UVM scoreboard | High | `cp_read_tbit`, `cp_resp_err`, `cp_tid`, `cp_resp_len` |

### 4.11 Arbitration and Bus Behavior

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| ARB_001 | `entdaa_single_bit_arbitration_observe` | Verify ENTDAA bit-level receiver samples wired bus. | DAA target drives known PID bits. | During ENTDAA, observe each PID/BCR/DCR bit sampled by `bus_rx_flow`. | Captured 64-bit identity matches bus data. | `entdaa_fsm`, `bus_rx_flow`, bus model | High | `cp_daa_bit_pos` |
| ARB_002 | `entdaa_multi_target_arbitration_future` | Verify true multi-target DAA arbitration. | Multi-target simultaneous drive model added. | Two or more targets participate with different PIDs. | Wired-AND arbitration winner is assigned first; losing target retries later. | UVM bus model, `entdaa_fsm` | Future | `cp_daa_arbitration` |
| ARB_003 | `unexpected_stop_during_command` | Verify STOP detection during active command. | Bus model can force STOP or reset-like condition. | Inject STOP-like SDA rise while SCL high during DAA or data phase. | Controller follows a specified abort/recovery policy; if none exists, the test records a spec gap and is not positive sign-off coverage. | `bus_monitor`, `flow_active`, `entdaa_controller` | Medium | `cp_unexpected_bus_event` |
| ARB_004 | `start_when_bus_not_idle` | Verify controller behavior if command starts on busy bus. | Bus held non-idle before command. | Queue command while SCL/SDA not both high. | Controller must either wait for the specified Bus Available/Idle condition or reject the command with a specified error/software precondition; observed RTL behavior alone is not a pass criterion. | `scl_generator`, `bus_monitor` | Medium | `cp_bus_busy_start` |

### 4.12 UVM Environment, Scoreboard, and Regression Infrastructure

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| UVM_001 | `uvm_compile_elaborate` | Verify source list and compile flow. | Xcelium available and setup sourced. | Run `make compile` from `src/verification`. | Compile/elaboration passes with no fatal errors. | `Makefile`, `filelist.f`, all RTL/UVM | High | Build gate |
| UVM_002 | `uvm_smoke_regression` | Verify current smoke target. | Xcelium available. | Run `make smoke`. | UVM summary has zero `UVM_ERROR` and zero `UVM_FATAL`; RESP success is observed. | Existing UVM env | High | Regression gate |
| UVM_003 | `uvm_regression_current` | Verify current regression target. | Xcelium available. | Run `make regression`. | Smoke/write/read sequences pass; `sim.log` inspected for UVM summary. | `Makefile`, vseqs | High | Regression gate |
| UVM_004 | `scoreboard_cmd_resp_order` | Verify scoreboard command/response correlation. | Multiple commands with unique TIDs. | Queue back-to-back commands and read responses. | Scoreboard matches expected address, direction, data, TID, and no unconsumed expected transactions remain. | `i3c_scoreboard` | High | `cp_scb_order` |
| UVM_005 | `scoreboard_negative_mismatch` | Verify scoreboard detects failures. | Controlled mismatch injection available. | Intentionally mismatch expected data/address in a negative test. | Scoreboard emits `UVM_ERROR`; test infrastructure catches failure. | `i3c_scoreboard` | Medium | Checker validation |
| UVM_006 | `device_response_ack_nack_controls` | Verify device sequence configurability. | `i3c_device_response_seq` or derived seq. | Drive address ACK/NACK, data ACK/NACK, read data, I2C/I3C mode. | Device behavior matches sequence fields and supports error tests. | `i3c_driver`, `i3c_seq_item` | High | `cp_device_resp_mode` |
| UVM_007 | `monitor_ccc_and_daa_decode` | Verify monitor can decode management traffic. | CCC/DAA vseqs implemented. | Run ENEC/DISEC/ENTDAA tests. | Monitor reports CCC opcode, direct/broadcast flag, DAA data, and STOP/Sr accurately. | `i3c_monitor`, `i3c_item` | High | `cp_monitor_decode` |
| UVM_008 | `reg_agent_read_write_protocol` | Verify register agent behavior. | Register interface connected. | Run directed read/write operations with back-to-back accesses. | `reg_driver` drives single-cycle accesses; `reg_monitor` reports observed bus operations. | `reg_agent`, `reg_if` | Medium | `cp_reg_agent_op` |

### 4.13 Stress, Robustness, and Performance

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals / Metrics |
|---|---|---|---|---|---|---|---|---|
| STR_001 | `stress_random_i3c_private_rw` | Stress I3C private transfers. | Constrained-random vseq and target model. | Randomize direction, length, data, TID, DAT entry, ACK behavior. | No hang; scoreboard matches all legal transfers; expected errors only for injected NACK/short read. | Full DUT/UVM | High | Crosses for dir, len, data, err |
| STR_002 | `stress_i2c_i3c_mixed_devices` | Stress DAT device switching. | DAT entries include I2C and I3C targets. | Random command stream across device types. | Static vs dynamic address selection correct; OD/PP mode correct; responses ordered. | `flow_active`, DAT, UVM | High | `cross_device_type_x_dir` |
| STR_003 | `stress_ccc_daa_private_mix` | Stress management and data traffic sequencing. | CCC/DAA vseqs implemented. | Mix ENEC, DISEC, ENTDAA, reads, and writes. | Controller returns idle between completed commands; no stale state across command classes. | Full DUT/UVM | High | `cross_cmd_attr_x_prev_cmd` |
| STR_004 | `stress_fifo_boundary_random` | Stress queue boundary behavior. | TB can fill/drain software-visible queues. | Random command/TX writes and RX/RESP reads near full/empty. | No queue overflow/underflow corruption; status flags remain accurate. | `hci_queues`, `csr_registers` | High | `cross_fifo_kind_x_state` |
| STR_005 | `stress_long_run_1k` | Verify long-run stability. | Directed-random suite available. | Run at least 1000 legal and negative transactions. | Zero unexpected UVM errors/fatals; no timeout; final queues empty or intentionally drained. | Full DUT/UVM | Medium | Long-run stability |
| PERF_001 | `perf_sdr_rw_latency` | Measure I3C SDR read/write latency. | Timestamping in vseq or monitor. | Measure command enqueue to RESP for 1,4,16,64 byte transfers. | Report min/avg/max latency and throughput; no functional pass/fail except timeout. | Full DUT/UVM | Low | Latency metric |
| PERF_002 | `perf_i2c_legacy_latency` | Measure I2C legacy transfer latency. | I2C legacy vseqs implemented. | Measure read/write latency with configured I2C timing. | Report min/avg/max latency and compare against programmed timing. | Full DUT/UVM | Low | Latency metric |
| PERF_003 | `perf_back_to_back_gap` | Measure inter-command gap. | Back-to-back commands queued. | Measure STOP-to-next-START and RESP-to-next-command timing for W-W, R-R, W-R, R-W. | Report gap; identify unnecessary idle cycles. | `flow_active`, `scl_generator` | Low | Gap metric |

### 4.14 Non-Applicable Feature Documentation Tests

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| NA_001 | `na_ibi_no_positive_test` | Document IBI absence. | Code review. | Inspect RTL/UVM for IBI interfaces and queues. | IBI is not implemented; no positive IBI testcase is counted in current sign-off. | Repository docs/source | Low | Scope traceability |
| NA_002 | `na_hotjoin_no_positive_test` | Document Hot-Join absence. | Code review. | Inspect RTL/UVM for Hot-Join detection/CCC/event state. | Hot-Join is not implemented; future feature only. | Repository docs/source | Low | Scope traceability |
| NA_003 | `na_irq_no_positive_test` | Document interrupt absence. | Code review. | Inspect top-level ports and CSR map. | No IRQ output or interrupt enable/status registers exist; status verification is through `HC_STATUS`, `QUEUE_STATUS`, and RESP. | `i3c_controller_top`, `csr_registers` | Low | Scope traceability |
| NA_004 | `na_hdr_no_positive_test` | Document HDR absence. | Code review and invalid descriptor negative test. | Issue HDR mode enum values only as unsupported descriptor tests. | No HDR positive tests are required until HDR datapath is implemented. | `i3c_pkg`, `flow_active` | Low | Scope traceability |

## 5. Feature to Test and Coverage Mapping

| Feature | Primary testcases | Coverage goals |
|---|---|---|
| CSR reset/control/status | CSR_001, CSR_002, CSR_003, CSR_012 | `cp_csr_addr`, `cp_reset`, `cp_enable`, `cp_broadcast_addr_enable` |
| DAT programming and selection | CSR_005, DAA_004, DAA_008, STR_002 | `cp_dat_idx`, `cp_device_type`, `cp_dat_boundary` |
| CMD/TX/RX/RESP queues | CSR_006, CSR_008, CSR_010, FIFO_001..FIFO_004, STR_004 | `cp_fifo_kind`, `cp_fifo_state`, `cp_fifo_boundary` |
| START/STOP/Sr | BUS_002, BUS_003, BUS_004, BUS_007, CCC_004, DAA_001 | `cp_bus_event`, `cp_rstart`, `cp_timing` |
| SCL timing and stalls | BUS_005, BUS_006, SDRW_005, SDRR_005, I2C_008 | `cp_timing_mode`, `cp_stall_type` |
| I3C private write | SDRW_001..SDRW_008; broadcast-header enabled write framing is covered by CSR_003, SDRW_002, and SDRW_006 | `cp_dir`, `cp_data_len`, `cp_tbit_write_parity`, `cp_private_start_prefix` |
| I3C private read | SDRR_001..SDRR_009 | `cp_dir`, `cp_rx_partial_dword`, `cp_read_tbit`, `cp_private_start_prefix` |
| Immediate transfer | IMM_001..IMM_006 | `cp_imm`, `cp_imm_dtt`, `cross_imm_x_device_type` |
| CCC | CCC_001..CCC_008 | `cp_ccc_opcode`, `cp_ccc_direct`, `cp_ccc_broadcast`, `cp_ccc_nack` |
| ENTDAA | DAA_001..DAA_010 | `cp_daa_count`, `cp_daa_addr`, `cp_daa_result`, `cp_daa_arbitration` |
| I2C legacy | I2C_001..I2C_008 | `cp_i2c_dir`, `cp_i2c_ack_seq`, `cp_device_type`, `cp_first_address` |
| Broadcast-header private preamble | CSR_003, SDRW_002/006, SDRR_001..SDRR_009, I2C_003 | `cp_broadcast_addr_enable`, `cp_private_start_prefix`, `cp_first_address` |
| Error handling | ERR_001..ERR_013 | `cp_resp_err`, `cp_addr_ack`, `cp_short_read`, `cp_read_tbit`, `cp_invalid_cmd` |
| UVM infrastructure | UVM_001..UVM_008 | Checker validation and regression gates |
| Stress/performance | STR_001..STR_005, PERF_001..PERF_003 | Cross coverage closure and latency metrics |

## 6. Functional Coverage Plan

### 6.1 Coverpoints

| Coverpoint | Bins |
|---|---|
| `cp_cmd_attr` | `ImmediateDataTransfer`, `RegularTransfer`, `AddressAssignment`, `ComboTransfer/unsupported`, reserved |
| `cp_device_type` | I3C DAT entry, I2C legacy DAT entry |
| `cp_dir` | Write, Read |
| `cp_broadcast_addr_enable` | disabled, enabled |
| `cp_private_start_prefix` | dynamic-address-first, broadcast-header-then-dynamic |
| `cp_first_address` | `0x7e`, dynamic address, static address |
| `cp_data_len` | 0, 1, 2, 3, 4, 5-7, 8-15, 16+ |
| `cp_data_pattern` | zero, all-one, alternating A/5, walking-one, random |
| `cp_toc` | 0, 1 |
| `cp_resp_err` | Success, AddrHeader, Nack, Ovl, I3cShortReadErr, unreachable-defined-codes |
| `cp_addr_ack` | ACK, NACK |
| `cp_data_ack` | ACK all, NACK first, NACK middle, NACK last |
| `cp_read_tbit` | continue, end at expected length, early end |
| `cp_tbit_write_parity` | even data parity, odd data parity |
| `cp_fifo_kind` | CMD, TX, RX, RESP |
| `cp_fifo_state` | empty, one entry, middle, near full, full |
| `cp_fifo_operation` | write only, read only, simultaneous read/write, flush |
| `cp_dat_idx` | 0, 1, 2-14, 15 |
| `cp_bus_event` | START, STOP, repeated START, unexpected STOP |
| `cp_odpp_phase` | START, address, ACK, I3C data, I3C T-bit, STOP, ENTDAA |
| `cp_timing_mode` | I3C SDR timing, I2C legacy timing, custom timing |
| `cp_stall_type` | TX empty, RX full, RESP full, none |
| `cp_ccc_opcode` | ENEC, DISEC, ENTDAA, direct ENEC, direct DISEC, unsupported |
| `cp_ccc_form` | broadcast, direct |
| `cp_daa_count` | 0, 1, 2, 3-15 |
| `cp_daa_result` | assigned, no-device, address rejected |
| `cp_daa_addr` | low valid, high valid, alternating, reserved/invalid if tested as negative |
| `cp_reset_point` | idle, command fetch, address, data TX, data RX, DAA, response write |

### 6.2 Cross Coverage

| Cross | Purpose |
|---|---|
| `cmd_attr x device_type` | Ensure immediate/regular/address-assignment paths hit applicable device classes. |
| `device_type x dir x data_len` | Cover I3C and I2C read/write lengths. |
| `dir x resp_err` | Ensure each reachable error is hit for read and write where applicable. |
| `fifo_kind x fifo_state x fifo_operation` | Close queue boundary and backpressure behavior. |
| `ccc_opcode x ccc_form x resp_err` | Cover supported CCC forms and negative ACK paths. |
| `daa_count x daa_result` | Cover single, multi, no-device, and fewer-than-count DAA outcomes. |
| `reset_point x cmd_attr` | Cover reset during each major command class. |
| `odpp_phase x device_type` | Ensure OD/PP switching differs correctly between I3C and I2C. |
| `timing_mode x bus_event` | Verify timing for START/STOP/Sr under I3C and I2C settings. |
| `broadcast_addr_enable x transaction_type x first_address` | Ensure the control bit changes only private I3C first-address behavior while I2C, CCC, and ENTDAA retain their protocol-required address flows. |
| `prev_cmd_attr x next_cmd_attr` | Cover back-to-back sequencing across command classes. |

## 7. Missing Information and Required Clarifications

| Gap | Impact on verification |
|---|---|
| CCC byte/T-bit wording is inconsistent across local docs. | MIPI CCC command, defining, and data bytes are followed by T-bit, not target ACK. Stale module/spec comments must be aligned before they are used as verification oracles. |
| ENEC/DISEC exact descriptor encoding is not fully specified in public docs/source comments. | CCC tests can verify emitted bus frames, but pass/fail for defining/event byte policy needs a clarified spec. |
| Unsupported descriptor policy is not defined. | Tests for `ComboTransfer`, HDR modes, reserved modes, and unsupported CCCs should currently be negative/documentation tests, not strict feature tests. |
| DAA software-visible result format should be clarified. | The exact software consumption contract for PID/BCR/DCR/address must be documented before RX FIFO checks can be positive sign-off coverage. |
| SW reset during active transfer is undefined in CSR spec. | Verification should enforce safe SW sequence or RTL should define busy-reset behavior. |
| Dedicated OD/PP pad-model sequence is not implemented. | The top-level TB now connects `sda_oe_o` and `sel_od_pp_o`, but phase-level PP drive/release checks still need a dedicated `i3c_od_pp_pad_vseq`. |
| Functional coverage architecture is not implemented. | Coverage goals in this plan require adding covergroups/subscribers. |
| IBI, Hot-Join, IRQ, HDR, multi-master, target mode, bus recovery are absent. | Do not count these as current test failures; list them as future verification expansion. |

## 8. Future Verification Expansion

| Area | Recommended expansion |
|---|---|
| Coverage | Add `i3c_cov.sv` subscriber connected to reg and I3C monitor analysis ports; implement coverpoints/crosses in Section 6. |
| ENTDAA | Add dedicated `i3c_entdaa_vseq` and DAA target response sequence with PID/BCR/DCR/address ACK controls. |
| CCC | Add ENEC/DISEC broadcast/direct vseqs and scoreboard CCC frame decode. |
| Error injection | Extend device sequence to NACK address/data at programmable byte index and to end reads early. |
| I2C legacy | Add `i2c_legacy_write_vseq` and `i2c_legacy_read_vseq`; include OD-only and master ACK/NACK checks. |
| Pad model | Add `i3c_od_pp_pad_vseq` to explicitly check OD address/ACK/START/STOP behavior, PP write drive-high/drive-low behavior, and SDA release during I3C read data phases. |
| Assertions | Add SVA for START only when bus idle, Sr only after active transfer, no simultaneous TX bit/byte requests, T-bit parity generation, queue no-overflow/no-underflow, and OD/PP phase constraints. |
| Regression flow | Split per-sequence logs instead of overwriting `sim.log`; add a regression summary parser for UVM errors/fatals and seed tracking. |
| Protocol growth | If IBI, Hot-Join, HDR, target mode, or bus recovery are added, create new feature-specific categories rather than reusing current N/A rows. |
