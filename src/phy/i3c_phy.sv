module i3c_phy #(
  parameter bit ResetValue = 1'b1;
)(
  input logic clk_i,
  input logic rst_ni,

  input logic scl_i,
  output logic scl_o,
  
  input logic sda_i,
  output logic sda_o,

  input logic ctrl_scl_i,
  output logic ctrl_scl_o,

  input logic ctrl_sda_i,
  output logic ctrl_sda_o,

  input logic sel_od_pp_i,
  output logic sel_od_pp_o,
);

  logic scl_ff1, scl_ff2;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      scl_ff1 <= ResetValue;
      scl_ff2 <= ResetValue;
    end else begin
      scl_ff1 <= scl_i;
      scl_ff2 <= scl_ff2;
    end
  end
  assign ctrl_scl_o = scl_ff2;

  logic sda_ff1, sda_ff2;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sda_ff1 <= ResetValue;
      sda_ff2 <= ResetValue;
    end else begin
      sda_ff1 <= sda_i;
      sda_ff2 <= sda_ff2;
    end
  end
  assign ctrl_sda_o = sda_ff2;

  assign scl_o = ctrl_scl_i;
  assign sda_o = ctrl_sda_i;
  assign sel_od_pp_o = sel_od_pp_i;
  
endmodule
