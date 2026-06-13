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

    input wire sda_bus_i
);

  wire dut_drives = dut_sda_oe_i;
  wire device_drives = device_sda_pp_en_i || !device_sda_o_i;
  wire device_drives_low = !device_sda_o_i;
  wire device_drives_high = device_sda_pp_en_i && device_sda_o_i;
  wire device_released = !device_sda_pp_en_i && device_sda_o_i;
  wire safe_od_low_overlap = dut_drives && !dut_sda_o_i && !dut_sel_od_pp_i &&
      !device_sda_pp_en_i && !device_sda_o_i;
  wire unsafe_contention = dut_drives && device_drives && !safe_od_low_overlap;

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
                       sda_bus_i
                   }))
  else $error("tb_pad_model_sva: pad-model signals must not be X/Z");

  cp_pad_model_signals_known:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  !$isunknown({
                      dut_sda_oe_i,
                      dut_sda_o_i,
                      dut_sel_od_pp_i,
                      if_dut_sda_oe_i,
                      if_dut_sda_o_i,
                      if_dut_sel_od_pp_i,
                      device_sda_o_i,
                      device_sda_pp_en_i,
                      sda_bus_i
                  }));

  ap_sda_bus_known:
  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(sda_bus_i))
  else $error("tb_pad_model_sva: SDA bus must not resolve to X/Z");

  cp_sda_bus_known:
  cover property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(sda_bus_i));

  ap_if_dut_sda_oe_mirror:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   if_dut_sda_oe_i === dut_sda_oe_i)
  else $error("tb_pad_model_sva: i3c_if dut_sda_oe mirror mismatch");

  cp_if_dut_sda_oe_mirror:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  if_dut_sda_oe_i === dut_sda_oe_i);

  ap_if_dut_sda_o_mirror:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   if_dut_sda_o_i === dut_sda_o_i)
  else $error("tb_pad_model_sva: i3c_if dut_sda_o mirror mismatch");

  cp_if_dut_sda_o_mirror:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  if_dut_sda_o_i === dut_sda_o_i);

  ap_if_dut_sel_od_pp_mirror:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   if_dut_sel_od_pp_i === dut_sel_od_pp_i)
  else $error("tb_pad_model_sva: i3c_if dut_sel_od_pp mirror mismatch");

  cp_if_dut_sel_od_pp_mirror:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  if_dut_sel_od_pp_i === dut_sel_od_pp_i);

  ap_dut_sda_low_drive_bus_low:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   dut_sda_oe_i && !dut_sda_o_i |-> sda_bus_i === 1'b0)
  else $error("tb_pad_model_sva: DUT SDA low drive must pull bus low");

  cp_dut_sda_low_drive_bus_low:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  dut_sda_oe_i && !dut_sda_o_i && (sda_bus_i === 1'b0));

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

  ap_no_unsafe_contention:
  assert property (@(posedge clk_i) disable iff (!rst_ni) !unsafe_contention)
  else $error("tb_pad_model_sva: DUT and target must not create unsafe SDA contention");

  cp_no_unsafe_contention:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  !unsafe_contention && (dut_drives || device_drives));

  cp_safe_od_low_overlap:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  safe_od_low_overlap && (sda_bus_i === 1'b0));

endmodule
