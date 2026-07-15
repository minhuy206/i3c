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
| Register monitor | `reg_coverage` | DAT device/address class, command descriptor ghép từ hai DWORD, HC policy và accepted queue-port operations | ACK/NACK thực tế trên bus, số byte thực tế, FSM state; raw register-map/timing-value closure |
| I3C bus monitor | `i3c_coverage` | Address, direction, I3C/I2C, START/Sr/STOP, broadcast header, ACK/NACK/T-bit, CCC, byte count, abort | Command intent chưa được correlation với register stream, internal FIFO/FSM state |
| Response observation | Scoreboard response correlation + response SVA | Scoreboard kiểm tra status, TID, actual length; SVA kiểm tra reserved bits và protocol flow liên quan | Đếm các field-match/pass như functional coverage |
| Correlated transaction | `i3c_correlated_coverage`, nhận record đã ghép từ scoreboard | Command intent × bus result hiện tại; DAT/device và response mở rộng theo từng feature | Sampling hai stream độc lập mà không ghép theo command/TID |
| RTL/SVA | Các file trong `i3c_core/sva/` | FSM transition, handshake, stall, timing counter, reset point, OD/PP phase, FIFO boundary | Bus-level payload/address coverage đã có trong monitor |

### 3.1 Quy tắc sampling

1. `cg_dat_entry` chỉ sample khi address thuộc DAT window và word-aligned; dùng `wdata` cho write và `rdata` cho read.
2. `cg_cmd_desc` chỉ sample sau khi nhận đủ DWORD0 và DWORD1 của `CMD_QUEUE_PORT`; DAT index được group thành first/middle/last và DAA count thành 0/1/2/3+.
3. Bus covergroup chỉ sample khi monitor hoàn tất một `i3c_item`, không sample từng clock.
4. `cg_hc_control` và `cg_queue_sw_port` chỉ cover policy software ảnh hưởng trực tiếp đến transfer; register-map và timing CSR bị loại khỏi core protocol coverage metric, còn correctness được kiểm tra bởi CSR vseq/checker và các SVA áp dụng được.
5. Correlated covergroup chỉ sample khi scoreboard đã ghép xong command, bus transaction và response tương ứng. Với success `wroc=0`, sample bằng event hoàn tất không-response thay vì chờ `RESP_PORT`.
6. Equality của address/direction/RESP fields, payload integrity và recovery result là checker result: mismatch phải fail test, không được tính là coverage bin.
7. Illegal/reserved bins dùng cho negative test; các giá trị không thể sinh bởi RTL phải là `ignore_bins` hoặc được waiver, không để làm giảm coverage vô hạn.

## 4. Register và command descriptor coverage

### 4.1 Register access

| ID | Feature/scenario | Coverage item và bins | Nguồn | Test/vseq chính | Trạng thái |
|---|---|---|---|---|---|
| REG-001..006 | Register-map access và unmapped access | Không giữ bins read/write × từng địa chỉ; correctness do CSR vseq/checker và SVA áp dụng được kiểm tra | CSR vseq/checker + SVA một phần | CSR vseqs | `Excluded` from core protocol metric |
| REG-007 | HC enable | `cg_hc_control.cp_bus_enable`: 0, 1; transition 0=>1, 1=>0. Reset semantics do SVA cover | Register monitor + SVA | `csr_enable_disable_vseq` | `SVA` + `Implemented` |
| REG-008 | Broadcast header enable | `cp_broadcast_enable`: 0, 1; `cx_bus_broadcast` với BUS_ENABLE | Register monitor + SVA | `csr_broadcast_header_control_vseq` | `SVA` + `Implemented` |
| REG-009 | HC abort control | `cp_hc_abort`: 0, 1; transition set/clear. Idle/active và hold do SVA cover | Register monitor + SVA | `csr_hc_abort_control_vseq`, abort vseqs | `SVA` + `Implemented` |
| REG-010 | Software reset request | `cp_idle_reset_control_write_pulses_soft_reset`: idle accepted; `cp_busy_reset_control_write_ignored`: busy ignored; `cp_sw_reset_self_clear`: accepted pulse tự clear | SVA | `csr_sw_reset_flush_queues_vseq`, `i3c_sw_reset_while_busy_policy_vseq` | `SVA` |
| REG-011..012 | Timing register programming | Không giữ bins zero/one/middle/max × từng timing CSR; read/write correctness do CSR vseq/checker và SVA áp dụng được kiểm tra | CSR vseq/checker + SVA một phần | `csr_timing_rw_vseq` | `Excluded` from core protocol metric |
| REG-013 | DAT device type | `cg_dat_entry.cp_device`: I3C (`device=0`), legacy I2C (`device=1`); raw read/write access direction không được cross lại | Register monitor | `csr_dat_rw_all_entries_vseq`, I2C vseqs | `Implemented` |
| REG-014 | DAT address correctness | Không giữ raw DAT address-range bins: legal I2C address class thuộc BUS-003/I2C-001, assigned dynamic address thuộc DAA-006; DAT field correctness/readback do CSR checker xử lý | Bus/DAA coverage + CSR checker | DAT, SDR, I2C và DAA vseqs | Split ownership; excluded duplicate register bins |
| REG-015 | Queue software port usage | `cg_queue_sw_port.cp_queue_op`: accepted CMD push, TX push, RX pop, RESP pop request | Register monitor | CSR queue và transfer vseqs | `Implemented` |
| REG-016 | Empty RX/RESP read | RX empty, RESP empty; returned data zero | SVA | `csr_rx_resp_read_pop_vseq` | `SVA` |

### 4.2 Command descriptor

| ID | Feature/scenario | Coverage item và bins | Nguồn | Test/vseq chính | Trạng thái |
|---|---|---|---|---|---|
| CMD-001 | Descriptor attribute | `cp_cmd_attr`: Regular, Immediate, AddressAssignment và một bin `unsupported` gộp Combo/reserved 4..7 | Register monitor | SDR/IMM/DAA và invalid descriptor vseqs | `Implemented` |
| CMD-002 | Direction | `cp_cmd_rnw`: write, read; `iff` attribute có RNW | Register monitor | SDR read/write, I2C read/write | `Implemented` |
| CMD-003 | Terminate on completion | `cp_cmd_toc`: continue (`0`), terminate (`1`) | Register monitor | `i3c_write_toc_zero_vseq`, `i3c_read_toc_zero_vseq`, `i3c_imm_toc_vseq` | `Implemented` |
| CMD-004 | Response on completion | `cp_cmd_wroc`: suppress-success (`0`), response-required (`1`) | Register monitor | `i3c_wroc_policy_vseq` | `Implemented` |
| CMD-005 | Regular/Combo data length | `cp_cmd_data_len`: 0, 1, 2..4, 5..8, 9..16, 17..65535 | Register monitor | read/write length sweep | `Implemented` |
| CMD-006 | Immediate DTT | `cp_cmd_dtt`: từng valid 0..4 và một bin `unsupported` gộp 5..7 | Register monitor | `i3c_imm_dtt_sweep_vseq`, invalid descriptor vseq | `Implemented` |
| CMD-007 | DAA device count | `cp_cmd_dev_count`: 0, 1, 2, 3..15 | Register monitor | DAA vseqs | `Implemented` |
| CMD-008 | Descriptor DAT index | `cp_cmd_dat_idx`: first, middle, last cho known attribute | Register monitor | multi-DAT và DAA boundary vseqs | `Implemented` |
| CMD-009 | Regular direction × length | Không giữ descriptor-level Cartesian cross; direction/length intent là coverpoint riêng, actual supported path thuộc BUS-011 | Register monitor + bus monitor | read/write length sweep | `Implemented` without duplicate cross |
| CMD-010 | Attribute × TOC | `cx_cmd_attr_toc`, bỏ reserved attribute | Register monitor | TOC và descriptor vseqs | `Implemented` |
| CMD-011 | Transaction ID | Equality với response TID do scoreboard/SVA check; không cover từng giá trị TID | Scoreboard + SVA | back-to-back vseqs | Scoreboard check + `SVA` |
| CMD-012 | Transfer mode | `cp_cmd_mode`: SDR0 và một bin `unsupported` gộp SDR1..4/HDR/reserved; HDR không trở thành closure goal riêng | Register monitor | normal transfer và invalid descriptor vseq | `Implemented` |
| CMD-013 | Command-present bit | `cp_cmd_present`: 0, 1; `cx_cmd_attr_present`; bỏ AddressAssignment/reserved | Register monitor | CCC/regular và invalid descriptor vseqs | `Implemented` |
| CMD-014 | CCC opcode in descriptor | `cp_cmd_code`: broadcast/direct ENEC, broadcast/direct DISEC, ENTDAA, unsupported other opcode | Register monitor | CCC vseqs | `Implemented` |
| CMD-015 | Regular SRE | `cp_cmd_sre`; RTL thực thi SRE. DBP không được sample vì Regular CCC (`CP=1`) chưa được hỗ trợ và bị trả `NotSupported` | Register monitor | short-read vseq | `Implemented` |
| CMD-016 | Command staging | first DWORD only, unrelated CSR interleave, completed pair, reset-cleared partial pair | SVA | CMD staging CSR vseqs | `SVA` |
| CMD-017 | Attribute × device type | `cx_cmd_attr_device`: Regular/Immediate/AddressAssignment × I3C/I2C, chỉ sample DAT index đã được software cấu hình | Correlated register/DAT shadow | SDR, IMM, I2C, DAA vseqs | `Implemented` |
| CMD-018 | Attribute × DAT index | Bỏ Cartesian cross; DAT boundary được cover riêng bởi CMD-008 và DAA-004 | Register monitor + scoreboard | multi-DAT và DAA boundary vseqs | `Implemented` |
| CMD-019 | Previous × next command | Bỏ descriptor-order cross; STOP/RSTART/TOC/reset boundary do `cg_command_boundary` và SVA cover | Correlated transaction + SVA | back-to-back và TOC continuation vseqs | `Implemented` |

## 5. Bus transaction coverage

Các mục bus-observable trong phần này thuộc `i3c_coverage`. Collector chuẩn hóa mỗi `i3c_item` thành các address phase và logical transfer trước khi sample; command intent, requested length, DAT index và response result vẫn thuộc correlated coverage. Các dòng ghi `SVA` có cover độc lập ở RTL.

### 5.1 Common transaction framing

| ID | Feature/scenario | Coverage item và bins | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| BUS-001 | Protocol type | `cg_bus_transfer.cp_protocol`: I3C, I2C; address-phase collector không đếm lặp dimension này | Tất cả transfer vseqs | `Implemented` |
| BUS-002 | Bus direction | `cp_bus_op`: write, read | SDR và I2C vseqs | `Implemented` |
| BUS-003 | Address class | broadcast `0x7e`, I3C dynamic, I2C static, reserved/other negative | CSR broadcast, SDR, I2C, CCC, DAA | `Implemented` |
| BUS-004 | Address ACK | ACK, NACK cho từng broadcast-header/target/CCC/DAA address phase | success và NACK vseqs | `Implemented` |
| BUS-005 | Actual byte count | 0, 1, 2..4, multi-DWORD 5+; final remainder 0/1/2/3 cover packing boundary riêng | length sweep, abort/overflow | `Implemented` |
| BUS-006 | Payload integrity by protocol/direction | `cg_data_integrity.cp_protocol_direction`: I3C write, I3C read, I2C write, I2C read; chỉ sample sau khi scoreboard đã xác nhận toàn bộ payload | TX/RX byte-order và length sweep | `Implemented` correlated |
| BUS-007 | Start source | START, repeated START cho từng address phase | TOC, direct CCC, DAA | `Implemented` |
| BUS-008 | End condition | STOP/RSTART/TOC/reset boundary do `cg_command_boundary` và SVA sở hữu; raw bus end-condition/interrupted bins bị bỏ để tránh đếm lặp | TOC, abort, short-read | `Implemented` boundary + `SVA` |
| BUS-009 | Private preamble | `cg_private_preamble_correlation.cp_preamble_policy`: dynamic-first, `0x7e/W + Sr + dynamic`, continuation và I2C-no-header | broadcast control, SDR/I2C read/write | `Implemented` correlated |
| BUS-010 | Transaction termination | `cg_sdr_read_length_t_bit` cover final T-bit × exact/early/beyond; `cg_abort_termination` phân loại HC abort/reset/protocol termination × abort point và byte boundary. Reset active-point chi tiết tiếp tục do SVA sở hữu | abort/reset vseqs | `Implemented` correlated cause + `SVA` internal point |
| BUS-011 | Protocol × direction × length | I3C/I2C read/write × zero/one/2..4/5+ actual-length class | length sweep | `Implemented` |
| BUS-012 | Address class × ACK | ACK/NACK ở broadcast, dynamic, static và direct CCC address | NACK vseqs | `Implemented` |
| BUS-013 | Preamble × direction | Không giữ raw preamble × direction cross; policy thuộc BUS-009, direction thuộc BUS-002 và equality do scoreboard check | CSR broadcast, SDR vseqs | `Implemented` without duplicate cross |
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
| SDR-008 | Multi-DAT target | DAT index first/middle/last và scoreboard check expected/observed target address/payload; boundary bin không cross với từng command attribute | multi-DAT vseqs | Scoreboard check + `Implemented` boundary coverage |
| SDR-009 | Back-to-back direction | `cg_private_rstart_transition.cx_previous_next_op`: W=>W, R=>R, W=>R, R=>W; history clear khi reset/non-private | back-to-back và TOC continuation vseqs | `Implemented` |
| SDR-010 | Data integrity | `cg_data_integrity.cp_protocol_direction`: I3C/I2C × read/write. Write sample sau full bus-payload check; read sample chỉ sau khi software đọc và scoreboard check toàn bộ RX FIFO payload. Payload pattern không phải feature closure dimension; mismatch vẫn là checker error | scoreboard event, SDR/I2C/byte-order/multi-DAT vseqs | Scoreboard check + `Implemented` correlated metric |

### 5.3 Immediate transfer

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| IMM-001 | Immediate length by protocol | `cg_immediate_transfer.cx_protocol_dtt`: I3C and I2C × DTT 0, 1, 2, 3, 4 | `i3c_imm_dtt_sweep_vseq`, `i3c_imm_i2c_write_vseq` | `Implemented` command + correlated bus |
| IMM-002 | Immediate device type | `cg_immediate_transfer.cp_protocol`: I3C dynamic target, I2C static target | `i3c_imm_vseq`, `i3c_imm_i2c_write_vseq` | `Implemented` correlated |
| IMM-003 | Immediate TOC policy | TOC1 success, TOC0 NotSupported/no continuation | `i3c_imm_toc_vseq` | `SVA` |
| IMM-004 | Invalid DTT | `reg_coverage.cp_cmd_dtt.unsupported`: gộp DTT 5..7; NotSupported/no bus access checked by SVA | `i3c_imm_dtt_sweep_vseq` | `Implemented` register coverage + SVA |
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
| I2C-008 | I2C direction × ACK profile | Bỏ raw ACK-profile coverage; write data-NACK theo first/middle/last ở I2C-003, read ACK/NACK policy do SVA cover | I2C và error vseqs | `SVA` + `Implemented` correlated |

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
| CCC-007 | CCC ACK outcome | broadcast ACK/NACK và direct target ACK/NACK; raw opcode/event T-bit value không là coverage goal, parity correctness thuộc SVA | CCC/error vseqs | `Implemented` bus observation + `SVA` parity |
| CCC-008 | Opcode/form và response | Opcode × form thuộc `cg_ccc`; CCC status thuộc `cg_response_status.cx_status_cmd_class`; scoreboard kiểm tra mapping response. Không giữ thêm Cartesian opcode × form × status | CCC/error/abort vseqs | `Implemented` split ownership + checker |

### 6.2 Dynamic Address Assignment

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| DAA-001 | Requested device count | 0, 1, 2, 3..15 | DAA vseqs | `Implemented` command |
| DAA-002 | Actual joined count | `cg_daa_result.cp_joined_count`: accepted assignment count 0, 1, multiple; requested count cũng group one/multiple | single/no-device/multi-device vseqs | `Implemented` |
| DAA-003 | DAA result | `cg_daa_result.cp_result`: assigned-all/fewer/no-device/address-rejected/overflow/abort; requested/joined count là coverpoint riêng và cardinality mapping do scoreboard kiểm tra | DAA và error vseqs | `Implemented` correlated + checker |
| DAA-004 | DAT start/boundary, multi-round progression và resolved identity stream | `cg_daa_dat_boundary.cx_start_span_response`: first/middle/last start × within/ends-at-last/crosses-boundary span × accepted/boundary-rejected. Round count và PID/BCR/DCR order được directed checker kiểm tra, không tạo thêm raw count/pattern bins | DAA multi-device DAT-loop and boundary vseqs | `Implemented` correlated + directed check |
| DAA-005 | PID/BCR/DCR integrity | Scoreboard so sánh đầy đủ identity stream và RX result order; zero/ones/alternating không phải feature bins | DAA stimulus variants | Scoreboard check; excluded from metric |
| DAA-006 | Assigned address | `cg_daa_assigned_address.cp_address_class`: low `0x08..0x1f`, middle `0x20..0x5f`, high `0x60..0x77`; reserved bị ignore và xử lý bởi DAA-010. Parity correctness thuộc scoreboard/SVA, không cross raw parity 0/1 | DAA single/multi/boundary/rejected vseqs | Scoreboard/SVA + `Implemented` address class |
| DAA-007 | Round termination | `cg_daa_round.cp_round_outcome`: assigned-address ACK/NACK, no-device address NACK, interrupted ID phase, other | DAA/error vseqs | `SVA` + `Implemented` bus observation |
| DAA-008 | Requested/joined count và outcome | Count classes và result cover độc lập; không Cartesian-cross count với mọi outcome, joined-count legality do scoreboard/SVA check | DAA vseqs | `SVA` + `Implemented` |
| DAA-009 | Result × response status | `cg_daa_result_response.cx_result_response`: normal completion=>Success, reject=>Nack, overflow=>Ovl, abort=>HcAborted, sampled only after response status/TID/length correlation passes | DAA/error vseqs | `Implemented` correlated |
| DAA-010 | Reserved assigned dynamic address | `cp_entdaa_reserved_dat_rejects_before_rstart`, `cp_addr_assign_reserved_addr_uses_common_stop_path`, and `cp_addr_assign_reserved_addr_not_supported_resp`: reserved DAT address is detected before the DAA round, no `7'h7E+R` round is issued for that address, STOP path is used, and RESP is `NotSupported` | `i3c_daa_reserved_addr_resp_vseq` | `SVA` + scoreboard check |
| DAA-011 | DAA FSM paths | ACK receive ID, send address, result commit, no-device, wait-stop, idle return | DAA vseqs | `SVA` |
| DAA-012 | DAA abort point | identity receive, assigned-address phase, completed-round boundary | DAA abort vseq | `SVA` (`cover property` trong `entdaa_fsm_sva.sv`) |

## 7. Response, error và recovery coverage

### 7.1 Response descriptor

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| RSP-001 | Error status | `cg_response_status.cp_status`: Success, AddrHeader, Nack, Ovl, I3cShortReadErr, HcAborted, I2cDataNackOrI3cBusAborted, NotSupported | normal và response error vseqs | `SVA` selected outcomes + `Implemented` |
| RSP-002 | Defined but unreachable status | Crc, Parity, Frame; `ignore_bins unreachable` trong `cp_resp_status` | N/A | `Excluded` until RTL can generate them |
| RSP-003 | Response TID | Command/RESP TID equality do scoreboard/SVA check; không cover từng TID value | back-to-back, all response vseqs | `SVA` + scoreboard check |
| RSP-004 | Actual response length | `cg_response_length`: requested-length class và relation exact/short/zero/partial-abort/partial-overflow là hai feature dimensions độc lập; scoreboard kiểm tra quan hệ exact | normal/error length vseqs | `Implemented` correlated |
| RSP-005 | Reserved response bits | Reserved bits bằng zero do response-path SVA kiểm tra; scoreboard chỉ correlation status/TID/length | all response-producing vseqs | `SVA` |
| RSP-006 | WROC success policy | `cg_response_presence_policy.cx_cmd_class_wroc_completion_presence`: command class × wroc0-absent/wroc1-present; exact cardinality and duplicate rejection remain scoreboard/SVA-owned | `i3c_wroc_policy_vseq` | `SVA` + checker + `Implemented` correlated presence |
| RSP-007 | WROC error override | `cg_response_presence_policy.cx_cmd_class_wroc_completion_presence`: every applicable command class produces a response on error for wroc0 and wroc1; exact cardinality remains scoreboard/SVA-owned | WROC/error vseqs | `SVA` + checker + `Implemented` correlated presence |
| RSP-008 | Status × command attribute | `cg_response_status.cx_status_cmd_class`: each reachable status for applicable Regular/Immediate/CCC/DAA class; impossible class/status pairs ignored | all response vseqs | `Implemented` correlated |
| RSP-009 | Status × direction | Không giữ full status × direction cross; direction thuộc BUS-002, status × command class thuộc RSP-008, error-direction legality do scoreboard/SVA kiểm tra | all response vseqs | Checker/SVA; excluded duplicate cross |
| RSP-010 | Requested × actual length | Không giữ Cartesian requested-class × relation; hai coverpoint của RSP-004 ghi nhận boundary và outcome, exact mapping do scoreboard kiểm tra | read/write/error vseqs | `Implemented` without duplicate cross |

### 7.2 Error, abort và backpressure

| ID | Feature/scenario | Coverage item và bins/cross | Test/vseq chính | Trạng thái |
|---|---|---|---|---|
| ERR-001 | Private/broadcast address NACK | `cg_address_phase.cx_addr_class_nack` cover ACK/NACK theo broadcast/dynamic/static; `cg_ccc_target.cx_ccc_target_nack` cover direct CCC target ACK/NACK | NACK response vseqs | `SVA` + `Implemented` bus observation |
| ERR-002 | Data NACK | `cg_i2c_write_nack_position`: command class Regular/Immediate và position first/middle/last-requested/none là coverpoint riêng; không cross lại với mọi length/class combination | data-NACK vseqs | `SVA` + `Implemented` correlated |
| ERR-003 | TX underflow | before first data word, after partial progress; I3C/I2C | `i3c_write_tx_fifo_underflow_vseq` | `SVA` |
| ERR-004 | RX overflow | full boundary, partial DWORD; I3C/I2C/ENTDAA | RX overflow vseqs | `SVA` |
| ERR-005 | Short read | `cg_short_read_boundary`: SRE 0/1 và one-byte/DWORD/partial-1/2/3 boundary là coverpoint riêng. Zero-byte bị loại khỏi closure: sau address ACK, target chỉ kết thúc bằng T-bit sau ít nhất một data byte; address NACK và abort-before-data thuộc error/abort coverage | `i3c_read_short_target_end_vseq` | `SVA` policy + `Implemented` correlated boundary |
| ERR-006 | RESP FIFO backpressure | success response, error response, stable descriptor, release writes once | `i3c_resp_fifo_full_backpressure_vseq` | `SVA` |
| ERR-007 | HC abort command class | regular write, regular read, I2C, immediate, CCC, DAA | abort policy vseqs | `SVA` |
| ERR-008 | Abort entry point | idle holdoff, preamble, CCC, TX data, RX data, DAA, response stage | abort/reset vseqs | `SVA` |
| ERR-009 | Abort data boundary | `cg_abort_termination`: cause, abort point và byte boundary 0/1..3/one-DWORD/>one-DWORD cover riêng; giữ cause×point cho phase legality, không cross cause với mọi byte bucket | abort vseqs | `Implemented` correlated + `SVA` reset phase |
| ERR-010 | Error priority over abort | AddrHeader, data NACK, DAA NACK, overflow, short-read, NotSupported | abort policy/error vseqs | `SVA` |
| ERR-011 | Invalid descriptor | each attribute class invalid combination, no DAT/bus access, NotSupported response | invalid descriptor vseqs | `SVA` |
| ERR-012 | Reset point | idle, command fetch, address, TX, RX, CCC/DAA, response write | reset vseqs | `SVA` |
| ERR-013 | Recovery | `cg_recovery`: source, recovery command class, interrupted class và reset point là coverpoint riêng; không cross mọi source với mọi class. Pass/fail do scoreboard/SVA quyết định | abort/reset vseqs | `Implemented` correlated |
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
| COR-002 | Protocol × direction × length | Actual bus space do `cg_bus_transfer.cx_protocol_op_length` sở hữu; requested intent và equality do command coverage/scoreboard sở hữu. Correlated duplicate group đã bỏ | Immediate chỉ write và DTT 0..4 | Bus coverage + scoreboard |
| COR-003 | DAT boundary class | First/middle/last DAT index; DAA span có matrix riêng | Không cross mọi command attribute × mọi index | `Implemented` trong `reg_coverage.cg_cmd_desc` |
| COR-004 | Command/bus direction equality | Scoreboard/SVA check command intent khớp bus direction | Mismatch là test failure, không phải coverage bin | Scoreboard check + `SVA` |
| COR-005 | DAT address equality | Scoreboard check DAT address khớp observed target address | Mismatch là test failure, không phải coverage bin | Scoreboard check + `SVA` |
| COR-006 | Preamble policy | `cg_private_preamble_correlation.cp_preamble_policy`: I2C/I3C × broadcast enable × first header/continuation | Equality first address do scoreboard check | `Implemented` correlated metric |
| COR-007 | Response requested length và result relation | `cg_response_length.cp_requested_len` + `cp_length_relation`; scoreboard kiểm tra actual bus/descriptor length mapping | Không Cartesian-cross mọi length bucket với mọi error relation | `Implemented` cho Regular/Immediate |
| COR-008 | `cg_address_response_correlation.cx_phase_ack_status`: address phase × ACK/NACK × observed response status, chỉ sample sau khi status/TID/length của descriptor đã correlation thành công | ACK/NACK được encode đúng | Broadcast-header hoặc private/direct-target NACK => `AddrHeader`; ACK cho phép success hoặc lỗi phát sinh sau address phase | Scoreboard check + `Implemented` correlated metric |
| COR-009 | `cg_response_status.cx_status_cmd_class`: command class × response status | End-to-end result cho Regular/Immediate/CCC/DAA | Chỉ reachable status mỗi class | `Implemented` |
| COR-010 | Direction × response status | Không giữ full cross; BUS-002 và COR-009 cover hai feature dimensions, legality/mapping do scoreboard/SVA check | Tránh lặp direction qua mọi status | Checker/SVA |
| COR-011 | `cg_response_presence_policy.cx_cmd_class_wroc_completion_presence`: command class × WROC × completion result × response presence | Success suppression và error override trên từng command class | wroc0-success: absent; wroc1-success và mọi error: present; duplicate/missing cardinality do scoreboard/SVA kiểm tra | Scoreboard/SVA check + `Implemented` correlated metric |
| COR-012 | CCC opcode/form, target ACK và status | Opcode×form thuộc bus collector, target ACK thuộc `cg_ccc_target`, status×CCC class thuộc COR-009; mapping do scoreboard kiểm tra | ENTDAA dùng DAA result cross; không tạo 4-D Cartesian cross | Split ownership + checker |
| COR-013 | DAA requested/joined count và result | `cg_daa_result` cover one/multiple requested, zero/one/multiple joined và từng result độc lập | Không Cartesian-cross; cardinality/result consistency do scoreboard/SVA check | `Implemented` + checker |
| COR-014 | Abort point và response status | `cg_abort_termination` cover cause/point/boundary; COR-009 cover response status/class; scoreboard kiểm tra error mapping. Full point×class×status cross đã bỏ | Idle abort là holdoff, reset không gán response giả | SVA + checker + split functional coverage |
| COR-015 | Recovery source và next class | `cg_recovery` giữ source/recovery/interrupted/reset-point coverpoints độc lập | Không Cartesian-cross source × class; active FSM phase thuộc SVA, recovery pass do checker quyết định | `SVA` reset phase + `Implemented` correlated metric |
| COR-016 | Command boundary type | `cg_command_boundary.cp_boundary`: STOP/RSTART/TOC continuation/idle-back-to-back/reset-cleared | Command-class pairing không được Cartesian-cross; legal path do SVA/scoreboard check | `Implemented` boundary coverage |
| COR-017 | `cg_data_integrity.cp_protocol_direction`: protocol × direction | End-to-end payload integrity cho I3C write/read và I2C write/read; read chỉ publish sau full RX FIFO check | Mismatch tiếp tục là `uvm_error`, không phải positive closure bin | Scoreboard check + `Implemented` correlated metric |
| COR-018 | Stall type | `cg_stall_recovery.cp_stall_type`: TX empty/RX full/RESP full/WaitCmd | Không yêu cầu mỗi stall trên mọi command class; internal handshake/recovery pass thuộc SVA/scoreboard | `SVA` stall behavior + `Implemented` correlated metric |

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
8. Nếu một covergroup có cross làm closure owner, các component coverpoint của cross chỉ là diagnostic bins và không được cộng lại vào mẫu số KPI. Các closure owner điển hình là protocol×direction×length, DAA result×response, address ACK/NACK×status, WROC×completion×response-presence và previous-op×next-op.
9. `cp_reset_readback_unmapped_020` được giữ làm diagnostic nhưng waive khỏi SVA closure vì một raw unmapped address cụ thể không phải feature F1-F10.

## 12. Baseline sign-off sau khi đơn giản hóa

- Coverage regression seed 1 ngày 2026-07-15: 81/81 UVM summaries có `UVM_ERROR=0`, `UVM_FATAL=0`.
- Functional closure bins: 222/222 (100.0%). Diagnostic component bins: 173/173 (100.0%); diagnostic bins không được cộng lại vào KPI.
- SVA: 386/386 assertions PASS, 578/578 in-scope cover properties HIT, không có FAIL/VACUOUS/MISS.
- `cp_reset_readback_unmapped_020` là waiver duy nhất và bị loại khỏi mẫu số SVA; property vẫn được giữ để debug.
- Zero-byte short read không phải hole: case này unreachable sau address ACK và đã được loại khỏi functional closure.
- Directed contribution xác nhận DAA middle-span ends-at-last/crossing, reserved DAT sau một vòng join, I2C-no-header khi enable, queued-command reset, WROC CCC error/RESP-full, read-abort TOC0 và private W=>R repeated START.
- Core functional coverage chỉ chứa feature transaction: transfer type/length, CCC/DAA, response status/length/WROC, address/data NACK, short read, abort, command boundary và stall type.
- Register-map, timing CSR, raw response descriptor fields, payload byte-level, equality/match và pass/fail checker result không còn là functional coverage bins.
- Các mismatch của address, direction, response fields, payload integrity và recovery tiếp tục là scoreboard/SVA failure.
