# Kiểm toán toàn bộ hệ thống citation và bibliography — “Thiết kế bộ điều khiển I3C”

## 0. Thông tin phiên kiểm toán

| Hạng mục | Kết quả |
|---|---|
| Commit đang kiểm tra | `c06739b88ff1c6c1516ce6b1a76bb829bc965890` (`main`; `docs(report): checkpoint before chapter 3 design-first restructure`; commit ngày 2026-07-18) |
| Trạng thái working tree | **Bẩn**. Snapshot lúc kiểm toán có **76** mục tracked đã sửa/xóa và **9** file untracked. Kiểm toán dùng đúng nội dung working tree, không restore/checkout/ghi đè thay đổi của người dùng. |
| Ngày kiểm tra | **2026-07-22**, múi giờ Asia/Ho_Chi_Minh |
| Hiệu chỉnh sau tái kiểm độc lập | **2026-07-22**: sửa F04 để bỏ các nhánh IBI/Secondary Controller/HDR đã gán nhầm từ Figure 169–173; làm rõ giới hạn suy luận provenance ở F02. Không thay đổi số lượng hay mức độ finding. |
| Bibliography nguồn | Chỉ `docs/report/latex/References/references.bib`; không dùng `report-blx.bib`, `.bbl`, `.aux`, `.blg`, `.run.xml` làm nguồn chỉnh sửa. |
| Build cô lập | Thành công trong `/private/tmp/i3c-citation-audit-clean.KjGLdw/latex`; không ghi artifact build vào working tree. |

### File đã đọc

Nguồn báo cáo chính thức:

- `docs/report/latex/report.tex`, `Title/title.tex`, `Appendix/thanks.tex`, `Appendix/reassurances.tex`, `Appendix/tomtat.tex`.
- `chapters/01_introduction.tex` đến `chapters/06_conclusion.tex`.
- `Appendix/appendixA.tex`, `appendixB.tex`, `appendixC.tex`, `appendixE.tex`.
- `thesisterms.sty`, `myacronyms.sty`, `References/references.bib`.
- Toàn bộ file được `\input` thật sự: `figures/i3c_low_handoff_timing.tex`, `i3c_read_takeover_timing.tex`, `csr_queue_handshake.tex`, `i3c_primary_controller_fsm.tex`, `entdaa_fsm.tex`.
- Toàn bộ asset được `\includegraphics` thật sự: `i3c_controller_top_architecture.pdf`, `uvm_i3c_verification_architecture_uvm.pdf`, `scl_generator_fsm.pdf`, `entdaa_controller_fsm.pdf`, `entdaa_fsm.pdf`, `i3c_write.png`, `i3c_read.png`, `i3c_imm.png`, `enec_bcast.png`, `enec_direct.png`, `daa1_png.png`, `daa5_png.png`, `daa4_png.png`, `i2c_write.png`, `i2c_read.png`; đồng thời kiểm tra các nguồn `.drawio` hiện có tương ứng.
- `figures/flow_active_algorithm.tex` được kiểm tra nhưng **không** nằm trong include graph chính thức, vì vậy không tính là nội dung báo cáo hiện hành.

Nguồn đối chiếu nội bộ:

- `docs/phase1_spec_v2.md`; các file trong `docs/module_specs/` và `docs/verification_specs/` liên quan kiến trúc, HCI queue, FSM, UVM, coverage, SVA và build.
- RTL trọng yếu: `src/rtl/i3c_pkg.sv`, `src/rtl/ctrl/controller_pkg.sv`, `flow_active.sv`, `controller_active.sv`, `bus_tx_flow.sv`, `bus_rx_flow.sv`, `entdaa_controller.sv`, `entdaa_fsm.sv`, `src/rtl/csr/`, `src/rtl/hci/`, `src/rtl/i3c_controller_top.sv`.
- UVM/SVA trọng yếu: `src/verification/Makefile`, `uvm_i3c/dv_inc/dv_macros.svh`, `uvm_i3c/i3c_core/`, thư viện `i3c_vseqs/`, `sva/flow_active_sva.sv`.
- Artifact: `src/verification/regression_result.txt`, `coverage_report.txt`, `sva_coverage_report.txt`.

Nguồn sơ cấp ngoài repo báo cáo nhưng có bản cục bộ: `docs/mipi_i3c_spec.pdf/.md` (I3C Basic v1.1.1 + Errata 01), `docs/mipi_i3c_tcri.pdf/.md` (TCRI v1.0), `docs/mipi-i3c_hci.pdf/.md` (HCI v1.2). Ngoài ra đã đối chiếu một clone tạm, read-only của upstream `chipsalliance/i3c-core` tại commit `ab6daf3d7a7d511887c6540cb0a444b7c488e6a1`.

### Dấu vết đối chiếu F02

- `docs/phase1_spec_v2.md:465` tự phân loại `bus_rx_flow` là **Reuse** và ghi “reuse as-is”.
- Diff giữa working tree và upstream `chipsalliance/i3c-core@ab6daf3d7a7d511887c6540cb0a444b7c488e6a1:src/ctrl/bus_rx_flow.sv` cho thấy hai file cùng enum bốn trạng thái `Idle`, `ReadByte`, `ReadBit`, `NextTaskDecision`; cùng các khối `read_byte_from_bus`, `update_bit_counter`, `update_fsm_state`, `rx_fsm_outputs`; và cùng khung chuyển trạng thái chính. File upstream có `SPDX-License-Identifier: Apache-2.0`, còn file local bắt đầu ngay bằng `module`.
- Bản unified diff tại thời điểm audit đã được lưu ở [`evidence/f02_bus_rx_flow_vs_chipsalliance_ab6daf3d.diff`](evidence/f02_bus_rx_flow_vs_chipsalliance_ab6daf3d.diff). Có thể tái lập khi clone còn sẵn bằng `diff -u /private/tmp/i3c-upstream-audit-20260722/src/ctrl/bus_rx_flow.sv src/rtl/ctrl/bus_rx_flow.sv`; đường dẫn `/private/tmp` chỉ là workspace kiểm toán tạm.
- Diff này chứng minh **độ tương đồng cấu trúc**, không tự nó chứng minh chiều dẫn xuất, snapshot lịch sử chính xác hay việc sao chép từng dòng. Kết luận provenance/license vì vậy vẫn cần lịch sử phát triển hoặc commit nguồn do tác giả xác nhận.

### Trạng thái build

Đã chạy đúng chuỗi release trên bản sao sạch artifact:

```text
pdflatex → bibtex → makeglossaries → pdflatex → pdflatex
```

Năm bước đều exit `0`; PDF cuối có **74 trang**, **697568 byte**. `report.blg` ghi `warning$ -- 0`. Không có undefined citation, empty bibliography, missing entry, duplicate key hay BibTeX missing-field warning. PDF in đúng 7 nguồn được cite.

Có một warning thuộc phạm vi định dạng bibliography: `Name format 'last-first' deprecated`, phát sinh từ `report.tex:240–241` (F61). Warning fallback backend BibLaTeX xuất hiện vì cấu hình chủ ý dùng `backend=bibtex`; các warning font/xcolor/hyperref không thuộc phạm vi audit này.

### Giới hạn truy cập nguồn ngoài

- Đã đọc trực tiếp nội dung MIPI Basic/TCRI/HCI bản cục bộ; đọc trực tiếp NXP UM10204 PDF chính thức, Accellera UVM User’s Guide, trang sản phẩm Cadence và repository/file upstream chính thức.
- IEEE 1800-2017 và UVM Class Reference chỉ được xác minh metadata/trang phát hành chính thức; không tuyên bố đã đọc toàn bộ nội dung chuẩn IEEE.
- Nội dung paper gắn với `chauhan_i3c_uvm` không tồn tại tại DOI đã ghi; Crossref được truy vấn trực tiếp và cho metadata của **một paper khác** (F06).
- Không tìm được bản ghi đáng tin cậy cho `verma_uvm_fv`; áp dụng đúng kết luận: **“Chưa thể xác minh nội dung nguồn — cần kiểm tra thủ công.”**
- Trang web/repository là nguồn động; trạng thái URL và phiên bản được ghi nhận tại ngày audit. Với nguồn code, bibliography hiện chưa pin commit/tag nên chưa tái lập được chính xác snapshot tác giả đã dùng.

## 1. Convention citation thực tế

`report.tex:25–29` khai báo:

```latex
\usepackage[
    sorting=nty,
    backend=bibtex]{biblatex}
\addbibresource{References/references.bib}
```

Không khai báo `style`, nên BibLaTeX nạp style mặc định **numeric**; log build xác nhận `numeric.cbx`. Bibliography được sắp **name–title–year (`nty`)**, không theo thứ tự citation đầu tiên. PDF sinh nhãn `[1]` NXP, `[2]` Cadence, `[3]` CHIPS Alliance, `[4]` IEEE, `[5]` MIPI Basic, `[6]` MIPI TCRI, `[7]` UVM User’s Guide. Đây là hành vi hợp lệ của convention hiện tại; audit **không** coi thứ tự này là lỗi IEEE và không đề xuất ép sang IEEE/APA. Chưa có quy chế định dạng chính thức của cơ sở đào tạo trong phạm vi file được cung cấp, nên tác giả vẫn cần xác nhận numeric+`nty` có được chấp nhận hay không.

Vị trí citation so với dấu câu nhìn chung nhất quán: `~\cite{...}` đặt trước dấu chấm cuối câu. Multi-key được viết trong một `\cite{a,b}`; không phát hiện lỗi punctuation độc lập.

## 2. Kiểm tra cơ học citation–bibliography

- Chỉ tìm thấy `\cite`; không có `\parencite`, `\textcite`, `\autocite`, `\footcite`, `\nocite` hay macro citation tự định nghĩa trong include graph.
- **13** lệnh citation, **17** lượt key, **7** key duy nhất; cả 7 key đều tồn tại.
- `references.bib` có **14** entry; **7** entry chưa cite; không có key trùng hay hai entry trùng nội dung.
- Không có citation trong Tóm tắt/Abstract, caption, footnote, listing, algorithm hay phụ lục.

### Kiểm tra từng citation hiện có

| Lệnh | Vị trí | Key | Phạm vi hỗ trợ và kết luận |
|---|---|---|---|
| C01 | `01_introduction.tex:12` | `nxp_i2c,mipi_i3c_basic` | NXP hỗ trợ giới hạn I2C; MIPI hỗ trợ DAA. Đúng vị trí và đúng nguồn sơ cấp. |
| C02 | `01_introduction.tex:15` | `mipi_i3c_basic` | Hỗ trợ SDR/Push-Pull/DAA/CCC và 12,5 MHz. Đã xác minh trực tiếp. |
| C03 | `01_introduction.tex:19` | `chipsalliance_i3c` | Repository chính thức xác nhận i3c-core và liên hệ Caliptra; phù hợp ở mức giới thiệu dự án. |
| C04 | `01_introduction.tex:24` | `ieee1800,uvm12_ug,cadence_xcelium` | Nguồn xác nhận chuẩn/công cụ và khả năng UVM/SystemVerilog, nhưng không chứng minh dự án thực sự dùng chúng; phần đó cần evidence nội bộ. Phạm vi citation mơ hồ (F62). |
| C05 | `02_background_requirements.tex:12` | `nxp_i2c` | Hỗ trợ bus hai dây, Open-Drain, phân xử. Đúng và trực tiếp. |
| C06 | `02_background_requirements.tex:14` | `nxp_i2c` | Hỗ trợ START/address/ACK-NACK/STOP và Fast Mode 400 kHz. Đúng và trực tiếp. |
| C07 | `02_background_requirements.tex:21` | `mipi_i3c_basic` | Hỗ trợ coexistence, SDR và 12,5 MHz. Đúng và trực tiếp. |
| C08 | `02_background_requirements.tex:23` | `mipi_i3c_basic` | Hỗ trợ OD/PP và hai ngữ nghĩa T-Bit. Đúng và trực tiếp. |
| C09 | `02_background_requirements.tex:127` | `mipi_i3c_basic` | Hỗ trợ takeover ở câu chứa citation; không bao phủ đoạn handoff trước đó (F11–F12). |
| C10 | `02_background_requirements.tex:212` | `mipi_i3c_basic` | Hỗ trợ trình tự ENTDAA, PID/BCR/DCR và parity. Đúng nội dung, nhưng citation cuối đoạn dài và cấu trúc paraphrase cần xem F17. |
| C11 | `02_background_requirements.tex:384` | `mipi_i3c_basic,nxp_i2c` | Hỗ trợ các số timing ở bảng kế tiếp; vị trí dẫn nhập bảng đủ rõ. |
| C12 | `03_architecture_rtl.tex:55` | `chipsalliance_i3c` | Root repo chứng minh dự án tồn tại, nhưng không chứng minh chính xác module/descriptor nào được kế thừa từ commit nào. Chỉ hỗ trợ một phần (F25). |
| C13 | `03_architecture_rtl.tex:262` | `mipi_i3c_tcri` | TCRI hỗ trợ cấu trúc/mã response; không hỗ trợ thứ tự ưu tiên lỗi nội bộ và không đủ cho từ “HCI”. Chỉ hỗ trợ một phần (F26). |

## 3. Bảng phát hiện

Mã mức cần citation: **1** = chắc chắn cần citation mới/attribution; **2** = có khả năng cần citation, cần tác giả xác nhận; **3** = không cần citation ngoài, cần bằng chứng nội bộ; **4** = không áp dụng hoặc đã có citation nhưng phải sửa phạm vi/metadata.

Trong bảng, đường dẫn `.tex`/`figures/...` không ghi tiền tố được hiểu là tương đối từ `docs/report/latex/`; mọi vị trí đều kèm số dòng của working tree tại thời điểm audit.

| STT | Vị trí | Nội dung hoặc citation liên quan | Citation key/nguồn | Loại vấn đề | Mức độ | Mức độ cần citation | Trạng thái xác minh nguồn | Giải thích | Đề xuất sửa |
|---|---|---|---|---|---|---|---|---|---|
| F01 | `Appendix/reassurances.tex:7–10`; `src/verification/uvm_i3c/dv_inc/dv_macros.svh:1–3` | “Toàn bộ ... UVM ... do em tự thực hiện” trong khi `dv_macros.svh` ghi copyright lowRISC/OpenTitan và Apache-2.0 | `opentitan_dv`; [file upstream](https://github.com/lowRISC/opentitan/blob/master/hw/dv/sv/dv_utils/dv_macros.svh) | Lỗi citation của mã nguồn / nguy cơ attribution | Critical | 1 — Chắc chắn | Đã xác minh trực tiếp | Lời cam đoan tuyệt đối mâu thuẫn với header bản quyền có ngay trong repo. Entry OpenTitan có trong `.bib` nhưng chưa cite. Không kết luận đạo văn; đây là rủi ro attribution rõ ràng phải xử lý. | Thu hẹp lời cam đoan; nêu ngoại lệ mã tái sử dụng, license và nguồn; cite OpenTitan tại nơi mô tả DV infrastructure; pin file+commit. |
| F02 | `docs/phase1_spec_v2.md:465`; `src/rtl/ctrl/bus_rx_flow.sv:1–152`; `Appendix/reassurances.tex:7–10` | Spec nội bộ tự ghi `bus_rx_flow` là “Reuse ... reuse as-is”; file local không có SPDX header, repo không có `LICENSE` top-level, còn snapshot upstream Apache-2.0 có độ tương đồng cấu trúc đáng kể | `chipsalliance_i3c`; upstream `src/ctrl/bus_rx_flow.sv` tại `ab6daf3d…`; [diff lưu kèm](evidence/f02_bus_rx_flow_vs_chipsalliance_ab6daf3d.diff) | Lỗi citation của mã nguồn / nguy cơ attribution-license | Critical | 1 — Chắc chắn | Đã xác minh trực tiếp | Đã xác minh các dữ kiện: mô tả reuse nội bộ, thiếu notice/license local, và cùng enum bốn trạng thái cùng khung FSM với snapshot upstream. Chưa đủ bằng chứng để chốt chiều dẫn xuất, commit nguồn lịch sử hay mức sao chép từng dòng; do đó đây là rủi ro provenance/license cần tác giả và người có thẩm quyền rà soát, không phải kết luận vi phạm license. | Lập inventory module reused/modified; cung cấp lịch sử hoặc commit nguồn thật sự; lưu diff tái lập; phục hồi notice/license thích hợp sau khi xác nhận nghĩa vụ; pin commit/path upstream, mô tả mức thay đổi và sửa lời cam đoan. |
| F03 | `03_architecture_rtl.tex:158–165`; `figures/i3c_primary_controller_fsm.tex:1–55` (Hình `fig:primary-controller-flow`) | Sơ đồ dùng cùng cấu trúc và nhiều nhãn đặc thù như “Pvt Msg Entry Repeated Start”, “SDA arbitration happens”, “I3C capability” | MIPI I3C Basic v1.1.1, Annex C, Figure 168 | Lỗi citation của hình / nguy cơ attribution | Critical | 1 — Chắc chắn | Đã xác minh trực tiếp | Đây là bản vẽ lại/rút gọn rõ ràng của Figure 168 có copyright MIPI, nhưng caption không ghi “phỏng theo” và không cite. | Đổi caption thành “phỏng theo MIPI ... Figure 168”, cite `mipi_i3c_basic`, nêu các nhánh đã lược bỏ và kiểm tra quyền tái sử dụng hình. Nếu tác giả thực tế vẽ lại từ asset CHIPS Alliance, cite thêm đúng file/commit nguồn trung gian sau khi xác nhận. |
| F04 | `03_architecture_rtl.tex:158–165`; `figures/i3c_primary_controller_fsm.tex:1–55`; `src/rtl/ctrl/controller_pkg.sv:14–33` | Hình 168 kiểu protocol FSM được giới thiệu như trình tự trạng thái của thiết kế, nhưng RTL `flow_active` có 15 state khác tên/cấu trúc | RTL hiện tại; xem nguồn/attribution của hình tại F03 | Nội dung không khớp bằng chứng nội bộ / lỗi hình | Major | 3 — Không cần citation ngoài | Không áp dụng — bằng chứng nội bộ | Hình là FSM giao thức tổng quát và có các nhánh thật sự hiện diện như `I3C Directed CCC`, `I2C Legacy mode`, `start DAA`; nó không phải state diagram một-một của FSM 15 state hiện thực. | Hoặc đổi ngữ cảnh thành “FSM giao thức tổng quát, phỏng theo MIPI Figure 168” và giải thích ánh xạ/phần ngoài phạm vi, hoặc thay bằng sơ đồ sinh từ 15 state RTL hiện tại. |
| F05 | `03_architecture_rtl.tex:212–222`; `figures/entdaa_fsm.tex:1–33` (Hình `fig:entdaa-flow`) | Sơ đồ giữ trình tự/nút “Broadcast CCC ENTDAA”, “Sr, 7E/R”, “Read 48 bit Prov ID”, BCR, DCR, Dyn Addr | MIPI I3C Basic v1.1.1, Annex C, Figure 170 | Lỗi citation của hình / nguy cơ attribution | Critical | 1 — Chắc chắn | Đã xác minh trực tiếp | Là bản điều chỉnh từ Figure 170 nhưng caption không attribution/citation. | Ghi “phỏng theo ... Figure 170”, cite MIPI, chỉ rõ thay đổi NACK/Abort so với nguồn và kiểm tra quyền tái sử dụng. Nếu asset được dựng từ bản CHIPS Alliance, cite thêm đúng file/commit nguồn trung gian sau khi xác nhận. |
| F06 | `References/references.bib:91–99` | `chauhan_i3c_uvm` gắn DOI `10.1109/ICCSP48568.2020.9182137` với title/authors I3C/UVM | [Crossref DOI record](https://api.crossref.org/works/10.1109%2FICCSP48568.2020.9182137) | Reference sai / DOI dẫn sai nguồn | Critical | 4 — Không áp dụng | Đã xác minh trực tiếp | DOI thực tế là “Implementation and Performance Analysis of 5-Level Multilevel Converter using Arduino”, Hemant Ravindran et al., trang 775–779. Metadata `.bib` không thuộc DOI này. | Không cite entry hiện tại. Xóa hoặc thay **chỉ sau khi** tìm được paper I3C thật và xác minh title/authors/venue/DOI từ nguồn sơ cấp. |
| F07 | `01_introduction.tex:7–9` | SoC hiện đại tích hợp nhiều cảm biến; I2C được sử dụng rộng rãi | Chưa chỉ định | Có khả năng cần citation | Minor | 2 — Có khả năng | Chỉ xác minh metadata | Là nhận định bối cảnh phổ quát nhưng “thường/rộng rãi” có tính ngoại sinh. | Nếu giữ sắc thái định lượng/phổ biến, thêm survey/standard phù hợp; nếu không, viết trung tính. |
| F08 | `02_background_requirements.tex:16` | Hạn chế RC và static-address/manual configuration của I2C | `nxp_i2c`, `mipi_i3c_basic` | Thiếu citation | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Là kiến thức/so sánh chuẩn; citation ở hai đoạn trước không xác định rõ phạm vi cho toàn bộ câu này, đặc biệt mệnh đề thiếu DAA. | Cite NXP cho RC/static address và MIPI cho DAA ngay cuối câu. |
| F09 | `02_background_requirements.tex:28–30` (§2.1.3) | Định nghĩa START, STOP, Repeated START, Bus Free/Available/Idle | `mipi_i3c_basic`, `nxp_i2c` | Thiếu citation | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Các định nghĩa và điều kiện timing đến từ specification. | Tách phạm vi và cite ngay sau nhóm định nghĩa tương ứng. |
| F10 | `02_background_requirements.tex:32–90` (Hình `fig:start-sr-stop`) | Waveform START/Sr/STOP tự vẽ từ định nghĩa chuẩn, caption không nguồn | MIPI/NXP | Lỗi citation của hình | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Tác giả có thể tự vẽ, nhưng nội dung dữ liệu/frame đến từ chuẩn. | Caption: “Tác giả vẽ theo ...”; cite MIPI/NXP. |
| F11 | `02_background_requirements.tex:96–111` | Quy tắc OD/PP và handoff chi tiết | `mipi_i3c_basic` | Thiếu citation / citation không rõ phạm vi | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | C09 ở dòng 127 chỉ nằm trong đoạn takeover, không thể hiện rõ là nguồn cho handoff. | Cite ngay cuối đoạn OD/PP và cuối mô tả handoff; có thể thêm section locator. |
| F12 | `02_background_requirements.tex:113–120`; `figures/i3c_low_handoff_timing.tex` | Waveform handoff ACK Open-Drain không attribution trong caption | MIPI Basic §5.1.2.3.1 | Lỗi citation của hình | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Hình tự vẽ nhưng sequence/timing là nội dung đặc tả. | Ghi “phỏng theo”/“tác giả vẽ theo” và cite section thích hợp. |
| F13 | `02_background_requirements.tex:103–111` | Trình tự diễn đạt handoff bám sát thứ tự bước của đặc tả | MIPI Basic §5.1.2.3.1 | Có nguy cơ paraphrase quá sát nguồn | Major | 4 — Đã xử lý citation ở F11 | Đã xác minh trực tiếp | **Có dấu hiệu cần kiểm tra nguy cơ paraphrase quá sát nguồn.** Chưa có đủ cơ sở để kết luận đạo văn. | Viết lại theo phân tích thiết kế, rút gọn chi tiết, cite section; nếu giữ diễn đạt gần nguyên văn thì dùng quote/locator theo quy định. |
| F14 | `02_background_requirements.tex:129–136`; `figures/i3c_read_takeover_timing.tex` | Caption waveform takeover không nêu quan hệ với nguồn dù prose có citation | `mipi_i3c_basic` | Lỗi citation của hình | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Citation trong prose hỗ trợ cơ chế nhưng caption standalone không attribution cho hình dẫn xuất. | Thêm attribution/citation ngay caption. |
| F15 | `02_background_requirements.tex:141` | Mô tả chi tiết SDR Private Write/Read frame, `0x7E`, OD/PP, T-Bit | `mipi_i3c_basic` | Thiếu citation | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Toàn bộ phần đầu là nội dung chuẩn; phần ba yêu cầu RTL cuối câu là suy luận nội bộ. | Chia câu: cite phần frame chuẩn; giữ riêng phần suy luận thiết kế không cần nguồn ngoài. |
| F16 | `02_background_requirements.tex:143–207` (Hình `fig:sdr-frame`) | Hai frame SDR tự vẽ nhưng không nguồn dữ liệu | `mipi_i3c_basic` | Lỗi citation của hình | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Attribution bắt buộc dù đồ họa do tác giả dựng. | Ghi “tác giả tổng hợp từ...” và cite section/figure tương ứng. |
| F17 | `02_background_requirements.tex:212` | Một đoạn rất dài tái hiện nguyên trình tự ENTDAA, citation chỉ ở cuối | `mipi_i3c_basic` | Citation không rõ phạm vi / nguy cơ paraphrase quá sát | Major | 4 — Đã có citation | Đã xác minh trực tiếp | Nguồn hỗ trợ nội dung, nhưng phạm vi một citation cho nhiều mệnh đề dài gây mơ hồ. **Có dấu hiệu cần kiểm tra nguy cơ paraphrase quá sát nguồn.** | Chia đoạn theo opening/round/termination, cite từng phần hoặc một câu dẫn rõ “theo §...”; viết lại theo mục tiêu RTL. |
| F18 | `02_background_requirements.tex:214–265` (Hình `fig:entdaa`) | Frame ENTDAA tự vẽ, caption “Định dạng ENTDAA” không nguồn | `mipi_i3c_basic` | Lỗi citation của hình | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Dữ liệu frame, trường PID/BCR/DCR/parity đến từ spec. | Thêm attribution và citation trong caption. |
| F19 | `02_background_requirements.tex:227–236` (Hình `fig:entdaa`) | Sau opcode `0x07` hình đi thẳng sang Sr, bỏ T-Bit | MIPI Basic: mọi CCC opcode là 8 bit theo sau bởi T-Bit | Citation không hỗ trợ nội dung / lỗi kỹ thuật của hình | Major | 4 — Không phải lỗi thiếu cite | Đã xác minh trực tiếp | Hình mâu thuẫn nguồn sơ cấp và cả frame CCC ngay sau đó. | Chèn T-Bit sau `0x07`; kiểm tra lại ACK/T-Bit ở từng trường trước khi cite. |
| F20 | `02_background_requirements.tex:267–269` | SETDASA, SETAASA, RSTDAA, SETNEWDA và chức năng | `mipi_i3c_basic` | Thiếu citation | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Danh mục/ý nghĩa opcode là kiến thức chuẩn dù ngoài phạm vi hiện thực. | Cite MIPI tại cuối câu. |
| F21 | `02_background_requirements.tex:274–277` | Định nghĩa CCC, Broadcast/Direct và trình tự Direct | `mipi_i3c_basic` | Thiếu citation | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Định nghĩa protocol không phải quyết định nội bộ. | Cite MIPI ngay sau định nghĩa. |
| F22 | `02_background_requirements.tex:279–336` (Hình `fig:ccc-frames`) | Frame ENEC/DISEC và opcode không attribution | `mipi_i3c_basic` | Lỗi citation của hình | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Nội dung frame/opcode từ spec. | Caption “phỏng theo/tổng hợp từ...” và cite. |
| F23 | `02_background_requirements.tex:338–353` (Bảng `tab:ccc`) | Opcode `00/01/07/80/81` và chức năng không nguồn | `mipi_i3c_basic` | Lỗi citation của bảng | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Đây là giá trị normative. | Đưa citation vào caption hoặc note nguồn dưới bảng. |
| F24 | `02_background_requirements.tex:358–379` (Bảng `tab:i3c-vs-i2c`) | So sánh 400 kHz/12,5 MHz, OD/PP, DAA, T-Bit, coexistence | `mipi_i3c_basic`, `nxp_i2c` | Lỗi citation của bảng | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Các dữ kiện xuất hiện rải rác có cite trước đó, nhưng bảng standalone không nêu nguồn tổng hợp. | Thêm note/caption nguồn cho hai cột và tránh biến nhận định phạm vi thiết kế thành claim toàn chuẩn. |
| F25 | `03_architecture_rtl.tex:55` | “kế thừa cách tổ chức module và mô hình Descriptor” chỉ cite root repo động | `chipsalliance_i3c` | Citation chỉ hỗ trợ một phần | Major | 4 — Đã có citation, cần chính xác hóa | Đã xác minh trực tiếp | Root repo không định danh commit/path hay phần nào reuse/modify; current upstream đã thay đổi. | Pin commit/tag dùng khi phát triển, cite path/module/descriptor cụ thể; lập bảng reused/modified/rewritten. |
| F26 | `03_architecture_rtl.tex:262` | “tuân theo quy ước MIPI TCRI/HCI” nhưng chỉ cite TCRI; cùng citation đứng sau cả thứ tự ưu tiên lỗi | `mipi_i3c_tcri`; HCI v1.2 chưa có entry | Citation chỉ hỗ trợ một phần | Major | 1 — Chắc chắn nếu giữ “HCI” | Đã xác minh trực tiếp | TCRI v1.0 tồn tại và định nghĩa command/response; thứ tự ưu tiên là nội bộ. HCI bị nhắc nhưng không cite/version. | Tách câu: cite TCRI cho code/layout; mô tả priority là quyết định RTL. Xóa “/HCI” hoặc thêm entry HCI v1.2 đã xác minh. |
| F27 | `03_architecture_rtl.tex:262,278`; `04_verification.tex:386`; `src/rtl/i3c_pkg.sv:56–69` | Báo cáo gọi code `0x9` là `I2cDataNack`; RTL/TCRI dùng `I2cDataNackOrI3cBusAborted` | TCRI Table 11 + RTL | Nội dung không khớp bằng chứng nội bộ | Major | 3 — Không cần citation ngoài mới | Không áp dụng — bằng chứng nội bộ | Tên ngắn làm mất nửa ý nghĩa chuẩn và không khớp enum hiện hành. | Dùng đúng enum đầy đủ; nếu thiết kế chỉ sinh nhánh I2C, nói rõ đó là policy hiện thực, không đổi tên chuẩn. |
| F28 | `Appendix/appendixA.tex:4–54` | Map CSR/DAT dùng tên HCI/i3c-core nhưng không nêu phần nào custom/phỏng theo | CHIPS i3c-core/HCI | Có khả năng cần citation / lỗi citation của bảng | Major | 2 — Có khả năng | Đã xác minh trực tiếp | Giá trị địa chỉ hiện hành là bằng chứng nội bộ; nguồn gốc naming/layout có dấu hiệu kế thừa. **Có khả năng cần citation — cần tác giả xác nhận nguồn gốc nội dung.** | Tác giả xác nhận nguồn gốc; nếu derived, thêm câu dẫn nguồn và phân biệt địa chỉ custom với HCI/upstream. |
| F29 | `Appendix/appendixB.tex:4–68` | Response/Immediate/Regular/AddressAssignment descriptor fields trùng cấu trúc TCRI, không cite | `mipi_i3c_tcri` | Thiếu citation / lỗi citation của bảng | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | `src/rtl/i3c_pkg.sv` tự ghi locator TCRI §§7.1.2–7.1.3; phụ lục chỉ nói “định nghĩa trong i3c_pkg”. | Thêm câu “bố trí phỏng theo TCRI v1.0 ...”, cite source, rồi nêu các field/ràng buộc do thiết kế rút gọn. |
| F30 | `04_verification.tex:33–44` | Directed và constrained-random stimulus | UVM User’s Guide / tài liệu verification uy tín | Thiếu citation | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Hai khái niệm methodology bên ngoài được định nghĩa mà không neo nguồn. | Cite UVM User’s Guide hoặc nguồn sơ cấp phù hợp ở lần giới thiệu; phần policy từng vseq là nội bộ. |
| F31 | `04_verification.tex:46–58` | Vai trò Scoreboard, SVA, Functional Coverage | IEEE 1800; UVM User’s Guide/Class Reference | Thiếu citation | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Định nghĩa methodology cần nguồn; đã đọc trực tiếp UVM Guide nhưng IEEE chỉ xác minh metadata. Mô tả checker cụ thể của dự án không cần nguồn ngoài. | Cite chuẩn tại tên cơ chế, sau đó tách mô tả hiện thực nội bộ. |
| F32 | `04_verification.tex:63–88` | UVM Configuration Database, monitor, analysis port/subscriber | `uvm12_ug`, `uvm12_ref` | Thiếu citation | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Đây là API/kiến trúc UVM 1.2. | Cite UVM 1.2 User Guide/Class Reference ở lần đầu; giữ wiring cụ thể là evidence nội bộ. |
| F33 | `04_verification.tex:145–156` | SVA, assertion/cover property, vacuous pass | `ieee1800` | Thiếu citation | Major | 1 — Chắc chắn | Chỉ xác minh metadata | Khái niệm ngôn ngữ/semantics chuẩn cần IEEE; kết quả kích hoạt là nội bộ. | Cite IEEE 1800-2017 và tránh diễn đạt semantics chi tiết hơn phần đã đọc/xác minh. |
| F34 | `04_verification.tex:158–181`; `flow_active_sva.sv:760–804` | Listing “minh họa” bỏ `else $error` và hai cover parity 0/1, không ghi đường dẫn/rút gọn | Mã nội bộ | Thiếu thông tin nguồn của listing/mã nguồn | Minor | 3 — Không cần citation ngoài | Không áp dụng — bằng chứng nội bộ | Listing không sai assertion chính nhưng có thể bị hiểu là trích nguyên file hiện hành. | Caption/note: “trích rút gọn từ ...:760”; nêu phần lược bỏ. |
| F35 | `04_verification.tex:183–223` | Covergroup, coverpoint, cross, illegal bin, `uvm_subscriber`, analysis port | IEEE 1800; UVM 1.2 | Thiếu citation | Major | 1 — Chắc chắn | Đã xác minh trực tiếp | Đã đọc trực tiếp API UVM liên quan; phần semantics IEEE chỉ xác minh metadata. Policy closure/diagnostic là nội bộ. | Cite IEEE/UVM cho khái niệm; tách rõ policy tự xây dựng. |
| F36 | `04_verification.tex:370–408`; `thesisterms.sty:124–135`; `src/verification/Makefile:32–131` | Bảng vseq ghi tổng 80 và nhóm 11/14/5/6/8/5/4/9/4/14; Makefile hiện có 81 với nhóm 11/14/5/5/6/4/3/5/7/21 | Makefile hiện hành | Nội dung không khớp bằng chứng nội bộ | Major | 3 — Không cần citation ngoài | Không áp dụng — bằng chứng nội bộ | Macro/bảng là snapshot cũ; current Makefile là source of truth chạy regression. | Sinh số đếm từ Makefile hoặc cập nhật macro/bảng và lưu script đếm tái lập. |
| F37 | `05_results.tex:18–75,421–462,517–520`; `06_conclusion.tex:26–30`; `Appendix/appendixE.tex:15–23`; artifacts | Báo cáo 81/81; `regression_result.txt` ghi `total=80 pass=80`; coverage/SVA ghi “Tests analysed: 81” | Artifact nội bộ | Nội dung không khớp bằng chứng nội bộ | Major | 3 — Không cần citation ngoài | Không áp dụng — bằng chứng nội bộ | Ba nguồn nội bộ không tạo một baseline thống nhất. Makefile hiện có 81 test nhưng grouping khác bảng báo cáo. | Chạy lại release regression hoặc giải thích rõ hai snapshot; không in “81/81” cho đến khi có summary 81 tương ứng. |
| F38 | `Appendix/appendixE.tex:4–24` | Comment trỏ `src/verification/logs/...` không tồn tại; listing “total=81 ... error=0” không phải format/nội dung file thật | Artifact nội bộ | Lỗi bằng chứng nội bộ / trích đoạn không trung thực với nguồn | Major | 3 — Không cần citation ngoài | Không áp dụng — bằng chứng nội bộ | File thật là `src/verification/regression_result.txt` và không có cột `error=0` trong summary. | Trích tự động từ artifact thật, ghi path và hash/commit; không tự dựng excerpt dưới nhãn “trích”. |
| F39 | `05_results.tex:18–24` | “mọi số liệu ... cùng một trạng thái mã nguồn” | Không có manifest/commit trong artifact | Thiếu bằng chứng nội bộ | Major | 3 — Không cần citation ngoài | Không áp dụng — bằng chứng nội bộ | Ba report không chứa commit hash/tool version/source manifest; working tree hiện bẩn nên không thể chứng minh cùng snapshot. | Ghi commit, dirty flag, Xcelium version, command, seed và hash input/artifact trong baseline. |
| F40 | `05_results.tex:18–22` | “Cố định seed bảo đảm bộ kết quả tái lập chính xác” | Chưa chỉ định | Có khả năng cần citation / phát biểu tuyệt đối | Minor | 2 — Có khả năng | Không áp dụng — bằng chứng nội bộ | Seed chỉ kiểm soát random stream trong cùng tool/config; không đảm bảo khác version, compile order hay source. | Đổi thành “hỗ trợ tái lập trong cùng môi trường”; ghi version/options. Citation chỉ cần nếu giữ claim tổng quát. |
| F41 | `05_results.tex:412–414,448–452`; `sva_coverage_report.txt` | “mọi thuộc tính ... được kiểm tra trong mọi lần chạy” | SVA report có property `tests=1`, `tests=18`, ... | Nội dung không khớp bằng chứng nội bộ | Major | 3 — Không cần citation ngoài | Không áp dụng — bằng chứng nội bộ | Không phải assertion/transaction nào cũng kích hoạt trong 81 test; báo cáo SVA ghi rõ số test khác nhau cho từng property. | Đổi thành “được checker kiểm tra trong các test liên quan”; dẫn số `tests=` khi cần. |
| F42 | `05_results.tex:270,301,322`; `figures/daa1_png.png`, `daa5_png.png`, `daa4_png.png` | Ba waveform DAA dùng trong PDF nhưng là file untracked | Artifact simulation nội bộ | Lỗi bằng chứng nội bộ / lỗi hình | Major | 3 — Không cần citation ngoài | Không áp dụng — bằng chứng nội bộ | Build hiện tại thành công chỉ vì file tồn tại trong working tree; clone commit không tái tạo được ba hình. | Track file hoặc quy trình sinh hình; ghi test/seed/time window và nguồn simulation trong caption/manifest. |
| F43 | `05_results.tex:409–410` | I2C 400 kHz “trục thời gian rộng hơn gần một bậc” so với I3C 12,5 MHz | Waveform/tần số nội bộ | Nội dung không khớp bằng chứng nội bộ / suy luận sai | Minor | 3 — Không cần citation ngoài | Không áp dụng — bằng chứng nội bộ | Tỷ số tần số danh định là 31,25 (~1,5 bậc), còn bề rộng hình phụ thuộc zoom/time window; câu không được phép suy ra chỉ từ ảnh. | So sánh duration đo được với cùng số byte và cùng scale, hoặc bỏ “gần một bậc”. |
| F44 | `Appendix/tomtat.tex:4–16` (Tóm tắt VI) | Lịch sử/lợi ích I3C, 12,5 MHz/400 kHz và claim upstream “FSM còn bỏ ngỏ” không cite | MIPI/NXP/CHIPS | Có khả năng cần citation | Minor | 2 — Có khả năng | Đã xác minh trực tiếp | Nhiều trường không cho citation trong abstract; tuy nhiên claim so sánh/upstream cụ thể cần nguồn ở thân bài và exact commit/diff. | Xác nhận quy định khóa luận; nếu cấm citation, làm mềm câu và bảo đảm lần xuất hiện đầu trong thân bài có nguồn; không giữ “bỏ ngỏ” nếu chưa pin evidence. |
| F45 | `Appendix/tomtat.tex:34–46` (Abstract EN) | Bản tiếng Anh lặp các claim ngoại sinh/upstream không cite | MIPI/NXP/CHIPS | Có khả năng cần citation | Minor | 2 — Có khả năng | Đã xác minh trực tiếp | Cùng vấn đề F44; đã kiểm cả hai ngôn ngữ, không giả định bản dịch tự được bao phủ. | Áp dụng cùng convention với Tóm tắt VI và giữ hai bản nhất quán. |
| F46 | `Appendix/tomtat.tex:18–20,48–50`; `01_introduction.tex:56`; toàn `05_results.tex` | Hứa “quy mô mã nguồn” và “so sánh với bản tham chiếu” ở Chương Kết quả nhưng Ch5 không có các số liệu đó | Nội bộ | Nội dung không khớp bằng chứng nội bộ | Major | 3 — Không cần citation ngoài | Không áp dụng — bằng chứng nội bộ | Abstract/outline mô tả nội dung không tồn tại trong báo cáo chính thức. | Bổ sung metric/methodology so sánh có thể tái lập hoặc bỏ các lời hứa này khỏi VI/EN/outline. |
| F47 | `References/references.bib:34–38` | `uvm12_ref` chưa cite | Accellera UVM 1.2 Class Reference | Reference không được sử dụng | Minor | 4 — Không áp dụng | Chỉ xác minh metadata | Nguồn phù hợp cho F32/F35 nhưng hiện không in trong bibliography. | Cite đúng API UVM hoặc xóa nếu chỉ dùng User’s Guide. |
| F48 | `References/references.bib:48–55` | `palnitkar_verilog` chưa cite | Sách Palnitkar | Reference không được sử dụng | Minor | 4 — Không áp dụng | Chỉ xác minh metadata | Không có nội dung chính thức đang dựa rõ vào sách này. | Cite tại kiến thức Verilog thực sự lấy từ sách hoặc xóa entry. |
| F49 | `References/references.bib:57–64` | `spear_sv` chưa cite | Sách Spear & Tumbush | Reference không được sử dụng | Minor | 4 — Không áp dụng | Chỉ xác minh metadata | Có thể dùng cho verification concepts nhưng hiện không cite. | Chỉ cite nếu đã đọc phần hỗ trợ trực tiếp; nếu không, xóa. |
| F50 | `References/references.bib:66–73` | `harris_ddca` chưa cite | Sách Harris & Harris | Reference không được sử dụng | Minor | 4 — Không áp dụng | Chỉ xác minh metadata | Không có claim digital architecture nào dẫn nguồn này. | Cite đúng nội dung hoặc xóa. |
| F51 | `References/references.bib:83–89` | `opentitan_dv` chưa cite dù repo dùng `dv_macros.svh` | OpenTitan official repo/file | Reference không được sử dụng | Major | 4 — Citation location đã ghi F01 | Đã xác minh trực tiếp | Đây không phải “entry chết” vô hại: nó liên quan trực tiếp attribution code. | Cite ở phần methodology/acknowledgement và pin file+commit; giữ license notice. |
| F52 | `References/references.bib:91–99` | `chauhan_i3c_uvm` chưa cite | Entry có DOI sai, xem F06 | Reference không được sử dụng | Major | 4 — Không áp dụng | Đã xác minh trực tiếp | Dù chưa gây citation sai trong PDF, entry sai metadata là rủi ro nếu được dùng sau này. | Xóa/quarantine ngay; không “sửa đoán” DOI/title. |
| F53 | `References/references.bib:101–108` | `verma_uvm_fv` chưa cite | Không xác minh được | Reference không được sử dụng | Major | 4 — Không áp dụng | Không thể xác minh nguồn | Entry không xuất hiện trong bibliography PDF và không có locator. | Xóa nếu không có bản gốc; nếu tác giả có PDF, xác minh từng metadata trước khi dùng. |
| F54 | `References/references.bib:34–38` | UVM 1.2 Class Reference ghi năm 2015 | [Accellera UVM downloads](https://www.accellera.org/downloads/standards/uvm) | Sai metadata | Minor | 4 — Không áp dụng | Đã xác minh trực tiếp | Trang chính thức ghi Class Reference/Reference Implementation **2014-06**; User’s Guide là 2015-10. | Sửa date/year của Class Reference theo tài liệu cụ thể; không đánh đồng hai ấn phẩm. |
| F55 | `References/references.bib:1–6` | `mipi_i3c_basic` ghi `year=2022`, note Errata 01 | [MIPI version page](https://www.mipi.org/specifications/i3c-sensor-specification) | Metadata chưa đủ rõ | Minor | 4 — Không áp dụng | Đã xác minh trực tiếp | Bản base v1.1.1 đề ngày 09-Jun-2021; Errata 01 là mốc khác và có thể khiến 2022 có ý nghĩa nếu cite bản hợp nhất. | Ghi ngày/version/errata rõ ràng; nếu cần, tách base spec và errata thành hai entry. |
| F56 | `references.bib:1–18,28–38` | MIPI Basic, TCRI, NXP và hai tài liệu UVM không có URL/urldate/identifier truy cập | Trang chính thức tương ứng | Thiếu thông tin nguồn | Minor | 4 — Không áp dụng | Đã xác minh trực tiếp | `@manual` không bắt buộc URL trong mọi style, nhưng thiếu locator làm giảm khả năng kiểm chứng; riêng UVM Class Reference chỉ mới xác minh metadata. | Thêm URL chính thức ổn định và urldate nhất quán; ưu tiên DOI/number nếu có. |
| F57 | `References/references.bib:75–89` | CHIPS/OpenTitan dùng root repo động, `year=2024`, không commit/tag/path | Official GitHub repos | Thiếu thông tin nguồn / metadata repo | Major | 4 — Không áp dụng | Đã xác minh trực tiếp | Năm repo không đại diện publication snapshot; root URL không tái lập lineage/code. | Dùng `@software`/`@online` theo convention, thêm version/commit, exact path, date và urldate. |
| F58 | `References/references.bib:40–46` | Trang sản phẩm Cadence ghi `year=2026` bằng năm truy cập | Cadence Xcelium product page | Sai/không rõ metadata | Minor | 4 — Không áp dụng | Đã xác minh trực tiếp | Trang động không nêu 2026 là publication year; `urldate=2026-07-04` đã mang nghĩa truy cập. | Bỏ year nếu không có publication date, hoặc dùng date/version tài liệu sản phẩm cụ thể. |
| F59 | `References/references.bib:48–73` | Edition viết `2nd/3rd`; Spear có DOI sách chính thức nhưng entry chỉ ISBN | WorldCat/Springer/Elsevier | Sai định dạng / thiếu metadata khuyến nghị | Minor | 4 — Không áp dụng | Chỉ xác minh metadata | BibLaTeX thường dùng edition số để localized; DOI `10.1007/978-1-4614-0715-7` có thể tăng traceability cho Spear. | Chuẩn hóa `edition={2}`/`{3}` theo convention và thêm DOI **sau khi** kiểm tra bản/ISBN khớp. |
| F60 | `References/references.bib:101–108` | `verma_uvm_fv` không URL, DOI, pages và không tìm được exact record | `verma_uvm_fv` | Nguồn không thể xác minh / thiếu metadata | Major | 4 — Không áp dụng | Không thể xác minh nguồn | **Chưa thể xác minh nội dung nguồn — cần kiểm tra thủ công.** Không đủ căn cứ gọi đây là paper thật hay dùng nó hỗ trợ claim. | Yêu cầu tác giả cung cấp PDF/landing page chính thức; nếu không có, xóa entry. |
| F61 | `report.tex:240–241`; build log | `\DeclareNameAlias{...}{last-first}` bị BibLaTeX 3.21 deprecate | BibLaTeX hiện hành | Sai định dạng / build warning | Minor | 4 — Không áp dụng | Không áp dụng — bằng chứng nội bộ | Build vẫn thành công nhưng convention dùng tên format cũ. | Thay bằng alias hiện hành tương đương sau khi kiểm tra output tên; build lại release. |
| F62 | `01_introduction.tex:23–24` | Citation IEEE/UVM/Cadence gắn vào câu “được dùng” trong dự án | C04 | Citation chỉ hỗ trợ một phần / không rõ phạm vi | Minor | 4 — Đã có citation | Đã xác minh trực tiếp | Trang chuẩn/sản phẩm chứng minh công cụ tồn tại và hỗ trợ tính năng, không chứng minh run của khóa luận; bằng chứng đó phải đến từ Makefile/log/manifest. | Tách câu nguồn ngoài (định danh chuẩn/công cụ) khỏi câu evidence nội bộ; ghi version/tool log trong Ch5. |

## 4. Rà câu/đoạn chưa citation và nguồn gốc hình–mã

### Ma trận phân loại phạm vi

| Phạm vi | Phân loại chính | Kết quả |
|---|---|---|
| Title, Lời cảm ơn, bố cục/chuyển ý | 4 — Không áp dụng | Không cần nguồn ngoài. |
| Lời cam đoan | 3/1 | Bằng chứng nội bộ cho authorship; F01–F02 là ngoại lệ Critical. |
| Tóm tắt/Abstract | 2/3 | Claim chuẩn/upstream có khả năng cần citation tùy quy định; kết quả thiết kế là nội bộ (F44–F46). |
| Chương 1 | 1/2/3 | Citation hiện có nhìn chung đúng; bối cảnh và tool provenance xem F07/F62. |
| Chương 2 | 1 | Phần lớn định nghĩa/frame/timing là external; các lỗ hổng được tách F08–F24. Timing table đã có câu nguồn tại dòng 381–385 nên không báo thiếu. |
| Chương 3 | 3, trừ lineage/standard | Kiến trúc/FSM/queue do repo chứng minh không cần cite ngoài; lineage, HCI/TCRI và hai hình spec là F03–F05/F25–F29. |
| Chương 4 | 1 cho methodology; 3 cho implementation | UVM/SVA/coverage API cần nguồn; wiring/scoreboard/vseq của dự án không cần (F30–F36). |
| Chương 5–6 | 3 | Kết quả/waveform không cần citation ngoài nhưng phải khớp artifact (F37–F46). |
| Phụ lục A/B/C/E | 1/2/3 | A/B cần làm rõ nguồn descriptor/HCI; C là sơ đồ RTL nội bộ; E là artifact nội bộ nhưng hiện lệch nguồn. |
| Công thức/pseudocode/algorithm | 4 | Không có algorithm/pseudocode chính thức được include. Parity/timing là nội dung chuẩn đã được xét ở prose/figure/listing. |
| Footnote | 4 | Không có footnote chứa claim/citation trong include graph. |

### Audit asset đang dùng

| Nhóm asset | Kết luận nguồn gốc |
|---|---|
| START/Sr/STOP, handoff, takeover, SDR, ENTDAA, CCC | Tác giả vẽ/TikZ nhưng dữ liệu protocol từ MIPI/NXP; cần attribution như F10/F12/F14/F16/F18/F22. |
| `i3c_primary_controller_fsm.tex` | Dẫn xuất rõ từ MIPI Figure 168; Critical F03; đồng thời không phải FSM RTL hiện hành F04. |
| `entdaa_fsm.tex` ở Ch3 | Dẫn xuất rõ từ MIPI Figure 170; Critical F05. |
| `i3c_controller_top_architecture.pdf`, `csr_queue_handshake.tex`, `uvm_i3c_verification_architecture_uvm.pdf` | Sơ đồ kiến trúc/handshake nội bộ, đối chiếu được với repo; không cần citation ngoài nếu không tuyên bố lấy upstream. |
| Ba PDF FSM ở Appendix C | Khớp module/state nội bộ; không phát hiện copyright/URL ngoài; không cần citation ngoài. |
| 10 PNG waveform Ch5 | Được mô tả là kết quả SimVision của dự án; không cần citation ngoài. Ba PNG DAA chưa tracked, xem F42. Không phát hiện metadata chứng minh nguồn ngoài. |
| Listing SVA | Code nội bộ, không cần citation ngoài; cần locator và nhãn “rút gọn”, F34. |
| Code upstream | `dv_macros.svh` là OpenTitan; `bus_rx_flow` có mô tả reuse nội bộ và tương đồng cấu trúc với CHIPS nhưng provenance lịch sử chưa chốt; xem F01–F02. |

Không phát hiện trích dẫn trực tiếp bằng ngoặc kép cần số trang trong prose. Hai đoạn F13/F17 chỉ được đánh dấu nguy cơ paraphrase; không kết luận đạo văn. Hai hình F03/F05 có bằng chứng đối chiếu trực tiếp mạnh hơn và được phân loại Critical attribution.

## 5. Chất lượng và metadata từng entry

| Key | Phân loại | Trạng thái xác minh | Nhận xét |
|---|---|---|---|
| `mipi_i3c_basic` | Primary source | Đã xác minh trực tiếp | Đúng v1.1.1; base 2021 + Errata 01 cần ghi ngày rõ (F55). [Trang MIPI](https://www.mipi.org/specifications/i3c-sensor-specification). |
| `mipi_i3c_tcri` | Primary source | Đã xác minh trực tiếp | v1.0 phát hành 2022, đúng baseline dự án; current web version là v1.1 (2025), không tự động làm v1.0 sai. [MIPI TCRI](https://www.mipi.org/specifications/i3c-tcri). |
| `nxp_i2c` | Primary source | Đã xác minh trực tiếp | UM10204 Rev.7.0, 1-Oct-2021. [NXP PDF](https://www.nxp.com/docs/en/user-guide/UM10204.pdf). |
| `ieee1800` | Primary source | Chỉ xác minh metadata | Number/DOI/year hợp lý; chưa đọc toàn văn chuẩn. [IEEE 1800-2017](https://standards.ieee.org/ieee/1800/6700/). |
| `uvm12_ug` | Primary source | Đã xác minh trực tiếp | User’s Guide ngày 2015-10 đúng. [Accellera PDF](https://www.accellera.org/images/downloads/standards/uvm/uvm_users_guide_1.2.pdf). |
| `uvm12_ref` | Primary source | Chỉ xác minh metadata | Official release 2014-06, không phải 2015 (F54). |
| `cadence_xcelium` | Primary source | Đã xác minh trực tiếp | Trang sản phẩm chính thức phù hợp để định danh capability, không chứng minh tool run nội bộ; year không ổn định (F58). |
| `palnitkar_verilog` | Reliable secondary source | Chỉ xác minh metadata | Sách uy tín nhưng chưa cite; không dùng nó để suy ra support khi chưa đọc đoạn liên quan. |
| `spear_sv` | Reliable secondary source | Chỉ xác minh metadata | Springer xác nhận 3rd ed., 2012, ISBN/DOI; chưa cite. [Springer](https://link.springer.com/book/10.1007/978-1-4614-0715-7). |
| `harris_ddca` | Reliable secondary source | Chỉ xác minh metadata | Elsevier xác nhận 2nd ed./ISBN; chưa cite. [Elsevier](https://shop.elsevier.com/books/digital-design-and-computer-architecture/harris/978-0-12-394424-5). |
| `chipsalliance_i3c` | Primary source | Đã xác minh trực tiếp | Official repo; phù hợp lineage, nhưng phải pin commit/path (F25/F57). [i3c-core](https://github.com/chipsalliance/i3c-core). |
| `opentitan_dv` | Primary source | Đã xác minh trực tiếp | Official source/file, trực tiếp liên quan `dv_macros.svh`; root URL hiện quá rộng (F01/F51/F57). |
| `chauhan_i3c_uvm` | Unverifiable source | Đã xác minh trực tiếp | Claimed paper không khớp DOI; không được coi là reliable paper (F06). |
| `verma_uvm_fv` | Unverifiable source | Không thể xác minh nguồn | Không exact record/locator; **chưa thể xác minh nội dung nguồn — cần kiểm tra thủ công** (F60). |

Phân loại là loại trừ lẫn nhau: **Primary 9**, **Reliable secondary 3**, **Weak 0**, **Unverifiable 2**. Cadence là primary product documentation khi chỉ hỗ trợ capability của chính sản phẩm; nếu dùng để chứng minh ưu thế học thuật rộng hơn thì sẽ trở thành nguồn không phù hợp, nhưng report hiện không làm vậy.

Kiểm tra format tổng quát: `@manual` phù hợp cho standard/guide, `@book` phù hợp cho ba sách và `@online` chấp nhận được cho product/repository động (dù `@software` có thể chính xác hơn cho repo nếu convention/style hỗ trợ). `@inproceedings` của F06 chỉ đúng về loại hình giả định, nhưng metadata thực tế sai; `@article` của F60 có trường lõi nhưng thiếu locator/pages và không xác minh được. Tên tổ chức/acronym quan trọng nhìn chung đã được bảo toàn bằng `{}`; các `urldate` hiện có hợp lý và nhất quán về ISO date. Không có missing field làm BibTeX warning, nhưng “không warning” không thay thế các thiếu sót metadata F54–F60.

## 6. Thống kê tái lập

Quy tắc đếm:

- “Lệnh citation” = mỗi command `\cite{...}` tính 1.
- “Lượt citation key” = mỗi key trong command tính 1, kể cả lặp; `\cite{a,b}` = 1 lệnh, 2 lượt key.
- “Key duy nhất” = tập hợp key sau khi loại lặp.
- Số vị trí cần citation = số hàng Fxx mang mức 1 hoặc 2; một hàng là một vị trí/scope sửa độc lập, không phải số câu vật lý.
- Severity, hình/bảng, code và mismatch được đếm từ tag của bảng F01–F62. Một finding có thể thuộc thống kê hình và Critical đồng thời.

| Chỉ số | Giá trị |
|---|---|
| Tổng số lệnh citation | **13** |
| Tổng số lượt citation key, tính cả lặp | **17** |
| Tổng số citation key duy nhất | **7** |
| Tổng số entry trong `references.bib` | **14** |
| Citation key không có entry | **0** |
| Entry chưa được cite | **7**: `uvm12_ref`, `palnitkar_verilog`, `spear_sv`, `harris_ddca`, `opentitan_dv`, `chauhan_i3c_uvm`, `verma_uvm_fv` |
| Entry trùng/có khả năng trùng | **0** |
| Vị trí chắc chắn cần thêm citation/attribution | **25**: F01, F02, F03, F05, F08–F12, F14–F16, F18, F20–F24, F26, F29–F33, F35 |
| Vị trí có khả năng cần citation | **5**: F07, F28, F40, F44, F45 |
| Citation hiện có không hỗ trợ hoặc chỉ hỗ trợ một phần | **3 lệnh**: C04/F62, C12/F25, C13/F26 |
| Nguồn Primary | **9** |
| Nguồn Reliable secondary | **3** |
| Nguồn Weak | **0** |
| Nguồn Unverifiable | **2** |
| Lỗi hình/bảng | **15 finding**: F03–F05, F10, F12, F14, F16, F18–F19, F22–F24, F28–F29, F42 |
| Lỗi thuật toán/listing/mã nguồn | **3**: F01, F02, F34 |
| Vị trí có nguy cơ paraphrase quá sát | **2**: F13, F17 |
| Lỗi nội dung/bằng chứng nội bộ | **10**: F04, F27, F36–F39, F41–F43, F46 |
| Critical | **5**: F01, F02, F03, F05, F06 |
| Major | **40** |
| Minor | **17** |
| Tổng finding | **62** |
| Citation style/convention thực tế | **BibLaTeX numeric**, `sorting=nty`, `backend=bibtex`; bibliography theo name–title–year |

Lệnh tái lập cơ học nên chạy trên đúng include graph (không tính draft/generated): dùng `rg` cho nhóm command citation; tách phần trong `{}` theo dấu phẩy để đếm lượt key; dùng `rg '^@' References/references.bib` để đếm entry; so sánh hai tập key. Kết quả còn được đối chiếu với `.aux/.bbl` của **bản build tạm**, không dùng các file đó làm bibliography nguồn.

### Đánh giá tổng thể

- **Tính đầy đủ:** chưa đạt. Nhiều định nghĩa/frame/bảng protocol và methodology UVM/SVA chưa attribution; tóm tắt cần xác nhận convention.
- **Tính nhất quán cơ học:** tốt. Không undefined key, duplicate hay lỗi build citation; 7 key được resolve đúng.
- **Độ tin cậy nguồn:** chưa đạt do một DOI sai hoàn toàn (F06), một source không xác minh được (F60), và source code repo chưa pin snapshot.
- **Attribution hình/code:** chưa đạt; hai hình MIPI và code OpenTitan/CHIPS là rủi ro cao nhất.
- **Bằng chứng nội bộ:** chưa đạt do baseline 80/81, category drift, excerpt không khớp file thật và thiếu provenance snapshot.

Vì vậy không thể kết luận hệ thống citation “đạt” chỉ từ build sạch.

## 7. Checklist sửa theo thứ tự ưu tiên

1. **Nguy cơ đạo văn, bịa nguồn hoặc dẫn sai nguồn**
   - [ ] Xử lý authorship/license của OpenTitan; chốt provenance và nghĩa vụ license của RTL có dấu hiệu reuse; sửa lời cam đoan, notice, LICENSE và pin source theo kết quả xác minh (F01–F02).
   - [ ] Attribution/permission cho hai hình MIPI Figure 168/170 (F03, F05).
   - [ ] Loại bỏ/quarantine entry DOI sai trước khi ai đó cite (F06, F52).
   - [ ] Review paraphrase thủ công, không kết luận đạo văn khi chưa đối chiếu thêm (F13, F17).

2. **Citation mâu thuẫn hoặc không hỗ trợ nhận định**
   - [ ] Pin evidence cụ thể cho lineage CHIPS (F25).
   - [ ] Tách TCRI/HCI khỏi priority nội bộ và xử lý HCI source (F26).
   - [ ] Tách capability nguồn ngoài khỏi bằng chứng tool thực dùng (F62).

3. **Nội dung quan trọng chắc chắn cần citation**
   - [ ] Vá định nghĩa/frame/CCC/DAA/OD-PP ở Ch2 (F08–F12, F14–F16, F18, F20–F24).
   - [ ] Cite descriptor TCRI ở Appendix B (F29).
   - [ ] Neo nguồn UVM/IEEE cho methodology, SVA và coverage ở Ch4 (F30–F33, F35).

4. **Nội dung có khả năng cần citation, cần tác giả xác nhận**
   - [ ] Xác nhận claim bối cảnh SoC/I2C và quy tắc abstract (F07, F44–F45).
   - [ ] Xác nhận nguồn gốc map CSR Appendix A (F28).
   - [ ] Làm mềm claim exact reproducibility hoặc bổ sung nguồn/evidence (F40).

5. **Citation key và bibliography không khớp**
   - [ ] Quyết định cite-or-delete cho 7 entry chưa dùng, nhưng không cite chỉ để “làm sống” bibliography (F47–F53).

6. **Hình, bảng, thuật toán hoặc mã nguồn thiếu nguồn**
   - [ ] Sửa toàn bộ finding hình/bảng F03–F05, F10, F12, F14, F16, F18–F19, F22–F24, F28–F29, F42.
   - [ ] Ghi locator/rút gọn cho listing SVA (F34); attribution code theo F01–F02.

7. **Phát biểu không khớp RTL/UVM/regression**
   - [ ] Thay/đổi vai trò hình FSM protocol để không giả làm FSM RTL (F04).
   - [ ] Đồng bộ enum error 0x9 (F27).
   - [ ] Chọn một source-of-truth cho vseq/regression, sửa 80/81, artifact và Appendix E (F36–F38).
   - [ ] Gắn provenance/tool version/commit và sửa claim “mọi lần chạy” (F39, F41).
   - [ ] Track waveform DAA, sửa so sánh time scale, và bỏ lời hứa nội dung không tồn tại (F42–F43, F46).

8. **Nguồn yếu, không chính thức hoặc sai version**
   - [ ] Không dùng `chauhan_i3c_uvm`/`verma_uvm_fv` cho đến khi xác minh (F06, F52–F53, F60).
   - [ ] Xác nhận mốc base spec/Errata và baseline version chủ ý (F55).

9. **Metadata và định dạng BibLaTeX**
   - [ ] Sửa UVM Class Reference date, locator manual, metadata repo/Cadence, edition/DOI sách (F54–F59).
   - [ ] Thay name alias deprecated và build lại (F61).

10. **Dấu câu và trình bày nhỏ**
   - [ ] Giữ convention `~\cite` trước dấu chấm; không đổi sang IEEE/APA hay `sorting=none` nếu chưa có quy định chính thức.
   - [ ] Sau mọi sửa đổi, chạy lại chuỗi release và kiểm `.log/.blg/.bbl/PDF`; xác nhận numeric+`nty` với cơ sở đào tạo.

## 8. Kết luận

Hệ thống hiện **sạch về liên kết cơ học** nhưng **chưa đủ tin cậy về học thuật và bằng chứng**. Năm vấn đề Critical gồm attribution/authorship code OpenTitan, rủi ro provenance/license CHIPS cần chốt bằng lịch sử nguồn, hai hình MIPI không ghi nguồn, và một DOI gán sai hoàn toàn. Ngoài ra, baseline regression không thống nhất 80/81 và chưa có provenance đủ để chứng minh các số liệu cùng snapshot.

Các phần kiến trúc RTL, UVM tự xây dựng, waveform simulation và kết quả coverage/SVA **không bị yêu cầu citation ngoài một cách máy móc**; chúng được đánh giá bằng evidence nội bộ. Ngược lại, mọi claim tuân thủ/nguồn gốc MIPI–TCRI–HCI–UVM–CHIPS và mọi hình/code dẫn xuất vẫn phải có attribution cụ thể. Chỉ sau khi xử lý các finding Critical/Major, đồng bộ artifact và xác minh lại nguồn chưa truy cập đầy đủ mới có thể đánh giá hệ thống citation là đạt.
