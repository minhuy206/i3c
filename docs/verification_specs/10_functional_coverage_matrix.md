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

ID dạng `BUS-001`, `ERR-001`, ... trong tài liệu này thuộc namespace của coverage matrix. Label SVA dạng `ap_bus001_*`/`cp_bus001_*` tiếp tục tham chiếu ID dạng `BUS_001` trong `docs/test_plan/I3C_Testplan.md`; hai namespace không được dùng thay thế cho nhau khi ghi traceability.

Các feature không có trong RTL hiện tại như IBI, Hot-Join, HDR, multi-controller, target mode và interrupt controller không được tính vào coverage closure. Physical multi-target ENTDAA contention, wired-AND resolution và target loser/retry cũng nằm ngoài closure: active controller chỉ quan sát identity stream đã được resolve trên SDA.

## 2. Quy ước trạng thái

| Trạng thái | Ý nghĩa |
|---|---|
| `Implemented` | Coverpoint/cross đã tồn tại trong collector hiện tại và compile; không cam kết mọi bin đã được hit. Bin cần negative stimulus phải có dedicated test hoặc waiver khi sign-off. |
| `SVA` | Hành vi đã được quan sát bằng `cover property` hoặc `assert property` trong các file SVA. |
| `Planned` | Cần bổ sung vào collector trong bước tiếp theo. |
| `Excluded` | Ngoài phạm vi hoặc không reachable trong RTL hiện tại; phải có waiver khi sign-off. |

## 3. Kiến trúc quan sát

| Nguồn quan sát | Collector | Dữ liệu đáng tin cậy | Không nên đặt tại đây |
|---|---|---|---|
| Register monitor | `reg_coverage` | Địa chỉ CSR, read/write, write data, read data, DAT index, command descriptor được ghép từ hai DWORD | ACK/NACK thực tế trên bus, số byte thực tế, FSM state |
| I3C bus monitor | `i3c_coverage` | Address, direction, I3C/I2C, START/Sr/STOP, broadcast header, ACK/NACK/T-bit, CCC, byte count, abort | Command intent chưa được correlation với register stream, internal FIFO/FSM state |
| Response observation | `reg_coverage.cg_resp_desc`, decode từ lần đọc hợp lệ tại `RESP_PORT` | `err_status`, `tid`, reserved bits, actual length | Suy đoán bus result chỉ từ response code; kiểm tra TID bằng command khi chưa correlation |
| Correlated transaction | `i3c_correlated_coverage`, nhận record đã ghép từ scoreboard | Command intent × bus result hiện tại; DAT/device và response mở rộng theo từng feature | Sampling hai stream độc lập mà không ghép theo command/TID |
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
| CMD-011 | Transaction ID | `cp_cmd_tid`: từng TID 0..15 | Register monitor | back-to-back vseqs | `Implemented` |
| CMD-012 | Transfer mode | `cp_cmd_mode`: SDR0..SDR4, HDR-TSx, HDR-DDR, reserved; non-SDR0 là negative bins theo RTL hiện tại | Register monitor | normal transfer và invalid descriptor vseq | `Implemented` |
| CMD-013 | Command-present bit | `cp_cmd_present`: 0, 1; `cx_cmd_attr_present`; bỏ AddressAssignment/reserved | Register monitor | CCC/regular và invalid descriptor vseqs | `Implemented` |
| CMD-014 | CCC opcode in descriptor | `cp_cmd_code`: broadcast/direct ENEC, broadcast/direct DISEC, ENTDAA, unsupported other opcode | Register monitor | CCC vseqs | `Implemented` |
| CMD-015 | Regular SRE/DBP | `cp_cmd_sre`, `cp_cmd_dbp`, `cx_cmd_sre_dbp`; field programming coverage; RTL thực thi SRE, DBP semantics chưa triển khai | Register monitor | short-read và invalid descriptor vseq | `Implemented` |
| CMD-016 | Command staging | first DWORD only, unrelated CSR interleave, completed pair, reset-cleared partial pair | SVA | CMD staging CSR vseqs | `SVA` |
| CMD-017 | Attribute × device type | `cx_cmd_attr_device`: Regular/Immediate/AddressAssignment × I3C/I2C, chỉ sample DAT index đã được software cấu hình | Correlated register/DAT shadow | SDR, IMM, I2C, DAA vseqs | `Implemented` |
| CMD-018 | Attribute × DAT index | `cx_cmd_attr_dat_idx`: known command class × 0..31; bỏ reserved attribute | Register monitor | multi-DAT và DAA boundary vseqs | `Implemented` |
| CMD-019 | Previous × next command | `cx_previous_next_cmd`: Regular W/R, Immediate, CCC, DAA; chỉ sample hai descriptor liên tiếp được RTL hỗ trợ, clear history khi invalid/reset | Correlated register history | back-to-back và TOC continuation vseqs | `Implemented` |

## 5. Bus transaction coverage

Các mục bus-observable trong phần này thuộc `i3c_coverage`. Collector chuẩn hóa mỗi `i3c_item` thành các address phase và logical transfer trước khi sample; command intent, requested length, DAT index và response result vẫn thuộc correlated coverage. Các dòng ghi `SVA` có cover độc lập ở RTL.

### 5.1 Common transaction framing

| ID | Feature/scenario | Coverage item và bins | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| BUS-001 | Protocol type | `cg_address_phase/cg_bus_transfer.cp_protocol`: I3C, I2C | Tất cả transfer vseqs | `Implemented` |
| BUS-002 | Bus direction | `cp_bus_op`: write, read | SDR và I2C vseqs | `Implemented` |
| BUS-003 | Address class | broadcast `0x7e`, I3C dynamic, I2C static, reserved/other negative | CSR broadcast, SDR, I2C, CCC, DAA | `Implemented` |
| BUS-004 | Address ACK | ACK, NACK cho từng broadcast-header/target/CCC/DAA address phase | success và NACK vseqs | `Implemented` |
| BUS-005 | Actual byte count | 0, 1, 2..4, 5..8, 9..16, 17..64, >64 | length sweep, abort/overflow | `Implemented` |
| BUS-006 | Data pattern | `cg_payload_byte.cp_data_pattern`: all-zero, all-one, từng `AA/55`, từng walking-one bit, random/other | TX/RX byte-order và length sweep | `Implemented` |
| BUS-007 | Start source | START, repeated START cho từng address phase | TOC, direct CCC, DAA | `Implemented` |
| BUS-008 | End condition | STOP, RSTART, RSTART+STOP, incomplete; interrupt là coverpoint riêng | TOC, abort, short-read | `Implemented` bus observation |
| BUS-009 | Private preamble | dynamic-first, `0x7e/W + Sr + dynamic` | broadcast control, SDR read/write | `Implemented` |
| BUS-010 | Transaction termination | `cg_i3c_read_end.cx_t_bit_interrupted`: bus observation normal/interrupted × final T-bit target-end/controller-continue; `cg_abort_termination` phân loại HC abort/reset/protocol termination × abort point và byte boundary. Reset active-point chi tiết tiếp tục do SVA sở hữu | abort/reset vseqs | `Implemented` correlated cause + `SVA` internal point |
| BUS-011 | Protocol × direction × length | I3C/I2C read/write × actual-length class | length sweep | `Implemented` |
| BUS-012 | Address class × ACK | ACK/NACK ở broadcast, dynamic, static và direct CCC address | NACK vseqs | `Implemented` |
| BUS-013 | Preamble × direction | enabled/disabled private preamble × read/write | CSR broadcast, SDR vseqs | `Implemented` |
| BUS-014 | START/STOP/Sr detection | Legal sequence, glitch reject, enable gating, one-cycle pulse | focused bus vseqs | `SVA` |
| BUS-015 | SCL timing | START, STOP, PP low, OD low, WaitCmd stall/resume, repeated START | focused SCL vseqs | `SVA` |
| BUS-016 | OD/PP phase | START/address/ACK/STOP/DAA OD; I3C data PP; I2C always OD | SDR/I2C/CCC/DAA | `SVA` |
| BUS-017 | TX/RX serialization | Byte/bit request, payload pattern, MSB-first | byte-order vseqs | `SVA` + `Implemented` payload pattern |

### 5.2 I3C SDR private transfer

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| SDR-001 | SDR private write | direction=write, actual length bins; payload pass được publish sau khi scoreboard so sánh đủ bus payload với TX FIFO model | write baseline/length/back-to-back | `Implemented` bus + correlated integrity |
| SDR-002 | SDR private read | direction=read, actual length bins, partial DWORD 1/2/3 bytes | read baseline/length/back-to-back | `Implemented` |
| SDR-003 | Write T-bit | T-bit 0, 1; parity match `~^byte` | write vseqs | `SVA` |
| SDR-004 | Read T-bit outcome | `cg_sdr_read_length_t_bit.cx_t_bit_length_outcome`: final T-bit 0/1 × exact/early/beyond-requested; beyond là controller đã nhận đủ requested bytes nhưng target trả T-bit=1 để báo còn dữ liệu, không yêu cầu actual bus length vượt requested | read length sweep, target-end và more-than-requested vseqs | `Implemented` correlated + `SVA` |
| SDR-005 | Zero-length write | address ACK then no data/T-bit, success length 0 | `i3c_write_len_sweep_vseq` | `SVA` |
| SDR-006 | Partial final DWORD | byte remainder 1, 2, 3, 0 | read/write length sweep | `Implemented` + `SVA` read |
| SDR-007 | TOC continuation | TOC0 accepted, missing continuation, unsupported continuation, TOC1 stop | TOC-zero vseqs | `SVA` |
| SDR-008 | Multi-DAT target | DAT index/address 0, 1, boundary indices; scoreboard đã check expected/observed target address và payload; functional cross DAT index × observed address/payload vẫn cần bổ sung | multi-DAT vseqs | Scoreboard check + `Planned` functional cross + `SVA` selected indices |
| SDR-009 | Back-to-back direction | `cg_private_transition.cx_previous_next_op`: W=>W, R=>R, W=>R, R=>W; history clear khi reset/non-private | back-to-back/stress vseqs | `Implemented` |
| SDR-010 | Data integrity | `cg_data_integrity.cx_pattern_direction_integrity`: zero/ones/AA55/walking-one/other × read/write × pass. Write sample sau full bus-payload check; read sample chỉ sau khi software đọc và scoreboard check toàn bộ RX FIFO payload. Fail vẫn là checker error và bị ignore khỏi positive closure | scoreboard event, SDR/I2C/byte-order/multi-DAT vseqs | Scoreboard check + `Implemented` correlated metric |

### 5.3 Immediate transfer

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| IMM-001 | Immediate length by protocol | `cg_immediate_transfer.cx_protocol_dtt`: I3C and I2C × DTT 0, 1, 2, 3, 4 | `i3c_imm_dtt_sweep_vseq`, `i3c_imm_i2c_write_vseq` | `Implemented` command + correlated bus |
| IMM-002 | Immediate device type | `cg_immediate_transfer.cp_protocol`: I3C dynamic target, I2C static target | `i3c_imm_vseq`, `i3c_imm_i2c_write_vseq` | `Implemented` correlated |
| IMM-003 | Immediate TOC policy | TOC1 success, TOC0 NotSupported/no continuation | `i3c_imm_toc_vseq` | `SVA` |
| IMM-004 | Invalid DTT | `reg_coverage.cp_cmd_dtt.reserved[]`: DTT 5, 6, 7; NotSupported/no bus access checked by SVA | `i3c_imm_dtt_sweep_vseq` | `Implemented` register coverage + SVA |
| IMM-005 | Immediate address/data NACK | `cg_immediate_transfer.cx_protocol_nack`: I3C address NACK, I2C address NACK, I2C data NACK | `i3c_private_addr_nack_resp_vseq`, `i3c_imm_data_nack_i2c_vseq` | `Implemented` correlated + SVA |

### 5.4 I2C legacy transfer

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| I2C-001 | Static address selection | `cg_address_phase.cp_i2c_static_addr_range`: usable low `0x08..0x1f`, mid `0x20..0x5f`, high `0x60..0x77`; reserved addresses excluded from legal private-transfer stimulus; transmitted address checked against `DAT.static_address` by SVA | `i2c_regular_write_basic_vseq` | `Implemented` + `SVA` |
| I2C-002 | Legacy direction | write, read | I2C basic vseqs | `Implemented` |
| I2C-003 | Write ACK sequence | `cg_i2c_write_nack_position`: ACK-all/NACK first/middle/last-requested; position dùng first NACK index, requested length từ command và actual byte count từ bus | I2C write và data-NACK vseq | `Implemented` correlated |
| I2C-004 | Read master ACK policy | ACK intermediate, NACK final/full boundary/abort boundary | I2C read/abort/overflow vseqs | `SVA` |
| I2C-005 | Length/packing | 1, 2, 3, 4, >4; partial/full DWORD | `i2c_len_sweep_partial_rx_vseq` | `Implemented` + `SVA` |
| I2C-006 | No broadcast preamble | I2C read/write never emits private `0x7e` header | I2C basic vseqs | `SVA` |
| I2C-007 | OD-only transfer | no push-pull in address, ACK, data, STOP phases | I2C vseqs | `SVA` |
| I2C-008 | I2C direction × ACK profile | `cg_i2c_ack.cx_i2c_op_ack`: write × no-data/all-ACK/write-NACK-first/write-NACK-after-progress; read × no-data/read-NACK; incompatible hoặc invalid read profiles ignored | I2C và error vseqs | `Implemented` observation |

## 6. CCC và DAA coverage

### 6.1 Common Command Codes

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| CCC-001 | CCC form | `cg_ccc.cp_ccc_form`: broadcast, direct | CCC vseqs | `Implemented` |
| CCC-002 | CCC opcode | ENEC, DISEC, ENTDAA, direct ENEC/DISEC, unsupported | CCC và invalid command vseqs | `Implemented` |
| CCC-003 | Broadcast ENEC | opcode, opcode T-bit, event byte, event T-bit, STOP, success response | `i3c_ccc_broadcast_enec_vseq` | `SVA` |
| CCC-004 | Broadcast DISEC | opcode, opcode T-bit, event byte, event T-bit, STOP, success response | `i3c_ccc_broadcast_disec_vseq` | `SVA` |
| CCC-005 | Direct ENEC | broadcast leg, Sr, target address/ACK, event byte/T-bit, STOP | `i3c_ccc_direct_enec_vseq` | `SVA` |
| CCC-006 | Direct DISEC | broadcast leg, Sr, target address/ACK, event byte/T-bit, STOP | `i3c_ccc_direct_disec_vseq` | `SVA` |
| CCC-007 | CCC ACK outcome | broadcast ACK/NACK, direct target ACK/NACK, opcode/event T-bit | CCC/error vseqs | `Implemented` bus observation |
| CCC-008 | Opcode × form × response | `cg_ccc_response.cx_operation_form_response`: ENEC/DISEC × broadcast/direct × Success/AddrHeader/HcAborted, sampled after the matching response descriptor passes scoreboard correlation | CCC/error/abort vseqs | `Implemented` correlated |

### 6.2 Dynamic Address Assignment

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| DAA-001 | Requested device count | 0, 1, 2, 3..15 | DAA vseqs | `Implemented` command |
| DAA-002 | Actual joined count | `cg_daa_transaction.cp_joined_count`: accepted assignment count 0, 1, 2, 3+ | single/no-device/multi-device vseqs | `Implemented` |
| DAA-003 | DAA result | `cg_daa_result.cp_result`: assigned-all, fewer-than-count, no-device, address-rejected, overflow, abort | DAA và error vseqs | `Implemented` correlated |
| DAA-004 | DAT start/boundary, multi-round progression và resolved identity stream | `cg_daa_dat_boundary.cx_start_span_response`: first/middle/last start × within/ends-at-last/crosses-boundary span × descriptor accepted/boundary-rejected; `cg_daa_result.cp_rstart_count` covers checked DAA round count. `i3c_daa_multi_device_dat_loop_vseq` checks RX result order against the pre-resolved PID/BCR/DCR order; this verifies controller handling of the resolved stream, not physical target arbitration | DAA multi-device DAT-loop and boundary vseqs | `Implemented` correlated + directed check |
| DAA-005 | PID/BCR/DCR pattern | zero, all-one, AA/55-only, random/other trên 8 identity bytes | DAA stimulus variants | `Implemented` |
| DAA-006 | Assigned address | `cg_daa_assigned_address.cx_address_class_parity`: low `0x08..0x1f`, middle `0x20..0x5f`, high `0x60..0x77`, reserved × parity 0/1; chỉ sample round có đủ byte assigned-address | DAA single/multi/boundary/rejected vseqs | Scoreboard check + `Implemented` address × parity |
| DAA-007 | Round termination | `cg_daa_round.cp_round_outcome`: assigned-address ACK/NACK, no-device address NACK, interrupted ID phase, other | DAA/error vseqs | `SVA` + `Implemented` bus observation |
| DAA-008 | Requested × actual count | `cg_daa_result.cx_requested_joined_result`: exact, fewer, zero; DAT boundary remains under DAA-004 | DAA vseqs | `Implemented` correlated |
| DAA-009 | Result × response status | `cg_daa_result_response.cx_result_response`: normal completion=>Success, reject=>Nack, overflow=>Ovl, abort=>HcAborted, sampled only after response status/TID/length correlation passes | DAA/error vseqs | `Implemented` correlated |
| DAA-011 | DAA FSM paths | ACK receive ID, send address, result commit, no-device, wait-stop, idle return | DAA vseqs | `SVA` |
| DAA-012 | DAA abort point | identity receive, assigned-address phase, completed-round boundary | DAA abort vseq | `SVA` (`cover property` trong `entdaa_fsm_sva.sv`) |

## 7. Response, error và recovery coverage

### 7.1 Response descriptor

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| RSP-001 | Error status | `cg_resp_desc.cp_resp_status`: Success, AddrHeader, Nack, Ovl, I3cShortReadErr, HcAborted, I2cDataNackOrI3cBusAborted, NotSupported | normal và response error vseqs | `SVA` selected outcomes + `Implemented` |
| RSP-002 | Defined but unreachable status | Crc, Parity, Frame; `ignore_bins unreachable` trong `cp_resp_status` | N/A | `Excluded` until RTL can generate them |
| RSP-003 | Response TID | `cp_resp_tid`: 0..15; `cg_response_descriptor_correlation.cp_tid_match` so sánh command TID với observed RESP TID | back-to-back, all response vseqs | `Implemented` field coverage + scoreboard check + correlated equality |
| RSP-004 | Actual response length | `cp_resp_data_len`: 0, 1, 2..4, 5..8, 9..16, >16 | normal/error length vseqs | `Implemented` |
| RSP-005 | Reserved response bits | `cp_resp_reserved_zero`: exactly zero | all response-producing vseqs | `SVA`/scoreboard check + `Implemented` cover |
| RSP-006 | WROC success policy | `cg_response_presence_policy.cx_cmd_class_wroc_completion_presence`: command class × wroc0-absent/wroc1-present; exact cardinality and duplicate rejection remain scoreboard/SVA-owned | `i3c_wroc_policy_vseq` | `SVA` + checker + `Implemented` correlated presence |
| RSP-007 | WROC error override | `cg_response_presence_policy.cx_cmd_class_wroc_completion_presence`: every applicable command class produces a response on error for wroc0 and wroc1; exact cardinality remains scoreboard/SVA-owned | WROC/error vseqs | `SVA` + checker + `Implemented` correlated presence |
| RSP-008 | Status × command attribute | `cg_response_status.cx_status_cmd_class`: each reachable status for applicable Regular/Immediate/CCC/DAA class; impossible class/status pairs ignored | all response vseqs | `Implemented` correlated |
| RSP-009 | Status × direction | `cg_response_status.cx_status_direction`: read/write applicable outcomes; DAA `Nack`×read, data-NACK×read và short-read×write ignored | all response vseqs | `Implemented` correlated |
| RSP-010 | Requested × actual length | `cg_response_length.cx_requested_length_relation`: requested-length class × exact/short/zero/partial-abort/partial-overflow; sample only after bus length and RESP length match | read/write/error vseqs | `Implemented` correlated |

### 7.2 Error, abort và backpressure

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| ERR-001 | Private/broadcast address NACK | `cg_address_phase.cx_addr_class_nack` cover ACK/NACK theo broadcast/dynamic/static; `cg_ccc_target.cx_ccc_target_nack` cover direct CCC target ACK/NACK | NACK response vseqs | `SVA` + `Implemented` bus observation |
| ERR-002 | Data NACK | `cg_i2c_write_nack_position.cx_cmd_class_nack_position`: I2C Regular/Immediate × first/middle/last-requested/none | data-NACK vseqs | `SVA` + `Implemented` correlated |
| ERR-003 | TX underflow | before first data word, after partial progress; I3C/I2C | `i3c_write_tx_fifo_underflow_vseq` | `SVA` |
| ERR-004 | RX overflow | full boundary, partial DWORD; I3C/I2C/ENTDAA | RX overflow vseqs | `SVA` |
| ERR-005 | Short read | `cg_short_read_boundary.cx_sre_wroc_boundary`: SRE 0/1 × WROC 0/1 × zero/one-byte/DWORD/partial-1/2/3 boundary; `toc=0` suppression tiếp tục do SVA/checker kiểm tra | `i3c_read_short_target_end_vseq` | `SVA` policy + `Implemented` correlated boundary |
| ERR-006 | RESP FIFO backpressure | success response, error response, stable descriptor, release writes once | `i3c_resp_fifo_full_backpressure_vseq` | `SVA` |
| ERR-007 | HC abort command class | regular write, regular read, I2C, immediate, CCC, DAA | abort policy vseqs | `SVA` |
| ERR-008 | Abort entry point | idle holdoff, preamble, CCC, TX data, RX data, DAA, response stage | abort/reset vseqs | `SVA` |
| ERR-009 | Abort data boundary | `cg_abort_termination.cx_cause_byte_boundary`: 0 bytes, 1..3 bytes, one DWORD, >one DWORD × HC abort/reset/protocol termination | abort vseqs | `Implemented` correlated |
| ERR-010 | Error priority over abort | AddrHeader, data NACK, DAA NACK, overflow, short-read, NotSupported | abort policy/error vseqs | `SVA` |
| ERR-011 | Invalid descriptor | each attribute class invalid combination, no DAT/bus access, NotSupported response | invalid descriptor vseqs | `SVA` |
| ERR-012 | Reset point | idle, command fetch, address, TX, RX, CCC/DAA, response write | reset vseqs | `SVA` |
| ERR-013 | Recovery | `cg_recovery`: source HC abort/reset/protocol termination × interrupted class/no-active-command × next command class × pass; context được consume đúng một lần | abort/reset vseqs | `Implemented` correlated |
| ERR-014 | Bus stuck low | observed wait/no recovery timeout | future directed stimulus | `Excluded` from positive closure until recovery policy exists |

## 8. FIFO và internal control coverage do SVA sở hữu

Không tạo UVM coverpoint cho các tín hiệu `valid/ready`, pointer, depth hoặc FSM state nội bộ. Functional coverage (covergroup) nằm trong `reg_coverage`, `i3c_coverage` và `i3c_correlated_coverage`. Các hành vi nội bộ dưới đây được quan sát qua `cover property` / `assert property` trong file SVA, hoặc qua Xcelium code/FSM coverage (`-coverage all`).

| ID | Feature/scenario | Coverage owner | Cover intent chính | Test/vseq chính | Trạng thái |
|---|---|---|---|---|---|
| FIFO-001 | Reset/flush | `sync_fifo_sva.sv` | hard reset clear; flush idle/read/write/read+write | FIFO vseqs, SW reset | `SVA` |
| FIFO-002 | Write/read handshake | `sync_fifo_sva.sv` | write-only increment, read-only decrement, pointer advance | FIFO basic vseq | `SVA` |
| FIFO-003 | Simultaneous read/write | `sync_fifo_sva.sv` | mid, near-empty, near-full; depth preserved | simultaneous RW vseq | `SVA` |
| FIFO-004 | Boundary rejection | `sync_fifo_sva.sv` | full write blocked, empty read blocked, pointers stable | boundary vseq | `SVA` |
| FIFO-005 | Queue status | `sync_fifo_sva.sv`, `csr_registers_sva.sv` | full/empty matches depth and CSR mirror for CMD/TX/RX/RESP | queue status vseq | `SVA` |
| FIFO-006 | Pointer wrap/reuse | `sync_fifo_sva.sv` | write/read index wrap with extra-MSB toggle; full pointer reuse wrap to zero; generation order after wrap | `fifo_pointer_wrap_reuse_vseq` | `SVA` |
| FSM-001 | Main FSM state reachability | Xcelium code/FSM coverage (`-coverage all`) | tất cả 13 trạng thái `flow_active` | full regression | `Excluded` (delegated to code coverage) |
| FSM-002 | Main FSM transitions | Xcelium code/FSM coverage (`-coverage all`) | representative arc coverage; `cover property` trong `flow_active_sva.sv` cho các handshake path | full regression | `Excluded` (delegated to code coverage) |
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

| ID | Cross | Mục tiêu | Điều kiện/ignore | Trạng thái |
|---|---|---|---|---|
| COR-001 | command attribute × device type | Mỗi command class đi qua đúng I3C/I2C path | Ignore DAA×I2C; Combo nếu unsupported | `Implemented` trong `reg_coverage.cx_cmd_attr_device` |
| COR-002 | `cg_private_transfer_correlation.cx_protocol_direction_length`: device type × direction × requested length | Đóng I3C/I2C read/write length space | Immediate chỉ write và DTT 0..4 | `Implemented` |
| COR-003 | command attribute × DAT index | Kiểm tra chọn target trên toàn DAT | Có thể group index 2..30 nếu không yêu cầu từng Cartesian bin | `Implemented` trong `reg_coverage.cx_cmd_attr_dat_idx` |
| COR-004 | `cg_private_transfer_correlation.cx_cmd_observed_direction`: command direction × bus direction | Command intent khớp bus observed direction | DAA/CCC có framing riêng, sample ở cross riêng | Scoreboard check + `Implemented` correlated metric |
| COR-005 | `cg_private_transfer_correlation.cx_dat_idx_addr_match`: DAT index/requested address × observed address equality | Dynamic/static target address đúng | Broadcast preamble không thay thế target address | Scoreboard check + `Implemented` correlated metric |
| COR-006 | `cg_private_preamble_correlation.cx_policy_first_addr_match`: broadcast enable/protocol/preamble policy × first address equality | Control bit chỉ thay đổi private-I3C preamble | I2C không được dùng first address `0x7e`; continuation không lặp header | Scoreboard check + `Implemented` correlated metric |
| COR-007 | `cg_response_length.cx_requested_length_relation`: requested length × actual bus length × response length relation | Đóng success, short, abort, underflow/overflow boundary | Sample sau RESP correlation; detailed byte-boundary bins theo ERR-005/009 vẫn có thể cần bổ sung | `Implemented` cho Regular/Immediate |
| COR-008 | `cg_address_response_correlation.cx_phase_ack_status`: address phase × ACK/NACK × observed response status, chỉ sample sau khi status/TID/length của descriptor đã correlation thành công | ACK/NACK được encode đúng | Broadcast-header hoặc private/direct-target NACK => `AddrHeader`; ACK cho phép success hoặc lỗi phát sinh sau address phase | Scoreboard check + `Implemented` correlated metric |
| COR-009 | `cg_response_status.cx_status_cmd_class`: command class × response status | End-to-end result cho Regular/Immediate/CCC/DAA | Chỉ reachable status mỗi class | `Implemented` |
| COR-010 | `cg_response_status.cx_status_direction`: direction × response status | Read/write error distribution | Ignore Nack/data-NACK×read và short-read×write | `Implemented` |
| COR-011 | `cg_response_presence_policy.cx_cmd_class_wroc_completion_presence`: command class × WROC × completion result × response presence | Success suppression và error override trên từng command class | wroc0-success: absent; wroc1-success và mọi error: present; duplicate/missing cardinality do scoreboard/SVA kiểm tra | Scoreboard/SVA check + `Implemented` correlated metric |
| COR-012 | CCC opcode × form × target ACK × status | Broadcast/direct management path | ENTDAA dùng DAA result cross | `Implemented` opcode×form×status và bus target-ACK riêng + `Planned` combined cross |
| COR-013 | `cg_daa_result.cx_requested_joined_result`: DAA requested count × joined count × result | Exact/fewer/no-device/address reject/overflow/abort | Joined count không vượt requested/DAT capacity; cần review thêm unreachable bins từ coverage report | `Implemented` |
| COR-014 | `cg_abort_response.cx_abort_point_cmd_response`: abort point × command class × response status | Chỉ sample sau khi matching response descriptor pass status/TID/length correlation; reset không gán response giả | Idle abort là holdoff, không có active-command response | `SVA` point/policy + `Implemented` correlated metric |
| COR-015 | `cg_recovery.cx_reset_point_class_result`: reset point × interrupted/no-active class × recovery result | Scoreboard phân biệt idle, queued-command và active-unknown; active FSM phase chi tiết thuộc SVA | Recovery result do matching response của command kế tiếp quyết định | `SVA` reset phase + `Implemented` correlated recovery metric |
| COR-016 | `cg_command_boundary.cx_previous_next_boundary`: previous command class × next command class × STOP/RSTART/TOC continuation/idle-back-to-back/reset-cleared | STOP là successor đã nằm trong expected queue khi command trước hoàn tất; idle/back-to-back là queue rỗng rồi software mới cấp descriptor tiếp theo. History clear trên reset | Chỉ legal continuation pairs | `Implemented` combined boundary cross |
| COR-017 | `cg_data_integrity.cx_pattern_direction_integrity`: data pattern × direction × integrity pass | End-to-end payload integrity; read chỉ publish sau full RX FIFO check | Mismatch tiếp tục là `uvm_error`, không phải positive closure bin | Scoreboard check + `Implemented` correlated metric |
| COR-018 | `cg_stall_recovery.cx_stall_cmd_recovery`: TX empty/RX full/RESP full/WaitCmd × command class × pass | TX/RX lấy từ scoreboard FIFO inference, RESP-full từ queue state, WaitCmd từ legal TOC continuation; internal handshake thuộc SVA | Ignore non-applicable class/stall pairs | `SVA` stall behavior + `Implemented` correlated recovery metric |

## 10. Traceability theo feature và stimulus

| Feature group | Directed stimulus chính | Coverage owner |
|---|---|---|
| CSR/DAT | `csr_reset_defaults_vseq`, `csr_enable_disable_vseq`, `csr_timing_rw_vseq`, `csr_dat_rw_all_entries_vseq`, CMD staging/reset/status vseqs | `reg_coverage` + CSR SVA |
| SDR write | `i3c_write_vseq`, `i3c_write_len_sweep_vseq`, `i3c_write_toc_zero_vseq`, `i3c_write_back_to_back_vseq`, `i3c_write_multi_dat_idx_vseq` | `reg_coverage` + `i3c_coverage` + flow SVA |
| SDR read | `i3c_read_vseq`, `i3c_read_len_sweep_vseq`, target-end, TOC-zero, back-to-back, multi-DAT vseqs | `reg_coverage` + `i3c_coverage` + flow SVA |
| Immediate | `i3c_imm_vseq`, `i3c_imm_dtt_sweep_vseq`, `i3c_imm_toc_vseq`, `i3c_imm_i2c_write_vseq` | `reg_coverage` + `i3c_coverage` + `i3c_correlated_coverage` + flow SVA |
| I2C | `i2c_regular_write_basic_vseq`, `i2c_regular_read_basic_vseq`, `i2c_len_sweep_partial_rx_vseq` | `i3c_coverage` + flow/top SVA |
| CCC | broadcast/direct ENEC/DISEC và ENTDAA opening-frame vseqs | `i3c_coverage` + flow SVA |
| DAA | single/no-device/fewer/multi-round/address-rejected/DAT-boundary vseqs | `reg_coverage` + `i3c_coverage` + `i3c_correlated_coverage` + ENTDAA SVA |
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
6. Các status `Crc`, `Parity`, `Frame`, HDR/Combo path, IBI, Hot-Join, multi-controller và physical multi-target ENTDAA contention/loser-retry phải được exclude/waive cho cấu hình RTL hiện tại.
7. Cross có Cartesian product lớn phải định nghĩa `ignore_bins` cho tổ hợp không hợp lệ trước khi chạy closure.

## 12. Thứ tự triển khai đề xuất

1. `i3c_coverage` đã triển khai common framing, protocol, direction, address, ACK/NACK, byte count, payload pattern, CCC form/opcode và DAA round/result observation.
2. Mở rộng `reg_coverage`: command TID, mode, command-present và CCC opcode. Address class, queue software-port usage, DAT device/address, HC control field và timing CSR coverage đã được triển khai.
3. Response descriptor tại `RESP_PORT`, `cg_resp_desc`, response field equality và các response cross RSP-003/006/007/008/009/010 trong correlated coverage đã được triển khai.
4. Correlated transaction record, response correlation, length/T-bit/NACK/short-boundary coverage và DAA assigned-address class × parity (DAA-006) đã được triển khai. Tiếp theo hoàn thiện combined cross COR-012 và review closure/waiver cho các lifecycle cross COR-014/015/018.
5. Chạy các multi-DAT, CCC, DAA và error regressions; merge coverage; bổ sung stimulus chỉ cho các hole reachable.
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
- `i3c_coverage` đã được instantiate/connect và có mười một covergroup bus-level, gồm DAA assigned-address class × parity chỉ sample khi round có đủ byte thứ chín;
- collector sample một lần khi monitor hoàn tất `i3c_item`, tách private broadcast preamble và các nested direct-CCC/DAA address phase; `i3c_monitor` latch `start_from_rstart` trước khi field `rstart` được tái sử dụng làm end condition;
- internal FSM/FIFO/timing/reset/abort/invalid-cmd coverage được quan sát bằng `cover property` và `assert property` trong thư mục `i3c_core/sva/`; functional coverage hiện nằm trong `reg_coverage` (9 covergroup), `i3c_coverage` (11 covergroup) và `i3c_correlated_coverage` (21 covergroup); FSM state/transition reachability được đóng bằng Xcelium code/FSM coverage (`-coverage all`);
- Sau review correlation, `i3c_wroc_policy_vseq`, seed 1 đạt `UVM_ERROR=0`, `UVM_FATAL=0`; contribution là `cg_response_descriptor_correlation=91.67%`, `cg_address_response_correlation=79.17%`, `cg_response_presence_policy=84.33%` sau khi thêm command-class dimension. `csr_broadcast_header_control_vseq` đạt `cg_private_preamble_correlation=60.00%` sau khi thêm policy × first-address-match cross. `i3c_broadcast_header_nack_resp_vseq` cũng đạt `UVM_ERROR=0`, `UVM_FATAL=0`, `cg_address_response_correlation=37.50%` sau khi chỉ cho phép sample descriptor đã match, và hit broadcast-header NACK => `AddrHeader`;
- `i3c_imm_dtt_sweep_vseq`, seed 1 đạt `UVM_ERROR=0`, `UVM_FATAL=0` và đóng phía I3C của cross DTT 0..4; `i3c_imm_i2c_write_vseq` cung cấp phía I2C của cross;
- `i3c_private_addr_nack_resp_vseq` và `i3c_imm_data_nack_i2c_vseq`, seed 1 đều đạt `UVM_ERROR=0`, `UVM_FATAL=0`; coverage merge hit đủ ba bin `i3c,address_nack`, `i2c,address_nack` và `i2c,data_nack` của IMM-005;
- Nhóm length/NACK seed 1 đều đạt `UVM_ERROR=0`, `UVM_FATAL=0`: `i3c_read_short_target_end_vseq` sample `cg_short_read_boundary=78.12%`; `i2c_data_nack_write_vseq` sample Regular first/middle/last (`cg_i2c_write_nack_position=58.93%`); `i3c_imm_data_nack_i2c_vseq` sample Immediate first/middle/last (`54.76%`); `i3c_read_len_sweep_vseq` và `i3c_read_target_more_than_requested_vseq` sample exact và beyond-requested, còn target-end sample early. Đây là contribution từng test, chưa phải số merge closure;
- Nhóm #4..#9 seed 1 đều đạt `UVM_ERROR=0`, `UVM_FATAL=0`: DAA single-device sample `cg_daa_assigned_address=29.17%`; SDR read/write sample `cg_data_integrity=45.00%`; `i2c_regular_abort_vseq` sample khác zero cho abort termination/response/recovery; reset-during-transfer sample `cg_recovery=45.82%` và `cg_command_boundary=36.25%`; TOC-zero, TX-empty, RX-full và RESP-full focused tests đều sample khác zero cho `cg_stall_recovery`. Đây là contribution từng test, chưa phải số merge closure;
- một coverage run với `i3c_imm_vseq`, seed 1 đã in `cg_reg_access=27.86%`, `cg_dat_entry=31.25%`, `cg_cmd_desc=19.06%` và `cg_resp_desc=35.42%`; đây là contribution của một test, không phải coverage closure của regression.
- `csr_timing_rw_vseq`, seed 1 đạt `cg_timing_csr=100.00%`; `csr_broadcast_header_control_vseq` và `csr_hc_abort_control_vseq` đã sample `cg_hc_control`. Cả ba run kết thúc với `UVM_ERROR=0`, `UVM_FATAL=0`; coverage control cần merge regression để đánh giá closure.
