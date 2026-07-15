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
| SDR write command pop invariant | Xóa AP, CP và helper không còn dùng | Trùng trực tiếp với cấu trúc RTL và các assertion theo từng nhánh continuation/error |
| I2C never enters broadcast header | Xóa AP | Trùng với hai assertion chuyển trạng thái I2C read/write cụ thể |
| Pad-model turnaround overlap | Xóa AP, CP và exception | Handoff hiện tại đã loại scheduler artifact; exception chưa từng được hit |
| HC-abort read contention | Xóa CP và exception | Không xuất hiện trong các test abort; giữ exception có thể che contention thật |

## 3. Phân tích chi tiết

### 3.1 SDR write không pop CMD ngoài accepted continuation

Trong `flow_active.sv`, `cmd_queue_rready` mặc định bằng `0`. Ngoài thời điểm
nhận command ban đầu tại `WaitForCmd`, tín hiệu chỉ được bật bởi
`accept_continuation_cmd()`. Task này chỉ được gọi khi transfer hoàn thành với
`toc=0`, command kế tiếp available/supported, và điều kiện WROC/RESP-ready được
thỏa mãn.

Do đó `ap_sdr_write_no_cmd_pop_except_continuation` lặp lại cấu trúc điều khiển
của RTL. Các nhánh có ý nghĩa chức năng đã được kiểm tra riêng bởi các property
cho accepted continuation, missing continuation, unsupported continuation,
WROC backpressure, abort, overflow và short read. Property tổng quát không bổ
sung điểm kiểm tra độc lập và không tạo coverage bin hữu ích dù regression đã
thực hiện nhiều SDR write.

Thay đổi:

- Xóa `ap_sdr_write_no_cmd_pop_except_continuation`.
- Xóa `cp_sdr_write_no_cmd_pop_except_continuation`.
- Xóa helper `sdr_write_active_state()` vì không còn nơi sử dụng.

### 3.2 Legacy I2C không vào I3C broadcast header

Nhánh `WaitDAT` của RTL chọn trực tiếp `InitWrite` hoặc `InitRead` khi
`target_is_i3c=0`. Chỉ I3C target, CCC và ENTDAA có đường vào
`I3CBcastHeader`.

Hai property sau đã kiểm tra chính xác hai đường chuyển trạng thái legacy I2C:

- `ap_i2c_write_skips_broadcast_header`
- `ap_i2c_read_skips_broadcast_header`

`ap_i2c_never_enters_broadcast_header` là invariant tổng quát trùng với hai
property trên. Việc assertion này vẫn `MISS` trong khi các I2C assertion và
cover khác đã hit cho thấy nó không phải coverage hook phù hợp, thay vì cho thấy
regression thiếu I2C stimulus.

Thay đổi: xóa `ap_i2c_never_enters_broadcast_header`.

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

Thay đổi loại 3 assertion miss và 3 cover-property miss. Nếu áp dụng trực tiếp
lên số liệu report 80 test hiện có, tổng lý thuyết thay đổi như sau:

| Metric | Trước | Sau khi loại property | Closure lý thuyết |
|---|---:|---:|---:|
| Assertions | 411, gồm 404 PASS và 7 MISS | 408, gồm 404 PASS và 4 MISS | 99.0% |
| Cover properties | 590, gồm 577 HIT và 13 MISS | 587, gồm 577 HIT và 10 MISS | 98.3% |

Đây là phép tính từ report cũ, không phải kết quả regression mới.

## 5. Kiểm tra thực hiện

- Không còn reference đến các AP/CP, exception wire hoặc helper đã xóa trong
  thư mục SVA.
- `git diff --check` không phát hiện whitespace error.
- Chưa chạy compile/regression và chưa tái tạo SVA coverage report vì Xcelium
  `xrun` không có trên `PATH` của môi trường hiện tại.

Report coverage hiện có được giữ nguyên như một generated artifact lịch sử.
Sau khi chạy lại Xcelium regression, cần tái tạo `sva_coverage_report.txt` để
xác nhận số lượng property và closure mới.
