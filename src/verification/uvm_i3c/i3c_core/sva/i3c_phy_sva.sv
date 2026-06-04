module i3c_phy_sva #(
    parameter bit ResetValue = 1'b1
) (
    input logic clk_i,
    input logic rst_ni,

    input logic scl_i,
    input logic scl_o,
    input logic sda_i,
    input logic sda_o,

    input logic ctrl_scl_i,
    input logic ctrl_scl_o,
    input logic ctrl_sda_i,
    input logic ctrl_sda_oe_i,
    input logic ctrl_sda_o,

    input logic sel_od_pp_i,
    input logic sda_oe_o,
    input logic sel_od_pp_o
);

  logic [1:0] sync_history_valid_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sync_history_valid_q <= 2'b00;
    end else begin
      sync_history_valid_q <= {sync_history_valid_q[0], 1'b1};
    end
  end

  assert property (@(posedge clk_i) !rst_ni |-> (ctrl_scl_o === ResetValue))
  else $error("i3c_phy_sva: ctrl_scl_o must reset to ResetValue");

  assert property (@(posedge clk_i) !rst_ni |-> (ctrl_sda_o === ResetValue))
  else $error("i3c_phy_sva: ctrl_sda_o must reset to ResetValue");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   sync_history_valid_q[1] |-> (ctrl_scl_o === $past(scl_i, 2)))
  else $error("i3c_phy_sva: ctrl_scl_o must equal scl_i delayed by 2 clocks");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   sync_history_valid_q[1] |-> (ctrl_sda_o === $past(sda_i, 2)))
  else $error("i3c_phy_sva: ctrl_sda_o must equal sda_i delayed by 2 clocks");

  assert property (@(posedge clk_i) scl_o === ctrl_scl_i)
  else $error("i3c_phy_sva: scl_o must pass through ctrl_scl_i");

  assert property (@(posedge clk_i) sda_o === ctrl_sda_i)
  else $error("i3c_phy_sva: sda_o must pass through ctrl_sda_i");

  assert property (@(posedge clk_i) sda_oe_o === ctrl_sda_oe_i)
  else $error("i3c_phy_sva: sda_oe_o must pass through ctrl_sda_oe_i");

  assert property (@(posedge clk_i) sel_od_pp_o === sel_od_pp_i)
  else $error("i3c_phy_sva: sel_od_pp_o must pass through sel_od_pp_i");

endmodule
