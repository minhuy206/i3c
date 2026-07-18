# Kiểm toán tính nhất quán của toàn bộ báo cáo

## Phạm vi và trạng thái

Tài liệu này ghi trạng thái sau khi xử lý các phát hiện của lần kiểm toán ngày 16/07/2026. Phạm vi gồm phần đầu, Tóm tắt/Abstract, sáu chương, danh mục, tài liệu tham khảo và bốn phụ lục. Nội dung được kiểm tra trên PDF 85 trang biên dịch từ một bản sao tạm bằng đúng chuỗi release `pdflatex → bibtex → makeglossaries → pdflatex → pdflatex`.

RTL/UVM, `regression_result.txt`, `coverage_report.txt`, `sva_coverage_report.txt` và Makefile được dùng làm nguồn đối chiếu. Comment LaTeX và cách tổ chức nội bộ của mã nguồn không được xem là nội dung hiển thị.

## Sai lệch còn lại

| STT | Location | Original text or usage | Issue | Quy ước/bằng chứng | Khuyến nghị |
|---:|---|---|---|---|---|
| 1 | Toàn báo cáo, thiết lập cỡ chữ/font — `report.tex:12–17` | thân bài 13 pt với một số công thức và shape T5 | **[Định dạng] Thấp:** toolchain vẫn thay thế một số font/shape không tồn tại; sau khi thêm `fix-cm`, sai khác cỡ tối đa giảm từ 1,75 pt xuống 1,0 pt. | Build release hoàn tất; nội dung và bố cục vẫn hiển thị đúng. Cảnh báo phụ thuộc bộ font của môi trường TeX. | Chỉ xử lý tiếp nếu môi trường nộp chính thức yêu cầu tuyệt đối không có font warning; khi đó chọn bộ font có đủ math/T5 shape ở 13 pt. |

## Các chỉnh sửa kỹ thuật đã xác minh

- Thống nhất kết quả pass/fail, Functional Coverage và SVA trên cùng một tập gồm 81 test regression.
- Giữ nguyên cách phân loại theo mục tiêu/chức năng của 80 test trong mười nhóm chính; các số lượng 11/14/5/6/8/5/4/9/4/14 là có chủ ý. Test còn lại được liệt kê trong nhóm Coverage closure, nên tổng regression bằng 81.
- Đồng bộ Chương 6 và Phụ lục D với kết quả hiện hành: Functional Coverage closure 222/222, diagnostic 173/173; SVA 386/386 assertion PASS, 578/578 cover property HIT, một cover property được waive ngoài mẫu số.
- Thay ví dụ coverage lỗi thời `cg_abort_response` bằng `cg_abort_termination` và thay toàn bộ trích đoạn report cũ.
- Loại Hình 5.9 placeholder khỏi nội dung và Danh mục hình.
- Dùng đúng `i3c_sequencer` và `reg_sequencer` khi nói tới các lớp cụ thể của dự án.
- Sửa macro độ rộng mục DAT thành `DatEntryWidth`, bổ sung năm 2022 cho MIPI I3C TCRI v1.0 và chuẩn hóa mục OD thành `Open-Drain`.
- Sửa các lỗi tràn lề đã ghi nhận ở Chương 3, Chương 4 và Phụ lục A/B. Build cuối không còn `Overfull \hbox` đáng kể.

## Quy ước biên tập thống nhất

- Văn xuôi chính dùng tiếng Việt và Abstract dùng tiếng Anh, nhưng thuật ngữ chuyên ngành RTL/UVM đã phổ biến được giữ bằng tiếng Anh: `module`, `top-level`, `interface`, `clock`, `reset`, `timing`, `counter`, `synchronizer`, `testbench`, `agent`, `sequencer`, `scoreboard`, `driver`, `monitor`, `sequence`, `coverage`, `regression`, `waveform`, `frame`, `setup` và `hold`.
- Mọi chú thích nằm bên trong hình dùng tiếng Anh. Lưu đồ thuật toán là ngoại lệ: câu hành động và điều kiện có thể dùng tiếng Việt, còn identifier và thuật ngữ chuyên ngành vẫn giữ tiếng Anh.
- Caption hình/bảng vẫn dùng tiếng Việt. Tên giao thức, acronym và identifier giữ đúng dạng chuẩn.
- Tiêu đề chương/mục dùng sentence case; acronym và tên riêng không đổi kiểu viết.
- Tên module, lớp, instance, signal, property, state và file dùng đúng identifier và đặt ở kiểu monospace. Tên loại thành phần UVM có thể dùng dạng tiếng Anh thông thường trong văn xuôi.
- Số thập phân dùng dấu phẩy trong văn xuôi tiếng Việt (`12,5 MHz`) và dấu chấm trong Abstract, log hoặc listing tiếng Anh (`12.5 MHz`, `100.0%`).

## Các khác biệt có chủ ý, không phải lỗi

1. `err` trong báo cáo là tên giao diện/khái niệm tài liệu rút gọn, không phải tuyên bố identifier RTL `err_status`.
2. `I2cDataNack` mô tả phạm vi hành vi được trình bày trong báo cáo; enum RTL rộng hơn là `I2cDataNackOrI3cBusAborted`.
3. Số lượng test theo nhóm trong báo cáo là phân loại theo mục tiêu/chức năng, không ánh xạ một-một với biến nhóm chạy trong Makefile. Negative test chỉ tái lập trong read, write hoặc ENTDAA được tính vào chức năng tương ứng; lỗi có thể tái lập ở mọi luồng, như Address Header, được tính vào Response/error.
4. File nguồn `Appendix/appendixE.tex` được include ở vị trí phụ lục thứ tư nên hiển thị là Phụ lục D. Tên file không quyết định ký hiệu phụ lục.

## Thống kê

- Tổng số dòng sai lệch còn lại: **1**.
- Số lượng theo nhóm chính: **Định dạng 1**.
- Các phát hiện đã xử lý và các khác biệt được xác nhận là có chủ ý không được tính vào tổng trên.

## Kết quả kiểm tra bản in

- Build release tạo PDF 85 trang và hoàn tất không có lỗi.
- Không có citation hoặc cross-reference chưa định nghĩa.
- Không còn placeholder, số liệu closure 80,8%, thống kê SVA 7/13 MISS hoặc trích đoạn report 80-test lỗi thời.
- Không còn `Overfull \hbox` nhìn thấy; cảnh báo font còn lại có sai khác cỡ tối đa 1,0 pt.
- Cảnh báo `Underfull \vbox`, cảnh báo màu của `listings`, BibTeX fallback và format-name deprecated không được tính là sai lệch vì không làm sai nội dung hiển thị.
