# Audit delta so với `full_citation_bibliography_audit_vi.md`

## Phạm vi đã đổi

Audit gốc chụp commit `c06739b...`; phạm vi hiện hành ở HEAD `6b87234...` đã thay
`Appendix/appendixC.tex` bằng `Appendix/appendixCoverage.tex`. Vì thay đổi này đã nằm
trong HEAD, đợt sửa lấy `appendixCoverage` làm appendix active và ghi `appendixC`
cùng ba PDF FSM của nó là asset mồ côi. Không tự khôi phục hoặc xóa các file mồ côi.

Các locator dòng trong audit cũ chỉ là locator lịch sử. Trước mỗi batch phải tìm lại
claim bằng nội dung/macro/label và kiểm hash file, không sửa theo số dòng cũ.

## Kiểm tra `appendixCoverage`

Đã đối chiếu với cả năm nguồn hiện thực liên quan:

- `src/verification/uvm_i3c/dv_reg/reg_coverage.sv`
- `src/verification/uvm_i3c/dv_i3c/i3c_coverage.sv`
- `src/verification/uvm_i3c/i3c_core/i3c_correlated_coverage.sv`
- `src/verification/uvm_i3c/i3c_core/i3c_correlated_item.sv`
- `src/verification/uvm_i3c/i3c_core/i3c_scoreboard_cov.svh`

Kết quả cơ học: 30 tên `covergroup` trong phụ lục khớp đúng 30 tên khai báo trong
ba coverage class; không có tên thiếu hoặc dư. Các mô tả nhóm phù hợp với coverpoint,
cross, điều kiện `iff` và hàm phân loại tương ứng. Đây là bằng chứng nội bộ, không tạo
nhu cầu citation ngoài mới.

## Finding mới

### F63 — Major — hai phương án nháp coverage cùng nằm trong build

- `chapters/04_verification.tex` chứa khối `[NHÁP — PHƯƠNG ÁN A]`.
- `Appendix/appendixCoverage.tex` chứa `[NHÁP — PHƯƠNG ÁN B]`.
- Cả hai file đều thuộc include graph, nên PDF release hiện có đồng thời nội dung lựa
  chọn biên tập và bảng/chú giải trùng mục đích.

Trạng thái: **BLOCKED quyết định tác giả** chọn A hoặc B. Không sửa trong đợt này vì cả
hai file đang có hunk chưa commit của người dùng. F63 độc lập với F27/F36/F37 và không
làm thay đổi tổng 62 finding lịch sử; phạm vi hiện hành là F01–F63.

## Kết luận gate Phase 0

Phase 0 đủ để mở các batch không đụng hai file đang được người dùng sửa và không phụ
thuộc quyết định provenance/license/baseline. Các batch liên quan coverage Ch4 tiếp tục
bị gate bởi F63 và gate nguồn IEEE/UVM metadata-only.
