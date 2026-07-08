module entdaa_controller_sva
  import controller_pkg::dat_entry_t;
  import i3c_pkg::is_i3c_rsvd_addr;
#(
    parameter int unsigned DatDepth = 32,
    localparam int unsigned DatAw = $clog2(DatDepth)
) (
    input logic clk_i,
    input logic rst_ni,

    input logic [2:0] state_q,
    input logic [3:0] dev_round_q,
    input logic [6:0] daa_addr_q,
    input logic [3:0] dev_count_i,
    input logic bus_stop_det_i,

    input logic invalid_addr_o,
    input logic req_rstart_o,

    input logic dat_read_valid_o,
    input logic [DatAw-1:0] dat_index_o,
    input logic [31:0] dat_rdata_i,
    input logic [5:0] dat_sum,

    input logic done_daa,
    input logic addr_valid,
    input logic no_device,
    input logic stopped,
    input logic [47:0] pid,
    input logic [7:0] bcr,
    input logic [7:0] dcr,

    input logic [6:0] daa_address_o,
    input logic daa_address_valid_o,
    input logic [47:0] daa_pid_o,
    input logic [7:0] daa_bcr_o,
    input logic [7:0] daa_dcr_o
);

  localparam logic [2:0] StartLoop = 3'd1;
  localparam logic [2:0] RequestRStart = 3'd2;
  localparam logic [2:0] WaitRStart = 3'd3;
  localparam logic [2:0] ReadDAT = 3'd4;
  localparam logic [2:0] RunEntdaa = 3'd5;
  localparam logic [2:0] Done = 3'd6;

  function automatic logic [6:0] sva_dat_dynamic_addr(input logic [31:0] dat_word);
    dat_entry_t entry;

    entry = dat_entry_t'(dat_word);
    return entry.dynamic_address;
  endfunction

  function automatic logic [DatAw-1:0] expected_dat_index(input logic [5:0] sum);
    if (sum >= DatDepth) begin
      expected_dat_index = DatAw'(DatDepth - 1);
    end else begin
      expected_dat_index = sum[DatAw-1:0];
    end
  endfunction

  function automatic logic dat_dynamic_addr_is_reserved(input logic [31:0] dat_word);
    return is_i3c_rsvd_addr(sva_dat_dynamic_addr(dat_word));
  endfunction

  ap_entdaa_start_reads_dat: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == StartLoop && dev_round_q < dev_count_i && !bus_stop_det_i)
    |->
    (dat_read_valid_o &&
     dat_index_o == expected_dat_index(dat_sum))
  );

  cp_entdaa_start_reads_dat: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == StartLoop &&
     dev_round_q < dev_count_i &&
     !bus_stop_det_i &&
     dat_read_valid_o &&
     dat_index_o == expected_dat_index(dat_sum))
  );

  ap_entdaa_valid_dat_requests_rstart: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadDAT && !bus_stop_det_i && !dat_dynamic_addr_is_reserved(dat_rdata_i))
    |=> (state_q == RequestRStart && req_rstart_o)
  );

  cp_entdaa_valid_dat_requests_rstart: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadDAT && !bus_stop_det_i && !dat_dynamic_addr_is_reserved(dat_rdata_i))
    ##1 (state_q == RequestRStart && req_rstart_o)
  );

  ap_entdaa_reserved_dat_rejects_before_rstart: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadDAT && !bus_stop_det_i && dat_dynamic_addr_is_reserved(dat_rdata_i))
    |->
    (!req_rstart_o)
    ##1 (state_q == Done && invalid_addr_o)
  );

  cp_entdaa_reserved_dat_rejects_before_rstart: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadDAT && !bus_stop_det_i && dat_dynamic_addr_is_reserved(dat_rdata_i) &&
     !req_rstart_o)
    ##1 (state_q == Done && invalid_addr_o)
  );

  ap_entdaa_read_dat_latches_dynamic_addr: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadDAT && !bus_stop_det_i)
    |=> (daa_addr_q == sva_dat_dynamic_addr($past(dat_rdata_i)))
  );

  cp_entdaa_read_dat_latches_dynamic_addr: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == ReadDAT && !bus_stop_det_i)
    ##1 (daa_addr_q == sva_dat_dynamic_addr($past(dat_rdata_i)))
  );

  ap_entdaa_success_outputs_assignment: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == RunEntdaa && done_daa && addr_valid)
    |->
    (daa_address_valid_o &&
     daa_address_o == daa_addr_q &&
     daa_pid_o == pid &&
     daa_bcr_o == bcr &&
     daa_dcr_o == dcr)
  );

  cp_entdaa_success_outputs_assignment: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == RunEntdaa && done_daa && addr_valid &&
     daa_address_valid_o &&
     daa_address_o == daa_addr_q &&
     daa_pid_o == pid &&
     daa_bcr_o == bcr &&
     daa_dcr_o == dcr)
  );

  ap_entdaa_success_advances_round: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == RunEntdaa && done_daa && addr_valid && !stopped && !bus_stop_det_i)
    |=> (state_q == StartLoop && dev_round_q == $past(dev_round_q) + 1'b1)
  );

  cp_entdaa_success_advances_round: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == RunEntdaa && done_daa && addr_valid && !stopped && !bus_stop_det_i)
    ##1 (state_q == StartLoop && dev_round_q == $past(dev_round_q) + 1'b1)
  );

  ap_entdaa_stopped_assignment_exits_after_commit: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == RunEntdaa && done_daa && addr_valid && stopped)
    |=> (state_q == Done && dev_round_q == $past(dev_round_q) + 1'b1)
  );

  cp_entdaa_stopped_assignment_exits_after_commit: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == RunEntdaa && done_daa && addr_valid && stopped)
    ##1 (state_q == Done && dev_round_q == $past(dev_round_q) + 1'b1)
  );

  ap_entdaa_no_device_no_assignment_result: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == RunEntdaa && done_daa && no_device && !addr_valid)
    |-> (!daa_address_valid_o)
  );

  cp_entdaa_no_device_no_assignment_result: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == RunEntdaa && done_daa && no_device && !addr_valid && !daa_address_valid_o)
  );

  ap_entdaa_controller_no_device_exits: assert property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == RunEntdaa && done_daa && no_device && !addr_valid)
    |=> (state_q == Done)
  );

  cp_entdaa_controller_no_device_exits: cover property (
    @(posedge clk_i) disable iff (!rst_ni)
    (state_q == RunEntdaa && done_daa && no_device && !addr_valid)
    ##1 (state_q == Done)
  );

endmodule

bind entdaa_controller entdaa_controller_sva #(
    .DatDepth(DatDepth)
) u_entdaa_controller_sva (
    .clk_i,
    .rst_ni,
    .state_q,
    .dev_round_q,
    .daa_addr_q,
    .dev_count_i,
    .bus_stop_det_i,
    .invalid_addr_o,
    .req_rstart_o,
    .dat_read_valid_o,
    .dat_index_o,
    .dat_rdata_i,
    .dat_sum,
    .done_daa,
    .addr_valid,
    .no_device,
    .stopped,
    .pid,
    .bcr,
    .dcr,
    .daa_address_o,
    .daa_address_valid_o,
    .daa_pid_o,
    .daa_bcr_o,
    .daa_dcr_o
);
