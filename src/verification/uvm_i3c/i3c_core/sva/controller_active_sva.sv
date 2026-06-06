module controller_active_mux_sva (
    input logic clk_i,
    input logic rst_ni,

    input logic ctrl_scl_o,
    input logic ctrl_sda_o,
    input logic ctrl_sda_oe_o,
    input logic sel_od_pp_o,

    input logic scl_gen_scl,
    input logic scl_gen_sda,
    input logic scl_gen_driving_sda,

    input logic tx_flow_sda_drive,
    input logic tx_flow_sda,
    input logic tx_flow_sel_od_pp,

    input logic flow_use_i2c_timing,
    input logic daa_active,
    input logic flow_scl_use_od_low,
    input logic active_scl_use_od_low
);

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   ctrl_scl_o === scl_gen_scl)
  else $error("controller_active_mux_sva: ctrl_scl_o must come from scl_generator in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   scl_gen_driving_sda |-> (ctrl_sda_o === scl_gen_sda))
  else $error("controller_active_mux_sva: scl_generator-owned SDA value mismatch in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   scl_gen_driving_sda |-> (ctrl_sda_oe_o === ~scl_gen_sda))
  else $error("controller_active_mux_sva: scl_generator-owned SDA OE mismatch in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   scl_gen_driving_sda |-> (sel_od_pp_o === 1'b0))
  else $error("controller_active_mux_sva: scl_generator-owned phases must force OD in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!scl_gen_driving_sda && tx_flow_sda_drive) |-> (ctrl_sda_o === tx_flow_sda))
  else $error("controller_active_mux_sva: tx-flow SDA value mismatch in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!scl_gen_driving_sda && tx_flow_sda_drive)
                   |-> (ctrl_sda_oe_o === (tx_flow_sel_od_pp | ~tx_flow_sda)))
  else $error("controller_active_mux_sva: tx-flow SDA OE mismatch in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!scl_gen_driving_sda && !tx_flow_sda_drive)
                   |-> ((ctrl_sda_o === 1'b1) && (ctrl_sda_oe_o === 1'b0)))
  else $error("controller_active_mux_sva: inactive tx-flow must release SDA in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !scl_gen_driving_sda |-> (sel_od_pp_o === tx_flow_sel_od_pp))
  else $error("controller_active_mux_sva: final OD/PP must follow tx-flow outside bus events in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   flow_use_i2c_timing |-> !active_scl_use_od_low)
  else $error("controller_active_mux_sva: I2C timing must not select I3C OD low timing in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!flow_use_i2c_timing && daa_active) |-> active_scl_use_od_low)
  else $error("controller_active_mux_sva: ENTDAA must select I3C OD low timing in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!flow_use_i2c_timing && !daa_active)
                   |-> (active_scl_use_od_low === flow_scl_use_od_low))
  else $error("controller_active_mux_sva: SCL OD-low mode must follow flow_active outside ENTDAA in %m");

endmodule
