# SVA Miss Investigation Report

## 1. Phạm vi

Báo cáo này điều tra và đưa ra quyết định cho các SVA miss sau trong
`src/verification/sva_coverage_report.txt`:

- `ap_sdr_write_no_cmd_pop_except_continuation`
- `cp_sdr_write_no_cmd_pop_except_continuation`
- `ap_i2c_never_enters_broadcast_header`
- `ap_pad_model_turnaround_overlap_one_cycle`
- `cp_pad_model_turnaround_overlap_one_cycle`
- `cp_hc_abort_read_contention`

Việc điều tra dựa trên SVA source, RTL FSM, UVM stimulus, lịch sử Git và hai lần
ghi nhận coverage: report 240 test ngày 2026-07-05 và report 80 test ngày
2026-07-08. Cả hai report đều ghi nhận các property trên là `MISS`.

## 2. Kết luận

| Nhóm | Quyết định | Lý do chính |
|---|---|---|
| SDR write command pop invariant | Giữ AP dưới dạng converse; xóa CP trùng lặp | AP bảo vệ mọi active cycle; dạng converse tạo coverage event tại legal continuation |
| I2C never enters broadcast header | Giữ AP dưới dạng converse | Hai assertion chuyển trạng thái không bao phủ entry từ state/path khác |
| Pad-model turnaround overlap | Xóa AP, CP và exception | Handoff hiện tại đã loại scheduler artifact; exception chưa từng được hit |
| HC-abort read contention | Xóa CP và exception | Không xuất hiện trong các test abort; giữ exception có thể che contention thật |

## 3. Phân tích chi tiết

### 3.1 SDR write không pop CMD ngoài accepted continuation

Trong `flow_active.sv`, `cmd_queue_rready` mặc định bằng `0`. Ngoài thời điểm
nhận command ban đầu tại `WaitForCmd`, tín hiệu chỉ được bật bởi
`accept_continuation_cmd()`. Task này chỉ được gọi khi transfer hoàn thành với
`toc=0`, command kế tiếp available/supported, và điều kiện WROC/RESP-ready được
thỏa mãn.

Các property theo từng nhánh continuation/error chỉ kiểm tra thời điểm transfer
hoàn thành. Chúng không phát hiện một CMD pop sai ở `InitWrite`, `FetchTxData`
hoặc giữa `IssueI3CWrite`; pop như vậy sẽ ghi đè `cmd_desc` của transaction đang
chạy. Vì vậy invariant tổng quát vẫn là một guard độc lập cần giữ.

Dạng cũ dùng điều kiện "không phải accepted continuation" làm antecedent nhưng
Xcelium ghi `pass=0` ngay cả trong `i3c_write_vseq`. Property được đổi sang dạng
converse tương đương trong logic hai trạng thái: nếu CMD pop trong active SDR
write thì toàn bộ điều kiện accepted continuation phải đúng. Legal continuation
được cover sẵn bởi `cp_toc0_accept_continuation`.

Thay đổi:

- Giữ `ap_sdr_write_no_cmd_pop_except_continuation` dưới dạng converse.
- Xóa `cp_sdr_write_no_cmd_pop_except_continuation`.
- Giữ helper `sdr_write_active_state()` cho invariant.

### 3.2 Legacy I2C không vào I3C broadcast header

Nhánh `WaitDAT` của RTL chọn trực tiếp `InitWrite` hoặc `InitRead` khi
`target_is_i3c=0`. Chỉ I3C target, CCC và ENTDAA có đường vào
`I3CBcastHeader`.

Hai property sau đã kiểm tra chính xác hai đường chuyển trạng thái legacy I2C:

- `ap_i2c_write_skips_broadcast_header`
- `ap_i2c_read_skips_broadcast_header`

Hai property trên chỉ kiểm tra transition từ `WaitDAT` với các điều kiện local
`!dat_read_valid_hw_o` và `!cont_pending_q`. Chúng không thay thế invariant cấm
I2C descriptor xuất hiện tại `I3CBcastHeader` do entry từ state/path khác.

Coverage cô lập xác nhận `i2c_regular_write_basic_vseq` làm
`ap_i2c_write_skips_broadcast_header` pass 4 lần, trong khi dạng cũ của
`ap_i2c_never_enters_broadcast_header` vẫn có `pass=0`. Do đó MISS không phải do
thiếu I2C stimulus. Property được giữ nhưng đổi sang converse: khi state là
`I3CBcastHeader`, descriptor không được là legacy I2C.

Thay đổi: giữ `ap_i2c_never_enters_broadcast_header` dưới dạng converse.

Hai cover scenario I2C với `broadcast_header_enable=1` không bị xóa; chúng vẫn
cần stimulus riêng để chứng minh bit broadcast-header bị bỏ qua đối với legacy
I2C.

### 3.3 Pad-model turnaround overlap

Target model hiện tại gọi `wait_for_i3c_target_sda_handoff()` trước khi drive
SDA và release push-pull drive sau data/T-bit. Cả regression 240 test và 80 test
đều không quan sát thấy `model_turnaround_overlap`.

Điều này cho thấy exception một cycle được thêm cho scheduler artifact cũ không
còn phù hợp với pad model hiện tại. Nếu overlap DUT-low/target-high xuất hiện
trở lại, nó phải được báo là contention thay vì được miễn trong một cycle.

Thay đổi:

- Xóa `model_turnaround_overlap`.
- Xóa `ap_pad_model_turnaround_overlap_one_cycle`.
- Xóa `cp_pad_model_turnaround_overlap_one_cycle`.
- Không còn loại turnaround overlap khỏi `unsafe_contention`.

### 3.4 HC-abort read contention

Regression đã chứa early/deep HC-abort read nhưng không hit
`cp_hc_abort_read_contention`. RTL chỉ thực hiện STOP/takeover khi bus TX/RX đã
idle và target model có cơ chế handoff/release SDA.

Exception cũ cho phép DUT drive low đồng thời target drive push-pull high khi
`hc_abort=1`. Nó cũng cho phép bus resolved thành unknown và vô hiệu hóa kiểm
tra DUT-low kéo bus-low trong đúng trường hợp nguy hiểm nhất. Vì tình huống này
không phải hành vi protocol mong đợi, exception có thể che lỗi pad-model hoặc
driver thật.

Thay đổi:

- Xóa `hc_abort_read_contention`.
- Xóa `cp_hc_abort_read_contention`.
- `unsafe_contention` không còn miễn contention khi HC abort.
- `ap_pad_model_signals_known` yêu cầu SDA bus luôn known sau reset.
- `ap_dut_sda_low_drive_bus_low` luôn yêu cầu DUT-low kéo bus-low, kể cả khi HC abort.

## 4. Ảnh hưởng coverage dự kiến

Thay đổi loại 1 assertion miss và 3 cover-property miss; đồng thời chuyển 2
assertion miss sang dạng converse dự kiến có PASS event. Nếu áp dụng trực tiếp
lên số liệu report 80 test hiện có, tổng lý thuyết thay đổi như sau:

| Metric | Trước | Sau thay đổi | Closure lý thuyết |
|---|---:|---:|---:|
| Assertions | 411, gồm 404 PASS và 7 MISS | 410, gồm 406 PASS và 4 MISS | 99.0% |
| Cover properties | 590, gồm 577 HIT và 13 MISS | 587, gồm 577 HIT và 10 MISS | 98.3% |

Đây là phép tính từ report cũ, không phải kết quả regression mới.

## 5. Kiểm tra thực hiện

- Coverage cô lập trên parent commit với `i3c_write_vseq`,
  `i2c_regular_write_basic_vseq` và `i3c_read_abort_vseq` xác nhận hai invariant
  dạng cũ vẫn có `pass=0` dù các property stimulus lân cận đã pass.
- Coverage sau khi rewrite với `i3c_write_toc_zero_vseq` và
  `i2c_regular_write_basic_vseq` xác nhận:
  - `ap_sdr_write_no_cmd_pop_except_continuation`: `pass=1`, `fail=0`.
  - `ap_i2c_never_enters_broadcast_header`: `pass=1`, `fail=0`.
  - `ap_i2c_write_skips_broadcast_header`: `pass=4`, `fail=0`.
  - `cp_toc0_accept_continuation`: `hits=1`.
- Full `make regression COV=1 SEED=1` hoàn thành 81/81 UVM summary với tổng
  `UVM_ERROR=0` và `UVM_FATAL=0`.
- `git diff --check` không phát hiện whitespace error.
- Xcelium 18.03 vẫn phát sinh diagnostic môi trường `*E,IMPDLL` cho
  `_sv_export.so` ở mỗi simulation; các simulation tiếp tục chạy và kết thúc
  với UVM summary sạch.

Report mới đã được export từ 81 UCD cùng schema. Kết quả cuối: 386/386
assertions PASS, 578/578 cover properties trong phạm vi HIT, không có
FAIL/VACUOUS/MISS; `cp_reset_readback_unmapped_020` được báo cáo WAIVED.

## 6. Waiver policy

`cp_reset_readback_unmapped_020` được giữ trong `csr_registers_sva.sv` để debug
raw readback tại địa chỉ unmapped `0x020`, nhưng được báo cáo `WAIVED` và loại
khỏi mẫu số SVA closure. Đây là một địa chỉ CSR cụ thể, không phải feature F1-F10.
Không có assertion failure nào được waive; zero-byte short read cũng không dùng
waiver SVA vì đã được loại khỏi functional closure như một scenario unreachable.
