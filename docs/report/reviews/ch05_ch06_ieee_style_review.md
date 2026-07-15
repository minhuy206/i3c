# Phản biện văn phong IEEE — Chương 5 và Chương 6

## Phạm vi và nguyên tắc

Nhận xét này chỉ xét văn phong của `05_results.tex` và `06_conclusion.tex` tại thời điểm rà soát. Các số liệu và kết luận kỹ thuật được giữ nguyên. Nội dung kỹ thuật chỉ được đề cập khi cách trình bày làm giảm tính rõ ràng, khả năng truy vết hoặc tính nhất quán thuật ngữ.

Quy ước điểm: 10 là tốt nhất đối với bốn tiêu chí tổng thể. Riêng **mức độ dư thừa**, 10 là dư thừa nghiêm trọng.

## Đánh giá tổng thể

| Tiêu chí | Điểm | Nhận xét |
|---|---:|---|
| Tính súc tích | 6/10 | Nhiều câu chứa mệnh đề giải thích có thể rút gọn; một số số liệu được lặp ba lần. |
| Khả năng đọc | 7/10 | Cấu trúc chương rõ, nhưng câu dài và thuật ngữ Việt–Anh trộn lẫn làm tăng tải đọc. |
| Viết kỹ thuật | 7/10 | Bằng chứng định lượng tốt; một số nhận định suy diễn và cấu trúc liệt kê chưa đủ trung tính. |
| Tuân thủ văn phong IEEE | 6/10 | Cần tăng tính khách quan, chuẩn hóa thuật ngữ và giảm diễn đạt dẫn chuyện. |
| Mức độ dư thừa | 4/10 | Dư thừa ở mức vừa; tập trung tại phần tổng kết Chương 5 và phần mở đầu/kết thúc Chương 6. |

## Vấn đề xuyên suốt hai chương

### Thuật ngữ cần chuẩn hóa

Nên chọn một dạng duy nhất và dùng nhất quán. Tên lớp, thành phần mã nguồn và định danh SystemVerilog được giữ nguyên bằng tiếng Anh; khái niệm mô tả nên dùng tiếng Việt.

| Dạng hiện tại | Dạng đề nghị | Ghi chú |
|---|---|---|
| simulation | mô phỏng | Dùng `simulation` chỉ khi là một phần của tên công cụ hoặc trích log. |
| regression | hồi quy kiểm chứng | Sau lần định nghĩa đầu có thể dùng “hồi quy”. |
| waveform | dạng sóng | Tên tệp hoặc tùy chọn `DUMP_WAVES` giữ nguyên. |
| stimulus | kích thích | “Thư viện kích thích”, “kịch bản kích thích”. |
| coverage | độ bao phủ | Giữ `Functional Coverage`, `covergroup`, `coverpoint`, `cross`, `bin` khi chỉ cấu trúc ngôn ngữ/UVM. |
| coverage closure | đóng độ bao phủ | Không dùng cấu trúc lai “coverage chưa closure”. |
| gap | khoảng trống kiểm chứng | Tránh từ khẩu ngữ kỹ thuật tiếng Anh trong văn bản tiếng Việt. |
| assertion | thuộc tính SVA / assertion | Định nghĩa “thuộc tính SVA (assertion)” lần đầu; sau đó dùng một dạng. |
| checker | bộ kiểm tra | Giữ tên định danh checker trong `\texttt{}`. |
| fail / pass | thất bại / đạt | `PASS`, `UVM_ERROR`, `UVM_FATAL` giữ nguyên khi chỉ trạng thái hoặc trường log. |
| Testbench | môi trường kiểm chứng | Dùng `Testbench` khi đề cập tên khối cụ thể đã được định nghĩa bằng macro. |
| Scoreboard | `\texttt{i3c_scoreboard}` hoặc scoreboard | Không chuyển đổi giữa “Scoreboard” và tên định danh trong cùng ngữ cảnh. |
| instance | thể hiện | Có thể ghi “thể hiện (instance)” ở lần đầu. |
| queue | hàng đợi | Giữ `Command Queue` nếu đây là tên giao diện; không dùng “queue” cho danh từ chung. |
| nominal | danh định | Tránh “luồng nominal”. |
| debug | gỡ lỗi | Tên chức năng công cụ có thể giữ tiếng Anh. |
| synthesis / timing closure | tổng hợp / khép kín định thời | Chuẩn hóa trong cả hai chương. |

Ngoài ra, cần thống nhất cách gọi `Virtual Sequence`: nếu đây là lớp UVM cụ thể, dùng macro hoặc kiểu chữ mã nguồn; nếu chỉ tập kịch bản, dùng “trình tự ảo”. Các thuật ngữ `property`, `assertion`, `cover property` và `checker` không đồng nghĩa: `property` là thuộc tính, `assertion` là phép kiểm tra thuộc tính, `cover property` là phép ghi nhận kích hoạt, và `checker` là khối chứa các phép kiểm tra. Bản hiện tại đôi lúc dùng “assertion” để chỉ cả thuộc tính lẫn kết quả kiểm tra.

## (A) Nhận xét có chú giải

### Chương 5

| Dòng | Tiêu chí | Vấn đề | Đề nghị |
|---:|---|---|---|
| 13–16 | Câu, mật độ thông tin | Câu mở đầu liệt kê sáu nội dung, dài và mang tính dẫn chuyện (“Nội dung đi theo trình tự…”). | Dùng một câu nêu mục đích; bỏ mục lục bằng văn xuôi vì các đề mục đã thể hiện cấu trúc. |
| 18 | IEEE tone | “Baseline” chưa được Việt hóa hoặc định nghĩa. | Đổi thành “Điều kiện đo và phương pháp đánh giá”. |
| 21–25 | Câu, thuật ngữ | Đoạn chứa bốn ý: trạng thái mã nguồn, công cụ, seed và tiêu chí PASS. “để kết quả tái lập được”, “tái lập chính xác” lặp ý. “zero” và “simulation” tạo câu lai ngôn ngữ. | Tách thành ba câu; dùng “không có”; chỉ nêu khả năng tái lập một lần. |
| 23–24 | Chính xác diễn đạt | “constrained-random vẫn sinh ngẫu nhiên … trên seed đó” dài và có thể gây hiểu nhầm rằng cùng seed vẫn tạo kết quả khác nhau. | Viết: “Kích thích ngẫu nhiên có ràng buộc vẫn được sử dụng, nhưng chuỗi kích thích được cố định bởi seed.” |
| 27–28 | Súc tích | Hai câu chỉ có chức năng dẫn bảng; “tóm tắt baseline” lặp tiêu đề. | Gộp: “Bảng … tóm tắt điều kiện đo; độ bao phủ được hợp nhất từ 80 phép thử.” |
| 32, 36–44 | Thuật ngữ | Bảng trộn “Simulator”, “Seed”, “Coverage”, “test class”, “Simulation” với tiếng Việt. | Việt hóa nhãn mô tả; giữ tên công cụ và định danh kỹ thuật. |
| 49–51 | IEEE tone | “phản ánh trọng tâm khóa luận…” là diễn giải chủ quan từ số dòng mã; không cần cho kết quả đo. | Nêu tỷ lệ và phân bố. Nếu giữ diễn giải, dùng “Tỷ lệ này phù hợp với phạm vi tập trung vào kiểm chứng.” |
| 56–58 | Câu | Câu thứ hai chứa kết quả phân nhóm, chế độ SDR và vị trí phụ lục. | Tách thành hai câu. “assertion fail” đổi thành “phép kiểm tra SVA thất bại”. |
| 84–87 | Câu, tổ chức | Một câu 58 từ, gồm cơ chế, điều kiện lỗi và suy luận từ biên dịch. Nội dung là bằng chứng bổ sung, nhưng chuyển tiếp “Ngoài 80 test” yếu. | Chia thành hai câu. Đặt sau đoạn giải thích ý nghĩa PASS hoặc tạo tiểu đoạn “Kiểm tra tham số”. |
| 89–93 | Mật độ, câu | Cấu trúc “Thứ nhất/Thứ hai” hợp lý nhưng câu đầu chứa ba cơ chế không được định danh rõ; “kết luận đồng thời của cả ba” mơ hồ. | Nêu trực tiếp: kết quả PASS dựa trên scoreboard, SVA và trạng thái UVM. Tách giới hạn của seed thành câu riêng. |
| 98–104 | Câu, danh sách | Câu đầu dài, chứa mục đích, công cụ, tùy chọn và danh sách năm đặc trưng giao thức. | Chia thành câu về phương pháp và câu về các đặc trưng quan sát. Danh sách có thể chuyển vào chú thích hình hoặc bảng nhỏ nếu cần phân tích từng đặc trưng. |
| 102–104 | Dư thừa | Hai hình đã có chú thích; câu lặp lại tên giao dịch và mô tả hình. | Chỉ nêu điểm phân tích bổ sung: chuyển Open Drain sang Push-Pull ở hình ghi. |
| 158–160 | Tone, thuật ngữ | “mang tính minh họa và phục vụ debug” mang sắc thái hội thoại; danh sách chen bằng gạch ngang làm câu nặng. | Viết hai câu khách quan; dùng “gỡ lỗi”; dùng dấu hai chấm cho danh sách. |
| 167–169 | Súc tích | Câu dẫn bảng lặp số liệu tổng sẽ xuất hiện ngay trong bảng. | Giữ một câu nêu tổng và một câu nêu số covergroup đạt 100%; bỏ “phân rã theo”. |
| 173, 177 | Thuật ngữ | “Functional Coverage theo component”, “Bin covered” là cấu trúc lai. | “Độ bao phủ chức năng theo thành phần”, “Số bin được bao phủ”. |
| 188–197 | Mật độ | Hình chụp tổng kết lặp trực tiếp số liệu bảng, không thêm quan hệ mới. | Nếu hình chỉ là ảnh IMC, chuyển sang phụ lục làm bằng chứng tái lập; trong chương chính giữ bảng. |
| 199–201 | Tone | “Đúng như nguyên tắc…”, “con số tổng chỉ có ý nghĩa…” là diễn đạt dẫn chuyện và tuyệt đối. | Viết trực tiếp: “Tỷ lệ tổng cần được đánh giá cùng các bin chưa bao phủ.” |
| 203–212 | Danh sách, câu | Mỗi mục là một câu dài gồm kết quả, nguyên nhân và hệ quả. Ba mục có cấu trúc lặp. | Chuyển thành bảng gồm `covergroup`, tỷ lệ, phần chưa bao phủ và nguyên nhân. Nếu giữ danh sách, chia mỗi mục thành hai câu. |
| 214–218 | Tone, câu | “Cách đọc này cho một kết luận cân bằng” chủ quan; “gần đủ” không định lượng; câu cuối chứa hai hành động và tham chiếu. | Nêu trực tiếp các tỷ lệ. Tách việc bổ sung kịch bản và rà soát tổ hợp không khả thi. |
| 222–224 | Câu, thuật ngữ | Cụm ngoặc dài làm gián đoạn chủ ngữ–vị ngữ. “instance checker SVA” không tự nhiên. | Tách số lượng thể hiện, cách `bind`, và số lượng phép kiểm tra thành hai câu. |
| 241–249 | Câu, tổ chức | Đoạn chứa bốn mục đích: kết quả, cơ chế phát hiện, ba nhóm thiếu kích thích và diễn giải. Câu liệt kê ba nhóm quá dài. | Tách thành hai đoạn: (1) kết quả kích hoạt; (2) phân loại khoảng trống kích thích. Có thể dùng bảng ba hàng. |
| 241–243 | Thuật ngữ | “assertion … pass rỗng (vacuous)” trộn phép kiểm tra với thuộc tính và trạng thái. | “Không có phép kiểm tra SVA nào thất bại hoặc đạt theo nghĩa rỗng (vacuous pass).” |
| 247–249 | IEEE tone | “Đây là gap về stimulus” là khẩu ngữ kỹ thuật. | “Các trường hợp này là khoảng trống kích thích, không phải lỗi thiết kế đã quan sát.” |
| 254–257 | Tone, suy diễn | “phản ánh đúng vị trí hội tụ độ phức tạp” là đánh giá định tính từ số dòng mã. | “`flow_active` chiếm 1.794 dòng và là khối lớn nhất của phân hệ điều khiển.” |
| 278–280 | Tone | Dấu ngoặc kép quanh “đường điều khiển gọn hơn” tạo giọng tranh luận; “được đo theo cùng cách” chưa nêu lại quy tắc. | Nêu mục tiêu định lượng trực tiếp và dẫn đến bảng. |
| 302–311 | Mật độ | Biểu đồ cột sẽ lặp toàn bộ Bảng 5.x mà không bổ sung dữ liệu. | Chọn bảng hoặc biểu đồ. Với yêu cầu truy vết số liệu, bảng phù hợp hơn; chuyển biểu đồ sang phần trình bày nếu cần. |
| 313–320 | Tổ chức, câu | Đoạn trộn kết quả tỷ lệ, cảnh báo phạm vi, nguyên nhân và kết luận về khả năng bảo trì. Câu cuối suy rộng từ số dòng mã sang “tính đọc được và chi phí duy trì” mà chưa có thước đo trực tiếp. | Chia hai đoạn. Chỉ kết luận về quy mô; nếu giữ khả năng bảo trì, trình bày như giới hạn diễn giải, không như bằng chứng đã xác lập. |
| 325–328 | Súc tích | “Khép lại chương” là dẫn chuyện; “đã lập” và “tương ứng” không thêm thông tin. | “Bảng … ánh xạ F1–F10 với kết quả hồi quy và độ bao phủ.” |
| 338–346 | Thuật ngữ | Các ô trộn `correlation`, `response`, `read-end`, `register access`, `timing`, `nominal`, `cross`, `HIT`. | Chuẩn hóa tiếng Việt; giữ từ khóa/định danh trong kiểu chữ mã nguồn nếu cần. |
| 351–357 | Câu, danh sách | Một câu liệt kê toàn bộ P1–P5, dài hơn 80 từ. Câu sau tiếp tục chứa ba giới hạn. | Chuyển P1–P5 thành bảng hoặc năm câu ngắn. Tách giới hạn mô phỏng RTL thành đoạn riêng. |
| 359–363 | Dư thừa | Lặp 80/80, 411 assertion, 80,8%, bảy assertion và thiếu hậu tổng hợp đã nêu ngay trước đó. | Chỉ kết luận về mức đáp ứng và dẫn Chương 6; bỏ lặp số liệu hoặc giữ tối đa ba chỉ số cốt lõi một lần. |

### Chương 6

| Dòng | Tiêu chí | Vấn đề | Đề nghị |
|---:|---|---|---|
| 7–9 | Súc tích | Lặp mục tiêu và phạm vi đã nêu ở Chương 1; “được xác định tường minh” không cần thiết. | Rút thành một câu xác nhận mục tiêu và dẫn phạm vi. |
| 11–19 | Đoạn, câu | Một đoạn chứa kiến trúc, danh sách chức năng và so sánh quy mô. Câu 14–17 quá dài; “IP hoàn chỉnh” có sắc thái tuyệt đối trong khi phạm vi đã giới hạn. | Tách thành hai đoạn: kiến trúc/chức năng và quy mô. Đổi thành “IP trong phạm vi xác định”. |
| 12–17 | Danh sách | Liệt kê nhiều khối và giao thức trong văn xuôi; thông tin phần lớn lặp Chương 3. | Chỉ giữ kiến trúc cấp cao và các nhóm chức năng; chi tiết khối dẫn về Chương 3 hoặc chuyển thành bảng tổng kết. |
| 21–24 | Câu, thuật ngữ | Một câu có bảy thành phần môi trường; “instance checker” và “Functional Coverage” không nhất quán. | Tách thành hai câu; chuẩn hóa “145 thể hiện bộ kiểm tra SVA” và “độ bao phủ chức năng”. |
| 26–30 | Dư thừa | Lặp gần nguyên văn kết luận Chương 5: 80 test, 411 assertion, 80,8%, 19/42, F1–F10 và P1–P5. | Chương kết luận có thể nhắc ba chỉ số chính, nhưng bỏ chi tiết 19/42 và câu giải thích uncovered bin đã có ở Chương 5. |
| 32–50 | IEEE tone | Mục “Kiến thức và kỹ năng thu được” mang tính tự sự/cá nhân, ít phù hợp với cấu trúc IEEE Transactions. | Nếu quy định luận văn bắt buộc, giữ nhưng viết theo dạng “Năng lực chuyên môn được áp dụng/phát triển”; nếu không, chuyển sang phần tự đánh giá hoặc lược bỏ. |
| 35–50 | Danh sách, câu | Bốn mục dài, mỗi mục kết hợp hoạt động, kiến thức và lợi ích. | Rút mỗi mục về một năng lực và một kết quả; bỏ “khai thác có phê phán”. |
| 45–46 | Tone | “tư duy coverage-driven”, “thay vì dừng ở việc test chạy qua” mang tính hội thoại. | “áp dụng kiểm chứng hướng độ bao phủ để định lượng mức đầy đủ của kích thích.” |
| 47–49 | Thuật ngữ | `build/regression`, `coverage database`, `debug` trộn ngôn ngữ. | “xây dựng và chạy hồi quy”, “cơ sở dữ liệu độ bao phủ”, “gỡ lỗi”. |
| 55–56 | Súc tích | “được tổng hợp tại đây thành một danh sách duy nhất” là câu dẫn không có nội dung mới. | “Các hạn chế về thiết kế và bằng chứng kiểm chứng gồm:”. |
| 59–73 | Song song ngữ pháp | Các nhãn mục không cùng dạng: phạm vi, trạng thái coverage, số assertion, cấu hình, thiếu bằng chứng. | Dùng cụm danh từ song song: “Phạm vi giao thức”, “Độ bao phủ”, “Kích hoạt SVA”, “Cấu hình kiểm chứng”, “Bằng chứng hậu tổng hợp”. |
| 61–63 | Thuật ngữ, câu | “Coverage chưa closure”, “cross bậc ba”, “rà soát loại trừ có căn cứ” khó đọc. | “Độ bao phủ đạt 80,8%; phần chưa bao phủ… Cần bổ sung kịch bản và xác định các tổ hợp không khả thi.” |
| 64–66 | Logic | “checker đã sẵn sàng” mang sắc thái nhân hóa và không xác định trạng thái kỹ thuật. | “Các phép kiểm tra đã được hiện thực nhưng chưa có kích thích tương ứng.” |
| 67–70 | Câu | Một mục chứa hai hạn chế độc lập: độ sâu hàng đợi và số Target Agent. | Tách thành hai câu hoặc hai mục nếu cần ánh xạ riêng sang lộ trình. |
| 71–73 | Thuật ngữ | `synthesis`, `timing closure`, `simulation` dùng lẫn tiếng Việt. | “tổng hợp”, “khép kín định thời”, “mô phỏng RTL”. |
| 79–81 | Câu | Câu dài và chứa cả quan hệ nhân quả lẫn thứ tự ưu tiên. | Tách: “Bảng … trình bày lộ trình theo thứ tự ưu tiên. Ba hạng mục đầu…”. |
| 91–101 | Bảng | Nội dung bảng rõ hơn văn xuôi, nhưng nhiều ô chứa hai hoặc ba hành động. Hàng 6 gộp HDR và vai trò Target dù là hai mở rộng khác nhau. | Nếu không cần giới hạn sáu mức ưu tiên, tách HDR và Target role; dùng động từ nhất quán ở đầu mỗi ô. |
| 95–96 | Thuật ngữ | “Synthesis và FPGA”, “timing”, “board”, “Target I3C thật” không đồng nhất. | “Tổng hợp và thử nghiệm FPGA”; “định thời”; “bo mạch”; “Target I3C vật lý”. |
| 97–101 | Tone | “phần mở rộng giao thức tự nhiên đầu tiên”, “các thay đổi kiến trúc lớn nhất” là nhận định chủ quan. | Nêu quan hệ phụ thuộc kỹ thuật ngắn gọn hoặc bỏ định tính. |
| 106–110 | Tone, câu | “Điểm đáng lưu ý” là dẫn chuyện; câu cuối dài và chứa ba ánh xạ kiến trúc. “không đòi hỏi thay đổi RTL đáng kể” chưa định lượng. | Nêu trực tiếp rằng ba ưu tiên đầu tập trung vào bằng chứng; tách mỗi mở rộng thành một câu hoặc bảng ánh xạ. |
| 112–116 | Dư thừa, tone | “Tổng kết lại” lặp chức năng đề mục. “hiện thực gọn”, “đầy đủ ba cơ chế” mang tính đánh giá; đoạn lặp mục tiêu, cấu trúc UVM và khả năng tái lập. | Kết luận bằng một câu về kết quả và một câu về khả năng mở rộng của quy trình; dùng “quy mô 5.121 dòng” thay cho “gọn”. |

## Phân tích tổ chức đoạn và luồng lập luận

Chương 5 có trình tự tổng thể hợp lý: điều kiện đo → hồi quy → dạng sóng → độ bao phủ/SVA → quy mô → đối chiếu yêu cầu. Hai điều chỉnh nên thực hiện:

1. Đưa đoạn kiểm tra tham số `sync_fifo` (dòng 84–87) vào cuối phần điều kiện đo hoặc tạo tiểu mục bằng chứng bổ sung. Đoạn này không thuộc phân rã 80 phép thử.
2. Trong phần độ bao phủ và SVA, tách kết quả định lượng khỏi diễn giải nguyên nhân. Mỗi đoạn chỉ nên trả lời một câu hỏi: “đạt bao nhiêu?”, “chưa đạt ở đâu?”, hoặc “vì sao chưa đạt?”.

Chương 6 có trình tự phù hợp với luận văn: kết quả → năng lực → hạn chế → hướng phát triển. Tuy nhiên, mục năng lực làm gián đoạn quan hệ trực tiếp giữa kết quả và hạn chế theo văn phong bài báo IEEE. Nếu mẫu luận văn không bắt buộc mục này, nên chuyển mục đó ra sau hướng phát triển hoặc lược bỏ. Nếu bắt buộc, nên rút còn một đoạn hoặc bảng ngắn.

## Các khái niệm bị lặp và đề nghị xóa

| Khái niệm | Vị trí lặp | Xử lý đề nghị |
|---|---|---|
| 80/80 phép thử đạt | Ch. 5 dòng 56, 359–360; Ch. 6 dòng 26 | Giữ tại kết quả hồi quy và nhắc một lần trong kết luận Ch. 6; xóa ở cuối Ch. 5. |
| 411 assertion, không thất bại | Ch. 5 dòng 222–249, 360; Ch. 6 dòng 26 | Giữ bảng SVA; trong Ch. 6 chỉ ghi “không có vi phạm SVA” nếu cần. |
| Độ bao phủ 80,8% | Ch. 5 dòng 167, bảng, 359–361; Ch. 6 dòng 27, 61 | Giữ ở bảng và mục hạn chế; bỏ ở cuối Ch. 5 hoặc đầu Ch. 6 để tránh ba lần liên tiếp. |
| Bảy assertion chưa kích hoạt | Ch. 5 dòng 241–249, 362; Ch. 6 dòng 64–66 | Giữ phân tích Ch. 5 và danh sách hạn chế Ch. 6; bỏ ở kết đoạn Ch. 5. |
| Thiếu dữ liệu hậu tổng hợp | Ch. 5 dòng 355–357, 362–363; Ch. 6 dòng 71–73 | Giữ khi giới hạn P1–P5 và trong hạn chế; bỏ khỏi câu tổng hợp Ch. 5. |
| Quy mô 5.121 dòng và 13,4% | Ch. 5 dòng 254–320; Ch. 6 dòng 11, 18–19 | Giữ số tổng trong Ch. 6; không lặp chi tiết phân hệ. |
| Ba cơ chế kiểm chứng | Ch. 5 dòng 89–93, 158–160; Ch. 6 dòng 21–24, 112–115 | Giữ phần giải thích ý nghĩa PASS ở Ch. 5; Ch. 6 chỉ nêu tên ba lớp bằng chứng một lần. |

## Khuyến nghị về bảng và hình

- Chuyển ba ví dụ `covergroup` ở Chương 5 thành bảng bốn cột. Cấu trúc lặp của ba mục phù hợp với bảng hơn danh sách.
- Chuyển đối chiếu P1–P5 thành bảng ba cột: chỉ tiêu, bằng chứng, giới hạn. Cách này giảm một câu liệt kê hơn 80 từ và tăng khả năng truy vết.
- Không trình bày đồng thời bảng số dòng và biểu đồ cột dùng cùng dữ liệu. Giữ bảng trong luận văn; biểu đồ chỉ hữu ích trong slide.
- Chuyển ảnh chụp công cụ về độ bao phủ sang phụ lục nếu ảnh chỉ xác nhận số liệu đã có trong bảng.
- Giữ hai hình dạng sóng vì chúng minh họa đặc trưng khác nhau, nhưng chú thích cần nêu điểm cần quan sát thay vì chỉ tên giao dịch.

## Kết luận phản biện

Bản thảo có cấu trúc bằng chứng tốt và số liệu được truy vết rõ. Các sửa đổi cần thiết chủ yếu thuộc biên tập: rút câu ghép, loại bỏ câu dẫn chuyện, chuẩn hóa thuật ngữ Việt–Anh, phân tách kết quả khỏi diễn giải và giảm lặp giữa hai chương. Sau khi áp dụng các sửa đổi này, văn bản phù hợp hơn với nguyên tắc IEEE về tính khách quan, mật độ thông tin và khả năng kiểm tra chéo.
