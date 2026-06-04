module csr_registers_sva #(
    parameter int unsigned AddrWidth    = 12,
    parameter int unsigned DataWidth    = 32,
    parameter int unsigned CmdDataWidth = 64
) (
    input logic clk_i,
    input logic rst_ni,

    input logic [AddrWidth-1:0] addr_i,
    input logic [DataWidth-1:0] wdata_i,
    input logic                 wen_i,
    input logic                 ren_i,
    input logic [DataWidth-1:0] rdata_o,
    input logic                 ready_o,

    input logic sw_reset_o,

    input logic                    cmd_wvalid_o,
    input logic [CmdDataWidth-1:0] cmd_wdata_o,
    input logic                    cmd_wready_i,
    input logic                    tx_wvalid_o,
    input logic [DataWidth-1:0]    tx_wdata_o,
    input logic                    tx_wready_i,

    input logic                 rx_rvalid_i,
    input logic [DataWidth-1:0] rx_rdata_i,
    input logic                 rx_rready_o,
    input logic                 resp_rvalid_i,
    input logic [DataWidth-1:0] resp_rdata_i,
    input logic                 resp_rready_o,

    input logic cmd_full_i,
    input logic cmd_empty_i,
    input logic tx_full_i,
    input logic tx_empty_i,
    input logic rx_full_i,
    input logic rx_empty_i,
    input logic resp_full_i,
    input logic resp_empty_i,
    input logic i3c_fsm_idle_i,

    input logic                         cmd_staging_valid_i,
    input logic [DataWidth-1:0]         cmd_dword0_i,
    input logic                         cmd_wvalid_int_i,
    input logic [CmdDataWidth-1:0]      cmd_wdata_int_i,
    input logic                         tx_wvalid_int_i,
    input logic [DataWidth-1:0]         tx_wdata_int_i,
    input logic [DataWidth-1:0]         hc_status_i,
    input logic [DataWidth-1:0]         queue_status_i
);

  localparam logic [AddrWidth-1:0] ADDR_HC_CONTROL   = 12'h000;
  localparam logic [AddrWidth-1:0] ADDR_CMD_QUEUE    = 12'h100;
  localparam logic [AddrWidth-1:0] ADDR_TX_DATA      = 12'h104;
  localparam logic [AddrWidth-1:0] ADDR_RX_DATA      = 12'h108;
  localparam logic [AddrWidth-1:0] ADDR_RESP         = 12'h10C;

  logic cmd_queue_write;
  logic tx_data_write;
  logic rx_data_read;
  logic resp_read;
  logic repeated_sw_reset_write;
  logic csr_bus_known;

  assign csr_bus_known          = !$isunknown({addr_i, wen_i, ren_i});
  assign cmd_queue_write        = wen_i && (addr_i == ADDR_CMD_QUEUE);
  assign tx_data_write          = wen_i && (addr_i == ADDR_TX_DATA);
  assign rx_data_read           = ren_i && (addr_i == ADDR_RX_DATA);
  assign resp_read              = ren_i && (addr_i == ADDR_RESP);
  assign repeated_sw_reset_write = wen_i && (addr_i == ADDR_HC_CONTROL) && wdata_i[1];

  assert property (@(posedge clk_i) disable iff (!rst_ni) ready_o)
  else $error("csr_registers_sva: ready_o must remain asserted");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   cmd_wvalid_o == cmd_wvalid_int_i)
  else $error("csr_registers_sva: cmd_wvalid_o must mirror internal cmd_wvalid");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   cmd_wdata_o == cmd_wdata_int_i)
  else $error("csr_registers_sva: cmd_wdata_o must mirror internal cmd_wdata");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   tx_wvalid_o == tx_wvalid_int_i)
  else $error("csr_registers_sva: tx_wvalid_o must mirror internal tx_wvalid");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   tx_wdata_o == tx_wdata_int_i)
  else $error("csr_registers_sva: tx_wdata_o must mirror internal tx_wdata");

  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_o || !csr_bus_known)
                   (cmd_queue_write && !cmd_wvalid_int_i && !cmd_staging_valid_i)
                   |=> (cmd_staging_valid_i && !cmd_wvalid_int_i &&
                        (cmd_dword0_i == $past(wdata_i))))
  else $error("csr_registers_sva: first CMD_QUEUE write must stage DWORD0 only");

  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_o || !csr_bus_known)
                   (cmd_queue_write && !cmd_wvalid_int_i && cmd_staging_valid_i)
                   |=> (!cmd_staging_valid_i && cmd_wvalid_int_i &&
                        (cmd_wdata_int_i == {$past(wdata_i), $past(cmd_dword0_i)})))
  else $error("csr_registers_sva: second CMD_QUEUE write must emit staged command");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   (cmd_staging_valid_i && !cmd_wvalid_int_i && wen_i &&
                    (addr_i != ADDR_CMD_QUEUE))
                   |=> (cmd_staging_valid_i && (cmd_dword0_i == $past(cmd_dword0_i))))
  else $error("csr_registers_sva: non-CMD writes must not disturb CMD staging");

  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_o)
                   (!$past(sw_reset_o) && cmd_wvalid_int_i && !cmd_wready_i)
                   |=> (sw_reset_o ||
                        (cmd_wvalid_int_i && (cmd_wdata_int_i == $past(cmd_wdata_int_i)))))
  else $error("csr_registers_sva: CMD write data changed before ready");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   sw_reset_o |=> (!cmd_staging_valid_i && !cmd_wvalid_int_i))
  else $error("csr_registers_sva: sw_reset_o must clear CMD staging and valid");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   (sw_reset_o && !repeated_sw_reset_write) |=> !sw_reset_o)
  else $error("csr_registers_sva: sw_reset_o must self-clear without another reset write");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   (tx_data_write && !tx_wvalid_int_i)
                   |=> (tx_wvalid_int_i && (tx_wdata_int_i == $past(wdata_i))))
  else $error("csr_registers_sva: TX_DATA write must raise tx_wvalid with written data");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (tx_wvalid_int_i && !tx_wready_i)
                   |=> (tx_wvalid_int_i && (tx_wdata_int_i == $past(tx_wdata_int_i))))
  else $error("csr_registers_sva: TX write data changed before ready");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   rx_rready_o == rx_data_read)
  else $error("csr_registers_sva: rx_rready_o must pulse only for RX_DATA reads");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   resp_rready_o == resp_read)
  else $error("csr_registers_sva: resp_rready_o must pulse only for RESP reads");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   (rx_data_read && rx_rvalid_i) |=> (rdata_o == $past(rx_rdata_i)))
  else $error("csr_registers_sva: RX_DATA read must return RX FIFO data");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   (rx_data_read && !rx_rvalid_i) |=> (rdata_o == '0))
  else $error("csr_registers_sva: empty RX_DATA read must return zero");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   (resp_read && resp_rvalid_i) |=> (rdata_o == $past(resp_rdata_i)))
  else $error("csr_registers_sva: RESP read must return RESP FIFO data");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   (resp_read && !resp_rvalid_i) |=> (rdata_o == '0))
  else $error("csr_registers_sva: empty RESP read must return zero");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   hc_status_i == {29'b0, resp_empty_i, cmd_full_i, i3c_fsm_idle_i})
  else $error("csr_registers_sva: HC_STATUS mirror mismatch");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   queue_status_i == {24'b0, resp_empty_i, resp_full_i, rx_empty_i, rx_full_i,
                                      tx_empty_i, tx_full_i, cmd_empty_i, cmd_full_i})
  else $error("csr_registers_sva: QUEUE_STATUS mirror mismatch");

endmodule
