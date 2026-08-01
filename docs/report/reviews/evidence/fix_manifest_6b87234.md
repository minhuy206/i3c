# Manifest trước khi sửa citation/bibliography

- Thời điểm chụp: `2026-07-22T18:18:42+0700` (Asia/Ho_Chi_Minh).
- Git HEAD: `6b87234bcc5d7d53009a358cc86b78ef72286403`.
- Digest SHA-256 của tập nội dung đang build (file gốc, BibTeX, 14 include trực tiếp,
  5 input lồng và 12 graphic active):
  `58df06c924271bcde0ba9725c8a0f0856c5e72b12a67bf620fab86cc809d181d`.
- Trạng thái bẩn tại thời điểm chụp: `Appendix/appendixCoverage.tex` và
  `chapters/04_verification.tex` là thay đổi nội dung có sẵn của người dùng;
  `report.xdv` và `report.synctex(busy)` là artifact do tiến trình biên dịch/editor sinh.
  Các file này không được restore/checkout/stage/ghi đè trong đợt sửa.

## Include graph hiện hành

`report.tex` có 14 lệnh `\input`/`\include` trực tiếp:

1. `Title/title.tex`
2. `Appendix/thanks.tex`
3. `Appendix/reassurances.tex`
4. `Appendix/tomtat.tex`
5. `chapters/01_introduction.tex`
6. `chapters/02_background_requirements.tex`
7. `chapters/03_architecture_rtl.tex`
8. `chapters/04_verification.tex`
9. `chapters/05_results.tex`
10. `chapters/06_conclusion.tex`
11. `Appendix/appendixA.tex`
12. `Appendix/appendixB.tex`
13. `Appendix/appendixCoverage.tex`
14. `Appendix/appendixE.tex`

Năm `\input` lồng đang hoạt động:

- `figures/i3c_low_handoff_timing.tex`
- `figures/i3c_read_takeover_timing.tex`
- `figures/csr_queue_handshake.tex`
- `figures/i3c_primary_controller_fsm.tex`
- `figures/entdaa_fsm.tex`

Graphic active gồm `i3c_controller_top_architecture.pdf`,
`uvm_i3c_verification_architecture_uvm.pdf` và 10 PNG waveform:
`i3c_write`, `i3c_read`, `i3c_imm`, `enec_bcast`, `enec_direct`, `daa1_png`,
`daa5_png`, `daa4_png`, `i2c_write`, `i2c_read`.

`Appendix/appendixC.tex`, `scl_generator_fsm.pdf`, `entdaa_controller_fsm.pdf`
và `entdaa_fsm.pdf` vẫn tồn tại/tracked nhưng không thuộc include graph hiện hành.

## Citation/bibliography baseline

- Nguồn BibTeX duy nhất: `References/references.bib`.
- 13 lệnh citation, 17 lượt key, 7 key duy nhất.
- 14 entry BibTeX; không có citation key thiếu entry.
- 7 key active: `cadence_xcelium`, `chipsalliance_i3c`, `ieee1800`,
  `mipi_i3c_basic`, `mipi_i3c_tcri`, `nxp_i2c`, `uvm12_ug`.
- Không dùng `.aux`, `.bbl`, `.blg`, `.run.xml`, `report-blx.bib` hay artifact
  sinh tự động làm nguồn chỉnh sửa.

## Cơ chế rollback của đợt sửa

Mỗi batch lưu/đánh giá theo forward diff của chính batch. Rollback hợp lệ là
`git apply --check -R <forward.patch>` rồi `git apply -R <forward.patch>` trên đúng
postimage; không dùng `git checkout`, `git restore` hoặc inverse patch bị đảo hai lần.

