# Tái kiểm toán citation và bibliography — 28/07/2026

## 1. Kết luận

Hệ thống citation của report hiện **đạt** trong phạm vi kiểm tra: mọi claim ngoại sinh có citation trong
include graph chính thức đều được nguồn tương ứng hỗ trợ; các claim kỹ thuật dễ kiểm tra nhầm đã có
section/table/figure locator; không còn citation sai nguồn, không xác minh được hoặc chỉ hỗ trợ một phần.

Tái kiểm này thay thế kết luận về trạng thái hiện tại, nhưng không ghi đè audit lịch sử
`full_citation_bibliography_audit_vi.md` ngày 22/07/2026.

## 2. Phạm vi và phương pháp

- Include graph: phần đầu, Chương 1--6, Phụ lục A--B và mọi hình/bảng được các file này đưa vào PDF.
- Không tính `appendixCoverage.tex`, `appendixE.tex`, figure standalone/draft và file đang bị comment.
- Bibliography nguồn duy nhất: `docs/report/latex/References/references.bib`.
- Tổng cộng: **53 lệnh citation**, **67 lượt citation key**, **10 key duy nhất**, **10 bibliography entry**.
- Đối chiếu trực tiếp nội dung bảy PDF cục bộ: MIPI I3C Basic v1.1.1 + Errata 01, MIPI TCRI v1.0,
  MIPI HCI v1.2, NXP UM10204 Rev. 7.0, UVM 1.2 User's Guide, UVM 1.2 Class Reference và
  IEEE Std 1800-2023.
- Đối chiếu source code bằng archive CHIPS Alliance cục bộ và
  `src/verification/uvm_i3c/dv_inc/dv_macros.svh`; URL bibliography vẫn trỏ repository/file chính thức
  theo yêu cầu, không pin commit.
- Trang Cadence chính thức chỉ được dùng để định danh Xcelium và khả năng hỗ trợ
  SystemVerilog/UVM; việc khóa luận thực sự chạy Xcelium được xem là evidence nội bộ của Chương 5.

## 3. Ma trận claim–nguồn

| Phạm vi report | Claim được kiểm tra | Nguồn và locator chính | Kết quả |
|---|---|---|---|
| Chương 1, dòng 10--16 | Giới hạn I2C Fast-mode, static addressing, DAA, SDR và 12,5 MHz | NXP Secs. 3.1, 5.1; MIPI Secs. 2, 5.1.2--5.1.4 | Supported |
| Chương 1, dòng 20--25 | Nguồn gốc i3c-core/Caliptra và công cụ SystemVerilog, UVM, Xcelium | CHIPS README + `doc/source/introduction.md`; IEEE 1800-2023; UVM UG; Cadence | Supported; claim sử dụng công cụ là evidence nội bộ |
| Chương 2, dòng 12--28 | Bus I2C, arbitration, START/STOP/Sr, bus condition | NXP Secs. 3.1.1, 3.1.4--3.1.8; MIPI Secs. 5.1.2--5.1.3 | Supported |
| Chương 2, dòng 94--132 | Open-Drain/Push-Pull, ACK handoff và read takeover | MIPI Secs. 5.1.2.2--5.1.2.3.4 | Supported |
| Chương 2, dòng 139--211 | I3C SDR Private Write/Read và frame minh họa | MIPI Annex A.2 | Supported |
| Chương 2, dòng 218--270 | DAA/ENTDAA, PID/BCR/DCR, arbitration và dynamic address | MIPI Secs. 5.1.4.2, 5.1.9.3.4; Fig. 37 | Supported |
| Chương 2, dòng 274--341 | RSTDAA/SETDASA/SETNEWDA, CCC, ENEC/DISEC | MIPI Secs. 5.1.9.1--5.1.9.3; Table 16; Figs. 32--33 | Supported |
| Chương 2, dòng 365--410 | So sánh I3C/I2C và các giá trị timing | MIPI Tables 86--87; NXP Table 11 | Supported |
| Chương 3, dòng 55--65 | Nguồn tham khảo module/descriptor và PIO queues | CHIPS `controller_overview.md`; HCI Secs. 6.5, 7.5 | Supported |
| Chương 3, dòng 169--238 | Luồng giao dịch và DAA Processor | MIPI Annex C, Figs. 168 và 170; Secs. 5.1.4.2, 5.1.9.3.4 | Supported, hình đã attribution |
| Chương 3, dòng 294--303 | Error status của Response Descriptor | TCRI Sec. 6.4.1, Table 1 | Supported |
| Chương 4, dòng 33--55 | Directed/constrained-random stimulus, scoreboard, SVA, functional coverage | UVM UG Secs. 3.10, 4.6, 4.9, 4.10, 6.5.2.4; IEEE Clause 16 | Supported |
| Chương 4, dòng 63--81 | Configuration Database, analysis port và macro OpenTitan | UVM Class Ref Sec. 10.3, Chap. 16; OpenTitan `dv_macros.svh` | Supported |
| Chương 4, dòng 198--245 | Coverage observer model và `uvm_subscriber` | UVM UG Sec. 4.10; UVM Class Ref Sec. 17.10 | Supported |
| Chương 4, dòng 288--294 | Nguồn gốc I3C Agent | CHIPS `verification/uvm_i3c/dv_i3c` và diff với source local | Supported |
| Chương 5, dòng 468--472 | Phạm vi công bố của CHIPS i3c-core | CHIPS README và `doc/source/dv.md` | Supported |
| Phụ lục A, dòng 4--7 | Register/queue/DAT phỏng theo HCI và CHIPS | HCI Secs. 7.3--7.5; CHIPS `src/rdl`, `controller_overview.md` | Supported |
| Phụ lục B, dòng 4--68 | Response, Immediate, Regular và Address Assignment descriptors | TCRI Secs. 7.1.2--7.1.3, 7.2.2--7.2.3 | Supported |

Các yêu cầu F1--F10, kiến trúc RTL/UVM riêng của khóa luận, waveform, regression, coverage và kết luận
không cần citation ngoài vì đó là specification nội bộ hoặc kết quả của chính dự án. Chúng chỉ cần khớp
source/artifact trong repo; không dùng standard hoặc trang sản phẩm để thay thế evidence nội bộ.

## 4. Hiệu chỉnh đã áp dụng

- Thêm section/table/figure locator cho các claim protocol, methodology và descriptor.
- Thêm attribution “tác giả vẽ theo” hoặc “được rút gọn theo” cho tám hình dựa trên MIPI/NXP.
- Tách citation IEEE/UVM/Cadence trong Chương 1 để mỗi nguồn chỉ bao phủ đúng đối tượng.
- Sửa locator timing I2C từ Table 10 thành **Table 11** sau khi đọc trực tiếp UM10204.
- Làm rõ file OpenTitan và thư mục agent CHIPS được tái sử dụng.
- Chuẩn hóa bibliography cho IEEE 1800-2023, ngày truy cập và URL repository/source chính thức.
- Giữ nguyên citation style BibLaTeX numeric, `sorting=nty`, `backend=bibtex`.

## 5. Kiểm chứng build

Build cô lập thành công bằng:

```text
xelatex → bibtex → makeglossaries → xelatex → xelatex
```

- PDF: **72 trang**, 3.27 MB.
- BibTeX: `warning$ -- 0`.
- Không có undefined citation, undefined reference, missing bibliography entry hoặc empty bibliography.
- PDF hiển thị đúng IEEE Std 1800-2023, DOI/ISBN, CHIPS repository và OpenTitan source file.
- Các warning còn lại là warning có sẵn ngoài phạm vi citation: BibLaTeX fallback backend, font
  substitution, xcolor và một PDF-string warning.

## 6. Trạng thái cuối

| Tiêu chí | Trạng thái |
|---|---|
| Citation key resolve đúng | PASS |
| Claim có citation được nguồn hỗ trợ | PASS |
| Claim kỹ thuật quan trọng có locator | PASS |
| Hình dựa trên standard có attribution | PASS |
| Bibliography metadata và IEEE 1800-2023 | PASS |
| Nguồn sai/không xác minh được | 0 |
| Finding Critical/Major còn mở | 0 |

