module bus_monitor_sva #(
    parameter int CounterWidth = 20
) (
    input logic clk_i,
    input logic rst_ni,

    input logic enable_i,
    input logic [CounterWidth-1:0] t_r_i,
    input logic [CounterWidth-1:0] t_f_i,

    input logic scl_negedge_i,
    input logic scl_posedge_i,
    input logic sda_negedge_i,
    input logic sda_posedge_i,
    input logic sda_negedge,
    input logic sda_posedge,
    input logic sda_r,
    input logic scl_stable_high,
    input logic scl_high_at_sda_edge,
    input logic start_candidate,
    input logic stop_candidate,
    input logic start_candidate_q,
    input logic stop_candidate_q,
    input logic start_det_trigger,
    input logic stop_det_trigger,
    input logic start_det,
    input logic stop_det,
    input logic rstart_detection_en,
    input logic state_start_det,
    input logic state_rstart_det,
    input logic state_stop_det
);

  logic bus_event_trigger;

  assign bus_event_trigger = start_det_trigger || stop_det_trigger;

  ap_bus002_valid_start_reports_start:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && start_det_trigger && !rstart_detection_en
                   |=> state_start_det && !state_rstart_det && !state_stop_det)
  else $error("bus_monitor_sva: legal START did not report state_o.start_det in %m");

  cp_bus002_valid_start_reports_start:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && start_det_trigger && !rstart_detection_en
                  ##1 state_start_det && !state_rstart_det && !state_stop_det);

  ap_bus002_valid_stop_reports_stop:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && stop_det_trigger
                   |=> state_stop_det && !state_start_det && !state_rstart_det)
  else $error("bus_monitor_sva: legal STOP did not report state_o.stop_det in %m");

  cp_bus002_valid_stop_reports_stop:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && stop_det_trigger
                  ##1 state_stop_det && !state_start_det && !state_rstart_det);

  ap_bus003_first_start_classified_as_start:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && start_det && !rstart_detection_en
                   |-> state_start_det && !state_rstart_det)
  else $error("bus_monitor_sva: first START was not classified as start_det in %m");

  cp_bus003_first_start_classified_as_start:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && start_det && !rstart_detection_en
                  && state_start_det && !state_rstart_det);

  ap_bus003_first_start_enables_rstart_detection:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && start_det && !rstart_detection_en && !stop_det
                   |=> rstart_detection_en)
  else $error("bus_monitor_sva: START did not arm repeated START detection in %m");

  cp_bus003_first_start_enables_rstart_detection:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && start_det && !rstart_detection_en && !stop_det
                  ##1 rstart_detection_en);

  ap_bus003_repeated_start_classified_as_rstart:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && start_det && rstart_detection_en
                   |-> state_rstart_det && !state_start_det)
  else $error("bus_monitor_sva: repeated START was not classified as rstart_det in %m");

  cp_bus003_repeated_start_classified_as_rstart:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && start_det && rstart_detection_en
                  && state_rstart_det && !state_start_det);

  ap_bus003_stop_clears_rstart_detection:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && stop_det |=> !rstart_detection_en)
  else $error("bus_monitor_sva: STOP did not clear repeated START detection in %m");

  cp_bus003_stop_clears_rstart_detection:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && stop_det ##1 !rstart_detection_en);

  cp_bus003_start_rstart_stop_sequence:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && state_start_det
                  ##[1:64] state_rstart_det
                  ##[1:64] state_stop_det);

  ap_bus004_start_candidate_requires_filtered_sda_high:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && sda_negedge_i && !sda_r |=> !start_candidate_q)
  else $error("bus_monitor_sva: START candidate latched without prior filtered SDA high in %m");

  cp_bus004_start_candidate_requires_filtered_sda_high:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && sda_negedge_i && !sda_r ##1 !start_candidate_q);

  ap_bus004_stop_candidate_requires_filtered_sda_low:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && sda_posedge_i && sda_r |=> !stop_candidate_q)
  else $error("bus_monitor_sva: STOP candidate latched without prior filtered SDA low in %m");

  cp_bus004_stop_candidate_requires_filtered_sda_low:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && sda_posedge_i && sda_r ##1 !stop_candidate_q);

  ap_bus004_start_candidate_requires_scl_stable_high:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && sda_negedge_i && !scl_high_at_sda_edge
                   |=> !start_candidate_q)
  else $error("bus_monitor_sva: START candidate latched when SCL was not stable high in %m");

  cp_bus004_start_candidate_requires_scl_stable_high:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && sda_negedge_i && !scl_high_at_sda_edge
                  ##1 !start_candidate_q);

  ap_bus004_stop_candidate_requires_scl_stable_high:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && sda_posedge_i && !scl_high_at_sda_edge
                   |=> !stop_candidate_q)
  else $error("bus_monitor_sva: STOP candidate latched when SCL was not stable high in %m");

  cp_bus004_stop_candidate_requires_scl_stable_high:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && sda_posedge_i && !scl_high_at_sda_edge
                  ##1 !stop_candidate_q);

  ap_bus004_rejected_sda_falling_edge_no_start_trigger:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && sda_negedge && !start_candidate |-> !start_det_trigger)
  else $error("bus_monitor_sva: rejected SDA falling edge produced START trigger in %m");

  cp_bus004_rejected_sda_falling_edge_no_start_trigger:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && sda_negedge && !start_candidate && !start_det_trigger);

  ap_bus004_rejected_sda_rising_edge_no_stop_trigger:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && sda_posedge && !stop_candidate |-> !stop_det_trigger)
  else $error("bus_monitor_sva: rejected SDA rising edge produced STOP trigger in %m");

  cp_bus004_rejected_sda_rising_edge_no_stop_trigger:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && sda_posedge && !stop_candidate && !stop_det_trigger);

  ap_bus004_simultaneous_falling_edges_no_start_candidate:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && sda_negedge_i && scl_negedge_i |=> !start_candidate_q)
  else $error("bus_monitor_sva: simultaneous SCL/SDA falling edges latched START candidate in %m");

  cp_bus004_simultaneous_falling_edges_no_start_candidate:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && sda_negedge_i && scl_negedge_i ##1 !start_candidate_q);

  ap_bus004_simultaneous_rising_edges_no_stop_candidate:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   enable_i && sda_posedge_i && scl_posedge_i |=> !stop_candidate_q)
  else $error("bus_monitor_sva: simultaneous SCL/SDA rising edges latched STOP candidate in %m");

  cp_bus004_simultaneous_rising_edges_no_stop_candidate:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && sda_posedge_i && scl_posedge_i ##1 !stop_candidate_q);

  cp_bus004_short_sda_low_glitch_rejected:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && (t_f_i != '0) && scl_stable_high && sda_r && sda_negedge_i
                  ##[1:8] (sda_posedge_i && sda_r)
                  ##1 (!stop_candidate_q && !bus_event_trigger));

  cp_bus004_short_sda_high_glitch_rejected:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && (t_r_i != '0) && scl_stable_high && !sda_r && sda_posedge_i
                  ##[1:8] (sda_negedge_i && !sda_r)
                  ##1 (!start_candidate_q && !bus_event_trigger));

  cp_bus004_valid_start_trigger:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && sda_negedge_i && scl_high_at_sda_edge && sda_r
                  ##[1:16] start_det_trigger);

  cp_bus004_valid_stop_trigger:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  enable_i && sda_posedge_i && scl_high_at_sda_edge && !sda_r
                  ##[1:16] stop_det_trigger);

endmodule

bind bus_monitor bus_monitor_sva #(
    .CounterWidth(CounterWidth)
) u_bus_monitor_sva (
    .clk_i,
    .rst_ni,
    .enable_i,
    .t_r_i,
    .t_f_i,
    .scl_negedge_i,
    .scl_posedge_i,
    .sda_negedge_i,
    .sda_posedge_i,
    .sda_negedge,
    .sda_posedge,
    .sda_r,
    .scl_stable_high,
    .scl_high_at_sda_edge,
    .start_candidate,
    .stop_candidate,
    .start_candidate_q,
    .stop_candidate_q,
    .start_det_trigger,
    .stop_det_trigger,
    .start_det,
    .stop_det,
    .rstart_detection_en,
    .state_start_det(state_o.start_det),
    .state_rstart_det(state_o.rstart_det),
    .state_stop_det(state_o.stop_det)
);
