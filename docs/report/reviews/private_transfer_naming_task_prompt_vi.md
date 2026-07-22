# Nhiệm vụ: Chuẩn hóa tên I3C Private Write/Read theo MIPI I3C Basic v1.1.1 (bản đầy đủ, đi đường macro)

## Bối cảnh

Báo cáo LaTeX nằm tại `docs/report/latex/`. Các thuật ngữ bus-level "Private Write/Read/Transfer"
hiện được bọc bằng macro trong `docs/report/latex/thesisterms.sty`:

```latex
\newcommand{\PrivateWrite}{Private Write}
\newcommand{\PrivateRead}{Private Read}
\newcommand{\PrivateWriteRead}{Private Write/Read}
\newcommand{\PrivateTransfer}{Private Transfer}
```

Các giá trị này KHÔNG khớp thuật ngữ chuẩn của MIPI I3C Basic v1.1.1 (đã đối chiếu trực tiếp
`docs/mipi_i3c_spec.pdf`):

- `I3C Private Write Transfer` — spec dùng nguyên văn (vd. Figure 158/159, Appendix A.2).
- `I3C Private Read Transfer` — nguyên văn.
- Tên chung cả hai hướng: `I3C Private Write and Read Transfers` — MỘT cụm chia sẻ tiền tố
  "I3C Private", KHÔNG phải "Private Write" + "Private Read" ghép bằng dấu `/`.
- Danh từ chung số ít ở mức Message: `private Message` (chữ `private` thường, `Message` hoa).

`SDR Mode` là ngữ cảnh hoạt động, KHÔNG phải thành phần trong các tên trên. Khi cần nêu chế độ,
đặt riêng: `... trong SDR Mode`.

KHÔNG tự tạo/dùng các biến thể: `I3C SDR Private Write`, `SDR Private Transfer`, `Private Transfer`,
`Private Write/Read`, `I3C Private Write và Private Read`. KHÔNG dịch/đổi từ bên trong tên riêng
`I3C Private Write and Read Transfers` (giữ nguyên chữ `and`).

Ràng buộc từ quy ước biên tập (memory `thesis-writing-conventions`, rule 12 & 13):
- Proper noun của spec **nên bọc bằng macro trong `thesisterms.sty`**, KHÔNG hardcode rải rác nhiều
  chương. → Vì vậy cách đúng là **định nghĩa lại macro**, không phải chèn chữ thẳng vào từng chương.
- Các macro Private-* chỉ dùng cho ngữ cảnh I3C, KHÔNG dùng cho `\iic{}`.

## Nguyên tắc thực hiện

Đây là điểm khác biệt then chốt so với bản prompt trước (bản trước chỉ sửa tay ~11 chỗ, bỏ sót 13
chỗ, gây bất nhất). Bản này sửa gốc ở macro để **cả 24 instance** của
`\PrivateWrite{}`/`\PrivateRead{}`/`\PrivateWriteRead{}` tự đổi đồng bộ, rồi chỉ xử lý tay các
trường hợp macro không gánh được.

Tổng occurrence (đã kiểm bằng grep toàn cây `.tex`): `\PrivateWriteRead{}`=8, `\PrivateWrite{}`=9,
`\PrivateRead{}`=7, `\PrivateTransfer{}`=5. Không có occurrence nào ngoài `chapters/` và
`Appendix/tomtat.tex`.

---

## Bước 1 — Định nghĩa lại macro trong `thesisterms.sty`

Sửa 3 dòng, XÓA 1 dòng:

```latex
% CŨ:
\newcommand{\PrivateWrite}{Private Write}
\newcommand{\PrivateRead}{Private Read}
\newcommand{\PrivateWriteRead}{Private Write/Read}
\newcommand{\PrivateTransfer}{Private Transfer}

% MỚI:
\newcommand{\PrivateWrite}{Private Write Transfer}
\newcommand{\PrivateRead}{Private Read Transfer}
\newcommand{\PrivateWriteRead}{Private Write and Read Transfers}
% (xóa hẳn dòng \PrivateTransfer sau khi hoàn tất Bước 2)
```

Sau bước này, tất cả `I3C \PrivateWrite{}` render thành `I3C Private Write Transfer`,
`I3C \PrivateRead{}` → `I3C Private Read Transfer`, `I3C \PrivateWriteRead{}` →
`I3C Private Write and Read Transfers` — đồng bộ, không cần đụng tay 24 chỗ đó.

---

## Bước 2 — Thay 5 chỗ dùng `\PrivateTransfer{}` (macro này không redefine đồng loạt được, vì 5 chỗ cần 3 cách diễn đạt khác nhau)

### 2.1 `chapters/01_introduction.tex` (câu phạm vi)

Đổi: `hỗ trợ SDR \PrivateTransfer{}`
Thành: `hỗ trợ I3C Private Write and Read Transfers trong SDR Mode`
Giữ nguyên phần còn lại của câu (`, các CCC được chọn, ENTDAA và hỗ trợ tương thích \iic{} Fast Mode`).

### 2.2 `chapters/02_background_requirements.tex` (đoạn mở đầu mục frame)

Đổi: `Một I3C \PrivateTransfer{} trong I3C SDR Mode có cấu trúc tuần tự gồm:`
Thành: `Một private Message trong SDR Mode có cấu trúc tuần tự gồm:`

### 2.3 `chapters/05_results.tex` (bảng đối chiếu yêu cầu, hàng F1--F2)

Đổi: `\PrivateTransfer{} correlation`
Thành: `correlation của I3C Private Write and Read Transfers`

### 2.4 `Appendix/tomtat.tex` — phần tiếng Việt

Đổi: `các luồng truyền SDR \PrivateTransfer{} (ghi, đọc)`
Thành: `I3C Private Write and Read Transfers trong SDR Mode`
Kết quả câu: `... bộ điều khiển thực hiện đúng I3C Private Write and Read Transfers trong SDR Mode,
\ImmediateDataTransfer{}, CCC, ENTDAA và truy cập thanh ghi, ...` (chỉnh tối thiểu, giữ phần còn lại).

### 2.5 `Appendix/tomtat.tex` — phần tiếng Anh

Đổi: `the SDR \PrivateTransfer{}s (write, read)`
Thành: `the I3C Private Write and Read Transfers in SDR Mode`
(Lưu ý xóa cả chữ `s` thừa của `\PrivateTransfer{}s`.)

Sau khi thay xong cả 5 chỗ, **xóa dòng** `\newcommand{\PrivateTransfer}{Private Transfer}` trong
`thesisterms.sty`. Kiểm tra `grep -rn '\\PrivateTransfer' docs/report/latex` phải trả về 0 kết quả.

---

## Bước 3 — Sửa tay `chapters/01_introduction.tex` dòng itemize (nếu để nguyên `SDR \PrivateWrite{}` thì macro sẽ ra "SDR Private Write Transfer" — chèn "SDR" cạnh tên, KHÔNG phải cách spec dùng)

Trong câu: `Triển khai các luồng SDR \PrivateWrite{}, SDR \PrivateRead{}, \ImmediateDataTransfer{}, một số CCC được lựa chọn, ...`

Đổi cụm: `các luồng SDR \PrivateWrite{}, SDR \PrivateRead{}`
Thành: `các luồng I3C \PrivateWriteRead{} trong SDR Mode`

Render ra: `các luồng I3C Private Write and Read Transfers trong SDR Mode, Immediate Data Transfer,
một số CCC...`.

Lý do:
- Dùng tên chung nguyên văn spec `I3C Private Write and Read Transfers` (qua macro gộp
  `\PrivateWriteRead{}`), KHÔNG thêm/bớt từ nào trong tên riêng.
- "SDR" KHÔNG đặt cạnh/bên trong tên; đặt riêng thành mệnh đề ngữ cảnh `trong SDR Mode` — đúng cách
  spec làm (*"...in SDR Mode"*), và trùng dạng chuẩn mà quy tắc thuật ngữ đã nêu.
- Tránh lặp "I3C ... và I3C ..."; nhất quán với cách tên chung được dùng ở ch03/04/05/06.

Không đụng phần còn lại của câu (`\ImmediateDataTransfer{}, một số CCC được lựa chọn, \gls{entdaa} và
giao dịch với \Target{} \iic{} Fast Mode`).

---

## Bước 4 — Bỏ "I3C" thừa ở "trong I3C SDR Mode" tại các chỗ tên riêng đứng ngay trước (tránh "I3C ... trong I3C SDR")

Chỉ áp dụng ở những chỗ macro Private-* (đã render kèm "I3C") đứng NGAY TRƯỚC "trong I3C SDR Mode".
KHÔNG đụng "I3C SDR Mode" ở các chỗ khác (đó là thuật ngữ hợp lệ, dùng nhất quán toàn tài liệu).

- `chapters/02_background_requirements.tex` tiêu đề mục:
  `\subsection{I3C \PrivateWriteRead{} trong I3C SDR Mode}`
  → `\subsection{I3C \PrivateWriteRead{} trong SDR Mode}`  (giữ nguyên `\label{sec:bg-frame}`)

- `chapters/02_background_requirements.tex` chú thích hình:
  `\caption{Định dạng frame I3C \PrivateWriteRead{} trong I3C SDR Mode.}`
  → `\caption{Định dạng frame của I3C \PrivateWriteRead{} trong SDR Mode.}`  (thêm "của", bỏ "I3C" thừa; giữ `\label{fig:sdr-frame}`)

- `chapters/02_background_requirements.tex` bảng yêu cầu F1:
  `Thực hiện I3C \PrivateWrite{} trong I3C SDR Mode`
  → `Thực hiện I3C \PrivateWrite{} trong SDR Mode`

- `chapters/02_background_requirements.tex` bảng yêu cầu F2:
  `Thực hiện I3C \PrivateRead{} trong I3C SDR Mode`
  → `Thực hiện I3C \PrivateRead{} trong SDR Mode`

- `chapters/04_verification.tex` (câu phạm vi kiểm chứng, LƯU Ý cụm này bị NGẮT DÒNG giữa `I3C` và
  `\PrivateWriteRead{}` — dòng 20–21):
  `I3C \PrivateWriteRead{} trong I3C SDR Mode`
  → `I3C \PrivateWriteRead{} trong SDR Mode`

`chapters/05_results.tex` dòng 102 đã là `trong SDR Mode` sẵn — KHÔNG đổi.

---

## Những chỗ KHÔNG cần đụng tay (macro tự lo — liệt kê để review khỏi tưởng bị sót)

- `chapters/03_architecture_rtl.tex` câu nối tiếp giao dịch: `chỉ các giao dịch I3C \PrivateWriteRead{}
  hợp lệ` → tự render `... I3C Private Write and Read Transfers hợp lệ`. Cố ý dùng tên chung ở đây
  (câu nói về việc chỉ giao dịch loại này mới nối bằng `\RepeatedSTART{}`); KHÔNG tách hướng
  Write/Read để tránh lẫn với phân biệt loại Descriptor (Regular vs Immediate).
- `chapters/02` dòng 142: `Với I3C \PrivateWrite{},` và `Với I3C \PrivateRead{},` → tự render
  `Với I3C Private Write Transfer,` / `Với I3C Private Read Transfer,`.
- `chapters/04` dòng 132 (list scoreboard), 175 (prose SVA), 180 (caption listing), 334/335 (bảng vseq).
- `chapters/05` dòng 66/67 (bảng regression), 133/162 (caption waveform), 324/328 (prose waveform),
  420 (`14 test I3C \PrivateWriteRead{} PASS`).
- `chapters/06` dòng 20: `hỗ trợ I3C \PrivateWriteRead{}` → tự render
  `hỗ trợ I3C Private Write and Read Transfers`. (Không cần thêm "trong SDR Mode" vào giữa danh sách
  liệt kê — sẽ gượng; tên riêng đã đủ.)

## Những chỗ TUYỆT ĐỐI không đổi

- Comment trong listing `chapters/04_verification.tex` dòng 181: `// SDR Private Write data phase: ...`
  (nội dung code, giữ nguyên).
- Mã SystemVerilog, tên property `ap_*`/`cp_*`, tên field `\texttt{...}`, nhãn `\label{...}`, số liệu
  test/coverage/PASS, các `\cref`/`\Cref`.

---

## Kiểm tra sau khi sửa

1. `grep -rn '\\PrivateTransfer' docs/report/latex` → 0 kết quả (macro đã xóa, mọi chỗ đã thay).
2. `grep -rnE 'Private Write/Read|Private Write,|Private Read,' docs/report/latex/chapters` → không
   còn dạng cũ thiếu chữ "Transfer" (trừ comment listing ở 04:181).
3. Build lại: `pdflatex → bibtex → makeglossaries → pdflatex ×2`. Không cảnh báo mới.
4. Soát mắt bảng `chapters/05_results.tex` (cột `L{5.0cm}`): `I3C Private Write Transfer` dài hơn
   trước; xác nhận không tràn/xuống dòng xấu, nếu cần thì để LaTeX tự wrap là chấp nhận được.
5. Xác nhận không còn "I3C ... trong I3C SDR Mode" ở 5 chỗ tại Bước 4; các "I3C SDR Mode" khác giữ nguyên.
