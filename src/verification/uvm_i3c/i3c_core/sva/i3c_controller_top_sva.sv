module i3c_controller_top_sva #(
    parameter int unsigned AddrWidth = 12,
    parameter int unsigned DataWidth = 32,
    parameter int unsigned MaxEnableToCmdAcceptCycles = 32
) (
    input logic clk_i,
    input logic rst_ni,

    input logic [AddrWidth-1:0] reg_addr_i,
    input logic                 reg_wen_i,
    input logic                 reg_ren_i,
    input logic [DataWidth-1:0] reg_rdata_o,

    input logic ctrl_enable_i,
    input logic i3c_fsm_idle_i,

    input logic cmd_hw_rvalid_i,
    input logic cmd_hw_rready_i,
    input logic tx_hw_rready_i,
    input logic rx_hw_wvalid_i,
    input logic resp_hw_wvalid_i,
    input logic cmd_empty_i,
    input logic resp_empty_i,

    input logic flow_gen_start_i,
    input logic flow_gen_rstart_i,
    input logic flow_gen_stop_i,
    input logic flow_gen_clock_i,
    input logic flow_use_i2c_timing_i,
    input logic scl_o,
    input logic sda_o,
    input logic sel_od_pp_o
);

  localparam logic [AddrWidth-1:0] ADDR_QUEUE_STATUS = 12'h0B4;
  localparam int unsigned QS_CMD_EMPTY_BIT = 1;
  localparam int unsigned QS_RESP_EMPTY_BIT = 7;

  logic seen_enable_q;
  logic queue_status_read;
  logic disabled_window;
  logic disabled_bus_idle;
  logic sda_oe;

  always_ff @(posedge clk_i or negedge rst_ni) begin : track_first_enable
    if (!rst_ni) seen_enable_q <= 1'b0;
    else if (ctrl_enable_i) seen_enable_q <= 1'b1;
  end

  assign queue_status_read = reg_ren_i && !reg_wen_i && (reg_addr_i == ADDR_QUEUE_STATUS);
  assign disabled_window = !ctrl_enable_i;
  assign sda_oe = sel_od_pp_o || !sda_o;
  assign disabled_bus_idle =
      !flow_gen_start_i && !flow_gen_rstart_i && !flow_gen_stop_i &&
      !flow_gen_clock_i && !sda_oe;

  ap_hard_reset_forces_idle_and_releases_bus :
  assert property (@(posedge clk_i)
                   !rst_ni |->
                   (i3c_fsm_idle_i && scl_o && sda_o &&
                    !sda_oe && !sel_od_pp_o))
  else $error("i3c_controller_top_sva: hard reset did not force idle and release the bus");

  cp_hard_reset_forces_idle_and_releases_bus :
  cover property (@(posedge clk_i)
                  !rst_ni && i3c_fsm_idle_i && scl_o && sda_o &&
                  !sda_oe && !sel_od_pp_o);

  ap_hard_reset_release_has_no_queue_activity :
  assert property (@(posedge clk_i) $rose(
      rst_ni
  ) |-> (i3c_fsm_idle_i && !cmd_hw_rready_i && !tx_hw_rready_i && !rx_hw_wvalid_i &&
         !resp_hw_wvalid_i))
  else $error("i3c_controller_top_sva: queue activity observed at hard-reset release");

  cp_hard_reset_release_has_no_queue_activity :
  cover property (@(posedge clk_i) $rose(
      rst_ni
  ) && i3c_fsm_idle_i && !cmd_hw_rready_i && !tx_hw_rready_i && !rx_hw_wvalid_i &&
      !resp_hw_wvalid_i);

  cp_reset_point_idle :
  cover property (@(negedge rst_ni) i3c_fsm_idle_i);

  ap_disabled_no_cmd_pop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   disabled_window && cmd_hw_rvalid_i |-> !cmd_hw_rready_i)
  else $error("i3c_controller_top_sva: command popped while HC_CONTROL.ENABLE=0");

  cp_disabled_no_cmd_pop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  disabled_window && cmd_hw_rvalid_i && !cmd_hw_rready_i);

  ap_disabled_no_bus_activity :
  assert property (@(posedge clk_i) disable iff (!rst_ni) disabled_window |-> disabled_bus_idle)
  else $error("i3c_controller_top_sva: bus activity observed while HC_CONTROL.ENABLE=0");

  cp_disabled_no_bus_activity :
  cover property (@(posedge clk_i) disable iff (!rst_ni) disabled_window && disabled_bus_idle);

  ap_enable_with_pending_cmd_pops_cmd :
  assert property (@(posedge clk_i) disable iff (!rst_ni) $rose(
      ctrl_enable_i
  ) && cmd_hw_rvalid_i |-> ##[1:MaxEnableToCmdAcceptCycles] cmd_hw_rready_i)
  else $error("i3c_controller_top_sva: pending command was not accepted after enable");

  cp_enable_with_pending_cmd_pops_cmd :
  cover property (@(posedge clk_i) disable iff (!rst_ni) $rose(
      ctrl_enable_i
  ) && cmd_hw_rvalid_i ##[1:MaxEnableToCmdAcceptCycles] cmd_hw_rready_i);

  ap_disabled_queue_status_has_pending_cmd_no_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   disabled_window && queue_status_read && cmd_hw_rvalid_i && resp_empty_i
                   |=> (!reg_rdata_o[QS_CMD_EMPTY_BIT] && reg_rdata_o[QS_RESP_EMPTY_BIT]))
  else $error("i3c_controller_top_sva: disabled QUEUE_STATUS did not show pending CMD/no RESP");

  cp_disabled_queue_status_has_pending_cmd_no_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  disabled_window && queue_status_read && cmd_hw_rvalid_i && resp_empty_i
                  ##1 (!reg_rdata_o[QS_CMD_EMPTY_BIT] && reg_rdata_o[QS_RESP_EMPTY_BIT]));

  ap_i2c_timing_forces_top_open_drain :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   ctrl_enable_i && flow_use_i2c_timing_i |-> !sel_od_pp_o)
  else $error("i3c_controller_top_sva: BUS_014 top-level I2C path asserted push-pull");

  cp_i2c_timing_forces_top_open_drain :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  ctrl_enable_i && flow_use_i2c_timing_i && !sel_od_pp_o);

  cp_cmd_start_after_enable :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  seen_enable_q && (flow_gen_start_i || flow_gen_rstart_i));

  cp_status_returns_idle_after_enable :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  seen_enable_q && i3c_fsm_idle_i && cmd_empty_i && resp_empty_i);

endmodule

bind i3c_controller_top i3c_controller_top_sva #(
    .AddrWidth(AddrWidth),
    .DataWidth(DataWidth)
) u_i3c_controller_top_sva (
    .clk_i,
    .rst_ni,
    .reg_addr_i,
    .reg_wen_i,
    .reg_ren_i,
    .reg_rdata_o,
    .ctrl_enable_i(ctrl_enable),
    .i3c_fsm_idle_i(i3c_fsm_idle),
    .cmd_hw_rvalid_i(cmd_hw_rvalid),
    .cmd_hw_rready_i(cmd_hw_rready),
    .tx_hw_rready_i(tx_hw_rready),
    .rx_hw_wvalid_i(rx_hw_wvalid),
    .resp_hw_wvalid_i(resp_hw_wvalid),
    .cmd_empty_i(cmd_empty),
    .resp_empty_i(resp_empty),
    .flow_gen_start_i(u_ctrl.flow_gen_start),
    .flow_gen_rstart_i(u_ctrl.flow_gen_rstart),
    .flow_gen_stop_i(u_ctrl.flow_gen_stop),
    .flow_gen_clock_i(u_ctrl.flow_gen_clock),
    .flow_use_i2c_timing_i(u_ctrl.flow_use_i2c_timing),
    .scl_o,
    .sda_o,
    .sel_od_pp_o
);
