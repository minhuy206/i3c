# Đề cương bảo vệ khóa luận — I3C RTL–UVM trong 15 phút

Đầu ra này là đề cương nội dung và speaker notes, chưa phải file PowerPoint/Beamer hoàn chỉnh. Bài gồm 17 slide, nói trong **14 phút 30 giây** và chừa khoảng **30 giây dự phòng**. Mạch kể chuyện:

> Giới hạn I2C → cải tiến và yêu cầu mới của I3C → cơ chế RTL → UVM kích thích, quan sát và kiểm tra → bằng chứng → giới hạn.

Quy ước thiết kế chung: dùng nền sáng vì nhiều PNG có transparency; chữ trên mỗi slide chỉ giữ 3–5 ý ngắn; không đọc tên state, module, class, CSR hay bitfield; mọi kết luận đúng/sai dựa trên checker, không dựa riêng vào waveform.

## Slide 1 — THIẾT KẾ VÀ KIỂM CHỨNG BỘ ĐIỀU KHIỂN I3C

### 1. Tiêu đề

**THIẾT KẾ VÀ KIỂM CHỨNG BỘ ĐIỀU KHIỂN I3C — RTL & UVM**

### 2. Thông điệp chính

Khóa luận trình bày hai đóng góp đồng hạng: Controller RTL và môi trường UVM tự kiểm tra.

### 3. Chữ trên slide

- Sinh viên: Võ Minh Huy — MSSV: 22207042
- Giảng viên hướng dẫn: ThS. Nguyễn Duy Mạnh Thi
- Khoa Điện tử – Viễn thông
- RTL Controller • UVM self-checking

### 4. Hình cụ thể

Không cần hình kỹ thuật. Có thể dùng rất mờ một dải SDA/SCL lấy từ `docs/report/latex/figures/png/fig_5_1_i3c_write_waveform.png`, không để waveform cạnh tranh với tiêu đề.

### 5. Bố cục

Tiêu đề lớn ở nửa trên; thông tin sinh viên và giảng viên ở góc dưới trái; nhãn “RTL Controller • UVM self-checking” ở góc dưới phải.

### 6. Lời thuyết trình

“Em xin trình bày khóa luận thiết kế và kiểm chứng bộ điều khiển I3C. Hai phần chính là kiến trúc RTL tạo giao dịch trên bus và môi trường UVM tự kiểm tra hành vi đó trong phạm vi yêu cầu đã chọn.”

### 7. Câu chuyển tiếp

“Trước hết, vì sao một bus hai dây rất thành công như I2C vẫn cần được cải tiến?”

### 8. Thời lượng

**15 giây**

## Slide 2 — Bài toán SoC: I2C bắt đầu chạm giới hạn

### 1. Tiêu đề

**Bài toán SoC: I2C bắt đầu chạm giới hạn**

### 2. Thông điệp chính

I2C tiết kiệm chân và dễ ghép thiết bị, nhưng Open-Drain, tốc độ và quản lý địa chỉ trở thành nút thắt khi hệ thống mở rộng.

### 3. Chữ trên slide

- **Ưu điểm còn giá trị:** SDA + SCL, nhiều thiết bị, ít chân
- **Open-Drain toàn giao dịch:** cạnh lên phụ thuộc pull-up
- **Fast Mode: 400 kHz:** hạn chế lưu lượng cảm biến
- **Địa chỉ chủ yếu tĩnh:** khó mở rộng và thay thế thiết bị
- **Không có CCC:** thiếu cơ chế quản lý chung trên bus

### 4. Hình cụ thể

Một phép so sánh trực quan bằng shape đơn giản: bên trái là bus SDA/SCL nối nhiều cảm biến; bên phải là bốn “nút thắt” Open-Drain, 400 kHz, địa chỉ tĩnh và thiếu CCC. Không tạo sơ đồ giao thức mới.

### 5. Bố cục

Chia 40/60. Bên trái giữ hình bus hai dây và nhãn “ưu điểm”; bên phải xếp bốn nút thắt theo chiều dọc, dùng một màu cảnh báo duy nhất.

### 6. Lời thuyết trình

“I2C vẫn rất phù hợp để nối cảm biến và ngoại vi vì chỉ dùng hai dây, ít chân và cho phép nhiều thiết bị cùng chia sẻ bus. Điểm yếu xuất hiện khi số thiết bị và lượng dữ liệu tăng. Vì toàn bộ giao dịch dùng Open-Drain, cạnh lên phụ thuộc điện trở kéo và điện dung bus; Fast Mode dừng ở 400 kHz. Địa chỉ thường phải cấu hình tĩnh, còn bus không có một tập lệnh quản lý chung tương đương CCC. Bài toán không phải bỏ I2C, mà là giữ ưu điểm hai dây và tháo các nút thắt này.”

### 7. Câu chuyển tiếp

“I3C giữ lại SDA/SCL, nhưng mỗi cải tiến của nó đồng thời đặt ra một yêu cầu thiết kế mới.”

### 8. Thời lượng

**45 giây**

## Slide 3 — I3C giải quyết giới hạn — đồng thời tạo yêu cầu mới

### 1. Tiêu đề

**I3C giải quyết giới hạn — đồng thời tạo yêu cầu mới**

### 2. Thông điệp chính

I3C tăng khả năng của bus bằng OD/PP, Dynamic Address và CCC, nhưng Controller phải điều phối pha, quyền lái và nhiều loại frame chính xác.

### 3. Chữ trên slide

- Open-Drain chậm → **OD + Push-Pull** → phải handoff đúng pha
- Địa chỉ tĩnh → **ENTDAA** → phải phân xử và cấp địa chỉ
- Thiếu quản lý bus → **CCC** → thêm Broadcast/Direct frame
- 400 kHz → **SDR đến 12,5 MHz** → timing phải cấu hình và kiểm tra
- Giữ SDA/SCL → **tương thích I2C** → hai chính sách timing/lái

### 4. Hình cụ thể

Hình chính: `docs/report/latex/figures/png/fig_2_4_sdr_private_write_read.png`. Đặt các callout “OD”, “PP”, “T-Bit/ACK” trực tiếp lên đúng pha của frame.

### 5. Bố cục

Phía trên là chuỗi ba cột “hạn chế → cải tiến → yêu cầu phát sinh”; phía dưới là frame chiếm toàn chiều ngang. Không đưa định nghĩa chi tiết START/ACK lên slide.

### 6. Lời thuyết trình

“I3C không thay bus hai dây mà thay cách sử dụng bus. Các pha cần phân xử hoặc phản hồi vẫn dùng Open-Drain; dữ liệu phù hợp chuyển sang Push-Pull để tăng tốc. ENTDAA cho phép Controller cấp Dynamic Address, còn CCC cung cấp lệnh quản lý chung hoặc cho từng Target. Trên frame phía dưới, điểm cần nhìn không phải từng bit mà là ranh giới OD–PP và cách ACK hoặc T-Bit thay đổi theo hướng truyền. Vì vậy, cải tiến về hiệu năng kéo theo yêu cầu mới về điều phối pha, quyền lái và kiểm tra timing.”

### 7. Câu chuyển tiếp

“Từ các yêu cầu mới đó, đề tài chọn một phạm vi đủ tạo thành đường xử lý đầu-cuối và đủ kiểm chứng.”

### 8. Thời lượng

**50 giây**

## Slide 4 — Mục tiêu và hai đóng góp đồng hạng: RTL + UVM

### 1. Tiêu đề

**Mục tiêu và hai đóng góp đồng hạng: RTL + UVM**

### 2. Thông điệp chính

Đề tài vừa xây dựng Controller RTL theo F1–F10/P1–P5, vừa xây dựng UVM để tự động chứng minh đúng trong chính phạm vi đó.

### 3. Chữ trên slide

- **RTL:** Host → bus → RX/Response hoàn chỉnh
- **UVM:** stimulus hai phía + expected–observed + SVA + coverage
- **F1–F10:** Private, Immediate, CCC, ENTDAA, I2C, Host/FIFO/error/timing
- **P1–P5:** 333 MHz; I3C 12,5 MHz; I2C 400 kHz; DAT 32; register 32-bit
- **Ngoài phạm vi:** IBI, Hot-Join, HDR, Target/Secondary Controller, full HCI

### 4. Hình cụ thể

Hai khối cân bằng tự dựng bằng shape: “RTL Controller” và “UVM self-checking”, nối vào cùng dải yêu cầu F1–F10/P1–P5. Không dùng hình kiến trúc để tránh lặp slide 6 và 11.

### 5. Bố cục

Hai cột 50/50. Dải yêu cầu chạy ngang phía dưới; một khung nhỏ “ngoài phạm vi” đặt ở chân slide và dùng màu trung tính.

### 6. Lời thuyết trình

“Mục tiêu thứ nhất là một Controller RTL có luồng hoàn chỉnh: Host gửi lệnh và dữ liệu, bus thực hiện giao dịch, rồi dữ liệu đọc và trạng thái quay về Host. Mục tiêu thứ hai, đồng hạng, là môi trường UVM tự kiểm tra hai giao diện của Controller. Phạm vi chức năng được khóa bằng F1 đến F10; các chỉ tiêu cấu hình là P1 đến P5. Những tính năng như IBI, Hot-Join, HDR và vai trò Target hay Secondary Controller không được triển khai, vì vậy cũng không được dùng để suy rộng kết quả coverage.”

### 7. Câu chuyển tiếp

“Để tránh yêu cầu chỉ tồn tại trên giấy, mỗi nhóm đều phải đi qua RTL, checker và một loại bằng chứng cụ thể.”

### 8. Thời lượng

**45 giây**

## Slide 5 — Từ yêu cầu giao thức đến RTL, checker và bằng chứng

### 1. Tiêu đề

**Từ yêu cầu giao thức đến RTL, checker và bằng chứng**

### 2. Thông điệp chính

Traceability được đóng kín theo chuỗi yêu cầu → cơ chế RTL → cơ chế kiểm tra → bằng chứng.

### 3. Chữ trên slide

| Nhóm yêu cầu | Cơ chế RTL | UVM/checker | Bằng chứng |
|---|---|---|---|
| OD/PP + Private | điều phối pha/lái | bus monitor + SVA | write/read waveform |
| ENTDAA | DAA + DAT | Target model + scoreboard | 3 dải DAA |
| CCC + I2C | policy frame/timing | monitor + reference | CCC/I2C waveform |
| Host/FIFO/error | đường lệnh–phản hồi | register monitor + scoreboard | regression/coverage |

### 4. Hình cụ thể

Chính ma trận bốn hàng là hình. Gắn thumbnail rất nhỏ ở cột bằng chứng, lấy từ `fig_5_1`, `fig_5_5`, `fig_5_4` và `coverage_all.jpg`; không thêm sơ đồ mới.

### 5. Bố cục

Ma trận chiếm gần toàn slide. Tô màu theo hàng, không theo cột, để mắt đi từ yêu cầu sang bằng chứng. Mỗi ô tối đa hai dòng.

### 6. Lời thuyết trình

“Ma trận này là xương sống của bài. Hàng đầu liên kết Private Transfer và chuyển OD/PP với điều phối pha ở RTL, bus monitor và SVA, rồi waveform write/read. Hàng ENTDAA nối xử lý cấp địa chỉ với DAT, Target model và Scoreboard. CCC và I2C tái sử dụng phần cứng nhưng cần policy frame và timing riêng. Cuối cùng, lệnh Host, FIFO, Response và lỗi được kiểm tra xuyên giao diện. Nhờ chuỗi này, waveform cho thấy sự kiện đã xảy ra, còn checker mới kết luận sự kiện đó đúng.”

### 7. Câu chuyển tiếp

“Bây giờ ta đi vào nửa RTL, bắt đầu bằng đường đi thật của một lệnh.”

### 8. Thời lượng

**50 giây**

## Slide 6 — Một lệnh đi qua Controller như thế nào?

### 1. Tiêu đề

**Một lệnh đi qua Controller như thế nào?**

### 2. Thông điệp chính

Controller tạo một vòng khép kín Host → xử lý giao thức → bus → RX/Response → Host.

### 3. Chữ trên slide

- Host nạp cấu hình, DAT, Command và TX data
- Transaction/DAA Processor chọn luồng giao thức
- SCL + Bus TX/RX tạo và lấy mẫu SDA/SCL
- PHY thực thi chế độ lái trên bus
- RX data + Response quay về Host

### 4. Hình cụ thể

`docs/report/latex/figures/png/fig_3_1_controller_architecture.png`. Thêm một đường highlight có đánh số 1→5: Host → CSR/FIFO/DAT → Transaction/DAA Processor → SCL và Bus TX/RX → PHY → Response/RX.

### 5. Bố cục

Hình kiến trúc chiếm 80% slide; năm nhãn ngắn nằm thành một dải dưới hình. Làm mờ các nhánh không nằm trên đường đang kể.

### 6. Lời thuyết trình

“Ta lần theo đường tô sáng trên hình. Host trước hết cấu hình timing và DAT, rồi nạp Command cùng dữ liệu ghi. Khối xử lý phân loại lệnh: giao dịch thông thường đi theo Transaction Processor, còn cấp địa chỉ đi theo nhánh DAA. Từ đó, SCL Generator và Bus TX/RX biến nội dung giao dịch thành hoạt động trên SDA/SCL; PHY quyết định cách lái chân. Ở chiều ngược lại, dữ liệu Target gửi được đưa về RX FIFO, còn trạng thái và số byte đã xử lý được đóng thành Response cho Host. Đây là đường đầu-cuối mà UVM phải kiểm tra.”

### 7. Câu chuyển tiếp

“Điểm khó nhất trên đoạn ra bus là đổi chế độ và đổi quyền lái SDA mà không tạo contention.”

### 8. Thời lượng

**55 giây**

## Slide 7 — Open-Drain/Push-Pull: đổi quyền lái mà không contention

### 1. Tiêu đề

**Open-Drain/Push-Pull: đổi quyền lái mà không contention**

### 2. Thông điệp chính

Chuyển OD/PP chỉ an toàn khi Controller và Target đổi quyền lái tại đúng ranh giới giao thức.

### 3. Chữ trên slide

- OD: các pha phân xử và phản hồi chung
- PP: Controller chủ động lái dữ liệu tốc độ cao
- **Write handoff:** giữ mức thấp trước khi đổi chế độ
- **Read takeover:** Target nhả, Controller giành lại trước STOP
- Target model + monitor + SVA kiểm tra ba góc nhìn độc lập

### 4. Hình cụ thể

Ghép `docs/report/latex/figures/png/fig_2_2_i3c_low_handoff.png` và `docs/report/latex/figures/png/fig_2_3_i3c_read_takeover.png`. Đánh dấu rõ “Controller drives”, “Target drives”, điểm handoff và điểm takeover.

### 5. Bố cục

Hai waveform đặt trên/dưới với cùng trục thời gian và cùng bảng màu quyền lái. Cột nhỏ bên phải ghi ba checker: Target model, monitor, SVA.

### 6. Lời thuyết trình

“Ở hình trên, Controller đang phát write. Pha đầu dùng Open-Drain; tại điểm handoff được khoanh, SDA được giữ thấp để đổi sang Push-Pull mà không tạo cạnh giả. Ở hình dưới, chiều read làm quyền lái đảo lại: Target phát dữ liệu và T-Bit, sau đó nhả SDA; Controller chỉ takeover tại ranh giới hợp lệ để tạo STOP. Ba cơ chế kiểm chứng nhìn cùng sự kiện theo ba cách: Target model tạo phản hồi, monitor tái tạo giao dịch từ chân bus, còn SVA kiểm tra theo chu kỳ rằng hai phía không cùng lái xung đột.”

### 7. Câu chuyển tiếp

“Khi quyền lái đã được kiểm soát, cùng datapath có thể phục vụ nhiều loại frame bằng các policy khác nhau.”

### 8. Thời lượng

**60 giây**

## Slide 8 — Một datapath, ba chính sách frame: Private / CCC / I2C

### 1. Tiêu đề

**Một datapath, ba chính sách frame: Private / CCC / I2C**

### 2. Thông điệp chính

Phần cứng truyền nhận được tái sử dụng; loại giao dịch quyết định địa chỉ, timing, ACK/T-Bit và cách kết thúc.

### 3. Chữ trên slide

- **Private:** Dynamic Address; OD preamble → PP data; T-Bit
- **CCC:** Broadcast/Direct; opcode + payload; có thể có Sr
- **I2C:** Static Address; toàn bộ Open-Drain; ACK/NACK
- Chung: tạo SCL, tuần tự hóa byte, lấy mẫu SDA, STOP/RSTART

### 4. Hình cụ thể

Ba crop cùng kích thước từ `fig_2_4_sdr_private_write_read.png`, `fig_2_6_enec_disec_frames.png` và `fig_5_8_i2c_write_waveform.png` trong `docs/report/latex/figures/png/`. Mỗi crop chỉ giữ đoạn cho thấy policy khác nhau.

### 5. Bố cục

Ba card ngang Private / CCC / I2C. Dải dưới cùng ghi phần cứng chung; tô callout khác màu tại address, OD/PP, ACK/T-Bit và STOP/Sr.

### 6. Lời thuyết trình

“Ba card cho thấy vì sao thiết kế không cần ba datapath riêng. Private Transfer dùng Dynamic Address, bắt đầu bằng các pha Open-Drain rồi có thể chuyển Push-Pull; write dùng T-Bit, còn read có phản hồi và kết thúc riêng. CCC thêm Broadcast hoặc Direct header, opcode và payload; Direct CCC trên kết quả sau còn có Repeated START. I2C dùng Static Address, giữ toàn bộ giao dịch ở Open-Drain và dùng ACK/NACK. Phần tạo SCL, dịch byte và lấy mẫu SDA vẫn dùng chung; policy giao dịch quyết định địa chỉ, timing, phản hồi và cách kết thúc.”

### 7. Câu chuyển tiếp

“Policy phức tạp nhất trong phạm vi đề tài là ENTDAA, vì nó vừa nhận định danh vừa thay đổi trạng thái địa chỉ của Target.”

### 8. Thời lượng

**55 giây**

## Slide 9 — ENTDAA: từ địa chỉ tĩnh đến cấp phát động có kiểm chứng

### 1. Tiêu đề

**ENTDAA: từ địa chỉ tĩnh đến cấp phát động có kiểm chứng**

### 2. Thông điệp chính

ENTDAA là một vòng lặp có trạng thái: Controller nhận định danh, chọn địa chỉ từ DAT, cấp phát và kiểm tra phản hồi cho từng Target.

### 3. Chữ trên slide

- Broadcast ENTDAA → Target tham gia phân xử
- Nhận PID/BCR/DCR → chọn Dynamic Address từ DAT
- Gửi địa chỉ + parity → kiểm tra ACK/NACK → lặp
- Test: 0/1/nhiều Target, NACK, reserved address, biên DAT

### 4. Hình cụ thể

Hình khung: `docs/report/latex/figures/png/fig_2_5_entdaa_frame.png`. Bên dưới ghép liên tục `fig_5_5_entdaa_part1_waveform.png`, `fig_5_6_entdaa_part2_waveform.png`, `fig_5_7_entdaa_part3_waveform.png` và đánh số ba pha.

### 5. Bố cục

Frame lý thuyết ở 35% phía trên; ba dải waveform ở 65% phía dưới. Một đường nối dọc ánh xạ “CCC”, “ID”, “assigned address” giữa frame và waveform.

### 6. Lời thuyết trình

“ENTDAA được điều phối bởi hai luồng ở mức khái quát: luồng giao dịch tạo Broadcast CCC và các điều kiện bus; luồng DAA quản lý từng lượt nhận định danh và cấp địa chỉ. Trên frame, sau ENTDAA, Target thắng phân xử gửi PID, BCR và DCR. Controller lấy Dynamic Address từ vùng DAT được chỉ định, gửi địa chỉ kèm parity và quan sát ACK; nếu còn Target thì lặp. Ba dải waveform phía dưới lần lượt chứng minh mở đầu CCC, nhận chuỗi định danh và cấp địa chỉ. Testbench còn kích hoạt trường hợp không có Target, một hoặc nhiều lượt, NACK, địa chỉ reserved và các biên đầu/cuối DAT.”

### 7. Câu chuyển tiếp

“Các waveform này rất hữu ích để giải thích giao thức, nhưng chỉ nhìn waveform vẫn chưa đủ để kết luận toàn bộ Controller đúng.”

### 8. Thời lượng

**70 giây**

## Slide 10 — Vì sao waveform thủ công chưa đủ?

### 1. Tiêu đề

**Vì sao waveform thủ công chưa đủ?**

### 2. Thông điệp chính

Lỗi của Controller có thể nằm giữa các giao diện dù một phần waveform trông đúng; cần kiểm tra xuyên suốt Host–bus–Host.

### 3. Chữ trên slide

- Lệnh Host đúng → **bus phát sai**
- Bus nhận đúng → **RX FIFO sai**
- Dữ liệu đúng → **Response sai**
- Waveform giải thích; checker mới kết luận PASS/FAIL

### 4. Hình cụ thể

Ba card cảnh báo tự dựng, cùng một đường Host → Bus → Host. Mỗi card đặt dấu lỗi tại một ranh giới khác nhau; dùng icon đơn giản, không tạo sơ đồ kiến trúc mới.

### 5. Bố cục

Ba card ngang bằng nhau. Dưới mỗi card chỉ có một câu “observed cục bộ đúng, quan hệ đầu-cuối sai”.

### 6. Lời thuyết trình

“Waveform giúp thấy START, byte dữ liệu hay STOP, nhưng Controller có nhiều miền quan sát. Host có thể nạp đúng descriptor trong khi bus phát sai địa chỉ. Target có thể gửi đúng byte trên bus nhưng RX FIFO lưu sai thứ tự. Giao dịch và dữ liệu đều có thể đúng nhưng Response lại báo sai số byte hoặc mã lỗi. Nếu chỉ nhìn một cửa sổ tín hiệu, các lỗi xuyên giao diện này dễ bị bỏ qua. Vì vậy waveform trong bài là bằng chứng minh họa; kết luận PASS/FAIL phải đến từ cơ chế expected–observed tự động.”

### 7. Câu chuyển tiếp

“Môi trường UVM được tổ chức đúng theo hai phía cần nối lại: phía Host và phía Target.”

### 8. Thời lượng

**40 giây**

## Slide 11 — UVM tự kiểm tra ở hai phía Host–Target

### 1. Tiêu đề

**UVM tự kiểm tra ở hai phía Host–Target**

### 2. Thông điệp chính

Hai agent tạo và quan sát hai giao diện độc lập; Scoreboard nối các quan sát thành kết luận đầu-cuối.

### 3. Chữ trên slide

- Register Agent đóng vai **Host** tại CSR/FIFO/DAT
- I3C Agent đóng vai **Target** trên SDA/SCL
- Hai monitor thu observed độc lập với driver
- Scoreboard đối chiếu; coverage ghi nhận activation

### 4. Hình cụ thể

`docs/report/latex/figures/png/fig_4_1_uvm_architecture.png`. Tô hai vùng Host và Target khác màu; làm nổi hai đường monitor đi vào Scoreboard/coverage.

### 5. Bố cục

Hình chiếm 80% slide. Bốn dòng chữ đặt ở dải dưới; không bổ sung class hierarchy, factory hay UVM phase.

### 6. Lời thuyết trình

“Đây là kiến trúc UVM, khác với kiến trúc RTL ở slide trước. Register Agent đóng vai Host: cấu hình CSR và DAT, nạp FIFO rồi đọc kết quả. I3C Agent đóng vai Target: phản hồi địa chỉ, gửi hoặc nhận data và tham gia ENTDAA. Quan trọng nhất là hai monitor quan sát độc lập với driver; chúng tái tạo điều thực sự xảy ra thay vì tin vào stimulus đã yêu cầu. Các luồng observed được đưa tới Scoreboard để đối chiếu đầu-cuối và tới coverage để ghi nhận tình huống nào đã được kích hoạt.”

### 7. Câu chuyển tiếp

“Để một kịch bản xảy ra đúng thời điểm, stimulus của hai agent phải được điều phối nhưng không được tự chấm điểm.”

### 8. Thời lượng

**55 giây**

## Slide 12 — Virtual Sequence đồng bộ stimulus Host và phản hồi Target

### 1. Tiêu đề

**Virtual Sequence đồng bộ stimulus Host và phản hồi Target**

### 2. Thông điệp chính

Virtual Sequence phối hợp hai nhánh chạy song song; nó tạo điều kiện kiểm thử, còn checker quyết định đúng sai.

### 3. Chữ trên slide

- Host: cấu hình → nạp TX/Command → đọc RX/Response
- Target: địa chỉ → ACK/NACK/T-Bit → phát/nhận data
- Hai nhánh chạy song song, đồng bộ tại sự kiện bus
- Sequence tạo stimulus, **không tự kết luận PASS/FAIL**

### 4. Hình cụ thể

`docs/report/latex/figures/png/fig_4_3_virtual_sequence_coordination.png`. Đánh dấu hai nhánh Host và Target, cùng điểm chúng gặp nhau tại DUT/bus.

### 5. Bố cục

Hình ở trung tâm, hai dải chú thích bám hai bên tương ứng hai nhánh. Một banner nhỏ ở đáy: “check ở monitor/reference/scoreboard/SVA”.

### 6. Lời thuyết trình

“Một lệnh Host chỉ trở thành giao dịch có nghĩa nếu Target phản hồi đúng lúc. Virtual Sequence vì vậy khởi chạy hai nhánh song song. Nhánh Host cấu hình, nạp dữ liệu và command, rồi chờ đọc RX và Response. Nhánh Target chuẩn bị địa chỉ, quyết định ACK/NACK hoặc T-Bit, và phát hay nhận payload theo kịch bản. Hai nhánh đồng bộ qua diễn biến bus chứ không gọi trực tiếp vào nhau. Sequence chỉ tạo stimulus và các trường hợp lỗi có chủ đích; nó không tự tuyên bố PASS, để tiêu chí đúng sai không bị lặp hoặc phụ thuộc driver.”

### 7. Câu chuyển tiếp

“Khi stimulus đã tách khỏi verdict, ba lớp kiểm tra có thể đảm nhiệm ba loại câu hỏi khác nhau.”

### 8. Thời lượng

**45 giây**

## Slide 13 — Expected–observed: Scoreboard + SVA + Coverage

### 1. Tiêu đề

**Expected–observed: Scoreboard + SVA + Coverage**

### 2. Thông điệp chính

Scoreboard kiểm tra quan hệ đầu-cuối, SVA bắt vi phạm theo chu kỳ, coverage đo tình huống đã được kích hoạt.

### 3. Chữ trên slide

- Reference Model: Host intent → expected bus / RX / Response
- Scoreboard: expected ↔ observed trên ba đường
- SVA: handshake, FIFO, timing, quyền lái, handoff/takeover
- Coverage: Host intent • bus behavior • tương quan đầu-cuối
- Đúng sai và độ phủ là hai kết luận riêng

### 4. Hình cụ thể

`docs/report/latex/figures/png/fig_4_2_scoreboard_flow.png`. Tô rõ phía expected từ Reference Model và phía observed từ hai monitor; gắn hai vệ tinh nhỏ “SVA: cycle” và “Coverage: activation”.

### 5. Bố cục

Hình scoreboard chiếm 70% bên trái; bên phải là ba card Scoreboard/SVA/Coverage, mỗi card chỉ một câu hỏi. Tránh liệt kê trường descriptor hoặc class.

### 6. Lời thuyết trình

“Reference Model theo dõi những gì Host thực sự cấu hình và nạp: command, DAT và TX data. Từ đó nó dự đoán ba đầu ra: giao dịch phải xuất hiện trên bus, dữ liệu phải quay về RX FIFO và Response phải mô tả đúng kết quả. Hai monitor cung cấp observed độc lập để Scoreboard đối chiếu cả ba đường. SVA bổ sung góc nhìn theo chu kỳ, ví dụ handshake, trạng thái FIFO, timing SCL và quyền lái SDA tại handoff/takeover. Coverage không kết luận thiết kế đúng; nó hỏi các tình huống mục tiêu đã được kích hoạt chưa ở ba lớp: ý định Host, hành vi bus và tương quan đầu-cuối. Vì thế PASS và closure phải được báo cáo riêng.”

### 7. Câu chuyển tiếp

“Với cơ chế kiểm tra này, ta có thể dùng waveform để chỉ ra những chuyển pha thật sự, rồi dùng kết quả checker để kết luận.”

### 8. Thời lượng

**70 giây**

## Slide 14 — Waveform: các điểm chuyển pha thật sự đã xảy ra

### 1. Tiêu đề

**Waveform: các điểm chuyển pha thật sự đã xảy ra**

### 2. Thông điệp chính

Bốn waveform đại diện xác nhận các policy bus khác nhau đã được kích hoạt và quan sát đúng điểm chuyển pha.

### 3. Chữ trên slide

- Private Write: **OD → PP** trước data
- Private Read Abort: **takeover → STOP** tại biên hợp lệ
- Direct ENEC: **Sr** nối Broadcast với Direct frame
- I2C Write: **Open-Drain toàn giao dịch**

### 4. Hình cụ thể

Lưới 2×2: `fig_5_1_i3c_write_waveform.png`, `fig_5_2_i3c_read_abort_waveform.png`, `fig_5_4_enec_direct_waveform.png`, `fig_5_8_i2c_write_waveform.png` trong `docs/report/latex/figures/png/`. Mỗi ô có đúng một callout lớn.

### 5. Bố cục

Lưới 2×2 đồng kích thước; cắt bỏ vùng tín hiệu không liên quan. Dùng cùng màu cho OD, PP, quyền lái Target và condition S/Sr/P ở cả bốn ô.

### 6. Lời thuyết trình

“Bốn ô chỉ vào bốn requirement cụ thể. Trên Private Write, tín hiệu chọn chế độ đổi từ Open-Drain sang Push-Pull trước pha data: đây là bằng chứng cho F1 và cơ chế slide 7. Private Read có yêu cầu abort; Target nhả bus, Controller takeover tại biên hợp lệ rồi mới tạo STOP, liên hệ F2 và F9. Direct ENEC cho thấy Repeated START nối phần Broadcast với phần địa chỉ Direct, là hành vi thuộc F4. I2C Write giữ Open-Drain từ đầu đến cuối và dùng ACK/NACK, chứng minh policy F6 khác I3C. Các ảnh cho thấy activation; bus monitor, Scoreboard và SVA mới xác nhận nội dung, kết quả và timing đều đúng.”

### 7. Câu chuyển tiếp

“Từ các trường hợp đại diện này, regression và coverage cho biết toàn bộ tập mục tiêu đã đi được đến đâu.”

### 8. Thời lượng

**75 giây**

## Slide 15 — Kết quả: pass, closure và activation — trong phạm vi đã định

### 1. Tiêu đề

**Kết quả: pass, closure và activation — trong phạm vi đã định**

### 2. Thông điệp chính

Regression hoàn thành mà không ghi nhận lỗi từ checker; các bin Functional Coverage đã định nghĩa cho F1–F10/P1–P5 được kích hoạt trong giới hạn một seed.

### 3. Chữ trên slide

- **81/81 PASS** với `Seed = 1`
- **0 UVM_ERROR / 0 UVM_FATAL**
- **222/222 closure + 173/173 diagnostic**
- **Không ghi nhận lỗi SVA**
- Phạm vi kết luận: verification model **F1–F10/P1–P5**

### 4. Hình cụ thể

`docs/report/latex/figures/coverage_all/coverage_all.jpg` làm bằng chứng phụ ở chân slide; không phóng log thành nội dung chính. Các con số lớn là hình thị giác chính.

### 5. Bố cục

Bốn ô kết quả lớn ở 75% phía trên; dải phạm vi kết luận và ảnh log ở 25% phía dưới. Không dùng biểu đồ tròn vì không cần biểu diễn cơ cấu tỷ lệ.

### 6. Lời thuyết trình

“Cùng một regression gồm 81 test, chạy với seed cố định bằng 1, cho 81 trên 81 PASS và không có UVM_ERROR hay UVM_FATAL. Functional Coverage đạt 222 trên 222 closure bin; 173 trên 173 diagnostic bin cũng được kích hoạt. Phía SVA, regression không ghi nhận assertion failure. Do chưa có công cụ chuyên dụng để phân tích SVA coverage, khóa luận không kết luận về độ bao phủ assertion. Kết quả cung cấp bằng chứng mô phỏng cho F1–F10 và P1–P5, không phải tuyên bố full compliance hay thiết kế không còn lỗi.”

### 7. Câu chuyển tiếp

“Vì mọi con số đều gắn với một model hữu hạn, kết luận cuối cùng phải đặt phần đã chứng minh cạnh phần chưa chứng minh.”

### 8. Thời lượng

**60 giây**

## Slide 16 — Kết luận có giới hạn và hướng phát triển

### 1. Tiêu đề

**Kết luận có giới hạn và hướng phát triển**

### 2. Thông điệp chính

Đề tài đã chứng minh một Controller RTL và UVM đầu-cuối trong phạm vi chọn; phần chưa chứng minh xác định trực tiếp lộ trình tiếp theo.

### 3. Chữ trên slide

| Đã chứng minh | Chưa chứng minh / hướng phát triển |
|---|---|
| Host → bus → RX/Response | nhiều seed, nhiều Target, coverage sâu hơn |
| Private, Immediate, CCC, ENTDAA, I2C | IBI, Hot-Join, HDR |
| F1–F10/P1–P5 bằng mô phỏng RTL | vai trò Target/Secondary Controller |
| Scoreboard + SVA + coverage khép kín | synthesis, post-synthesis timing, FPGA |

### 4. Hình cụ thể

Không dùng thêm hình nguồn. Hai cột đối xứng là hình chính; một đường biên đậm phân tách “bằng chứng hiện có” và “chưa có bằng chứng”.

### 5. Bố cục

Hai cột 50/50. Cột trái dùng màu kết quả; cột phải dùng màu trung tính, không dùng màu đỏ để tránh diễn giải “thất bại”.

### 6. Lời thuyết trình

“Phần đã chứng minh là đường xử lý từ Host qua Controller, ra bus rồi quay về RX và Response; các chức năng Private, Immediate, CCC, ENTDAA và I2C đều có bằng chứng mô phỏng theo F1–F10/P1–P5. UVM kết hợp Scoreboard, SVA và coverage để tự động hóa kết luận. Tuy nhiên, regression hiện dùng một seed và mô hình chủ yếu một Controller–một Target. Chưa có IBI, Hot-Join, HDR hay vai trò Target/Secondary Controller; cũng chưa có tổng hợp, timing sau tổng hợp hoặc FPGA. Hướng phát triển là mở rộng không gian kiểm chứng trước, rồi mở rộng giao thức và bằng chứng phần cứng.”

### 7. Câu chuyển tiếp

“Đó là phạm vi kết quả em xin trình bày; em xin cảm ơn hội đồng và sẵn sàng trao đổi.”

### 8. Thời lượng

**70 giây**

## Slide 17 — Cảm ơn

### 1. Tiêu đề

**XIN CẢM ƠN HỘI ĐỒNG ĐÃ LẮNG NGHE**

### 2. Thông điệp chính

Kết thúc phần trình bày và chuyển sang câu hỏi, không đưa thêm kết luận kỹ thuật mới.

### 3. Chữ trên slide

- XIN CẢM ƠN HỘI ĐỒNG ĐÃ LẮNG NGHE
- CÂU HỎI VÀ THẢO LUẬN
- RTL Controller • UVM self-checking • evidence in scope

### 4. Hình cụ thể

Có thể dùng mờ hai thumbnail cân bằng: `fig_3_1_controller_architecture.png` và `fig_4_1_uvm_architecture.png`; không thêm waveform hoặc số liệu mới.

### 5. Bố cục

Lời cảm ơn ở trung tâm; hai thumbnail mờ ở hai góc dưới để nhắc lại cân bằng RTL–UVM.

### 6. Lời thuyết trình

“Em xin cảm ơn thầy cô trong hội đồng đã lắng nghe. Em xin tiếp nhận câu hỏi và góp ý về thiết kế RTL, phương pháp kiểm chứng UVM cũng như phạm vi của các bằng chứng đã trình bày.”

### 7. Câu chuyển tiếp

“Em xin mời câu hỏi từ hội đồng.”

### 8. Thời lượng

**10 giây**

---

## Audit cuối tài liệu

### 1. Số slide và thời lượng

| Phần | Slide | Thời lượng |
|---|---:|---:|
| Tiêu đề | 1 | 0:15 |
| Bối cảnh, mục tiêu, traceability | 2–5 | 3:10 |
| Cơ chế RTL và giao thức | 6–9 | 4:20 |
| UVM và cơ chế kiểm tra | 10–13 | 3:30 |
| Waveform, kết quả, kết luận | 14–16 | 3:25 |
| Cảm ơn | 17 | 0:10 |
| **Tổng** | **17** | **14:30** |

Khoảng dự phòng trong khung 15 phút: **0:30**.

### 2. Cân bằng RTL–UVM

- Nền tảng và phạm vi chung: slide 2–5 — **3:10**.
- RTL/giao thức: slide 6–9 — **4:20**.
- UVM/verification method: slide 10–13 — **3:30**.
- Bằng chứng tích hợp RTL–UVM: slide 14–15 — **2:15**.
- Kết luận chung: slide 16 — **1:10**.

RTL và UVM được trình bày thành hai nửa rõ ràng; hai đóng góp gặp nhau ở traceability (slide 5), waveform có checker (slide 14) và số liệu closure (slide 15).

### 3. Traceability F1–F10/P1–P5

| Yêu cầu | Slide trình bày cơ chế | Slide bằng chứng/kết luận |
|---|---|---|
| F1–F2: I3C Private Write/Read | 3, 7, 8 | 14, 15 |
| F3: Immediate Data Transfer | 4, 8 | 15 |
| F4: Broadcast/Direct ENEC–DISEC | 3, 8 | 14, 15 |
| F5: ENTDAA | 3, 9 | 9, 15 |
| F6: I2C Fast Mode | 3, 8 | 14, 15 |
| F7: CSR/FIFO/DAT | 4, 6 | 11–13, 15 |
| F8: Response Descriptor | 6, 10, 13 | 15 |
| F9: abort/reset/backpressure/error | 4, 10, 13 | 14, 15 |
| F10: timing/enable qua CSR | 3, 4, 6 | 13–15 |
| P1: system clock 333 MHz | 4 | 15–16, bằng chứng mô phỏng RTL |
| P2: I3C SCL đến 12,5 MHz | 3–4, 7–8 | 13–15, timing theo chu kỳ |
| P3: I2C SCL đến 400 kHz | 2–4, 8 | 14–15, timing theo chu kỳ |
| P4: DAT 32 mục | 4, 6, 9 | 9, 15, test biên DAT |
| P5: giao diện thanh ghi 32-bit | 4, 6 | 11–13, 15 |

Lưu ý: P1–P3 là bằng chứng mô phỏng hành vi/timing theo chu kỳ clock, không phải timing closure sau tổng hợp.

### 4. Slide có nguy cơ nhiều chữ

| Slide | Rủi ro | Cách khống chế khi dựng slide |
|---:|---|---|
| 5 | ma trận bốn cột | mỗi ô tối đa hai dòng; thumbnail thay mô tả dài |
| 8 | so sánh ba loại frame | ba card đồng cấu trúc; chỉ callout bốn điểm khác nhau |
| 13 | ba cơ chế kiểm tra | mỗi card trả lời đúng một câu hỏi; chi tiết để trong notes |
| 16 | kết luận và giới hạn | hai cột đối xứng; mỗi ô một dòng, không thêm tiểu mục |

### 5. Kiểm tra nội dung trùng

- Slide 6 chỉ nói kiến trúc **RTL** và đường Host–bus–Host.
- Slide 11 chỉ nói kiến trúc **UVM** và vai trò hai agent/monitor.
- Slide 13 không lặp kiến trúc; chỉ giải thích **cơ chế verdict và activation**.
- Slide 9 dùng ENTDAA để giải thích cơ chế; slide 14 không lặp ENTDAA mà chọn bốn waveform đại diện khác.
- Slide 15 báo số liệu; slide 16 chỉ diễn giải phạm vi của kết luận và phần chưa có bằng chứng.

### 6. Audit nguồn và cách diễn giải

- Nguồn cuối cho Functional Coverage: `src/verification/coverage_report.txt` — 81 test, 222/222 closure bin, 173/173 diagnostic bin.
- Kết quả SVA chỉ được diễn giải là regression không ghi nhận assertion failure; không dùng báo cáo tự trích xuất để kết luận SVA coverage.
- Danh sách regression hiện hành: `src/verification/Makefile`, có test `i3c_daa_reserved_addr_resp_vseq`.
- Điều kiện chạy và đối chiếu yêu cầu: `docs/report/latex/chapters/05_results.tex`; giới hạn: `docs/report/latex/chapters/06_conclusion.tex`.
- `src/verification/regression_result.txt` là snapshot cũ 80 test, thiếu test DAA reserved-address; **không dùng số 80 trên slide**.
- Functional Coverage 100% chỉ có nghĩa toàn bộ bin đã định nghĩa trong verification model F1–F10 được kích hoạt; không có nghĩa full I3C compliance, không còn lỗi hoặc sẵn sàng phần cứng.
- Toàn bộ 17 đường dẫn hình được nêu trong đề cương đã được kiểm tra tồn tại trong cây nguồn; không yêu cầu sửa RTL, UVM, API hoặc hình nguồn.
