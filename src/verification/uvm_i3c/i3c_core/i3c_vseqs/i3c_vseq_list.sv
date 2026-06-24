`include "i3c_vseqs/i3c_base_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_base_vseq.sv"

// 4.1 CSR, DAT, and Register Bus
`include "i3c_vseqs/csr_vseqs/csr_reset_defaults_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_enable_disable_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_broadcast_header_control_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_timing_rw_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_dat_rw_all_entries_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_dat_hw_read_selection_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_cmd_queue_2dw_staging_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_cmd_partial_then_other_write_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_sw_reset_flush_queues_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_sw_reset_clears_cmd_staging_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_queue_status_flags_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_rx_resp_read_pop_vseq.sv"
`include "i3c_vseqs/csr_vseqs/csr_unmapped_addr_no_side_effect_vseq.sv"

// 4.2 FIFO and Queue Behavior
`include "i3c_vseqs/fifo_vseqs/fifo_base_vseq.sv"
`include "i3c_vseqs/fifo_vseqs/fifo_basic_push_pop_order_vseq.sv"
`include "i3c_vseqs/fifo_vseqs/fifo_full_empty_boundaries_vseq.sv"
`include "i3c_vseqs/fifo_vseqs/fifo_simultaneous_read_write_vseq.sv"
`include "i3c_vseqs/fifo_vseqs/fifo_flush_during_activity_vseq.sv"

// 4.3 PHY, Bus Conditions, and Timing
`include "i3c_vseqs/bus_vseqs/bus_base_vseq.sv"
`include "i3c_vseqs/bus_vseqs/bus_phy_reset_and_sync_vseq.sv"
`include "i3c_vseqs/bus_vseqs/bus_start_stop_detect_vseq.sv"
`include "i3c_vseqs/bus_vseqs/bus_repeated_start_detect_vseq.sv"
`include "i3c_vseqs/bus_vseqs/bus_scl_start_stop_timing_vseq.sv"
`include "i3c_vseqs/bus_vseqs/bus_scl_clock_low_high_timing_vseq.sv"
`include "i3c_vseqs/bus_vseqs/bus_scl_waitcmd_stall_resume_vseq.sv"
`include "i3c_vseqs/bus_vseqs/bus_scl_repeated_start_from_waitcmd_vseq.sv"
`include "i3c_vseqs/bus_vseqs/bus_tx_byte_and_bit_order_vseq.sv"
`include "i3c_vseqs/bus_vseqs/bus_rx_byte_and_bit_order_vseq.sv"
`include "i3c_vseqs/bus_vseqs/bus_od_pp_phase_switch_vseq.sv"
`include "i3c_vseqs/bus_vseqs/bus_tb_pad_model_odpp_wiring_vseq.sv"

// 4.4 I3C SDR Private Write
`include "i3c_vseqs/sdr_write_vseqs/i3c_write_vseq.sv"
`include "i3c_vseqs/sdr_write_vseqs/i3c_write_len_sweep_vseq.sv"
`include "i3c_vseqs/sdr_write_vseqs/i3c_write_data_patterns_vseq.sv"
`include "i3c_vseqs/sdr_write_vseqs/i3c_write_toc_zero_vseq.sv"
`include "i3c_vseqs/sdr_write_vseqs/i3c_write_back_to_back_vseq.sv"
`include "i3c_vseqs/sdr_write_vseqs/i3c_write_multi_dat_idx_vseq.sv"

// 4.5 I3C SDR Private Read
`include "i3c_vseqs/sdr_read_vseqs/i3c_read_vseq.sv"
`include "i3c_vseqs/sdr_read_vseqs/i3c_read_len_sweep_vseq.sv"
`include "i3c_vseqs/sdr_read_vseqs/i3c_read_target_more_than_requested_vseq.sv"
`include "i3c_vseqs/sdr_read_vseqs/i3c_read_data_patterns_vseq.sv"
`include "i3c_vseqs/sdr_read_vseqs/i3c_read_toc_zero_vseq.sv"
`include "i3c_vseqs/sdr_read_vseqs/i3c_read_back_to_back_vseq.sv"
`include "i3c_vseqs/sdr_read_vseqs/i3c_read_multi_dat_idx_vseq.sv"

// Shared ENTDAA stimulus helper used by both DAA and error vseqs
`include "i3c_vseqs/daa_vseqs/i3c_daa_stimulus.sv"

// 4.10 Error Handling, Status, and Recovery
`include "i3c_vseqs/resp_vseqs/i3c_private_addr_nack_resp_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i3c_broadcast_header_nack_resp_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i3c_read_tbit_no_parity_resp_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i3c_read_short_target_end_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i3c_ovl_resp_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i3c_write_tx_fifo_underflow_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i3c_read_rx_fifo_full_overflow_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i3c_write_abort_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i3c_read_abort_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i3c_imm_data_nack_i2c_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i3c_imm_abort_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i2c_data_nack_write_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i2c_regular_abort_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i3c_entdaa_rx_fifo_partial_overflow_vseq.sv"
`include "i3c_vseqs/resp_vseqs/i3c_daa_hc_abort_vseq.sv"

// 4.6 Immediate Data Transfer
`include "i3c_vseqs/imm_vseqs/i3c_imm_vseq.sv"
`include "i3c_vseqs/imm_vseqs/i3c_imm_dtt_sweep_vseq.sv"
`include "i3c_vseqs/imm_vseqs/i3c_imm_toc_vseq.sv"
`include "i3c_vseqs/imm_vseqs/i3c_imm_i2c_write_vseq.sv"

// 4.7 Common Command Codes
`include "i3c_vseqs/ccc_vseqs/i3c_ccc_entdaa_opening_frame_vseq.sv"
`include "i3c_vseqs/ccc_vseqs/i3c_ccc_broadcast_enec_vseq.sv"
`include "i3c_vseqs/ccc_vseqs/i3c_ccc_broadcast_disec_vseq.sv"
`include "i3c_vseqs/ccc_vseqs/i3c_ccc_direct_enec_vseq.sv"
`include "i3c_vseqs/ccc_vseqs/i3c_ccc_direct_disec_vseq.sv"

// 4.8 Dynamic Address Assignment / ENTDAA
`include "i3c_vseqs/daa_vseqs/i3c_daa_single_device_success_vseq.sv"
`include "i3c_vseqs/daa_vseqs/i3c_daa_no_device_vseq.sv"
`include "i3c_vseqs/daa_vseqs/i3c_daa_fewer_devices_than_count_vseq.sv"
`include "i3c_vseqs/daa_vseqs/i3c_daa_multi_device_dat_loop_vseq.sv"
`include "i3c_vseqs/daa_vseqs/i3c_daa_address_rejected_vseq.sv"
`include "i3c_vseqs/daa_vseqs/i3c_daa_dat_boundary_vseq.sv"

// 4.9 I2C Legacy Compatibility
`include "i3c_vseqs/i2c_vseqs/i2c_regular_write_basic_vseq.sv"
`include "i3c_vseqs/i2c_vseqs/i2c_regular_read_basic_vseq.sv"
`include "i3c_vseqs/i2c_vseqs/i2c_broadcast_addr_enable_ignored_vseq.sv"
`include "i3c_vseqs/i2c_vseqs/i2c_len_sweep_partial_rx_vseq.sv"
