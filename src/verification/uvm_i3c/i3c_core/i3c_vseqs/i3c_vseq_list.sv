`include "i3c_vseqs/i3c_base_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_base_vseq.sv"

// 4.1 CSR, DAT, and Register Bus
`include "i3c_vseqs/csr_vseqs/csr_reset_defaults_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_enable_disable_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_timing_rw_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_dat_rw_all_entries_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_cmd_queue_2dw_staging_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_cmd_partial_then_other_write_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_sw_reset_flush_queues_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_sw_reset_clears_cmd_staging_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_queue_status_flags_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_rx_resp_read_pop_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_unmapped_addr_no_side_effect_vseq.sv"

// 4.4 I3C SDR Private Write
`include "i3c_vseqs/sdr_write_vseqs/i3c_write_vseq.sv"
`include "i3c_vseqs/sdr_write_vseqs/i3c_write_toc_zero_vseq.sv"

// 4.5 I3C SDR Private Read
`include "i3c_vseqs/sdr_read_vseqs/i3c_read_vseq.sv"
`include "i3c_vseqs/sdr_read_vseqs/i3c_read_toc_zero_vseq.sv"

// 4.6 Immediate Data Transfer
`include "i3c_vseqs/imm_vseqs/i3c_smoke_vseq.sv"

// 4.7 Common Command Codes
`include "i3c_vseqs/ccc_vseqs/i3c_ccc_broadcast_enec_vseq.sv"
