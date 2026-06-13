module i3c_controller_top_sva #(
    parameter int unsigned AddrWidth = 12,
    parameter int unsigned DataWidth = 32,
    parameter int unsigned MaxEnableToCmdAcceptCycles = 32
) (
    input logic clk_i,
    input logic rst_ni,

    input logic [AddrWidth-1:0] reg_addr_i,
    input logic [DataWidth-1:0] reg_wdata_i,
    input logic                 reg_wen_i,
    input logic                 reg_ren_i,
    input logic [DataWidth-1:0] reg_rdata_o,

    input logic ctrl_enable_i,
    input logic i3c_fsm_en_i,
    input logic broadcast_header_enable_i,
    input logic i3c_fsm_idle_i,

    input logic cmd_hw_rvalid_i,
    input logic cmd_hw_rready_i,
    input logic cmd_empty_i,
    input logic resp_empty_i,

    input logic flow_gen_start_i,
    input logic flow_gen_rstart_i,
    input logic flow_gen_stop_i,
    input logic flow_gen_clock_i,
    input logic ctrl_sda_oe_to_phy_i,
    input logic sda_oe_o
);

  localparam logic [AddrWidth-1:0] ADDR_HC_CONTROL = 12'h000;
  localparam logic [AddrWidth-1:0] ADDR_QUEUE_STATUS = 12'h110;
  localparam int unsigned QS_CMD_EMPTY_BIT = 1;
  localparam int unsigned QS_RESP_EMPTY_BIT = 7;

  logic seen_enable_q;
  logic hc_control_write;
  logic hc_control_read;
  logic queue_status_read;
  logic pre_enable_window;
  logic pre_enable_bus_idle;

  always_ff @(posedge clk_i or negedge rst_ni) begin : track_first_enable
    if (!rst_ni) seen_enable_q <= 1'b0;
    else if (ctrl_enable_i) seen_enable_q <= 1'b1;
  end

  assign hc_control_write = reg_wen_i && (reg_addr_i == ADDR_HC_CONTROL);
  assign hc_control_read = reg_ren_i && !reg_wen_i && (reg_addr_i == ADDR_HC_CONTROL);
  assign queue_status_read = reg_ren_i && !reg_wen_i && (reg_addr_i == ADDR_QUEUE_STATUS);
  assign pre_enable_window = !seen_enable_q && !ctrl_enable_i;
  assign pre_enable_bus_idle =
      !flow_gen_start_i && !flow_gen_rstart_i && !flow_gen_stop_i &&
      !flow_gen_clock_i && !ctrl_sda_oe_to_phy_i && !sda_oe_o;

  ap_ctrl_enable_matches_i3c_fsm_en :
  assert property (@(posedge clk_i) disable iff (!rst_ni) ctrl_enable_i == i3c_fsm_en_i)
  else $error("i3c_controller_top_sva: ctrl_enable and i3c_fsm_en mismatch");

  cp_ctrl_enable_matches_i3c_fsm_en :
  cover property (@(posedge clk_i) disable iff (!rst_ni) ctrl_enable_i == i3c_fsm_en_i);

  ap_pre_enable_no_cmd_pop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   pre_enable_window && cmd_hw_rvalid_i |-> !cmd_hw_rready_i)
  else $error("i3c_controller_top_sva: command popped before HC_CONTROL.ENABLE");

  cp_pre_enable_no_cmd_pop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  pre_enable_window && cmd_hw_rvalid_i && !cmd_hw_rready_i);

  ap_pre_enable_no_bus_activity :
  assert property (@(posedge clk_i) disable iff (!rst_ni) pre_enable_window |-> pre_enable_bus_idle)
  else $error("i3c_controller_top_sva: bus activity observed before HC_CONTROL.ENABLE");

  cp_pre_enable_no_bus_activity :
  cover property (@(posedge clk_i) disable iff (!rst_ni) pre_enable_window && pre_enable_bus_idle);

  ap_broadcast_only_write_keeps_disabled :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   hc_control_write && reg_wdata_i[2] && !reg_wdata_i[0]
                   |=> (!ctrl_enable_i && broadcast_header_enable_i))
  else $error("i3c_controller_top_sva: BROADCAST_HEADER_ENABLE-only write enabled controller");

  cp_broadcast_only_write_keeps_disabled :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  hc_control_write && reg_wdata_i[2] && !reg_wdata_i[0]
                  ##1 (!ctrl_enable_i && broadcast_header_enable_i));

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
                   pre_enable_window && queue_status_read && cmd_hw_rvalid_i
                   |=> (!reg_rdata_o[QS_CMD_EMPTY_BIT] && reg_rdata_o[QS_RESP_EMPTY_BIT]))
  else $error("i3c_controller_top_sva: disabled QUEUE_STATUS did not show pending CMD/no RESP");

  cp_disabled_queue_status_has_pending_cmd_no_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  pre_enable_window && queue_status_read && cmd_hw_rvalid_i
                  ##1 (!reg_rdata_o[QS_CMD_EMPTY_BIT] && reg_rdata_o[QS_RESP_EMPTY_BIT]));

  ap_hc_control_enable_readback :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   hc_control_read |=> (reg_rdata_o[0] == $past(
      ctrl_enable_i
  )))
  else $error("i3c_controller_top_sva: HC_CONTROL ENABLE readback mismatch");

  cp_hc_control_enable_readback :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  hc_control_read ##1 (reg_rdata_o[0] == $past(
      ctrl_enable_i
  )));

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
    .reg_wdata_i,
    .reg_wen_i,
    .reg_ren_i,
    .reg_rdata_o,
    .ctrl_enable_i(ctrl_enable),
    .i3c_fsm_en_i(i3c_fsm_en),
    .broadcast_header_enable_i(broadcast_header_enable),
    .i3c_fsm_idle_i(i3c_fsm_idle),
    .cmd_hw_rvalid_i(cmd_hw_rvalid),
    .cmd_hw_rready_i(cmd_hw_rready),
    .cmd_empty_i(cmd_empty),
    .resp_empty_i(resp_empty),
    .flow_gen_start_i(u_ctrl.flow_gen_start),
    .flow_gen_rstart_i(u_ctrl.flow_gen_rstart),
    .flow_gen_stop_i(u_ctrl.flow_gen_stop),
    .flow_gen_clock_i(u_ctrl.flow_gen_clock),
    .ctrl_sda_oe_to_phy_i(ctrl_sda_oe_to_phy),
    .sda_oe_o
);
