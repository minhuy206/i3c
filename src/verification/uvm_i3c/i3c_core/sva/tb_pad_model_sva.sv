module tb_pad_model_sva (
    input logic clk_i,
    input logic rst_ni,

    input logic dut_sda_oe_i,
    input logic dut_sda_o_i,
    input logic dut_sel_od_pp_i,

    input logic if_dut_sda_oe_i,
    input logic if_dut_sda_o_i,
    input logic if_dut_sel_od_pp_i,
    input logic device_sda_o_i,
    input logic device_sda_pp_en_i,
    input logic hc_abort_i,

    input wire sda_bus_i
);

  wire dut_drives = dut_sda_oe_i;
  wire device_drives = device_sda_pp_en_i || !device_sda_o_i;
  wire device_drives_low = !device_sda_o_i;
  wire device_drives_high = device_sda_pp_en_i && device_sda_o_i;
  wire device_released = !device_sda_pp_en_i && device_sda_o_i;
  wire safe_od_low_overlap = dut_drives && !dut_sda_o_i && !dut_sel_od_pp_i &&
      !device_sda_pp_en_i && !device_sda_o_i;
  wire safe_same_low_overlap = dut_drives && !dut_sda_o_i && device_drives_low;
  wire model_turnaround_overlap = dut_drives && !dut_sda_o_i && !dut_sel_od_pp_i &&
      device_drives_high && (sda_bus_i === 1'b0);
  wire hc_abort_read_contention = hc_abort_i && dut_drives && !dut_sda_o_i &&
      device_drives_high;
  wire unsafe_contention = dut_drives && device_drives && !safe_same_low_overlap &&
      !model_turnaround_overlap && !hc_abort_read_contention;
  wire pad_interface_signals_visible = (if_dut_sda_oe_i === dut_sda_oe_i) &&
      (if_dut_sda_o_i === dut_sda_o_i) &&
      (if_dut_sel_od_pp_i === dut_sel_od_pp_i);

  ap_pad_model_signals_known:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !$isunknown({
                       dut_sda_oe_i,
                       dut_sda_o_i,
                       dut_sel_od_pp_i,
                       if_dut_sda_oe_i,
                       if_dut_sda_o_i,
                       if_dut_sel_od_pp_i,
                       device_sda_o_i,
                       device_sda_pp_en_i,
                       hc_abort_i
                   }) && (!$isunknown(sda_bus_i) || hc_abort_read_contention))
  else $error("tb_pad_model_sva: pad-model signals must not be X/Z");

  // No matching cover for the known-signal invariant: it hits on the first
  // enabled idle cycle. The electrical ownership covers below require actual
  // controller/target drive activity. ap_sda_bus_known was subsumed here.

  // The behavioral target can release PP-high on a different scheduler point
  // than the DUT takes over with OD-low for read turnaround. Allow only a
  // single sampled cycle, and keep the bus-known assertion active.
  ap_pad_model_turnaround_overlap_one_cycle:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   model_turnaround_overlap |=> !model_turnaround_overlap)
  else $error("tb_pad_model_sva: pad-model turnaround overlap persisted");

  cp_pad_model_turnaround_overlap_one_cycle:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  model_turnaround_overlap ##1 !model_turnaround_overlap);

  // BUS_013 sign-off hooks: the detailed assertions below check each electrical
  // case; these labels keep the testplan mapping explicit.
  ap_pad_model_interface_signals_visible:
  assert property (@(posedge clk_i) disable iff (!rst_ni) pad_interface_signals_visible)
  else $error("tb_pad_model_sva: BUS_013 i3c_if pad visibility mismatch");

  // No matching cover: interface visibility is a static wiring invariant and
  // would hit while idle. Keep one combined assertion instead of three mirror
  // assertions for the individual interface signals.

  ap_pad_model_no_unsafe_sda_contention:
  assert property (@(posedge clk_i) disable iff (!rst_ni) !unsafe_contention)
  else $error(
      "tb_pad_model_sva: BUS_013 unsafe SDA contention dut_oe=%0b dut_sda=%0b dut_pp=%0b dev_sda=%0b dev_pp=%0b sda_bus=%0b model_turnaround=%0b hc_abort=%0b",
      dut_sda_oe_i, dut_sda_o_i, dut_sel_od_pp_i, device_sda_o_i, device_sda_pp_en_i,
      sda_bus_i, model_turnaround_overlap, hc_abort_i);

  cp_pad_model_no_unsafe_sda_contention:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  !unsafe_contention && (dut_drives || device_drives));

  cp_pad_model_dut_drive_high_pp:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  dut_drives && dut_sda_o_i && dut_sel_od_pp_i &&
                  (sda_bus_i === 1'b1));

  ap_dut_sda_low_drive_bus_low:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   dut_sda_oe_i && !dut_sda_o_i && !hc_abort_read_contention
                   |-> sda_bus_i === 1'b0)
  else $error("tb_pad_model_sva: DUT SDA low drive must pull bus low");

  cp_dut_sda_low_drive_bus_low:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  dut_sda_oe_i && !dut_sda_o_i && !hc_abort_read_contention &&
                  (sda_bus_i === 1'b0));

  ap_dut_sda_high_drive_bus_high:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   dut_sda_oe_i && dut_sda_o_i |-> sda_bus_i === 1'b1)
  else $error("tb_pad_model_sva: DUT SDA high drive must drive bus high");

  cp_dut_sda_high_drive_bus_high:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  dut_sda_oe_i && dut_sda_o_i && (sda_bus_i === 1'b1));

  ap_dut_sda_high_drive_only_pp:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   dut_sda_oe_i && dut_sda_o_i |-> dut_sel_od_pp_i)
  else $error("tb_pad_model_sva: DUT must only drive SDA high in push-pull mode");

  cp_dut_sda_high_drive_only_pp:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  dut_sda_oe_i && dut_sda_o_i && dut_sel_od_pp_i);

  ap_target_sda_low_drive_bus_low:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !dut_drives && device_drives_low |-> sda_bus_i === 1'b0)
  else $error("tb_pad_model_sva: target SDA low drive must pull bus low when DUT releases");

  cp_target_sda_low_drive_bus_low:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  !dut_drives && device_drives_low && (sda_bus_i === 1'b0));

  ap_target_sda_high_drive_bus_high:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !dut_drives && device_drives_high |-> sda_bus_i === 1'b1)
  else $error("tb_pad_model_sva: target SDA high drive must drive bus high when DUT releases");

  cp_target_sda_high_drive_bus_high:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  !dut_drives && device_drives_high && (sda_bus_i === 1'b1));

  ap_released_sda_pullup_high:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !dut_drives && device_released |-> sda_bus_i === 1'b1)
  else $error("tb_pad_model_sva: released SDA must return high through the pull-up");

  cp_released_sda_pullup_high:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  !dut_drives && device_released && (sda_bus_i === 1'b1));

  cp_safe_od_low_overlap:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  safe_od_low_overlap && (sda_bus_i === 1'b0));

  cp_safe_same_low_overlap:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  safe_same_low_overlap && (sda_bus_i === 1'b0));

  cp_hc_abort_read_contention:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  hc_abort_read_contention);

endmodule
