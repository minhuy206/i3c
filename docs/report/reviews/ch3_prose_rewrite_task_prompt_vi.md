# Đặc tả nhiệm vụ — Đợt viết lại Chương 3 (văn xuôi thiết kế + FSM mức giao thức)

> Prompt tự chứa cho đợt chỉnh sửa Chương 3 của khóa luận I3C. Dán trực tiếp vào một
> phiên làm việc mới để tái lập bối cảnh, quyết định đã chốt và ràng buộc kiểm chứng.

---

## 1. Bối cảnh

- Khóa luận Thạc sĩ (HCMUS, Khoa Điện tử – Viễn thông) về **MIPI I3C Basic v1.1.1 Master
  Controller** (RTL SystemVerilog + testbench UVM). Phạm vi: SDR mode (12.5 MHz SCL),
  I2C FM (400 kHz), ENTDAA. Ngoài phạm vi: IBI, Hot-Join, HDR, multi-master, target mode.
- Báo cáo LaTeX: lớp `extreport`, biên dịch bằng **XeLaTeX** (sinh `report.xdv`/`report.pdf`),
  `hyperref[unicode]`, `cleveref[nameinlink]`, `biblatex/biber`, `glossaries`; các chương nạp
  bằng `\include` (label nằm trong `.aux` của từng tệp con).
- Thư mục làm việc: `docs/report/latex/`. Tệp chương: `chapters/03_architecture_rtl.tex`.
- **Báo cáo tham khảo phong cách:** `docs/report/ref_report.pdf` (khóa luận L2-cache/MESI).
  Đặc trưng của nó — và là chuẩn phong cách cần noi theo:
  - Sơ đồ khối đặt tên đơn vị **theo chức năng chung** (Buffer, FSM, Lookup Unit,
    Error Detector), **không dùng tên module RTL**.
  - Mỗi bộ xử lý được vẽ bằng **một máy trạng thái bong bóng duy nhất**, trạng thái đặt tên
    theo chức năng, kèm một đoạn gạch đầu dòng ngắn mô tả luồng.
  - **Không** liệt kê enum trạng thái, **không** nói về bộ đếm vi mô ở phần chữ.
- **Tham chiếu mức trừu tượng đúng của I3C spec:** MIPI I3C Basic v1.1.1 **Hình 168**
  (I3C Primary Controller FSM) và **Hình 170** (Dynamic Address Assignment FSM).

## 2. Mục tiêu của đợt

Biến Chương 3 từ một bản "đi qua cây mã nguồn" (trích dẫn dày đặc tên module RTL qua macro
`\FlowActive{}`, `\SclGenerator{}`, `\BusTx{}`… và liệt kê 14 trạng thái enum của `flow_active`)
thành một **bản mô tả *thiết kế* bằng văn xuôi chức năng ở mức giao thức**, giống ref report:

1. **Bỏ toàn bộ tên module RTL khỏi phần chữ**, thay bằng mô tả chức năng tiếng Việt nhất quán.
2. **Không đi sâu từng khối** — chỉ nói về thiết kế: phân lớp, luồng giao dịch, handshake,
   định thời, descriptor, xử lý lỗi + thứ tự ưu tiên, hành vi ENTDAA, phân xử/handoff SDA.
3. **Bỏ liệt kê trạng thái RTL** trong chương; thay hai lưu đồ chi tiết bằng **hai FSM mức
   giao thức** (điều khiển chính kiểu Hình 168 + ENTDAA kiểu Hình 170).
4. Mọi `\cref` trong và ngoài chương vẫn biên dịch.

## 3. Quyết định đã chốt (đừng hỏi lại)

1. Trình bày bằng **2 sơ đồ FSM mức giao thức**: một FSM điều khiển chính (kiểu Hình 168) và
   một FSM ENTDAA (kiểu Hình 170); trạng thái đặt tên theo chức năng.
2. **Dời bảng 14 trạng thái `flow_active`** từ Chương 3 xuống **Phụ lục C** (cạnh các bảng FSM
   RTL khác đã có sẵn ở đó); phụ lục giữ nguyên tên enum RTL làm tham chiếu.
3. Việc bỏ tên module + viết lại văn xuôi **chỉ áp dụng cho Chương 3**. Phụ lục vẫn giữ định
   danh RTL. Nới quy ước "dùng macro module" chỉ cho riêng chương này.
4. **Hai hình FSM để dạng placeholder** (khung `\fbox` + chú thích "sẽ bổ sung sau"), giữ nguyên
   `\caption` và `\label`. Người dùng sẽ tự vẽ hình sau — **không tự vẽ TikZ trong đợt này**.

## 4. Quy ước dịch tên module → chức năng (dùng trong phần chữ Chương 3)

| Macro/định danh RTL (bỏ) | Cụm chức năng tiếng Việt (thay) |
|---|---|
| `\FlowActive{}` | khối điều khiển trung tâm / máy trạng thái điều khiển chính |
| `\ControllerActive{}` | lõi xử lý giao thức |
| `\SclGenerator{}` | bộ tạo định thời SCL |
| `\BusTxFlow{}` / `\BusTx{}` / `\BusRxFlow{}` | đường truyền dữ liệu / đường nhận dữ liệu (mô tả gộp) |
| `\EntdaaController{}` / `\EntdaaFsm{}` | khối gán địa chỉ động / trình tự cấp phát cho một Target |
| `\CsrRegisters{}` / `\HciQueues{}` | khối giao diện thanh ghi / hàng đợi FIFO |
| `i3c_phy` | lớp PHY / lớp giao tiếp bus |
| `bus_monitor` | bộ giám sát bus |
| `edge_detector` / `stable_high_detector` | mô tả chức năng (lọc glitch, xác nhận cạnh hợp lệ) |

**Vẫn giữ nguyên (là dữ kiện thiết kế, không phải tên module):**
- Trường/tín hiệu giao thức: `toc`, `wroc`, `RnW`, `BUS_ENABLE`, `ABORT`, `IBA_INCLUDE`,
  `HC_CONTROL`; mã lỗi `NotSupported`, `Ovl`, `HcAborted`, `NACK`…
- Macro khái niệm giao thức: `\DynamicAddress{}`, `\OpenDrain{}`, `\PushPull{}`,
  `\RepeatedSTART{}`, `\Target{}`, `\Host{}`, `\Controller{}`, `\iic{}`, `\TBit{}`,
  `\IThreeCBroadcastAddress{}`, `\AddressHeader{}`, `\CommandDescriptor{}`,
  `\ResponseDescriptor{}`, `\CommandFifo{}`, `\TxFifo{}`, `\RxFifo{}`…

## 5. Ràng buộc cross-reference (đã rà bằng grep — không đổi tên label)

Giữ nguyên các `\label` sau vì được tham chiếu **từ ngoài Chương 3**:
- `sec:rtl-csr` ← `Appendix/appendixA.tex`
- `tab:err-status` ← `Appendix/appendixB.tex`, `chapters/04_verification.tex`
- `sec:arch-err` ← `chapters/04_verification.tex`
- `sec:rtl-controller-active` ← `chapters/05_results.tex`
- `app:fsm`, `fig:scl-gen-fsm`, `fig:entdaa-fsm` (định nghĩa ở Phụ lục C) ← Chương 3 trỏ tới.
- `tab:flow-states` ← đã **chuyển định nghĩa xuống Phụ lục C** (giữ nguyên tên label);
  Chương 3 trỏ tới nó qua `\cref{app:fsm}`.

Label nội bộ Chương 3 giữ nguyên để an toàn: `sec:flow-states`, `sec:flow-route`,
`sec:flow-merge`, `sec:flow-end`, `sec:rtl-scl`, `sec:rtl-txrx`, `sec:rtl-entdaa`,
`sec:arch-*`, `sec:rtl-phy`, `sec:rtl-queues`, `sec:rtl-monitor`.

Hình/bảng dữ kiện thiết kế **không được đụng**: `tab:scl-timing-cycles`, `tab:desc-summary`,
`tab:err-status`, `fig:arch-block`, `fig:csr-queue-handshake`.

Hai label hình FSM mới (nội bộ chương): `fig:controller-fsm`, `fig:entdaa-flow`.

## 6. Thay đổi theo tệp

### A. `chapters/03_architecture_rtl.tex` (chính)

Giữ khung 6 mục (3.1 Tổng quan kiến trúc; 3.2 Cấu trúc dữ liệu & giao diện; 3.3 Đường tạo
định thời & tuần tự hóa; 3.4 Khối điều khiển trung tâm; 3.5 Khối gán Dynamic Address (ENTDAA);
3.6 Tích hợp & phân xử tài nguyên bus). Viết lại **phần chữ** theo Mục 4; đổi tiêu đề mục bỏ
macro module (giữ label); bỏ bảng 14 trạng thái; đặt **2 hình FSM ở dạng placeholder**
(`\fbox{\begin{minipage}[c][6cm][c]{0.85\textwidth}…\end{minipage}}` + caption + label).

### B. `Appendix/appendixC.tex` (phụ)

Thêm `\section*{\FlowActive{} — \FlowStateCount{} trạng thái}` chứa **bảng 14 trạng thái
`flow_active`** (ID 0–14, giữ nguyên tên enum RTL) dưới dạng `table` float có
`\caption{…}\label{tab:flow-states}`, cột `C{1.0cm} L{4.0cm} L{7.4cm}`, kèm câu mở đầu trỏ
`\cref{fig:controller-fsm}` và giới thiệu bảng ngay tại phụ lục.

## 7. Việc KHÔNG làm

- Không sửa Phụ lục A/B, Chương 1/2/4/5/6 (phạm vi "chỉ Chương 3").
- Không đụng RTL/UVM source — đây là thay đổi tài liệu.
- Không xóa macro trong `thesisterms.sty`/`myacronyms.sty` (phụ lục vẫn dùng).
- Không tự vẽ nội dung hai hình FSM — để placeholder, người dùng vẽ sau.
