# I3C Controller Functional Coverage Matrix

## 1. Mục đích và phạm vi

Tài liệu này định nghĩa functional coverage cho phạm vi RTL hiện có của I3C active controller:

- CSR, DAT và các cổng queue;
- command descriptor và response descriptor;
- I3C SDR private write/read;
- immediate transfer;
- I2C legacy write/read;
- CCC ENEC, DISEC và ENTDAA;
- Dynamic Address Assignment (DAA);
- FIFO, reset, abort, backpressure và protocol timing.

Matrix được xây dựng theo **feature trước**, sau đó mới chọn **nguồn quan sát** phù hợp. Một feature có thể cần nhiều nguồn quan sát, nhưng cùng một hành vi nội bộ không được tạo lại bằng UVM coverpoint nếu SVA đã quan sát chính xác.

Các feature không có trong RTL hiện tại như IBI, Hot-Join, HDR, multi-controller, target mode và interrupt controller không được tính vào coverage closure.

## 2. Quy ước trạng thái

| Trạng thái | Ý nghĩa |
|---|---|
| `Implemented` | Coverpoint/cross đã tồn tại trong collector hiện tại và compile; không cam kết mọi bin đã được hit. Bin cần negative stimulus phải có dedicated test hoặc waiver khi sign-off. |
| `SVA` | Hành vi đã được quan sát bằng `cover property` hoặc covergroup bind vào RTL. |
| `Planned` | Cần bổ sung vào collector trong bước tiếp theo. |
| `Excluded` | Ngoài phạm vi hoặc không reachable trong RTL hiện tại; phải có waiver khi sign-off. |

## 3. Kiến trúc quan sát

| Nguồn quan sát | Collector | Dữ liệu đáng tin cậy | Không nên đặt tại đây |
|---|---|---|---|
| Register monitor | `reg_coverage` | Địa chỉ CSR, read/write, write data, read data, DAT index, command descriptor được ghép từ hai DWORD | ACK/NACK thực tế trên bus, số byte thực tế, FSM state |
| I3C bus monitor | `i3c_coverage` | Address, direction, I3C/I2C, START/Sr/STOP, broadcast header, ACK/NACK/T-bit, CCC, byte count, abort | Command intent chưa được correlation với register stream, internal FIFO/FSM state |
| Response observation | `reg_coverage.cg_resp_desc`, decode từ lần đọc hợp lệ tại `RESP_PORT` | `err_status`, `tid`, reserved bits, actual length | Suy đoán bus result chỉ từ response code; kiểm tra TID bằng command khi chưa correlation |
| Correlated transaction | Planned coverage model đặt cạnh scoreboard | Command intent × DAT/device × bus result × response | Sampling hai stream độc lập mà không ghép theo command/TID |
| RTL/SVA | Các file trong `i3c_core/sva/` | FSM transition, handshake, stall, timing counter, reset point, OD/PP phase, FIFO boundary | Bus-level payload/address coverage đã có trong monitor |

### 3.1 Quy tắc sampling

1. `cg_reg_access` sample một lần cho mỗi `reg_seq_item` do register monitor phát ra. `cp_addr_class` ưu tiên phân loại misaligned trước, sau đó mới phân biệt mapped và aligned-unmapped.
2. `cg_dat_entry` chỉ sample khi address thuộc DAT window và word-aligned; dùng `wdata` cho write và `rdata` cho read.
3. `cg_cmd_desc` chỉ sample sau khi nhận đủ DWORD0 và DWORD1 của `CMD_QUEUE_PORT`.
4. Bus covergroup chỉ sample khi monitor hoàn tất một `i3c_item`, không sample từng clock.
5. `cg_resp_desc` chỉ sample khi phần mềm đọc `RESP_PORT` và `resp_valid_i=1`; đọc FIFO rỗng trả về `32'h0` không được tính là response `Success/TID=0/length=0`.
6. `cg_hc_control` sample mỗi access `HC_CONTROL`, dùng `wdata` cho write và `rdata` cho read; field transition phản ánh chuỗi giá trị CSR mà phần mềm ghi/đọc được.
7. `cg_timing_csr` sample mỗi access timing CSR, dùng `wdata` cho write và `rdata` cho read. Default được so theo reset value của đúng địa chỉ; reserved upper-bit attempt chỉ lấy từ write data.
8. `cg_queue_sw_port` sample accepted software request: CMD chỉ sau DWORD thứ hai, TX trên write `PIO_DATA_PORT`, RX trên read `PIO_DATA_PORT`, RESP trên read `RESP_PORT`. FIFO handshake và empty-pop vẫn do SVA cover.
9. Correlated covergroup chỉ sample khi scoreboard đã ghép xong command, bus transaction và response tương ứng. Với success `wroc=0`, sample bằng event hoàn tất không-response thay vì chờ `RESP_PORT`.
10. Reset hủy command staging và mọi partial correlation context. Busy software reset không được hủy context vì policy hiện tại coi thao tác đó là no-op.
11. Illegal/reserved bins dùng cho negative test; các giá trị không thể sinh bởi RTL phải là `ignore_bins` hoặc được waiver, không để làm giảm coverage vô hạn.

## 4. Register và command descriptor coverage

### 4.1 Register access

| ID | Feature/scenario | Coverage item và bins | Nguồn | Test/vseq chính | Trạng thái |
|---|---|---|---|---|---|
| REG-001 | Loại truy cập | `cp_access_type`: read, write | Register monitor | Tất cả CSR vseq | `Implemented` |
| REG-002 | Nhóm địa chỉ CSR | `cp_addr`: HC control/reset/status, CMD/RESP/PIO/queue status, từng timing CSR, DAT table | Register monitor | `csr_reset_defaults_vseq`, `csr_timing_rw_vseq` | `Implemented` |
| REG-003 | Access × address | `cx_access_addr`: read/write cho từng mapped register bin | Register monitor | Tất cả CSR vseq | `Implemented` |
| REG-004 | DAT entry index | `cp_dat_idx`: từng index 0..31, sample khi address thuộc DAT window và word-aligned | Register monitor | `csr_dat_rw_all_entries_vseq` | `Implemented` |
| REG-005 | DAT access × index | `cx_access_dat_idx`: read/write × DAT[0..31] | Register monitor | `csr_dat_rw_all_entries_vseq` | `Implemented` |
| REG-006 | Unmapped register access | `cp_addr_class`: mapped, aligned-unmapped, misaligned; `cx_access_addr_class`: read/write × address class | Register monitor | `csr_unmapped_addr_no_side_effect_vseq` | `Implemented` |
| REG-007 | HC enable | `cg_hc_control.cp_bus_enable`: 0, 1; transition 0=>1, 1=>0. Reset semantics do SVA cover | Register monitor + SVA | `csr_enable_disable_vseq` | `SVA` + `Implemented` |
| REG-008 | Broadcast header enable | `cp_broadcast_enable`: 0, 1; `cx_bus_broadcast` với BUS_ENABLE | Register monitor + SVA | `csr_broadcast_header_control_vseq` | `SVA` + `Implemented` |
| REG-009 | HC abort control | `cp_hc_abort`: 0, 1; transition set/clear. Idle/active và hold do SVA cover | Register monitor + SVA | `csr_hc_abort_control_vseq`, abort vseqs | `SVA` + `Implemented` |
| REG-010 | Software reset request | `cp_idle_reset_control_write_pulses_soft_reset`: idle accepted; `cp_busy_reset_control_write_ignored`: busy ignored; `cp_sw_reset_self_clear`: accepted pulse tự clear | SVA | `csr_sw_reset_flush_queues_vseq`, `i3c_sw_reset_while_busy_policy_vseq` | `SVA` |
| REG-011 | Timing register value class | `cg_timing_csr`: `cp_timing_value` zero/one/middle/max, `cp_timing_default` default/non-default theo địa chỉ, `cp_timing_reserved_upper` clear/write-attempt | Register monitor | `csr_timing_rw_vseq` | `Implemented` |
| REG-012 | Timing CSR × value class | `cx_timing_reg_value`, `cx_timing_reg_default`, `cx_timing_reg_reserved` | Register monitor | `csr_timing_rw_vseq` | `Implemented` |
| REG-013 | DAT device type | `cg_dat_entry.cp_device`: I3C (`device=0`), legacy I2C (`device=1`); `cx_access_device`: read/write × device | Register monitor | `csr_dat_rw_all_entries_vseq`, I2C vseqs | `Implemented` |
| REG-014 | DAT address class | `cp_static_addr`, `cp_dynamic_addr`: zero, low `0x01..0x07`, usable `0x08..0x77`, high `0x78..0x7f`; cross từng field với read/write; `cp_reserved_write_attempt`: clean, attempted | Register monitor | DAT, SDR, I2C và DAA vseqs | `Implemented` |
| REG-015 | Queue software port usage | `cg_queue_sw_port.cp_queue_op`: accepted CMD push, TX push, RX pop, RESP pop request | Register monitor | CSR queue và transfer vseqs | `Implemented` |
| REG-016 | Empty RX/RESP read | RX empty, RESP empty; returned data zero | SVA | `csr_rx_resp_read_pop_vseq` | `SVA` |

### 4.2 Command descriptor

| ID | Feature/scenario | Coverage item và bins | Nguồn | Test/vseq chính | Trạng thái |
|---|---|---|---|---|---|
| CMD-001 | Descriptor attribute | `cp_cmd_attr`: Regular, Immediate, AddressAssignment, Combo, reserved 4..7 | Register monitor | SDR/IMM/DAA và invalid descriptor vseqs | `Implemented` |
| CMD-002 | Direction | `cp_cmd_rnw`: write, read; `iff` attribute có RNW | Register monitor | SDR read/write, I2C read/write | `Implemented` |
| CMD-003 | Terminate on completion | `cp_cmd_toc`: continue (`0`), terminate (`1`) | Register monitor | `i3c_write_toc_zero_vseq`, `i3c_read_toc_zero_vseq`, `i3c_imm_toc_vseq` | `Implemented` |
| CMD-004 | Response on completion | `cp_cmd_wroc`: suppress-success (`0`), response-required (`1`) | Register monitor | `i3c_wroc_policy_vseq` | `Implemented` |
| CMD-005 | Regular/Combo data length | `cp_cmd_data_len`: 0, 1, 2..4, 5..8, 9..16, 17..65535 | Register monitor | read/write length sweep | `Implemented` |
| CMD-006 | Immediate DTT | `cp_cmd_dtt`: từng valid 0..4, từng reserved 5..7 | Register monitor | `i3c_imm_dtt_sweep_vseq`, invalid descriptor vseq | `Implemented` |
| CMD-007 | DAA device count | `cp_cmd_dev_count`: 0, từng value 1..15 | Register monitor | DAA vseqs | `Implemented` |
| CMD-008 | Descriptor DAT index | `cp_cmd_dat_idx`: từng index 0..31 cho known attribute | Register monitor | multi-DAT và DAA boundary vseqs | `Implemented` |
| CMD-009 | Regular direction × length | `cx_regular_rnw_len` | Register monitor | read/write length sweep | `Implemented` |
| CMD-010 | Attribute × TOC | `cx_cmd_attr_toc`, bỏ reserved attribute | Register monitor | TOC và descriptor vseqs | `Implemented` |
| CMD-011 | Transaction ID | `cp_cmd_tid`: từng TID 0..15 | Register monitor | back-to-back vseqs | `Planned` |
| CMD-012 | Transfer mode | `cp_cmd_mode`: SDR0..SDR4, HDR/reserved negative bins | Register monitor | normal transfer và invalid descriptor vseq | `Planned` |
| CMD-013 | Command-present bit | `cp_cmd_present`: 0, 1; cross với attribute | Register monitor | CCC/regular và invalid descriptor vseqs | `Planned` |
| CMD-014 | CCC opcode in descriptor | `cp_cmd_code`: ENEC, DISEC, ENTDAA, other supported, unsupported | Register monitor | CCC vseqs | `Planned` |
| CMD-015 | Regular SRE/DBP | `cp_sre`, `cp_dbp`: 0, 1; applicability/unsupported policy | Register monitor | short-read và invalid descriptor vseq | `Planned` |
| CMD-016 | Command staging | first DWORD only, unrelated CSR interleave, completed pair, reset-cleared partial pair | SVA | CMD staging CSR vseqs | `SVA` |
| CMD-017 | Attribute × device type | Regular/Immediate × I3C/I2C; AddressAssignment × I3C only; invalid combinations | Correlated | SDR, IMM, I2C, DAA vseqs | `Planned` |
| CMD-018 | Attribute × DAT index | known command class × 0..31; use bins/groups if full Cartesian product is not a requirement | Register/correlated | multi-DAT và DAA boundary vseqs | `Planned` |
| CMD-019 | Previous × next command | Regular W/R, Immediate, CCC, DAA transitions; only legal/reachable combinations | Correlated | back-to-back và TOC continuation vseqs | `Planned` |

## 5. Bus transaction coverage

Các mục trong phần này thuộc `i3c_coverage`. Collector hiện tại mới là skeleton, vì vậy toàn bộ coverpoint UVM bus-level đang ở trạng thái `Planned`; các dòng ghi `SVA` đã có cover độc lập ở RTL.

### 5.1 Common transaction framing

| ID | Feature/scenario | Coverage item và bins | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| BUS-001 | Protocol type | `cp_protocol`: I3C, I2C | Tất cả transfer vseqs | `Planned` |
| BUS-002 | Bus direction | `cp_bus_op`: write, read | SDR và I2C vseqs | `Planned` |
| BUS-003 | Address class | broadcast `0x7e`, I3C dynamic, I2C static, reserved/other negative | CSR broadcast, SDR, I2C, CCC, DAA | `Planned` |
| BUS-004 | Address ACK | ACK, NACK; separate broadcast-header ACK và target ACK | success và NACK vseqs | `Planned` |
| BUS-005 | Actual byte count | 0, 1, 2..4, 5..8, 9..16, 17..64, >64 | length sweep, abort/overflow | `Planned` |
| BUS-006 | Data pattern | all-zero, all-one, `AA/55`, walking bit, random/other | TX/RX byte-order và length sweep | `Planned` |
| BUS-007 | Start source | START, repeated START | TOC, direct CCC, DAA | `Planned` |
| BUS-008 | End condition | STOP, RSTART, interrupted/aborted | TOC, abort, short-read | `Planned` |
| BUS-009 | Private preamble | dynamic-first, `0x7e/W + Sr + dynamic` | broadcast control, SDR read/write | `Planned` |
| BUS-010 | Transaction abort flag | normal, aborted, interrupted read | abort/reset vseqs | `Planned` |
| BUS-011 | Protocol × direction × length | Legal I3C/I2C read/write length combinations | length sweep | `Planned` |
| BUS-012 | Address class × ACK | ACK/NACK ở broadcast, dynamic, static và direct CCC address | NACK vseqs | `Planned` |
| BUS-013 | Preamble × direction | enabled/disabled private preamble × read/write | CSR broadcast, SDR vseqs | `Planned` |
| BUS-014 | START/STOP/Sr detection | Legal sequence, glitch reject, enable gating, one-cycle pulse | focused bus vseqs | `SVA` |
| BUS-015 | SCL timing | START, STOP, PP low, OD low, WaitCmd stall/resume, repeated START | focused SCL vseqs | `SVA` |
| BUS-016 | OD/PP phase | START/address/ACK/STOP/DAA OD; I3C data PP; I2C always OD | SDR/I2C/CCC/DAA | `SVA` |
| BUS-017 | TX/RX serialization | Byte/bit request, `00`, `ff`, `a5`, `96`, MSB-first | byte-order vseqs | `SVA` + `Planned` payload pattern |

### 5.2 I3C SDR private transfer

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| SDR-001 | SDR private write | direction=write, actual length bins, data integrity pass | write baseline/length/back-to-back | `Planned` |
| SDR-002 | SDR private read | direction=read, actual length bins, partial DWORD 1/2/3 bytes | read baseline/length/back-to-back | `Planned` |
| SDR-003 | Write T-bit | T-bit 0, 1; parity match `~^byte` | write vseqs | `SVA` |
| SDR-004 | Read T-bit outcome | continue, end exactly requested length, early end, continue beyond requested | read target-end vseqs | `Planned` + `SVA` |
| SDR-005 | Zero-length write | address ACK then no data/T-bit, success length 0 | `i3c_write_len_sweep_vseq` | `SVA` |
| SDR-006 | Partial final DWORD | byte remainder 1, 2, 3, 0 | read/write length sweep | `Planned` + `SVA` read |
| SDR-007 | TOC continuation | TOC0 accepted, missing continuation, unsupported continuation, TOC1 stop | TOC-zero vseqs | `SVA` |
| SDR-008 | Multi-DAT target | DAT index/address 0, 1, boundary indices; payload remains per target | multi-DAT vseqs | `Planned` + `SVA` selected indices |
| SDR-009 | Back-to-back direction | W=>W, R=>R, W=>R, R=>W | back-to-back/stress vseqs | `Planned` |
| SDR-010 | Data integrity | expected byte equals observed bus/RX byte; pass bin only in normal regression | scoreboard event | `Planned` correlated metric |

### 5.3 Immediate transfer

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| IMM-001 | I3C immediate length | DTT 0, 1, 2, 3, 4 | `i3c_imm_dtt_sweep_vseq` | `Implemented` command + `Planned` bus |
| IMM-002 | Immediate device type | I3C dynamic target, I2C static target | `i3c_imm_vseq`, `i3c_imm_i2c_write_vseq` | `Planned` correlated |
| IMM-003 | Inline byte integrity | descriptor byte1..4 equals observed bus byte | immediate vseqs | `SVA` + `Planned` end-to-end |
| IMM-004 | Immediate TOC policy | TOC1 success, TOC0 NotSupported/no continuation | `i3c_imm_toc_vseq` | `SVA` |
| IMM-005 | Invalid DTT | DTT 5, 6, 7 => NotSupported/no bus access | invalid descriptor vseq | `SVA` |
| IMM-006 | Immediate address/data NACK | I3C address NACK, I2C address NACK, I2C data NACK | response error vseqs | `Planned` + `SVA` |

### 5.4 I2C legacy transfer

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| I2C-001 | Static address selection | low/mid/high valid static address | I2C basic/multi-DAT extensions | `Planned` + `SVA` |
| I2C-002 | Legacy direction | write, read | I2C basic vseqs | `Planned` |
| I2C-003 | Write ACK sequence | ACK all, NACK first/middle/last data byte | I2C write và data-NACK vseq | `Planned` |
| I2C-004 | Read master ACK policy | ACK intermediate, NACK final/full boundary/abort boundary | I2C read/abort/overflow vseqs | `SVA` |
| I2C-005 | Length/packing | 1, 2, 3, 4, >4; partial/full DWORD | `i2c_len_sweep_partial_rx_vseq` | `Planned` + `SVA` |
| I2C-006 | No broadcast preamble | I2C read/write never emits private `0x7e` header | I2C basic vseqs | `SVA` |
| I2C-007 | OD-only transfer | no push-pull in address, ACK, data, STOP phases | I2C vseqs | `SVA` |
| I2C-008 | I2C × direction × ACK result | Read/write × ACK/NACK/abort/overflow applicable outcomes | I2C và error vseqs | `Planned` |

## 6. CCC và DAA coverage

### 6.1 Common Command Codes

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| CCC-001 | CCC form | broadcast, direct | CCC vseqs | `Planned` |
| CCC-002 | CCC opcode | ENEC, DISEC, ENTDAA, unsupported | CCC và invalid command vseqs | `Planned` |
| CCC-003 | Broadcast ENEC | opcode, opcode T-bit, event byte, event T-bit, STOP, success response | `i3c_ccc_broadcast_enec_vseq` | `SVA` |
| CCC-004 | Broadcast DISEC | opcode, opcode T-bit, event byte, event T-bit, STOP, success response | `i3c_ccc_broadcast_disec_vseq` | `SVA` |
| CCC-005 | Direct ENEC | broadcast leg, Sr, target address/ACK, event byte/T-bit, STOP | `i3c_ccc_direct_enec_vseq` | `SVA` |
| CCC-006 | Direct DISEC | broadcast leg, Sr, target address/ACK, event byte/T-bit, STOP | `i3c_ccc_direct_disec_vseq` | `SVA` |
| CCC-007 | CCC ACK outcome | broadcast ACK/NACK, direct target ACK/NACK, event data ACK/T-bit | CCC/error vseqs | `Planned` |
| CCC-008 | Opcode × form × response | ENEC/DISEC × broadcast/direct × Success/NACK/HcAborted | CCC/error/abort vseqs | `Planned` correlated |

### 6.2 Dynamic Address Assignment

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| DAA-001 | Requested device count | 0, 1, 2, 3..15 | DAA vseqs | `Implemented` command |
| DAA-002 | Actual joined count | 0, 1, 2, 3+ | single/no-device/multi-device vseqs | `Planned` |
| DAA-003 | DAA result | assigned-all, fewer-than-count, no-device, address-rejected, overflow, abort | DAA và error vseqs | `Planned` correlated |
| DAA-004 | DAT start/boundary index | 0, middle, last-valid, request crossing DAT depth | DAA boundary vseq | `Implemented` command + `Planned` result |
| DAA-005 | PID/BCR/DCR pattern | zero, all-one, alternating, random/other | DAA stimulus variants | `Planned` |
| DAA-006 | Assigned address | low/mid/high valid; parity result 0/1; reserved negative | DAA vseqs | `SVA` address × parity |
| DAA-007 | Round termination | device ACK, device address NACK, no next device, HC abort | DAA/error vseqs | `SVA` + `Planned` bus |
| DAA-008 | Requested × actual count | Exact, fewer, zero, bounded by DAT depth | DAA vseqs | `Planned` |
| DAA-009 | Result × response status | assigned=>Success, reject=>Nack, overflow=>Ovl, abort=>HcAborted | DAA/error vseqs | `Planned` correlated |
| DAA-010 | Multi-target arbitration | winner first, loser retries, multiple rounds | arbitration vseq | `Planned`; requires bus-model support |
| DAA-011 | DAA FSM paths | ACK receive ID, send address, result commit, no-device, wait-stop, idle return | DAA vseqs | `SVA` |
| DAA-012 | DAA abort point | identity receive, assigned-address phase, completed-round boundary | DAA abort vseq | `SVA` covergroup |

## 7. Response, error và recovery coverage

### 7.1 Response descriptor

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| RSP-001 | Error status | `cg_resp_desc.cp_resp_status`: Success, AddrHeader, Nack, Ovl, I3cShortReadErr, HcAborted, I2cDataNackOrI3cBusAborted, NotSupported | normal và response error vseqs | `SVA` selected outcomes + `Implemented` |
| RSP-002 | Defined but unreachable status | Crc, Parity, Frame; `ignore_bins unreachable` trong `cp_resp_status` | N/A | `Excluded` until RTL can generate them |
| RSP-003 | Response TID | `cp_resp_tid`: 0..15; equality với command TID cần correlated record | back-to-back, all response vseqs | `Implemented` field coverage + `Planned` correlated equality |
| RSP-004 | Actual response length | `cp_resp_data_len`: 0, 1, 2..4, 5..8, 9..16, >16 | normal/error length vseqs | `Implemented` |
| RSP-005 | Reserved response bits | `cp_resp_reserved_zero`: exactly zero | all response-producing vseqs | `SVA`/scoreboard check + `Implemented` cover |
| RSP-006 | WROC success policy | wroc0 no response, wroc1 one response | `i3c_wroc_policy_vseq` | `SVA` |
| RSP-007 | WROC error override | error writes response for wroc0 and wroc1 | WROC/error vseqs | `SVA` |
| RSP-008 | Status × command attribute | each reachable status for applicable Regular/Immediate/CCC/DAA class | all response vseqs | `Planned` correlated |
| RSP-009 | Status × direction | read/write applicable outcomes | all response vseqs | `Planned` correlated |
| RSP-010 | Requested × actual length | exact, short, zero, partial-before-abort/overflow | read/write/error vseqs | `Planned` correlated |

### 7.2 Error, abort và backpressure

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| ERR-001 | Private/broadcast address NACK | broadcast header, I3C private W/R, I2C W/R, direct CCC | NACK response vseqs | `SVA` + `Planned` bus |
| ERR-002 | Data NACK | I2C regular, I2C immediate; first/middle/last byte | data-NACK vseqs | `SVA` + `Planned` position bins |
| ERR-003 | TX underflow | before first data word, after partial progress; I3C/I2C | `i3c_write_tx_fifo_underflow_vseq` | `SVA` |
| ERR-004 | RX overflow | full boundary, partial DWORD; I3C/I2C/ENTDAA | RX overflow vseqs | `SVA` |
| ERR-005 | Short read | one-byte short, DWORD boundary, other partial length | `i3c_read_short_target_end_vseq` | `SVA` + `Planned` actual length |
| ERR-006 | RESP FIFO backpressure | success response, error response, stable descriptor, release writes once | `i3c_resp_fifo_full_backpressure_vseq` | `SVA` |
| ERR-007 | HC abort command class | regular write, regular read, I2C, immediate, CCC, DAA | abort policy vseqs | `SVA` |
| ERR-008 | Abort entry point | idle holdoff, preamble, CCC, TX data, RX data, DAA, response stage | abort/reset vseqs | `SVA` covergroups/properties |
| ERR-009 | Abort data boundary | 0 bytes, 1..3 bytes, one DWORD, >one DWORD | abort vseqs | `Planned` correlated |
| ERR-010 | Error priority over abort | AddrHeader, data NACK, DAA NACK, overflow, short-read, NotSupported | abort policy/error vseqs | `SVA` |
| ERR-011 | Invalid descriptor | each attribute class invalid combination, no DAT/bus access, NotSupported response | invalid descriptor vseqs | `SVA` |
| ERR-012 | Reset point | idle, command fetch, address, TX, RX, CCC/DAA, response write | reset vseqs | `SVA` |
| ERR-013 | Recovery | next legal command passes after abort, hard reset, accepted SW reset | abort/reset vseqs | `Planned` correlated |
| ERR-014 | Bus stuck low | observed wait/no recovery timeout | future directed stimulus | `Excluded` from positive closure until recovery policy exists |

## 8. FIFO và internal control coverage do SVA sở hữu

Không tạo UVM coverpoint cho các tín hiệu `valid/ready`, pointer, depth hoặc FSM state nội bộ. Các hành vi sau được đóng coverage bằng SVA.

| ID | Feature/scenario | Coverage owner | Cover intent chính | Test/vseq chính | Trạng thái |
|---|---|---|---|---|---|
| FIFO-001 | Reset/flush | `sync_fifo_sva.sv` | hard reset clear; flush idle/read/write/read+write | FIFO vseqs, SW reset | `SVA` |
| FIFO-002 | Write/read handshake | `sync_fifo_sva.sv` | write-only increment, read-only decrement, pointer advance | FIFO basic vseq | `SVA` |
| FIFO-003 | Simultaneous read/write | `sync_fifo_sva.sv` | mid, near-empty, near-full; depth preserved | simultaneous RW vseq | `SVA` |
| FIFO-004 | Boundary rejection | `sync_fifo_sva.sv` | full write blocked, empty read blocked, pointers stable | boundary vseq | `SVA` |
| FIFO-005 | Queue status | `sync_fifo_sva.sv`, `csr_registers_sva.sv` | full/empty matches depth and CSR mirror for CMD/TX/RX/RESP | queue status vseq | `SVA` |
| FIFO-006 | Pointer wrap/reuse | `sync_fifo_sva.sv` extension required if exact wrap is sign-off goal | generation order after wrap | future wrap vseq | `Planned` SVA |
| FSM-001 | Main FSM state reachability | `flow_active_cov.sv` | `cp_state` for reachable states | full regression | `SVA` |
| FSM-002 | Main FSM transitions | `flow_active_cov.sv` | `cp_transitions`: representative nominal command paths và selected error/abort shortcuts; không đại diện exhaustive arc coverage | full regression | `SVA` |
| FSM-003 | Command flow handshakes | `flow_active_sva.sv` | DAT read, TX fetch, RX commit, response write, continuation | transfer/error vseqs | `SVA` |
| FSM-004 | ENTDAA control paths | `entdaa_controller_sva.sv`, `entdaa_fsm_sva.sv` | round loop, no-device, assignment commit, stop and return idle | DAA vseqs | `SVA` |
| TIM-001 | START/STOP timing | `scl_generator_sva.sv` | setup/hold counter load and state sequence | normal/focused bus vseqs | `SVA` |
| TIM-002 | SCL low/high timing | `scl_generator_sva.sv` | PP low, OD low, high delay | SCL timing vseq | `SVA` |
| TIM-003 | WaitCmd stall/resume | `scl_generator_sva.sv` | hold low, resume clock, repeated START | WaitCmd vseqs | `SVA` |
| PHY-001 | Two-flop synchronization | `i3c_phy_sva.sv` | reset idle, SCL/SDA settle, input patterns 00/01/10/11 | PHY reset/sync vseq | `SVA` |
| PAD-001 | SDA pad ownership | `tb_pad_model_sva.sv` | release/drive, OD/PP high-drive rule, contention safety | pad-model và transfer vseqs | `SVA` |
| CSR-SVA-001 | CSR semantics | `csr_registers_sva.sv` | reset defaults, write/readback, staging, backpressure, empty reads | CSR vseqs | `SVA` |

## 9. Correlated coverage matrix

Các cross dưới đây không được đặt trực tiếp trong `reg_coverage` hoặc `i3c_coverage`, vì một subscriber đơn lẻ không có đủ command intent, observed bus result và response result. Chúng cần một transaction record đã correlation theo thứ tự command/TID trong scoreboard hoặc một dedicated coverage model.

| ID | Cross | Mục tiêu | Điều kiện/ignore |
|---|---|---|---|
| COR-001 | command attribute × device type | Mỗi command class đi qua đúng I3C/I2C path | Ignore DAA×I2C; Combo nếu unsupported |
| COR-002 | device type × direction × requested length | Đóng I3C/I2C read/write length space | Immediate chỉ write và DTT 0..4 |
| COR-003 | command attribute × DAT index | Kiểm tra chọn target trên toàn DAT | Có thể group index 2..30 nếu không yêu cầu từng Cartesian bin |
| COR-004 | command direction × bus direction | Command intent khớp bus observed direction | DAA/CCC có framing riêng, sample ở cross riêng |
| COR-005 | requested address × observed address | Dynamic/static/direct/assigned address đúng | Broadcast preamble không thay thế target address |
| COR-006 | broadcast enable × transaction type × first address | Control bit chỉ thay đổi private-I3C preamble | Ignore I2C first address=`0x7e` |
| COR-007 | requested length × actual bus length × response length | Đóng success, short, abort, underflow/overflow boundary | Group theo relation: exact, short, zero, overflow-partial |
| COR-008 | address ACK × response status | ACK/NACK được encode đúng | Broadcast header NACK=>AddrHeader; private NACK=>Nack |
| COR-009 | command attribute × bus result × response status | End-to-end result cho Regular/Immediate/CCC/DAA | Chỉ reachable status mỗi class |
| COR-010 | direction × response status | Read/write error distribution | Ignore short-read×write, TX-underflow×read |
| COR-011 | WROC × completion class × response presence | Success suppression và error override | Response presence: none/exactly-one |
| COR-012 | CCC opcode × form × target ACK × status | Broadcast/direct management path | ENTDAA dùng DAA result cross |
| COR-013 | DAA requested count × joined count × result | Exact/fewer/no-device/address reject | Joined count không vượt requested/DAT capacity |
| COR-014 | abort point × command class × response status | Abort coverage trên mọi active flow | Idle abort là holdoff, không có active-command response |
| COR-015 | reset point × command class × recovery result | Reset không để stale queue/context | Recovery result: next command pass/fail |
| COR-016 | previous command class × next command class × boundary | STOP và RSTART/back-to-back command mixing | Chỉ legal continuation pairs |
| COR-017 | data pattern × direction × integrity result | End-to-end payload integrity | Mismatch bin chỉ dành checker-negative test, không phải closure bin normal |
| COR-018 | stall type × command class × recovery | TX empty, RX full, RESP full, WaitCmd | Ignore non-applicable class/stall pairs |

## 10. Traceability theo feature và stimulus

| Feature group | Directed stimulus chính | Coverage owner |
|---|---|---|
| CSR/DAT | `csr_reset_defaults_vseq`, `csr_enable_disable_vseq`, `csr_timing_rw_vseq`, `csr_dat_rw_all_entries_vseq`, CMD staging/reset/status vseqs | `reg_coverage` + CSR SVA |
| SDR write | `i3c_write_vseq`, `i3c_write_len_sweep_vseq`, `i3c_write_toc_zero_vseq`, `i3c_write_back_to_back_vseq`, `i3c_write_multi_dat_idx_vseq` | `reg_coverage` + `i3c_coverage` + flow SVA |
| SDR read | `i3c_read_vseq`, `i3c_read_len_sweep_vseq`, target-end, TOC-zero, back-to-back, multi-DAT vseqs | `reg_coverage` + `i3c_coverage` + flow SVA |
| Immediate | `i3c_imm_vseq`, `i3c_imm_dtt_sweep_vseq`, `i3c_imm_toc_vseq`, `i3c_imm_i2c_write_vseq` | `reg_coverage` + `i3c_coverage` + flow SVA |
| I2C | `i2c_regular_write_basic_vseq`, `i2c_regular_read_basic_vseq`, `i2c_len_sweep_partial_rx_vseq` | `i3c_coverage` + flow/top SVA |
| CCC | broadcast/direct ENEC/DISEC và ENTDAA opening-frame vseqs | `i3c_coverage` + flow SVA |
| DAA | single/no-device/fewer/multi/address-rejected/DAT-boundary/arbitration vseqs | `reg_coverage` + `i3c_coverage` + ENTDAA SVA |
| Errors | private/broadcast NACK, data NACK, short-read, underflow, overflow, RESP backpressure, abort, invalid descriptor vseqs | correlated coverage + flow SVA |
| Reset/recovery | reset-idle, reset-transfer, SW-reset-busy, SW reset queue/staging vseqs | correlated coverage + top/CSR/flow/FIFO SVA |
| Bus primitives | PHY, START/STOP/Sr, glitch, SCL timing/stall, byte order và pad model vseqs | bus/PHY/SCL/pad SVA |

## 11. Coverage closure criteria

Coverage sign-off chỉ hợp lệ khi đồng thời thỏa các điều kiện sau:

1. Tất cả regression dùng để closure kết thúc với `UVM_ERROR=0` và `UVM_FATAL=0`.
2. Mỗi coverpoint/cross thuộc phạm vi đạt 100%, hoặc có waiver giải thích bin unreachable/unsupported.
3. Không dùng reserved/illegal negative bins để ép stimulus vào hành vi chưa được đặc tả chỉ nhằm tăng phần trăm.
4. Code coverage không thay thế functional coverage; functional coverage cũng không thay thế scoreboard và assertion pass/fail.
5. Coverage được merge trên cùng build/configuration. Báo cáo từng test chỉ dùng để debug contribution, không dùng làm số sign-off tổng.
6. Các status `Crc`, `Parity`, `Frame`, HDR/Combo path, IBI, Hot-Join và multi-controller phải được exclude/waive cho cấu hình RTL hiện tại.
7. Cross có Cartesian product lớn phải định nghĩa `ignore_bins` cho tổ hợp không hợp lệ trước khi chạy closure.

## 12. Thứ tự triển khai đề xuất

1. Hoàn thiện `i3c_coverage`: common framing, protocol, direction, address, ACK/NACK, byte count, CCC form/opcode và DAA round/result.
2. Mở rộng `reg_coverage`: command TID, mode, command-present và CCC opcode. Address class, queue software-port usage, DAT device/address, HC control field và timing CSR coverage đã được triển khai.
3. Response descriptor tại `RESP_PORT` và `cg_resp_desc` đã được triển khai; phần TID equality và response cross tiếp tục ở correlated coverage.
4. Tạo correlated transaction record trong scoreboard/coverage model; triển khai COR-001 đến COR-011 trước.
5. Chạy các length, multi-DAT, CCC, DAA và error regressions; merge coverage; bổ sung stimulus chỉ cho các hole reachable.
6. Review SVA coverage report, thêm waiver cho state/transition không reachable và tránh duplicate các SVA-owned coverpoints trong UVM.

## 13. Baseline hiện tại

Tại thời điểm tạo matrix:

- `reg_coverage` đã được instantiate và connect trong `i3c_env`;
- `cg_reg_access` và `cg_cmd_desc` đã compile và sample thành công;
- `cg_dat_entry` đã được triển khai và compile thành công, gồm device type, static/dynamic address class, reserved-bit write attempt và các cross với read/write;
- `cg_resp_desc` đã được triển khai và sample có qualifier `resp_valid_i`, gồm status, TID, actual length và reserved-zero;
- `cg_hc_control` đã được triển khai cho BUS_ENABLE, BROADCAST_HEADER_ENABLE, HC_ABORT, các transition set/clear và BUS_ENABLE × BROADCAST_HEADER_ENABLE;
- `cg_timing_csr` đã được triển khai cho 18 timing CSR, numeric/default/reserved-upper class và ba cross theo địa chỉ; coverage được đặt tại collector thay vì trong `csr_timing_rw_vseq`;
- `cg_reg_access.cp_addr_class` và `cx_access_addr_class` đã được triển khai cho mapped, aligned-unmapped và misaligned × read/write; `csr_unmapped_addr_no_side_effect_vseq`, seed 1 kết thúc với `UVM_ERROR=0`, `UVM_FATAL=0`;
- `cg_queue_sw_port` đã được triển khai cho accepted CMD/TX push và RX/RESP pop request. `csr_cmd_partial_then_other_write_vseq` sample CMD/TX/RESP (`75%` contribution), `csr_rx_resp_read_pop_vseq` sample RX/RESP (`50%` contribution); cả hai seed 1 kết thúc với `UVM_ERROR=0`, `UVM_FATAL=0` và cần merge để báo số closure;
- `i3c_coverage` đã được instantiate/connect nhưng chưa có covergroup;
- internal FSM/FIFO/timing/reset coverage đã có số lượng lớn `cover property` trong thư mục `i3c_core/sva/`;
- một coverage run với `i3c_imm_vseq`, seed 1 đã in `cg_reg_access=27.86%`, `cg_dat_entry=31.25%`, `cg_cmd_desc=19.06%` và `cg_resp_desc=35.42%`; đây là contribution của một test, không phải coverage closure của regression.
- `csr_timing_rw_vseq`, seed 1 đạt `cg_timing_csr=100.00%`; `csr_broadcast_header_control_vseq` và `csr_hc_abort_control_vseq` đã sample `cg_hc_control`. Cả ba run kết thúc với `UVM_ERROR=0`, `UVM_FATAL=0`; coverage control cần merge regression để đánh giá closure.
