# Giải thích test case I3C bằng tiếng Việt

## Ghi chú về oracle verification

Mục tiêu của testplan là kiểm tra RTL có tuân thủ specification hay không. Vì vậy expected result của testcase phải đi từ MIPI I3C Basic v1.1.1 và các spec của project, không được lấy hành vi hiện tại của RTL làm chuẩn để test pass.

Nếu RTL khác specification, testcase phải fail hoặc ghi rõ đây là RTL/spec gap. Nếu project spec chưa định nghĩa một policy, testcase đó chỉ là clarification/negative test và không được tính là positive sign-off coverage cho đến khi expected behavior được specification hóa.

## 4.1 CSR, DAT, and Register Bus

Phần 4.1 kiểm tra lớp register của controller. Mục tiêu là đảm bảo software hoặc UVM testbench có thể cấu hình, đọc trạng thái, đưa command, đưa data, và lấy response thông qua CSR interface một cách đúng đắn. Nếu các test trong mục này fail, các test protocol I3C phía sau có thể fail do lỗi cấu hình CSR/FIFO, chứ không nhất thiết do lỗi giao tiếp trên bus SCL/SDA.

### CSR_001 - `csr_reset_defaults`

Test này kiểm tra giá trị các thanh ghi ngay sau reset.

Sau khi reset được assert và release, testbench sẽ đọc các register quan trọng như `HC_CONTROL`, `HC_STATUS`, các timing register, `QUEUE_STATUS`, và toàn bộ DAT từ `DAT[0]` đến `DAT[31]`.

Kết quả mong đợi là controller chưa được enable, FSM đang ở trạng thái idle, các queue đang empty, toàn bộ DAT entry bằng 0, và các timing register có giá trị default đúng với CSR/module spec.

Test này quan trọng vì reset là trạng thái ban đầu của toàn bộ DUT. Nếu reset default sai, các test tiếp theo có thể bắt đầu từ một trạng thái không xác định.

### CSR_002 - `csr_enable_disable`

Test này kiểm tra bit enable của controller trong `HC_CONTROL[31]` (BUS_ENABLE).

Testbench sẽ ghi command vào CMD queue khi controller chưa enable, sau đó mới bật enable. Khi controller đang disabled, DUT không được bắt đầu transaction trên bus. Sau khi `HC_CONTROL[31]` (BUS_ENABLE) được set lên 1, command mới được phép chạy.

Kết quả mong đợi là không có bus transaction trước khi enable. Sau khi enable, command được thực thi và controller quay về idle khi hoàn tất.

Test này đảm bảo software có quyền kiểm soát lúc nào controller được phép hoạt động.

### CSR_003 - `csr_broadcast_header_control`

Test này kiểm tra bit `BROADCAST_ADDR_ENABLE` trong `HC_CONTROL[0]` (IBA_INCLUDE) và kiểm tra luôn hiệu ứng của bit này lên private I3C transfer.

Bit này chỉ điều khiển việc private I3C transfer có bắt đầu bằng broadcast header `0x7e/W` hay không. Nó không phải bit enable controller và không được tự tạo traffic trên bus.

Testbench sẽ đọc `HC_CONTROL[BROADCAST_ADDR_ENABLE]` sau reset, sau đó ghi set và clear bit này qua `HC_CONTROL`. Testbench cũng thử set riêng bit này khi `HC_CONTROL[31]` (BUS_ENABLE) vẫn bằng 0.

Sau phần control-plane, testbench sẽ cấu hình DAT[0] là I3C target có dynamic address `0x08`, rồi issue hai regular SDR private write 4 byte với TX data đã biết. Lần thứ nhất chạy với `BROADCAST_ADDR_ENABLE=0`, lần thứ hai chạy với `BROADCAST_ADDR_ENABLE=1`. Ở mode enable, device model phải ACK broadcast header `0x7e/W`, sau đó ACK dynamic address `0x08/W`.

Kết quả mong đợi là reset value của bit này bằng 0, software có thể ghi 1 và ghi lại 0 đúng như mong đợi, và việc set riêng `BROADCAST_ADDR_ENABLE` không làm controller enable cũng không làm phát START hay bất kỳ transaction nào trên bus. Khi bit bằng 0, private write phải bắt đầu trực tiếp bằng `START + 0x08/W`, không được phát `0x7e`. Khi bit bằng 1, bus frame phải là `START + 0x7e/W + ACK + Sr + 0x08/W + ACK + data/T-bit + STOP`. Monitor và scoreboard phải xem toàn bộ preamble cộng target phase là một transaction đầy đủ, không tách `0x7e` thành một transaction rỗng riêng.

Test này quan trọng vì nó chứng minh cả hai mặt của cùng một CSR setting: CSR phải lưu đúng cấu hình, bit này không được tự enable controller, và khi software enable controller cùng command hợp lệ thì setting đó phải thật sự đổi first-address behavior của private I3C transfer.

### CSR_004 - `csr_timing_rw`

Test này kiểm tra khả năng ghi và đọc lại các timing register.

Timing register điều khiển các tham số thời gian của bus, gồm nhóm I3C `T_R`, `T_F`, `T_LOW`, `T_LOW_OD`, `T_HIGH`, `T_SU_STA`, `T_HD_STA`, `T_SU_STO`, `T_SU_DAT`, `T_HD_DAT`, `T_BUS_FREE` và nhóm I2C `I2C_T_SU_DAT` tới `I2C_T_BUF` (I2C dùng chung `T_R`/`T_F`/`T_HD_DAT` với I3C). Testbench sẽ ghi các giá trị default, 0, giá trị nhỏ hợp lệ, giá trị lớn nhất 20-bit, giá trị random hợp lệ, và giá trị có các bit reserved phía trên được set, sau đó đọc lại.

Kết quả mong đợi là 20 bit thấp `[19:0]` đọc ra đúng với giá trị đã ghi. Các bit reserved phía trên phải đọc ra 0. Sau mỗi lần ghi một timing register, các timing register còn lại cũng được đọc lại để bảo đảm không có lỗi ghi nhầm địa chỉ hoặc làm hỏng giá trị lân cận.

Test này giúp xác nhận software có thể lập trình timing cho I3C/I2C transaction và register không lưu sai các bit reserved.

### CSR_005 - `csr_dat_rw_all_entries`

Test này kiểm tra DAT, viết tắt của Device Address Table.

DAT lưu thông tin địa chỉ của các device mà controller sẽ giao tiếp. Mỗi entry có các field quan trọng như `device`, `dynamic_address`, và `static_address`. Testbench sẽ ghi các giá trị khác nhau vào `DAT[0]` đến `DAT[31]`, sau đó đọc lại từng entry.

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

Test này kiểm tra software reset thông qua `RESET_CONTROL[0]` (SOFT_RST).

Khi các queue đang có dữ liệu, testbench sẽ đợi controller idle, sau đó ghi `RESET_CONTROL[0]=1` để yêu cầu software reset. Sau reset, testbench đọc queue status và các port liên quan.

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

Test này kiểm tra hành vi đọc từ `PIO_DATA_PORT` và `RESP_PORT`.

`PIO_DATA_PORT` dùng để software đọc data mà controller nhận được từ target trong các read transaction. `RESP_PORT` dùng để software đọc response descriptor sau khi command hoàn tất. Cả hai port này được nối với FIFO, nên mỗi lần đọc hợp lệ phải pop đúng một entry.

Ví dụ RX FIFO có hai entry:

```text
[0xAAAA_BBBB, 0xCCCC_DDDD]
```

Lần đọc đầu tiên từ `PIO_DATA_PORT` phải trả về `0xAAAA_BBBB`, sau đó FIFO chỉ còn `0xCCCC_DDDD`. Lần đọc thứ hai trả về `0xCCCC_DDDD`, sau đó FIFO empty.

Nếu software tiếp tục đọc khi FIFO đã empty, DUT phải trả về 0 và không được làm hỏng FIFO pointer. Tương tự, đọc `RESP_PORT` khi có response phải pop một response; đọc khi empty phải trả về 0 và không underflow.

Kết quả mong đợi là mỗi valid read chỉ pop một entry, data/response trả về đúng thứ tự FIFO, và empty read an toàn.

### CSR_012 - `csr_unmapped_addr_no_side_effect`

Test này kiểm tra hành vi khi software đọc hoặc ghi vào địa chỉ register không tồn tại trong CSR map.

Testbench sẽ chụp lại trạng thái hiện tại của các CSR và queue, sau đó thực hiện read/write vào các địa chỉ aligned nhưng không được map vào bất kỳ register hợp lệ nào.

Kết quả mong đợi là read từ địa chỉ unmapped trả về 0. Write vào địa chỉ unmapped không được thay đổi `HC_CONTROL`, timing register, DAT, queue, command staging, hoặc bắt đầu transaction trên bus.

Ví dụ nếu `HC_CONTROL`, `DAT[0]`, và CMD FIFO đang có trạng thái xác định, sau khi ghi `0xDEADBEEF` vào một địa chỉ invalid, các trạng thái đó phải giữ nguyên.

Test này quan trọng vì software có thể truy cập nhầm địa chỉ, hoặc có bug trong driver. DUT cần xử lý truy cập invalid một cách an toàn, không tạo side effect không mong muốn.

### CSR_013 - `csr_hc_abort_control`

Test này kiểm tra bit abort của host controller trong `HC_CONTROL[29]` (ABORT).

Sau reset, testbench đọc `HC_CONTROL` để xác nhận bit này bằng 0. Sau đó testbench ghi set và clear bit này qua `HC_CONTROL`, đồng thời thử set riêng `ABORT` khi `HC_CONTROL[31]` (BUS_ENABLE) vẫn bằng 0.

Kết quả mong đợi là `ABORT` là bit RW dạng level: software ghi 1 thì đọc lại thấy 1, ghi 0 thì đọc lại thấy 0, và hardware không tự clear bit này. Việc set riêng `ABORT` không được tự enable controller và không được tự tạo transaction trên bus.

Test này chỉ kiểm tra mặt control-plane của bit abort. Hành vi abort khi controller đang chạy transaction, response encoding, data boundary, và recovery policy được kiểm tra ở `ERR_009`.

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

### FIFO_005 - `sync_fifo_depth_power_of_two_contract`

Mục này không còn là một test regression riêng. Ràng buộc cấu hình của module `sync_fifo` đã được cover trực tiếp bởi assertion trong RTL.

`sync_fifo` yêu cầu depth phải là power-of-two, ví dụ:

```text
2, 4, 8, 16, 32, ...
```

Các depth như 3, 5, 6, 10 không hợp lệ.

RTL hiện có elaboration-time assertion kiểm tra `Depth == (1 << $clog2(Depth))`. Vì vậy nếu người dùng instantiate `sync_fifo` với depth không hợp lệ, elaboration sẽ fail ngay theo parameter contract của module.

Do đây là ràng buộc cấu hình tĩnh, không phải behavior runtime, không cần giữ một negative UVM/regression target riêng. Các FIFO runtime test vẫn cover các depth hợp lệ đang dùng trong top-level testbench, còn depth bất hợp lệ được chặn bởi assertion trong chính RTL.

Trạng thái của FIFO_005 là retired/already covered by RTL elaboration assertion.

### FIFO_006 - `fifo_pointer_wrap_reuse`

Test này kiểm tra trường hợp FIFO đã chạy đủ nhiều để read pointer và write pointer wrap qua boundary của depth.

Ví dụ FIFO depth là 8. Testbench fill đủ 8 entry, drain hết 8 entry, sau đó push một chuỗi data mới hoàn toàn khác và drain tiếp. Ở lượt thứ hai, pointer nội bộ đã quay lại index thấp nhưng extra MSB của pointer đã thay đổi, nên đây là chỗ dễ lộ bug full/empty hoặc stale data.

Kết quả mong đợi là chuỗi data thứ hai phải đọc ra đúng thứ tự và không được lẫn bất kỳ entry cũ nào từ chuỗi thứ nhất. Các flag empty/full/depth phải vẫn đúng sau mỗi lần fill, drain, wrap, và sau final drain.

Test này quan trọng vì FIFO dùng circular buffer. Nếu pointer wrap sai, bug có thể không xuất hiện ở push/pop đơn giản nhưng sẽ xuất hiện sau nhiều transaction back-to-back.

### FIFO_007 - `fifo_simultaneous_rw_empty_full_edges`

Test này bổ sung hai boundary còn thiếu của simultaneous read/write.

Trường hợp thứ nhất là FIFO đang empty, testbench assert `wvalid` và `rready` cùng một cycle. Vì FIFO đang empty nên `rvalid` phải bằng 0, read không hợp lệ, và chỉ write hợp lệ được nhận. Sau cycle đó FIFO phải có depth bằng 1 và entry vừa ghi phải đọc ra được.

Trường hợp thứ hai là FIFO đang full, testbench assert `wvalid` và `rready` cùng một cycle. Vì FIFO đang full nên `wready` phải bằng 0, write dư không được nhận, còn read hợp lệ được thực hiện. Sau cycle đó FIFO giảm xuống `Depth-1`, entry overflow không được xuất hiện khi drain, và thứ tự các entry còn lại phải đúng.

Test này quan trọng vì boundary empty/full có handshake khác với mid-depth. Nếu chỉ test near-empty hoặc near-full thì chưa chứng minh rõ behavior khi một phía handshake bị block bởi trạng thái biên chính xác.

### FIFO_008 - `fifo_csr_blocked_sw_write_boundaries`

Test này kiểm tra full-boundary từ góc nhìn software qua CSR, tập trung vào CMD và TX queue.

Testbench giữ controller idle hoặc disabled để hardware không consume CMD/TX trong lúc kiểm tra. Sau đó fill CMD queue bằng các write vào `CMD_QUEUE_PORT` và fill TX queue bằng các write vào `PIO_DATA_PORT`. Khi mỗi queue đã full, testbench thử ghi thêm một command hoặc một TX DWORD.

Kết quả mong đợi là write dư không được làm hỏng nội dung FIFO. Với CMD queue, staging hai DWORD phải giữ coherency: không được ghép nửa command cũ với nửa command mới, không duplicate descriptor, và không làm sai thứ tự command đã có. Với TX queue, pending write khi full phải được hold cho tới khi có space hoặc bị clear bởi software reset theo policy hiện tại; trong mọi trường hợp không được xuất hiện stale hoặc duplicate data sau recovery.

Test này quan trọng vì các FIFO test block-level có thể force trực tiếp handshake nội bộ, nhưng software thật nhìn thấy FIFO thông qua CSR. Full-boundary ở CSR path còn có thêm staging/pending register nên cần test riêng.

## 4.3 PHY, Bus Conditions, and Timing

Phần 4.3 kiểm tra lớp bus/PHY và các điều kiện timing cơ bản của I3C.

Nếu 4.1 kiểm tra register và 4.2 kiểm tra FIFO, thì 4.3 kiểm tra phần DUT thật sự tương tác với hai dây bus `SCL` và `SDA`. Các test trong phần này đảm bảo controller nhìn thấy START/STOP đúng, tạo clock đúng timing, truyền/nhận bit đúng thứ tự, và chọn đúng chế độ open-drain hoặc push-pull theo từng phase.

Thứ tự trình bày trong mục BUS được gom theo lớp kiểm tra: PHY input conditioning, bus monitor detection/filter/gating, SCL generation/timing, TX/RX bit primitive, rồi cuối cùng là OD/PP và pad/top-level wiring. ID testcase, assertion, coverpoint, và message trong vseq được reindex theo thứ tự này.

### BUS_001 - `phy_reset_and_sync`

Test này kiểm tra reset và bộ đồng bộ 2 flip-flop trong `i3c_phy`.

Tín hiệu `SCL` và `SDA` đến từ bên ngoài DUT, nên chúng là tín hiệu bất đồng bộ so với clock nội bộ của controller. Vì vậy PHY cần dùng synchronizer để đưa các tín hiệu này vào clock domain của DUT một cách ổn định.

Testbench dùng `bus_phy_reset_and_sync_vseq` để force trực tiếp input PHY quanh reset:

```text
SCL/SDA = 00, assert hard reset
release reset, vẫn giữ 00
SCL/SDA = 10
SCL/SDA = 01
SCL/SDA = 11
```

Kết quả mong đợi là sau reset, giá trị sampled của `SCL` và `SDA` trở về mức high, vì bus idle của I3C/I2C là cả hai dây đều high. Sau vài chu kỳ latency của synchronizer, tín hiệu controller nhìn thấy phải ổn định và đúng với input.

Pass/fail chính nằm trong `i3c_phy_sva`. Checker này kiểm tra từng tầng của synchronizer:

```text
SCL input ổn định => scl_ff1 giữ đúng giá trị sampled
scl_ff2 <= scl_ff1
SCL input ổn định qua cửa sổ đồng bộ => ctrl_scl_o đúng với input

SDA input ổn định => sda_ff1 giữ đúng giá trị sampled
sda_ff2 <= sda_ff1
SDA input ổn định qua cửa sổ đồng bộ => ctrl_sda_o đúng với input
```

Các cover chính gồm `cp_bus001_reset_sets_sync_idle` và các pattern `cp_bus001_sync_pattern_00/10/01/11`. Tính đúng của từng tầng và latency hai chu kỳ được kiểm tra bằng assertion `ap_bus001_*_matches_shadow` và `ap_bus001_*_two_cycle_settle`; không tạo cover equality-only vì trạng thái idle có thể làm chúng hit ngay.

Test này quan trọng vì nếu synchronizer sai, các block phía sau có thể phát hiện nhầm START/STOP hoặc đọc sai bit trên bus.

### BUS_002 - `bus_start_stop_detect`

Test này kiểm tra phát hiện điều kiện START và STOP trên bus.

Trong I3C/I2C, START xảy ra khi `SDA` chuyển từ high xuống low trong lúc `SCL` đang high. STOP xảy ra khi `SDA` chuyển từ low lên high trong lúc `SCL` đang high.

Testbench dùng vseq `bus_start_stop_detect_vseq` để drive trực tiếp input bus của monitor:

```text
SCL high, SDA: 1 -> 0  => START hợp lệ
SCL high, SDA: 0 -> 1  => STOP hợp lệ
SCL low,  SDA đổi mức  => không phải START/STOP
```

Kết quả mong đợi là START hợp lệ phải xuất hiện ở `state_o.start_det`, STOP hợp lệ phải xuất hiện ở `state_o.stop_det`, và cạnh SDA không được qualify bởi SCL stable-high thì không được latch candidate hoặc tạo trigger START/STOP.

Pass/fail chính nằm trong `bus_monitor_sva`, với các assertion/cover như `ap_bus002_valid_start_reports_start`, `ap_bus002_valid_stop_reports_stop`, `ap_bus002_sda_fall_when_scl_not_high_no_start_candidate`, `ap_bus002_sda_rise_when_scl_not_high_no_stop_candidate`, `ap_bus002_rejected_falling_edge_no_start_trigger`, và `ap_bus002_rejected_rising_edge_no_stop_trigger`.

Test này liên quan đến `bus_monitor`, `edge_detector`, `stable_high_detector`, và `bus_monitor_sva`.

### BUS_003 - `bus_repeated_start_detect`

Test này kiểm tra phát hiện repeated START, thường viết là `Sr`.

Repeated START là một START mới xuất hiện khi bus đã có START trước đó nhưng chưa có STOP. Nó được dùng trong các transaction cần chuyển phase mà không thả bus, ví dụ direct CCC hoặc một số read flow.

Test này thuộc về `bus_monitor`. Mục tiêu không phải là kiểm tra `scl_generator` tạo Sr đúng timing; phần đó thuộc BUS_009. Ở BUS_003, testbench chỉ cần tạo waveform bus tối thiểu: START đầu tiên, sau đó không tạo STOP, rồi tạo một START thứ hai. START thứ hai này phải được monitor phân loại là repeated START.

Kết quả mong đợi là START đầu tiên pulse `start_det`, START thứ hai trước STOP pulse `rstart_det`, và hai pulse này không được lẫn nhau. Sau khi STOP xuất hiện, trạng thái "đã thấy START" phải bị clear, để START kế tiếp không bị phân loại nhầm thành repeated START.

Implementation note: BUS_003 dùng vseq `bus_repeated_start_detect_vseq` để tạo directed waveform START -> Sr -> STOP. Checker chính nằm trong `bus_monitor_sva`, với các assertion/cover như `ap_bus003_first_start_classified_as_start`, `ap_bus003_repeated_start_classified_as_rstart`, `ap_bus003_stop_clears_rstart_detection`, và `cp_bus003_start_rstart_stop_sequence`.

### BUS_004 - `bus_monitor_glitch_and_simultaneous_edge_filter`

Test này kiểm tra bus monitor không báo nhầm START/STOP khi bus có glitch ngắn hoặc khi `SCL` và `SDA` đổi cùng lúc.

Theo spec của `bus_monitor`, START/STOP không chỉ dựa vào việc `SDA` đổi khi `SCL` đang high ở một sample đơn lẻ. RTL dùng candidate latch và edge detector có delay `T_R`/`T_F`, nên một glitch ngắn hơn delay cấu hình không được tạo event hợp lệ.

Testbench sẽ program `T_R` và `T_F` thành giá trị nonzero, enable bus monitor, rồi tạo các tình huống âm:

```text
SDA glitch low khi SCL high nhưng chưa đủ T_F
SDA glitch high khi SCL high nhưng chưa đủ T_R
SCL và SDA đổi cùng cycle
```

Kết quả mong đợi là không có pulse `start_det`, `stop_det`, hoặc `rstart_det` cho các tình huống trên. Nếu monitor đã latch candidate tạm thời, candidate đó phải được clear khi edge không được confirm. Sau các negative case, testbench tạo một START/STOP hợp lệ để chứng minh monitor vẫn hoạt động bình thường.

Test này quan trọng vì bus thật có thể có cạnh gần nhau hoặc nhiễu ngắn. Nếu monitor báo nhầm START/STOP, controller có thể đổi state sai giữa transaction.

### BUS_005 - `bus_monitor_enable_gating_and_edge_pulses`

Test này kiểm tra hai behavior còn lại của `bus_monitor`: enable gating và độ rộng pulse của edge/event output.

Đầu tiên testbench giữ monitor disabled, rồi drive các điều kiện START, STOP, và repeated START hợp lệ. Khi `enable_i=0`, monitor không được phát bất kỳ event pulse nào và các pending candidate phải bị clear.

Sau đó testbench enable monitor và drive các cạnh `SCL`/`SDA` hợp lệ. Các output edge như `scl.pos_edge`, `scl.neg_edge`, `sda.pos_edge`, `sda.neg_edge` phải pulse đúng một cycle. Tương tự, `start_det`, `stop_det`, và `rstart_det` cũng phải pulse đúng một cycle cho mỗi event hợp lệ, không được giữ level nhiều cycle.

Kết quả mong đợi là khi disabled thì hoàn toàn không có event; khi enabled thì mỗi cạnh/event hợp lệ tạo đúng một pulse một cycle. Không được có pulse trễ còn sót lại từ lúc monitor disabled.

Test này quan trọng vì các block phía sau thường dùng event pulse để trigger FSM transition. Nếu pulse bị kéo dài hoặc rò qua lúc disabled, controller có thể chạy nhầm nhiều bước hoặc bắt đầu transaction ở trạng thái không hợp lệ.

### BUS_006 - `scl_start_stop_timing`

Test này kiểm tra timing khi DUT tạo START và STOP.

START và STOP xuất hiện trong hầu hết transaction bình thường, ví dụ SDR write/read, CCC, DAA và I2C. Vì vậy test này không cần một vseq riêng để force block-level `scl_generator`.

Checker chính nằm trong `scl_generator_sva`. Các vseq transaction hiện có tạo stimulus tự nhiên; SVA quan sát local FSM và counter load bên trong `scl_generator`.

Kết quả mong đợi cho START:

- Khi có request START từ `Idle`, generator phải load `t_su_sta_i` và đi vào `GenerateStart`.
- `GenerateStart` giữ `SCL=1`, `SDA=1` trong setup window.
- `SdaFall` tạo START bằng cách kéo `SDA=0` khi `SCL=1`, rồi load `t_hd_sta_i`.
- `HoldStart` giữ START đủ thời gian, sau đó load `active_t_low + t_f_i`, đi vào `DriveLow`, và pulse `done_o`.

Kết quả mong đợi cho STOP:

- STOP request phải đi vào `GenerateStop` và load low/fall delay.
- `GenerateStop` giữ `SDA=0` trong lúc chuẩn bị release `SCL`.
- Khi `SCL` đã high, generator load `t_su_sto_i` và đi qua `SclHighForStop`.
- `SdaRise` tạo STOP bằng cách release `SDA=1` khi `SCL=1`, rồi load `t_bus_free_i`.
- `BusFree` hết counter thì về `Idle` và pulse `done_o`.

Test này quan trọng vì bus target sẽ dựa vào timing vật lý này để hiểu transaction.

### BUS_007 - `scl_clock_low_high_timing`

Test này kiểm tra chu kỳ low/high của clock `SCL`.

Timing register có thể được program nhiều giá trị khác nhau như `t_low`, `t_low_od`, `t_high`, `t_r`, và `t_f`. Testbench dùng stimulus tập trung cho `scl_generator` để chạy nhiều timing profile: PP-low, PP-low bị kéo dài, OD-low, và profile tương đương I2C.

Kết quả mong đợi là generator chọn đúng timing source và load đúng counter:

- Khi `scl_use_od_low_i=0`, low delay dùng `t_low`.
- Khi `scl_use_od_low_i=1`, low delay dùng `t_low_od`.
- Khi kết thúc `DriveLow` và còn request clock, generator phải load `t_high + t_r` rồi đi qua `DriveHigh`.
- Khi kết thúc `DriveHigh` và còn request clock, generator phải load `active_t_low + t_f` rồi quay lại `DriveLow`.

Checker chính nằm trong `scl_generator_sva`, còn vseq `bus_scl_clock_low_high_timing_vseq` chỉ tạo các profile timing để cover cả low-mode PP và OD. Test này liên quan đến `scl_generator` và `csr_registers`, vì register lưu timing còn generator dùng timing đó để tạo clock.

### BUS_008 - `scl_waitcmd_stall_resume`

Test này kiểm tra behavior `scl_generator` giữ `SCL` low khi đã tạo START xong nhưng chưa có command clock tiếp theo.

```text
WaitCmd hold/resume: no command -> hold SCL low, gen_clock_i -> resume clock
```

Với BUS_008, vseq chỉ cần tạo stimulus nhỏ cho `scl_generator`: pulse START, giữ `gen_clock_i=0` để generator đi vào `WaitCmd`, chờ một khoảng thời gian, rồi assert `gen_clock_i=1` để resume clock. Không cần transaction-level SDR read/write và không cần scoreboard FIFO.

Checker chính nằm trong `scl_generator_sva`:

- Khi `state_q == WaitCmd` và không có `gen_clock_i`, `gen_stop_i`, `gen_rstart_i`, `gen_idle_i`, FSM phải giữ `WaitCmd`.
- Trong `WaitCmd`, `SCL` phải bị kéo low, `SDA` được release, và `done_o` không được assert.
- Khi `gen_clock_i=1` trong `WaitCmd`, FSM phải resume qua `DriveLow` và load delay `active_t_low + t_f`.

Test này quan trọng vì `WaitCmd` là điểm generator cố ý park bus low để higher-level controller quyết định bước tiếp theo. Nếu logic này sai, bus có thể release clock quá sớm hoặc không resume đúng khi command tiếp theo đến.

### BUS_009 - `scl_repeated_start_from_waitcmd`

Test này kiểm tra khả năng tạo repeated START khi clock đang bị giữ low hoặc đang ở trạng thái wait.

Một số flow như ENTDAA hoặc directed CCC có thể cần repeated START giữa các phase. Nếu lúc đó generator đang ở low/wait state, logic vẫn phải tạo `Sr` đúng timing và không treo bus.

Testbench sẽ đưa controller vào flow ENTDAA hoặc directed CCC, sau đó yêu cầu repeated START trong lúc generator đang ở trạng thái low/wait.

Kết quả mong đợi là repeated START được tạo hợp lệ, timing đúng, và controller không bị kẹt ở trạng thái chờ.

Implementation note: BUS_009 dùng vseq `bus_scl_repeated_start_from_waitcmd_vseq` để tạo stimulus đưa `scl_generator` vào `WaitCmd` rồi request `gen_rstart_i`. Checker chính là `scl_generator_sva`, với các assertion/cover như `ap_bus009_waitcmd_rstart_enters_generate_rstart`, `ap_bus009_generate_rstart_holds_scl_low`, `ap_bus009_rstart_sda_fall_drives_sr`, `cp_bus009_waitcmd_to_rstart`, và `cp_rstart_state_sequence`.

### BUS_010 - `bus_tx_byte_and_bit_order`

Test này kiểm tra thứ tự bit khi DUT truyền data ra bus ở mức bus primitive.

Trong I3C/I2C, byte được truyền MSB-first, nghĩa là bit 7 đi trước, sau đó bit 6, ..., cuối cùng là bit 0.

Testbench gửi các pattern dễ quan sát:

```text
00, FF, A5, 96
```

Các pattern `A5` và `96` hữu ích vì bit 1/0 xen kẽ, giúp phát hiện lỗi đảo bit hoặc dịch sai thứ tự.

Kết quả mong đợi là `bus_tx` serialize byte theo MSB-first. Với mỗi request truyền byte hoặc truyền bit đơn, `bus_tx_done_o` chỉ pulse một lần khi hoàn tất. Timing setup/hold của `SDA` so với `SCL` cũng phải đúng.

Test này được giữ trong BUS category vì nó tập trung vào behavior của TX bus path. Các SDRW transaction khác vẫn kiểm tra flow-level như length, continuation, DAT index, và response ordering.

### BUS_011 - `bus_rx_byte_and_bit_order`

Test này kiểm tra thứ tự bit khi DUT nhận data từ bus ở mức bus primitive.

Device model drive `SDA` với các byte pattern và ACK/NACK bit. DUT phải deserialize các bit nhận được thành byte đúng theo MSB-first.

Ví dụ nếu target drive byte `8'hA5`, DUT phải reconstruct đúng `8'hA5`, không được thành giá trị bị đảo bit hoặc shift sai.

Với single-bit read như ACK/NACK hoặc T-bit, testplan yêu cầu bit đọc được nằm ở `bit[0]`. Ngoài ra mutual exclusion SVA phải pass, nghĩa là logic không được vừa read byte vừa read bit theo cách xung đột.

Test này được giữ trong BUS category vì nó tập trung vào behavior của RX bus path. Các SDRR transaction khác vẫn kiểm tra flow-level như length, over-run termination, continuation, DAT index, và response ordering.

### BUS_012 - `od_pp_phase_switch`

Test này kiểm tra việc chọn chế độ open-drain hoặc push-pull theo từng phase của transaction.

I3C dùng cả hai kiểu drive bus:

```text
OD: open-drain, an toàn cho address/ACK/START/STOP và arbitration
PP: push-pull, nhanh hơn, dùng cho một số data phase của I3C SDR
```

Testbench sẽ chạy I3C write/read transfer và quan sát `sel_od_pp_o` qua các phase như START, address, ACK, data, T-bit, và STOP.

Kết quả mong đợi là OD được dùng cho START/address/ACK/STOP và ENTDAA. PP chỉ được dùng ở các data phase I3C SDR nằm trong scope được project spec định nghĩa.

Test này quan trọng vì chọn sai OD/PP có thể gây xung đột điện trên bus hoặc làm sai behavior so với protocol.

Implementation note: BUS_012 không cần vseq riêng. Stimulus đã có từ các vseq SDRW/SDRR, I2C, CCC, và ENTDAA hiện hữu; phần pass/fail chính nằm ở SVA `ap_sel_od_pp_matches_expected` trong `flow_active_sva`, với expectation tính theo state/phase/device type.

### BUS_013 - `tb_pad_model_odpp_wiring`

Test này kiểm tra pad model trong testbench sau khi DUT đã có `sda_oe_o` và `sel_od_pp_o`.

`sel_od_pp_o` cho biết bus đang ở mode open-drain hay push-pull. `sda_oe_o` cho biết DUT có đang thật sự drive SDA hay không. Hai signal này khác nhau và đều cần thiết để testbench model SDA đúng.

Testbench sẽ quan sát `sda_oe_o`, `sda_o`, `sel_od_pp_o`, và `sda_bus` trong các transaction I3C write/read hiện có.

Kết quả mong đợi là `tb_i3c_top` chỉ drive SDA khi `sda_oe_o=1`. Khi `sda_oe_o=0`, testbench phải release SDA về `Z` để pull-up hoặc target có thể điều khiển bus.

Ví dụ trong I3C write data phase, DUT có thể dùng push-pull và drive SDA trực tiếp. Nhưng trong I3C read data phase, target là bên drive data, nên DUT phải release SDA dù data phase đang là push-pull.

Test này quan trọng vì nếu pad model drive SDA sai thời điểm, simulation có thể che mất lỗi thật hoặc tạo contention giả trên bus.

Implementation note: BUS_013 dùng cả vseq và SVA. Vseq `bus_tb_pad_model_odpp_wiring_vseq` tạo I3C write/read traffic để exercise controller-drive, controller-release, và target-drive path. SVA `tb_pad_model_sva` là checker chính, với các hook `ap_bus013_if_exposes_dut_pad_signals`, `ap_bus013_no_unsafe_sda_contention`, và các cover `cp_bus013_*` để map rõ về testplan.

### BUS_014 - `bus_i2c_od_only_check`

Test này kiểm tra I2C legacy transfer không bao giờ bật push-pull mode.

Trong thiết kế này, DAT entry có bit `device=1` được xem là I2C legacy target. Với I2C, controller phải giữ open-drain trong toàn bộ transaction: START, address, ACK, data byte, final NACK, và STOP. I2C không dùng push-pull data phase như I3C SDR.

Testbench sẽ program một DAT entry là I2C device với static address hợp lệ, sau đó chạy cả I2C write và I2C read. Trong suốt transaction, testbench quan sát `sel_od_pp_o`, `sda_oe_o`, `sda_o`, và bus SDA thực tế.

Kết quả mong đợi là `sel_od_pp_o` luôn bằng 0 trong toàn bộ I2C transaction. Khi DUT cần kéo SDA low, nó dùng open-drain low. Khi line cần high hoặc target drive ACK/data, DUT phải release SDA đúng lúc. Không được có phase nào DUT chuyển sang push-pull.

Test này bổ sung cho `BUS_012`: `BUS_012` chứng minh I3C SDR có phase được phép dùng push-pull, còn `BUS_014` chứng minh I2C legacy không dùng push-pull. Hai test này tạo cross-coverage giữa OD/PP phase và device type.

Implementation note: BUS_014 không cần vseq riêng. Stimulus I2C write/read đã có trong `i2c_regular_write_basic_vseq` và `i2c_regular_read_basic_vseq`; phần pass/fail chính được check bằng SVA `ap_bus014_i2c_regular_xfer_never_push_pull` trong `flow_active_sva` và top-level propagation SVA trong `i3c_controller_top_sva`.

### BUS_015 - `start_when_bus_not_idle`

Test này kiểm tra behavior khi software queue command trong lúc bus chưa idle.

Trước khi issue command, testbench giữ `SCL` hoặc `SDA` ở trạng thái non-idle, tức không phải cả hai đều high. Sau đó queue một command bình thường.

Kết quả mong đợi là controller phải chờ Bus Available/Idle hoặc báo lỗi theo policy đã được specification hóa. Nếu hardware không support case này, software precondition phải yêu cầu chỉ queue command khi bus idle.

Test này quan trọng vì controller bắt đầu START trên bus không idle có thể làm target hiểu sai frame hoặc gây contention. Đây hiện là specification gap và chưa được tính là positive sign-off coverage.

## 4.4 I3C SDR Private Write

Phần 4.4 kiểm tra I3C SDR private write, nghĩa là controller ghi data đến một I3C target thông qua dynamic address trong DAT.

Các test trong phần này tập trung vào regular write path: command được lấy từ CMD FIFO, data được lấy từ TX FIFO, controller phát địa chỉ private I3C, truyền các byte data, tạo T-bit, rồi ghi response vào RESP FIFO. Với `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0`, transfer bắt đầu trực tiếp bằng `dynamic_address + W`. Với bit này bằng 1, transfer private mới phải có preamble `0x7e/W + ACK + Sr` trước khi phát dynamic address.

### SDRW_001 - `i3c_regular_write_4b_existing`

DAT[0] được cấu hình là I3C device với dynamic address `0x08`, `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0`. Target ACK địa chỉ và ACK các phase cần thiết. Testbench chạy `i3c_write_vseq` với TX word `32'hDEAD_BEEF`.

Kết quả mong đợi là controller phát transaction write bắt đầu trực tiếp bằng `START + 0x08/W + ACK`, không được phát `0x7e` preamble. Bốn byte data được lấy từ TX word theo packing contract của TX FIFO trong project spec.

RESP trả về phải là success và length bằng 4. Test này quan trọng vì đây là baseline để biết regular I3C write path vẫn tuân thủ spec sau các thay đổi khác.

### SDRW_002 - `i3c_regular_write_len_sweep`

Test này kiểm tra nhiều độ dài write khác nhau, cách TX FIFO được pack thành byte trên bus, và framing của private write khi bật broadcast header.

Testbench sẽ chạy các length 0, 1, 2, 3, 4, 5, 7, 8, 16, 64, và 256 byte ở cả hai mode: `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0` và `HC_CONTROL[BROADCAST_ADDR_ENABLE]=1`. Data trong TX FIFO dùng pattern dễ kiểm tra để biết byte nào phải xuất hiện trên bus trước.

Kết quả mong đợi là controller truyền đúng số byte được yêu cầu, không thiếu byte và không dư byte. Với length 0, controller chỉ phát address, nhận ACK, rồi STOP; không được phát data byte hoặc T-bit, và RESP báo Success length 0. Với length 256, testbench nạp đúng 64 TX DWORD và kiểm tra toàn bộ payload theo thứ tự. Với các length không chia hết cho 4, byte cuối cùng vẫn phải lấy đúng từ DWORD tương ứng trong TX FIFO. Khi broadcast header bị tắt, transaction phải bắt đầu trực tiếp bằng `START + 0x08/W`; khi broadcast header được bật, bus phải có preamble `START + 0x7e/W + ACK + Sr + 0x08/W` trước data phase.

RESP length phải bằng số byte thật sự đã truyền. Test này quan trọng vì lỗi ở boundary DWORD rất dễ xảy ra khi data length là 1, 2, 3, 5, hoặc 7 byte.

Directed regression không chạy full length 65535 byte vì runtime cao. Case đó được giữ làm future stress/performance test; length 256 đã cover boundary lớn hơn với 64 DWORD liên tiếp trong regression thường.

SDR write T-bit parity không còn là một directed test riêng. Behavior này được assert bằng SVA `ap_sdr_write_tbit_parity`, cover bằng `cp_sdr_write_tbit_parity`, `cp_sdr_write_tbit_parity_one`, và `cp_sdr_write_tbit_parity_zero`, rồi được exercise tự nhiên bởi các SDRW test có payload random/pattern.

### SDRW_003 - `i3c_write_toc_zero`

Test này kiểm tra behavior continuation của regular SDR I3C write khi command đầu tiên có `toc=0`.

`toc` là bit "terminate on completion". Với `toc=1`, controller kết thúc transfer bằng STOP. Với `toc=0`, project descriptor spec định nghĩa continuation cho SDR regular I3C transfer: controller không tạo STOP sau byte data cuối cùng, mà tạo Repeated START (`Sr`) để nối sang command regular SDR I3C tiếp theo đang có sẵn trong CMD FIFO.

Testbench queue hai regular write command đến cùng I3C target. Command thứ nhất có `toc=0`, length 2 byte. Command thứ hai có `toc=1`, length 2 byte. Cả hai command đều được queue trước khi transaction đầu tiên kết thúc để controller có thể tạo continuation ngay tại boundary sau T-bit cuối cùng.

Testbench cũng chạy negative subcase trong đó command đầu tiên có `toc=0` nhưng không có command regular SDR I3C tiếp theo trong CMD FIFO.

Test chạy cả hai mode private address: `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0` và `HC_CONTROL[BROADCAST_ADDR_ENABLE]=1`.

Kết quả mong đợi trên bus là command thứ nhất truyền address, ACK, data bytes và T-bit bình thường, sau đó tạo `Sr` thay vì STOP. Ngay sau `Sr`, controller phát address cho command thứ hai, tiếp tục truyền data của command thứ hai, rồi chỉ tạo STOP ở cuối command thứ hai vì command này có `toc=1`.

Với `BROADCAST_ADDR_ENABLE=1`, command đầu tiên là private I3C transfer mới nên controller phải phát preamble `START + 0x7e/W + ACK + Sr`, rồi mới phát dynamic address của target. Nhưng command thứ hai là continuation trong cùng private sequence, nên sau `Sr` controller phải đi thẳng đến dynamic address của command thứ hai và không được phát lại `0x7e/W + ACK + Sr` trước command continuation.

RESP của cả hai command phải báo Success, TID phải khớp từng command, và length phải bằng số byte đã truyền. Bus không được idle giữa command thứ nhất và command thứ hai; idle chỉ được quan sát sau STOP cuối cùng.

Trong negative subcase, command đầu tiên vẫn phải truyền đủ data/T-bit đã yêu cầu, sau đó controller phát STOP thay vì Repeated START. RESP phải báo `NotSupported` với length bằng số byte thật sự đã truyền, kể cả khi command đặt `wroc=0`, vì missing continuation là error. Khi `BROADCAST_ADDR_ENABLE=1`, chỉ transfer đầu tiên có broadcast-header preamble; không được phát một preamble rỗng hoặc treo bus khi không có continuation hợp lệ.

Test này quan trọng vì `toc=0` ảnh hưởng trực tiếp đến ownership của bus và sequencing giữa nhiều SDR private transfer trong cùng một frame. Nếu controller tạo STOP quá sớm, transfer bị tách frame sai. Nếu controller không tạo được `Sr`, không lấy command kế tiếp đúng lúc, hoặc phát lại `0x7e` ở mỗi continuation, continuation flow sẽ sai so với semantics đã specification hóa.

### SDRW_004 - `i3c_write_back_to_back`

Test này kiểm tra nhiều regular write command chạy liên tiếp.

Testbench queue nhiều write command với TID khác nhau và data khác nhau trong TX FIFO. Các command phải được thực thi theo đúng thứ tự FIFO.

Kết quả mong đợi là command đầu tiên dùng đúng data đầu tiên, command thứ hai dùng đúng data tiếp theo, và cứ tiếp tục như vậy. Không được có stale TX data từ command trước rơi sang command sau.

Mỗi RESP phải có TID và length khớp với command tương ứng. Scoreboard phải match đúng thứ tự command/response.

Test này quan trọng vì hệ thống thực tế thường không chỉ chạy một command đơn lẻ. Back-to-back command giúp phát hiện lỗi state cleanup, FIFO pointer, và response ordering.

### SDRW_005 - `i3c_write_multi_dat_idx`

Test này kiểm tra controller chọn đúng DAT entry khi regular SDR private write dùng `dev_idx` khác nhau.

Testbench program `DAT[0]` là I3C device có dynamic address `0x08`, và `DAT[1]` là I3C device có dynamic address `0x12`. Sau đó testbench queue một write tới `dev_idx=0` và một write tới `dev_idx=1`, với TID và payload khác nhau. Directed case hiện tại chạy ở private-address mode trực tiếp (`BROADCAST_ADDR_ENABLE=0`); biến thể broadcast-header DAT[1] được giữ làm future extension, còn framing broadcast-header đã được cover ở các SDRW khác với DAT[0].

Kết quả mong đợi là bus thấy address theo đúng thứ tự `0x08/W` rồi `0x12/W`. Data payload của từng command phải đúng với TX FIFO data tương ứng, không được lấy nhầm payload giữa hai DAT index. RESP của mỗi command phải báo Success, TID đúng, length đúng, và tất cả queue empty sau test.

Ngoài các case hai target, test chạy thêm một sweep xác định qua `dev_idx=0..31`. Mỗi DAT entry được program một dynamic address hợp lệ riêng, sau đó một write bốn byte được thực thi và hoàn tất trước khi chuyển sang index tiếp theo. Sweep này đóng đủ các bin command DAT index mà không làm thay đổi TID hoặc các scenario selector của những directed case khác.

Test này quan trọng vì DAT index là contract giữa software command descriptor và hardware target lookup. Nếu controller luôn dùng DAT[0] hoặc giữ stale address từ command trước, các transfer multi-target sẽ đi sai device dù FIFO và data path vẫn có vẻ hoạt động.

## 4.5 I3C SDR Private Read

Phần 4.5 kiểm tra I3C SDR private read, nghĩa là controller đọc data từ một I3C target thông qua dynamic address trong DAT.

Các test trong phần này tập trung vào regular read path: command được lấy từ CMD FIFO, controller phát địa chỉ private I3C, nhận các byte data do target drive trên bus, xử lý T-bit của read phase, pack data vào RX FIFO, rồi ghi response vào RESP FIFO. Tương tự write path, `BROADCAST_ADDR_ENABLE=0` nghĩa là bắt đầu trực tiếp bằng dynamic address; `BROADCAST_ADDR_ENABLE=1` nghĩa là private transfer mới bắt đầu bằng `0x7e/W + ACK + Sr` rồi mới tới dynamic address với direction read.

### SDRR_001 - `i3c_regular_read_4b_existing`

Test này giữ lại regression read hiện có.

DAT[0] được cấu hình là I3C device với dynamic address `0x08`, `HC_CONTROL[BROADCAST_ADDR_ENABLE]=0`. Target ACK địa chỉ read và trả về bốn byte data. Testbench chạy `i3c_read_vseq`.

Kết quả mong đợi là controller thực hiện transaction read bắt đầu trực tiếp bằng `START + 0x08/R + ACK`, không phát `0x7e` preamble. Bốn byte nhận được được pack vào RX FIFO theo packing contract của RX FIFO trong project spec.

RX FIFO word mong đợi là `32'hBEBA_FECA`, và RESP trả về phải là success với length bằng 4.

Test này quan trọng vì đây là baseline để biết regular I3C read path vẫn tuân thủ spec, bao gồm address phase, data receive phase, RX FIFO packing, và response generation.

Case baseline chạy cả hai private-address mode. Khi `BROADCAST_ADDR_ENABLE=1`, frame phải bắt đầu bằng `START + 0x7e/W + ACK + Sr + 0x08/R`; khi bit này bằng 0, controller đi thẳng tới dynamic address.

### SDRR_002 - `i3c_regular_read_len_sweep`

Test này kiểm tra nhiều độ dài read khác nhau và cách RX FIFO pack byte thành DWORD.

Target được cấu hình để trả đủ số byte mà controller yêu cầu. Testbench sẽ chạy các length như 1, 2, 3, 4, 5, 7, 8, và 16 byte.

Kết quả mong đợi là RX FIFO chứa đúng toàn bộ byte target đã trả về, theo thứ tự little-endian DWORD packing. Với các length không chia hết cho 4, DWORD cuối cùng là partial DWORD và vẫn phải giữ đúng các byte hợp lệ.

Ví dụ nếu read 3 byte, controller không được đợi đủ 4 byte mới ghi RX FIFO, cũng không được làm mất byte cuối cùng. Nếu read 5 byte, byte thứ 5 phải nằm trong DWORD tiếp theo đúng vị trí.

Test này quan trọng vì lỗi partial DWORD rất dễ xảy ra ở read path, đặc biệt khi length là 1, 2, 3, 5, hoặc 7 byte.

### SDRR_003 - `i3c_read_target_more_than_requested`

Test này kiểm tra trường hợp target vẫn muốn gửi tiếp data sau khi controller đã nhận đủ số byte yêu cầu.

Testbench request đọc `N` byte, trong khi target model được cấu hình như thể còn data để gửi tiếp và T-bit vẫn chỉ continuation sau byte thứ `N`.

Kết quả mong đợi là controller phải dừng đúng sau `N` byte. Nếu `toc=1`, controller tạo STOP để kết thúc transaction. Không được ghi thêm byte thứ `N+1` vào RX FIFO.

Nói cách khác, requested length của command là giới hạn mà controller phải tôn trọng, kể cả khi target còn có thể cung cấp thêm data.

Test này quan trọng vì nếu controller đọc dư byte, RX FIFO sẽ chứa data ngoài mong muốn và response length sẽ không còn khớp với command.

### SDRR_004 - `i3c_read_toc_zero`

Test này kiểm tra behavior continuation của regular SDR I3C read khi command đầu tiên có `toc=0`.

Trong scope project hiện tại, `toc=0` continuation được định nghĩa cho SDR regular I3C private transfer, bao gồm cả write và read. Vì vậy read path cũng cần test riêng, không chỉ dựa vào `SDRW_003`.

Testbench queue hai command đến cùng I3C target. Command thứ nhất là regular read với `toc=0`, length 2 byte. Target trả về hai byte hợp lệ và T-bit cuối báo kết thúc đúng tại requested length. Command thứ hai là regular write với `toc=1`, length 2 byte, và command này đã nằm sẵn trong CMD FIFO trước khi read đầu tiên kết thúc.

Kết quả mong đợi là controller nhận đúng hai byte read, ghi đúng vào RX FIFO, rồi tạo Repeated START (`Sr`) thay vì STOP sau T-bit cuối của read command. Ngay sau `Sr`, controller phát address cho write command thứ hai, truyền data của command thứ hai, và chỉ tạo STOP ở cuối command thứ hai vì command này có `toc=1`.

RESP của read command phải báo Success với TID và length đúng. RESP của write command cũng phải báo Success với TID và length đúng. Bus không được idle hoặc tạo STOP giữa read đầu tiên và write thứ hai; boundary hợp lệ giữa hai command là `Sr`.

Test này quan trọng vì read termination có thêm RX FIFO packing và T-bit semantics, nên không thể chỉ dùng write `toc=0` để kết luận read continuation đã đúng. Nếu controller flush RX data sai thời điểm, tạo STOP quá sớm, hoặc không tạo được `Sr`, response và bus sequencing đều có thể sai.

### SDRR_005 - `i3c_read_back_to_back`

Test này kiểm tra nhiều regular SDR private read được queue liên tiếp, tương tự coverage back-to-back của write path.

Testbench cấu hình DAT[0] là một I3C target, rồi queue ba read command đến cùng target trước khi enable controller. Ba command dùng length khác nhau, ví dụ 3, 5, và 4 byte, và mỗi command có TID riêng. Target model trả về payload khác nhau cho từng command để dễ phát hiện lỗi trộn data.

Kết quả mong đợi là controller xử lý ba command theo đúng FIFO order. Vì cả ba command đều có `toc=1`, mỗi read là một transfer độc lập và phải kết thúc bằng STOP; không được tạo Repeated START giữa các read độc lập này.

RX FIFO phải chứa data theo đúng boundary của từng command. Khi testbench drain RX FIFO theo thứ tự command, payload của command thứ nhất chỉ chứa data của read thứ nhất, payload của command thứ hai chỉ chứa data của read thứ hai, và payload của command thứ ba chỉ chứa data của read thứ ba. Không được có byte bị rơi, duplicate, hoặc lẫn từ command trước/sau.

RESP metadata phải giữ đúng thứ tự command, đặc biệt là TID và length tương ứng với từng read đã queue. Sau khi test hoàn tất, CMD, TX, RX, và RESP queue đều phải empty.

Test này quan trọng vì read back-to-back dùng RX FIFO và RESP FIFO nhiều hơn write path. Nếu controller pop command sai thời điểm, pack partial DWORD sai, hoặc không giữ boundary giữa các read, lỗi sẽ xuất hiện dưới dạng RX data bị trộn hoặc response không còn khớp với command.

### SDRR_006 - `i3c_read_multi_dat_idx`

Test này kiểm tra regular SDR private read chọn đúng DAT entry khi command dùng nhiều `dev_idx`.

Testbench program hai DAT entry với dynamic address khác nhau, chạy các read độc lập, rồi chạy một cặp read continuation `toc=0` sang `toc=1`.

Kết quả mong đợi là mỗi command phát đúng dynamic address của DAT entry được chọn, RX data của từng target giữ đúng thứ tự và không bị trộn. Cặp continuation tạo đúng một Repeated START, chuyển sang target tiếp theo, và tất cả queue được drain sạch.

Test này quan trọng vì nó kiểm tra đồng thời DAT lookup, RX FIFO ordering và việc thay đổi target tại continuation boundary.

## 4.6 Immediate Data Transfer

Phần 4.6 kiểm tra immediate data transfer, nghĩa là data payload được nhúng trực tiếp trong command descriptor thay vì lấy từ TX FIFO.

Trong thiết kế này, immediate path chủ yếu áp dụng cho write-style command. Controller đọc command từ CMD FIFO, decode các field immediate như `dtt`, lấy inline data từ chính descriptor, phát địa chỉ target, truyền data byte ra bus, rồi ghi response vào RESP FIFO. Vì data không đi qua TX FIFO, các test trong phần này cần kiểm tra rõ rằng controller không đọc nhầm TX FIFO và vẫn xử lý address, STOP, NACK, và device type đúng.

### IMM_001 - `i3c_immediate_write_smoke_existing`

Test này giữ lại smoke regression hiện có cho I3C immediate write.

DAT[0] được cấu hình là I3C device, target ACK địa chỉ và các phase cần thiết. Testbench chạy `i3c_imm_vseq`, trong đó command immediate chứa hai byte data inline.

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

Với `toc=0`, test không nên tự suy ra một continuation hợp lệ như `SDRW_003`. Đây là clarification/negative case cho đến khi project spec định nghĩa policy. Policy được chấp nhận cho sign-off phải là một hành vi rõ ràng như reject/abort với error response hoặc force STOP; điểm quan trọng là controller không được để bus treo ở trạng thái không có STOP cũng không có `Sr`, và không được tự ý nối sang command kế tiếp bằng waveform sai.

Test này quan trọng vì `toc` xuất hiện trong descriptor immediate, nhưng MIPI I3C spec chỉ định bus-level START, Repeated START và STOP, không định nghĩa trực tiếp khái niệm Immediate descriptor. Vì vậy test này dùng để khóa policy của project spec, còn test chứng minh `toc=0` continuation hợp lệ nằm ở regular SDR private transfer.

### IMM_004 - `i2c_immediate_write_basic`

Test này kiểm tra immediate path khi DAT entry là legacy I2C device.

DAT[0].`device` được set bằng 1 và static address được program. Testbench issue I2C immediate write với độ dài từ 1 đến 4 byte.

Kết quả mong đợi là controller dùng static address với direction write, không dùng dynamic address của I3C. Toàn bộ transaction phải chạy ở open-drain mode theo I2C legacy semantics.

Target ACK địa chỉ và các data byte. RESP length phải bằng đúng số byte đã truyền, và response phải là success.

Test này quan trọng vì cùng một immediate command path có thể phục vụ cả I3C và I2C tùy theo DAT. Nếu decode device type sai, controller có thể dùng sai địa chỉ hoặc sai OD/PP mode.

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

Các test trong phần này tập trung vào cả success path và các corner case: không có device, số device ít hơn `dev_count`, tăng DAT index qua nhiều round, parity của assigned address, target reject address, boundary của DAT, và arbitration nhiều target. Abort giữa round được gom vào nhóm error/recovery `ERR_009` vì đó là HC abort behavior chung, không phải positive DAA flow. Việc capture PID/BCR/DCR và pack DAA result vào RX FIFO là một phần bắt buộc của success path DAA_001, không phải một test độc lập.

### DAA_001 - `entdaa_single_device_success`

Test này kiểm tra đầy đủ một round ENTDAA thành công với một target, bao gồm capture identity và đường DAA result software-visible.

DAT[0] chứa dynamic address cần gán. Target model drive các giá trị PID, BCR, DCR đã biết trước và ACK assigned address. Testbench issue `AddressAssignment` với `dev_idx=0` và `dev_count=1`.

Kết quả mong đợi là ENTDAA frame hoàn tất đầy đủ. PID/BCR/DCR được capture đúng giá trị và đúng thứ tự byte mà target đã drive. Controller gửi assigned address byte đúng với dynamic address trong DAT[0], bao gồm parity bit đúng. Target ACK address đó.

RESP phải báo `Success` với length 12. DAA result software-visible phải được ghi vào RX FIFO theo đúng ba DWORD:

- `PID[47:16]`
- `{PID[15:0], BCR[7:0], DCR[7:0]}`
- `{25'h0, DA[6:0]}`

Scoreboard so sánh dữ liệu RX FIFO với identity quan sát được trên bus. Assertion `ap_entdaa_done_outputs_id_fields` kiểm tra trực tiếp các output PID/BCR/DCR của `entdaa_fsm` so với shift register đã capture.

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

Test này kiểm tra việc tăng DAT index và xử lý một chuỗi winner ENTDAA đã được resolve qua nhiều round.

Testbench tạo nhiều target identity, sort theo `{PID,BCR,DCR}` tăng dần để tạo thứ tự winner hợp lệ, rồi dùng một device-response item cho mỗi winner. Sau đó test program nhiều DAT entry liên tiếp và issue `AddressAssignment` với `dev_idx=N` và `dev_count=K`.

Kết quả mong đợi là controller dùng đúng DAT index cho từng round: `N`, `N+1`, ..., `N+K-1`. Mỗi round sau round đầu phải bắt đầu bằng repeated START, và RX FIFO phải chứa PID/BCR/DCR theo đúng thứ tự winner đã resolve.

Nếu có đủ `K` target phản hồi, controller phải assign đủ `K` dynamic address theo đúng thứ tự DAT.

Test này không kiểm tra một thuật toán arbitration nằm trong controller. Controller chỉ quan sát identity winner trên SDA. Test tập trung vào việc controller capture đúng winner, tăng DAT index đúng và tiếp tục đủ các ENTDAA round.

### DAA_005 - `covered_by_sva_no_vseq`

Test này kiểm tra parity bit của assigned address trong ENTDAA.

DAA_005 không có dedicated vseq. Stimulus được tái sử dụng từ các ENTDAA vseq như DAA_001 và DAA_004, kết hợp nhiều regression seed để tạo các dynamic address đại diện: địa chỉ thấp, địa chỉ cao, pattern xen kẽ bit 0/1, và các giá trị random hợp lệ khác.

Kết quả mong đợi là controller gửi assigned address theo format `{dynamic_addr[6:0], PAR}`. Bit `PAR` phải là odd parity của 7-bit dynamic address: `PAR = ~^dynamic_addr[6:0]`. Nói cách khác, tổng số bit `1` trong `{dynamic_addr[6:0], PAR}` phải là số lẻ.

`ap_entdaa_send_addr_value` kiểm tra công thức này ở mọi lần FSM gửi assigned address. Scoreboard kiểm tra parity thực tế quan sát được trên bus. Covergroup trong `entdaa_fsm_sva` thu coverage cho nhóm địa chỉ low, high, alternating, nhóm còn lại, cả hai giá trị parity, và cross giữa nhóm địa chỉ với parity.

Coverage DAA_005 chỉ được close khi assertion pass và các functional coverage bin yêu cầu đã hit; việc một ENTDAA vseq đơn lẻ pass không đủ để close mục tiêu này. Test này quan trọng vì parity sai có thể làm target reject assignment dù địa chỉ chính đúng.

### DAA_006 - `entdaa_address_rejected`

Test này kiểm tra trường hợp target nhận PID/BCR/DCR phase bình thường nhưng NACK assigned address.

Target ACK `7'h7E+R`, drive PID/BCR/DCR đầy đủ, nhưng khi controller gửi assigned address, target NACK.

Kết quả mong đợi là `addr_valid_o` không được assert, vì address assignment không thành công. Controller sau đó tiếp tục loop hoặc kết thúc theo policy đã specification hóa cho `dev_count` và no-device path.

Không được ghi nhận target là đã được assign address nếu target đã NACK address byte.

Test này quan trọng vì target có quyền từ chối assigned address. Controller phải phân biệt rõ capture identity thành công với assignment thành công.

### DAA_007 - `entdaa_dat_boundary`

Test này kiểm tra boundary của DAT khi ENTDAA bắt đầu gần cuối table.

DAT trong thiết kế có 32 entry, được đánh index từ 0 đến 31. Testbench program `dev_idx` tại entry cuối là `dev_idx=31`. Sau đó chạy hai case: `dev_idx=31`, `dev_count=1`; và `dev_idx=31`, `dev_count>1`.

Kết quả mong đợi là case `dev_idx=31`, `dev_count=1` hoạt động đúng và sử dụng DAT[31]. Với case `dev_idx=31`, `dev_count=2`, tổng `dev_idx+dev_count=33` lớn hơn `DatDepth=32`, nên descriptor không hợp lệ.

Controller phải reject toàn bộ command ngay trong `FetchDAT`, trước khi assert DAT read hoặc tạo bất kỳ bus activity nào. RESP phải có status `NotSupported`, TID khớp command, reserved bits bằng 0, và length bằng 0. Không target nào được assign address, và DAT index không được wrap từ 31 về 0.

Test này quan trọng vì lỗi boundary DAT có thể gây đọc sai entry, assign address rác, hoặc corrupt state khi software cấu hình sai.

## 4.9 I2C Legacy Compatibility

Phần 4.9 kiểm tra khả năng tương thích I2C legacy của controller.

Trong thiết kế này, DAT entry có field `device`. Khi `device=1`, controller phải xử lý target như I2C legacy device: dùng `static_address` thay vì `dynamic_address`, chạy bus ở open-drain mode, dùng ACK/NACK theo I2C, và không dùng các semantics riêng của I3C như T-bit SDR data phase.

Các test trong phần này đảm bảo regular read/write I2C chạy đúng, length packing giống expectation của HCI queues, address NACK và data NACK được report đúng, OD mode được giữ trong toàn bộ transaction, và timing register có thể cấu hình bus theo hướng I2C.

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

### I2C_003 - `i2c_len_sweep_partial_rx`

Test này kiểm tra nhiều độ dài read/write trong I2C legacy path.

Testbench chạy cả I2C write và I2C read với các length 1, 2, 3, 4, 5, 7, và 8 byte. I2C target model ACK và trả data hợp lệ.

Kết quả mong đợi là TX packing và RX packing đều đúng. Với write, controller lấy đúng byte từ TX FIFO theo thứ tự expected. Với read, RX FIFO chứa đúng data target trả về.

Các length không chia hết cho 4 phải xử lý partial DWORD đúng, đặc biệt ở RX FIFO. RESP length phải khớp số byte thật sự transfer.

Test này quan trọng vì I2C path vẫn dùng HCI queues giống các path khác. Lỗi packing ở boundary DWORD có thể xuất hiện riêng ở I2C read/write dù I3C path đã pass.

### I2C_004 - `covered_by_sva_no_vseq`

Mục này không dùng virtual sequence riêng.

Lý do là I2C legacy read/write đã được kích thích bởi I2C_001 và I2C_002. Nếu thêm một vseq chỉ chạy lại read/write để kiểm tra timing mặc định 400 kHz thì phần stimulus bị trùng và không chứng minh thêm nhiều.

Coverage cho I2C_004 nên nằm ở SVA và reset/default checks: `I2C_T_*` reset về các giá trị tương đương I2C Fast-mode 400 kHz, và khi controller chạy I2C legacy transfer thì timing mux phải chọn `I2C_T_*` thay vì nhóm timing chung `T_*`.

Kết quả mong đợi là default `I2C_T_LOW`, `I2C_T_HIGH`, START/STOP/data timing I2C được giữ đúng ở CSR/SVA level, còn functional transaction được cover bởi các I2C vseq còn lại.

Mục này quan trọng để tránh hiểu nhầm rằng cần một vseq riêng để program timing. Trong current design, I2C dùng 400 kHz-equivalent timing theo default `I2C_T_*`; nếu sau này cần verify software-programmed I2C timing, nên tạo test riêng ghi `I2C_T_*` trực tiếp.

## 4.10 Error Handling, Status, and Recovery

Phần 4.10 kiểm tra cách controller report lỗi, ghi response, xử lý reset, và recover khỏi các tình huống bất thường.

Các test trước đó tập trung vào từng protocol flow riêng lẻ: data đúng, không corrupt FIFO, terminate/recover đúng, và không đi vào phase sai. Phần này gom lại các yêu cầu chung về status và recovery: RESP descriptor phải encode đúng success/error/TID/reserved/length, lỗi address và data phải được phân loại đúng, short read và overflow phải báo đúng error, FIFO response full phải tạo backpressure an toàn, reset không được để lại state rác, và các behavior chưa được hỗ trợ như bus stuck hoặc invalid descriptor phải được document rõ. Với descriptor đã có policy rõ, ví dụ `AddressAssignment`/ENTDAA có `toc=0`, `wroc=0`, `dev_count=0`, hoặc `dev_idx+dev_count>DatDepth`, test phải check strict `NotSupported`, không DAT access, và không bus activity.

Thứ tự trong phần này đi theo quan hệ response/recovery: baseline RESP thành công, lỗi address/header, lỗi data/read termination, FIFO/backpressure, HC abort recovery, descriptor/response policy gap, rồi reset và bus-recovery gap.

### ERR_001 - `resp_success_tid_length`

Test này kiểm tra các field của RESP descriptor khi transaction thành công.

Implementation note: ERR_001 được cover bằng SVA, không cần vseq riêng. Các vseq functional hiện có như immediate write, regular write, regular read, I2C, CCC, và ENTDAA success path đã tạo stimulus thành công tự nhiên; `flow_active_sva` quan sát lúc DUT ghi RESP FIFO.

Kết quả mong đợi là mỗi response có field error/status là `Success`, TID trong response khớp với TID của command, và length bằng số byte hoặc số lượng dữ liệu thực tế mà transaction đã xử lý.

Theo testplan, các field quan trọng là `RESP[31:28]` cho status, `RESP[27:24]` cho TID, `RESP[23:16]` cho reserved zero, và `RESP[15:0]` cho actual length. Checker chính dùng predicate chung `success_resp_matches_current_len()` cùng các cover như `cp_sdr_write_toc1_success_resp`, `cp_sdr_read_success_resp_len`, `cp_i2c_write_success_resp`, `cp_i2c_read_success_resp`, `cp_imm_success_resp`, và `cp_daa_success_resp`.

Test này quan trọng vì software dựa vào RESP để biết command nào đã hoàn tất và hoàn tất với bao nhiêu data. Nếu TID hoặc length sai, software có thể ghép nhầm response với command khác.

### ERR_002 - `resp_private_addr_nack`

Test này kiểm tra response khi lỗi xảy ra ở private hoặc target address phase.

Target được cấu hình để NACK address. Testbench chạy `i3c_private_addr_nack_resp_vseq` cho I3C write/read, I2C write/read, I3C/I2C immediate write, và direct CCC target-address NACK.

Kết quả mong đợi là controller không được đi vào phase tiếp theo sau address NACK. Với write, không truyền data. Với read, không ghi RX data. Với immediate write, không gửi inline data byte. Với direct CCC, broadcast header và opcode đã được ACK/nhận, nhưng nếu target address sau repeated START bị NACK thì controller không được gửi direct data byte.

RESP phải báo error `AddrHeader` ở mọi command class được support có private/target address NACK. TID phải khớp command, reserved bits phải bằng 0, và length phải bằng 0.

Checker chính cho descriptor là `ap_addr_nack_resp` trong `flow_active_sva`, dùng predicate chung `addr_nack_resp_matches()` để kiểm tra `AddrHeader`, TID, reserved zero, và length 0 tại thời điểm ghi RESP. Các cover `cp_sdr_write_addr_nack_resp`, `cp_sdr_read_addr_nack_resp`, `cp_i2c_write_addr_nack_resp`, `cp_i2c_read_addr_nack_resp`, `cp_i3c_imm_addr_nack_resp`, `cp_i2c_imm_addr_nack_resp`, và `cp_direct_ccc_target_addr_nack_resp` chứng minh từng nhánh ERR_002 đã hit.

Test này quan trọng vì private/target address NACK là lỗi phổ biến và cần được phân loại riêng với data NACK hoặc short read.

### ERR_003 - `resp_broadcast_header_nack`

Test này kiểm tra response khi broadcast header `7'h7E+W` bị NACK.

Broadcast header là frame chung `START + 7'h7E + W + ACK/NACK`. Nếu NACK xảy ra ở frame này, controller chưa đi vào phase riêng của command, nên checker không cần phân biệt command đang chờ là CCC, ENTDAA, hay private I3C transfer có bật broadcast-header preamble.

Testbench chạy `i3c_broadcast_header_nack_resp_vseq` để tạo representative broadcast-header NACK. Checker chính nằm trong `flow_active_sva` trên state chung `I3CBcastHeader`, với các cover `cp_bcast_header_nack_sample_no_followup`, `cp_bcast_header_nack_stops_no_followup`, và `cp_bcast_header_nack_resp`.

Kết quả mong đợi là controller dừng frame ngay sau broadcast-header NACK. Không được phát command-specific follow-up: không có CCC opcode/payload, không có ENTDAA round `7'h7E+R`, không có private target-address phase, và không có transfer data.

RESP phải báo error `AddrHeader`, TID phải khớp command, reserved bits phải bằng 0, và length phải bằng 0.

Test này được tách khỏi `ERR_002` vì broadcast header là địa chỉ reserved `7'h7E` dùng làm preamble chung. `ERR_002` tập trung vào private hoặc target address thật của transfer cụ thể sau khi broadcast-header phase đã qua hoặc không được dùng.

### ERR_004 - `resp_data_nack_error`

Test này kiểm tra response khi target NACK data byte trong các write-style phase của I2C.

Testbench chạy `i2c_data_nack_write_vseq` cho regular write nhiều DWORD với NACK ở data byte đầu, giữa, và byte cuối. Testbench cũng chạy `i3c_imm_data_nack_i2c_vseq` cho immediate write với `dtt=2..4`, bao phủ NACK ở inline byte đầu, giữa, và byte cuối. Target ACK address nhưng NACK một data byte.

Kết quả mong đợi là controller phát hiện data NACK, tạo STOP và không truyền các byte regular hoặc inline còn lại. Byte bị NACK vẫn đã được clock đủ 8 bit nên actual length bằng số byte đã truyền tới boundary lỗi. RESP phải là `I2cDataNackOrI3cBusAborted`, TID phải khớp, reserved bits bằng 0 và length bằng actual length đó.

Regular write có thể để lại TX FIFO word chưa được fetch, nên recovery phải đợi idle rồi SW reset trước khi chạy FIFO-backed write tiếp theo. Immediate payload nằm trong descriptor nên immediate transfer hợp lệ tiếp theo phải chạy được mà không SW reset.

Test này quan trọng vì data NACK khác với address NACK. Nếu report sai error, software khó xác định target không tồn tại hay target từ chối data.

### ERR_005 - `resp_short_read_error`

Test này kiểm tra response khi I3C target kết thúc read sớm.

Testbench request đọc `N` byte, nhưng target chỉ trả `M` byte với `M < N`, rồi báo end bằng T-bit theo read semantics. Các case phủ đủ vị trí kết thúc trong một DWORD, có riêng boundary `M = N - 1`, và phủ policy `SRE × WROC`.

Test chạy `i3c_read_short_target_end_vseq` trong cả hai private-address mode. Sweep data-integrity dùng `SRE=1,WROC=1`; các case policy bổ sung `SRE=1,WROC=0`, `SRE=0,WROC=1`, `SRE=0,WROC=0`, và một subcase `SRE=0,toc=0` có command hợp lệ xếp sau.

RX FIFO phải commit đúng các byte đã nhận, các byte padding phải bằng 0 và không được nhận thêm data sau T-bit kết thúc. Short read luôn ép STOP, không phát continuation Repeated START và không consume command sau như một continuation. Khi `SRE=1`, RESP phải báo `I3cShortReadErr` với actual length `M` kể cả `WROC=0`. Khi `SRE=0`, early end là completion hợp lệ: `WROC=1` tạo Success RESP với actual length `M`, còn `WROC=0` không tạo RESP.

Test này quan trọng vì short read không nhất thiết là bus corruption. Nó là một tình huống protocol cần report chính xác để software biết có bao nhiêu data hợp lệ trong RX FIFO.

### ERR_006 - `covered_by_sva_no_vseq`

ERR_006 được cover bằng SVA, không cần vseq riêng. Các SDR read vseq hiện có đã tạo đúng stimulus cần thiết trong quá trình regression.

Trong read phase, T-bit do target gửi không phải parity của data byte. Theo MIPI I3C SDR read semantics, khi target gửi T-bit bằng 0 thì đó là tín hiệu end-of-data.

`i3c_device_response_seq` mặc định phát T-bit bằng 0 sau byte cuối. `i3c_read_vseq` và `i3c_read_len_sweep_vseq` chạy read đủ requested length trong cả hai private-address mode, nên các test functional này tự nhiên kích hoạt ERR_006. Đặc biệt, length sweep đã bao gồm length 5 từng dùng trong standalone vseq cũ.

`ap_sdr_read_target_end_at_requested_len` kiểm tra final T-bit bằng 0 làm remaining length về 0 mà không set short read. `ap_sdr_read_success_resp_len` kiểm tra RESP là `Success`, đúng TID, reserved bằng 0 và length bằng số byte đã nhận. `cp_sdr_read_final_tbit_end_policy` cover chuỗi end-to-end từ final T-bit bằng 0, STOP hợp lệ, đến Success RESP. Vì response được yêu cầu chính xác là `Success`, trường hợp này cũng không thể bị phân loại thành `Parity`.

Các functional vseq và scoreboard tiếp tục kiểm tra RX data, số byte quan sát được và queue drain. SVA chịu trách nhiệm trực tiếp cho semantic của final T-bit và response classification, tránh duy trì một vseq trùng lặp.

### ERR_007 - `resp_ovl_error`

Test này kiểm tra response khi transfer I3C/I2C hoặc ENTDAA kết thúc bằng FIFO overflow/underflow class `Ovl`. Không dùng umbrella sequence; từng vseq chuyên biệt chịu trách nhiệm cho một boundary rõ ràng.

`i3c_write_tx_fifo_underflow_vseq` chạy regular write I3C và I2C khi TX FIFO rỗng hoàn toàn, chỉ có một DWORD, hoặc data đến trễ. I3C được chạy với cả hai chế độ có/không có broadcast-header preamble. Các case phủ `toc=0/1`; case `toc=0` phải có command tiếp theo thực sự nằm trong queue để chứng minh underflow ép STOP và không consume command đó như continuation. RESP length là số byte đã truyền trước khi thiếu data. Sau khi FSM idle, SW reset loại bỏ residual hoặc late TX data, rồi một FIFO-backed write hợp lệ phải thành công.

`i3c_read_rx_fifo_full_overflow_vseq` chạy regular read I3C và I2C với RX FIFO đầy, chỉ còn một DWORD trống, và RX FIFO đầy tại partial-DWORD length 1, 2, hoặc 3. Length trong RESP là số byte đã nhận trên bus đến commit bị reject, kể cả khi DWORD cuối không được lưu. Không được ghi garbage vào RX FIFO, không được nhận thêm data sau khi latch overflow, và `toc=0` không được tạo continuation. Với I2C, nếu byte vừa nhận hoàn tất một DWORD mà RX FIFO không thể accept, controller phải phát NACK tại ACK/NACK bit của byte đó rồi STOP. Sau khi drain RX/RESP, một I3C read và một I2C read hợp lệ phải thành công mà không cần SW reset.

Với ENTDAA, một DAA result của design này cần 3 DWORD trong RX FIFO:

- word 0: `PID[47:16]`
- word 1: `{PID[15:0], BCR, DCR}`
- word 2: `{25'h0, DA[6:0]}`

`i3c_entdaa_rx_fifo_partial_overflow_vseq` chạy 3 subcase: RX FIFO còn 0, 1, hoặc 2 slot trước khi DAA result được ghi. Controller không được silently drop DAA result rồi vẫn trả `Success`. RESP length phải lần lượt là 0, 4, hoặc 8 byte tương ứng với số DWORD đã commit. Các word prefill phải giữ nguyên và các DAA-result DWORD đã commit phải đúng format. Sau khi drain RX/RESP, một ENTDAA hợp lệ phải thành công mà không cần SW reset.

`flow_active_sva` kiểm tra độc lập việc reject RX/ENTDAA commit phải latch overflow, chặn thêm data hoặc result write, ép STOP, chặn continuation, kiểm tra I2C NACK tại full-DWORD boundary, và kiểm tra RESP `Ovl` có TID/reserved/actual-length đúng. Coverage được tách theo I3C/I2C TX underflow, I3C/I2C RX overflow, partial DWORD và ENTDAA overflow bằng các cover `cp_*_ovl` tương ứng trong test plan.

Test này quan trọng vì `Ovl` là error in-scope của FIFO boundary path. Software cần phân biệt nó với address NACK và short read để biết lỗi đến từ producer/consumer FIFO thay vì target không phản hồi.

### ERR_008 - `resp_fifo_full_backpressure`

`i3c_resp_fifo_full_backpressure_vseq` kiểm tra hai nguồn response bắt buộc: regular write thành công với `wroc=1`, và immediate command có `wroc=0` nhưng bị address NACK nên error phải override WROC. Trước mỗi command, testbench backdoor-fill đủ 8 entry của RESP FIFO bằng các pattern phân biệt được và đồng bộ scoreboard để các entry synthetic không bị hiểu nhầm là response của command đang chạy.

Khi transaction hoàn tất, test giữ FIFO full thêm nhiều cycle và kiểm tra FSM vẫn ở `WriteResp`, `resp_hw_wvalid` vẫn bằng 1, `resp_hw_wdata` không đổi, write-ready vẫn bằng 0, pointer/depth không đổi, và toàn bộ 8 entry cũ không bị overwrite.

Sau đó software pop đúng một entry để tạo một slot. Pending response phải được ghi đúng một lần vào slot đó và FSM trở về idle. Test drain toàn bộ FIFO để kiểm tra 7 entry cũ còn lại vẫn đúng thứ tự, response mới nằm cuối queue với status/TID/length chính xác, và FIFO cuối cùng empty. Depth phải trở lại 8 ngay sau chuỗi một-pop/một-write; nếu response bị drop hoặc duplicate thì kiểm tra depth và thứ tự drain sẽ fail.

`flow_active_sva` kiểm tra độc lập bốn invariant bằng `cp_resp_full_success_holds_pending_write`, `cp_resp_full_error_holds_pending_write`, `cp_resp_full_keeps_descriptor_stable`, và `cp_resp_backpressure_release_writes_once`. Trường hợp success `wroc=0` không phụ thuộc RESP FIFO thuộc ERR_012, không lặp lại ở đây.

Test này quan trọng vì software có thể đọc response chậm hơn tốc độ controller hoàn tất command. Backpressure ở RESP FIFO phải được xử lý như một phần của flow control bình thường.

### ERR_009 - `resp_hc_abort_error`

Test này kiểm tra HC abort cho I3C SDR regular write/read, I2C regular write/read, immediate transfer, CCC ENEC broadcast/direct và ENTDAA bằng `i3c_write_abort_vseq`, `i3c_read_abort_vseq`, `i2c_regular_abort_vseq`, `i3c_imm_abort_vseq`, `i3c_daa_hc_abort_vseq` và `i3c_hc_abort_policy_vseq`.

Các case SDR gồm abort sớm, abort sau khi đã truyền hoặc commit ít nhất một DWORD, và `toc=0` nơi abort phải override continuation. Immediate case assert abort trong data phase `IssueCmd` cho private I3C/I2C. Transfer hoàn tất tại protocol boundary đã định nghĩa, tạo STOP, không chain command kế tiếp, và RESP phải là `HcAborted` với TID, reserved bits và actual length đúng.

Với I3C hoặc I2C regular write, HC abort không tự flush phần TX FIFO chưa được fetch; recovery sạch cần clear `HC_CONTROL[29]` (ABORT), đợi idle và SW reset. Với regular read, software drain và kiểm tra RX data đã commit cùng RESP sau khi clear abort; cả I3C và I2C đều chạy một read hợp lệ tiếp theo mà không SW reset. I2C read abort phải drive controller NACK ở byte cuối rồi STOP và luôn giữ OD mode.

Với immediate transfer, payload nằm trong command descriptor và không dùng TX/RX FIFO. Sau khi clear abort và đọc RESP, queue đã sạch và một immediate transfer hợp lệ tiếp theo phải chạy thành công trước bất kỳ SW reset cleanup nào.

Với ENTDAA, test assert HC abort trong lúc nhận PID/BCR/DCR, trong assigned-address phase, và sau một round đã hoàn tất. RESP phải là `HcAborted` với TID, reserved bits và actual length đúng. Nếu đã có DAA result được commit vào RX FIFO, software drain phần result đó cùng RESP, clear abort, và sau **mỗi** abort point đều chạy một ENTDAA hợp lệ thành công không cần SW reset.

`i3c_hc_abort_policy_vseq` bổ sung ba policy case còn thiếu. Khi ABORT được giữ ở idle và CMD đã queue, controller không được pop CMD, phát START hoặc tạo RESP; sau khi clear ABORT, chính CMD đó phải chạy thành công. Trong normal CCC, test abort ENEC broadcast và direct sau khi data byte/T-bit đã hoàn tất, kiểm tra STOP, RESP `HcAborted` exact và một CCC recovery thành công không SW reset. Priority case tạo broadcast-header NACK rồi assert ABORT trong lúc STOP đang xử lý; RESP phải giữ `AddrHeader`, vì lỗi địa chỉ có priority cao hơn `HcAborted`.

Coverage được implement trực tiếp bằng `cp_abort_entry_state`, `cp_abort_stop_state`, `cp_resp_err_priority`, `cp_daa_abort_point` và các assertion/cover pair `cp_abort_idle_blocks_command`, `cp_abort_error_priority_resp`, `cp_regular_write_abort_resp`, `cp_immediate_abort_resp`, `cp_ccc_abort_resp`, `cp_daa_abort_resp` cùng các read-abort cover hiện có.

Test này quan trọng vì abort là error path có thể để lại dữ liệu hợp lệ lẫn residual queue state; recovery policy phải phân biệt rõ write và read.

### ERR_010 - `invalid_descriptor_attr`

`i3c_invalid_descriptor_attr_vseq` kiểm tra policy từ chối tập trung của `flow_active`. Controller chỉ hỗ trợ DAT-format `RegularTransfer`, `ImmediateDataTransfer`, `AddressAssignment` và chỉ hỗ trợ mode `sdr0`. `ComboTransfer`, attr direct/internal `100..111`, mọi mode khác SDR0, Regular có `cp=1`, Immediate có `rnw=1` hoặc `dtt>4`, immediate CCC ngoài ENEC/DISEC `00/01/80/81`, và AddressAssignment có opcode khác ENTDAA `07` đều không hợp lệ.

Test ghi trực tiếp từng descriptor vào CMD queue, bao gồm một case `wroc=0`. Từ lúc command được nhận đến khi FSM trở lại idle, test theo dõi các tín hiệu nội bộ để chứng minh `dat_read_valid_hw_o`, START, repeated START, STOP và toàn bộ bus TX/RX request không bao giờ được assert.

Mỗi case phải tạo đúng một RESP `NotSupported` với TID khớp descriptor, reserved bits bằng 0 và length bằng 0. Error response không bị suppress bởi `wroc=0`. Sau khi đọc RESP, cả bốn queue phải sạch; test chạy ngay một Immediate SDR0 hợp lệ không SW reset để chứng minh FSM và queue phục hồi hoàn toàn.

`flow_active_sva` kiểm tra độc lập bằng `cp_invalid_cmd_rejected_before_access` và `cp_invalid_cmd_not_supported_resp`. Covergroup phân loại stimulus bằng `cp_invalid_cmd`, `cp_imm` và `cp_unsupported_cmd`.

Policy này cố ý nghiêm ngặt hơn upstream `i3c-core`: upstream định nghĩa attr `100..111` cho direct/internal descriptor, nhưng simplified controller không implement các layout đó; upstream cũng chưa từ chối mọi unsupported CCC trước bus. Vì vậy project này trả `NotSupported` thay vì alias, stall hoặc phát frame một phần.

Test này quan trọng vì command descriptor là input từ software. Descriptor sai phải bị cô lập trước khi tác động DAT, bus hoặc data FIFO.

### ERR_011 - `entdaa_invalid_descriptor_resp`

Test này kiểm tra response khi software issue `AddressAssignment`/ENTDAA descriptor sai format.

`i3c_entdaa_invalid_descriptor_resp_vseq` chạy bốn subcase độc lập:

- `toc=0`, `wroc=1`, `dev_count=1`
- `toc=1`, `wroc=0`, `dev_count=1`
- `toc=1`, `wroc=1`, `dev_count=0`
- `dev_idx=31`, `dev_count=2` khi `DatDepth=32`

Theo policy hiện tại, các descriptor này bị reject ngay trong `FetchDAT`, trước khi controller đọc DAT hoặc phát bất kỳ frame ENTDAA nào. Cùng policy này cũng áp dụng cho descriptor có `dev_idx+dev_count>DatDepth`.

Kết quả mong đợi là không có DAT read, START/RSTART/STOP, bus TX/RX request, broadcast header `7'h7E+W`, CCC opcode ENTDAA `8'h07`, hoặc DAA-controller activation. Controller chỉ ghi đúng một RESP với status `NotSupported`, TID khớp command, reserved bits bằng 0, và length bằng 0.

Sau mỗi subcase lỗi, test chạy một Immediate SDR0 hợp lệ không cần SW reset để chứng minh queue/FSM không bị corrupt. `flow_active_sva` kiểm tra độc lập bằng `cp_addr_assign_invalid_rejected_before_access` và `cp_addr_assign_invalid_not_supported_resp`; covergroup ERR_011 phân loại đủ bốn nguyên nhân bằng `cp_addr_assign_desc` và cover response/TID/length/bus silence.

Test này nằm trong error category, không nằm trong CCC/DAA happy-path, vì mục tiêu chính là kiểm tra error response và pre-bus rejection của command descriptor sai.

### ERR_012 - `wroc_policy`

Test này là positive sign-off coverage cho field `wroc` (response on completion) trong command descriptor.

`i3c_wroc_policy_vseq` issue các regular, immediate và immediate-CCC command thành công với cả `wroc=0` và `wroc=1`; trộn hai policy trong cùng command stream; chạy continuation `toc=0,wroc=0`; giữ RESP FIFO full để chứng minh command không phụ thuộc RESP backpressure; và tạo address NACK trên command `wroc=0` để kiểm tra error override.

Policy mong đợi là:

- Command thành công với `wroc=1` ghi đúng một RESP `Success` với TID và actual length đúng.
- Command thành công với `wroc=0` không ghi RESP.
- Continuation hợp lệ `toc=0,wroc=1` chỉ accept command kế tiếp khi RESP FIFO ready; với `wroc=0`, controller accept continuation mà không phụ thuộc RESP FIFO, kể cả khi FIFO full.
- Mọi error vẫn ghi RESP bất kể `wroc`, bao gồm address/data NACK, underflow/overflow, short read khi `sre=1`, HC abort, invalid descriptor và missing/unsupported continuation. Early target end khi `sre=0` là completion hợp lệ và tuân theo WROC. Missing/unsupported continuation trả `NotSupported`.
- `AddressAssignment` không tham gia suppression policy: `wroc=0` vẫn là descriptor không hợp lệ và được cover bởi ERR_011.

Scoreboard lưu `wroc` trong expected transaction và chỉ queue expected response cho success khi `wroc=1`; error luôn queue expected response. Các SVA `ap_wroc0_success_suppresses_resp`, `ap_wroc1_success_enters_write_resp`, `ap_wroc0_error_override_writes_resp`, `ap_wroc0_continuation_ignores_resp_ready` và `ap_wroc1_continuation_waits_for_resp_ready` kiểm tra policy độc lập với vseq.

Test này quan trọng vì software dùng số RESP để quản lý queue accounting. Suppression sai có thể tạo RESP thừa; suppress nhầm error có thể làm software mất hoàn toàn trạng thái lỗi của transaction.

### ERR_013 - `reset_during_idle`

Test này kiểm tra reset khi DUT đang idle.

Controller được đưa về trạng thái idle, sau đó testbench assert và deassert `rst_ni`.

Kết quả mong đợi là các register, queue, FIFO pointer, FSM state, và bus output trở về reset state. Bus phải được release về trạng thái không drive sai.

Sau reset, controller phải có thể chạy một command hợp lệ mới từ trạng thái sạch.

Test này quan trọng vì reset idle là đường reset cơ bản nhất. Nếu reset idle không sạch, các reset trong active phase càng khó tin cậy.

### ERR_014 - `reset_during_transfer_phases`

Test này kiểm tra reset trong lúc controller đang hoạt động.

Testbench assert reset tại nhiều phase khác nhau, ví dụ START, address ACK, data TX, data RX, DAA, và WriteResp phase.

Kết quả mong đợi là bus được release, FSM quay về reset state, và sau reset không có queue pop/push ngoài ý muốn từ transaction dang dở.

Sau mỗi reset point, testbench chạy một legal transfer tiếp theo để kiểm tra controller đã recover thật sự.

Test này quan trọng vì reset có thể xảy ra bất kỳ lúc nào trong hệ thống thật. Nếu reset giữa transfer để lại stale command, stale data, hoặc response nửa chừng, bug sẽ rất khó debug.

### ERR_015 - `sw_reset_while_busy_policy`

Test này kiểm tra policy khi software reset được assert trong lúc controller đang bận.

Testbench bắt đầu một chuỗi transfer có command tiếp theo đang chờ, sau đó ghi `RESET_CONTROL[0]` (SOFT_RST) khi `HC_STATUS[FSM_IDLE]=0`.

Policy hiện tại là busy SOFT_RST được bus CSR accept nhưng không có side effect: không tạo pulse `sw_reset`, không flush CMD/TX/RX/RESP FIFO, không clear CSR CMD/TX staging, và không reset protocol FSM.

Kết quả mong đợi là transfer đang chạy và các transfer đã queue vẫn hoàn tất bình thường. Nếu software muốn hủy active transfer, đường recovery đúng là dùng `HC_CONTROL[ABORT]`, đợi idle, rồi dùng SOFT_RST khi idle để cleanup FIFO/staging nếu cần.

Test này quan trọng vì RTL cũ flush queue ngay cả khi protocol FSM vẫn đang chạy, tạo nguy cơ mất command/data và làm trạng thái controller khó dự đoán.

### ERR_016 - `bus_stuck_scl_low`

Test này xác định gap recovery khi bus bị kẹt, ví dụ `SCL` bị giữ low.

Device hoặc bus model giữ `SCL` low trong lúc transfer đang chạy, khiến controller không thể tiến triển bình thường.

Theo testplan, project scope hiện chưa có bus recovery hoặc timeout hoàn chỉnh. Vì vậy test có thể fail bằng simulation timeout hoặc document đây là known gap.

Kết quả quan trọng là behavior phải được ghi nhận rõ, không được coi là một pass chức năng nếu controller chỉ chờ vô hạn mà không có timeout policy.

Test này quan trọng vì bus stuck là lỗi thực tế trên hệ thống open-drain. Nếu không có timeout/recovery, software hoặc system-level logic phải biết đây là giới hạn hiện tại.

### ERR_017 - `unexpected_stop_during_command`

Test này kiểm tra phản ứng của controller khi có STOP bất ngờ trong lúc command đang active.

Bus model force một điều kiện giống STOP, tức `SDA` rising khi `SCL` high, trong lúc DUT đang ở DAA hoặc data phase.

Kết quả mong đợi là controller phải terminate command hoặc đưa controller về trạng thái hợp lệ theo recovery policy đã được specification hóa. Nếu chưa có recovery policy cho STOP bất ngờ, test phải ghi nhận missing spec/RTL behavior này.

Controller không được âm thầm tiếp tục dùng state cũ như thể không có STOP nếu điều đó làm corrupt transaction sau.

Test này quan trọng vì bus event bất ngờ có thể xảy ra do reset, target lỗi, hoặc contention trong hệ thống. Verification cần biết scope/spec yêu cầu recovery đến mức nào.

## 4.11 UVM Environment, Scoreboard, and Regression Infrastructure

Phần 4.11 kiểm tra chính môi trường verification: compile flow, regression targets, scoreboard, device response sequence, monitor decode, và register agent.

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

## 4.12 Stress, Robustness, and Performance

Phần 4.12 kiểm tra độ bền của controller khi chạy nhiều transaction, nhiều loại command, trạng thái FIFO sát biên, và đo một số chỉ số performance.

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

Test này document việc IRQ output chưa tồn tại.

Reviewer inspect top-level port và CSR map. Thiết kế hiện tại không có IRQ output pin, không có interrupt enable register, và không có interrupt-status CSR.

Kết quả mong đợi là xác nhận không có positive IRQ assertion testcase trong sign-off hiện tại. Phần status verification đi qua `HC_STATUS`, `QUEUE_STATUS`, và RESP FIFO.

Do không có IRQ interface, software phải poll status/response thay vì dựa vào IRQ output.

Test này quan trọng vì nhiều controller thật có interrupt path. Nếu không document rõ, người đọc testplan có thể nhầm việc thiếu IRQ testcase là thiếu sót verification, trong khi đây là giới hạn scope của thiết kế hiện tại.

### NA_004 - `na_hdr_no_positive_test`

Test này document việc HDR mode chưa được implement.

Reviewer kiểm tra package và `flow_active`. Dù có thể tồn tại enum hoặc descriptor value liên quan HDR, thiết kế hiện tại không có HDR datapath.

Kết quả mong đợi là không có positive HDR test bắt buộc. Các HDR mode enum chỉ nên được dùng trong invalid descriptor hoặc unsupported descriptor negative test.

Test này quan trọng vì HDR là feature khác lớn so với SDR. Nếu chưa có datapath, chạy positive HDR test sẽ không hợp lý; verification chỉ cần đảm bảo unsupported descriptor không làm controller corrupt hoặc lock up.
