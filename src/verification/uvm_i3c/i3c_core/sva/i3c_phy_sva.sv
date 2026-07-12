module i3c_phy_sva #(
    parameter bit ResetValue = 1'b1
) (
    input logic clk_i,
    input logic rst_ni,

    input logic scl_i,
    input logic ctrl_scl_o,
    input logic scl_ff1,
    input logic scl_ff2,

    input logic sda_i,
    input logic ctrl_sda_o,
    input logic sda_ff1,
    input logic sda_ff2
);

  logic [1:0] past_valid_q;
  logic       exp_scl_ff1_q;
  logic       exp_scl_ff2_q;
  logic       exp_sda_ff1_q;
  logic       exp_sda_ff2_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin : track_past_valid
    if (!rst_ni) past_valid_q <= 2'b00;
    else past_valid_q <= {past_valid_q[0], 1'b1};
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : track_expected_sync
    if (!rst_ni) begin
      exp_scl_ff1_q <= ResetValue;
      exp_scl_ff2_q <= ResetValue;
      exp_sda_ff1_q <= ResetValue;
      exp_sda_ff2_q <= ResetValue;
    end else begin
      exp_scl_ff1_q <= scl_i;
      exp_scl_ff2_q <= exp_scl_ff1_q;
      exp_sda_ff1_q <= sda_i;
      exp_sda_ff2_q <= exp_sda_ff1_q;
    end
  end

  ap_bus001_reset_sets_sync_idle:
  assert property (@(posedge clk_i)
                   !rst_ni |-> ((scl_ff1 === ResetValue) &&
                                (scl_ff2 === ResetValue) &&
                                (ctrl_scl_o === ResetValue) &&
                                (sda_ff1 === ResetValue) &&
                                (sda_ff2 === ResetValue) &&
                                (ctrl_sda_o === ResetValue)))
  else $error("i3c_phy_sva: BUS_001 reset did not set synchronized bus inputs to idle");

  cp_bus001_reset_sets_sync_idle:
  cover property (@(posedge clk_i)
                  !rst_ni && (scl_ff1 === ResetValue) && (scl_ff2 === ResetValue) &&
                  (ctrl_scl_o === ResetValue) && (sda_ff1 === ResetValue) &&
                  (sda_ff2 === ResetValue) && (ctrl_sda_o === ResetValue));

  ap_bus001_scl_ff1_matches_shadow:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q[0])
                   scl_ff1 === exp_scl_ff1_q)
  else $error("i3c_phy_sva: BUS_001 SCL first synchronizer flop does not match shadow model");

  ap_bus001_scl_two_cycle_settle:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q[0])
                   ctrl_scl_o === exp_scl_ff2_q)
  else $error("i3c_phy_sva: BUS_001 SCL synchronized output does not match 2FF shadow model");

  ap_bus001_sda_ff1_matches_shadow:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q[0])
                   sda_ff1 === exp_sda_ff1_q)
  else $error("i3c_phy_sva: BUS_001 SDA first synchronizer flop does not match shadow model");

  ap_bus001_sda_two_cycle_settle:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q[0])
                   ctrl_sda_o === exp_sda_ff2_q)
  else $error("i3c_phy_sva: BUS_001 SDA synchronized output does not match 2FF shadow model");

  // No equality-only covers for the shadow-model invariants: stable idle inputs
  // satisfy them immediately. The four input-pattern covers below demonstrate
  // that the synchronizer exercised every SCL/SDA value combination.

  cp_bus001_sync_pattern_00:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !(&past_valid_q))
                  ({exp_scl_ff2_q, exp_sda_ff2_q} === 2'b00) &&
                  ({ctrl_scl_o, ctrl_sda_o} === 2'b00));

  cp_bus001_sync_pattern_10:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !(&past_valid_q))
                  ({exp_scl_ff2_q, exp_sda_ff2_q} === 2'b10) &&
                  ({ctrl_scl_o, ctrl_sda_o} === 2'b10));

  cp_bus001_sync_pattern_01:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !(&past_valid_q))
                  ({exp_scl_ff2_q, exp_sda_ff2_q} === 2'b01) &&
                  ({ctrl_scl_o, ctrl_sda_o} === 2'b01));

  cp_bus001_sync_pattern_11:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !(&past_valid_q))
                  ({exp_scl_ff2_q, exp_sda_ff2_q} === 2'b11) &&
                  ({ctrl_scl_o, ctrl_sda_o} === 2'b11));

endmodule

bind i3c_phy i3c_phy_sva #(
    .ResetValue(ResetValue)
) u_i3c_phy_sva (
    .clk_i,
    .rst_ni,
    .scl_i,
    .ctrl_scl_o,
    .scl_ff1,
    .scl_ff2,
    .sda_i,
    .ctrl_sda_o,
    .sda_ff1,
    .sda_ff2
);
