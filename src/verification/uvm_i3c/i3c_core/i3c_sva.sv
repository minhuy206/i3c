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

module sync_fifo_model_sva #(
    parameter  int unsigned Width  = 32,
    parameter  int unsigned Depth  = 64,
    localparam int unsigned DepthW = $clog2(Depth + 1)
) (
    input logic clk_i,
    input logic rst_ni,
    input logic flush_i,

    input logic             wvalid_i,
    input logic             wready_o,
    input logic [Width-1:0] wdata_i,

    input logic             rvalid_o,
    input logic             rready_i,
    input logic [Width-1:0] rdata_o,

    input logic              empty_o,
    input logic [DepthW-1:0] depth_o
);

  logic [Width-1:0] model_q[$];
  bit               model_valid_q;

  logic do_write;
  logic do_read;

  assign do_write = wvalid_i && wready_o;
  assign do_read  = rready_i && rvalid_o;

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_fifo_model
    if (!rst_ni) begin
      model_q.delete();
      model_valid_q <= 1'b1;
    end else if (flush_i) begin
      model_q.delete();
      model_valid_q <= 1'b1;
    end else if (model_valid_q && (model_q.size() != int'(depth_o))) begin
      model_q.delete();
      model_valid_q <= empty_o && (depth_o == '0);
    end else if (model_valid_q) begin
      if (do_read) begin
        assert (model_q.size() > 0)
        else $error("sync_fifo_model_sva: tracked read underflow in %m");

        if (model_q.size() > 0) begin
          assert (rdata_o === model_q[0])
          else $error("sync_fifo_model_sva: read order mismatch in %m exp=0x%0h got=0x%0h",
                      model_q[0], rdata_o);
          void'(model_q.pop_front());
        end
      end

      if (do_write) begin
        assert (model_q.size() < Depth)
        else $error("sync_fifo_model_sva: tracked write overflow in %m");

        if (model_q.size() < Depth) begin
          model_q.push_back(wdata_i);
        end
      end
    end else if (empty_o && (depth_o == '0)) begin
      model_q.delete();
      model_valid_q <= 1'b1;
    end
  end

endmodule

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
