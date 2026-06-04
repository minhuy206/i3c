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

  wire device_released = !device_sda_pp_en_i && device_sda_o_i;

  assert property (@(posedge clk_i) disable iff (!rst_ni) !$isunknown(sda_bus_i))
  else $error("tb_pad_model_sva: SDA bus must not resolve to X/Z");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   if_dut_sda_oe_i === dut_sda_oe_i)
  else $error("tb_pad_model_sva: i3c_if dut_sda_oe mirror mismatch");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   if_dut_sda_o_i === dut_sda_o_i)
  else $error("tb_pad_model_sva: i3c_if dut_sda_o mirror mismatch");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   if_dut_sel_od_pp_i === dut_sel_od_pp_i)
  else $error("tb_pad_model_sva: i3c_if dut_sel_od_pp mirror mismatch");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   dut_sda_oe_i && !dut_sda_o_i |-> sda_bus_i === 1'b0)
  else $error("tb_pad_model_sva: DUT SDA low drive must pull bus low");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   dut_sda_oe_i && dut_sda_o_i |-> sda_bus_i === 1'b1)
  else $error("tb_pad_model_sva: DUT SDA high drive must drive bus high");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   dut_sda_oe_i && dut_sda_o_i |-> dut_sel_od_pp_i)
  else $error("tb_pad_model_sva: DUT must only drive SDA high in push-pull mode");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !dut_sda_oe_i && device_released |-> sda_bus_i === 1'b1)
  else $error("tb_pad_model_sva: released SDA must return high through the pull-up");

endmodule
