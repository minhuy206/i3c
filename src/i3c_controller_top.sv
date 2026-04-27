module i3c_controller_top
  import i3c_pkg::*;
  import controller_pkg::*;
#(
  parameter int DatDepth      = 16,
  parameter int CmdFifoDepth  = 64,
  parameter int TxFifoDepth   = 64,
  parameter int RxFifoDepth   = 64,
  parameter int RespFifoDepth = 64,
  parameter int AddrWidth     = 12,
  parameter int DataWidth     = 32
) (
  input  logic clk_i,
  input  logic rst_ni,

  input  logic [AddrWidth-1:0] reg_addr_i,
  input  logic [DataWidth-1:0] reg_wdata_i,
  input  logic                 reg_wen_i,
  input  logic                 reg_ren_i,
  output logic [DataWidth-1:0] reg_rdata_o,
  output logic                 reg_ready_o,

  input  logic scl_i,
  output logic scl_o,
  input  logic sda_i,
  output logic sda_o,
  output logic sel_od_pp_o
);

  // ---------------------------------------------------------------------------
  // Internal signals
  // ---------------------------------------------------------------------------

  // CSR configuration outputs
  logic ctrl_enable, i3c_fsm_en, sw_reset;
  logic [19:0] t_r, t_f, t_low, t_high;
  logic [19:0] t_su_sta, t_hd_sta, t_su_sto, t_su_dat, t_hd_dat;

  // CSR ↔ HCI Queues: CMD (SW write → HW read)
  logic        cmd_csr_wvalid, cmd_csr_wready;
  logic [63:0] cmd_csr_wdata;

  // CSR ↔ HCI Queues: TX (SW write → HW read)
  logic        tx_csr_wvalid, tx_csr_wready;
  logic [31:0] tx_csr_wdata;

  // CSR ↔ HCI Queues: RX (HW write → SW read)
  logic        rx_csr_rvalid, rx_csr_rready;
  logic [31:0] rx_csr_rdata;

  // CSR ↔ HCI Queues: RESP (HW write → SW read)
  logic        resp_csr_rvalid, resp_csr_rready;
  logic [31:0] resp_csr_rdata;

  // Queue status (shared between CSR and controller)
  logic cmd_full, cmd_empty;
  logic tx_full, tx_empty;
  logic rx_full, rx_empty;
  logic resp_full, resp_empty;

  // HCI Queues ↔ Controller: CMD read side
  logic        cmd_hw_rvalid, cmd_hw_rready;
  logic [63:0] cmd_hw_rdata;

  // HCI Queues ↔ Controller: TX read side
  logic        tx_hw_rvalid, tx_hw_rready;
  logic [31:0] tx_hw_rdata;

  // HCI Queues ↔ Controller: RX write side
  logic        rx_hw_wvalid, rx_hw_wready;
  logic [31:0] rx_hw_wdata;

  // HCI Queues ↔ Controller: RESP write side
  logic        resp_hw_wvalid, resp_hw_wready;
  logic [31:0] resp_hw_wdata;

  // DAT hardware read port
  logic             dat_read_valid;
  logic [DatAw-1:0] dat_index;
  logic [31:0]      dat_rdata;

  // Controller ↔ PHY
  logic ctrl_scl_from_phy, ctrl_sda_from_phy;
  logic ctrl_scl_to_phy, ctrl_sda_to_phy;
  logic ctrl_sel_od_pp;

  // Status
  logic i3c_fsm_idle;

  // ---------------------------------------------------------------------------
  // CSR Registers
  // ---------------------------------------------------------------------------

  csr_registers #(
    .DatDepth  (DatDepth),
    .AddrWidth (AddrWidth),
    .DataWidth (DataWidth)
  ) u_csr (
    .clk_i,
    .rst_ni,
    .addr_i          (reg_addr_i),
    .wdata_i         (reg_wdata_i),
    .wen_i           (reg_wen_i),
    .ren_i           (reg_ren_i),
    .rdata_o         (reg_rdata_o),
    .ready_o         (reg_ready_o),
    .ctrl_enable_o   (ctrl_enable),
    .i3c_fsm_en_o    (i3c_fsm_en),
    .sw_reset_o      (sw_reset),
    .t_r_o           (t_r),
    .t_f_o           (t_f),
    .t_low_o         (t_low),
    .t_high_o        (t_high),
    .t_su_sta_o      (t_su_sta),
    .t_hd_sta_o      (t_hd_sta),
    .t_su_sto_o      (t_su_sto),
    .t_su_dat_o      (t_su_dat),
    .t_hd_dat_o      (t_hd_dat),
    .dat_read_valid_i(dat_read_valid),
    .dat_index_i     (dat_index),
    .dat_rdata_o     (dat_rdata),
    .cmd_wvalid_o    (cmd_csr_wvalid),
    .cmd_wdata_o     (cmd_csr_wdata),
    .cmd_wready_i    (cmd_csr_wready),
    .tx_wvalid_o     (tx_csr_wvalid),
    .tx_wdata_o      (tx_csr_wdata),
    .tx_wready_i     (tx_csr_wready),
    .rx_rvalid_i     (rx_csr_rvalid),
    .rx_rdata_i      (rx_csr_rdata),
    .rx_rready_o     (rx_csr_rready),
    .resp_rvalid_i   (resp_csr_rvalid),
    .resp_rdata_i    (resp_csr_rdata),
    .resp_rready_o   (resp_csr_rready),
    .cmd_full_i      (cmd_full),
    .cmd_empty_i     (cmd_empty),
    .tx_full_i       (tx_full),
    .tx_empty_i      (tx_empty),
    .rx_full_i       (rx_full),
    .rx_empty_i      (rx_empty),
    .resp_full_i     (resp_full),
    .resp_empty_i    (resp_empty),
    .i3c_fsm_idle_i  (i3c_fsm_idle)
  );

  // ---------------------------------------------------------------------------
  // HCI Queues
  // ---------------------------------------------------------------------------

  hci_queues #(
    .CmdFifoDepth (CmdFifoDepth),
    .TxFifoDepth  (TxFifoDepth),
    .RxFifoDepth  (RxFifoDepth),
    .RespFifoDepth(RespFifoDepth)
  ) u_queues (
    .clk_i,
    .rst_ni,
    .sw_reset_i     (sw_reset),
    .cmd_wvalid_i   (cmd_csr_wvalid),
    .cmd_wready_o   (cmd_csr_wready),
    .cmd_wdata_i    (cmd_csr_wdata),
    .cmd_rvalid_o   (cmd_hw_rvalid),
    .cmd_rready_i   (cmd_hw_rready),
    .cmd_rdata_o    (cmd_hw_rdata),
    .cmd_full_o     (cmd_full),
    .cmd_empty_o    (cmd_empty),
    .cmd_depth_o    (),
    .tx_wvalid_i    (tx_csr_wvalid),
    .tx_wready_o    (tx_csr_wready),
    .tx_wdata_i     (tx_csr_wdata),
    .tx_rvalid_o    (tx_hw_rvalid),
    .tx_rready_i    (tx_hw_rready),
    .tx_rdata_o     (tx_hw_rdata),
    .tx_full_o      (tx_full),
    .tx_empty_o     (tx_empty),
    .tx_depth_o     (),
    .rx_wvalid_i    (rx_hw_wvalid),
    .rx_wready_o    (rx_hw_wready),
    .rx_wdata_i     (rx_hw_wdata),
    .rx_rvalid_o    (rx_csr_rvalid),
    .rx_rready_i    (rx_csr_rready),
    .rx_rdata_o     (rx_csr_rdata),
    .rx_full_o      (rx_full),
    .rx_empty_o     (rx_empty),
    .rx_depth_o     (),
    .resp_wvalid_i  (resp_hw_wvalid),
    .resp_wready_o  (resp_hw_wready),
    .resp_wdata_i   (resp_hw_wdata),
    .resp_rvalid_o  (resp_csr_rvalid),
    .resp_rready_i  (resp_csr_rready),
    .resp_rdata_o   (resp_csr_rdata),
    .resp_full_o    (resp_full),
    .resp_empty_o   (resp_empty),
    .resp_depth_o   ()
  );

  // ---------------------------------------------------------------------------
  // Controller Active (protocol engine)
  // ---------------------------------------------------------------------------

  controller_active #(
    .DatDepth(DatDepth)
  ) u_ctrl (
    .clk_i,
    .rst_ni,
    .ctrl_scl_i        (ctrl_scl_from_phy),
    .ctrl_sda_i        (ctrl_sda_from_phy),
    .ctrl_scl_o        (ctrl_scl_to_phy),
    .ctrl_sda_o        (ctrl_sda_to_phy),
    .sel_od_pp_o       (ctrl_sel_od_pp),
    .cmd_queue_empty_i (cmd_empty),
    .cmd_queue_rvalid_i(cmd_hw_rvalid),
    .cmd_queue_rready_o(cmd_hw_rready),
    .cmd_queue_rdata_i (cmd_hw_rdata),
    .tx_queue_empty_i  (tx_empty),
    .tx_queue_rvalid_i (tx_hw_rvalid),
    .tx_queue_rready_o (tx_hw_rready),
    .tx_queue_rdata_i  (tx_hw_rdata),
    .rx_queue_full_i   (rx_full),
    .rx_queue_wvalid_o (rx_hw_wvalid),
    .rx_queue_wready_i (rx_hw_wready),
    .rx_queue_wdata_o  (rx_hw_wdata),
    .resp_queue_full_i (resp_full),
    .resp_queue_wvalid_o(resp_hw_wvalid),
    .resp_queue_wready_i(resp_hw_wready),
    .resp_queue_wdata_o(resp_hw_wdata),
    .dat_read_valid_hw_o(dat_read_valid),
    .dat_index_hw_o    (dat_index),
    .dat_rdata_hw_i    (dat_rdata),
    .t_r_i             (t_r),
    .t_f_i             (t_f),
    .t_low_i           (t_low),
    .t_high_i          (t_high),
    .t_su_sta_i        (t_su_sta),
    .t_hd_sta_i        (t_hd_sta),
    .t_su_sto_i        (t_su_sto),
    .t_su_dat_i        (t_su_dat),
    .t_hd_dat_i        (t_hd_dat),
    .ctrl_enable_i     (ctrl_enable),
    .i3c_fsm_en_i      (i3c_fsm_en),
    .i3c_fsm_idle_o    (i3c_fsm_idle)
  );

  // ---------------------------------------------------------------------------
  // PHY (2FF synchronizer + output drivers)
  // ---------------------------------------------------------------------------

  i3c_phy u_phy (
    .clk_i,
    .rst_ni,
    .scl_i,
    .scl_o,
    .sda_i,
    .sda_o,
    .ctrl_scl_i  (ctrl_scl_to_phy),
    .ctrl_scl_o  (ctrl_scl_from_phy),
    .ctrl_sda_i  (ctrl_sda_to_phy),
    .ctrl_sda_o  (ctrl_sda_from_phy),
    .sel_od_pp_i (ctrl_sel_od_pp),
    .sel_od_pp_o
  );

endmodule
