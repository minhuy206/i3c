# Task 1 Completion Report

**Project**: I3C SVA AP/CP Redundancy Review and Closure  
**Date**: 2026-07-15  
**Status**: ✅ Complete

---

## Chat Interface Output

Đã hoàn tất báo cáo cho phiên rà soát và tinh gọn SVA AP/CP.

- Đã bỏ 4 assertion và 3 cover trùng chức năng; các property tổng quát hoặc property chuyên biệt theo từng hướng đọc/ghi vẫn giữ đầy đủ khả năng bắt lỗi.
- Đã bổ sung stimulus cho CSR backpressure/reset, I2C khi bật broadcast-header, TOC=0, abort, WROC và DAA. Sau caveat review, AP/CP WROC1 đã được khôi phục đủ ba read-only guard để giữ semantics cũ mà vẫn tương thích việc chấm coverage của Xcelium.
- Full coverage regression tạo 81 database: 386/386 assertion PASS, không FAIL/VACUOUS/MISS; 578/578 cover trong scope HIT. Một cover unmapped-address mang tính chẩn đoán được waiver và không tính vào closure. Closure đạt 100%.
- Không sửa RTL synthesizable. Các thay đổi dirty không liên quan trong worktree được giữ nguyên.

Báo cáo chi tiết: [task_1_completed.md](/home/minhuy/Workspaces/i3c/reports/i3c-sva-ap-cp-redundancy/task_1_completed.md).

---

## Task Overview

**Task ID**: Task 1

**Description**: Rà soát các block `ap_` (assert property) và `cp_` (cover property) trong SVA, loại bỏ các check trùng lặp không tăng khả năng phát hiện lỗi, bổ sung stimulus cho các scenario chưa được kích hoạt, rồi xác nhận closure bằng Xcelium coverage regression.

**Objectives**:

- Xác định assertion/cover bị trùng về điều kiện và trách nhiệm kiểm tra.
- Chỉ xóa property khi một property khác vẫn chứng minh cùng hành vi hoặc mạnh hơn.
- Bổ sung directed stimulus cho các AP/CP có ý nghĩa nhưng chưa được kích hoạt.
- Đồng bộ test plan và giải thích lý do tinh gọn bằng tiếng Việt.
- Chạy targeted verification, full regression và tái tạo SVA coverage report.

**Success Criteria**:

- Không còn label `ap_` hoặc `cp_` bị trùng.
- Không có assertion FAIL, VACUOUS hoặc MISS trong regression cuối.
- Tất cả cover nằm trong scope closure đều HIT.
- Không làm suy giảm khả năng phát hiện lỗi và không sửa RTL synthesizable.
- Không đưa simulator artifact vào source changes.

**Context**: Công việc áp dụng quy ước SVA trong `AGENTS.md`: mọi assertion/cover có label, assertion cần matching cover trừ khi có lý do kỹ thuật rõ ràng, và vseq chỉ kiểm tra hành vi đặc thù chưa được scoreboard sở hữu.

---

## Execution Timeline

### 22:15 - Rà soát SVA và coverage ownership

Đọc toàn bộ label `ap_`/`cp_`, so sánh antecedent, consequent và feature ownership giữa các property tổng quát, property theo loại descriptor, property continuation và các composite cover.

**Decisions**:

- Giữ các property nhỏ, độc lập vì chúng cho biết chính xác phần hành vi nào hỏng.
- Xóa property chuyên biệt nếu property tổng quát đã kiểm tra cùng antecedent và cùng hoặc mạnh hơn về consequent.
- Xóa composite cover nếu tất cả thành phần của chuỗi đã có cover độc lập và composite không đại diện cho feature closure riêng.

### 22:22 - Bổ sung directed stimulus

Cập nhật các vseq hiện hữu thay vì tạo stress test mới.

**Actions**:

- Đọc unmapped CSR `12'h020` ngay sau reset.
- Tạo CMD FIFO full và giữ request pending để kiểm tra `ready_o=0` cùng dữ liệu ổn định dưới backpressure.
- Chạy I2C read/write khi I3C broadcast-header enable đang bật.
- Thêm TOC=0 với next command không hợp lệ ở vai trò continuation nhưng vẫn hợp lệ khi thực thi độc lập.
- Queue continuation trước read abort và chứng minh abort không pop command đó.
- Tạo WROC=1 continuation khi RESP FIFO full, chứng minh stall rồi resume sau khi có chỗ trống.
- Thêm `i3c_daa_reserved_addr_resp_vseq` vào DAA regression list.

### 22:30 - Tinh gọn và hiệu chỉnh SVA

Trong phạm vi báo cáo này, các thay đổi SVA được quy thuộc cho task nằm tại
`flow_active_sva.sv`. Worktree đồng thời chứa các thay đổi chưa commit trong
những file SVA khác; do không có clean pre-task snapshot, `git diff` hiện tại
không thể tự chứng minh ownership của từng thay đổi đó.

**Removed assertions**:

- `ap_imm_dtt_gt4_not_supported_resp`: `invalid_cmd_desc()` đã bao gồm `dtt > 4`; assertion invalid-command tổng quát đã kiểm tra response `NotSupported`.
- `ap_addr_assign_invalid_rejected_before_access`: assertion invalid-command tổng quát đã kiểm tra không DAT/bus access và chuyển sang `WriteResp`.
- `ap_addr_assign_invalid_not_supported_resp`: response của AddressAssignment không hợp lệ đã thuộc assertion invalid-command tổng quát.
- `ap_wroc0_continuation_ignores_resp_ready`: hai assertion continuation riêng cho SDR read và SDR write đã kiểm tra đầy đủ việc pop command, không ghi RESP và không phát STOP; cover riêng vẫn giữ scenario RESP-not-ready.

**Removed covers**:

- `cp_toc0_accept_then_rstart_then_toc1_stop_read`.
- `cp_toc0_accept_then_rstart_then_toc1_stop`.
- `cp_toc0_bcast_header_once_write`.

Ba composite cover trên được bỏ vì continuation acceptance, repeated START, final STOP và broadcast-header-once đã có cover độc lập. Giữ composite sẽ đếm lại cùng hành vi nhưng không phân biệt thêm một loại bug mới.

**Added or adjusted checks**:

- Thêm `ap_sdr_write_no_cmd_pop_except_continuation` để giới hạn CMD pop của đường SDR write vào đúng thời điểm continuation.
- Thêm `ap_i2c_never_enters_broadcast_header` để chứng minh I2C không đi qua I3C broadcast-header path.
- Bỏ điều kiện `!entdaa_stop_req_q` khỏi common-stop AP/CP của reserved DAA vì điều kiện này loại mất cycle hợp lệ khi stop request đã được latch.
- Viết lại antecedent WROC=1 bằng state, descriptor, phase, remaining length và
  bus-idle trực tiếp để tránh vấn đề scoring UCIS của Xcelium 18.03 khi OR hai
  helper function read/write. Bản khai triển ban đầu đã vô tình mở rộng read
  antecedent; sau review, cả AP và matching CP được khôi phục ba read-only guard
  `!short_read_q`, `!rx_overflow_q` và `rx_byte_idx_q == 0` bằng biểu thức phụ
  thuộc state. Vì vậy phiên bản cuối giữ semantics của helper cũ mà không dùng
  OR giữa hai helper function.

### 22:39 - Targeted verification và full regression

Chạy các sequence bị ảnh hưởng trước, sau đó xóa coverage database cũ và chạy regression coverage seed 1 ngoài sandbox theo yêu cầu của repository.

**Commands**:

```sh
make sim SEQ=<changed_sequence> SEED=1
make regression COV=1 SEED=1
make sva_cov_report
git diff --check
```

**Output**:

- Mọi targeted simulation kết thúc với `UVM_ERROR=0`, `UVM_FATAL=0`.
- Full regression tạo 81 UCD database.
- SVA extractor phân tích đủ 81 test.

### 22:59 - Xuất report và kiểm tra cuối

Tái tạo `src/verification/sva_coverage_report.txt`, kiểm tra duplicate AP/CP label và whitespace errors.

**Output**:

- Không có duplicate AP/CP label.
- `git diff --check` sạch.
- SVA closure đạt 100%.

### 23:42 - Sửa caveat WROC1 và làm rõ phạm vi worktree

Review sau triển khai phát hiện bản khai triển WROC1 đầu tiên bỏ ba guard riêng
của read path. Khôi phục các guard cho cả AP và matching CP bằng biểu thức ternary
phụ thuộc `state_q`; đồng thời sửa báo cáo để không mô tả bản trung gian là một
pure refactor và liệt kê rõ các dirty file ngoài phạm vi.

**Verification**:

- `make coverage SEQ=i3c_wroc_policy_vseq SEED=1`: `UVM_ERROR=0`, `UVM_FATAL=0`.
- `ap_wroc1_continuation_waits_for_resp_ready`: PASS, pass count 1.
- `cp_wroc1_continuation_waits_for_resp_ready`: HIT, hit count 1.
- `make sva_cov_report`: 386/386 assertions PASS và 578/578 in-scope covers HIT.

---

## Inputs/Outputs

### Inputs

**Files Read**:

- `src/verification/uvm_i3c/i3c_core/sva/*.sv` - So sánh toàn bộ AP/CP label và ownership.
- `src/verification/sva_coverage_report.txt` - Xác định trạng thái PASS/HIT/MISS và số test kích hoạt.
- `src/verification/uvm_i3c/i3c_core/i3c_vseqs/` - Tìm vseq phù hợp để thêm stimulus có mục tiêu.
- `src/verification/Makefile` - Kiểm tra regression membership.
- `docs/test_plan/I3C_Testplan.md` - Đối chiếu verification objective và coverage goal.

**Configuration/Environment**:

- Cadence Xcelium 18.03-s001 với UVM `CDNS-1.2`.
- Regression seed: `1`.
- Simulator targets chạy ngoài sandbox theo repository policy.

### Outputs

**Files Modified trong phạm vi implementation**:

- `src/verification/Makefile` - Thêm reserved-address DAA sequence vào DAA regression.
- `src/verification/uvm_i3c/i3c_core/sva/flow_active_sva.sv` - Xóa property trùng, thêm guard assertions và điều chỉnh DAA/WROC predicates.
- `src/verification/uvm_i3c/i3c_core/i3c_vseqs/csr_vseqs/csr_reset_defaults_vseq.sv` - Reset-qualified unmapped read.
- `src/verification/uvm_i3c/i3c_core/i3c_vseqs/csr_vseqs/csr_queue_status_flags_vseq.sv` - CMD backpressure scenario.
- `src/verification/uvm_i3c/i3c_core/i3c_vseqs/i2c_vseqs/i2c_regular_{read,write}_basic_vseq.sv` - I2C with broadcast-header enable.
- `src/verification/uvm_i3c/i3c_core/i3c_vseqs/sdr_write_vseqs/i3c_write_toc_zero_vseq.sv` - Unsupported continuation and recovery.
- `src/verification/uvm_i3c/i3c_core/i3c_vseqs/resp_vseqs/i3c_read_abort_vseq.sv` - Retained continuation under abort.
- `src/verification/uvm_i3c/i3c_core/i3c_vseqs/resp_vseqs/i3c_wroc_policy_vseq.sv` - RESP-full WROC=1 continuation.
- `docs/test_plan/I3C_Testplan.md` - Đồng bộ coverage ownership và ERR_012 objective.
- `docs/test_plan/test_case_explaination_in_vietnamese.md` - Giải thích WROC/RESP-full bằng tiếng Việt.
- `src/verification/sva_coverage_report.txt` - Report SVA cuối.

**File Created**:

- `reports/i3c-sva-ap-cp-redundancy/task_1_completed.md` - Báo cáo phiên làm việc này.

**Artifacts Generated**:

- 81 UCD database dưới `src/verification/cov_work/`; đây là simulator artifacts cục bộ, không dành để commit.

**Out of Scope**:

- Không thay đổi file dưới `src/rtl/`.
- Worktree có thay đổi chưa commit trong `csr_registers_sva.sv`,
  `i3c_controller_top_sva.sv`, `sync_fifo_sva.sv`, `tb_pad_model_sva.sv`,
  `i3c_daa_dat_boundary_vseq.sv`, `i3c_reset_during_idle_vseq.sv` cùng các
  coverage/scoreboard/documentation khác và untracked stress files. Báo cáo này
  không nhận các thay đổi đó là deliverable của phần AP/CP redundancy.
- Trước khi commit phải stage theo file/hunk đã duyệt và kiểm tra
  `git diff --cached`; không dùng `git add -A`.

---

## Error Handling

### Warning 1: Xcelium DPI Export Warning

**Occurred at**: Compile và simulation.

**Message**:

```text
xmsim: *E,IMPDLL: Unable to load the implicit shared object.
OSDLERROR: .../_sv_export.so: cannot open shared object file
```

**Context**: Xcelium 18.03 không load được optional DPI export object trên host runtime hiện tại.

**Resolution**: Xác nhận elaboration/simulation vẫn hoàn tất và UVM summaries đều có zero error/fatal. Warning này không ảnh hưởng kết quả verification và được ghi lại như limitation môi trường.

### Error 1: WROC=1 cover không được UCIS chấm khi dùng OR helper functions

**Occurred at**: Targeted WROC coverage investigation.

**Root Cause**: Antecedent `(sdr_write_done_ready() || sdr_read_done_ready())` mô tả đúng logic nhưng Xcelium 18.03 không ghi nhận ổn định scenario này trong coverage database.

**Resolution Steps**:

1. Khai triển điều kiện chung bằng FSM state, transfer type, phase, remaining
   length và bus-idle.
2. Review phát hiện bản đầu đã bỏ `!short_read_q`, `!rx_overflow_q` và
   `rx_byte_idx_q == 0` của read helper.
3. Khôi phục ba guard cho cả AP và CP bằng state-dependent ternary, không dùng OR
   giữa hai helper function.
4. Chạy lại targeted WROC coverage và xác nhận assertion pass cùng cover hit.

**Prevention**: Với toolchain này, ưu tiên predicate trực tiếp cho closure-critical AP/CP thay vì OR giữa helper functions.

### Error 2: Targeted rerun chưa có Xcelium trên PATH

**Occurred at**: Lần chạy targeted coverage đầu tiên sau caveat review.

**Error Message**:

```text
make[1]: xrun: No such file or directory
make[1]: *** [Makefile:134: compile] Error 127
```

**Root Cause**: Shell của command đầu chưa source Xcelium environment script.

**Resolution**: Source
`/home/minhuy/EDA/cadence/xcelium/XCELIUM1803.sh` rồi chạy lại cùng target;
compile và simulation hoàn tất sạch.

### Edge Cases Discovered

**Abort trong TOC=0 khi continuation đã queue**:

- **Impact**: Chỉ quan sát RSTART không đủ để chứng minh continuation không bị consume vì abort takeover cũng có thể dùng RSTART.
- **Handling**: Kiểm tra trực tiếp CMD FIFO depth bằng 1 sau abort, rồi cleanup bằng software reset khi abort vẫn chặn idle acceptance.

**WROC=1 với RESP FIFO full**:

- **Impact**: Continuation không được pop cho tới khi response đầu tiên có thể được ghi; nếu chỉ kiểm tra response cuối thì có thể bỏ sót pop sớm.
- **Handling**: Giữ RESP FIFO full, kiểm tra `cmd_queue_rready_o=0`, giải phóng slot, sau đó xác nhận RSTART và cả hai response đúng TID/status.

---

## Final Status

### Success Confirmation

✅ **All objectives met**:

- ✅ Đã xác định và xóa 4 assertion cùng 3 cover bị trùng trách nhiệm.
- ✅ Các hành vi được xóa vẫn có property tổng quát hoặc focused property mạnh tương đương sở hữu.
- ✅ Directed stimulus kích hoạt các scenario CSR, I2C, TOC=0, abort, WROC và DAA cần thiết.
- ✅ Không có duplicate AP/CP label và `git diff --check` sạch.
- ✅ Full SVA closure đạt 100% mà không sửa RTL.

### Deliverables Summary

**SVA Results**:

- Tests analysed: 81.
- Assertions: 386 PASS, 0 VACUOUS, 0 FAIL, 0 MISS.
- In-scope covers: 578 HIT, 0 MISS.
- Diagnostic waiver: `cp_reset_readback_unmapped_020`; raw read của một unmapped address cụ thể không phải feature F1-F10 closure goal.
- Closure: 100.0%.

**Verification**:

- Targeted simulations: tất cả sạch, `UVM_ERROR=0`, `UVM_FATAL=0`.
- Full `make regression COV=1 SEED=1`: thành công, 81 UCD database.
- `make sva_cov_report`: thành công.
- AP/CP duplicate-label audit: không phát hiện duplicate.
- `git diff --check`: pass.

### Known Limitations

- Xcelium 18.03 vẫn phát warning `_sv_export.so`/`IMPDLL` của môi trường host.
- `regression_result.txt` là artifact/stale summary có sẵn và liệt kê 80 legacy tests; sign-off SVA dùng trực tiếp 81 UCD database và extractor report.
- Coverage databases và logs là local generated artifacts, không dành để commit.
- Worktree đã dirty trước và có thay đổi ngoài phạm vi; cần stage theo danh sách file mong muốn thay vì `git add -A`.

### Follow-Up Items

- [ ] Review danh sách file intended trước khi commit.
- [ ] Nếu cần commit, stage có chọn lọc source/docs/report và loại simulator artifacts.

### Related Resources

- SVA source: `src/verification/uvm_i3c/i3c_core/sva/flow_active_sva.sv`
- SVA report: `src/verification/sva_coverage_report.txt`
- Test plan: `docs/test_plan/I3C_Testplan.md`
- Vietnamese explanation: `docs/test_plan/test_case_explaination_in_vietnamese.md`
- Broader feature-coverage report: `reports/i3c-feature-coverage-closure/task_1_completed.md`

---

**Report Generated**: 2026-07-15 23:43:40 +07  
**Author**: Codex  
**Review Status**: Pending
