module i3c_controller_top_sva (
    input logic clk_i,
    input logic rst_ni,
    input logic sw_reset_i,

    input logic        cmd_csr_wvalid_i,
    input logic        cmd_csr_wready_i,
    input logic [63:0] cmd_csr_wdata_i,
    input logic        cmd_hw_rvalid_i,
    input logic        cmd_hw_rready_i,
    input logic [63:0] cmd_hw_rdata_i,

    input logic        tx_csr_wvalid_i,
    input logic        tx_csr_wready_i,
    input logic [31:0] tx_csr_wdata_i,
    input logic        tx_hw_rvalid_i,
    input logic        tx_hw_rready_i,
    input logic [31:0] tx_hw_rdata_i,

    input logic        rx_hw_wvalid_i,
    input logic        rx_hw_wready_i,
    input logic [31:0] rx_hw_wdata_i,
    input logic        rx_csr_rvalid_i,
    input logic        rx_csr_rready_i,
    input logic [31:0] rx_csr_rdata_i,

    input logic        resp_hw_wvalid_i,
    input logic        resp_hw_wready_i,
    input logic [31:0] resp_hw_wdata_i,
    input logic        resp_csr_rvalid_i,
    input logic        resp_csr_rready_i,
    input logic [31:0] resp_csr_rdata_i
);

  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i)
                   (!$past(sw_reset_i) && !$past(sw_reset_i, 2) && !$past(sw_reset_i, 3) &&
                    cmd_csr_wvalid_i && !cmd_csr_wready_i)
                   |=> (sw_reset_i || $past(sw_reset_i) || $past(sw_reset_i, 2) ||
                        !cmd_csr_wvalid_i ||
                        (cmd_csr_wvalid_i && (cmd_csr_wdata_i == $past(cmd_csr_wdata_i)))))
  else $error("i3c_controller_top_sva: CMD CSR write data changed while valid stayed blocked");

  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i)
                   (!$past(sw_reset_i) && !$past(sw_reset_i, 2) && !$past(sw_reset_i, 3) &&
                    cmd_hw_rvalid_i && !cmd_hw_rready_i)
                   |=> (sw_reset_i || $past(sw_reset_i) || $past(sw_reset_i, 2) ||
                        (cmd_hw_rvalid_i && (cmd_hw_rdata_i == $past(cmd_hw_rdata_i)))))
  else $error("i3c_controller_top_sva: CMD HW read data changed before ready");

  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i)
                   (!$past(sw_reset_i) && !$past(sw_reset_i, 2) && !$past(sw_reset_i, 3) &&
                    tx_csr_wvalid_i && !tx_csr_wready_i)
                   |=> (sw_reset_i || $past(sw_reset_i) || $past(sw_reset_i, 2) ||
                        !tx_csr_wvalid_i ||
                        (tx_csr_wvalid_i && (tx_csr_wdata_i == $past(tx_csr_wdata_i)))))
  else $error("i3c_controller_top_sva: TX CSR write data changed while valid stayed blocked");

  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i)
                   (!$past(sw_reset_i) && !$past(sw_reset_i, 2) && !$past(sw_reset_i, 3) &&
                    tx_hw_rvalid_i && !tx_hw_rready_i)
                   |=> (sw_reset_i || $past(sw_reset_i) || $past(sw_reset_i, 2) ||
                        (tx_hw_rvalid_i && (tx_hw_rdata_i == $past(tx_hw_rdata_i)))))
  else $error("i3c_controller_top_sva: TX HW read data changed before ready");

  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i)
                   (!$past(sw_reset_i) && !$past(sw_reset_i, 2) && !$past(sw_reset_i, 3) &&
                    rx_hw_wvalid_i && !rx_hw_wready_i)
                   |=> (sw_reset_i || $past(sw_reset_i) || $past(sw_reset_i, 2) ||
                        !rx_hw_wvalid_i ||
                        (rx_hw_wvalid_i && (rx_hw_wdata_i == $past(rx_hw_wdata_i)))))
  else $error("i3c_controller_top_sva: RX HW write data changed while valid stayed blocked");

  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i)
                   (!$past(sw_reset_i) && !$past(sw_reset_i, 2) && !$past(sw_reset_i, 3) &&
                    rx_csr_rvalid_i && !rx_csr_rready_i)
                   |=> (sw_reset_i || $past(sw_reset_i) || $past(sw_reset_i, 2) ||
                        (rx_csr_rvalid_i && (rx_csr_rdata_i == $past(rx_csr_rdata_i)))))
  else $error("i3c_controller_top_sva: RX CSR read data changed before ready");

  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i)
                   (!$past(sw_reset_i) && !$past(sw_reset_i, 2) && !$past(sw_reset_i, 3) &&
                    resp_hw_wvalid_i && !resp_hw_wready_i)
                   |=> (sw_reset_i || $past(sw_reset_i) || $past(sw_reset_i, 2) ||
                        !resp_hw_wvalid_i ||
                        (resp_hw_wvalid_i && (resp_hw_wdata_i == $past(resp_hw_wdata_i)))))
  else $error("i3c_controller_top_sva: RESP HW write data changed while valid stayed blocked");

  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i)
                   (!$past(sw_reset_i) && !$past(sw_reset_i, 2) && !$past(sw_reset_i, 3) &&
                    resp_csr_rvalid_i && !resp_csr_rready_i)
                   |=> (sw_reset_i || $past(sw_reset_i) || $past(sw_reset_i, 2) ||
                        (resp_csr_rvalid_i && (resp_csr_rdata_i == $past(resp_csr_rdata_i)))))
  else $error("i3c_controller_top_sva: RESP CSR read data changed before ready");

endmodule
