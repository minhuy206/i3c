module controller_active
  import i3c_pkg::*;
  import controller_pkg::*;
#(
  parameter int DatDepth = 16
) (
  input  logic clk_i,
  input  logic rst_ni,

  input  logic ctrl_scl_i,
  input  logic ctrl_sda_i,
  output logic ctrl_scl_o,
  output logic ctrl_sda_o,
  output logic sel_od_pp_o,

  input  logic        cmd_queue_empty_i,
  input  logic        cmd_queue_rvalid_i,
  output logic        cmd_queue_rready_o,
  input  logic [63:0] cmd_queue_rdata_i,

  input  logic        tx_queue_empty_i,
  input  logic        tx_queue_rvalid_i,
  output logic        tx_queue_rready_o,
  input  logic [31:0] tx_queue_rdata_i,

  input  logic        rx_queue_full_i,
  output logic        rx_queue_wvalid_o,
  input  logic        rx_queue_wready_i,
  output logic [31:0] rx_queue_wdata_o,

  input  logic        resp_queue_full_i,
  output logic        resp_queue_wvalid_o,
  input  logic        resp_queue_wready_i,
  output logic [31:0] resp_queue_wdata_o,

  output logic             dat_read_valid_hw_o,
  output logic [DatAw-1:0] dat_index_hw_o,
  input  logic [31:0]      dat_rdata_hw_i,

  input logic [19:0] t_r_i,
  input logic [19:0] t_f_i,
  input logic [19:0] t_low_i,
  input logic [19:0] t_high_i,
  input logic [19:0] t_su_sta_i,
  input logic [19:0] t_hd_sta_i,
  input logic [19:0] t_su_sto_i,
  input logic [19:0] t_su_dat_i,
  input logic [19:0] t_hd_dat_i,

  input  logic ctrl_enable_i,
  input  logic i3c_fsm_en_i,
  output logic i3c_fsm_idle_o
);

  // Internal signals
  bus_state_t bus_state;

  logic scl_gen_scl, scl_gen_sda;
  logic scl_gen_done, scl_gen_busy;

  logic flow_gen_start, flow_gen_rstart, flow_gen_stop;
  logic flow_gen_clock, flow_gen_idle;
  logic flow_sel_i3c_i2c;
  logic flow_sel_od_pp;
  logic flow_tx_req_byte, flow_tx_req_bit;
  logic [7:0] flow_tx_req_value;
  logic flow_rx_req_byte, flow_rx_req_bit;
  logic flow_ccc_valid;
  logic [6:0] flow_ccc_dev_addr;
  logic [3:0] flow_ccc_dev_count;
  logic flow_dat_read_valid;
  logic [DatAw-1:0] flow_dat_index;

  logic daa_done;
  logic daa_req_restart;
  logic daa_tx_req_byte, daa_tx_req_bit;
  logic [7:0] daa_tx_req_value;
  logic daa_tx_sel_od_pp;
  logic daa_rx_req_bit, daa_rx_req_byte;
  logic daa_dat_read_valid;
  logic [DatAw-1:0] daa_dat_index;
  logic [6:0] daa_address;
  logic daa_address_valid;
  logic [47:0] daa_pid;
  logic [7:0] daa_bcr, daa_dcr;

  logic tx_flow_done, tx_flow_idle;
  logic tx_flow_sda, tx_flow_sel_od_pp;

  logic [7:0] rx_flow_data;
  logic rx_flow_done, rx_flow_idle;

  logic mux_tx_req_byte, mux_tx_req_bit;
  logic [7:0] mux_tx_req_value;
  logic mux_tx_sel_od_pp;
  logic mux_rx_req_byte, mux_rx_req_bit;

  wire daa_active = flow_ccc_valid;

  // ---------------------------------------------------------------------------
  // Restart latch: entdaa_controller pulses req_restart for 1 cycle, but
  // scl_generator needs gen_rstart held high until it completes the Sr.
  // ---------------------------------------------------------------------------

  logic daa_restart_pending_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_daa_restart_pending
    if (!rst_ni)
      daa_restart_pending_q <= 1'b0;
    else if (daa_req_restart)
      daa_restart_pending_q <= 1'b1;
    else if (scl_gen_done || !daa_active)
      daa_restart_pending_q <= 1'b0;
  end

  wire gen_rstart_combined = flow_gen_rstart | daa_req_restart | daa_restart_pending_q;

  // ---------------------------------------------------------------------------
  // Bus TX/RX MUX: ENTDAA controller vs flow_active
  // ---------------------------------------------------------------------------

  always_comb begin : mux_bus_tx_rx
    if (daa_active) begin
      mux_tx_req_byte  = daa_tx_req_byte;
      mux_tx_req_bit   = daa_tx_req_bit;
      mux_tx_req_value = daa_tx_req_value;
      mux_tx_sel_od_pp = daa_tx_sel_od_pp;
      mux_rx_req_byte  = daa_rx_req_byte;
      mux_rx_req_bit   = daa_rx_req_bit;
    end else begin
      mux_tx_req_byte  = flow_tx_req_byte;
      mux_tx_req_bit   = flow_tx_req_bit;
      mux_tx_req_value = flow_tx_req_value;
      mux_tx_sel_od_pp = flow_sel_od_pp;
      mux_rx_req_byte  = flow_rx_req_byte;
      mux_rx_req_bit   = flow_rx_req_bit;
    end
  end

  // ---------------------------------------------------------------------------
  // DAT read MUX: both ports are never active simultaneously
  // ---------------------------------------------------------------------------

  always_comb begin : mux_dat_read
    if (daa_active) begin
      dat_read_valid_hw_o = daa_dat_read_valid;
      dat_index_hw_o      = daa_dat_index;
    end else begin
      dat_read_valid_hw_o = flow_dat_read_valid;
      dat_index_hw_o      = flow_dat_index;
    end
  end

  // ---------------------------------------------------------------------------
  // Output assignments
  // ---------------------------------------------------------------------------

  assign ctrl_scl_o  = scl_gen_scl;
  assign ctrl_sda_o  = scl_gen_sda & tx_flow_sda;
  assign sel_od_pp_o = tx_flow_sel_od_pp;

  // ---------------------------------------------------------------------------
  // Sub-module instances
  // ---------------------------------------------------------------------------

  bus_monitor u_bus_mon (
    .clk_i,
    .rst_ni,
    .enable_i (ctrl_enable_i),
    .scl_i    (ctrl_scl_i),
    .sda_i    (ctrl_sda_i),
    .t_hd_dat_i,
    .t_r_i,
    .t_f_i,
    .state_o  (bus_state)
  );

  scl_generator u_scl_gen (
    .clk_i,
    .rst_ni,
    .gen_start_i   (flow_gen_start),
    .gen_rstart_i  (gen_rstart_combined),
    .gen_stop_i    (flow_gen_stop),
    .gen_clock_i   (flow_gen_clock),
    .gen_idle_i    (flow_gen_idle),
    .sel_i3c_i2c_i (flow_sel_i3c_i2c),
    .done_o        (scl_gen_done),
    .busy_o        (scl_gen_busy),
    .t_low_i,
    .t_high_i,
    .t_su_sta_i,
    .t_hd_sta_i,
    .t_su_sto_i,
    .t_r_i,
    .t_f_i,
    .scl_i         (bus_state.scl.value),
    .scl_o         (scl_gen_scl),
    .sda_o         (scl_gen_sda)
  );

  bus_tx_flow u_tx_flow (
    .clk_i,
    .rst_ni,
    .t_r_i,
    .t_su_dat_i,
    .t_hd_dat_i,
    .scl_negedge_i    (bus_state.scl.neg_edge),
    .scl_posedge_i    (bus_state.scl.pos_edge),
    .scl_stable_low_i (bus_state.scl.stable_low),
    .req_byte_i       (mux_tx_req_byte),
    .req_bit_i        (mux_tx_req_bit),
    .req_value_i      (mux_tx_req_value),
    .bus_tx_done_o    (tx_flow_done),
    .bus_tx_idle_o    (tx_flow_idle),
    .req_error_o      (),
    .bus_error_o      (),
    .sel_od_pp_i      (mux_tx_sel_od_pp),
    .sel_od_pp_o      (tx_flow_sel_od_pp),
    .sda_o            (tx_flow_sda)
  );

  bus_rx_flow u_rx_flow (
    .clk_i,
    .rst_ni,
    .scl_posedge_i    (bus_state.scl.pos_edge),
    .scl_stable_high_i(bus_state.scl.stable_high),
    .sda_i            (bus_state.sda.value),
    .rx_req_bit_i     (mux_rx_req_bit),
    .rx_req_byte_i    (mux_rx_req_byte),
    .rx_data_o        (rx_flow_data),
    .rx_done_o        (rx_flow_done),
    .rx_idle_o        (rx_flow_idle)
  );

  flow_active #(
    .DatDepth(DatDepth)
  ) u_flow_fsm (
    .clk_i,
    .rst_ni,
    .cmd_queue_empty_i,
    .cmd_queue_rvalid_i,
    .cmd_queue_rready_o,
    .cmd_queue_rdata_i,
    .tx_queue_empty_i,
    .tx_queue_rvalid_i,
    .tx_queue_rready_o,
    .tx_queue_rdata_i,
    .rx_queue_full_i,
    .rx_queue_wvalid_o,
    .rx_queue_wready_i,
    .rx_queue_wdata_o,
    .resp_queue_full_i,
    .resp_queue_wvalid_o,
    .resp_queue_wready_i,
    .resp_queue_wdata_o,
    .dat_read_valid_hw_o (flow_dat_read_valid),
    .dat_index_hw_o      (flow_dat_index),
    .dat_rdata_hw_i,
    .bus_tx_req_byte_o   (flow_tx_req_byte),
    .bus_tx_req_bit_o    (flow_tx_req_bit),
    .bus_tx_req_value_o  (flow_tx_req_value),
    .bus_tx_done_i       (tx_flow_done),
    .bus_tx_idle_i       (tx_flow_idle),
    .bus_rx_req_byte_o   (flow_rx_req_byte),
    .bus_rx_req_bit_o    (flow_rx_req_bit),
    .bus_rx_data_i       (rx_flow_data),
    .bus_rx_done_i       (rx_flow_done),
    .bus_rx_idle_i       (rx_flow_idle),
    .gen_start_o         (flow_gen_start),
    .gen_rstart_o        (flow_gen_rstart),
    .gen_stop_o          (flow_gen_stop),
    .gen_clock_o         (flow_gen_clock),
    .gen_idle_o          (flow_gen_idle),
    .sel_i3c_i2c_o       (flow_sel_i3c_i2c),
    .scl_gen_done_i      (scl_gen_done),
    .scl_gen_busy_i      (scl_gen_busy),
    .ccc_valid_o         (flow_ccc_valid),
    .ccc_code_o          (),
    .ccc_def_byte_o      (),
    .ccc_dev_addr_o      (flow_ccc_dev_addr),
    .ccc_dev_count_o     (flow_ccc_dev_count),
    .ccc_done_i          (daa_done),
    .ccc_invalid_i       (1'b0),
    .daa_address_i       (daa_address),
    .daa_address_valid_i (daa_address_valid),
    .daa_pid_i           (daa_pid),
    .daa_bcr_i           (daa_bcr),
    .daa_dcr_i           (daa_dcr),
    .sel_od_pp_o         (flow_sel_od_pp),
    .i3c_fsm_en_i,
    .i3c_fsm_idle_o
  );

  entdaa_controller #(
    .DatDepth(DatDepth)
  ) u_daa_ctrl (
    .clk_i,
    .rst_ni,
    .ccc_valid_i         (flow_ccc_valid),
    .dev_count_i         (flow_ccc_dev_count),
    .dev_idx_i           (flow_ccc_dev_addr[4:0]),
    .done_o              (daa_done),
    .req_restart_o       (daa_req_restart),
    .bus_tx_done_i       (tx_flow_done),
    .bus_tx_idle_i       (tx_flow_idle),
    .bus_tx_req_byte_o   (daa_tx_req_byte),
    .bus_tx_req_bit_o    (daa_tx_req_bit),
    .bus_tx_req_value_o  (daa_tx_req_value),
    .bus_tx_sel_od_pp_o  (daa_tx_sel_od_pp),
    .bus_rx_data_i       (rx_flow_data),
    .bus_rx_done_i       (rx_flow_done),
    .bus_rx_req_bit_o    (daa_rx_req_bit),
    .bus_rx_req_byte_o   (daa_rx_req_byte),
    .bus_start_det_i     (bus_state.start_det),
    .bus_rstart_det_i    (bus_state.rstart_det),
    .bus_stop_det_i      (bus_state.stop_det),
    .dat_read_valid_o    (daa_dat_read_valid),
    .dat_index_o         (daa_dat_index),
    .dat_rdata_i         (dat_rdata_hw_i),
    .daa_address_o       (daa_address),
    .daa_address_valid_o (daa_address_valid),
    .daa_pid_o           (daa_pid),
    .daa_bcr_o           (daa_bcr),
    .daa_dcr_o           (daa_dcr)
  );

endmodule
