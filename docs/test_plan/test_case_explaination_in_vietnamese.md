# Giải thích test case I3C bằng tiếng Việt

## Ghi chú về oracle verification

Mục tiêu của testplan là kiểm tra RTL có tuân thủ specification hay không. Vì vậy expected result của testcase phải đi từ MIPI I3C Basic v1.1.1 và các spec của project, không được lấy hành vi hiện tại của RTL làm chuẩn để test pass.

Nếu RTL khác specification, testcase phải fail hoặc ghi rõ đây là RTL/spec gap. Nếu project spec chưa định nghĩa một policy, testcase đó chỉ là clarification/negative test và không được tính là positive sign-off coverage cho đến khi expected behavior được specification hóa.

## 4.1 CSR, DAT, and Register Bus

Phần 4.1 kiểm tra lớp register của controller. Mục tiêu là đảm bảo software hoặc UVM testbench có thể cấu hình, đọc trạng thái, đưa command, đưa data, và lấy response thông qua CSR interface một cách đúng đắn. Nếu các test trong mục này fail, các test protocol I3C phía sau có thể fail do lỗi cấu hình CSR/FIFO, chứ không nhất thiết do lỗi giao tiếp trên bus SCL/SDA.

### CSR_001 - `csr_reset_defaults`

Test này kiểm tra giá trị các thanh ghi ngay sau reset.

Sau khi reset được assert và release, testbench sẽ đọc các register quan trọng như `HC_CONTROL`, `HC_STATUS`, các timing register, `QUEUE_STATUS`, và toàn bộ DAT từ `DAT[0]` đến `DAT[15]`.

Kết quả mong đợi là controller chưa được enable, FSM đang ở trạng thái idle, các queue đang empty, toàn bộ DAT entry bằng 0, và các timing register có giá trị default đúng với CSR/module spec.

Test này quan trọng vì reset là trạng thái ban đầu của toàn bộ DUT. Nếu reset default sai, các test tiếp theo có thể bắt đầu từ một trạng thái không xác định.

### CSR_002 - `csr_enable_disable`

Test này kiểm tra bit enable của controller trong `HC_CONTROL[0]`.

Testbench sẽ ghi command vào CMD queue khi controller chưa enable, sau đó mới bật enable. Khi controller đang disabled, DUT không được bắt đầu transaction trên bus. Sau khi `HC_CONTROL[0]` được set lên 1, command mới được phép chạy.

Kết quả mong đợi là không có bus transaction trước khi enable. Sau khi enable, command được thực thi và controller quay về idle khi hoàn tất.

Test này đảm bảo software có quyền kiểm soát lúc nào controller được phép hoạt động.

### CSR_003 - `csr_broadcast_addr_enable_control`

Test này kiểm tra bit `BROADCAST_ADDR_ENABLE` trong `HC_CONTROL[2]`.

Bit này chỉ điều khiển việc private I3C transfer có bắt đầu bằng broadcast header `0x7e/W` hay không. Nó không phải bit enable controller và không được tự tạo traffic trên bus.

Testbench sẽ đọc `HC_CONTROL[BROADCAST_ADDR_ENABLE]` sau reset, sau đó ghi set và clear bit này qua `HC_CONTROL`. Testbench cũng thử set riêng bit này khi `HC_CONTROL[0]` vẫn bằng 0.

Kết quả mong đợi là reset value của bit này bằng 0, software có thể ghi 1 và ghi lại 0 đúng như mong đợi, và việc set riêng `BROADCAST_ADDR_ENABLE` không làm controller enable cũng không làm phát START hay bất kỳ transaction nào trên bus.

Test này quan trọng vì nó tách rõ control-plane và protocol-plane. CSR phải lưu đúng cấu hình, nhưng bus chỉ được hoạt động khi controller được enable và có command hợp lệ.

### CSR_004 - `csr_timing_rw`

Test này kiểm tra khả năng ghi và đọc lại các timing register.

Timing register điều khiển các tham số thời gian của bus, gồm nhóm I3C `T_R`, `T_F`, `T_LOW`, `T_LOW_OD`, `T_HIGH`, `T_SU_STA`, `T_HD_STA`, `T_SU_STO`, `T_SU_DAT`, `T_HD_DAT`, `T_BUS_FREE` và nhóm I2C `I2C_T_R` tới `I2C_T_BUF`. Testbench sẽ ghi các giá trị default, 0, giá trị nhỏ hợp lệ, giá trị lớn nhất 20-bit, giá trị random hợp lệ, và giá trị có các bit reserved phía trên được set, sau đó đọc lại.

Kết quả mong đợi là 20 bit thấp `[19:0]` đọc ra đúng với giá trị đã ghi. Các bit reserved phía trên phải đọc ra 0. Sau mỗi lần ghi một timing register, các timing register còn lại cũng được đọc lại để bảo đảm không có lỗi ghi nhầm địa chỉ hoặc làm hỏng giá trị lân cận.

Test này giúp xác nhận software có thể lập trình timing cho I3C/I2C transaction và register không lưu sai các bit reserved.

### CSR_005 - `csr_dat_rw_all_entries`

Test này kiểm tra DAT, viết tắt của Device Address Table.

DAT lưu thông tin địa chỉ của các device mà controller sẽ giao tiếp. Mỗi entry có các field quan trọng như `device`, `dynamic_address`, và `static_address`. Testbench sẽ ghi các giá trị khác nhau vào `DAT[0]` đến `DAT[15]`, sau đó đọc lại từng entry.

Kết quả mong đợi là các field trong DAT khớp với encoding được định nghĩa trong CSR/DAT spec, bao gồm bit `[31]`, bits `[22:16]`, và bits `[6:0]`. Ngoài ra, ghi vào một DAT entry không được làm hỏng entry bên cạnh.

Test này quan trọng vì command chỉ chứa `dev_idx`; controller sẽ dùng `dev_idx` để đọc DAT và lấy địa chỉ device. Nếu DAT sai, command có thể đi đến sai device.

### CSR_006 - `csr_cmd_queue_2dw_staging`

Test này kiểm tra cách CSR ghép command 64-bit từ hai lần ghi 32-bit.

Register bus chỉ ghi được 32 bit mỗi lần, trong khi CMD descriptor là 64 bit. Vì vậy software phải ghi `DWORD0` trước, sau đó ghi `DWORD1`. CSR logic phải giữ tạm `DWORD0`, chờ đến khi nhận `DWORD1` thì mới push một command 64-bit vào CMD FIFO.

Kết quả mong đợi là sau khi chỉ ghi `DWORD0`, CMD FIFO chưa được push. Chỉ sau khi ghi `DWORD1`, một entry mới được push với thứ tự `{DWORD1, DWORD0}`.

Test này đảm bảo controller không chạy command nửa chừng và không đảo sai thứ tự hai DWORD.

### CSR_007 - `csr_cmd_partial_then_other_write`

Test này kiểm tra trường hợp ghi command bị chen giữa bởi các CSR write khác.

Ví dụ software ghi `DWORD0` vào `CMD_QUEUE_PORT`, sau đó ghi timing register, DAT, hoặc TX register, rồi mới ghi `DWORD1`. CSR logic vẫn phải nhớ đúng `DWORD0` ban đầu và ghép nó với `DWORD1` cuối cùng.

Kết quả mong đợi là command cuối cùng được assemble từ đúng `DWORD0` ban đầu và `DWORD1` vừa ghi. Các write xen giữa không được làm mất hoặc thay đổi staging register.

Test này bảo vệ một case thực tế trong software: software có thể cấu hình thêm register giữa hai lần ghi command.

### CSR_008 - `csr_sw_reset_flush_queues`

Test này kiểm tra software reset thông qua `HC_CONTROL[1]`.

Khi các queue đang có dữ liệu, testbench sẽ đợi controller idle, sau đó ghi `HC_CONTROL[1]=1` để yêu cầu software reset. Sau reset, testbench đọc queue status và các port liên quan.

Kết quả mong đợi là CMD, TX, RX, và RESP queue đều bị flush về empty. Bit `SW_RESET` phải tự clear, nghĩa là software không cần ghi lại 0 để xóa bit này.

Test này đảm bảo software có cách đưa controller về trạng thái sạch sau lỗi, sau timeout, hoặc trước khi chạy test mới.

### CSR_009 - `csr_sw_reset_clears_cmd_staging`

Test này kiểm tra software reset có xóa command staging register hay không.

Command staging register là nơi tạm giữ `DWORD0` trong khi chờ `DWORD1`. Nếu software ghi một `DWORD0`, sau đó assert software reset, thì `DWORD0` cũ phải bị xóa. Sau reset, khi software ghi một command mới, command mới không được bị trộn với `DWORD0` cũ.

Kết quả mong đợi là chỉ command sau reset được thực thi. Không có field nào của command cũ xuất hiện trong descriptor mới.

Test này ngăn lỗi rất nguy hiểm: stale `DWORD0` có thể làm controller chạy sai command, sai địa chỉ device, sai hướng read/write, hoặc sai data length.

### CSR_010 - `csr_queue_status_flags`

Test này kiểm tra các bit full/empty trong `QUEUE_STATUS`.

Controller có nhiều FIFO/queue: CMD, TX, RX, và RESP. Testbench sẽ fill và drain từng queue đến các trạng thái empty, non-empty, và full.

Kết quả mong đợi là `QUEUE_STATUS` phản ánh đúng trạng thái thật của từng FIFO. Khi FIFO empty thì empty flag phải set. Khi FIFO full thì full flag phải set. Khi FIFO có dữ liệu nhưng chưa full thì các flag phải đúng với trạng thái trung gian.

Test này quan trọng vì software dựa vào `QUEUE_STATUS` để biết khi nào có thể ghi command/data và khi nào có response/data để đọc.

### CSR_011 - `csr_rx_resp_read_pop`

Test này kiểm tra hành vi đọc từ `RX_DATA_PORT` và `RESP_PORT`.

`RX_DATA_PORT` dùng để software đọc data mà controller nhận được từ target trong các read transaction. `RESP_PORT` dùng để software đọc response descriptor sau khi command hoàn tất. Cả hai port này được nối với FIFO, nên mỗi lần đọc hợp lệ phải pop đúng một entry.

Ví dụ RX FIFO có hai entry:

```text
[0xAAAA_BBBB, 0xCCCC_DDDD]
```

Lần đọc đầu tiên từ `RX_DATA_PORT` phải trả về `0xAAAA_BBBB`, sau đó FIFO chỉ còn `0xCCCC_DDDD`. Lần đọc thứ hai trả về `0xCCCC_DDDD`, sau đó FIFO empty.

Nếu software tiếp tục đọc khi FIFO đã empty, DUT phải trả về 0 và không được làm hỏng FIFO pointer. Tương tự, đọc `RESP_PORT` khi có response phải pop một response; đọc khi empty phải trả về 0 và không underflow.

Kết quả mong đợi là mỗi valid read chỉ pop một entry, data/response trả về đúng thứ tự FIFO, và empty read an toàn.

### CSR_012 - `csr_unmapped_addr_no_side_effect`

Test này kiểm tra hành vi khi software đọc hoặc ghi vào địa chỉ register không tồn tại trong CSR map.

Testbench sẽ chụp lại trạng thái hiện tại của các CSR và queue, sau đó thực hiện read/write vào các địa chỉ aligned nhưng không được map vào bất kỳ register hợp lệ nào.

Kết quả mong đợi là read từ địa chỉ unmapped trả về 0. Write vào địa chỉ unmapped không được thay đổi `HC_CONTROL`, timing register, DAT, queue, command staging, hoặc bắt đầu transaction trên bus.

Ví dụ nếu `HC_CONTROL`, `DAT[0]`, và CMD FIFO đang có trạng thái xác định, sau khi ghi `0xDEADBEEF` vào một địa chỉ invalid, các trạng thái đó phải giữ nguyên.

Test này quan trọng vì software có thể truy cập nhầm địa chỉ, hoặc có bug trong driver. DUT cần xử lý truy cập invalid một cách an toàn, không tạo side effect không mong muốn.

## 4.2 FIFO and Queue Behavior

Phần 4.2 kiểm tra hành vi của FIFO và các queue trong controller.

Trong thiết kế này, nhiều luồng dữ liệu không đi trực tiếp từ software ra bus hoặc từ bus về software. Chúng đi qua các FIFO/queue như CMD queue, TX queue, RX queue, và RESP queue. Vì vậy, trước khi kiểm tra các transaction I3C phức tạp, cần chắc chắn rằng FIFO hoạt động đúng: ghi vào đúng thứ tự, đọc ra đúng thứ tự, báo full/empty đúng, flush đúng, và không bị lỗi ở các trường hợp biên.

### FIFO_001 - `fifo_basic_push_pop_order`

Test này kiểm tra chức năng cơ bản nhất của FIFO: push vào rồi pop ra phải giữ nguyên thứ tự.

FIFO hoạt động theo nguyên tắc first-in first-out. Nghĩa là data nào được ghi vào trước thì phải được đọc ra trước.

Ví dụ testbench push chuỗi data:

```text
0x1111_1111
0x2222_2222
0x3333_3333
```

Khi pop ra, thứ tự bắt buộc phải là:

```text
0x1111_1111
0x2222_2222
0x3333_3333
```

Test cũng kiểm tra các trạng thái cơ bản như empty, full, và depth. Sau reset, FIFO phải empty. Khi push data vào, depth phải tăng. Khi pop data ra, depth phải giảm. Khi pop hết, FIFO phải quay lại empty.

Test này quan trọng vì nếu FIFO đổi sai thứ tự data, command hoặc response có thể bị ghép nhầm với transaction khác.

### FIFO_002 - `fifo_full_empty_boundaries`

Test này kiểm tra các trạng thái biên của FIFO: khi FIFO vừa đầy và khi FIFO vừa rỗng.

Testbench sẽ fill FIFO đúng bằng depth của nó. Ví dụ FIFO có depth là 8 thì ghi đúng 8 entry. Sau entry thứ 8, FIFO phải báo full.

Sau đó testbench thử ghi thêm một entry nữa. Entry dư này không được ghi vào FIFO, vì FIFO đã full. Quan trọng là pointer và data bên trong FIFO không được bị hỏng.

Tiếp theo, testbench drain FIFO cho đến khi empty. Khi FIFO đã empty, testbench thử đọc thêm một lần nữa. Lần đọc dư này không được làm pointer chạy sai, không được tạo data giả, và không được làm FIFO underflow.

Kết quả mong đợi là full sẽ chặn write dư, empty sẽ chặn read dư, và trạng thái FIFO vẫn ổn định sau các thao tác biên.

### FIFO_003 - `fifo_simultaneous_read_write`

Test này kiểm tra trường hợp read và write xảy ra trong cùng một clock cycle.

Trong phần cứng, FIFO thường có thể nhận một entry mới và trả ra một entry cũ trong cùng chu kỳ, nếu cả hai handshake đều hợp lệ. Trường hợp này dễ gây bug nếu logic cập nhật pointer hoặc depth không đúng.

Testbench sẽ tạo các tình huống FIFO đang ở trạng thái:

```text
mid       : FIFO có một số entry, chưa gần full hoặc empty
near-full : FIFO gần đầy
near-empty: FIFO gần rỗng
```

Ở mỗi trạng thái, testbench assert write valid và read ready cùng lúc. FIFO phải pop entry cũ và push entry mới đúng cách.

Kết quả mong đợi là không mất data, không duplicate data, và depth được cập nhật đúng. Ví dụ nếu FIFO đang ở mức trung bình, một read và một write cùng lúc thường làm depth giữ nguyên, nhưng data bên trong phải dịch đúng theo thứ tự FIFO.

Test này quan trọng vì các queue trong controller có thể vừa được phần bus tiêu thụ vừa được software hoặc block khác nạp thêm data.

### FIFO_004 - `fifo_flush_during_activity`

Test này kiểm tra tín hiệu flush của FIFO khi FIFO đang có hoạt động.

Flush nghĩa là xóa nội dung FIFO và đưa FIFO về trạng thái empty. Trong controller, flush thường xảy ra khi software reset hoặc khi cần hủy trạng thái cũ.

Testbench sẽ chuẩn bị FIFO có data, đồng thời tạo read/write request, rồi assert `flush_i`.

Kết quả mong đợi là flush có ưu tiên rõ ràng: pointer phải được clear, FIFO phải trở về empty, và sau flush không được lộ ra entry cũ. Nếu sau đó có traffic mới, FIFO phải bắt đầu từ trạng thái empty sạch, không dùng lại data cũ trước flush.

Test này quan trọng vì nếu flush không xóa sạch FIFO, command hoặc response cũ có thể xuất hiện sau reset, gây lỗi rất khó debug.

### FIFO_005 - `fifo_non_power_of_two_elaboration`

Test này kiểm tra ràng buộc cấu hình của module `sync_fifo`.

Theo testplan, `sync_fifo` yêu cầu depth phải là power-of-two, ví dụ:

```text
2, 4, 8, 16, 32, ...
```

Các depth như 3, 5, 6, 10 không hợp lệ.

Đây là negative compile test. Nghĩa là test không chạy simulation bình thường, mà cố tình instantiate `sync_fifo` với depth không hợp lệ. Kết quả mong đợi là elaboration phải báo fatal hoặc assertion đúng như FIFO parameter contract đã định nghĩa.

Mục tiêu của test không phải là làm FIFO hoạt động với depth sai. Mục tiêu là xác nhận parameter contract của FIFO phát hiện cấu hình sai sớm, thay vì để lỗi âm thầm xuất hiện trong simulation hoặc synthesis.

Priority của test này là Low vì đây là ràng buộc cấu hình, không phải luồng chức năng runtime chính. Tuy nhiên nó vẫn hữu ích để bảo vệ người dùng RTL khỏi parameter sai.

## 4.3 PHY, Bus Conditions, and Timing

Phần 4.3 kiểm tra lớp bus/PHY và các điều kiện timing cơ bản của I3C.

Nếu 4.1 kiểm tra register và 4.2 kiểm tra FIFO, thì 4.3 kiểm tra phần DUT thật sự tương tác với hai dây bus `SCL` và `SDA`. Các test trong phần này đảm bảo controller nhìn thấy START/STOP đúng, tạo clock đúng timing, truyền/nhận bit đúng thứ tự, và chọn đúng chế độ open-drain hoặc push-pull theo từng phase.

### BUS_001 - `phy_reset_and_sync`

Test này kiểm tra reset và bộ đồng bộ 2 flip-flop trong `i3c_phy`.

Tín hiệu `SCL` và `SDA` đến từ bên ngoài DUT, nên chúng là tín hiệu bất đồng bộ so với clock nội bộ của controller. Vì vậy PHY cần dùng synchronizer để đưa các tín hiệu này vào clock domain của DUT một cách ổn định.

Testbench sẽ toggle input `SCL`/`SDA` quanh thời điểm reset, rồi quan sát tín hiệu đã sample ở phía controller.

Kết quả mong đợi là sau reset, giá trị sampled của `SCL` và `SDA` trở về mức high, vì bus idle của I3C/I2C là cả hai dây đều high. Sau vài chu kỳ latency của synchronizer, tín hiệu controller nhìn thấy phải ổn định và đúng với input.

Test này quan trọng vì nếu synchronizer sai, các block phía sau có thể phát hiện nhầm START/STOP hoặc đọc sai bit trên bus.

### BUS_002 - `bus_start_stop_detect`

Test này kiểm tra phát hiện điều kiện START và STOP trên bus.

Trong I3C/I2C, START xảy ra khi `SDA` chuyển từ high xuống low trong lúc `SCL` đang high. STOP xảy ra khi `SDA` chuyển từ low lên high trong lúc `SCL` đang high.

Testbench sẽ drive các chuyển đổi hợp lệ trên `SDA` khi `SCL` high. Module bus monitor phải tạo pulse `start_det` hoặc `stop_det` đúng lúc.

Kết quả mong đợi là `start_det` chỉ pulse cho điều kiện START hợp lệ, và `stop_det` chỉ pulse cho điều kiện STOP hợp lệ. Nếu `SDA` đổi khi `SCL` low thì không được nhận nhầm là START/STOP.

Test này liên quan đến `bus_monitor`, `edge_detector`, và `stable_high_detector`.

### BUS_003 - `bus_repeated_start_detect`

Test này kiểm tra phát hiện repeated START, thường viết là `Sr`.

Repeated START là một START mới xuất hiện khi bus đã có START trước đó nhưng chưa có STOP. Nó được dùng trong các transaction cần chuyển phase mà không thả bus, ví dụ direct CCC hoặc một số read flow.

Testbench sẽ tạo một START trước, không tạo STOP, rồi tạo thêm một START nữa. DUT phải nhận ra đây là repeated START.

Kết quả mong đợi là `rstart_det` pulse đúng, và logic không nhầm repeated START với START đầu tiên. Điều này giúp controller phân biệt mở transaction mới với chuyển phase trong cùng transaction.

### BUS_004 - `scl_start_stop_timing`

Test này kiểm tra timing khi DUT tạo START và STOP.

Các timing CSR đã được program trước. Sau đó testbench yêu cầu START/STOP qua command flow bình thường hoặc bằng control block-level.

Kết quả mong đợi là thứ tự thay đổi của `SDA` và `SCL` phải đúng định nghĩa START/STOP, đồng thời delay giữa các bước phải khớp với giá trị counter đã program trong timing register.

Ví dụ với START, `SDA` phải được kéo xuống khi `SCL` đang high, sau đó mới tiếp tục clock/data phase. Với STOP, `SDA` phải được thả lên high khi `SCL` đang high.

Test này quan trọng vì bus target sẽ dựa vào timing vật lý này để hiểu transaction.

### BUS_005 - `scl_clock_low_high_timing`

Test này kiểm tra chu kỳ low/high của clock `SCL`.

Timing register có thể được program nhiều giá trị khác nhau như `t_low`, `t_high`, `t_r`, và `t_f`. Testbench chạy cả I3C SDR và I2C legacy transfer, rồi đo thời gian `SCL` ở low và high.

Kết quả mong đợi là low/high period đo được phải bám theo các giá trị đã program. Nếu tăng `t_low`, thời gian `SCL` low phải tăng. Nếu tăng `t_high`, thời gian `SCL` high phải tăng.

Test này liên quan đến `scl_generator` và `csr_registers`, vì register lưu timing còn generator dùng timing đó để tạo clock.

### BUS_006 - `scl_waitcmd_stall_resume`

Test này kiểm tra việc stall clock khi controller phải chờ dữ liệu hoặc chờ chỗ trống trong FIFO.

Có hai tình huống chính:

```text
StallWrite: controller cần data để write nhưng TX FIFO chưa có data
StallRead : controller nhận data nhưng RX FIFO đang full hoặc chưa thể ghi thêm
```

Khi bị stall, DUT được phép giữ `SCL` low để kéo dài transaction. Sau khi điều kiện stall được gỡ, ví dụ software nạp thêm TX data hoặc drain RX FIFO, controller phải resume transaction.

Kết quả mong đợi là `SCL` được giữ low trong thời gian chờ, rồi chạy tiếp mà không tạo thêm START/STOP ngoài ý muốn và không làm hỏng data.

Test này quan trọng vì backpressure FIFO là tình huống runtime thực tế, đặc biệt khi software hoặc testbench không cấp/đọc data kịp.

### BUS_007 - `scl_repeated_start_from_waitcmd`

Test này kiểm tra khả năng tạo repeated START khi clock đang bị giữ low hoặc đang ở trạng thái wait.

Một số flow như ENTDAA hoặc directed CCC có thể cần repeated START giữa các phase. Nếu lúc đó generator đang ở low/wait state, logic vẫn phải tạo `Sr` đúng timing và không treo bus.

Testbench sẽ đưa controller vào flow ENTDAA hoặc directed CCC, sau đó yêu cầu repeated START trong lúc generator đang ở trạng thái low/wait.

Kết quả mong đợi là repeated START được tạo hợp lệ, timing đúng, và controller không bị kẹt ở trạng thái chờ.

### BUS_008 - `bus_tx_byte_and_bit_order`

Test này kiểm tra thứ tự bit khi DUT truyền data ra bus.

Trong I3C/I2C, byte được truyền MSB-first, nghĩa là bit 7 đi trước, sau đó bit 6, ..., cuối cùng là bit 0.

Testbench sẽ gửi các pattern dễ quan sát:

```text
00, FF, A5, 5A
```

Các pattern `A5` và `5A` hữu ích vì bit 1/0 xen kẽ, giúp phát hiện lỗi đảo bit hoặc dịch sai thứ tự.

Kết quả mong đợi là `bus_tx` serialize byte theo MSB-first. Với mỗi request truyền byte hoặc truyền bit đơn, `bus_tx_done_o` chỉ pulse một lần khi hoàn tất. Timing setup/hold của `SDA` so với `SCL` cũng phải đúng.

### BUS_009 - `bus_rx_byte_and_bit_order`

Test này kiểm tra thứ tự bit khi DUT nhận data từ bus.

Device model hoặc block-level stimulus sẽ drive `SDA` với các byte pattern và ACK/NACK bit. DUT phải deserialize các bit nhận được thành byte đúng theo MSB-first.

Ví dụ nếu target drive byte `8'hA5`, DUT phải reconstruct đúng `8'hA5`, không được thành `8'h5A` hoặc giá trị bị đảo bit.

Với single-bit read như ACK/NACK hoặc T-bit, testplan yêu cầu bit đọc được nằm ở `bit[0]`. Ngoài ra mutual exclusion SVA phải pass, nghĩa là logic không được vừa read byte vừa read bit theo cách xung đột.

### BUS_010 - `od_pp_phase_switch`

Test này kiểm tra việc chọn chế độ open-drain hoặc push-pull theo từng phase của transaction.

I3C dùng cả hai kiểu drive bus:

```text
OD: open-drain, an toàn cho address/ACK/START/STOP và arbitration
PP: push-pull, nhanh hơn, dùng cho một số data phase của I3C SDR
```

Testbench sẽ chạy I3C write/read transfer và quan sát `sel_od_pp_o` qua các phase như START, address, ACK, data, T-bit, và STOP.

Kết quả mong đợi là OD được dùng cho START/address/ACK/STOP và ENTDAA. PP chỉ được dùng ở các data phase I3C SDR nằm trong scope được project spec định nghĩa.

Test này quan trọng vì chọn sai OD/PP có thể gây xung đột điện trên bus hoặc làm sai behavior so với protocol.

### BUS_011 - `tb_pad_model_odpp_wiring`

Test này kiểm tra pad model trong testbench sau khi DUT đã có `sda_oe_o` và `sel_od_pp_o`.

`sel_od_pp_o` cho biết bus đang ở mode open-drain hay push-pull. `sda_oe_o` cho biết DUT có đang thật sự drive SDA hay không. Hai signal này khác nhau và đều cần thiết để testbench model SDA đúng.

Testbench sẽ quan sát `sda_oe_o`, `sda_o`, `sel_od_pp_o`, và `sda_bus` trong các transaction I3C write/read hiện có.

Kết quả mong đợi là `tb_i3c_top` chỉ drive SDA khi `sda_oe_o=1`. Khi `sda_oe_o=0`, testbench phải release SDA về `Z` để pull-up hoặc target có thể điều khiển bus.

Ví dụ trong I3C write data phase, DUT có thể dùng push-pull và drive SDA trực tiếp. Nhưng trong I3C read data phase, target là bên drive data, nên DUT phải release SDA dù data phase đang là push-pull.

Test này quan trọng vì nếu pad model drive SDA sai thời điểm, simulation có thể che mất lỗi thật hoặc tạo contention giả trên bus.

## 4.4 I3C SDR Private Write

Phần 4.4 kiểm tra I3C SDR private write, nghĩa là controller ghi data đến một I3C target thông qua dynamic address trong DAT.

Các test trong phần này tập trung vào regular write path: command được lấy từ CMD FIFO, data được lấy từ TX FIFO, controller phát địa chỉ private I3C, truyền các byte data, tạo T-bit, rồi ghi response vào RESP FIFO. Với `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0`, transfer bắt đầu trực tiếp bằng `dynamic_address + W`. Với bit này bằng 1, transfer private mới phải có preamble `0x7e/W + ACK + Sr` trước khi phát dynamic address.

### SDRW_001 - `i3c_regular_write_4b_existing`

DAT[0] được cấu hình là I3C device với dynamic address `0x08`, `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0`. Target ACK địa chỉ và ACK các phase cần thiết. Testbench chạy `i3c_write_vseq` với TX word `32'hDEAD_BEEF`.

Kết quả mong đợi là controller phát transaction write bắt đầu trực tiếp bằng `START + 0x08/W + ACK`, không được phát `0x7e` preamble. Bốn byte data được lấy từ TX word theo packing contract của TX FIFO trong project spec.

RESP trả về phải là success và length bằng 4. Test này quan trọng vì đây là baseline để biết regular I3C write path vẫn tuân thủ spec sau các thay đổi khác.

### SDRW_002 - `i3c_write_broadcast_header_enabled`

Test này kiểm tra private I3C write khi `HC_CONTROL[BROADCAST_ADDR_ENABLE]=1`.

DAT[0] vẫn là I3C target có dynamic address `0x08`. Khác với baseline `SDRW_001`, controller không được bắt đầu ngay bằng `0x08/W`. Thay vào đó, controller phải phát broadcast header preamble để thông báo một private transfer sắp bắt đầu.

Testbench issue một regular write 4 byte với TX data đã biết. Device model phải ACK broadcast header `0x7e/W`, sau đó ACK dynamic address `0x08/W`.

Kết quả mong đợi trên bus là đúng thứ tự: `START + 0x7e/W + ACK + Sr + 0x08/W + ACK + data/T-bit + STOP`. Monitor và scoreboard phải xem toàn bộ preamble cộng target phase là một transaction đầy đủ, không tách `0x7e` thành một transaction rỗng riêng.

Test này quan trọng vì `BROADCAST_ADDR_ENABLE` thay đổi first-address behavior của private I3C transfer. Nó cũng kiểm tra monitor/scoreboard có hiểu flow `0x7e + Sr + target` hay không.

### SDRW_003 - `i3c_regular_write_len_sweep`

Test này kiểm tra nhiều độ dài write khác nhau và cách TX FIFO được pack thành byte trên bus.

Testbench sẽ chạy các length như 1, 2, 3, 4, 5, 7, 8, và 16 byte. Data trong TX FIFO dùng pattern dễ kiểm tra để biết byte nào phải xuất hiện trên bus trước.

Kết quả mong đợi là controller truyền đúng số byte được yêu cầu, không thiếu byte và không dư byte. Với các length không chia hết cho 4, byte cuối cùng vẫn phải lấy đúng từ DWORD tương ứng trong TX FIFO.

RESP length phải bằng số byte thật sự đã truyền. Test này quan trọng vì lỗi ở boundary DWORD rất dễ xảy ra khi data length là 1, 2, 3, 5, hoặc 7 byte.

### SDRW_004 - `i3c_regular_write_data_patterns`

Test này kiểm tra data integrity của write path với nhiều pattern khác nhau.

Testbench sẽ gửi các pattern như toàn 0, toàn 1, walking-one, alternating, và random data. Target hoặc monitor sẽ quan sát byte xuất hiện trên bus.

Kết quả mong đợi là dữ liệu target thấy trên bus phải khớp chính xác với dữ liệu đã nạp vào TX FIFO. Không được đảo bit, đảo byte, mất byte, hoặc lặp lại byte cũ.

Test này giúp phát hiện lỗi trong `bus_tx_flow`, byte ordering, và scoreboard expectation.

### SDRW_005 - `i3c_write_tbit_parity_generation`

Test này kiểm tra T-bit trong I3C SDR write.

Trong I3C SDR write, sau mỗi data byte controller cần gửi thêm T-bit. Theo MIPI I3C SDR semantics, T-bit của controller write là odd parity trên data byte; trong SystemVerilog có thể tính bằng `~^data_byte`.

Testbench sẽ gửi các data byte có parity chẵn và parity lẻ, rồi bus monitor sample T-bit sau từng byte.

Kết quả mong đợi là T-bit trên bus luôn làm tổng số bit 1 của `{data_byte, T-bit}` là lẻ, tương đương giá trị `~^data_byte`. Nếu data byte thay đổi parity, T-bit cũng phải thay đổi tương ứng.

Test này quan trọng vì target dùng T-bit để kiểm tra/đồng bộ data phase. Nếu T-bit sai, data byte có thể đúng nhưng transaction vẫn sai protocol.

### SDRW_006 - `i3c_write_addr_nack`

Test này kiểm tra phản ứng của controller khi target NACK địa chỉ trong regular write.

Target được cấu hình để không ACK dynamic address. Testbench issue một regular write command như bình thường.

Kết quả mong đợi là controller dừng transaction trước data phase, nghĩa là không được lấy và truyền data byte từ TX FIFO ra bus sau khi địa chỉ bị NACK.

Controller phải recover bus bằng STOP hoặc recovery sequence tương ứng, sau đó ghi RESP với error `AddrHeader`.

Test này quan trọng vì address NACK là lỗi cơ bản nhất khi target không tồn tại, chưa sẵn sàng, hoặc địa chỉ trong DAT bị sai.

### SDRW_007 - `i3c_write_tx_fifo_empty_stall`

Test này kiểm tra trường hợp controller cần write data nhưng TX FIFO chưa có đủ data.

Testbench issue một write command có length lớn hơn lượng data ban đầu trong TX FIFO. Sau đó testbench delay một khoảng thời gian rồi mới nạp thêm TX data.

Khi thiếu data, controller không được truyền byte rác hoặc đọc underflow từ TX FIFO. Thay vào đó controller phải stall an toàn, thường bằng cách giữ `SCL` low trong lúc chờ data.

Kết quả mong đợi là sau khi TX data được nạp thêm, controller resume transaction và tiếp tục truyền đúng byte tiếp theo. Data trên bus không bị corrupt và RESP cuối cùng vẫn đúng với số byte đã truyền.

Test này quan trọng vì software có thể cấp TX data chậm hơn tốc độ controller tiêu thụ.

### SDRW_008 - `i3c_write_toc_zero`

Test này kiểm tra behavior continuation của regular SDR I3C write khi command đầu tiên có `toc=0`.

`toc` là bit "terminate on completion". Với `toc=1`, controller kết thúc transfer bằng STOP. Với `toc=0`, project descriptor spec định nghĩa continuation cho SDR regular I3C transfer: controller không tạo STOP sau byte data cuối cùng, mà tạo Repeated START (`Sr`) để nối sang command regular SDR I3C tiếp theo đang có sẵn trong CMD FIFO.

Testbench queue hai regular write command đến cùng I3C target. Command thứ nhất có `toc=0`, length 2 byte. Command thứ hai có `toc=1`, length 2 byte. Cả hai command đều được queue trước khi transaction đầu tiên kết thúc để controller có thể tạo continuation ngay tại boundary sau T-bit cuối cùng.

Kết quả mong đợi trên bus là command thứ nhất truyền address, ACK, data bytes và T-bit bình thường, sau đó tạo `Sr` thay vì STOP. Ngay sau `Sr`, controller phát address cho command thứ hai, tiếp tục truyền data của command thứ hai, rồi chỉ tạo STOP ở cuối command thứ hai vì command này có `toc=1`.

RESP của cả hai command phải báo Success, TID phải khớp từng command, và length phải bằng số byte đã truyền. Bus không được idle giữa command thứ nhất và command thứ hai; idle chỉ được quan sát sau STOP cuối cùng.

Test này quan trọng vì `toc=0` ảnh hưởng trực tiếp đến ownership của bus và sequencing giữa nhiều SDR private transfer trong cùng một frame. Nếu controller tạo STOP quá sớm, transfer bị tách frame sai. Nếu controller không tạo được `Sr` hoặc không lấy command kế tiếp đúng lúc, continuation flow sẽ sai so với semantics đã specification hóa.

### SDRW_009 - `i3c_write_toc_zero_broadcast_header_once`

Test này kiểm tra interaction giữa `BROADCAST_ADDR_ENABLE=1` và continuation bằng `toc=0` trong private I3C write.

Khi command đầu tiên là một private I3C transfer mới, controller phải phát preamble `START + 0x7e/W + ACK + Sr`, rồi mới phát dynamic address của target. Nhưng khi command đó kết thúc với `toc=0`, repeated START tiếp theo vẫn là continuation của cùng một private sequence. Vì vậy controller không được phát lại một broadcast header `0x7e` thứ hai trước command continuation.

Testbench queue hai regular write command. Command đầu tiên có `toc=0`, command thứ hai có `toc=1`, và `HC_CONTROL[BROADCAST_ADDR_ENABLE]=1`.

Kết quả mong đợi là command đầu tiên có broadcast-header preamble một lần duy nhất. Sau data/T-bit của command đầu tiên, controller tạo `Sr` rồi đi thẳng đến dynamic address của command thứ hai. Không được có chuỗi `0x7e/W + ACK + Sr` thứ hai trước khi STOP cuối cùng xảy ra.

Test này quan trọng vì nếu controller phát lại `0x7e` ở mỗi continuation, bus frame sẽ sai semantics. Preamble chỉ được phát cho private transfer mới sau STOP, không phải cho từng command nối bằng repeated START.

### SDRW_010 - `i3c_write_back_to_back`

Test này kiểm tra nhiều regular write command chạy liên tiếp.

Testbench queue nhiều write command với TID khác nhau và data khác nhau trong TX FIFO. Các command phải được thực thi theo đúng thứ tự FIFO.

Kết quả mong đợi là command đầu tiên dùng đúng data đầu tiên, command thứ hai dùng đúng data tiếp theo, và cứ tiếp tục như vậy. Không được có stale TX data từ command trước rơi sang command sau.

Mỗi RESP phải có TID và length khớp với command tương ứng. Scoreboard phải match đúng thứ tự command/response.

Test này quan trọng vì hệ thống thực tế thường không chỉ chạy một command đơn lẻ. Back-to-back command giúp phát hiện lỗi state cleanup, FIFO pointer, và response ordering.

## 4.5 I3C SDR Private Read

Phần 4.5 kiểm tra I3C SDR private read, nghĩa là controller đọc data từ một I3C target thông qua dynamic address trong DAT.

Các test trong phần này tập trung vào regular read path: command được lấy từ CMD FIFO, controller phát địa chỉ private I3C, nhận các byte data do target drive trên bus, xử lý T-bit của read phase, pack data vào RX FIFO, rồi ghi response vào RESP FIFO. Tương tự write path, `BROADCAST_ADDR_ENABLE=0` nghĩa là bắt đầu trực tiếp bằng dynamic address; `BROADCAST_ADDR_ENABLE=1` nghĩa là private transfer mới bắt đầu bằng `0x7e/W + ACK + Sr` rồi mới tới dynamic address với direction read.

### SDRR_001 - `i3c_regular_read_4b_existing`

Test này giữ lại regression read hiện có.

DAT[0] được cấu hình là I3C device với dynamic address `0x08`, `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0`. Target ACK địa chỉ read và trả về bốn byte data. Testbench chạy `i3c_read_vseq`.

Kết quả mong đợi là controller thực hiện transaction read bắt đầu trực tiếp bằng `START + 0x08/R + ACK`, không phát `0x7e` preamble. Bốn byte nhận được được pack vào RX FIFO theo packing contract của RX FIFO trong project spec.

RX FIFO word mong đợi là `32'hBEBA_FECA`, và RESP trả về phải là success với length bằng 4.

Test này quan trọng vì đây là baseline để biết regular I3C read path vẫn tuân thủ spec, bao gồm address phase, data receive phase, RX FIFO packing, và response generation.

### SDRR_002 - `i3c_read_broadcast_header_enabled`

Test này kiểm tra private I3C read khi `HC_CONTROL[BROADCAST_ADDR_ENABLE]=1`.

Với read, broadcast-header preamble vẫn dùng direction write cho reserved address `0x7e/W`, vì đây là header để mở private transfer. Sau ACK của broadcast header, controller phải tạo repeated START rồi mới phát dynamic address của target với direction read.

DAT[0] chứa dynamic address `0x08`. Target ACK broadcast header, ACK `0x08/R`, sau đó drive bốn byte read data theo sequence đã cấu hình.

Kết quả mong đợi trên bus là `START + 0x7e/W + ACK + Sr + 0x08/R + ACK + read data/T-bit + STOP`. RX FIFO phải chứa đúng data target trả về, RESP length phải khớp số byte đọc, và scoreboard phải xem preamble cộng target phase là một transaction đầy đủ.

Test này quan trọng vì read path có cả address sequencing, target-driven data, T-bit read semantics, và RX FIFO packing. Nếu monitor tách `0x7e` thành transaction riêng, scoreboard có thể báo sai hoặc bỏ sót lỗi thật.

### SDRR_003 - `i3c_regular_read_len_sweep`

Test này kiểm tra nhiều độ dài read khác nhau và cách RX FIFO pack byte thành DWORD.

Target được cấu hình để trả đủ số byte mà controller yêu cầu. Testbench sẽ chạy các length như 1, 2, 3, 4, 5, 7, 8, và 16 byte.

Kết quả mong đợi là RX FIFO chứa đúng toàn bộ byte target đã trả về, theo thứ tự little-endian DWORD packing. Với các length không chia hết cho 4, DWORD cuối cùng là partial DWORD và vẫn phải giữ đúng các byte hợp lệ.

Ví dụ nếu read 3 byte, controller không được đợi đủ 4 byte mới ghi RX FIFO, cũng không được làm mất byte cuối cùng. Nếu read 5 byte, byte thứ 5 phải nằm trong DWORD tiếp theo đúng vị trí.

Test này quan trọng vì lỗi partial DWORD rất dễ xảy ra ở read path, đặc biệt khi length là 1, 2, 3, 5, hoặc 7 byte.

### SDRR_004 - `i3c_read_short_target_end`

Test này kiểm tra trường hợp target kết thúc read sớm hơn số byte controller yêu cầu.

Testbench request đọc `N` byte, nhưng target chỉ trả `M` byte với `M < N`, sau đó dùng T-bit để báo end trước thời điểm controller mong đợi.

Kết quả mong đợi là controller không được tiếp tục lấy thêm data giả. RX FIFO chỉ chứa đúng `M` byte đã thật sự nhận được từ target.

RESP phải báo error `I3cShortReadErr`, vì transaction kết thúc ngắn hơn requested length.

Test này quan trọng vì trong giao tiếp thực tế, target có thể không có đủ data hoặc chủ động kết thúc transfer. Controller phải report lỗi đúng và không được corrupt RX FIFO.

### SDRR_005 - `i3c_read_target_more_than_requested`

Test này kiểm tra trường hợp target vẫn muốn gửi tiếp data sau khi controller đã nhận đủ số byte yêu cầu.

Testbench request đọc `N` byte, trong khi target model được cấu hình như thể còn data để gửi tiếp và T-bit vẫn chỉ continuation sau byte thứ `N`.

Kết quả mong đợi là controller phải dừng đúng sau `N` byte. Nếu `toc=1`, controller tạo STOP để kết thúc transaction. Không được ghi thêm byte thứ `N+1` vào RX FIFO.

Nói cách khác, requested length của command là giới hạn mà controller phải tôn trọng, kể cả khi target còn có thể cung cấp thêm data.

Test này quan trọng vì nếu controller đọc dư byte, RX FIFO sẽ chứa data ngoài mong muốn và response length sẽ không còn khớp với command.

### SDRR_006 - `i3c_read_addr_nack`

Test này kiểm tra phản ứng của controller khi target NACK địa chỉ trong regular read.

Target được cấu hình để không ACK dynamic address với direction read. Testbench issue một regular read command như bình thường.

Kết quả mong đợi là controller không được đi vào data phase, không được ghi bất kỳ data nào vào RX FIFO, và phải recover bus về trạng thái hợp lệ.

RESP phải báo error `AddrHeader`, vì lỗi xảy ra ở address/header phase.

Test này quan trọng vì address NACK có thể xảy ra khi target không tồn tại, dynamic address trong DAT sai, hoặc target chưa sẵn sàng trả lời read.

### SDRR_007 - `i3c_read_rx_fifo_full_stall`

Test này kiểm tra backpressure khi controller đang read nhưng RX FIFO không còn chỗ để ghi data.

Trước khi hoặc trong lúc read, testbench làm RX FIFO full tại thời điểm controller cần flush data nhận được vào FIFO. Sau đó testbench drain RX FIFO để tạo chỗ trống.

Khi RX FIFO full, controller không được làm mất data đã nhận, không được ghi tràn FIFO, và không được làm transaction bị corrupt. Controller phải stall an toàn, thường bằng cách giữ `SCL` low cho đến khi có thể tiếp tục.

Kết quả mong đợi là sau khi RX FIFO được drain, controller resume và ghi data đúng thứ tự. Không có byte nào bị mất hoặc bị duplicate.

Test này quan trọng vì software có thể đọc RX FIFO chậm hơn tốc độ controller nhận data từ bus.

### SDRR_008 - `i3c_read_data_patterns`

Test này kiểm tra data integrity của read path với nhiều pattern khác nhau.

Target sequence sẽ drive các pattern như toàn 0, toàn 1, alternating, walking-one, và random byte pattern. Controller nhận data từ bus và ghi vào RX FIFO.

Kết quả mong đợi là nội dung RX FIFO phải khớp chính xác với data target đã drive. Không được đảo bit, đảo byte, mất byte, duplicate byte, hoặc lẫn data từ transaction trước.

Test này giúp phát hiện lỗi trong `i3c_driver`, `bus_rx_flow`, byte ordering, RX FIFO packing, và scoreboard expectation.

### SDRR_009 - `i3c_read_no_parity_error_on_end_tbit`

Test này kiểm tra ý nghĩa của T-bit trong I3C SDR read.

Trong read phase, T-bit do target gửi không phải parity của data byte. Theo MIPI I3C SDR read semantics, khi target gửi T-bit bằng 0 thì đó là tín hiệu end-of-data.

Testbench chạy một read transaction trong đó final T-bit bằng 0.

Kết quả mong đợi là controller không báo `Parity` response chỉ vì final T-bit bằng 0. Nếu transfer kết thúc sớm hơn requested length thì lỗi phù hợp là short read; nếu kết thúc đúng theo expected behavior thì response không được là parity error.

Test này quan trọng vì nếu controller diễn giải sai T-bit read phase thành parity error, các read transaction hợp lệ hoặc short-read hợp lệ sẽ bị báo sai nguyên nhân lỗi.

### SDRR_010 - `i3c_read_toc_zero`

Test này kiểm tra behavior continuation của regular SDR I3C read khi command đầu tiên có `toc=0`.

Trong scope project hiện tại, `toc=0` continuation được định nghĩa cho SDR regular I3C private transfer, bao gồm cả write và read. Vì vậy read path cũng cần test riêng, không chỉ dựa vào `SDRW_007`.

Testbench queue hai command đến cùng I3C target. Command thứ nhất là regular read với `toc=0`, length 2 byte. Target trả về hai byte hợp lệ và T-bit cuối báo kết thúc đúng tại requested length. Command thứ hai là regular write với `toc=1`, length 2 byte, và command này đã nằm sẵn trong CMD FIFO trước khi read đầu tiên kết thúc.

Kết quả mong đợi là controller nhận đúng hai byte read, ghi đúng vào RX FIFO, rồi tạo Repeated START (`Sr`) thay vì STOP sau T-bit cuối của read command. Ngay sau `Sr`, controller phát address cho write command thứ hai, truyền data của command thứ hai, và chỉ tạo STOP ở cuối command thứ hai vì command này có `toc=1`.

RESP của read command phải báo Success với TID và length đúng. RESP của write command cũng phải báo Success với TID và length đúng. Bus không được idle hoặc tạo STOP giữa read đầu tiên và write thứ hai; boundary hợp lệ giữa hai command là `Sr`.

Test này quan trọng vì read termination có thêm RX FIFO packing và T-bit semantics, nên không thể chỉ dùng write `toc=0` để kết luận read continuation đã đúng. Nếu controller flush RX data sai thời điểm, tạo STOP quá sớm, hoặc không tạo được `Sr`, response và bus sequencing đều có thể sai.

### SDRR_011 - `i3c_read_toc_zero_broadcast_header_once`

Test này kiểm tra private I3C read continuation khi `BROADCAST_ADDR_ENABLE=1`.

Command đầu tiên là một private read mới, nên controller phải phát broadcast-header preamble một lần: `START + 0x7e/W + ACK + Sr`, rồi tới dynamic address với direction read. Sau khi read command đầu tiên kết thúc với `toc=0`, repeated START tiếp theo là continuation của cùng private sequence, không phải private sequence mới.

Testbench queue command read đầu tiên với `toc=0` và command thứ hai với `toc=1`. Target trả data hợp lệ cho read command đầu tiên.

Kết quả mong đợi là chỉ command đầu tiên có `0x7e` preamble. Sau data/T-bit của read đầu tiên, controller tạo `Sr` rồi tiếp tục command kế tiếp mà không phát lại `0x7e/W`. RX FIFO phải chứa đúng data read, và RESP của cả hai command phải đúng TID/length.

Test này quan trọng vì nó bắt lỗi state `continuation pending`. Nếu controller quên rằng bus chưa có STOP, nó có thể phát lại broadcast header và làm frame sai. Nếu controller giữ state quá lâu sau STOP, transfer kế tiếp lại có thể thiếu preamble.

## 4.6 Immediate Data Transfer

Phần 4.6 kiểm tra immediate data transfer, nghĩa là data payload được nhúng trực tiếp trong command descriptor thay vì lấy từ TX FIFO.

Trong thiết kế này, immediate path chủ yếu áp dụng cho write-style command. Controller đọc command từ CMD FIFO, decode các field immediate như `dtt`, lấy inline data từ chính descriptor, phát địa chỉ target, truyền data byte ra bus, rồi ghi response vào RESP FIFO. Vì data không đi qua TX FIFO, các test trong phần này cần kiểm tra rõ rằng controller không đọc nhầm TX FIFO và vẫn xử lý address, STOP, NACK, và device type đúng.

### IMM_001 - `i3c_immediate_write_smoke_existing`

Test này giữ lại smoke regression hiện có cho I3C immediate write.

DAT[0] được cấu hình là I3C device, target ACK địa chỉ và các phase cần thiết. Testbench chạy `i3c_smoke_vseq`, trong đó command immediate chứa hai byte data inline.

Kết quả mong đợi là controller truyền đúng hai byte inline đó ra bus, không cần lấy data từ TX FIFO. Sau khi transaction hoàn tất, RESP phải báo success.

Test này quan trọng vì đây là baseline đơn giản nhất để xác nhận immediate command path vẫn hoạt động sau các thay đổi ở `flow_active`, command decode, hoặc bus transmit logic.

### IMM_002 - `i3c_immediate_write_dtt_sweep`

Test này kiểm tra field `dtt`, tức số byte inline data trong immediate command.

Testbench issue nhiều immediate command với các giá trị `dtt` đại diện cho 0 đến 4 byte hợp lệ. DAT[0] vẫn là I3C device và target ACK bình thường.

Kết quả mong đợi là controller truyền đúng số byte tương ứng với `dtt`. Nếu `dtt` chỉ ra 1 byte thì chỉ một byte được truyền; nếu `dtt` chỉ ra 4 byte thì bốn byte inline được truyền.

TX FIFO không được bị đọc trong các immediate transfer này. Queue status và TX FIFO content phải cho thấy immediate path dùng data trong descriptor, không tiêu thụ data chuẩn bị cho regular write.

Test này quan trọng vì lỗi decode `dtt` có thể làm controller truyền thiếu byte, dư byte, hoặc lấy nhầm data từ TX FIFO.

### IMM_003 - `i3c_immediate_write_toc`

Test này kiểm tra bit `toc` trong immediate write.

Immediate Data Transfer descriptor vẫn có field `toc`, nên testplan cần kiểm tra controller xử lý field này ra sao. Tuy nhiên, project descriptor spec hiện chưa định nghĩa continuation hợp lệ bằng Repeated START (`Sr`) cho immediate command như regular SDR private transfer.

Với `toc=1`, kết quả mong đợi là controller tạo STOP ở cuối immediate transfer và RESP báo success nếu các phase trước đó đều hợp lệ.

Với `toc=0`, test không nên tự suy ra một continuation hợp lệ như `SDRW_007`. Đây là clarification/negative case cho đến khi project spec định nghĩa policy. Policy được chấp nhận cho sign-off phải là một hành vi rõ ràng như reject/abort với error response hoặc force STOP; điểm quan trọng là controller không được để bus treo ở trạng thái không có STOP cũng không có `Sr`, và không được tự ý nối sang command kế tiếp bằng waveform sai.

Test này quan trọng vì `toc` xuất hiện trong descriptor immediate, nhưng MIPI I3C spec chỉ định bus-level START, Repeated START và STOP, không định nghĩa trực tiếp khái niệm Immediate descriptor. Vì vậy test này dùng để khóa policy của project spec, còn test chứng minh `toc=0` continuation hợp lệ nằm ở regular SDR private transfer.

### IMM_004 - `i2c_immediate_write_basic`

Test này kiểm tra immediate path khi DAT entry là legacy I2C device.

DAT[0].`device` được set bằng 1 và static address được program. Testbench issue I2C immediate write với độ dài từ 1 đến 4 byte.

Kết quả mong đợi là controller dùng static address với direction write, không dùng dynamic address của I3C. Toàn bộ transaction phải chạy ở open-drain mode theo I2C legacy semantics.

Target ACK địa chỉ và các data byte. RESP length phải bằng đúng số byte đã truyền, và response phải là success.

Test này quan trọng vì cùng một immediate command path có thể phục vụ cả I3C và I2C tùy theo DAT. Nếu decode device type sai, controller có thể dùng sai địa chỉ hoặc sai OD/PP mode.

### IMM_005 - `immediate_addr_nack`

Test này kiểm tra lỗi address NACK trong immediate transfer.

Target được cấu hình để NACK địa chỉ ngay tại ACK/NACK slot sau address byte. Testbench issue cả I3C immediate write và I2C immediate write để kiểm tra hai loại device: I3C dùng `dynamic_address + W`, còn I2C legacy dùng `static_address + W`.

Kết quả mong đợi là controller phát hiện `addr_nack` sau khi sample ACK/NACK bit của address phase, rồi tạo STOP để kết thúc transaction. Controller không được đi tiếp vào data phase, nên không có byte inline nào trong command descriptor được truyền ra bus sau address NACK.

RESP phải báo error `AddrHeader`. Vì lỗi xảy ra trước data phase, response length phải là 0; address byte không được tính là data payload. Sau STOP, bus phải quay về idle hoặc recovery state hợp lệ, không được bị treo.

Test này quan trọng vì immediate data nằm sẵn trong descriptor, nên nếu controller không chặn đúng sau address NACK, nó có thể vẫn truyền inline data dù target không tồn tại hoặc không chấp nhận transaction.

### IMM_006 - `immediate_data_nack_i2c`

Test này kiểm tra trường hợp I2C target ACK địa chỉ nhưng NACK một data byte trong immediate write.

DAT entry được cấu hình là I2C legacy device. Testbench issue một multi-byte I2C immediate write. Target ACK address phase, ACK một số byte đầu nếu cần, rồi NACK một data byte cụ thể.

Kết quả mong đợi là controller phát hiện data NACK ngay sau ACK/NACK slot của data byte bị từ chối. Controller phải tạo STOP để kết thúc I2C immediate transaction, rồi ghi RESP error `Nack`.

Controller không được tiếp tục truyền các byte inline còn lại như thể target vẫn ACK bình thường. Data byte bị NACK vẫn đã được clock ra bus đủ 8 bit trước khi ACK/NACK slot được sample, nên response length có thể tính byte đó là byte đã truyền; nhưng các byte sau vị trí NACK không được xuất hiện trên bus.

Test này quan trọng vì I2C data ACK/NACK là cơ chế flow/error cơ bản. Immediate path lấy payload trực tiếp từ command descriptor, nên nếu controller không chặn đúng sau data NACK thì controller có thể tiếp tục phát hết inline data dù target đã từ chối byte trước đó.

## 4.7 Common Command Codes

Phần 4.7 kiểm tra Common Command Codes, thường viết là CCC.

CCC là cơ chế để controller gửi các command chuẩn đến một hoặc nhiều I3C target. Trong phạm vi feature scope hiện tại, các flow quan trọng gồm ENTDAA opening frame, broadcast ENEC/DISEC, direct ENEC/DISEC, xử lý NACK trong CCC frame, và chính sách đối với opcode chưa được hỗ trợ rõ.

Các test trong phần này không chỉ kiểm tra data byte, mà còn kiểm tra đúng cấu trúc frame trên bus: START, broadcast address `7'h7E`, bit direction, broadcast-header ACK, CCC opcode kèm T-bit, repeated START cho direct CCC, target dynamic address, address ACK/NACK, data byte nếu có, T-bit, STOP, và RESP.

### CCC_001 - `ccc_entdaa_opening_frame`

Test này kiểm tra phần mở đầu của ENTDAA CCC.

ENTDAA là command dùng để bắt đầu Dynamic Address Assignment. Trước khi vào các vòng ENTDAA thật sự, controller phải phát broadcast frame đúng: START, broadcast address `7'h7E` với direction write, broadcast-header ACK, sau đó gửi CCC opcode `8'h07` kèm T-bit odd parity.

Testbench queue một `AddressAssignment` command với `cmd=0x07`. Device model ACK broadcast header.

Kết quả mong đợi là bus monitor thấy đúng frame mở đầu: START, `7'h7E+W`, broadcast-header ACK, `8'h07`, T-bit odd parity. Sau đó controller mới chuyển sang các ENTDAA round bắt đầu bằng `7'h7E+R`.

Test này quan trọng vì nếu opening frame sai, các target sẽ không hiểu controller đang bắt đầu ENTDAA, dù phần `entdaa_controller` phía sau có thể hoạt động đúng.

### CCC_002 - `ccc_broadcast_enec_frame`

Test này kiểm tra broadcast ENEC frame theo MIPI broadcast CCC format và descriptor convention của project.

ENEC là CCC dùng để enable một số event từ target. Broadcast ENEC được phát qua immediate command với `cp=1` và `cmd=8'h00`. Target chỉ ACK broadcast header `7'h7E+W`; sau byte CCC và event byte không có ACK từ target.

Testbench gửi Target Events byte trong `def_or_data_byte1` theo descriptor convention đã document. Controller phải phát broadcast CCC frame đúng với ENEC opcode `8'h00`.

Kết quả mong đợi là bus có thứ tự: START, broadcast address `7'h7E+W` ở open-drain, ACK của broadcast header ở open-drain, ENEC opcode `8'h00` ở push-pull, T-bit sau opcode bằng `~^8'h00`, Target Events byte ở push-pull, T-bit sau event byte bằng `~^event_byte`, rồi STOP. Không được kỳ vọng ACK sau CCC opcode hoặc sau Target Events byte vì hai vị trí đó là T-bit do controller drive.

Test này quan trọng vì ENEC là một CCC broadcast cơ bản. Nó cũng kiểm tra đường decode `cp=1`, opcode CCC, immediate data path dùng cho Target Events byte, T-bit generation, và việc chuyển `sel_od_pp` đúng từ open-drain sang push-pull trong payload CCC.

### CCC_003 - `ccc_broadcast_disec_frame`

Test này kiểm tra broadcast DISEC frame theo MIPI broadcast CCC format.

DISEC là CCC dùng để disable một số event từ target. Testbench issue immediate command với `cp=1` và `cmd=8'h01`, target ACK bình thường.

Kết quả mong đợi là controller phát broadcast CCC frame tương ứng với DISEC: START, broadcast address `7'h7E+W`, broadcast-header ACK, DISEC opcode `8'h01` kèm T-bit, Target Events byte kèm T-bit nếu descriptor yêu cầu, rồi STOP. Vì đây là DISEC, controller không được kích hoạt ENTDAA controller.

Nếu command có event byte hoặc defining data theo descriptor convention, bus frame phải khớp với convention đã được specification hóa, không phải chỉ khớp waveform hiện tại của RTL.

Test này quan trọng vì ENEC và DISEC thường đi thành cặp. Kiểm tra cả hai giúp phát hiện lỗi opcode decode hoặc nhầm lẫn giữa broadcast CCC và ENTDAA flow.

### CCC_004 - `ccc_direct_enec_frame`

Test này kiểm tra direct ENEC frame.

Khác với broadcast ENEC, direct CCC cần chỉ định một target cụ thể bằng dynamic address. DAT phải chứa dynamic address hợp lệ, target phải ACK broadcast header, và target được chỉ định phải ACK direct target address.

Testbench issue immediate command với `cp=1`, `cmd=8'h80`, và một data byte. Controller phải phát broadcast header và CCC opcode trước, sau đó tạo repeated START để chuyển sang direct phase.

Kết quả mong đợi là bus có thứ tự: broadcast header, CCC byte kèm T-bit, repeated START `Sr`, target dynamic address với direction write, address ACK, data byte, T-bit, rồi STOP nếu `toc` yêu cầu kết thúc.

Test này quan trọng vì direct CCC phức tạp hơn broadcast CCC. Nó kiểm tra repeated START, lookup DAT, target address phase, và data phase trong cùng một command.

### CCC_005 - `ccc_direct_disec_frame`

Test này kiểm tra direct DISEC frame.

DAT chứa dynamic address hợp lệ; target ACK broadcast header và direct target address. Testbench issue immediate command với `cp=1` và `cmd=8'h81`.

Kết quả mong đợi là controller phát direct DISEC frame đúng cấu trúc direct CCC: broadcast CCC portion, repeated START, target dynamic address, data phase nếu descriptor yêu cầu, và kết thúc hợp lệ.

RESP phải báo success nếu tất cả ACK cần thiết đều được nhận.

Test này quan trọng vì nó kiểm tra đường direct CCC với opcode DISEC, giúp phân biệt lỗi chung của direct flow với lỗi riêng của ENEC.

### CCC_006 - `ccc_broadcast_header_nack`

Test này kiểm tra recovery khi CCC bị NACK ở broadcast header. Với ENTDAA opening frame, opcode ENTDAA là CCC byte kèm T-bit, không phải ACK slot riêng.

Testbench cấu hình device để NACK `7'h7E+W`. Sau đó issue các command như ENEC, DISEC, hoặc ENTDAA để quan sát recovery.

Kết quả mong đợi là controller không được treo bus. Controller phải report error status được project spec định nghĩa cho broadcast-header NACK, hoặc nếu chưa định nghĩa rõ error code thì test ghi nhận spec gap cần bổ sung và không tính là positive sign-off coverage.

Quan trọng nhất là sign-off không được chấp nhận trạng thái controller bị kẹt vĩnh viễn sau NACK.

Test này quan trọng vì CCC broadcast header là điểm chung của nhiều flow. Nếu NACK ở đây không được xử lý tốt, nhiều loại CCC command có thể làm hệ thống treo.

### CCC_007 - `ccc_direct_target_nack`

Test này kiểm tra trường hợp direct CCC bị NACK ở target dynamic address.

Target ACK broadcast header, nhận CCC opcode kèm T-bit, nhưng NACK địa chỉ direct target sau repeated START. Testbench issue direct ENEC hoặc direct DISEC.

Kết quả mong đợi là controller không được gửi direct data byte sau khi target address bị NACK. RESP và bus recovery phải khớp với address/header NACK policy trong project spec.

Nếu project spec có error code phù hợp, response phải phản ánh lỗi address phase. Nếu policy chưa rõ, test cần ghi nhận gap, nhưng controller vẫn không được treo bus.

Test này quan trọng vì direct CCC có hai address/header phase khác nhau. Pass broadcast phase không có nghĩa là target cụ thể đã chấp nhận command.

### CCC_008 - `ccc_unsupported_opcode_policy`

Test này xác định behavior đối với CCC opcode chưa được hỗ trợ.

Testbench issue các immediate command với `cp=1`, nhưng opcode nằm ngoài các nhóm ENEC, DISEC, và ENTDAA được project scope hỗ trợ. Nên chọn cả ví dụ broadcast opcode và direct opcode để quan sát hai đường decode.

Theo testplan, project spec hiện chưa định nghĩa đầy đủ policy cho opcode unsupported. Vì vậy expected result không nên giả định rằng mọi opcode unsupported đều đã trả về `NotSupported`.

Kết quả mong đợi là đây phải được xử lý như clarification/negative case: project spec cần định nghĩa reject bằng `NotSupported`, một error khác, hoặc software restriction. Dù theo hướng nào, controller không được phát một frame thành công không được spec định nghĩa, không được corrupt queue, không được ghi response sai format, và không được lock up.

Test này quan trọng vì software có thể gửi nhầm hoặc gửi CCC chưa được implement. Thiết kế cần có policy rõ để debug và sign-off scope không bị mơ hồ.

## 4.8 Dynamic Address Assignment / ENTDAA

Phần 4.8 kiểm tra Dynamic Address Assignment, cụ thể là flow ENTDAA.

ENTDAA là cơ chế I3C dùng để gán dynamic address cho các target chưa có địa chỉ động. Trong thiết kế này, flow bắt đầu từ `AddressAssignment` command, phát CCC ENTDAA opening frame, sau đó `entdaa_controller` và `entdaa_fsm` thực hiện từng round: gửi `7'h7E+R`, nhận PID/BCR/DCR từ target, gửi assigned dynamic address kèm parity, sample ACK/NACK, rồi lặp tiếp nếu `dev_count` yêu cầu nhiều device.

Các test trong phần này tập trung vào cả success path và các corner case: không có device, số device ít hơn `dev_count`, tăng DAT index qua nhiều round, parity của assigned address, target reject address, capture PID/BCR/DCR, boundary của DAT, abort giữa round, và arbitration nhiều target.

### DAA_001 - `entdaa_single_device_success`

Test này kiểm tra một round ENTDAA thành công với một target.

DAT[0] chứa dynamic address cần gán. Target model có khả năng drive PID, BCR, DCR và ACK assigned address. Testbench issue `AddressAssignment` với `dev_idx=0` và `dev_count=1`.

Kết quả mong đợi là ENTDAA frame hoàn tất đầy đủ. Controller gửi assigned address byte đúng với dynamic address trong DAT[0], bao gồm parity bit đúng. Target ACK address đó.

RESP phải báo success. Nếu project spec định nghĩa việc đưa thông tin ENTDAA vào RX FIFO hoặc software-visible path, test phải kiểm tra theo đúng format đó.

Test này quan trọng vì đây là baseline của toàn bộ DAA flow. Nếu single-device success không đúng, các case multi-device hoặc corner case phía sau không có ý nghĩa.

### DAA_002 - `entdaa_no_device`

Test này kiểm tra trường hợp không có target nào tham gia ENTDAA.

Sau ENTDAA opening frame, controller bắt đầu round bằng cách gửi `7'h7E+R`. Trong test này, không target nào ACK address đó.

Kết quả mong đợi là `entdaa_fsm` đi vào no-device path. Controller phải tạo STOP hoặc kết thúc bus theo ENTDAA no-device policy đã specification hóa, sau đó hoàn tất response mà không tạo assignment result giả.

Controller không được bị kẹt chờ PID/BCR/DCR khi không có device trả lời.

Test này quan trọng vì đây là điều kiện hợp lệ trong hệ thống: có thể không còn target chưa được assign address. Controller phải thoát sạch thay vì treo bus.

### DAA_003 - `entdaa_fewer_devices_than_count`

Test này kiểm tra trường hợp `dev_count` lớn hơn số target thật sự phản hồi.

Ví dụ command yêu cầu assign `K` device, nhưng thực tế chỉ có `M` target với `M < K`. Các round đầu tiên target ACK và hoàn tất assignment. Đến round tiếp theo, không còn target nào ACK `7'h7E+R`.

Kết quả mong đợi là loop thoát sau no-device NACK. Controller không được cố gán thêm địa chỉ cho device không tồn tại, không được đọc DAT vượt quá số round hợp lệ, và không được tạo response sai.

Test này quan trọng vì software có thể không biết chính xác số lượng target chưa được assign. ENTDAA flow cần xử lý số device thực tế ít hơn request một cách an toàn.

### DAA_004 - `entdaa_multi_device_dat_loop`

Test này kiểm tra việc tăng DAT index qua nhiều ENTDAA round.

Testbench program nhiều DAT entry liên tiếp, rồi issue `AddressAssignment` với `dev_idx=N` và `dev_count=K`. Mỗi target phản hồi ở một round và ACK assigned address.

Kết quả mong đợi là controller dùng đúng DAT index cho từng round: `N`, `N+1`, ..., `N+K-1`. Mỗi round phải có repeated START hoặc sequencing tương ứng trước khi bắt đầu round tiếp theo.

Nếu có đủ `K` target phản hồi, controller phải assign đủ `K` dynamic address theo đúng thứ tự DAT.

Test này quan trọng vì lỗi tăng index có thể làm nhiều target bị gán cùng địa chỉ, hoặc target thứ hai nhận nhầm địa chỉ của DAT entry khác.

### DAA_005 - `entdaa_address_parity_sweep`

Test này kiểm tra parity bit của assigned address trong ENTDAA.

Target ACK assigned address. Testbench sweep nhiều dynamic address đại diện, ví dụ địa chỉ thấp, địa chỉ cao, pattern xen kẽ bit 0/1, và một vài giá trị random hợp lệ.

Kết quả mong đợi là controller gửi assigned address theo format `{dynamic_addr[6:0], PAR}`. Bit `PAR` phải là odd parity của 7-bit dynamic address: `PAR = ~^dynamic_addr[6:0]`. Nói cách khác, tổng số bit `1` trong `{dynamic_addr[6:0], PAR}` phải là số lẻ.

Nếu dynamic address thay đổi, parity bit phải thay đổi theo công thức trên. Target chỉ ACK khi 7-bit address đúng và `PAR` đúng; nếu `PAR` sai thì target NACK assigned address.

Test này quan trọng vì assigned address không chỉ là 7-bit address. Parity sai có thể làm target reject assignment dù địa chỉ chính đúng.

### DAA_006 - `entdaa_address_rejected`

Test này kiểm tra trường hợp target nhận PID/BCR/DCR phase bình thường nhưng NACK assigned address.

Target ACK `7'h7E+R`, drive PID/BCR/DCR đầy đủ, nhưng khi controller gửi assigned address, target NACK.

Kết quả mong đợi là `addr_valid_o` không được assert, vì address assignment không thành công. Controller sau đó tiếp tục loop hoặc kết thúc theo policy đã specification hóa cho `dev_count` và no-device path.

Không được ghi nhận target là đã được assign address nếu target đã NACK address byte.

Test này quan trọng vì target có quyền từ chối assigned address. Controller phải phân biệt rõ capture identity thành công với assignment thành công.

### DAA_007 - `entdaa_pid_bcr_dcr_capture`

Test này kiểm tra việc capture identity của target trong ENTDAA.

Target drive các giá trị PID, BCR, và DCR đã biết trước. Testbench chạy một ENTDAA round thành công.

Kết quả mong đợi là internal captured PID/BCR/DCR trong `entdaa_fsm` khớp chính xác với giá trị target đã drive trên bus.

Nếu project spec expose thông tin này cho software qua RX FIFO hoặc một format nào đó, test phải kiểm tra format đó. Nếu software-visible format chưa được định nghĩa rõ, test phải document đây là spec gap.

Test này quan trọng vì PID/BCR/DCR là identity của target trong DAA. Nếu capture sai, software hoặc controller có thể hiểu sai loại device hoặc trạng thái của target.

### DAA_008 - `entdaa_dat_boundary`

Test này kiểm tra boundary của DAT khi ENTDAA bắt đầu gần cuối table.

DAT trong thiết kế có số entry hữu hạn. Testbench program `dev_idx` gần entry cuối, ví dụ `dev_idx=15`. Sau đó chạy hai case: `dev_idx=15`, `dev_count=1`; và `dev_idx=15`, `dev_count>1`.

Kết quả mong đợi là case một device ở entry cuối hoạt động đúng. Với case `dev_count>1`, controller sẽ cần entry ngoài phạm vi DAT nếu không có cơ chế chặn.

Expected result cho out-of-range case phải theo policy đã được specification hóa: report error hoặc ràng buộc bằng software precondition. Nếu policy chưa có, đây là spec gap và không được tính là positive sign-off coverage.

Test này quan trọng vì lỗi boundary DAT có thể gây đọc sai entry, assign address rác, hoặc corrupt state khi software cấu hình sai.

### DAA_009 - `entdaa_stop_mid_round`

Test này kiểm tra handling khi ENTDAA bị interrupt hoặc abort giữa một round.

External stimulus hoặc device model tạo điều kiện giống STOP/abort, hoặc reset được assert trong lúc controller đang nhận PID/BCR/DCR.

Kết quả mong đợi là ENTDAA không được treo ở trạng thái giữa chừng. `entdaa_fsm` phải terminate hoặc controller phải quay về idle/recoverable state theo policy đã specification hóa. Nếu behavior chưa được định nghĩa rõ, test document gap.

Sau abort, controller phải ở trạng thái có thể recover, ví dụ software reset hoặc command mới hợp lệ không bị ảnh hưởng bởi state cũ.

Test này quan trọng vì abort giữa transaction là một trong những lỗi khó debug nhất. Nếu state cleanup sai, command sau có thể dùng lại PID/BCR/DCR hoặc DAT index cũ.

### DAA_010 - `entdaa_two_target_arbitration`

Test này kiểm tra wired-AND arbitration giữa hai target chưa được assign address.

Trong I3C ENTDAA thật, nhiều target có thể cùng phản hồi. Khi chúng drive PID khác nhau trên bus open-drain, target thua arbitration phải dừng tham gia, target thắng tiếp tục round hiện tại.

Testbench cần UVM bus model hỗ trợ nhiều target cùng drive bus. Hai unaddressed target sẽ drive PID khác nhau để tạo tình huống arbitration.

Kết quả mong đợi là controller assign address cho arbitration winner trước. Target thua không được bị assign trong round đó, nhưng có thể được assign ở round sau nếu còn tham gia.

Test này có priority Future trong testplan vì UVM bus model hiện tại có thể chưa hỗ trợ simultaneous target driving đầy đủ. Nó vẫn được ghi lại để định hướng mở rộng verification sau này.

## 4.9 I2C Legacy Compatibility

Phần 4.9 kiểm tra khả năng tương thích I2C legacy của controller.

Trong thiết kế này, DAT entry có field `device`. Khi `device=1`, controller phải xử lý target như I2C legacy device: dùng `static_address` thay vì `dynamic_address`, chạy bus ở open-drain mode, dùng ACK/NACK theo I2C, và không dùng các semantics riêng của I3C như T-bit SDR data phase.

Các test trong phần này đảm bảo regular read/write I2C chạy đúng, length packing giống expectation của HCI queues, address NACK và data NACK được report đúng, OD mode được giữ trong toàn bộ transaction, timing register có thể cấu hình bus theo hướng I2C, và cấu hình `BROADCAST_ADDR_ENABLE` của private I3C không ảnh hưởng đến I2C legacy transfer.

### I2C_001 - `i2c_regular_write_basic`

Test này kiểm tra regular write path cho I2C legacy device.

DAT[0].`device` được set bằng 1, static address được program, và target ACK bình thường. Testbench issue RegularTransfer write với length 1 byte và 4 byte.

Kết quả mong đợi là controller phát static address với direction write, không dùng dynamic address. Toàn bộ transaction phải chạy ở open-drain mode.

Các data byte phải được target ACK. RESP phải báo success, và response length bằng đúng số byte đã truyền.

Test này quan trọng vì nó xác nhận DAT `device` bit thật sự chọn I2C path, chứ không chỉ dùng chung I3C regular write path với địa chỉ khác.

### I2C_002 - `i2c_regular_read_basic`

Test này kiểm tra regular read path cho I2C legacy device.

DAT[0].`device` được set bằng 1 và static address hợp lệ. Target trả data cho controller. Testbench issue RegularTransfer read với length 1 byte và 4 byte.

Kết quả mong đợi là controller phát static address với direction read. Trong I2C read, controller phải ACK các byte trung gian và NACK byte cuối để báo kết thúc read.

Data nhận được phải được ghi vào RX FIFO đúng thứ tự và RESP phải báo success với length đúng.

Test này quan trọng vì I2C read có ACK/NACK policy khác với I3C read T-bit semantics. Nếu dùng nhầm logic I3C, target I2C có thể không hiểu thời điểm kết thúc transfer.

### I2C_003 - `i2c_broadcast_addr_enable_ignored`

Test này kiểm tra rằng `HC_CONTROL[BROADCAST_ADDR_ENABLE]` không ảnh hưởng đến I2C legacy transfer.

DAT[0] được cấu hình là I2C device bằng cách set `device=1`, static address hợp lệ được program, và `HC_CONTROL[BROADCAST_ADDR_ENABLE]` được set bằng 1. Sau đó testbench chạy một I2C write và một I2C read đại diện.

Kết quả mong đợi là first address trên bus vẫn là static address từ DAT, với direction tương ứng write hoặc read. Controller không được phát `0x7e/W` preamble trước I2C transfer, dù bit `BROADCAST_ADDR_ENABLE` đang bằng 1.

Toàn bộ transaction vẫn phải giữ open-drain behavior của I2C, dùng ACK/NACK theo I2C, và không dùng T-bit hoặc private I3C preamble semantics.

Test này quan trọng vì cùng một RegularTransfer descriptor có thể trỏ đến I3C hoặc I2C tùy field `device` trong DAT. `BROADCAST_ADDR_ENABLE` chỉ dành cho private I3C; nếu nó bị áp dụng nhầm cho I2C, controller sẽ phát frame không hợp lệ cho target I2C.

### I2C_004 - `i2c_len_sweep_partial_rx`

Test này kiểm tra nhiều độ dài read/write trong I2C legacy path.

Testbench chạy cả I2C write và I2C read với các length 1, 2, 3, 4, 5, 7, và 8 byte. I2C target model ACK và trả data hợp lệ.

Kết quả mong đợi là TX packing và RX packing đều đúng. Với write, controller lấy đúng byte từ TX FIFO theo thứ tự expected. Với read, RX FIFO chứa đúng data target trả về.

Các length không chia hết cho 4 phải xử lý partial DWORD đúng, đặc biệt ở RX FIFO. RESP length phải khớp số byte thật sự transfer.

Test này quan trọng vì I2C path vẫn dùng HCI queues giống các path khác. Lỗi packing ở boundary DWORD có thể xuất hiện riêng ở I2C read/write dù I3C path đã pass.

### I2C_005 - `i2c_addr_nack`

Test này kiểm tra address NACK trong I2C legacy transaction.

Target được cấu hình để NACK static address. Testbench issue cả I2C read và I2C write command.

Kết quả mong đợi là controller không được đi vào data phase sau address NACK. Với write, không được truyền data byte. Với read, không được ghi data vào RX FIFO.

RESP phải báo error `AddrHeader`, và bus phải quay về idle hoặc recovery state hợp lệ.

Test này quan trọng vì address NACK là lỗi phổ biến khi target I2C không tồn tại, sai static address, hoặc device đang bận.

### I2C_006 - `i2c_data_nack_write`

Test này kiểm tra data-byte NACK trong I2C write.

Target ACK static address, sau đó NACK một data byte ở vị trí `M` trong multi-byte write.

Kết quả mong đợi là controller phát hiện data NACK và RESP báo error `Nack`. Sau data NACK, transfer phải dừng hoặc recover theo I2C/project error policy.

Controller không được tiếp tục truyền các byte còn lại như thể target vẫn ACK bình thường. Sau lỗi, một transfer hợp lệ tiếp theo vẫn phải chạy được, để chứng minh state đã được cleanup.

Test này quan trọng vì I2C target có thể NACK data để báo không nhận thêm được. Controller phải xử lý đây là lỗi data phase, không nhầm với address error.

### I2C_007 - `i2c_od_only_check`

Test này kiểm tra rằng I2C legacy transfer luôn dùng open-drain mode.

Testbench chạy cả I2C read và I2C write, đồng thời quan sát `sel_od_pp_o` và SDA drive behavior trong các phase address, data, ACK, START, và STOP.

Kết quả mong đợi là `sel_od_pp_o` giữ ở OD trong toàn bộ I2C transaction. Controller không được chuyển sang push-pull trong data phase như I3C SDR.

SDA drive/release cũng phải phù hợp với open-drain semantics: chỉ kéo xuống khi cần drive 0 và release khi cần high hoặc khi target phải drive ACK/data.

Test này quan trọng vì push-pull trong I2C legacy bus có thể gây contention điện và không tương thích với target I2C.

### I2C_008 - `i2c_timing_400k_equivalent`

Test này kiểm tra timing path khi controller chạy I2C legacy transfer.

Timing register được program với các giá trị tương đương I2C Fast-mode 400 kHz theo clock của testbench. Sau đó testbench chạy một số I2C read/write đại diện.

Kết quả mong đợi là thời gian low/high của `SCL`, START timing, và STOP timing bám theo các counter đã program. Transaction vẫn phải hoàn tất đúng với target ACK/data bình thường.

Test này không nhất thiết chứng minh full compliance mọi thông số I2C ngoài scope, nhưng phải xác nhận rằng I2C path thật sự dùng timing configuration và không bị hard-code theo I3C path.

Test này quan trọng vì legacy I2C thường chạy chậm hơn I3C. Nếu timing không program được đúng, controller có thể chỉ pass simulation nhanh nhưng không phù hợp với target I2C thực tế.

## 4.10 Error Handling, Status, and Recovery

Phần 4.10 kiểm tra cách controller report lỗi, ghi response, xử lý reset, và recover khỏi các tình huống bất thường.

Các test trước đó tập trung vào từng protocol flow riêng lẻ. Phần này gom lại các yêu cầu chung về status và recovery: RESP descriptor phải encode đúng success/error/TID/length, lỗi address và data phải được phân loại đúng, short read phải báo đúng error, FIFO response full phải tạo backpressure an toàn, reset không được để lại state rác, và các behavior chưa được hỗ trợ như bus stuck hoặc invalid descriptor phải được document rõ.

### ERR_001 - `resp_success_tid_length`

Test này kiểm tra các field của RESP descriptor khi transaction thành công.

Testbench chạy nhiều loại transaction hợp lệ với TID khác nhau, ví dụ immediate write, regular write, regular read, và ENTDAA success path.

Kết quả mong đợi là mỗi response có field error/status là `Success`, TID trong response khớp với TID của command, và length bằng số byte hoặc số lượng dữ liệu thực tế mà transaction đã xử lý.

Theo testplan, các field quan trọng là `RESP[31:28]` cho status, `RESP[27:24]` cho TID, và `RESP[15:0]` cho actual length.

Test này quan trọng vì software dựa vào RESP để biết command nào đã hoàn tất và hoàn tất với bao nhiêu data. Nếu TID hoặc length sai, software có thể ghép nhầm response với command khác.

### ERR_002 - `resp_addr_header_error`

Test này kiểm tra response khi lỗi xảy ra ở address/header phase.

Target được cấu hình để NACK address. Testbench chạy nhiều loại command có address phase: I3C write, I3C read, I2C write, I2C read, và direct CCC target address phase.

Kết quả mong đợi là controller không được đi vào data phase sau address NACK. Với write, không truyền data. Với read, không ghi RX data. Với direct CCC, không gửi direct data byte sau khi target address bị NACK.

RESP phải báo error `AddrHeader` ở mọi command class được support có address/header NACK.

Test này quan trọng vì address/header NACK là lỗi phổ biến và cần được phân loại riêng với data NACK hoặc short read.

### ERR_003 - `resp_data_nack_error`

Test này kiểm tra response khi target NACK data byte trong các write-style phase của I2C.

Testbench chạy I2C regular write hoặc I2C immediate write, target ACK address nhưng NACK một data byte.

Kết quả mong đợi là controller phát hiện data NACK, dừng hoặc recover transfer theo I2C/project error policy, và ghi RESP error `Nack`.

Sau lỗi, controller phải có khả năng chạy transfer hợp lệ tiếp theo, chứng minh rằng state machine không bị kẹt trong error path.

Test này quan trọng vì data NACK khác với address NACK. Nếu report sai error, software khó xác định target không tồn tại hay target từ chối data.

### ERR_004 - `resp_short_read_error`

Test này kiểm tra response khi I3C target kết thúc read sớm.

Testbench request đọc `N` byte, nhưng target chỉ trả `M` byte với `M < N`, rồi báo end bằng T-bit theo read semantics.

Kết quả mong đợi là RX FIFO chỉ chứa đúng `M` byte đã nhận được. RESP phải báo error `I3cShortReadErr`.

Length trong response phải phản ánh số byte thật sự đã nhận, không phải requested length `N`.

Test này quan trọng vì short read không nhất thiết là bus corruption. Nó là một tình huống protocol cần report chính xác để software biết có bao nhiêu data hợp lệ trong RX FIFO.

### ERR_005 - `resp_unreachable_error_codes`

Test này document các error code đã được định nghĩa nhưng chưa nằm trong feature scope hoặc chưa có stimulus spec rõ.

Testbench kết hợp code review và một số directed unsupported stimuli để thử tạo các lỗi như CRC, Frame, Ovl, HcAborted, NotSupported, hoặc Parity.

Kết quả mong đợi theo testplan là các error code ngoài scope hoặc chưa có stimulus spec rõ phải được đánh dấu là N/A hoặc enhancement request, không tính như positive coverage bắt buộc.

Nếu một stimuli unsupported làm controller phát frame, trả error khác, hoặc không validate opcode, behavior đó phải được ghi lại rõ.

Test này quan trọng vì nó tránh việc verification plan giả định controller đã support đầy đủ mọi error code chỉ vì enum có định nghĩa trong package.

### ERR_006 - `resp_fifo_full_backpressure`

Test này kiểm tra trường hợp RESP FIFO full khi controller cần ghi response.

Testbench làm RESP FIFO full trước khi một transaction hoàn tất. Sau đó cho transaction đi đến phase ghi response, rồi drain RESP FIFO để tạo chỗ trống.

Kết quả mong đợi là FSM phải chờ an toàn ở response write phase. Controller không được drop response, không được ghi đè response cũ, và không được tạo nhiều response duplicate cho cùng một command.

Sau khi RESP FIFO có chỗ trống, đúng một response phải được ghi vào FIFO.

Test này quan trọng vì software có thể đọc response chậm hơn tốc độ controller hoàn tất command. Backpressure ở RESP FIFO phải được xử lý như một phần của flow control bình thường.

### ERR_007 - `reset_during_idle`

Test này kiểm tra reset khi DUT đang idle.

Controller được đưa về trạng thái idle, sau đó testbench assert và deassert `rst_ni`.

Kết quả mong đợi là các register, queue, FIFO pointer, FSM state, và bus output trở về reset state. Bus phải được release về trạng thái không drive sai.

Sau reset, controller phải có thể chạy một command hợp lệ mới từ trạng thái sạch.

Test này quan trọng vì reset idle là đường reset cơ bản nhất. Nếu reset idle không sạch, các reset trong active phase càng khó tin cậy.

### ERR_008 - `reset_during_transfer_phases`

Test này kiểm tra reset trong lúc controller đang hoạt động.

Testbench assert reset tại nhiều phase khác nhau, ví dụ START, address ACK, data TX, data RX, DAA, và WriteResp phase.

Kết quả mong đợi là bus được release, FSM quay về reset state, và sau reset không có queue pop/push ngoài ý muốn từ transaction dang dở.

Sau mỗi reset point, testbench chạy một legal transfer tiếp theo để kiểm tra controller đã recover thật sự.

Test này quan trọng vì reset có thể xảy ra bất kỳ lúc nào trong hệ thống thật. Nếu reset giữa transfer để lại stale command, stale data, hoặc response nửa chừng, bug sẽ rất khó debug.

### ERR_009 - `sw_reset_while_busy_policy`

Test này làm rõ policy khi software reset được assert trong lúc controller đang bận.

Testbench bắt đầu một transfer, sau đó ghi `HC_CONTROL[1]` khi FSM chưa idle.

Theo testplan, nếu spec hiện tại xem behavior này là undefined thì testcase chỉ được dùng để ghi nhận spec gap và khuyến nghị software chỉ dùng software reset khi `FSM_IDLE=1`; nó không phải positive pass/fail dựa trên waveform hiện tại.

Nếu muốn kiểm tra busy software reset như một feature, project spec phải định nghĩa rõ là flush queue, abort transfer, ignore reset, hay trả lỗi. Nếu có nguy cơ treo hoặc corrupt state, đó là gap cần được xử lý hoặc ràng buộc bằng software precondition.

Test này quan trọng vì software reset là công cụ recovery, nhưng nếu dùng sai thời điểm có thể làm trạng thái controller khó dự đoán.

### ERR_010 - `bus_stuck_scl_low`

Test này xác định gap recovery khi bus bị kẹt, ví dụ `SCL` bị giữ low.

Device hoặc bus model giữ `SCL` low trong lúc transfer đang chạy, khiến controller không thể tiến triển bình thường.

Theo testplan, project scope hiện chưa có bus recovery hoặc timeout hoàn chỉnh. Vì vậy test có thể fail bằng simulation timeout hoặc document đây là known gap.

Kết quả quan trọng là behavior phải được ghi nhận rõ, không được coi là một pass chức năng nếu controller chỉ chờ vô hạn mà không có timeout policy.

Test này quan trọng vì bus stuck là lỗi thực tế trên hệ thống open-drain. Nếu không có timeout/recovery, software hoặc system-level logic phải biết đây là giới hạn hiện tại.

### ERR_011 - `invalid_descriptor_attr`

Test này kiểm tra behavior khi command descriptor có attr hoặc mode không được hỗ trợ.

Testbench ghi trực tiếp các descriptor như `ComboTransfer`, reserved attr, HDR mode values, hoặc invalid mode encodings vào CMD queue.

Kết quả mong đợi là controller không được gây queue corruption, không được tạo pop/push bất hợp lệ, và không được treo vô hạn mà không được document. Protocol behavior cụ thể cần được specification hóa trước khi sign-off.

Nếu project spec chưa định nghĩa đầy đủ validation cho descriptor, test phải ghi nhận spec gap và đề xuất enhancement hoặc software restriction.

Test này quan trọng vì command descriptor là input từ software. Một descriptor sai không nên làm hỏng internal state hoặc phá toàn bộ controller.

## 4.11 Arbitration and Bus Behavior

Phần 4.11 kiểm tra các hành vi liên quan đến arbitration và trạng thái bus ngoài luồng transaction thông thường.

Trong I3C, đặc biệt ở ENTDAA, bus có thể có nhiều target cùng drive theo kiểu wired-AND. Ngoài ra controller cũng cần có policy rõ khi gặp STOP bất ngờ hoặc khi software queue command trong lúc bus chưa idle. Các test trong phần này không chỉ kiểm tra data path, mà còn kiểm tra cách DUT quan sát bus thật và phản ứng với điều kiện bus bất thường.

### ARB_001 - `entdaa_single_bit_arbitration_observe`

Test này kiểm tra việc receiver sample từng bit identity trong ENTDAA.

Target DAA drive PID/BCR/DCR với giá trị đã biết. Trong quá trình ENTDAA, testbench quan sát từng bit mà `bus_rx_flow` sample từ bus.

Kết quả mong đợi là identity 64-bit mà `entdaa_fsm` capture phải khớp với dữ liệu thật trên bus, bao gồm PID, BCR, và DCR.

Test này quan trọng vì ENTDAA arbitration và identity capture đều phụ thuộc vào việc sample đúng từng bit. Nếu bit-level receive sai, controller có thể assign address cho sai target hoặc capture sai thông tin target.

### ARB_002 - `entdaa_multi_target_arbitration_future`

Test này kiểm tra true multi-target arbitration trong ENTDAA.

Nhiều target chưa được assign address cùng tham gia ENTDAA và drive PID khác nhau. Vì bus open-drain/wired-AND, target nào thua arbitration phải dừng drive, còn target thắng tiếp tục round hiện tại.

Kết quả mong đợi là controller assign address cho arbitration winner trước. Target thua sẽ retry ở round sau và được assign sau nếu vẫn còn tham gia.

Test này có priority Future vì cần UVM bus model hỗ trợ nhiều target simultaneous drive. Hiện tại nếu testbench chưa hỗ trợ điều này, test được giữ như roadmap cho verification mở rộng.

### ARB_003 - `unexpected_stop_during_command`

Test này kiểm tra phản ứng của controller khi có STOP bất ngờ trong lúc command đang active.

Bus model force một điều kiện giống STOP, tức `SDA` rising khi `SCL` high, trong lúc DUT đang ở DAA hoặc data phase.

Kết quả mong đợi là controller phải terminate command hoặc đưa controller về trạng thái hợp lệ theo recovery policy đã được specification hóa. Nếu chưa có recovery policy cho STOP bất ngờ, test phải ghi nhận missing spec/RTL behavior này.

Controller không được âm thầm tiếp tục dùng state cũ như thể không có STOP nếu điều đó làm corrupt transaction sau.

Test này quan trọng vì bus event bất ngờ có thể xảy ra do reset, target lỗi, hoặc contention trong hệ thống. Verification cần biết scope/spec yêu cầu recovery đến mức nào.

### ARB_004 - `start_when_bus_not_idle`

Test này kiểm tra behavior khi software queue command trong lúc bus chưa idle.

Trước khi issue command, testbench giữ `SCL` hoặc `SDA` ở trạng thái non-idle, tức không phải cả hai đều high. Sau đó queue một command bình thường.

Kết quả mong đợi là controller phải chờ Bus Available/Idle hoặc báo lỗi theo policy đã được specification hóa. Nếu hardware không support case này, software precondition phải yêu cầu chỉ queue command khi bus idle.

Test này quan trọng vì controller bắt đầu START trên bus không idle có thể làm target hiểu sai frame hoặc gây contention. Nếu hardware không tự bảo vệ, requirement phải được đẩy lên software.

## 4.12 UVM Environment, Scoreboard, and Regression Infrastructure

Phần 4.12 kiểm tra chính môi trường verification: compile flow, regression targets, scoreboard, device response sequence, monitor decode, và register agent.

Các test này không phải protocol feature trực tiếp của DUT, nhưng rất quan trọng cho sign-off. Nếu testbench không compile ổn định, scoreboard không bắt mismatch, monitor không decode được CCC/DAA, hoặc device model không điều khiển ACK/NACK đúng, thì kết quả pass/fail của các test protocol phía trước không đáng tin cậy.

### UVM_001 - `uvm_compile_elaborate`

Test này kiểm tra source list và compile/elaboration flow.

Điều kiện là Xcelium có sẵn và environment đã source setup đúng. Testbench chạy `make compile` từ thư mục `src/verification`.

Kết quả mong đợi là toàn bộ RTL và UVM compile/elaborate pass, không có fatal error.

Test này quan trọng vì đây là build gate cơ bản nhất. Nếu compile không pass, các functional test phía sau không thể chạy hoặc kết quả không có ý nghĩa.

### UVM_002 - `uvm_smoke_regression`

Test này kiểm tra smoke regression hiện tại.

Testbench chạy `make smoke` trong môi trường Xcelium hợp lệ. Smoke target hiện tại chạy sequence cơ bản để chứng minh DUT, UVM env, driver, monitor, và scoreboard có thể phối hợp.

Kết quả mong đợi là UVM summary có zero `UVM_ERROR` và zero `UVM_FATAL`. RESP success phải được quan sát đúng theo smoke sequence.

Test này quan trọng vì smoke là gate nhanh để phát hiện lỗi lớn sau mỗi thay đổi.

### UVM_003 - `uvm_regression_current`

Test này kiểm tra regression target hiện tại của repository.

Testbench chạy `make regression` từ `src/verification`. Regression hiện tại gồm smoke, write, và read virtual sequences.

Kết quả mong đợi là các sequence hiện có pass. Sau khi chạy, `sim.log` phải được inspect để xác nhận UVM summary không có `UVM_ERROR` hoặc `UVM_FATAL`.

Test này quan trọng vì regression là baseline hiện tại của project. Các thay đổi RTL hoặc UVM không nên làm vỡ smoke/write/read flow đã có.

### UVM_004 - `scoreboard_cmd_resp_order`

Test này kiểm tra scoreboard correlate command và response đúng thứ tự.

Testbench queue nhiều command back-to-back với TID khác nhau, địa chỉ/data khác nhau, rồi đọc các response tương ứng.

Kết quả mong đợi là `i3c_scoreboard` match đúng expected address, direction, data, TID, và response ordering. Cuối test không được còn expected transaction chưa consume.

Test này quan trọng vì back-to-back command rất dễ lộ lỗi scoreboard nếu scoreboard chỉ check từng transaction đơn lẻ hoặc ghép response sai command.

### UVM_005 - `scoreboard_negative_mismatch`

Test này kiểm tra scoreboard thật sự phát hiện lỗi.

Khi có cơ chế mismatch injection có kiểm soát, testbench cố tình làm expected data hoặc expected address khác với traffic thật.

Kết quả mong đợi là scoreboard emit `UVM_ERROR`, và test infrastructure phải bắt được failure đó như một negative test hợp lệ.

Test này quan trọng vì một scoreboard không bao giờ fail không chứng minh được DUT đúng. Negative mismatch giúp xác nhận checker có khả năng bắt lỗi thật.

### UVM_006 - `device_response_ack_nack_controls`

Test này kiểm tra khả năng cấu hình device response sequence.

`i3c_device_response_seq` hoặc derived sequence phải điều khiển được nhiều hành vi target: address ACK/NACK, data ACK/NACK, read data payload, và mode I2C/I3C.

Kết quả mong đợi là `i3c_driver` drive đúng bus behavior theo các field trong sequence item. Các error tests như address NACK, data NACK, short read, và I2C/I3C mode switching phải có stimulus đáng tin cậy.

Test này quan trọng vì nhiều testcase trong testplan phụ thuộc vào target model tạo đúng lỗi. Nếu device response sequence không configurable, các negative test sẽ không kiểm tra đúng tình huống.

### UVM_007 - `monitor_ccc_and_daa_decode`

Test này kiểm tra monitor decode được traffic quản lý như CCC và DAA.

Sau khi các CCC/DAA virtual sequence được implement, testbench chạy ENEC, DISEC, và ENTDAA tests. `i3c_monitor` phải observe bus và tạo item với thông tin decode đúng.

Kết quả mong đợi là monitor report đúng CCC opcode, direct hoặc broadcast flag, dữ liệu DAA, STOP, và repeated START.

Test này quan trọng vì nếu monitor không decode được management traffic, scoreboard và coverage không thể kiểm chứng CCC/DAA một cách đáng tin cậy.

### UVM_008 - `reg_agent_read_write_protocol`

Test này kiểm tra register agent.

Register interface đã được connect. Testbench chạy các directed read/write operation, bao gồm back-to-back accesses.

Kết quả mong đợi là `reg_driver` drive đúng single-cycle register access theo protocol của `reg_if`, và `reg_monitor` report đúng các bus operation đã quan sát.

Test này quan trọng vì gần như mọi testcase đều cấu hình DUT qua register bus. Nếu reg agent sai, lỗi có thể bị hiểu nhầm là lỗi RTL hoặc protocol trong khi thực tế là stimulus sai.

## 4.13 Stress, Robustness, and Performance

Phần 4.13 kiểm tra độ bền của controller khi chạy nhiều transaction, nhiều loại command, trạng thái FIFO sát biên, và đo một số chỉ số performance.

Các test trong phần này khác với directed test ở các mục trước. Directed test kiểm tra từng behavior cụ thể, còn stress test cố tình trộn nhiều biến: direction, length, data pattern, TID, DAT entry, ACK/NACK, command class, và trạng thái queue. Mục tiêu là tìm lỗi state cleanup, ordering, backpressure, hoặc corner case chỉ xuất hiện khi nhiều flow chạy liên tiếp.

Các performance test có priority Low vì chúng chủ yếu đo latency/throughput, không phải pass/fail chức năng ngoại trừ timeout hoặc lỗi protocol rõ ràng.

### STR_001 - `stress_random_i3c_private_rw`

Test này stress các I3C private read/write transaction.

Testbench dùng constrained-random virtual sequence và target model. Các field được randomize gồm direction read/write, length, data pattern, TID, DAT entry, và ACK behavior.

Kết quả mong đợi là controller không bị hang. Với các transaction hợp lệ, scoreboard phải match toàn bộ data, address, direction, TID, và response. Với các lỗi được inject có chủ đích như NACK hoặc short read, response phải là lỗi expected chứ không phải lỗi bất ngờ.

Test này quan trọng vì nhiều bug không xuất hiện khi chỉ chạy một write hoặc một read cố định. Random private transfer giúp bắt lỗi ordering, stale state, length boundary, và error recovery.

### STR_002 - `stress_i2c_i3c_mixed_devices`

Test này stress việc chuyển qua lại giữa I2C và I3C device trong DAT.

DAT được program với cả I2C target và I3C target. Testbench tạo random command stream đến nhiều DAT entry khác nhau.

Kết quả mong đợi là controller chọn đúng static address cho I2C device và dynamic address cho I3C device. OD/PP mode cũng phải đúng theo từng device type: I2C giữ OD, I3C dùng OD/PP theo phase được project spec định nghĩa.

Response phải giữ đúng thứ tự command, không lẫn data hoặc TID giữa các device.

Test này quan trọng vì field `device` trong DAT ảnh hưởng nhiều logic: address selection, bus mode, ACK/NACK semantics, và data phase behavior. Switching liên tục giúp phát hiện lỗi state còn sót từ device trước.

### STR_003 - `stress_ccc_daa_private_mix`

Test này stress việc trộn management traffic và private data traffic.

Sau khi các virtual sequence cho CCC và DAA đã implement, testbench trộn các command như ENEC, DISEC, ENTDAA, regular read, và regular write.

Kết quả mong đợi là controller quay về idle giữa các command đã hoàn tất, không mang stale state từ command class này sang command class khác.

Ví dụ state của ENTDAA không được ảnh hưởng đến read/write sau đó; direct CCC không được làm sai DAT index hoặc command decode của private transfer kế tiếp.

Test này quan trọng vì controller thực tế sẽ không chỉ chạy một loại command. Mix command giúp kiểm tra cleanup giữa các FSM path khác nhau.

### STR_004 - `stress_fifo_boundary_random`

Test này stress các queue ở trạng thái gần full hoặc gần empty.

Testbench random việc ghi CMD/TX và đọc RX/RESP trong khi cố tình đưa các FIFO đến gần full, full, gần empty, và empty.

Kết quả mong đợi là không có overflow hoặc underflow làm corrupt queue. `QUEUE_STATUS` phải tiếp tục phản ánh đúng trạng thái thật của từng FIFO.

Các pop/push hợp lệ vẫn phải giữ đúng ordering. Các thao tác bị chặn do full/empty không được làm pointer chạy sai.

Test này quan trọng vì nhiều lỗi FIFO chỉ xuất hiện ở boundary, đặc biệt khi software và controller cùng tác động lên queue trong thời gian gần nhau.

### STR_005 - `stress_long_run_1k`

Test này kiểm tra độ ổn định khi chạy lâu.

Directed-random suite chạy ít nhất 1000 transaction, bao gồm cả transaction hợp lệ và negative transaction có lỗi được inject có chủ đích.

Kết quả mong đợi là không có `UVM_ERROR` hoặc `UVM_FATAL` bất ngờ, không timeout, và controller không bị hang. Cuối test, các queue phải empty hoặc được drain theo intent của test.

Expected error do NACK, short read, hoặc unsupported case phải được phân biệt rõ với unexpected failure.

Test này quan trọng vì memory leak trong testbench, stale expected transaction trong scoreboard, hoặc state leak trong DUT thường chỉ lộ ra sau nhiều transaction.

### PERF_001 - `perf_sdr_rw_latency`

Test này đo latency của I3C SDR read/write.

Testbench hoặc monitor timestamp từ thời điểm command được enqueue đến khi RESP xuất hiện. Các transfer size đại diện gồm 1, 4, 16, và 64 byte.

Kết quả mong đợi là test report min/avg/max latency và throughput cho từng loại transfer. Đây không phải functional pass/fail ngoại trừ timeout hoặc lỗi protocol.

Test này quan trọng vì nó cung cấp baseline performance để so sánh sau các thay đổi FSM, timing, hoặc queue handling.

### PERF_002 - `perf_i2c_legacy_latency`

Test này đo latency của I2C legacy transfer.

Sau khi các I2C legacy virtual sequence đã implement, testbench đo latency read/write với timing register được program theo I2C timing.

Kết quả mong đợi là test report min/avg/max latency và so sánh latency với timing đã program. Nếu tăng timing counter, latency phải tăng theo hướng hợp lý.

Test này quan trọng vì I2C legacy thường chậm hơn I3C. Performance data giúp xác nhận timing configuration có ảnh hưởng thật đến transaction latency.

### PERF_003 - `perf_back_to_back_gap`

Test này đo khoảng gap giữa các command chạy liên tiếp.

Testbench queue back-to-back commands và đo các khoảng như STOP-to-next-START hoặc RESP-to-next-command. Các tổ hợp cần đo gồm write-write, read-read, write-read, và read-write.

Kết quả mong đợi là test report gap và chỉ ra có bao nhiêu idle cycle giữa hai command. Đây chủ yếu là metric, không phải functional pass/fail trừ khi gap dẫn đến timeout hoặc sai protocol.

Test này quan trọng vì back-to-back efficiency ảnh hưởng throughput thực tế. Nó cũng giúp phát hiện các idle cycle không cần thiết trong `flow_active` hoặc `scl_generator`.

## 4.14 Non-Applicable Feature Documentation Tests

Phần 4.14 document các feature không nằm trong scope hiện tại hoặc chưa được implement.

Các test này không phải positive functional tests. Mục tiêu của chúng là tránh hiểu nhầm rằng verification plan đang bỏ sót một feature đã có. Nếu feature chưa tồn tại trong RTL/UVM, test phải ghi rõ là không có positive testcase cho sign-off hiện tại và feature đó chỉ được kiểm tra bằng code review hoặc negative/unsupported behavior.

### NA_001 - `na_ibi_no_positive_test`

Test này document việc IBI chưa được implement.

Testbench hoặc reviewer inspect RTL và UVM để tìm các interface, queue, event arbitration, hoặc IRQ path liên quan đến IBI.

Kết quả mong đợi là xác nhận IBI không tồn tại trong implementation hiện tại. Vì vậy không có positive IBI testcase được tính vào sign-off hiện tại.

Test này quan trọng vì IBI là feature lớn của I3C, nhưng không thuộc scope controller hiện tại. Ghi rõ N/A giúp tránh nhầm lẫn giữa coverage gap và intentional out-of-scope.

### NA_002 - `na_hotjoin_no_positive_test`

Test này document việc Hot-Join chưa được implement.

Reviewer inspect RTL/UVM để tìm logic phát hiện Hot-Join, event state, hoặc CCC flow liên quan đến Hot-Join.

Kết quả mong đợi là Hot-Join không được implement trong scope hiện tại. Nó được xem là future feature, không có positive testcase bắt buộc cho sign-off hiện tại.

Test này quan trọng vì Hot-Join liên quan đến target tự yêu cầu tham gia bus. Nếu không document rõ, người đọc testplan có thể nghĩ thiếu test Hot-Join là thiếu sót verification.

### NA_003 - `na_irq_no_positive_test`

Test này document việc interrupt output chưa tồn tại.

Reviewer inspect top-level port và CSR map. Thiết kế hiện tại không có IRQ output, interrupt enable register, hoặc interrupt status register riêng.

Kết quả mong đợi là xác nhận status verification hiện tại chỉ đi qua `HC_STATUS`, `QUEUE_STATUS`, và RESP FIFO.

Do không có interrupt interface, không có positive IRQ testcase trong sign-off hiện tại.

Test này quan trọng vì nhiều controller thật có interrupt path. Với design hiện tại, software phải poll status/response thay vì dựa vào IRQ.

### NA_004 - `na_hdr_no_positive_test`

Test này document việc HDR mode chưa được implement.

Reviewer kiểm tra package và `flow_active`. Dù có thể tồn tại enum hoặc descriptor value liên quan HDR, thiết kế hiện tại không có HDR datapath.

Kết quả mong đợi là không có positive HDR test bắt buộc. Các HDR mode enum chỉ nên được dùng trong invalid descriptor hoặc unsupported descriptor negative test.

Test này quan trọng vì HDR là feature khác lớn so với SDR. Nếu chưa có datapath, chạy positive HDR test sẽ không hợp lý; verification chỉ cần đảm bảo unsupported descriptor không làm controller corrupt hoặc lock up.
