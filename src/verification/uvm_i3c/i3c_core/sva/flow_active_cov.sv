module flow_active_cov (
  input logic clk_i,
  input logic rst_ni,
  input logic [3:0] state_q
);

  // Multi-hop transition bins require consecutive samples to be consecutive
  // distinct states. The FSM dwells many cycles per state, so sampling every
  // clock makes any path longer than two hops impossible to hit. Sample only
  // on the cycle a new state is entered to collapse the dwell.
  logic [3:0] state_prev;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) state_prev <= 4'd0;
    else         state_prev <= state_q;
  end
  wire state_changed = (state_q != state_prev);

  covergroup cg_flow_fsm @(posedge clk_i iff state_changed);
    option.per_instance = 1;
    cp_state: coverpoint state_q {
      bins IDLE             = {4'd0};
      bins WAIT_FOR_CMD     = {4'd1};
      bins FETCH_DAT        = {4'd2};
      bins WAIT_DAT         = {4'd3};
      bins I3C_BCAST_HEADER = {4'd4};
      bins ISSUE_IMM_CCC    = {4'd5};
      bins FETCH_TX_DATA    = {4'd6};
      bins INIT_I3C_WRITE   = {4'd7};
      bins INIT_I3C_READ    = {4'd8};
      bins INIT_I2C_WRITE   = {4'd9};
      bins INIT_I2C_READ    = {4'd10};
      bins ISSUE_CMD        = {4'd11};
      bins WRITE_RESP       = {4'd12};
    }

    // Representative end-to-end command paths and selected error shortcuts;
    // this is not an exhaustive arc model for the main FSM.
    cp_transitions: coverpoint state_q {
      bins sdr_write_path[]   = (4'd0 => 4'd1 => 4'd2 => 4'd3 => 4'd4 => 4'd7 => 4'd6 => 4'd11 => 4'd12);
      bins sdr_read_path[]    = (4'd0 => 4'd1 => 4'd2 => 4'd3 => 4'd4 => 4'd8 => 4'd11 => 4'd12);
      bins i2c_write_path[]   = (4'd0 => 4'd1 => 4'd2 => 4'd3 => 4'd9 => 4'd6 => 4'd11 => 4'd12);
      bins i2c_read_path[]    = (4'd0 => 4'd1 => 4'd2 => 4'd3 => 4'd10 => 4'd11 => 4'd12);
      bins imm_i3c_path[]     = (4'd0 => 4'd1 => 4'd2 => 4'd3 => 4'd4 => 4'd7 => 4'd11 => 4'd12);
      bins imm_i2c_path[]     = (4'd0 => 4'd1 => 4'd2 => 4'd3 => 4'd9 => 4'd11 => 4'd12);
      bins ccc_resp_path[]    = (4'd0 => 4'd1 => 4'd2 => 4'd3 => 4'd4 => 4'd5 => 4'd12);
      bins daa_path[]         = (4'd0 => 4'd1 => 4'd2 => 4'd3 => 4'd4 => 4'd11 => 4'd12);
      bins abort_from_issue[] = (4'd11 => 4'd12);
      bins bcast_nack_path[]  = (4'd4 => 4'd12);
    }
  endgroup

  cg_flow_fsm u_cg = new();

endmodule

bind flow_active flow_active_cov u_flow_active_cov (
  .clk_i  (clk_i),
  .rst_ni (rst_ni),
  .state_q(state_q)
);
