# Bản hiệu đính theo văn phong IEEE — Chương 5 và Chương 6

Tài liệu này là bản viết lại bằng tiếng Việt. Các nhãn `\cref`, định danh, số liệu, bảng và hình tương ứng với bản LaTeX hiện hành. Khi tích hợp, giữ nguyên mã TikZ và `label` trong tệp gốc.

# Chương 5. Kết quả và đánh giá

Chương này trình bày điều kiện đo, kết quả hồi quy kiểm chứng, bằng chứng dạng sóng, độ bao phủ, kết quả SVA, quy mô hiện thực và mức đáp ứng các yêu cầu trong \cref{sec:req}.

## 5.1. Điều kiện đo và phương pháp đánh giá

Mọi số liệu được thu trên cùng một phiên bản RTL và môi trường kiểm chứng. Mô phỏng sử dụng Cadence Xcelium và UVM~1.2. Mỗi phép thử thực thi một `Virtual Sequence` với `SEED=1`. Kích thích ngẫu nhiên có ràng buộc vẫn được sử dụng, nhưng seed cố định bảo đảm khả năng tái lập chuỗi kích thích.

Một phép thử được xác định là `PASS` khi mô phỏng hoàn tất mà không có `UVM_ERROR` hoặc `UVM_FATAL`. Độ bao phủ chức năng và SVA được hợp nhất từ toàn bộ 80 phép thử. \Cref{tab:res-baseline} tóm tắt điều kiện đo và quy tắc đếm.

**Bảng: Điều kiện đo và quy tắc đếm**

| Hạng mục | Giá trị hoặc quy tắc |
|---|---|
| Công cụ mô phỏng | Cadence Xcelium, UVM~1.2 |
| Seed | `SEED=1` cho mọi phép thử |
| Bộ phép thử | 80 `Virtual Sequence` (\cref{tab:vseq-cat}), một lớp phép thử |
| Tiêu chí `PASS` | Mô phỏng hoàn tất; `UVM_ERROR=0` và `UVM_FATAL=0` |
| Quy mô RTL | 18 tệp, 5.121 dòng (`src/rtl`) |
| Quy mô môi trường UVM | 136 tệp, 29.017 dòng (`src/verification/uvm_i3c`) |
| Độ bao phủ | Hợp nhất từ 80 phép thử |

Trong 29.017 dòng mã kiểm chứng, thư viện `Virtual Sequence` và các bộ kiểm tra SVA lần lượt chiếm 11.971 và 7.287 dòng. Tổng số dòng mã kiểm chứng bằng khoảng 5,5 lần số dòng RTL. Tỷ lệ này phù hợp với phạm vi tập trung vào kiểm chứng của khóa luận.

## 5.2. Kết quả hồi quy kiểm chứng

Toàn bộ 80 `Virtual Sequence` đạt với `SEED=1`; không có phép kiểm tra SVA nào thất bại. \Cref{tab:res-regression} phân loại kết quả theo mười nhóm kịch bản trong \cref{tab:vseq-cat}. Các phép thử I3C \PrivateWriteRead{} hoạt động ở chế độ I3C SDR. Trích đoạn nhật ký và kết quả chi tiết được trình bày trong \cref{app:regression}.

**Bảng: Kết quả hồi quy theo nhóm kịch bản (`SEED=1`)**

| Nhóm | Số phép thử | `PASS` | Phạm vi chính |
|---|---:|---:|---|
| Bus | 11 | 11 | PHY, START/Sr/STOP, định thời SCL |
| CSR | 14 | 14 | Giá trị mặc định, DAT, staging, reset |
| FIFO | 5 | 5 | Biên đầy/rỗng, thứ tự, wrap |
| I3C \PrivateWrite{} | 5 | 5 | Danh định, độ dài, liên tiếp |
| I3C \PrivateRead{} | 6 | 6 | Danh định, độ dài, kết thúc sớm |
| Immediate Data Transfer | 4 | 4 | DTT, payload trong Descriptor |
| CCC | 5 | 5 | ENEC/DISEC, khung mở đầu ENTDAA |
| DAA | 6 | 6 | Vòng ENTDAA, từ chối, biên DAT |
| Legacy I\textsuperscript{2}C | 3 | 3 | Ghi/đọc ở Fast Mode |
| Phản hồi và lỗi | 21 | 21 | NACK, tràn, hủy giao dịch, reset |
| **Tổng** | **80** | **80** | |

Kết quả `PASS` được xác định từ trạng thái UVM, kết quả đối chiếu của scoreboard và các phép kiểm tra SVA dùng chung. Do đó, logic kiểm tra không được cài đặt riêng trong từng phép thử. Tuy nhiên, kết quả với một seed chỉ chứng minh các hành vi đã được kích hoạt. Mức đầy đủ của kích thích được đánh giá riêng bằng độ bao phủ chức năng trong \cref{sec:res-coverage}.

Ràng buộc độ sâu của `sync_fifo` được kiểm tra bằng một assertion tại thời điểm elaboration. Cấu hình có độ sâu không phải lũy thừa của 2 làm dừng elaboration bằng thông báo fatal xác định trước. Vì vậy, mọi lần biên dịch thành công trong hồi quy cũng xác nhận ràng buộc tham số này.

## 5.3. Bằng chứng dạng sóng

Các giao dịch đại diện được quan sát bằng SimVision từ các lần chạy với `DUMP_WAVES=1`. Dạng sóng được dùng để đối chiếu trực quan chuỗi sự kiện SDA/SCL với mô tả giao thức trong \cref{ch:background-requirements}. Các đặc trưng quan sát gồm START và Address Header ở pha Open Drain, payload SDR ở pha Push-Pull, T-Bit sau mỗi byte và STOP khi bus trở về trạng thái nghỉ.

\Cref{fig:res-wave-write} và \cref{fig:res-wave-read} lần lượt minh họa giao dịch \PrivateWrite{} và \PrivateRead{}. \Cref{fig:res-wave-write} cũng thể hiện quá trình chuyển từ Open Drain sang Push-Pull được mô tả ở mức RTL trong \cref{sec:rtl-controller-active}.

**Chú thích hình đề nghị:**

- Dạng sóng giao dịch I3C \PrivateWrite{}, gồm START, Address Header, chuyển Open Drain–Push-Pull, payload và STOP.
- Dạng sóng giao dịch I3C \PrivateRead{}, gồm START, Address Header, payload và STOP.

Dạng sóng chỉ cung cấp bằng chứng minh họa và hỗ trợ gỡ lỗi; kết quả không phụ thuộc vào kiểm tra trực quan. `i3c_scoreboard` hoặc SVA tự động kiểm tra thứ tự pha, ACK/NACK, T-Bit và payload trong mọi lần chạy, kể cả khi không ghi dạng sóng.

## 5.4. Kết quả độ bao phủ chức năng và SVA

### 5.4.1. Độ bao phủ chức năng

Sau khi hợp nhất 80 phép thử, mô hình ba lớp bao phủ 1.324 trong tổng số 1.639 bin, tương ứng 80,8%. Trong 42 `covergroup`, 19 `covergroup` đạt 100%. \Cref{tab:res-cov} trình bày kết quả theo thành phần được mô tả trong \cref{sec:ver-cov}.

**Bảng: Độ bao phủ chức năng theo thành phần**

| Thành phần | Số bin được bao phủ | Tổng số bin | Tỷ lệ |
|---|---:|---:|---:|
| `reg_coverage` | 622 | 710 | 87,6% |
| `i3c_coverage` | 147 | 169 | 87,0% |
| `i3c_correlated_coverage` | 555 | 760 | 73,0% |
| **Tổng** | **1.324** | **1.639** | **80,8%** |

Tỷ lệ tổng được đánh giá cùng các bin chưa được bao phủ. Phần thiếu tập trung ở các `cross` lớn của lớp tương quan, mặc dù các `coverpoint` thành phần trong cùng `covergroup` đã đạt 100%. Ba trường hợp đại diện được trình bày dưới đây.

| `covergroup` | Tỷ lệ | Phần chưa được bao phủ | Nguyên nhân |
|---|---:|---|---|
| `cg_command_boundary` | 30,1% | `cross` 80 bin giữa lớp lệnh trước, lớp lệnh sau và loại điểm biên mới đạt 15 tổ hợp | Các tổ hợp yêu cầu hai lớp lệnh xác định xuất hiện liên tiếp tại một điểm biên xác định; thư viện hiện tại chưa tạo đủ các chuỗi này. |
| `cg_recovery` | 38,2% | `cross` 60 bin giữa nguồn gián đoạn, lớp lệnh bị gián đoạn và lớp lệnh phục hồi mới đạt 13 tổ hợp | Mỗi tổ hợp cần một kịch bản lỗi–phục hồi riêng. |
| `cg_short_read_boundary` | 55,9% | Thiếu các tổ hợp hiếm của `sre`, `wroc` và vị trí biên đọc ngắn | Thư viện hiện tại chưa kích hoạt đủ các tổ hợp của hai cờ tại các vị trí biên. |

Hai lớp quan sát trực tiếp đạt 87,6% và 87,0%. Phần chưa được bao phủ chủ yếu thuộc các tổ hợp ba chiều của chuỗi lệnh và tình huống lỗi–phục hồi. Việc đóng độ bao phủ cần các kịch bản có chủ đích. Các tổ hợp không khả thi cũng cần được xác định và loại trừ có căn cứ. Hai hạng mục này được đưa vào hướng phát triển trong \cref{ch:conclusion}.

Ảnh chụp giao diện công cụ, nếu cần làm bằng chứng, nên được chuyển sang phụ lục. Bảng số liệu trên cung cấp đủ thông tin cho nội dung chính.

### 5.4.2. Kết quả SVA

Môi trường có 145 thể hiện bộ kiểm tra SVA. Chín bộ kiểm tra được gắn vào các mô-đun đích bằng `bind` và được nhân bản theo số thể hiện mô-đun; bộ kiểm tra pad model được khởi tạo trong môi trường kiểm chứng. Toàn bộ hồi quy ghi nhận 411 assertion và 590 `cover property`.

**Bảng: Kết quả SVA sau khi hợp nhất 80 phép thử**

| Hạng mục | Đạt | Tổng | Tỷ lệ |
|---|---:|---:|---:|
| Assertion đã được kích hoạt và đạt | 404 | 411 | 98,3% |
| Assertion thất bại | 0 | 411 | 0% |
| `Cover property` được kích hoạt | 577 | 590 | 97,8% |

Không có assertion nào thất bại hoặc đạt theo nghĩa rỗng (*vacuous pass*). Bảy assertion và 13 `cover property` chưa được kích hoạt. Mỗi assertion có một `cover property` đối ứng theo quy ước trong \cref{sec:ver-sva}; do đó, các trường hợp chưa kích hoạt không bị phân loại nhầm là đạt.

Các trường hợp chưa kích hoạt thuộc ba nhóm: chuỗi tiếp diễn có `toc=0` nối nhiều Command Descriptor trong một khung bus; backpressure giữ ổn định dữ liệu ghi tại cổng Command Queue khi hàng đợi đầy; và thời điểm chuyển quyền điều khiển SDA trùng một chu kỳ trên pad model. Đây là các khoảng trống kích thích, không phải lỗi thiết kế đã quan sát. Tuy nhiên, các hành vi tương ứng chưa được chứng minh và được ghi nhận trong \cref{ch:conclusion}.

## 5.5. Quy mô hiện thực và so sánh với thiết kế tham chiếu

RTL gồm 18 tệp và 5.121 dòng. \Cref{tab:res-loc} trình bày phân bố theo phân hệ. Phân hệ điều khiển giao thức chiếm khoảng ba phần tư tổng số dòng. `flow_active`, FSM trung tâm trong \cref{sec:rtl-flow-active}, có 1.794 dòng và là khối lớn nhất của phân hệ này.

**Bảng: Quy mô RTL theo phân hệ**

| Phân hệ | Số tệp | Số dòng | Thành phần chính |
|---|---:|---:|---|
| Điều khiển giao thức (`ctrl`) | 12 | 3.997 | `flow_active` (1.794) |
| Mức trên cùng và package | 2 | 460 | `i3c_controller_top` |
| CSR | 1 | 368 | `csr_registers` |
| Hàng đợi (`hci`) | 2 | 241 | `sync_fifo` |
| PHY | 1 | 55 | `i3c_phy` |
| **Tổng** | **18** | **5.121** | |

Quy mô được so sánh với phần RTL của CHIPS Alliance `i3c-core` tại commit `f8ea634` ngày 2026-06-08. Hai thiết kế được đo bằng cùng quy tắc đếm. \Cref{tab:res-compare} trình bày kết quả theo phân hệ.

**Bảng: So sánh quy mô RTL với thiết kế tham chiếu**

| Phân hệ | `i3c-core` | Thiết kế của khóa luận |
|---|---:|---:|
| CSR hoặc tệp thanh ghi | 14.297 | 368 |
| Điều khiển giao thức | 13.842 | 3.997 |
| HCI, hàng đợi và bộ thích nghi bus | 2.674 | 241 |
| Mức trên cùng, package và wrapper | 2.304 | 460 |
| PHY | 119 | 55 |
| Recovery và thư viện primitive | 4.961 | — |
| **Tổng** | **38.197** | **5.121** |

Thiết kế của khóa luận có số dòng bằng 13,4% thiết kế tham chiếu, tương ứng mức giảm 86,6%. Tuy nhiên, hai thiết kế khác nhau về phạm vi chức năng. `i3c-core` hỗ trợ thêm vai trò Target, In-Band Interrupt, cơ chế phục hồi và các bộ thích nghi AXI/AHB. Do đó, phần lớn chênh lệch xuất phát từ phạm vi được giới hạn trong \cref{sec:req-oos}.

Hai quyết định hiện thực cũng làm giảm quy mô: tệp thanh ghi viết thủ công gồm 368 dòng thay cho khối CSR sinh tự động hơn 14.000 dòng; giao diện thanh ghi 32 bit trực tiếp thay cho các bộ thích nghi bus hệ thống. Phép so sánh này chỉ định lượng quy mô mã nguồn của hai phạm vi khác nhau và không biểu thị chất lượng tương đối.

Biểu đồ cột sử dụng cùng số liệu với bảng trên không cần thiết trong nội dung chính.

## 5.6. Đánh giá theo yêu cầu

\Cref{tab:res-req} ánh xạ các yêu cầu F1–F10 trong \cref{tab:req-func} với kết quả hồi quy và độ bao phủ. Mỗi yêu cầu có ít nhất một nhóm phép thử đạt và số liệu độ bao phủ tương ứng. Các phần chưa được bao phủ được phân loại trong \cref{sec:res-coverage}.

**Bảng: Đối chiếu yêu cầu chức năng với bằng chứng kiểm chứng**

| Yêu cầu | Bằng chứng hồi quy | Bằng chứng độ bao phủ |
|---|---|---|
| F1–F2 | 11 phép thử I3C \PrivateWriteRead{} đạt | Tương quan \PrivateTransfer{} đạt 95,2%; T-Bit và kết thúc đọc đạt 100% |
| F3 | 4 phép thử \ImmediateDataTransfer{} đạt | \ImmediateDataTransfer{} đạt 100% |
| F4 | 5 phép thử CCC đạt | Phản hồi CCC đạt 100%; opcode/khung CCC đạt 88,9% |
| F5 | 6 phép thử DAA đạt | Bao phủ phản hồi kết quả DAA và biên DAT; một số tổ hợp vòng lặp chưa được bao phủ |
| F6 | 3 phép thử I\textsuperscript{2}C đạt | ACK I\textsuperscript{2}C đạt 100%; vị trí NACK đạt 80,6% |
| F7 | 14 phép thử CSR và 5 phép thử FIFO đạt | Truy cập thanh ghi đạt 99,5%; định thời CSR đạt 100% |
| F8 | Phản hồi được kiểm tra trong mọi phép thử | `Cross` trạng thái phản hồi và Response Descriptor đạt 100% |
| F9 | 21 phép thử phản hồi/lỗi đạt | Các trường hợp hủy giao dịch và phục hồi danh định được bao phủ; `cross` ba chiều chưa được đóng |
| F10 | Các phép thử định thời CSR và bus đạt | Định thời CSR đạt 100%; `cover property` định thời được kích hoạt |

Các chỉ tiêu P1–P5 được đối chiếu như sau.

| Chỉ tiêu | Bằng chứng | Giới hạn |
|---|---|---|
| P1 | DUT hoạt động với clock chu kỳ 3 ns, tương ứng 333 MHz | Chỉ được xác nhận bằng mô phỏng RTL |
| P2–P3 | Nhóm phép thử định thời bus đo trực tiếp độ rộng pha thấp và cao của SCL | Xác nhận quan hệ định thời theo chu kỳ clock |
| P4 | Kịch bản DAA kiểm tra biên 32 mục của DAT | Không có giới hạn bổ sung trong phạm vi mô phỏng |
| P5 | Mọi truy cập phần mềm sử dụng giao diện dữ liệu thanh ghi 32 bit | Chỉ kiểm tra ở mức giao diện RTL |

Các kết quả trên xác nhận chức năng và quan hệ định thời ở mức mô phỏng RTL. Khóa luận không cung cấp kết quả tổng hợp hoặc khép kín định thời vật lý, phù hợp với phạm vi trong \cref{tab:req-oos}.

Trong phạm vi mô phỏng, thiết kế đáp ứng mười yêu cầu chức năng và năm chỉ tiêu cấu hình. Các hạn chế của bằng chứng được tổng hợp trong \cref{ch:conclusion}.

# Chương 6. Kết luận và hướng phát triển

## 6.1. Tổng kết kết quả

Khóa luận đã thiết kế và kiểm chứng một I3C \ActiveController{} theo MIPI I3C Basic v1.1.1 ở mức RTL có khả năng tổng hợp, trong phạm vi được xác định tại \cref{sec:req}.

Thiết kế gồm 18 mô-đun RTL với 5.121 dòng, được tổ chức theo ba lớp. Lớp giao diện cung cấp thanh ghi 32 bit, CSR, DAT và bốn hàng đợi. Khối \ActiveController{} gồm FSM `flow_active` 13 trạng thái, các bộ tuần tự hóa, bộ tạo SCL và bộ điều khiển ENTDAA. Lớp PHY đồng bộ tín hiệu qua hai flip-flop và điều khiển chuyển đổi Open Drain/Push-Pull.

Thiết kế xử lý toàn bộ luồng từ Command Descriptor đến giao dịch SDA/SCL và Response Descriptor. Phạm vi hỗ trợ gồm I3C \PrivateWriteRead{}, \ImmediateDataTransfer{}, CCC ENEC/DISEC, ENTDAA và Legacy I\textsuperscript{2}C Write/Read Fast Mode. Số dòng RTL bằng khoảng 13,4% thiết kế tham chiếu CHIPS Alliance `i3c-core` theo cùng quy tắc đếm (\cref{sec:res-size}); phép so sánh này không biểu thị sự tương đương về phạm vi chức năng.

Môi trường kiểm chứng UVM~1.2 gồm 29.017 dòng, với Register Agent, I3C Target Agent khả lập trình, Virtual Sequencer, `i3c_scoreboard`, \ReferenceModel{} độc lập, 145 thể hiện bộ kiểm tra SVA và mô hình độ bao phủ chức năng ba lớp. Thư viện gồm 80 `Virtual Sequence` thuộc mười nhóm kịch bản, từ truy cập CSR đến lỗi–phục hồi.

Toàn bộ 80 phép thử đạt với seed cố định và không ghi nhận vi phạm SVA. Độ bao phủ chức năng đạt 80,8%; các bin và thuộc tính chưa được kích hoạt đã được phân loại trong \cref{sec:res-coverage}. Bằng chứng đối chiếu cho F1–F10 và P1–P5 được trình bày trong \cref{sec:res-eval}.

## 6.2. Kiến thức và kỹ năng chuyên môn

Quá trình thực hiện khóa luận phát triển bốn nhóm năng lực chuyên môn:

- **Áp dụng đặc tả công nghiệp:** chuyển các yêu cầu của MIPI I3C Basic v1.1.1 về điều kiện bus, Open Drain/Push-Pull, T-Bit và ENTDAA thành yêu cầu thiết kế có thể kiểm chứng; phân biệt quy định giao thức với quy ước giao diện host.
- **Thiết kế RTL:** phân rã đường điều khiển thành các FSM có ranh giới xác định, thiết kế cơ chế bắt tay và xử lý hủy giao dịch, backpressure, reset giữa giao dịch.
- **Kiểm chứng số:** xây dựng môi trường UVM nhiều agent, \ReferenceModel{} độc lập, assertion có `cover property` đối ứng và quy trình kiểm chứng hướng độ bao phủ.
- **Hạ tầng công cụ:** xây dựng và chạy hồi quy bằng Makefile trên Xcelium, trích xuất cơ sở dữ liệu độ bao phủ qua UCIS, gỡ lỗi bằng SimVision và phân tích thiết kế tham chiếu.

## 6.3. Hạn chế

Các hạn chế về thiết kế và bằng chứng kiểm chứng gồm:

- **Phạm vi giao thức:** các chức năng ngoài phạm vi trong \cref{tab:req-oos} chưa được hiện thực. IP chỉ hỗ trợ một \ActiveController{} trên bus.
- **Độ bao phủ:** mô hình đạt 80,8%. Phần chưa được bao phủ tập trung ở các `cross` ba chiều của chuỗi lệnh và tình huống lỗi–phục hồi. Cần bổ sung kịch bản có chủ đích và xác định các tổ hợp không khả thi.
- **Kích hoạt SVA:** bảy assertion về chuỗi tiếp diễn `toc=0`, backpressure tại Command Queue và chuyển quyền điều khiển pad chưa có kích thích tương ứng. Các phép kiểm tra đã được hiện thực, nhưng các hành vi này chưa được chứng minh.
- **Cấu hình hàng đợi:** môi trường kiểm chứng sử dụng độ sâu 8 để tăng khả năng kích hoạt biên đầy/rỗng. Cấu hình mặc định 64 của RTL chưa được chạy hồi quy riêng.
- **Số lượng Target:** môi trường sử dụng một I3C Target Agent. Tương tác với nhiều Target chỉ được kiểm chứng trong vòng ENTDAA.
- **Bằng chứng hậu tổng hợp:** kết quả hiện tại chỉ dựa trên mô phỏng RTL. Chưa có dữ liệu tổng hợp, khép kín định thời hoặc thử nghiệm FPGA; tần số 333 MHz mới được xác nhận theo chu kỳ clock mô phỏng.

## 6.4. Hướng phát triển

\Cref{tab:concl-roadmap} trình bày lộ trình theo thứ tự ưu tiên. Ba hạng mục đầu củng cố bằng chứng cho phạm vi hiện tại; các hạng mục sau mở rộng chức năng giao thức.

**Bảng: Lộ trình phát triển đề xuất**

| Ưu tiên | Hạng mục | Nội dung |
|---:|---|---|
| 1 | Đóng độ bao phủ và SVA | Bổ sung kịch bản tiếp diễn `toc=0`, backpressure tại Command Queue và chuỗi lỗi–phục hồi ba chiều; xác định các tổ hợp không khả thi. |
| 2 | Mở rộng cấu hình kiểm chứng | Chạy hồi quy với độ sâu hàng đợi 64; hỗ trợ nhiều I3C Target Agent hoạt động đồng thời ngoài ENTDAA. |
| 3 | Tổng hợp và thử nghiệm FPGA | Đánh giá tài nguyên và định thời ở 333 MHz; thử nghiệm trên bo mạch với Target I3C vật lý. |
| 4 | In-Band Interrupt | Bổ sung tiếp nhận và điều phối IBI bằng đường Open Drain và bus monitor hiện có. |
| 5 | Hot-Join | Hỗ trợ Target tham gia bus khi hệ thống đang hoạt động trên cơ sở cơ chế IBI. |
| 6 | HDR | Bổ sung HDR-DDR để tăng băng thông. |
| 7 | Vai trò Target | Bổ sung vai trò Target hoặc Secondary \SecondaryController{}; hạng mục này yêu cầu thay đổi kiến trúc đáng kể. |

Ba ưu tiên đầu tập trung vào độ đầy đủ của bằng chứng kiểm chứng và đánh giá hiện thực. Kiến trúc phân lớp hỗ trợ bố trí các chức năng mở rộng theo ranh giới hiện có: IBI và Hot-Join liên quan chủ yếu đến bus monitor và lớp điều phối; HDR cần một bộ xử lý truyền bổ sung song song với đường SDR. Mức thay đổi đối với FSM trung tâm cần được đánh giá trong từng giai đoạn hiện thực.

Khóa luận đã hiện thực và kiểm chứng một I3C \ActiveController{} trong phạm vi xác định bằng ba lớp bằng chứng: scoreboard, SVA và độ bao phủ chức năng. Quy trình định danh yêu cầu, ánh xạ bằng chứng và đo số liệu theo quy tắc xác định có thể tiếp tục được sử dụng khi mở rộng thiết kế theo lộ trình trên.
