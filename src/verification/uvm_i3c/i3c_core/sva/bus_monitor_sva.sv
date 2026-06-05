module bus_monitor_event_sva #(
    parameter int CounterWidth = 20
) (
    input logic                      clk_i,
    input logic                      rst_ni,
    input logic                      enable_i,
    input logic                      scl_i,
    input logic                      sda_i,
    input logic [CounterWidth-1:0]   t_r_i,
    input logic [CounterWidth-1:0]   t_f_i,
    input logic                      scl_negedge,
    input logic                      sda_negedge,
    input logic                      sda_posedge,
    input logic                      scl_stable_high,
    input logic                      simultaneous_posedge,
    input logic                      simultaneous_negedge,
    input logic                      start_det_trigger,
    input logic                      stop_det_trigger,
    input logic                      rstart_detection_en,
    input logic                      start_det_o,
    input logic                      rstart_det_o,
    input logic                      stop_det_o
);

  logic past_valid_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) past_valid_q <= 1'b0;
    else past_valid_q <= 1'b1;
  end

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   start_det_trigger == (enable_i && scl_stable_high && sda_negedge &&
                                         !scl_negedge && !simultaneous_negedge))
  else $error("bus_monitor_event_sva: START trigger equation mismatch in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   stop_det_trigger == (enable_i && scl_stable_high && sda_posedge &&
                                        !scl_negedge && !simultaneous_posedge))
  else $error("bus_monitor_event_sva: STOP trigger equation mismatch in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   ($past(enable_i && start_det_trigger && !rstart_detection_en) && enable_i)
                   |-> start_det_o)
  else $error("bus_monitor_event_sva: START trigger did not produce START event in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   ($past(enable_i && start_det_trigger && rstart_detection_en) && enable_i)
                   |-> rstart_det_o)
  else $error("bus_monitor_event_sva: START trigger did not produce repeated START event in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   ($past(enable_i && stop_det_trigger) && enable_i) |-> stop_det_o)
  else $error("bus_monitor_event_sva: STOP trigger did not produce STOP event in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   start_det_o |-> $past(enable_i && start_det_trigger &&
                                         !rstart_detection_en))
  else $error("bus_monitor_event_sva: START event asserted without matching trigger in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   rstart_det_o |-> $past(enable_i && start_det_trigger &&
                                          rstart_detection_en))
  else $error("bus_monitor_event_sva: repeated START event asserted without matching trigger in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   stop_det_o |-> $past(enable_i && stop_det_trigger))
  else $error("bus_monitor_event_sva: STOP event asserted without matching trigger in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   (enable_i && (t_r_i == '0) && (t_f_i == '0) && $past(scl_i) &&
                    scl_i && $past(sda_i) && !sda_i && !rstart_detection_en)
                   |=> start_det_o)
  else $error("bus_monitor_event_sva: zero-delay START input edge did not produce START event in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   (enable_i && (t_r_i == '0) && (t_f_i == '0) && $past(scl_i) &&
                    scl_i && $past(sda_i) && !sda_i && rstart_detection_en)
                   |=> rstart_det_o)
  else $error("bus_monitor_event_sva: zero-delay START input edge did not produce repeated START event in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   (enable_i && (t_r_i == '0) && (t_f_i == '0) && $past(scl_i) &&
                    scl_i && !$past(sda_i) && sda_i)
                   |=> stop_det_o)
  else $error("bus_monitor_event_sva: zero-delay STOP input edge did not produce STOP event in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !(start_det_o && rstart_det_o) && !(start_det_o && stop_det_o) &&
                   !(rstart_det_o && stop_det_o))
  else $error("bus_monitor_event_sva: bus event outputs must be mutually exclusive in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   start_det_o |=> !start_det_o)
  else $error("bus_monitor_event_sva: START event must be a one-cycle pulse in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   rstart_det_o |=> !rstart_det_o)
  else $error("bus_monitor_event_sva: repeated START event must be a one-cycle pulse in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   stop_det_o |=> !stop_det_o)
  else $error("bus_monitor_event_sva: STOP event must be a one-cycle pulse in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !enable_i |-> !(start_det_o || rstart_det_o || stop_det_o))
  else $error("bus_monitor_event_sva: bus events must remain low while monitor is disabled in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   stop_det_o |=> !rstart_detection_en)
  else $error("bus_monitor_event_sva: STOP event must clear repeated START tracking in %m");

endmodule
