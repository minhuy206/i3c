module flow_active_sva
  import controller_pkg::cmd_transfer_dir_e;
  import controller_pkg::dat_entry_t;
  import controller_pkg::Write;
  import i3c_pkg::AddressAssignment;
  import i3c_pkg::i3c_cmd_attr_e;
  import i3c_pkg::ImmediateDataTransfer;
  import i3c_pkg::immediate_data_trans_desc_t;
#(
    parameter int HciCmdDataWidth = 64,
    parameter int HciTxDataWidth = 32,
    parameter int HciRxDataWidth = 32,
    parameter int HciRespDataWidth = 32,
    parameter int DatDepth = 16
) (
    input logic                       clk_i,
    input logic                       rst_ni,
    input logic                 [3:0] state_q,
    input logic                       sel_od_pp_o,
    input logic                 [7:0] issue_phase_q,
    input i3c_cmd_attr_e              cmd_attr,
    input cmd_transfer_dir_e          cmd_dir,
    input immediate_data_trans_desc_t imm_desc,
    input dat_entry_t                 dat_entry,
    input logic                [15:0] remaining_len_q,
    input logic                       short_read_q,
    input logic                       addr_after_rstart_q,
    input logic                       gen_start_o,
    input logic                       gen_rstart_o,
    input logic                       gen_stop_o
);

  localparam logic [3:0] Idle = 4'd0;
  localparam logic [3:0] WaitForCmd = 4'd1;
  localparam logic [3:0] FetchDAT = 4'd2;
  localparam logic [3:0] WaitDAT = 4'd3;
  localparam logic [3:0] I3CWriteImmediate = 4'd4;
  localparam logic [3:0] I2CWriteImmediate = 4'd5;
  localparam logic [3:0] FetchTxData = 4'd6;
  localparam logic [3:0] FetchRxData = 4'd7;
  localparam logic [3:0] InitI2CWrite = 4'd8;
  localparam logic [3:0] InitI2CRead = 4'd9;
  localparam logic [3:0] StallWrite = 4'd10;
  localparam logic [3:0] StallRead = 4'd11;
  localparam logic [3:0] IssueCmd = 4'd12;
  localparam logic [3:0] WriteResp = 4'd13;

  localparam logic [7:0] PhaseStart = 8'd0;
  localparam logic [7:0] PhaseAddr = 8'd1;
  localparam logic [7:0] PhaseAddrAck = 8'd2;
  localparam logic [7:0] PhaseDataStart = 8'd3;

  function automatic logic phase_in_data_pairs(input logic [7:0] phase,
                                               input logic [7:0] first_phase,
                                               input logic [2:0] byte_count);
    logic [7:0] phase_offset;

    phase_in_data_pairs = 1'b0;
    if (phase >= first_phase) begin
      phase_offset = phase - first_phase;
      phase_in_data_pairs = ((phase_offset >> 1) < {5'h00, byte_count});
    end
  endfunction

  function automatic logic bcast_has_event_byte(input immediate_data_trans_desc_t desc);
    logic bcast_enec_disec;

    bcast_enec_disec = desc.cp && !desc.cmd[7] && ((desc.cmd == 8'h00) || (desc.cmd == 8'h01));
    bcast_has_event_byte = bcast_enec_disec || (desc.dtt >= 3'd5);
  endfunction

  function automatic logic expected_imm_sel_od_pp(input immediate_data_trans_desc_t desc,
                                                  input logic [7:0] phase);
    expected_imm_sel_od_pp = 1'b0;

    if (!desc.cp) begin
      expected_imm_sel_od_pp = phase_in_data_pairs(phase, PhaseDataStart, desc.dtt);
    end else if (desc.cmd[7]) begin
      expected_imm_sel_od_pp = (phase == 8'd3) || (phase == 8'd4) ||
                               (phase == 8'd6) || (phase == 8'd8) ||
                               (phase == 8'd9);
    end else begin
      expected_imm_sel_od_pp = (phase == 8'd3) || (phase == 8'd4) ||
                               (bcast_has_event_byte(desc) &&
                                ((phase == 8'd5) || (phase == 8'd6)));
    end
  endfunction

  function automatic logic expected_regular_sel_od_pp(input i3c_cmd_attr_e attr,
                                                      input cmd_transfer_dir_e dir,
                                                      input dat_entry_t dat,
                                                      input logic [7:0] phase,
                                                      input logic [15:0] remaining_len,
                                                      input logic short_read,
                                                      input logic addr_after_rstart);
    expected_regular_sel_od_pp = 1'b0;

    if (attr == AddressAssignment || dat.device) begin
      expected_regular_sel_od_pp = 1'b0;
    end else if (phase == PhaseAddr) begin
      expected_regular_sel_od_pp = addr_after_rstart;
    end else if (phase > PhaseAddrAck) begin
      if (dir == Write) begin
        expected_regular_sel_od_pp = (remaining_len > 16'h0);
      end else begin
        expected_regular_sel_od_pp = !short_read && (remaining_len > 16'h0);
      end
    end
  endfunction

  function automatic logic expected_sel_od_pp(input logic [3:0] state,
                                              input i3c_cmd_attr_e attr,
                                              input cmd_transfer_dir_e dir,
                                              input immediate_data_trans_desc_t desc,
                                              input dat_entry_t dat,
                                              input logic [7:0] phase,
                                              input logic [15:0] remaining_len,
                                              input logic short_read,
                                              input logic addr_after_rstart,
                                              input logic gen_start,
                                              input logic gen_rstart,
                                              input logic gen_stop);
    expected_sel_od_pp = 1'b0;

    if (gen_start || gen_rstart || gen_stop) begin
      expected_sel_od_pp = 1'b0;
    end else begin
      unique case (state)
        I3CWriteImmediate: begin
          expected_sel_od_pp = expected_imm_sel_od_pp(desc, phase);
        end

        IssueCmd: begin
          expected_sel_od_pp = expected_regular_sel_od_pp(
              attr, dir, dat, phase, remaining_len, short_read, addr_after_rstart);
        end

        default: begin
          expected_sel_od_pp = 1'b0;
        end
      endcase
    end
  endfunction

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   sel_od_pp_o === expected_sel_od_pp(
                       state_q,
                       cmd_attr,
                       cmd_dir,
                       imm_desc,
                       dat_entry,
                       issue_phase_q,
                       remaining_len_q,
                       short_read_q,
                       addr_after_rstart_q,
                       gen_start_o,
                       gen_rstart_o,
                       gen_stop_o))
  else $error("flow_active_sva: sel_od_pp_o mismatch in %m");

endmodule
