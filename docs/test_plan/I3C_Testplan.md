# I3C Controller Verification Test Plan

## 1. Current Repository Architecture Summary

This repository implements a simplified MIPI I3C Basic active controller in SystemVerilog. The actual implemented scope is a single active controller with SDR private transfers, I2C legacy transfer paths, ENTDAA-based dynamic address assignment, a simple CSR bus, and FIFO-based command/data/response queues.

| Area | Current implementation |
|---|---|
| Top level | `src/rtl/i3c_controller_top.sv` integrates CSR, HCI queues, protocol controller, and PHY. External interfaces are a 32-bit register bus, SCL/SDA pins, SDA output-enable, and OD/PP mode select. |
| CSR and DAT | `csr_registers.sv` implements `HC_CONTROL`, `HC_STATUS`, timing registers, CMD/TX/RX/RESP queue ports, `QUEUE_STATUS`, and 16 32-bit DAT entries. DAT fields are `device`, `dynamic_address`, and `static_address`. |
| Queues | `hci_queues.sv` wraps four `sync_fifo` instances: CMD 64-bit, TX 32-bit, RX 32-bit, RESP 32-bit. Default RTL depth is 64; UVM top instantiates depth 8. |
| Controller wrapper | `controller_active.sv` connects `flow_active`, `scl_generator`, `bus_monitor`, `bus_tx_flow`, `bus_rx_flow`, and `entdaa_controller`. It multiplexes bus ownership between normal command flow and ENTDAA. |
| Main command FSM | `flow_active.sv` is the central command processor. It fetches CMD descriptors, reads DAT, drives immediate/regular transfer states, handles I2C legacy paths, starts ENTDAA, moves RX/TX FIFO data, and writes RESP descriptors. |
| Bus timing and conditions | `scl_generator.sv` generates START, repeated START, STOP, SCL low/high phases, and clock stalls. `bus_monitor.sv` detects START/STOP/Sr from synchronized bus inputs. |
| TX/RX datapath | `bus_tx_flow.sv` and `bus_tx.sv` serialize bytes/bits. `bus_rx_flow.sv` deserializes bytes/bits and includes an SVA preventing simultaneous bit and byte RX requests. |
| ENTDAA | `entdaa_controller.sv` manages the multi-device loop and DAT lookup. `entdaa_fsm.sv` sends `7'h7E+R`, receives PID/BCR/DCR bits, sends assigned address plus parity, and samples target ACK/NACK. |
| PHY | `i3c_phy.sv` provides 2-flop input synchronization and routes controller outputs to bus outputs with SDA output-enable and OD/PP select propagation. |
| UVM environment | `tb_i3c_top.sv`, `reg_agent`, `i3c_agent` in device mode, `i3c_env`, virtual sequencer, scoreboard, and three virtual sequences are implemented. `tb_i3c_top` now uses `sda_oe_o` for SDA pad drive/release and exposes DUT pad signals through `i3c_if`. |
| Current regression | `make regression` from `src/verification` runs `i3c_smoke_vseq`, `i3c_write_vseq`, and `i3c_read_vseq`. With `source ~/EDA/cadence/xcelium/XCELIUM1803.sh`, these existing sequences pass with zero `UVM_ERROR`/`UVM_FATAL`. |

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

### 3.1 Priorities

| Priority | Meaning |
|---|---|
| High | Required for minimum sign-off of the implemented controller behavior. Failures block release. |
| Medium | Important robustness, corner, or stress coverage. Failures require triage but may be deferred with documented risk. |
| Low | Informational, performance, or future-facing coverage. |
| Future | Applies only after RTL or UVM support is added. It must not be counted as current pass/fail coverage. |

### 3.2 Global Preconditions

Unless a testcase states otherwise:

- Reset is released through `rst_ni`.
- The register bus agent is active.
- `HC_CONTROL[0]` is written to enable the controller.
- Timing registers use either RTL reset defaults or testcase-specific values.
- DAT entries are explicitly programmed before issuing CMD descriptors.
- Device responses are driven through `i3c_device_response_seq` or a derived sequence.
- Completion is observed by polling `HC_STATUS[FSM_IDLE]` and reading `RESP_PORT`.

### 3.3 Existing UVM Regression

| Sequence | Current purpose | Coverage gap |
|---|---|---|
| `i3c_smoke_vseq` | Immediate I3C write of two inline bytes | Single device, success path only. |
| `i3c_write_vseq` | I3C regular write of four bytes from TX FIFO | No length sweep, NACK, stall, or I2C path. |
| `i3c_read_vseq` | I3C regular read of four bytes into RX FIFO | No partial DWORD, short read, RX full, or I2C path. |

## 4. Complete Testcase Plan

### 4.1 CSR, DAT, and Register Bus

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| CSR_001 | `csr_reset_defaults` | Verify reset-visible register defaults. | Reset applied and released. | Read `HC_CONTROL`, `HC_STATUS`, all timing registers, `QUEUE_STATUS`, and DAT[0..15]. | Enable is 0; FSM idle/status reflects idle; queue flags show empty; DAT entries are 0; timing defaults match RTL. | `csr_registers`, reg bus | High | `cp_reset`, `cp_csr_addr` |
| CSR_002 | `csr_enable_disable` | Verify controller enable gating. | CMD FIFO empty. | Toggle `HC_CONTROL[0]`; queue a command while disabled and then enable. | No bus transaction before enable; command starts after enable; status returns idle after completion. | `csr_registers`, `flow_active` | High | `cp_enable`, `cp_cmd_start` |
| CSR_003 | `csr_timing_rw` | Verify timing register read/write behavior. | Controller idle. | Write/read `T_R` through `T_HD_DAT` using default, minimum nonzero, and random legal values. | Readback matches written `[19:0]` values; reserved upper bits read 0. | `csr_registers`, reg bus | High | `cp_timing_reg`, `cp_timing_value` |
| CSR_004 | `csr_dat_rw_all_entries` | Verify all DAT entries and field packing. | Controller idle. | Write DAT[0..15] with varied static address, dynamic address, and `device` bit; read back. | DAT bit fields match `[31]`, `[22:16]`, and `[6:0]`; no adjacent entry corruption. | `csr_registers`, `controller_pkg::dat_entry_t` | High | `cp_dat_idx`, `cp_device_type` |
| CSR_005 | `csr_cmd_queue_2dw_staging` | Verify 64-bit CMD staging from two 32-bit writes. | CMD FIFO not full. | Write DWORD0 then DWORD1 to `CMD_QUEUE_PORT`. | One CMD FIFO entry is pushed as `{DWORD1,DWORD0}`; no push after only DWORD0. | `csr_registers`, `hci_queues` | High | `cp_cmd_staging` |
| CSR_006 | `csr_cmd_partial_then_other_write` | Verify partial CMD staging is not disturbed by unrelated CSR writes. | CMD FIFO not full. | Write CMD DWORD0, write timing/DAT/TX registers, then write CMD DWORD1. | Final CMD is assembled from the original DWORD0 and final DWORD1 only. | `csr_registers` | Medium | `cp_cmd_staging`, `cp_csr_interleave` |
| CSR_007 | `csr_sw_reset_flush_queues` | Verify software reset flushes queues. | Queues contain at least one entry where possible. | Poll idle, write `HC_CONTROL[1]=1`, then read queue status and ports. | CMD/TX/RX/RESP queues are empty; `SW_RESET` self-clears. | `csr_registers`, `hci_queues` | High | `cp_sw_reset`, `cp_fifo_state` |
| CSR_008 | `csr_sw_reset_clears_cmd_staging` | Verify stale DWORD0 cannot corrupt a later command. | Controller idle. | Write one CMD DWORD0, assert SW reset, then write a complete different command. | Only the post-reset command executes; no stale descriptor fields appear. | `csr_registers` | High | `cp_sw_reset`, `cp_cmd_staging` |
| CSR_009 | `csr_queue_status_flags` | Verify full/empty status bits. | Controller idle or block-level FIFO access. | Fill and drain CMD, TX, RX, and RESP queues to empty/non-empty/full points. | `QUEUE_STATUS` bits match actual FIFO state. | `csr_registers`, `hci_queues`, `sync_fifo` | High | `cp_fifo_kind`, `cp_fifo_state` |
| CSR_010 | `csr_rx_resp_read_pop` | Verify RX/RESP port pop behavior. | RX/RESP entries exist. | Read `RX_DATA_PORT` and `RESP_PORT`; read again after empty. | Valid reads pop one entry; empty reads return 0 and do not underflow. | `csr_registers`, `hci_queues` | High | `cp_port_pop`, `cp_empty_read` |
| CSR_011 | `csr_unmapped_addr_no_side_effect` | Verify unmapped address behavior. | Snapshot relevant CSRs and queues. | Read/write unmapped aligned addresses. | Reads return 0; no DAT, timing, control, or queue side effects occur. | `csr_registers`, reg bus | Medium | `cp_invalid_reg_addr` |

### 4.2 FIFO and Queue Behavior

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| FIFO_001 | `fifo_basic_push_pop_order` | Verify FIFO ordering. | FIFO reset. | Push known sequence, pop all entries. | Data order is preserved; empty/full/depth are correct. | `sync_fifo` | High | `cp_fifo_depth`, `cp_fifo_data_pattern` |
| FIFO_002 | `fifo_full_empty_boundaries` | Verify boundary flags. | FIFO reset. | Fill exactly to depth, attempt one extra write, drain to empty, attempt extra read. | Full blocks extra write; empty blocks extra read; no pointer corruption. | `sync_fifo`, `hci_queues` | High | `cp_fifo_boundary` |
| FIFO_003 | `fifo_simultaneous_read_write` | Verify concurrent handshake. | FIFO partially filled. | Assert write valid and read ready in the same cycle across mid, near-full, and near-empty states. | Data is neither lost nor duplicated; depth updates correctly. | `sync_fifo` | Medium | `cross_fifo_state_x_rw` |
| FIFO_004 | `fifo_flush_during_activity` | Verify synchronous flush. | FIFO contains data and traffic is active. | Assert `flush_i` while read/write requests are present. | Pointers clear; subsequent traffic starts from empty; no stale valid entry is exposed. | `sync_fifo`, `hci_queues` | High | `cp_fifo_flush` |
| FIFO_005 | `fifo_non_power_of_two_elaboration` | Verify documented depth restriction. | Block-level elaboration. | Instantiate `sync_fifo` with non-power-of-two depth in a negative compile test. | Elaboration fatal/assertion occurs as implemented. | `sync_fifo` | Low | `cp_param_illegal` |

### 4.3 PHY, Bus Conditions, and Timing

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| BUS_001 | `phy_reset_and_sync` | Verify PHY reset and 2FF synchronization. | Block-level PHY or top-level observation. | Toggle SCL/SDA inputs around reset. | Controller-side sampled inputs settle after synchronizer latency; reset values are high. | `i3c_phy` | Medium | `cp_phy_sync` |
| BUS_002 | `bus_start_stop_detect` | Verify START and STOP detection. | Bus monitor enabled. | Drive SDA falling/rising while SCL high with legal timing. | `start_det` and `stop_det` pulse only for legal conditions. | `bus_monitor`, `edge_detector`, `stable_high_detector` | High | `cp_bus_event` |
| BUS_003 | `bus_repeated_start_detect` | Verify repeated START detection. | A START has occurred without STOP. | Generate Sr before STOP. | `rstart_det` pulses; normal `start_det` is not confused with Sr. | `bus_monitor`, `scl_generator` | High | `cp_bus_event` |
| BUS_004 | `scl_start_stop_timing` | Verify generated START/STOP timing. | Timing CSRs programmed. | Request START and STOP through normal command flow or block-level control. | SDA/SCL sequence matches START/STOP definitions and programmed counter delays. | `scl_generator` | High | `cp_timing`, `cp_bus_event` |
| BUS_005 | `scl_clock_low_high_timing` | Verify SCL low/high periods. | Timing CSRs programmed to multiple values. | Run I3C SDR and I2C legacy transfers. | Measured low/high periods track `t_low`, `t_high`, `t_r`, and `t_f`. | `scl_generator`, `csr_registers` | High | `cp_timing_mode`, `cp_timing_value` |
| BUS_006 | `scl_waitcmd_stall_resume` | Verify clock stall behavior. | TX FIFO or RX FIFO backpressure condition available. | Force `StallWrite` or `StallRead`; later remove the stall. | SCL is held low during wait and resumes without extra START/STOP or data corruption. | `flow_active`, `scl_generator` | High | `cp_stall_type` |
| BUS_007 | `scl_repeated_start_from_waitcmd` | Verify repeated START while clock is held low. | ENTDAA or directed CCC flow active. | Request repeated START while generator is in low/wait state. | Sr is generated with legal timing; no bus hang. | `scl_generator`, `controller_active` | High | `cp_rstart_state` |
| BUS_008 | `bus_tx_byte_and_bit_order` | Verify TX serialization. | Block-level or top-level bus observation. | Send byte patterns `00`, `FF`, `A5`, `5A` and single-bit requests. | Bits are MSB-first; `bus_tx_done_o` pulses once per request; SDA setup/hold is respected. | `bus_tx`, `bus_tx_flow` | High | `cp_tx_pattern`, `cp_tx_req_type` |
| BUS_009 | `bus_rx_byte_and_bit_order` | Verify RX deserialization. | Block-level or device model drives SDA. | Receive byte patterns and ACK/NACK bits. | Data is reconstructed MSB-first; single-bit reads use bit[0]; mutual exclusion SVA passes. | `bus_rx_flow` | High | `cp_rx_pattern`, `cp_rx_req_type` |
| BUS_010 | `od_pp_phase_switch` | Verify OD/PP select by phase. | I3C write/read transfer. | Observe `sel_od_pp_o` through address, ACK, data, T-bit, START/STOP. | OD is used for START/address/ACK/STOP and ENTDAA; PP is used only for implemented I3C SDR data phases. | `controller_active`, `flow_active`, `i3c_phy` | High | `cp_odpp_phase` |
| BUS_011 | `tb_pad_model_odpp_wiring` | Verify enhanced TB pad-model wiring for SDA drive/release and OD/PP visibility. | Top-level UVM TB with `sda_oe_o` and `sel_od_pp_o` connected. | Observe `sda_oe_o`, `sda_o`, `sel_od_pp_o`, and `sda_bus` during existing I3C write/read traffic; later extend with a dedicated OD/PP pad vseq. | `tb_i3c_top` drives SDA only when `sda_oe_o=1`, releases SDA when `sda_oe_o=0`, and exposes DUT pad signals through `i3c_if`; existing smoke/write/read regressions show no SDA contention. Dedicated phase-level PP checks remain future work. | `tb_i3c_top`, `i3c_if`, `i3c_phy`, `i3c_controller_top` | Medium | `cp_pad_model`, `cp_sda_oe`, `cp_tb_odpp_visibility` |

### 4.4 I3C SDR Private Write

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| SDRW_001 | `i3c_regular_write_4b_existing` | Preserve existing write regression. | DAT[0] is I3C dynamic address `0x08`; device ACKs. | Run `i3c_write_vseq` with TX word `DEAD_BEEF`. | Bus write uses dynamic address+W; data byte order is little-endian from TX word; RESP success length 4. | Full DUT, UVM scoreboard | High | `cp_cmd_attr`, `cp_dir`, `cp_len_4` |
| SDRW_002 | `i3c_regular_write_len_sweep` | Verify write lengths and TX packing. | Device ACKs address and write data. | Write lengths 1,2,3,4,5,7,8,16 using patterned TX words. | Exact byte count transmitted; correct byte order; RESP length equals bytes transferred. | `flow_active`, `hci_queues`, `bus_tx_flow` | High | `cp_data_len`, `cp_tx_word_boundary` |
| SDRW_003 | `i3c_regular_write_data_patterns` | Verify data integrity over patterns. | Device ACKs all phases. | Send all-zero, all-one, walking-one, alternating, and random data. | Device monitor/scoreboard observes exact expected bytes and generated T-bits. | `bus_tx_flow`, `i3c_monitor`, scoreboard | Medium | `cp_data_pattern` |
| SDRW_004 | `i3c_write_tbit_parity_generation` | Verify SDR write T-bit generation. | I3C device target; bus monitor can sample T-bit. | Send data bytes with even and odd parity. | T-bit equals odd parity generation used by RTL (`~^data_byte`) for every write byte. | `flow_active`, `bus_tx_flow` | High | `cp_tbit_write_parity` |
| SDRW_005 | `i3c_write_addr_nack` | Verify address NACK response. | Device configured to NACK dynamic address. | Issue regular write. | No data bytes are transmitted; STOP/recovery occurs; RESP error is `AddrHeader`. | `flow_active`, `bus_rx_flow`, RESP FIFO | High | `cp_resp_err`, `cp_addr_ack` |
| SDRW_006 | `i3c_write_tx_fifo_empty_stall` | Verify TX underflow stall/recovery. | Write length exceeds initially available TX data. | Issue write, delay additional TX data, then provide it. | Controller stalls without corrupting bus data and resumes when TX data is available. | `flow_active`, `hci_queues`, `scl_generator` | High | `cp_stall_type`, `cp_tx_empty` |
| SDRW_007 | `i3c_write_toc_zero` | Verify no STOP when `toc=0`. | Device ACKs; next command is queued as applicable. | Issue write with `toc=0`. | RESP is produced without STOP only if current RTL/spec defines continuation; otherwise behavior is recorded as a spec gap. | `flow_active`, `scl_generator` | Medium | `cp_toc` |
| SDRW_008 | `i3c_write_back_to_back` | Verify write-to-write sequencing. | Multiple TX data words and commands queued. | Queue several write commands with unique TIDs and data. | Commands execute FIFO order; each RESP TID/length matches; no stale TX data. | `hci_queues`, `flow_active`, scoreboard | High | `cp_sequence_type`, `cross_tid_x_order` |

### 4.5 I3C SDR Private Read

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| SDRR_001 | `i3c_regular_read_4b_existing` | Preserve existing read regression. | DAT[0] is I3C dynamic address `0x08`; target returns four bytes. | Run `i3c_read_vseq`. | RX FIFO word is `32'hBEBA_FECA`; RESP success length 4. | Full DUT, UVM scoreboard | High | `cp_cmd_attr`, `cp_dir`, `cp_len_4` |
| SDRR_002 | `i3c_regular_read_len_sweep` | Verify read lengths and RX packing. | Device returns enough bytes. | Read lengths 1,2,3,4,5,7,8,16. | RX FIFO contains all bytes in little-endian DWORD packing; partial final DWORD is preserved. | `flow_active`, `hci_queues` | High | `cp_data_len`, `cp_rx_partial_dword` |
| SDRR_003 | `i3c_read_short_target_end` | Verify target early end handling. | Device returns T-bit end before requested length. | Request N bytes; target ends after M<N bytes. | RESP error is `I3cShortReadErr`; RX FIFO contains only transferred bytes. | `flow_active`, `bus_rx_flow`, RESP FIFO | High | `cp_short_read`, `cp_resp_err` |
| SDRR_004 | `i3c_read_target_more_than_requested` | Verify controller termination at requested length. | Device can provide more bytes. | Request N bytes while target indicates continuation beyond N. | Controller terminates after N bytes with STOP when `toc=1`; no extra RX bytes are stored. | `flow_active`, `scl_generator` | High | `cp_read_end_policy` |
| SDRR_005 | `i3c_read_addr_nack` | Verify address NACK response on read. | Device NACKs dynamic address+R. | Issue regular read. | No RX data is written; RESP error is `AddrHeader`; controller recovers. | `flow_active`, `bus_rx_flow` | High | `cp_resp_err`, `cp_addr_ack` |
| SDRR_006 | `i3c_read_rx_fifo_full_stall` | Verify RX backpressure. | RX FIFO is full before final data flush. | Issue read, hold RX full, then drain RX. | Controller stalls safely and resumes; no data loss. | `flow_active`, `hci_queues`, `scl_generator` | High | `cp_rx_full`, `cp_stall_type` |
| SDRR_007 | `i3c_read_data_patterns` | Verify read data integrity. | Device sequence can drive arbitrary data. | Return zero, one, alternating, walking, and random byte patterns. | RX FIFO contents match target data exactly. | `i3c_driver`, `bus_rx_flow`, scoreboard | Medium | `cp_data_pattern` |
| SDRR_008 | `i3c_read_no_parity_error_on_end_tbit` | Verify read T-bit semantics. | Target ends transfer with T-bit=0. | Run read where final T-bit is 0. | Controller treats T-bit=0 as end/short-read indicator, not as parity error. `Parity` response is not expected in current RTL. | `flow_active` | High | `cp_read_tbit`, `cp_resp_err` |

### 4.6 Immediate Data Transfer

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| IMM_001 | `i3c_immediate_write_smoke_existing` | Preserve existing immediate smoke. | DAT[0] I3C device; target ACKs. | Run `i3c_smoke_vseq`. | Two inline data bytes are transmitted; RESP success. | `flow_active`, `bus_tx_flow`, UVM | High | `cp_imm`, `cp_len_2` |
| IMM_002 | `i3c_immediate_write_dtt_sweep` | Verify inline data byte count. | DAT[0] I3C device. | Issue immediate commands with `dtt` values covering 0..4 valid bytes. | Correct number of inline bytes are transmitted; no TX FIFO access occurs. | `flow_active`, CMD descriptor | High | `cp_imm_dtt` |
| IMM_003 | `i3c_immediate_write_toc` | Verify immediate STOP control. | Target ACKs. | Repeat immediate command with `toc=1` and `toc=0`. | `toc=1` generates STOP; `toc=0` behavior matches RTL/spec or is documented as a gap. | `flow_active`, `scl_generator` | Medium | `cp_toc`, `cp_imm` |
| IMM_004 | `i2c_immediate_write_basic` | Verify immediate path for legacy I2C DAT entry. | DAT[0].`device=1`; static address programmed. | Issue I2C immediate write with 1..4 bytes. | OD-only static address+W, data ACKs, RESP length equals bytes transferred. | `flow_active`, `bus_tx_flow` | High | `cp_i2c`, `cp_imm` |
| IMM_005 | `immediate_addr_nack` | Verify address NACK for immediate transfer. | Target NACKs address. | Issue I3C and I2C immediate writes. | No data phase after NACK; RESP error is `AddrHeader`; controller returns idle. | `flow_active`, `bus_rx_flow` | High | `cp_resp_err`, `cross_imm_x_device_type` |
| IMM_006 | `immediate_data_nack_i2c` | Verify I2C immediate data NACK handling. | I2C target ACKs address and NACKs one data byte. | Issue multi-byte I2C immediate write. | RESP error is `Nack`; transfer stops/recover behavior follows RTL/spec. | `flow_active` | High | `cp_data_ack`, `cp_resp_err` |

### 4.7 Common Command Codes

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| CCC_001 | `ccc_entdaa_opening_frame` | Verify ENTDAA broadcast opening frame. | AddressAssignment CMD queued; device ACKs broadcast header and CCC. | Issue `AddressAssignment` with `cmd=0x07`. | Bus shows START, `7'h7E+W`, ACK, `8'h07`, ACK before ENTDAA rounds. | `flow_active`, `bus_tx_flow`, `bus_rx_flow` | High | `cp_ccc_opcode`, `cp_entdaa_phase` |
| CCC_002 | `ccc_broadcast_enec_frame` | Verify broadcast ENEC frame generation as implemented. | Immediate CMD with `cp=1`, `cmd=8'h00`; target ACKs. | Send event byte/defining data according to descriptor convention. | Bus frame matches current ENEC implementation; any missing defining-byte behavior is recorded as implementation gap. | `flow_active`, `i3c_monitor` | High | `cp_ccc_opcode`, `cp_ccc_broadcast` |
| CCC_003 | `ccc_broadcast_disec_frame` | Verify broadcast DISEC frame generation as implemented. | Immediate CMD with `cp=1`, `cmd=8'h01`; target ACKs. | Send event byte/defining data according to descriptor convention. | Bus frame matches current DISEC implementation; no ENTDAA controller activation. | `flow_active` | High | `cp_ccc_opcode`, `cp_ccc_broadcast` |
| CCC_004 | `ccc_direct_enec_frame` | Verify direct ENEC frame. | DAT dynamic address valid; target ACKs broadcast and direct address. | Immediate CMD with `cp=1`, `cmd=8'h80`, one data byte. | Bus shows broadcast header, CCC, Sr, target dynamic address+W, data/T-bit, STOP. | `flow_active`, `scl_generator` | High | `cp_ccc_direct`, `cp_rstart` |
| CCC_005 | `ccc_direct_disec_frame` | Verify direct DISEC frame. | DAT dynamic address valid; target ACKs. | Immediate CMD with `cp=1`, `cmd=8'h81`. | Direct DISEC frame is emitted; RESP success if all ACKs are received. | `flow_active` | High | `cp_ccc_opcode`, `cp_ccc_direct` |
| CCC_006 | `ccc_broadcast_header_nack` | Verify CCC NACK recovery. | Device NACKs `7'h7E+W` or CCC byte ACK slot. | Issue ENEC/DISEC/ENTDAA command. | Controller reports an implemented error status or the gap is documented; no hang is allowed for sign-off. | `flow_active`, RESP FIFO | High | `cp_ccc_nack`, `cp_resp_err` |
| CCC_007 | `ccc_direct_target_nack` | Verify direct CCC target address NACK. | Target ACKs broadcast header and CCC, NACKs direct address. | Issue direct ENEC/DISEC. | No direct data byte is sent after address NACK; RESP and bus recovery match RTL/spec. | `flow_active` | High | `cp_ccc_direct`, `cp_addr_ack` |
| CCC_008 | `ccc_unsupported_opcode_policy` | Define behavior for unsupported CCC opcodes. | Immediate CMD `cp=1`, opcode outside ENEC/DISEC/ENTDAA. | Issue representative unsupported broadcast and direct opcodes. | Current RTL lacks explicit opcode validation; expected result is documented behavior or a required `NotSupported` enhancement. | `flow_active`, `i3c_pkg` | Medium | `cp_unsupported_cmd` |

### 4.8 Dynamic Address Assignment / ENTDAA

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| DAA_001 | `entdaa_single_device_success` | Verify one successful ENTDAA round. | DAT[0] contains dynamic address; target can drive PID/BCR/DCR and ACK address. | Issue AddressAssignment with `dev_idx=0`, `dev_count=1`. | ENTDAA frame completes; assigned address byte uses correct parity; RESP success; RX visibility follows implemented policy. | `flow_active`, `entdaa_controller`, `entdaa_fsm` | High | `cp_daa_count`, `cp_daa_result` |
| DAA_002 | `entdaa_no_device` | Verify no-device exit. | No target ACKs `7'h7E+R`. | Issue AddressAssignment. | `entdaa_fsm` enters no-device path; STOP generated; response completes without assignment result. | `entdaa_fsm`, `entdaa_controller` | High | `cp_daa_no_device` |
| DAA_003 | `entdaa_fewer_devices_than_count` | Verify early exit when fewer devices respond than requested. | `dev_count` > actual responders. | First M rounds ACK; next `7'h7E+R` NACKs. | Loop exits after no-device NACK; no out-of-range extra assignment. | `entdaa_controller` | High | `cp_daa_count`, `cp_daa_no_device` |
| DAA_004 | `entdaa_multi_device_dat_loop` | Verify DAT index increment across rounds. | Multiple DAT entries programmed; multi-target UVM support available. | Issue `dev_idx=N`, `dev_count=K`. | DAT indices `N..N+K-1` are used; repeated START precedes each round; K addresses assigned if K targets respond. | `entdaa_controller`, `csr_registers` | High | `cp_daa_index`, `cp_rstart_count` |
| DAA_005 | `entdaa_address_parity_sweep` | Verify assigned address parity. | Target ACKs assigned addresses. | Sweep representative dynamic addresses including low, high, alternating patterns. | Sent address parity bit matches odd parity calculation. | `entdaa_fsm`, `bus_tx_flow` | High | `cp_daa_addr`, `cp_daa_parity` |
| DAA_006 | `entdaa_address_rejected` | Verify target NACK of assigned address. | Target ACKs `7'h7E+R`, drives PID/BCR/DCR, then NACKs address. | Issue AddressAssignment. | `addr_valid_o` is not asserted; loop continues or completes according to `dev_count`/no-device behavior. | `entdaa_fsm`, `entdaa_controller` | High | `cp_daa_addr_ack` |
| DAA_007 | `entdaa_pid_bcr_dcr_capture` | Verify identity capture. | Target drives known PID/BCR/DCR values. | Run successful ENTDAA. | Internal captured PID/BCR/DCR match target; software-visible RX data format is verified against RTL or documented as spec gap. | `entdaa_fsm`, `flow_active`, RX FIFO | High | `cp_daa_pid`, `cp_daa_bcr`, `cp_daa_dcr` |
| DAA_008 | `entdaa_dat_boundary` | Verify DAT boundary behavior. | Program `dev_idx` near last DAT entry. | Run `dev_idx=15`, `dev_count=1`, then `dev_idx=15`, `dev_count>1`. | Single entry works; out-of-range case follows current saturation behavior or is documented as SW responsibility. | `entdaa_controller`, `csr_registers` | Medium | `cp_dat_boundary` |
| DAA_009 | `entdaa_stop_mid_round` | Verify STOP/abort handling during DAA. | External/device model can force STOP-like bus condition or reset. | Interrupt during PID/BCR/DCR reception. | ENTDAA terminates to Done/NoDev path and controller returns idle or gap is documented. | `entdaa_fsm`, `entdaa_controller`, `bus_monitor` | Medium | `cp_daa_abort_point` |
| DAA_010 | `entdaa_two_target_arbitration` | Verify wired-AND arbitration across multiple targets. | UVM bus model supports simultaneous target driving. | Two unaddressed targets drive different PID bits; losing target stops participating. | Master assigns arbitration winner first, then remaining target in later round. | UVM I3C agent, bus, `entdaa_fsm` | Future | `cp_daa_arbitration` |

### 4.9 I2C Legacy Compatibility

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| I2C_001 | `i2c_regular_write_basic` | Verify I2C legacy write path. | DAT[0].`device=1`, static address programmed, target ACKs. | Issue RegularTransfer write of 1 and 4 bytes. | Static address+W is used; OD mode throughout; data bytes are ACKed; RESP success. | `flow_active`, `scl_generator`, `bus_tx_flow` | High | `cp_device_type`, `cp_i2c_dir` |
| I2C_002 | `i2c_regular_read_basic` | Verify I2C legacy read path. | DAT[0].`device=1`; target returns data. | Issue RegularTransfer read of 1 and 4 bytes. | Static address+R is used; master ACKs intermediate bytes and NACKs final byte; RX data correct. | `flow_active`, `bus_rx_flow`, `bus_tx_flow` | High | `cp_i2c_dir`, `cp_i2c_ack_seq` |
| I2C_003 | `i2c_len_sweep_partial_rx` | Verify I2C read/write length behavior. | I2C target model active. | Run I2C writes and reads of 1,2,3,4,5,7,8 bytes. | Correct TX/RX packing; partial RX DWORD preserved; RESP length correct. | `flow_active`, `hci_queues` | High | `cp_data_len`, `cp_rx_partial_dword` |
| I2C_004 | `i2c_addr_nack` | Verify I2C address NACK. | Target NACKs static address. | Issue read and write commands. | No data phase; RESP error is `AddrHeader`; bus returns idle. | `flow_active`, `bus_rx_flow` | High | `cp_resp_err`, `cp_i2c_addr_ack` |
| I2C_005 | `i2c_data_nack_write` | Verify I2C data-byte NACK. | Target ACKs address and NACKs byte M. | Issue multi-byte write. | Transfer stops or recovers according to RTL/spec; RESP error is `Nack`; next legal transfer passes. | `flow_active` | High | `cp_data_ack`, `cp_resp_err` |
| I2C_006 | `i2c_od_only_check` | Verify legacy transfers remain open-drain. | I2C read and write commands. | Observe `sel_od_pp_o` and SDA drive during address/data/ACK. | `sel_od_pp_o` remains OD for entire I2C transaction. | `controller_active`, `i3c_phy` | High | `cp_odpp_phase`, `cp_i2c` |
| I2C_007 | `i2c_timing_400k_equivalent` | Verify configured I2C timing path. | Timing registers programmed for I2C FM-equivalent values at TB clock. | Run representative I2C read/write. | SCL low/high and START/STOP timing match programmed counters. | `csr_registers`, `scl_generator` | Medium | `cp_timing_mode` |

### 4.10 Error Handling, Status, and Recovery

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| ERR_001 | `resp_success_tid_length` | Verify successful RESP descriptor fields. | Valid transactions with unique TIDs. | Run immediate, regular write, regular read, and ENTDAA success paths. | RESP `[31:28]=Success`, `[27:24]=TID`, `[15:0]=actual length`. | `flow_active`, RESP FIFO | High | `cp_resp_err`, `cp_tid`, `cp_resp_len` |
| ERR_002 | `resp_addr_header_error` | Verify address NACK error. | Device NACKs address. | Run I3C write/read, I2C write/read, and direct CCC address phases. | RESP error is `AddrHeader` where current RTL supports it; no data phase after address NACK. | `flow_active` | High | `cp_resp_err`, `cp_addr_ack` |
| ERR_003 | `resp_data_nack_error` | Verify data NACK error for I2C write-style phases. | Target NACKs data byte. | Run I2C write/immediate write with data NACK. | RESP error is `Nack`; transfer recovers. | `flow_active` | High | `cp_data_ack`, `cp_resp_err` |
| ERR_004 | `resp_short_read_error` | Verify short read response. | Target ends I3C read early. | Request N bytes, target ends after M<N. | RESP error is `I3cShortReadErr`; length reflects actual received bytes. | `flow_active` | High | `cp_short_read`, `cp_resp_err` |
| ERR_005 | `resp_unreachable_error_codes` | Document defined but unused error codes. | Code review plus directed unsupported stimuli. | Attempt CRC, Frame, Ovl, HcAborted, NotSupported, Parity scenarios. | Current RTL has no production paths for these codes; results are N/A or enhancement requests, not expected positive coverage. | `i3c_pkg`, `flow_active` | Low | `cp_error_code_reachability` |
| ERR_006 | `resp_fifo_full_backpressure` | Verify response write stalls safely. | RESP FIFO full before transaction completes. | Complete a transfer while RESP full, then drain RESP. | FSM waits in response write phase; exactly one response is eventually written. | `flow_active`, `hci_queues` | High | `cp_resp_full`, `cp_stall_type` |
| ERR_007 | `reset_during_idle` | Verify reset in idle. | DUT idle. | Assert/deassert `rst_ni`. | Registers/queues/FSM return to reset state; bus released. | Full DUT | High | `cp_reset_point` |
| ERR_008 | `reset_during_transfer_phases` | Verify reset during active operation. | Transfer in progress. | Reset during START, address ACK, data TX, data RX, DAA, and WriteResp phases. | Bus releases; no partial unintended queue pop/push after reset; next legal transfer passes. | Full DUT | High | `cp_reset_point`, `cross_reset_x_phase` |
| ERR_009 | `sw_reset_while_busy_policy` | Clarify SW reset during active transfer. | Transfer in progress. | Assert `HC_CONTROL[1]` while not idle. | Current spec says this is undefined; test documents behavior and recommends SW only reset when `FSM_IDLE=1`. | `csr_registers`, `hci_queues`, `flow_active` | Medium | `cp_sw_reset_busy` |
| ERR_010 | `bus_stuck_scl_low` | Identify bus recovery gap. | Device/bus model can hold SCL low or prevent progress. | Hold SCL low during transfer. | Current design has no complete bus recovery/timeout; test should fail by timeout or document gap. | `scl_generator`, `bus_monitor` | Medium | `cp_bus_stuck` |
| ERR_011 | `invalid_descriptor_attr` | Verify unsupported descriptor behavior. | CMD descriptors can be written directly. | Issue `ComboTransfer`, reserved attr, HDR mode values, and invalid mode encodings. | No unbounded hang or illegal queue corruption; expected protocol behavior must be specified before sign-off. | `flow_active`, CMD descriptor parsing | Medium | `cp_invalid_cmd` |

### 4.11 Arbitration and Bus Behavior

| ID | Test Name | Objective | Preconditions | Stimulus / Actions | Expected Results | Related Modules / Interfaces | Priority | Coverage Goals |
|---|---|---|---|---|---|---|---|---|
| ARB_001 | `entdaa_single_bit_arbitration_observe` | Verify ENTDAA bit-level receiver samples wired bus. | DAA target drives known PID bits. | During ENTDAA, observe each PID/BCR/DCR bit sampled by `bus_rx_flow`. | Captured 64-bit identity matches bus data. | `entdaa_fsm`, `bus_rx_flow`, bus model | High | `cp_daa_bit_pos` |
| ARB_002 | `entdaa_multi_target_arbitration_future` | Verify true multi-target DAA arbitration. | Multi-target simultaneous drive model added. | Two or more targets participate with different PIDs. | Wired-AND arbitration winner is assigned first; losing target retries later. | UVM bus model, `entdaa_fsm` | Future | `cp_daa_arbitration` |
| ARB_003 | `unexpected_stop_during_command` | Verify STOP detection during active command. | Bus model can force STOP or reset-like condition. | Inject STOP-like SDA rise while SCL high during DAA or data phase. | Implemented modules terminate or test records missing recovery behavior. | `bus_monitor`, `flow_active`, `entdaa_controller` | Medium | `cp_unexpected_bus_event` |
| ARB_004 | `start_when_bus_not_idle` | Verify controller behavior if command starts on busy bus. | Bus held non-idle before command. | Queue command while SCL/SDA not both high. | Current RTL behavior is documented; if unsupported, SW precondition must require idle bus before command. | `scl_generator`, `bus_monitor` | Medium | `cp_bus_busy_start` |

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
| CSR reset/control/status | CSR_001, CSR_002, CSR_003, CSR_011 | `cp_csr_addr`, `cp_reset`, `cp_enable` |
| DAT programming and selection | CSR_004, DAA_004, DAA_008, STR_002 | `cp_dat_idx`, `cp_device_type`, `cp_dat_boundary` |
| CMD/TX/RX/RESP queues | CSR_005, CSR_007, CSR_009, FIFO_001..FIFO_004, STR_004 | `cp_fifo_kind`, `cp_fifo_state`, `cp_fifo_boundary` |
| START/STOP/Sr | BUS_002, BUS_003, BUS_004, BUS_007, CCC_004, DAA_001 | `cp_bus_event`, `cp_rstart`, `cp_timing` |
| SCL timing and stalls | BUS_005, BUS_006, SDRW_006, SDRR_006, I2C_007 | `cp_timing_mode`, `cp_stall_type` |
| I3C private write | SDRW_001..SDRW_008 | `cp_dir`, `cp_data_len`, `cp_tbit_write_parity` |
| I3C private read | SDRR_001..SDRR_008 | `cp_dir`, `cp_rx_partial_dword`, `cp_read_tbit` |
| Immediate transfer | IMM_001..IMM_006 | `cp_imm`, `cp_imm_dtt`, `cross_imm_x_device_type` |
| CCC | CCC_001..CCC_008 | `cp_ccc_opcode`, `cp_ccc_direct`, `cp_ccc_broadcast`, `cp_ccc_nack` |
| ENTDAA | DAA_001..DAA_010 | `cp_daa_count`, `cp_daa_addr`, `cp_daa_result`, `cp_daa_arbitration` |
| I2C legacy | I2C_001..I2C_007 | `cp_i2c_dir`, `cp_i2c_ack_seq`, `cp_device_type` |
| Error handling | ERR_001..ERR_011 | `cp_resp_err`, `cp_addr_ack`, `cp_short_read`, `cp_invalid_cmd` |
| UVM infrastructure | UVM_001..UVM_008 | Checker validation and regression gates |
| Stress/performance | STR_001..STR_005, PERF_001..PERF_003 | Cross coverage closure and latency metrics |

## 6. Functional Coverage Plan

### 6.1 Coverpoints

| Coverpoint | Bins |
|---|---|
| `cp_cmd_attr` | `ImmediateDataTransfer`, `RegularTransfer`, `AddressAssignment`, `ComboTransfer/unsupported`, reserved |
| `cp_device_type` | I3C DAT entry, I2C legacy DAT entry |
| `cp_dir` | Write, Read |
| `cp_data_len` | 0, 1, 2, 3, 4, 5-7, 8-15, 16+ |
| `cp_data_pattern` | zero, all-one, alternating A/5, walking-one, random |
| `cp_toc` | 0, 1 |
| `cp_resp_err` | Success, AddrHeader, Nack, I3cShortReadErr, unreachable-defined-codes |
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
| `prev_cmd_attr x next_cmd_attr` | Cover back-to-back sequencing across command classes. |

## 7. Missing Information and Required Clarifications

| Gap | Impact on verification |
|---|---|
| ENEC/DISEC exact descriptor encoding is not fully specified in public docs/source comments. | CCC tests can verify emitted bus frames, but pass/fail for defining/event byte policy needs a clarified spec. |
| Unsupported descriptor policy is not defined. | Tests for `ComboTransfer`, HDR modes, reserved modes, and unsupported CCCs should currently be negative/documentation tests, not strict feature tests. |
| DAA software-visible result format should be clarified. | RTL forwards DAA PID/BCR/DCR/address toward RX FIFO, but the exact software consumption contract should be documented before sign-off. |
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
