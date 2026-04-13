// HCI (Host Controller Interface) queue wrapper.
// Instantiates 4 synchronous FIFOs:
//   CMD  64-bit  SW→HW  (software enqueues command descriptors)
//   TX   32-bit  SW→HW  (software provides write data)
//   RX   32-bit  HW→SW  (hardware delivers read data)
//   RESP 32-bit  HW→SW  (hardware delivers response descriptors)
// All FIFOs share a single sw_reset_i for software-initiated flush.
// Spec: docs/module_specs/06_hci_queues_spec.md

module hci_queues #(
  parameter int unsigned CmdFifoDepth  = 64,
  parameter int unsigned TxFifoDepth   = 64,
  parameter int unsigned RxFifoDepth   = 64,
  parameter int unsigned RespFifoDepth = 64,
  parameter int unsigned CmdDataWidth  = 64, // CMD entries are 64-bit (2 DWORDs)
  parameter int unsigned TxDataWidth   = 32,
  parameter int unsigned RxDataWidth   = 32,
  parameter int unsigned RespDataWidth = 32,
  // Depth counter widths: $clog2(Depth + 1) to represent 0..Depth
  localparam int unsigned CmdDepthW    = $clog2(CmdFifoDepth  + 1),
  localparam int unsigned TxDepthW     = $clog2(TxFifoDepth   + 1),
  localparam int unsigned RxDepthW     = $clog2(RxFifoDepth   + 1),
  localparam int unsigned RespDepthW   = $clog2(RespFifoDepth + 1)
) (
  input  logic clk_i,
  input  logic rst_ni,

  // Software-initiated FIFO flush (from HC_CONTROL SW_RESET bit)
  input  logic sw_reset_i,

  // CMD FIFO — Software write / Hardware read
  input  logic                    cmd_wvalid_i,
  output logic                    cmd_wready_o,
  input  logic [CmdDataWidth-1:0] cmd_wdata_i,
  output logic                    cmd_rvalid_o,
  input  logic                    cmd_rready_i,
  output logic [CmdDataWidth-1:0] cmd_rdata_o,
  output logic                    cmd_full_o,
  output logic                    cmd_empty_o,
  output logic [CmdDepthW-1:0]    cmd_depth_o,

  // TX FIFO — Software write / Hardware read
  input  logic                   tx_wvalid_i,
  output logic                   tx_wready_o,
  input  logic [TxDataWidth-1:0] tx_wdata_i,
  output logic                   tx_rvalid_o,
  input  logic                   tx_rready_i,
  output logic [TxDataWidth-1:0] tx_rdata_o,
  output logic                   tx_full_o,
  output logic                   tx_empty_o,
  output logic [TxDepthW-1:0]    tx_depth_o,

  // RX FIFO — Hardware write / Software read
  input  logic                   rx_wvalid_i,
  output logic                   rx_wready_o,
  input  logic [RxDataWidth-1:0] rx_wdata_i,
  output logic                   rx_rvalid_o,
  input  logic                   rx_rready_i,
  output logic [RxDataWidth-1:0] rx_rdata_o,
  output logic                   rx_full_o,
  output logic                   rx_empty_o,
  output logic [RxDepthW-1:0]    rx_depth_o,

  // RESP FIFO — Hardware write / Software read
  input  logic                     resp_wvalid_i,
  output logic                     resp_wready_o,
  input  logic [RespDataWidth-1:0] resp_wdata_i,
  output logic                     resp_rvalid_o,
  input  logic                     resp_rready_i,
  output logic [RespDataWidth-1:0] resp_rdata_o,
  output logic                     resp_full_o,
  output logic                     resp_empty_o,
  output logic [RespDepthW-1:0]    resp_depth_o
);
  // CMD FIFO instance
  // 64-bit wide; sw writes 2x32 (assembled by csr_registers), hw reads 64-bit
  sync_fifo #(
    .Width (CmdDataWidth),
    .Depth (CmdFifoDepth)
  ) cmd_fifo (
    .clk_i,
    .rst_ni,
    .flush_i  (sw_reset_i),
    .wvalid_i (cmd_wvalid_i),
    .wready_o (cmd_wready_o),
    .wdata_i  (cmd_wdata_i),
    .rvalid_o (cmd_rvalid_o),
    .rready_i (cmd_rready_i),
    .rdata_o  (cmd_rdata_o),
    .full_o   (cmd_full_o),
    .empty_o  (cmd_empty_o),
    .depth_o  (cmd_depth_o)
  );

  // TX FIFO instance
  sync_fifo #(
    .Width (TxDataWidth),
    .Depth (TxFifoDepth)
  ) tx_fifo (
    .clk_i,
    .rst_ni,
    .flush_i  (sw_reset_i),
    .wvalid_i (tx_wvalid_i),
    .wready_o (tx_wready_o),
    .wdata_i  (tx_wdata_i),
    .rvalid_o (tx_rvalid_o),
    .rready_i (tx_rready_i),
    .rdata_o  (tx_rdata_o),
    .full_o   (tx_full_o),
    .empty_o  (tx_empty_o),
    .depth_o  (tx_depth_o)
  );

  // RX FIFO instance
  sync_fifo #(
    .Width (RxDataWidth),
    .Depth (RxFifoDepth)
  ) rx_fifo (
    .clk_i,
    .rst_ni,
    .flush_i  (sw_reset_i),
    .wvalid_i (rx_wvalid_i),
    .wready_o (rx_wready_o),
    .wdata_i  (rx_wdata_i),
    .rvalid_o (rx_rvalid_o),
    .rready_i (rx_rready_i),
    .rdata_o  (rx_rdata_o),
    .full_o   (rx_full_o),
    .empty_o  (rx_empty_o),
    .depth_o  (rx_depth_o)
  );

  // RESP FIFO instance
  sync_fifo #(
    .Width (RespDataWidth),
    .Depth (RespFifoDepth)
  ) resp_fifo (
    .clk_i,
    .rst_ni,
    .flush_i  (sw_reset_i),
    .wvalid_i (resp_wvalid_i),
    .wready_o (resp_wready_o),
    .wdata_i  (resp_wdata_i),
    .rvalid_o (resp_rvalid_o),
    .rready_i (resp_rready_i),
    .rdata_o  (resp_rdata_o),
    .full_o   (resp_full_o),
    .empty_o  (resp_empty_o),
    .depth_o  (resp_depth_o)
  );
endmodule