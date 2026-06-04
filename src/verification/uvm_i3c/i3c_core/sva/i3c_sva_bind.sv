bind i3c_phy i3c_phy_sva #(
    .ResetValue(ResetValue)
) u_i3c_phy_sva (
    .clk_i,
    .rst_ni,
    .scl_i,
    .scl_o,
    .sda_i,
    .sda_o,
    .ctrl_scl_i,
    .ctrl_scl_o,
    .ctrl_sda_i,
    .ctrl_sda_oe_i,
    .ctrl_sda_o,
    .sel_od_pp_i,
    .sda_oe_o,
    .sel_od_pp_o
);

bind scl_generator scl_generator_timing_sva #(
    .CounterWidth(CounterWidth)
) u_scl_generator_timing_sva (
    .clk_i,
    .rst_ni,
    .gen_start_i,
    .gen_rstart_i,
    .gen_stop_i,
    .gen_clock_i,
    .gen_idle_i,
    .done_o,
    .busy_o,
    .sda_ctrl_active_o,
    .t_low_i,
    .t_high_i,
    .t_su_sta_i,
    .t_hd_sta_i,
    .t_su_sto_i,
    .t_r_i,
    .t_f_i,
    .scl_i,
    .scl_o,
    .sda_o,
    .state_q,
    .state_d,
    .tcount,
    .load_tcount,
    .tcount_load_val
);

bind bus_tx_flow bus_tx_flow_msb_sva u_bus_tx_flow_msb_sva (
    .clk_i,
    .rst_ni,
    .scl_posedge_i,
    .req_byte_i,
    .req_bit_i,
    .req_value_i,
    .req_error_o,
    .drive_bit_en,
    .sda_o
);

bind bus_rx_flow bus_rx_flow_msb_sva u_bus_rx_flow_msb_sva (
    .clk_i,
    .rst_ni,
    .scl_posedge_i,
    .sda_i,
    .rx_req_bit_i,
    .rx_req_byte_i,
    .rx_data_o,
    .rx_done_o,
    .rx_bit_en
);

bind flow_active flow_active_sva #(
    .HciCmdDataWidth(HciCmdDataWidth),
    .HciTxDataWidth(HciTxDataWidth),
    .HciRxDataWidth(HciRxDataWidth),
    .HciRespDataWidth(HciRespDataWidth),
    .DatDepth(DatDepth)
) u_flow_active_sva (
    .clk_i,
    .rst_ni,
    .state_q,
    .sel_od_pp_o,
    .issue_phase_q,
    .cmd_attr,
    .cmd_dir,
    .imm_desc,
    .dat_entry,
    .remaining_len_q,
    .short_read_q,
    .addr_after_rstart_q,
    .gen_start_o,
    .gen_rstart_o,
    .gen_stop_o
);

bind controller_active controller_active_mux_sva u_controller_active_mux_sva (
    .clk_i,
    .rst_ni,
    .ctrl_scl_o,
    .ctrl_sda_o,
    .ctrl_sda_oe_o,
    .sel_od_pp_o,
    .scl_gen_scl,
    .scl_gen_sda,
    .scl_gen_driving_sda,
    .tx_flow_sda_drive,
    .tx_flow_sda,
    .tx_flow_sel_od_pp
);

bind bus_monitor bus_monitor_event_sva #(
    .CounterWidth(CounterWidth)
) u_bus_monitor_event_sva (
    .clk_i,
    .rst_ni,
    .enable_i,
    .scl_i,
    .sda_i,
    .t_r_i,
    .t_f_i,
    .scl_negedge,
    .sda_negedge,
    .sda_posedge,
    .scl_stable_high,
    .simultaneous_posedge,
    .simultaneous_negedge,
    .start_det_trigger,
    .stop_det_trigger,
    .rstart_detection_en,
    .start_det_o  (state_o.start_det),
    .rstart_det_o (state_o.rstart_det),
    .stop_det_o   (state_o.stop_det)
);

bind sync_fifo sync_fifo_model_sva #(
    .Width(Width),
    .Depth(Depth)
) u_sync_fifo_model_sva (
    .clk_i,
    .rst_ni,
    .flush_i,
    .wvalid_i,
    .wready_o,
    .wdata_i,
    .rvalid_o,
    .rready_i,
    .rdata_o,
    .empty_o,
    .depth_o
);

bind csr_registers csr_registers_sva u_csr_registers_sva (
    .clk_i               (clk_i),
    .rst_ni              (rst_ni),
    .addr_i              (addr_i),
    .wdata_i             (wdata_i),
    .wen_i               (wen_i),
    .ren_i               (ren_i),
    .rdata_o             (rdata_o),
    .ready_o             (ready_o),
    .sw_reset_o          (sw_reset_o),
    .cmd_wvalid_o        (cmd_wvalid_o),
    .cmd_wdata_o         (cmd_wdata_o),
    .cmd_wready_i        (cmd_wready_i),
    .tx_wvalid_o         (tx_wvalid_o),
    .tx_wdata_o          (tx_wdata_o),
    .tx_wready_i         (tx_wready_i),
    .rx_rvalid_i         (rx_rvalid_i),
    .rx_rdata_i          (rx_rdata_i),
    .rx_rready_o         (rx_rready_o),
    .resp_rvalid_i       (resp_rvalid_i),
    .resp_rdata_i        (resp_rdata_i),
    .resp_rready_o       (resp_rready_o),
    .cmd_full_i          (cmd_full_i),
    .cmd_empty_i         (cmd_empty_i),
    .tx_full_i           (tx_full_i),
    .tx_empty_i          (tx_empty_i),
    .rx_full_i           (rx_full_i),
    .rx_empty_i          (rx_empty_i),
    .resp_full_i         (resp_full_i),
    .resp_empty_i        (resp_empty_i),
    .i3c_fsm_idle_i      (i3c_fsm_idle_i),
    .cmd_staging_valid_i (cmd_staging_valid),
    .cmd_dword0_i        (cmd_dword0),
    .cmd_wvalid_int_i    (cmd_wvalid),
    .cmd_wdata_int_i     (cmd_wdata),
    .tx_wvalid_int_i     (tx_wvalid),
    .tx_wdata_int_i      (tx_wdata),
    .hc_status_i         (hc_status),
    .queue_status_i      (queue_status)
);

bind i3c_controller_top i3c_controller_top_sva u_i3c_controller_top_sva (
    .clk_i               (clk_i),
    .rst_ni              (rst_ni),
    .sw_reset_i          (sw_reset),
    .cmd_csr_wvalid_i    (cmd_csr_wvalid),
    .cmd_csr_wready_i    (cmd_csr_wready),
    .cmd_csr_wdata_i     (cmd_csr_wdata),
    .cmd_hw_rvalid_i     (cmd_hw_rvalid),
    .cmd_hw_rready_i     (cmd_hw_rready),
    .cmd_hw_rdata_i      (cmd_hw_rdata),
    .tx_csr_wvalid_i     (tx_csr_wvalid),
    .tx_csr_wready_i     (tx_csr_wready),
    .tx_csr_wdata_i      (tx_csr_wdata),
    .tx_hw_rvalid_i      (tx_hw_rvalid),
    .tx_hw_rready_i      (tx_hw_rready),
    .tx_hw_rdata_i       (tx_hw_rdata),
    .rx_hw_wvalid_i      (rx_hw_wvalid),
    .rx_hw_wready_i      (rx_hw_wready),
    .rx_hw_wdata_i       (rx_hw_wdata),
    .rx_csr_rvalid_i     (rx_csr_rvalid),
    .rx_csr_rready_i     (rx_csr_rready),
    .rx_csr_rdata_i      (rx_csr_rdata),
    .resp_hw_wvalid_i    (resp_hw_wvalid),
    .resp_hw_wready_i    (resp_hw_wready),
    .resp_hw_wdata_i     (resp_hw_wdata),
    .resp_csr_rvalid_i   (resp_csr_rvalid),
    .resp_csr_rready_i   (resp_csr_rready),
    .resp_csr_rdata_i    (resp_csr_rdata)
);
