module flow_active_sva
  import controller_pkg::*;
  import i3c_pkg::AddressAssignment;
  import i3c_pkg::addr_assign_desc_t;
  import i3c_pkg::AddrHeader;
  import i3c_pkg::i3c_ccc_e;
  import i3c_pkg::ENEC;
  import i3c_pkg::DISEC;
  import i3c_pkg::ENTDAA;
  import i3c_pkg::DIR_ENEC;
  import i3c_pkg::DIR_DISEC;
  import i3c_pkg::HcAborted;
  import i3c_pkg::I3C_RSVD_ADDR;
  import i3c_pkg::I3cShortReadErr;
  import i3c_pkg::I2cDataNackOrI3cBusAborted;
  import i3c_pkg::Nack;
  import i3c_pkg::NotSupported;
  import i3c_pkg::Ovl;
  import i3c_pkg::Success;
  import i3c_pkg::i3c_cmd_attr_e;
  import i3c_pkg::ImmediateDataTransfer;
  import i3c_pkg::immediate_data_trans_desc_t;
  import i3c_pkg::regular_trans_desc_t;
  import i3c_pkg::RegularTransfer;
  import i3c_pkg::sdr0;
#(
    parameter int HciCmdDataWidth = 64,
    parameter int HciTxDataWidth = 32,
    parameter int HciRxDataWidth = 32,
    parameter int HciRespDataWidth = 32,
    parameter int DatDepth = 16,
    parameter int unsigned DatAw = $clog2(DatDepth)
) (
    input logic                                              clk_i,
    input logic                                              rst_ni,
    input logic                       [                 3:0] state_q,
    input logic                       [                 3:0] state_d,
    input logic                                              sel_od_pp_o,
    input logic                                              sel_i3c_i2c_o,
    input logic                                              use_i2c_timing_o,
    input logic                                              scl_use_od_low_o,
    input logic                       [                 7:0] issue_phase_q,
    input i3c_cmd_attr_e                                     cmd_attr,
    input cmd_transfer_dir_e                                 cmd_dir,
    input immediate_data_trans_desc_t                        imm_desc,
    input regular_trans_desc_t                               reg_desc,
    input addr_assign_desc_t                                 aa_desc,
    input dat_entry_t                                        dat_entry,
    input logic                                              dat_read_valid_hw_o,
    input logic                       [            DatAw-1:0] dat_index_hw_o,
    input logic                       [                15:0] remaining_len_q,
    input logic                       [                15:0] resp_data_len_q,
    input logic                                              short_read_q,
    input logic                                              short_read_error,
    input logic                                              addr_nack_q,
    input logic                                              data_nack_q,
    input logic                                              daa_nack_error_q,
    input logic                                              daa_invalid_addr_i,
    input logic                                              not_supported_q,
    input logic                                              addr_after_rstart_q,
    input logic                                              next_start_is_rstart_q,
    input logic                                              cont_pending_q,
    input logic                                              active_wroc,
    input logic                                              completion_error_q,
    input logic                                              broadcast_header_enable_i,
    input logic                       [                 3:0] cmd_tid,
    input logic                                              gen_start_o,
    input logic                                              gen_rstart_o,
    input logic                                              gen_stop_o,
    input logic                                              tx_queue_empty_i,
    input logic                                              tx_queue_rvalid_i,
    input logic                                              tx_queue_rready_o,
    input logic                                              tx_underflow_q,
    input logic                                              rx_overflow_q,
    input logic                                              daa_wr_busy_q,
    input logic                                              entdaa_stop_req_q,
    input logic                                              read_takeover_pending_q,
    input logic                                              rx_queue_full_i,
    input logic                                              rx_queue_wvalid,
    input logic                                              rx_queue_wready_i,
    input logic                       [  HciRxDataWidth-1:0] rx_queue_wdata,
    input logic                                              resp_queue_wready_i,
    input logic                                              cmd_queue_rready_o,
    input logic                                              bus_tx_idle_i,
    input logic                                              bus_rx_idle_i,
    input logic                                              next_cmd_available,
    input logic                                              next_cmd_supported,
    input logic                                              bus_tx_req_byte,
    input logic                                              bus_tx_req_bit,
    input logic                                              bus_rx_req_byte,
    input logic                                              bus_rx_req_bit,
    input logic                                              bus_rx_req_bit_handoff,
    input logic                       [                 7:0] bus_tx_req_value,
    input logic                       [                 7:0] current_tx_byte,
    input logic                       [                31:0] rx_dword_q,
    input logic                       [                 1:0] rx_byte_idx_q,
    input logic                                              bus_tx_done_i,
    input logic                                              bus_rx_done_i,
    input logic                       [                 7:0] bus_rx_data_i,
    input logic                                              scl_stop_done_q,
    input logic                                              hc_aborted_q,
    input logic                                              abort_i,
    input logic                                              read_abort_term_q,
    input logic                                              resp_queue_wvalid,
    input logic                       [HciRespDataWidth-1:0] resp_queue_wdata
);

  localparam logic [7:0] PhaseStart = 8'd0;
  localparam logic [7:0] PhaseAddr = 8'd1;
  localparam logic [7:0] PhaseAddrAck = 8'd2;
  localparam logic [7:0] PhaseDataStart = 8'd3;
  localparam int unsigned AddrNackRespTimeoutCycles = 256;


  function automatic logic phase_in_data_pairs(
      input logic [7:0] phase, input logic [7:0] first_phase, input logic [2:0] byte_count);
    logic [7:0] phase_offset;

    phase_in_data_pairs = 1'b0;
    if (phase >= first_phase) begin
      phase_offset = phase - first_phase;
      phase_in_data_pairs = ((phase_offset >> 1) < {5'h00, byte_count});
    end
  endfunction

  function automatic logic bcast_has_event_byte(input immediate_data_trans_desc_t desc);
    logic bcast_enec_disec;

    bcast_enec_disec = desc.cp && !desc.cmd[7] && ((desc.cmd == 8'(ENEC)) || (desc.cmd == 8'(DISEC)));
    bcast_has_event_byte = bcast_enec_disec || (desc.dtt >= 3'd5);
  endfunction

  function automatic logic ccc_broadcast_disec_active();
    return cmd_attr == ImmediateDataTransfer &&
           imm_desc.cp &&
           !imm_desc.cmd[7] &&
           imm_desc.cmd == 8'(DISEC) &&
           imm_desc.toc &&
           !addr_nack_q &&
           !data_nack_q &&
           !hc_aborted_q;
  endfunction

  function automatic logic ccc_broadcast_enec_active();
    return cmd_attr == ImmediateDataTransfer &&
           imm_desc.cp &&
           !imm_desc.cmd[7] &&
           imm_desc.cmd == 8'(ENEC) &&
           imm_desc.toc &&
           !addr_nack_q &&
           !data_nack_q &&
           !hc_aborted_q;
  endfunction

  function automatic logic ccc_direct_enec_active();
    return cmd_attr == ImmediateDataTransfer &&
           imm_desc.cp &&
           imm_desc.cmd[7] &&
           imm_desc.cmd == 8'(DIR_ENEC) &&
           imm_desc.toc &&
           !addr_nack_q &&
           !data_nack_q &&
           !hc_aborted_q;
  endfunction

  function automatic logic ccc_direct_disec_active();
    return cmd_attr == ImmediateDataTransfer &&
           imm_desc.cp &&
           imm_desc.cmd[7] &&
           imm_desc.cmd == 8'(DIR_DISEC) &&
           imm_desc.toc &&
           !addr_nack_q &&
           !data_nack_q &&
           !hc_aborted_q;
  endfunction


  function automatic logic ccc_broadcast_supported_active();
    return ccc_broadcast_enec_active() || ccc_broadcast_disec_active();
  endfunction

  function automatic logic ccc_direct_supported_active();
    return ccc_direct_enec_active() || ccc_direct_disec_active();
  endfunction

  function automatic logic ccc_supported_active();
    return ccc_broadcast_supported_active() || ccc_direct_supported_active();
  endfunction

  function automatic logic ccc_broadcast_frame_matches();
    case (issue_phase_q)
      8'd3: return bus_tx_req_byte && !bus_tx_req_bit &&
                   (bus_tx_req_value === imm_desc.cmd);
      8'd4: return bus_tx_req_bit && !bus_tx_req_byte &&
                   (bus_tx_req_value === {7'b0, ~^imm_desc.cmd});
      8'd5: return bus_tx_req_byte && !bus_tx_req_bit &&
                   (bus_tx_req_value === imm_desc.def_or_data_byte1);
      8'd6: return bus_tx_req_bit && !bus_tx_req_byte &&
                   (bus_tx_req_value === {7'b0, ~^imm_desc.def_or_data_byte1});
      default: return 1'b1;
    endcase
  endfunction

  function automatic logic ccc_direct_frame_matches();
    case (issue_phase_q)
      8'd3: return bus_tx_req_byte && !bus_tx_req_bit &&
                   (bus_tx_req_value === imm_desc.cmd);
      8'd4: return bus_tx_req_bit && !bus_tx_req_byte &&
                   (bus_tx_req_value === {7'b0, ~^imm_desc.cmd});
      8'd5: return gen_rstart_o && !gen_start_o && !gen_stop_o;
      8'd6: return bus_tx_req_byte && !bus_tx_req_bit &&
                   (bus_tx_req_value === {dat_entry.dynamic_address, Write});
      8'd7: return bus_rx_req_bit_handoff && !bus_rx_req_bit &&
                   !bus_rx_req_byte && !bus_tx_req_byte && !bus_tx_req_bit;
      8'd8: return bus_tx_req_byte && !bus_tx_req_bit &&
                   (bus_tx_req_value === imm_desc.def_or_data_byte1);
      8'd9: return bus_tx_req_bit && !bus_tx_req_byte &&
                   (bus_tx_req_value === {7'b0, ~^imm_desc.def_or_data_byte1});
      8'd10: return gen_stop_o && !gen_start_o && !gen_rstart_o;
      default: return 1'b1;
    endcase
  endfunction

  function automatic logic expected_imm_sel_od_pp(input immediate_data_trans_desc_t desc,
                                                  input logic [7:0] phase,
                                                  input logic addr_after_rstart);
    expected_imm_sel_od_pp = 1'b0;

    if (!desc.cp) begin
      expected_imm_sel_od_pp =
          ((phase == PhaseAddr) && addr_after_rstart) ||
          phase_in_data_pairs(phase, PhaseDataStart, desc.dtt);
    end else if (desc.cmd[7]) begin
      expected_imm_sel_od_pp = (phase == 8'd3) || (phase == 8'd4) ||
                               (phase == 8'd6) || (phase == 8'd8) ||
                               (phase == 8'd9);
    end else begin
      expected_imm_sel_od_pp = (phase == 8'd3) || (phase == 8'd4) ||
          (bcast_has_event_byte(desc) && ((phase == 8'd5) || (phase == 8'd6)));
    end
  endfunction

  function automatic logic expected_regular_sel_od_pp(
      input i3c_cmd_attr_e attr, input cmd_transfer_dir_e dir, input dat_entry_t dat,
      input logic [7:0] phase, input logic [15:0] remaining_len, input logic short_read,
      input logic addr_after_rstart);
    expected_regular_sel_od_pp = 1'b0;

    if (attr == AddressAssignment) begin
      expected_regular_sel_od_pp = (phase == 8'd3) || (phase == 8'd4);
    end else if (dat.device) begin
      expected_regular_sel_od_pp = 1'b0;
    end else if (dir == Write) begin
      expected_regular_sel_od_pp = (remaining_len > 16'h0);
    end else begin
      expected_regular_sel_od_pp = !short_read && (remaining_len > 16'h0);
    end
  endfunction

  function automatic logic expected_sel_od_pp(
      input logic [3:0] state, input i3c_cmd_attr_e attr, input cmd_transfer_dir_e dir,
      input immediate_data_trans_desc_t desc, input dat_entry_t dat, input logic [7:0] phase,
      input logic [15:0] remaining_len, input logic short_read, input logic addr_after_rstart,
      input logic gen_start, input logic gen_rstart, input logic gen_stop);
    expected_sel_od_pp = 1'b0;

    if (gen_start || gen_rstart || gen_stop) begin
      expected_sel_od_pp = 1'b0;
    end else begin
      unique case (state)
        IssueImmediateCcc: begin
          expected_sel_od_pp = expected_imm_sel_od_pp(desc, phase, addr_after_rstart);
        end

        InitWrite: begin
          expected_sel_od_pp = !dat.device && (phase == PhaseAddr) && addr_after_rstart;
        end

        InitRead: begin
          expected_sel_od_pp = !dat.device && (phase == PhaseAddr) && addr_after_rstart;
        end

        IssueDAA, IssueI3CWrite, IssueI2CWrite, IssueI3CRead, IssueI2CRead: begin
          expected_sel_od_pp = expected_regular_sel_od_pp(attr, dir, dat, phase, remaining_len,
                                                          short_read, addr_after_rstart);
        end

        default: begin
          expected_sel_od_pp = 1'b0;
        end
      endcase
    end
  endfunction

  function automatic logic expected_scl_use_od_low(
      input logic [3:0] state, input i3c_cmd_attr_e attr, input cmd_transfer_dir_e dir,
      input immediate_data_trans_desc_t desc, input dat_entry_t dat, input logic [7:0] phase,
      input logic [15:0] remaining_len, input logic short_read, input logic addr_after_rstart,
      input logic gen_start, input logic gen_rstart, input logic gen_stop,
      input logic use_i2c_timing);
    logic expected_sel;

    expected_sel = expected_sel_od_pp(
        state,
        attr,
        dir,
        desc,
        dat,
        phase,
        remaining_len,
        short_read,
        addr_after_rstart,
        gen_start,
        gen_rstart,
        gen_stop
    );
    expected_scl_use_od_low = 1'b0;

    if (!use_i2c_timing) begin
      if (gen_start || gen_rstart || gen_stop) begin
        expected_scl_use_od_low = 1'b1;
      end else if (state == I3CBcastHeader) begin
        expected_scl_use_od_low = !expected_sel;
      end else if (state == IssueImmediateCcc) begin
        expected_scl_use_od_low = !expected_sel;
      end else if (state == InitWrite && !dat.device) begin
        expected_scl_use_od_low = !expected_sel;
      end else if (state == InitRead && !dat.device) begin
        expected_scl_use_od_low = !expected_sel;
      end else if ((state == IssueDAA) || (state == IssueI3CWrite) ||
                   (state == IssueI3CRead)) begin
        expected_scl_use_od_low = !expected_sel;
      end
    end
  endfunction

  function automatic logic sdr_regular_i3c_write();
    return (cmd_attr == RegularTransfer) && (cmd_dir == Write) && !dat_entry.device;
  endfunction

  function automatic logic sdr_regular_i3c_read();
    return (cmd_attr == RegularTransfer) && (cmd_dir == Read) && !dat_entry.device;
  endfunction

  function automatic logic i2c_regular_write();
    return (cmd_attr == RegularTransfer) && (cmd_dir == Write) && dat_entry.device;
  endfunction

  function automatic logic i2c_regular_read();
    return (cmd_attr == RegularTransfer) && (cmd_dir == Read) && dat_entry.device;
  endfunction

  function automatic logic i2c_regular_xfer();
    return i2c_regular_write() || i2c_regular_read();
  endfunction

  function automatic logic regular_fifo_write();
    return sdr_regular_i3c_write() || i2c_regular_write();
  endfunction

  function automatic logic regular_fifo_read();
    return sdr_regular_i3c_read() || i2c_regular_read();
  endfunction

  function automatic logic i3c_immediate_private_write();
    return (cmd_attr == ImmediateDataTransfer) && !imm_desc.cp && !dat_entry.device;
  endfunction

  function automatic logic i2c_immediate_write();
    return (cmd_attr == ImmediateDataTransfer) && !imm_desc.cp && dat_entry.device;
  endfunction

  function automatic logic imm_private_active_state();
    return (cmd_attr == ImmediateDataTransfer) &&
           !imm_desc.cp &&
           ((state_q == InitWrite) ||
            (state_q == IssueI3CWrite) ||
            (state_q == IssueI2CWrite));
  endfunction

  function automatic logic imm_active_state();
    return (cmd_attr == ImmediateDataTransfer) &&
           ((imm_desc.cp && (state_q == IssueImmediateCcc)) ||
            (!imm_desc.cp && imm_private_active_state()));
  endfunction

  function automatic logic direct_ccc_target_addr_nack();
    return (cmd_attr == ImmediateDataTransfer) &&
           imm_desc.cp &&
           imm_desc.cmd[7] &&
           ((imm_desc.cmd == 8'(DIR_ENEC)) || (imm_desc.cmd == 8'(DIR_DISEC))) &&
           issue_phase_q >= 8'd8;
  endfunction

  function automatic logic legal_imm_private_addr_rstart();
    return state_q == InitWrite &&
           i3c_immediate_private_write() &&
           issue_phase_q == PhaseStart &&
           next_start_is_rstart_q &&
           !addr_after_rstart_q;
  endfunction

  function automatic logic i2c_active_state();
    return (state_q == InitWrite) ||
           (state_q == InitRead) ||
           (state_q == FetchTxData) ||
           (state_q == IssueI2CWrite) ||
           (state_q == IssueI2CRead);
  endfunction

  function automatic logic [7:0] expected_imm_data_byte(
      input immediate_data_trans_desc_t desc, input logic [7:0] phase);
    logic [2:0] idx;
    idx = ((phase - PhaseDataStart) >> 1);  // matches select_imm_data_byte
    unique case (idx)
      3'd0: expected_imm_data_byte = desc.def_or_data_byte1;
      3'd1: expected_imm_data_byte = desc.data_byte2;
      3'd2: expected_imm_data_byte = desc.data_byte3;
      3'd3: expected_imm_data_byte = desc.data_byte4;
      default: expected_imm_data_byte = 8'h00;
    endcase
  endfunction

  function automatic logic [1:0] expected_next_rx_byte_idx(input logic [1:0] idx);
    expected_next_rx_byte_idx = (idx == 2'd3) ? 2'd0 : (idx + 2'd1);
  endfunction

  function automatic logic [1:0] expected_rx_byte_idx_after_tbit(
      input logic [1:0] idx, input logic [15:0] remaining_len, input logic target_end,
      input logic rx_ready, input logic rx_full);
    if (((remaining_len == 16'h1) || target_end) && rx_ready && !rx_full) begin
      expected_rx_byte_idx_after_tbit = 2'h0;
    end else begin
      expected_rx_byte_idx_after_tbit = expected_next_rx_byte_idx(idx);
    end
  endfunction

  function automatic logic [31:0] expected_rx_word_with_byte(
      input logic [31:0] word, input logic [1:0] idx, input logic [7:0] data);
    expected_rx_word_with_byte = word;
    case (idx)
      2'd0: expected_rx_word_with_byte[7:0] = data;
      2'd1: expected_rx_word_with_byte[15:8] = data;
      2'd2: expected_rx_word_with_byte[23:16] = data;
      2'd3: expected_rx_word_with_byte[31:24] = data;
      default: expected_rx_word_with_byte = word;
    endcase
  endfunction

  function automatic logic addr_nack_resp_matches();
    return resp_queue_wvalid &&
           (resp_queue_wdata[31:28] == AddrHeader) &&
           (resp_queue_wdata[27:24] == cmd_tid) &&
           (resp_queue_wdata[23:16] == 8'h00) &&
           (resp_queue_wdata[15:0] == 16'h0000);
  endfunction

  function automatic logic success_resp_matches_current_len();
    return resp_queue_wvalid &&
           (resp_queue_wdata[31:28] == Success) &&
           (resp_queue_wdata[27:24] == cmd_tid) &&
           (resp_queue_wdata[23:16] == 8'h00) &&
           (resp_queue_wdata[15:0] == resp_data_len_q);
  endfunction

  function automatic logic short_read_resp_matches_current_len();
    return resp_queue_wvalid &&
           (resp_queue_wdata[31:28] == I3cShortReadErr) &&
           (resp_queue_wdata[27:24] == cmd_tid) &&
           (resp_queue_wdata[23:16] == 8'h00) &&
           (resp_queue_wdata[15:0] == resp_data_len_q);
  endfunction

  function automatic logic data_nack_resp_matches_current_len();
    return resp_queue_wvalid &&
           (resp_queue_wdata[31:28] == I2cDataNackOrI3cBusAborted) &&
           (resp_queue_wdata[27:24] == cmd_tid) &&
           (resp_queue_wdata[23:16] == 8'h00) &&
           (resp_queue_wdata[15:0] == resp_data_len_q);
  endfunction

  function automatic logic hc_aborted_resp_matches_current_len();
    return resp_queue_wvalid &&
           (resp_queue_wdata[31:28] == HcAborted) &&
           (resp_queue_wdata[27:24] == cmd_tid) &&
           (resp_queue_wdata[23:16] == 8'h00) &&
           (resp_queue_wdata[15:0] == resp_data_len_q);
  endfunction

  function automatic logic ovl_resp_matches_current_len();
    return resp_queue_wvalid &&
           (resp_queue_wdata[31:28] == Ovl) &&
           (resp_queue_wdata[27:24] == cmd_tid) &&
           (resp_queue_wdata[23:16] == 8'h00) &&
           (resp_queue_wdata[15:0] == resp_data_len_q);
  endfunction

  function automatic logic not_supported_resp_matches_current_len();
    return resp_queue_wvalid &&
           (resp_queue_wdata[31:28] == NotSupported) &&
           (resp_queue_wdata[27:24] == cmd_tid) &&
           (resp_queue_wdata[23:16] == 8'h00) &&
           (resp_queue_wdata[15:0] == resp_data_len_q);
  endfunction

  function automatic logic invalid_addr_assign_desc();
    logic [5:0] dat_end;

    dat_end = {1'b0, aa_desc.dev_idx} + {2'b00, aa_desc.dev_count};
    return !aa_desc.toc || !aa_desc.wroc || (aa_desc.dev_count == 4'd0) ||
           (dat_end > DatDepth) || (aa_desc.cmd != 8'(ENTDAA));
  endfunction

  function automatic logic supported_immediate_ccc();
    return (imm_desc.cmd == 8'(ENEC))    || (imm_desc.cmd == 8'(DISEC)) ||
           (imm_desc.cmd == 8'(DIR_ENEC)) || (imm_desc.cmd == 8'(DIR_DISEC));
  endfunction

  function automatic logic invalid_cmd_desc();
    unique case (cmd_attr)
      RegularTransfer: begin
        return reg_desc.cp || (reg_desc.mode != sdr0);
      end
      ImmediateDataTransfer: begin
        return imm_desc.rnw || (imm_desc.mode != sdr0) || (imm_desc.dtt > 3'd4) ||
               (imm_desc.cp && !supported_immediate_ccc());
      end
      AddressAssignment: begin
        return invalid_addr_assign_desc();
      end
      default: begin
        return 1'b1;
      end
    endcase
  endfunction


  function automatic logic sdr_write_active_state();
    return (state_q == InitWrite) ||
           (state_q == FetchTxData) ||
           (state_q == IssueI3CWrite);
  endfunction

  function automatic logic sdr_write_done_ready();
    return state_q == IssueI3CWrite &&
           sdr_regular_i3c_write() &&
           !addr_nack_q &&
           (remaining_len_q == 16'h0) &&
           (issue_phase_q > PhaseAddrAck) &&
           bus_tx_idle_i &&
           bus_rx_idle_i;
  endfunction

  function automatic logic sdr_read_done_ready();
    return state_q == IssueI3CRead &&
           sdr_regular_i3c_read() &&
           !addr_nack_q &&
           !short_read_q &&
           !rx_overflow_q &&
           (remaining_len_q == 16'h0) &&
           (rx_byte_idx_q == 2'd0) &&
           (issue_phase_q > PhaseAddrAck) &&
           bus_tx_idle_i &&
           bus_rx_idle_i;
  endfunction

  function automatic logic higher_priority_error_present();
    return addr_nack_q || data_nack_q || daa_nack_error_q || rx_overflow_q ||
           tx_underflow_q || short_read_error || not_supported_q;
  endfunction

  function automatic logic [3:0] prioritized_error_status();
    if (addr_nack_q) begin
      return AddrHeader;
    end else if (data_nack_q) begin
      return I2cDataNackOrI3cBusAborted;
    end else if (daa_nack_error_q) begin
      return Nack;
    end else if (rx_overflow_q || tx_underflow_q) begin
      return Ovl;
    end else if (short_read_error) begin
      return I3cShortReadErr;
    end else begin
      return NotSupported;
    end
  endfunction

  ap_abort_idle_blocks_command :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitForCmd &&
                                            abort_i &&
                                            next_cmd_available
                                            |->
                                            !cmd_queue_rready_o && !gen_start_o)
  else $error("flow_active_sva: HC abort held at idle must block command acceptance in %m");

  cp_abort_idle_blocks_command :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitForCmd &&
                                            abort_i &&
                                            next_cmd_available &&
                                            !cmd_queue_rready_o && !gen_start_o);

  ap_abort_error_priority_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            hc_aborted_q &&
                                            higher_priority_error_present()
                                            |->
                                            resp_queue_wvalid &&
                                            (resp_queue_wdata[31:28] ==
                                             prioritized_error_status()) &&
                                            (resp_queue_wdata[27:24] == cmd_tid) &&
                                            (resp_queue_wdata[23:16] == 8'h00) &&
                                            (resp_queue_wdata[15:0] == resp_data_len_q))
  else $error("flow_active_sva: higher-priority error must override HcAborted response in %m");

  cp_abort_error_priority_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            hc_aborted_q &&
                                            higher_priority_error_present() &&
                                            resp_queue_wvalid &&
                                            (resp_queue_wdata[31:28] ==
                                             prioritized_error_status()) &&
                                            (resp_queue_wdata[27:24] == cmd_tid) &&
                                            (resp_queue_wdata[23:16] == 8'h00) &&
                                            (resp_queue_wdata[15:0] == resp_data_len_q));

  ap_hc_abort_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            hc_aborted_q &&
                                            !higher_priority_error_present()
                                            |->
                                            hc_aborted_resp_matches_current_len())
  else $error("flow_active_sva: HC-aborted response mismatch in %m");

  // The class-specific covers below provide activation for the generic
  // response assertion and preserve ERR-007 command-class closure.
  cp_regular_write_abort_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == RegularTransfer &&
                                            cmd_dir == Write &&
                                            hc_aborted_q &&
                                            !higher_priority_error_present() &&
                                            hc_aborted_resp_matches_current_len());

  cp_immediate_abort_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            hc_aborted_q &&
                                            !higher_priority_error_present() &&
                                            hc_aborted_resp_matches_current_len());

  cp_ccc_abort_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            imm_desc.cp &&
                                            hc_aborted_q &&
                                            !higher_priority_error_present() &&
                                            hc_aborted_resp_matches_current_len());

  cp_daa_abort_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == AddressAssignment &&
                                            hc_aborted_q &&
                                            !higher_priority_error_present() &&
                                            hc_aborted_resp_matches_current_len());

  // BUS_012: OD/PP phase rule. Existing SDRW/SDRR/I2C/CCC/ENTDAA vseqs create
  // the phases; this checker owns pass/fail, so no BUS_012-specific stimulus
  // sequence is required.
  ap_sel_od_pp_matches_expected :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
      !$changed(abort_i) |-> sel_od_pp_o === expected_sel_od_pp(
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
      gen_stop_o
  ))
  else
    $error(
        "flow_active_sva: sel_od_pp_o mismatch in %m state=%0d phase=0x%02h rem=%0d dir=%0b sel=%0b exp=%0b gen_start=%0b gen_rstart=%0b gen_stop=%0b",
        state_q, issue_phase_q, remaining_len_q, cmd_dir, sel_od_pp_o,
        expected_sel_od_pp(
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
            gen_stop_o
        ),
        gen_start_o, gen_rstart_o, gen_stop_o
    );

  ap_scl_use_od_low_matches_expected :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !$changed(abort_i) |->
                   scl_use_od_low_o === expected_scl_use_od_low(
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
      gen_stop_o,
      use_i2c_timing_o
  ))
  else
    $error(
        "flow_active_sva: scl_use_od_low_o mismatch in %m state=%0d phase=0x%02h rem=%0d dir=%0b scl_od=%0b exp=%0b gen_start=%0b gen_rstart=%0b gen_stop=%0b",
        state_q, issue_phase_q, remaining_len_q, cmd_dir, scl_use_od_low_o,
        expected_scl_use_od_low(
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
            gen_stop_o,
            use_i2c_timing_o
        ),
        gen_start_o, gen_rstart_o, gen_stop_o
    );

  // No matching covers for the two phase-selection invariants: equality is
  // already true during idle. Protocol-specific phase covers below exercise
  // the meaningful OD/PP and I2C timing scenarios.

  ap_sdr_write_tbit_parity :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                             state_q == IssueI3CWrite &&
                                             sdr_regular_i3c_write() &&
                                             remaining_len_q > 16'h0 &&
                                             issue_phase_q > PhaseAddrAck &&
                                             !issue_phase_q[0]
                                             |->
                                             bus_tx_req_bit &&
                                             !bus_tx_req_byte &&
                                             bus_tx_req_value === {7'b0, ~^current_tx_byte})
  else $error("flow_active_sva: SDR write T-bit parity mismatch in %m");

  cp_sdr_write_tbit_parity :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CWrite &&
                                            sdr_regular_i3c_write() &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            bus_tx_req_value === {7'b0, ~^current_tx_byte});

  cp_sdr_write_tbit_parity_one :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                                state_q == IssueI3CWrite &&
                                                sdr_regular_i3c_write() &&
                                                remaining_len_q > 16'h0 &&
                                                issue_phase_q > PhaseAddrAck &&
                                                !issue_phase_q[0] &&
                                                bus_tx_req_bit &&
                                                !bus_tx_req_byte &&
                                                bus_tx_req_value === 8'h01);

  cp_sdr_write_tbit_parity_zero :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                                 state_q == IssueI3CWrite &&
                                                 sdr_regular_i3c_write() &&
                                                 remaining_len_q > 16'h0 &&
                                                 issue_phase_q > PhaseAddrAck &&
                                                 !issue_phase_q[0] &&
                                                 bus_tx_req_bit &&
                                                 !bus_tx_req_byte &&
                                                 bus_tx_req_value === 8'h00);

  ap_regular_dat_read_uses_cmd_dev_idx :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchDAT &&
                                            cmd_attr == RegularTransfer &&
                                            dat_read_valid_hw_o
                                            |->
                                            dat_index_hw_o == reg_desc.dev_idx[DatAw-1:0])
  else $error("flow_active_sva: regular transfer DAT read index must match command dev_idx in %m");

  cp_sdr_write_dat0_read :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchDAT &&
                                            sdr_regular_i3c_write() &&
                                            dat_read_valid_hw_o &&
                                            reg_desc.dev_idx == 5'd0 &&
                                            dat_index_hw_o == reg_desc.dev_idx[DatAw-1:0]);

  cp_sdr_write_dat1_read :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchDAT &&
                                            sdr_regular_i3c_write() &&
                                            dat_read_valid_hw_o &&
                                            reg_desc.dev_idx == 5'd1 &&
                                            dat_index_hw_o == reg_desc.dev_idx[DatAw-1:0]);

  cp_sdr_read_dat0_read :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchDAT &&
                                            sdr_regular_i3c_read() &&
                                            dat_read_valid_hw_o &&
                                            reg_desc.dev_idx == 5'd0 &&
                                            dat_index_hw_o == reg_desc.dev_idx[DatAw-1:0]);

  cp_sdr_read_dat7_read :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchDAT &&
                                            sdr_regular_i3c_read() &&
                                            dat_read_valid_hw_o &&
                                            reg_desc.dev_idx == 5'd7 &&
                                            dat_index_hw_o == reg_desc.dev_idx[DatAw-1:0]);

  ap_sdr_write_addr_uses_dynamic_address :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitWrite &&
                                            sdr_regular_i3c_write() &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte
                                            |->
                                            bus_tx_req_value === {dat_entry.dynamic_address, Write})
  else $error("flow_active_sva: SDR write address byte must use selected DAT dynamic address in %m");

  cp_sdr_write_addr_uses_dynamic_address :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitWrite &&
                                            sdr_regular_i3c_write() &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte &&
                                            bus_tx_req_value === {dat_entry.dynamic_address, Write});

  ap_sdr_write_zero_len_no_data_phase :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            (state_q == InitWrite || state_q == IssueI3CWrite) &&
                                            sdr_regular_i3c_write() &&
                                            !addr_nack_q &&
                                            remaining_len_q == 16'h0 &&
                                            issue_phase_q > PhaseAddrAck
                                            |->
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit)
  else $error("flow_active_sva: zero-length SDR write must not request data or T-bit phase in %m");

  cp_sdr_write_zero_len_no_data_phase :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            (state_q == InitWrite || state_q == IssueI3CWrite) &&
                                            sdr_regular_i3c_write() &&
                                            !addr_nack_q &&
                                            remaining_len_q == 16'h0 &&
                                            resp_data_len_q == 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit);

  ap_fetch_tx_empty_latches_underflow :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            regular_fifo_write() &&
                                            tx_queue_empty_i &&
                                            !tx_underflow_q
                                            |=>
                                            tx_underflow_q)
  else $error("flow_active_sva: FetchTxData empty TX FIFO must latch underflow in %m");

  cp_fetch_tx_empty_latches_underflow :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            regular_fifo_write() &&
                                            tx_queue_empty_i &&
                                            !tx_underflow_q
                                            ##1
                                            tx_underflow_q);

  ap_fetch_tx_underflow_no_tx_pop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            regular_fifo_write() &&
                                            (tx_queue_empty_i || tx_underflow_q)
                                            |->
                                            !tx_queue_rready_o)
  else $error("flow_active_sva: TX underflow path must not pop TX FIFO in %m");

  cp_fetch_tx_underflow_no_tx_pop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            regular_fifo_write() &&
                                            (tx_queue_empty_i || tx_underflow_q) &&
                                            !tx_queue_rready_o);

  ap_fetch_tx_valid_enters_issue :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            regular_fifo_write() &&
                                            !tx_underflow_q &&
                                            !tx_queue_empty_i &&
                                            tx_queue_rvalid_i
                                            |=>
                                            (state_q == IssueI3CWrite || state_q == IssueI2CWrite))
  else $error("flow_active_sva: valid TX data in FetchTxData must enter IssueI3CWrite/IssueI2CWrite in %m");

  cp_fetch_tx_valid_enters_issue :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            regular_fifo_write() &&
                                            !tx_underflow_q &&
                                            !tx_queue_empty_i &&
                                            tx_queue_rvalid_i
                                            ##1
                                            (state_q == IssueI3CWrite || state_q == IssueI2CWrite));

  ap_tx_underflow_requests_stop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            regular_fifo_write() &&
                                            (tx_queue_empty_i || tx_underflow_q)
                                            |->
                                            gen_stop_o &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit)
  else $error("flow_active_sva: TX underflow path must request STOP without TX activity in %m");

  cp_tx_underflow_requests_stop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            regular_fifo_write() &&
                                            (tx_queue_empty_i || tx_underflow_q) &&
                                            gen_stop_o &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit);

  ap_tx_underflow_stop_to_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            regular_fifo_write() &&
                                            tx_underflow_q &&
                                            scl_stop_done_q
                                            |=>
                                            state_q == WriteResp)
  else $error("flow_active_sva: TX underflow must transition to WriteResp after STOP completes in %m");

  cp_tx_underflow_stop_to_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            regular_fifo_write() &&
                                            tx_underflow_q &&
                                            scl_stop_done_q
                                            ##1
                                            state_q == WriteResp);

  cp_i3c_tx_underflow_resp_ovl :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
                                            tx_underflow_q &&
                                            ovl_resp_matches_current_len());

  cp_i2c_tx_underflow_resp_ovl :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            i2c_regular_write() &&
                                            tx_underflow_q &&
                                            ovl_resp_matches_current_len());

  // ERR_007: a rejected RX commit latches overflow. Once latched, no more
  // read data or continuation command may be accepted; termination proceeds
  // through read takeover when required and then forces STOP.
  ap_rx_commit_reject_latches_overflow :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            (state_q == IssueI3CRead || state_q == IssueI2CRead) &&
                                            regular_fifo_read() &&
                                            !rx_overflow_q &&
                                            rx_queue_wvalid &&
                                            (!rx_queue_wready_i || rx_queue_full_i)
                                            |=>
                                            rx_overflow_q)
  else $error("flow_active_sva: rejected regular-read RX commit did not latch overflow in %m");

  cp_rx_commit_reject_latches_overflow :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            (state_q == IssueI3CRead || state_q == IssueI2CRead) &&
                                            regular_fifo_read() &&
                                            !rx_overflow_q &&
                                            rx_queue_wvalid &&
                                            (!rx_queue_wready_i || rx_queue_full_i)
                                            ##1
                                            rx_overflow_q);

  cp_rx_partial_dword_commit_overflow :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            (state_q == IssueI3CRead || state_q == IssueI2CRead) &&
                                            regular_fifo_read() &&
                                            rx_byte_idx_q != 2'd3 &&
                                            rx_queue_wvalid &&
                                            (!rx_queue_wready_i || rx_queue_full_i)
                                            ##1
                                            rx_overflow_q);

  ap_read_rx_overflow_blocks_data_and_continuation :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            (state_q == IssueI3CRead || state_q == IssueI2CRead) &&
                                            regular_fifo_read() &&
                                            rx_overflow_q
                                            |->
                                            !bus_rx_req_byte &&
                                            !bus_rx_req_bit &&
                                            !bus_rx_req_bit_handoff &&
                                            !cmd_queue_rready_o)
  else $error("flow_active_sva: RX overflow must block more read data and continuation in %m");

  cp_read_rx_overflow_blocks_data_and_continuation :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            (state_q == IssueI3CRead || state_q == IssueI2CRead) &&
                                            regular_fifo_read() &&
                                            rx_overflow_q &&
                                            !bus_rx_req_byte &&
                                            !bus_rx_req_bit &&
                                            !bus_rx_req_bit_handoff &&
                                            !cmd_queue_rready_o);

  ap_read_rx_overflow_requests_stop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            (state_q == IssueI3CRead || state_q == IssueI2CRead) &&
                                            regular_fifo_read() &&
                                            rx_overflow_q &&
                                            !read_takeover_pending_q &&
                                            bus_tx_idle_i &&
                                            bus_rx_idle_i
                                            |->
                                            gen_stop_o &&
                                            !cmd_queue_rready_o)
  else $error("flow_active_sva: RX overflow must force STOP after bus ownership is available in %m");

  cp_read_rx_overflow_requests_stop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            (state_q == IssueI3CRead || state_q == IssueI2CRead) &&
                                            regular_fifo_read() &&
                                            rx_overflow_q &&
                                            !read_takeover_pending_q &&
                                            bus_tx_idle_i &&
                                            bus_rx_idle_i &&
                                            gen_stop_o &&
                                            !cmd_queue_rready_o);

  ap_i2c_read_full_commit_boundary_nacks :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            rx_byte_idx_q == 2'd3 &&
                                            (!rx_queue_wready_i || rx_queue_full_i)
                                            |->
                                            bus_tx_req_bit &&
                                            bus_tx_req_value[0] == NACK)
  else $error("flow_active_sva: I2C RX overflow boundary must drive NACK in %m");

  cp_i2c_read_full_commit_boundary_nacks :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            rx_byte_idx_q == 2'd3 &&
                                            (!rx_queue_wready_i || rx_queue_full_i) &&
                                            bus_tx_req_bit &&
                                            bus_tx_req_value[0] == NACK);

  ap_entdaa_commit_reject_latches_overflow_and_stops :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueDAA &&
                                            cmd_attr == AddressAssignment &&
                                            daa_wr_busy_q &&
                                            (!rx_queue_wready_i || rx_queue_full_i)
                                            |->
                                            gen_stop_o
                                            ##1
                                            rx_overflow_q && entdaa_stop_req_q)
  else $error("flow_active_sva: rejected ENTDAA result commit must latch overflow and stop in %m");

  cp_entdaa_commit_reject_latches_overflow_and_stops :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueDAA &&
                                            cmd_attr == AddressAssignment &&
                                            daa_wr_busy_q &&
                                            (!rx_queue_wready_i || rx_queue_full_i) &&
                                            gen_stop_o
                                            ##1
                                            rx_overflow_q && entdaa_stop_req_q);

  ap_entdaa_overflow_blocks_result_write :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueDAA &&
                                            cmd_attr == AddressAssignment &&
                                            rx_overflow_q
                                            |->
                                            !rx_queue_wvalid)
  else $error("flow_active_sva: ENTDAA overflow must block further result writes in %m");

  cp_entdaa_overflow_blocks_result_write :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueDAA &&
                                            cmd_attr == AddressAssignment &&
                                            rx_overflow_q &&
                                            !rx_queue_wvalid);

  ap_ovl_resp_matches_current_len :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            (tx_underflow_q || rx_overflow_q)
                                            |->
                                            ovl_resp_matches_current_len())
  else $error("flow_active_sva: Ovl response status/TID/reserved/length mismatch in %m");

  cp_ovl_resp_matches_current_len :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            (tx_underflow_q || rx_overflow_q) &&
                                            ovl_resp_matches_current_len());

  cp_i3c_read_rx_overflow_resp_ovl :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            rx_overflow_q &&
                                            ovl_resp_matches_current_len());

  cp_i2c_read_rx_overflow_resp_ovl :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            i2c_regular_read() &&
                                            rx_overflow_q &&
                                            ovl_resp_matches_current_len());

  cp_entdaa_rx_overflow_resp_ovl :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == AddressAssignment &&
                                            rx_overflow_q &&
                                            ovl_resp_matches_current_len());

  ap_init_i3c_write_no_tx_pop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitWrite &&
                                            sdr_regular_i3c_write()
                                            |->
                                            !tx_queue_rready_o)
  else $error("flow_active_sva: InitWrite must not pop TX FIFO before address ACK in %m");

  cp_init_i3c_write_addr_ack_to_fetch_tx :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitWrite &&
                                            sdr_regular_i3c_write() &&
                                            !addr_nack_q &&
                                            issue_phase_q > PhaseAddrAck &&
                                            remaining_len_q > 16'h0
                                            ##1
                                            state_q == FetchTxData);

  ap_init_i3c_read_no_rx_data_req :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitRead &&
                                            sdr_regular_i3c_read()
                                            |->
                                            !bus_rx_req_byte &&
                                            !rx_queue_wvalid)
  else $error("flow_active_sva: InitRead must not request read data or push RX FIFO in %m");

  cp_init_i3c_read_no_rx_data_req :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitRead &&
                                            sdr_regular_i3c_read() &&
                                            !bus_rx_req_byte &&
                                            !rx_queue_wvalid);

  ap_sdr_read_addr_uses_dynamic_address :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitRead &&
                                            sdr_regular_i3c_read() &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte
                                            |->
                                            bus_tx_req_value === {dat_entry.dynamic_address, Read})
  else $error("flow_active_sva: SDR read address byte must use selected DAT dynamic address in %m");

  cp_sdr_read_addr_uses_dynamic_address :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitRead &&
                                            sdr_regular_i3c_read() &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte &&
                                            bus_tx_req_value === {dat_entry.dynamic_address, Read});

  ap_init_i3c_read_addr_ack_to_issue_cmd :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitRead &&
                                            sdr_regular_i3c_read() &&
                                            !addr_nack_q &&
                                            issue_phase_q > PhaseAddrAck
                                            |=>
                                            state_q == IssueI3CRead)
  else $error("flow_active_sva: InitRead must enter IssueI3CRead after address ACK in %m");

  cp_init_i3c_read_addr_ack_to_issue_cmd :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitRead &&
                                            sdr_regular_i3c_read() &&
                                            !addr_nack_q &&
                                            issue_phase_q > PhaseAddrAck
                                            ##1
                                            state_q == IssueI3CRead);

  ap_sdr_write_addr_nack_no_data_phase :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                                         (state_q == InitWrite ||
                                                          state_q == IssueI3CWrite) &&
                                                         sdr_regular_i3c_write() &&
                                                         addr_nack_q
                                                         |->
                                                         gen_stop_o &&
                                                         !bus_tx_req_byte &&
                                                         !bus_tx_req_bit)
  else $error("flow_active_sva: SDR write address NACK must stop without data phase in %m");

  cp_sdr_write_addr_nack_no_data_phase :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                                         (state_q == InitWrite ||
                                                          state_q == IssueI3CWrite) &&
                                                         sdr_regular_i3c_write() &&
                                                         addr_nack_q &&
                                                         gen_stop_o &&
                                                         !bus_tx_req_byte &&
                                                         !bus_tx_req_bit);

  ap_sdr_write_addr_nack_sample_no_data_phase :
  assert property (
      @(posedge clk_i) disable iff (!rst_ni)
      (state_q == InitWrite || state_q == IssueI3CWrite) &&
      sdr_regular_i3c_write() &&
      issue_phase_q == PhaseAddrAck &&
      bus_rx_done_i &&
      bus_rx_data_i[0]
      |->
      !bus_tx_req_byte &&
      !bus_tx_req_bit)
  else $error("flow_active_sva: SDR write address NACK sample must not overlap data phase in %m");

  cp_sdr_write_addr_nack_sample_no_data_phase :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
      (state_q == InitWrite || state_q == IssueI3CWrite) &&
      sdr_regular_i3c_write() &&
      issue_phase_q == PhaseAddrAck &&
      bus_rx_done_i &&
      bus_rx_data_i[0] &&
      !bus_tx_req_byte &&
      !bus_tx_req_bit);

  ap_sdr_write_addr_nack_eventually_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni) $rose(
      addr_nack_q
  ) && (state_q == InitWrite || state_q == IssueI3CWrite) && sdr_regular_i3c_write() |->
      ##[1:AddrNackRespTimeoutCycles] (state_q == WriteResp && addr_nack_resp_matches()))
  else
    $error(
        "flow_active_sva: SDR write address NACK did not produce bounded AddrHeader response in %m"
    );

  cp_sdr_write_addr_nack_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                          state_q == WriteResp &&
                                          sdr_regular_i3c_write() &&
                                          addr_nack_q &&
                                          addr_nack_resp_matches());

  // ERR_003: a NACK on the shared 7'h7E+W broadcast-header frame stops the
  // transfer before any command-specific phase and reports AddrHeader.
  ap_bcast_header_nack_sample_no_followup :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                                state_q == I3CBcastHeader &&
                                                issue_phase_q == PhaseAddrAck &&
                                                bus_rx_done_i &&
                                                bus_rx_data_i[0]
                                                |->
                                                !gen_rstart_o &&
                                                !bus_tx_req_byte &&
                                                !bus_tx_req_bit &&
                                                !bus_rx_req_byte)
  else $error("flow_active_sva: broadcast-header NACK sample must not overlap a follow-up bus phase in %m");

  cp_bcast_header_nack_sample_no_followup :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                                state_q == I3CBcastHeader &&
                                                issue_phase_q == PhaseAddrAck &&
                                                bus_rx_done_i &&
                                                bus_rx_data_i[0] &&
                                                !gen_rstart_o &&
                                                !bus_tx_req_byte &&
                                                !bus_tx_req_bit &&
                                                !bus_rx_req_byte);

  ap_bcast_header_nack_stops_no_followup :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                                state_q == I3CBcastHeader &&
                                                addr_nack_q
                                                |->
                                                gen_stop_o &&
                                                !gen_rstart_o &&
                                                !bus_tx_req_byte &&
                                                !bus_tx_req_bit &&
                                                !bus_rx_req_byte &&
                                                !bus_rx_req_bit)
  else $error("flow_active_sva: broadcast-header NACK must STOP without command-specific follow-up in %m");

  cp_bcast_header_nack_stops_no_followup :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                                state_q == I3CBcastHeader &&
                                                addr_nack_q &&
                                                gen_stop_o &&
                                                !gen_rstart_o &&
                                                !bus_tx_req_byte &&
                                                !bus_tx_req_bit &&
                                                !bus_rx_req_byte &&
                                                !bus_rx_req_bit);

  ap_bcast_header_nack_eventually_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                                state_q == I3CBcastHeader &&
                                                addr_nack_q
                                                |->
                                                ##[1:AddrNackRespTimeoutCycles]
                                                (state_q == WriteResp &&
                                                 addr_nack_resp_matches()))
  else $error("flow_active_sva: broadcast-header NACK did not produce bounded AddrHeader response in %m");

  cp_bcast_header_nack_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                                state_q == I3CBcastHeader &&
                                                addr_nack_q
                                                ##[1:AddrNackRespTimeoutCycles]
                                                state_q == WriteResp &&
                                                addr_nack_resp_matches());

  // ERR_002/ERR_003: every address/header NACK response uses the common
  // AddrHeader/TID/reserved-zero/len0 encoding. Class-specific covers below
  // make the ERR_002 I2C, immediate, and direct-CCC target cases visible.
  ap_addr_nack_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                                state_q == WriteResp &&
                                                addr_nack_q
                                                |->
                                                addr_nack_resp_matches())
  else $error("flow_active_sva: address NACK response descriptor mismatch in %m");

  cp_addr_nack_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                          state_q == WriteResp &&
                                          addr_nack_q &&
                                          addr_nack_resp_matches());

  cp_i2c_write_addr_nack_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                          state_q == WriteResp &&
                                          i2c_regular_write() &&
                                          addr_nack_q &&
                                          addr_nack_resp_matches());

  cp_i2c_read_addr_nack_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                          state_q == WriteResp &&
                                          i2c_regular_read() &&
                                          addr_nack_q &&
                                          addr_nack_resp_matches());

  cp_i3c_imm_addr_nack_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                          state_q == WriteResp &&
                                          i3c_immediate_private_write() &&
                                          addr_nack_q &&
                                          addr_nack_resp_matches());

  cp_i2c_imm_addr_nack_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                          state_q == WriteResp &&
                                          i2c_immediate_write() &&
                                          addr_nack_q &&
                                          addr_nack_resp_matches());

  cp_direct_ccc_target_addr_nack_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                          state_q == WriteResp &&
                                          direct_ccc_target_addr_nack() &&
                                          addr_nack_q &&
                                          addr_nack_resp_matches());

  ap_sdr_write_toc1_success_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
                                            !invalid_cmd_desc() &&
                                            reg_desc.toc &&
                                            !addr_nack_q &&
                                            !tx_underflow_q &&
                                            !hc_aborted_q
                                            |->
                                            success_resp_matches_current_len())
  else $error("flow_active_sva: SDR write success response descriptor mismatch in %m");

  cp_sdr_write_toc1_success_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
                                            !invalid_cmd_desc() &&
                                            reg_desc.toc &&
                                            !addr_nack_q &&
                                            !tx_underflow_q &&
                                            success_resp_matches_current_len());

  ap_sdr_read_addr_nack_no_data_phase :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                                         state_q == InitRead &&
                                                         sdr_regular_i3c_read() &&
                                                         addr_nack_q
                                                         |->
                                                         gen_stop_o &&
                                                         !bus_rx_req_byte &&
                                                         !bus_rx_req_bit &&
                                                         !rx_queue_wvalid)
  else $error("flow_active_sva: SDR read address NACK must stop without data phase in %m");

  cp_sdr_read_addr_nack_no_data_phase :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                                         state_q == InitRead &&
                                                         sdr_regular_i3c_read() &&
                                                         addr_nack_q &&
                                                         gen_stop_o &&
                                                         !bus_rx_req_byte &&
                                                         !bus_rx_req_bit &&
                                                         !rx_queue_wvalid);

  ap_sdr_read_addr_nack_sample_no_data_phase :
  assert property (
      @(posedge clk_i) disable iff (!rst_ni)
      state_q == InitRead &&
      sdr_regular_i3c_read() &&
      issue_phase_q == PhaseAddrAck &&
      bus_rx_done_i &&
      bus_rx_data_i[0]
      |=>
      addr_nack_q &&
      gen_stop_o &&
      !bus_rx_req_byte &&
      !bus_rx_req_bit &&
      !rx_queue_wvalid)
  else $error("flow_active_sva: SDR read address NACK sample must not enter data phase in %m");

  cp_sdr_read_addr_nack_sample_no_data_phase :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
      state_q == InitRead &&
      sdr_regular_i3c_read() &&
      issue_phase_q == PhaseAddrAck &&
      bus_rx_done_i &&
      bus_rx_data_i[0]
      ##1
      addr_nack_q &&
      gen_stop_o &&
      !bus_rx_req_byte &&
      !bus_rx_req_bit &&
      !rx_queue_wvalid);

  ap_sdr_read_addr_nack_eventually_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni) $rose(
      addr_nack_q
  ) && state_q == InitRead && sdr_regular_i3c_read() |->
      ##[1:AddrNackRespTimeoutCycles] (state_q == WriteResp && addr_nack_resp_matches()))
  else
    $error(
        "flow_active_sva: SDR read address NACK did not produce bounded AddrHeader response in %m"
    );

  cp_sdr_read_addr_nack_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                          state_q == WriteResp &&
                                          sdr_regular_i3c_read() &&
                                          addr_nack_q &&
                                          addr_nack_resp_matches());

  ap_sdr_read_byte_pack :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0] &&
                                            bus_rx_done_i
                                            |=>
                                            rx_dword_q === expected_rx_word_with_byte(
      $past(rx_dword_q), $past(rx_byte_idx_q), $past(bus_rx_data_i)
  ))
  else $error("flow_active_sva: SDR read byte did not pack into expected RX DWORD lane in %m");

  cp_sdr_read_byte_pack :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0] &&
                                            bus_rx_done_i);

  ap_sdr_read_tbit_updates_count :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            !abort_i &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i
                                            |=>
                                            rx_byte_idx_q == expected_rx_byte_idx_after_tbit(
      $past(rx_byte_idx_q), $past(remaining_len_q), !$past(bus_rx_data_i[0]),
      $past(rx_queue_wready_i), $past(rx_queue_full_i)
  ) && remaining_len_q == ($past(
      remaining_len_q
  ) - 16'h1) && resp_data_len_q == ($past(
      resp_data_len_q
  ) + 16'h1))
  else $error("flow_active_sva: SDR read T-bit phase did not update counters in %m");

  cp_sdr_read_tbit_updates_count :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i);

  ap_sdr_read_target_tbit_end_sets_short :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            !abort_i &&
                                            remaining_len_q > 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b0
                                            |=>
                                            short_read_q)
  else $error("flow_active_sva: early target T-bit end did not set short_read_q in %m");

  cp_sdr_read_target_tbit_end_sets_short :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q > 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b0
                                            ##1
                                            short_read_q);

  cp_sdr_read_one_byte_short :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            !abort_i &&
                                            remaining_len_q == 16'h2 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b0
                                            ##1
                                            short_read_q);

  ap_sdr_read_short_commits_received_word_and_stops :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            !abort_i &&
                                            remaining_len_q > 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b0 &&
                                            rx_queue_wready_i &&
                                            !rx_queue_full_i
                                            |->
                                            rx_queue_wvalid &&
                                            rx_queue_wdata === rx_dword_q &&
                                            gen_stop_o &&
                                            !gen_rstart_o &&
                                            !cmd_queue_rready_o)
  else
    $error(
        "flow_active_sva: short read must commit received data and force STOP without continuation in %m"
    );

  cp_sdr_read_short_commits_received_word_and_stops :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            !abort_i &&
                                            remaining_len_q > 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b0 &&
                                            rx_queue_wready_i &&
                                            !rx_queue_full_i &&
                                            rx_queue_wvalid &&
                                            rx_queue_wdata === rx_dword_q &&
                                            gen_stop_o &&
                                            !gen_rstart_o &&
                                            !cmd_queue_rready_o
                                            ##1
                                            short_read_q);

  ap_sdr_read_short_blocks_more_data_and_continuation :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            short_read_q
                                            |->
                                            !bus_rx_req_byte &&
                                            !bus_rx_req_bit &&
                                            !bus_rx_req_bit_handoff &&
                                            !cmd_queue_rready_o &&
                                            !gen_rstart_o)
  else
    $error(
        "flow_active_sva: latched short read must block further data and continuation in %m"
    );

  cp_sdr_read_short_blocks_more_data_and_continuation :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            short_read_q &&
                                            !bus_rx_req_byte &&
                                            !bus_rx_req_bit &&
                                            !bus_rx_req_bit_handoff &&
                                            !cmd_queue_rready_o &&
                                            !gen_rstart_o);

  ap_sdr_read_target_continue_at_requested_len :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q == 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b1
                                            |=>
                                            !short_read_q &&
                                            remaining_len_q == 16'h0)
  else
    $error(
        "flow_active_sva: target continue T-bit at requested length must not be a short read in %m"
    );

  cp_sdr_read_target_continue_at_requested_len :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q == 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b1
                                            ##1
                                            !short_read_q &&
                                            remaining_len_q == 16'h0);

  ap_sdr_read_target_end_at_requested_len :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q == 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b0
                                            |=>
                                            !short_read_q &&
                                            remaining_len_q == 16'h0)
  else
    $error("flow_active_sva: final target T-bit end must complete read without short read in %m");

  cp_sdr_read_target_end_at_requested_len :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q == 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b0
                                            ##1
                                            !short_read_q &&
                                            remaining_len_q == 16'h0);

  cp_sdr_read_short_dword_boundary :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q > 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b0 &&
                                            rx_byte_idx_q == 2'd3
                                            ##1
                                            short_read_q &&
                                            rx_byte_idx_q == 2'd0);

  ap_sdr_read_success_resp_len :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            !invalid_cmd_desc() &&
                                            !addr_nack_q &&
                                            !short_read_error &&
                                            !rx_overflow_q &&
                                            !hc_aborted_q
                                            |->
                                            success_resp_matches_current_len())
  else $error("flow_active_sva: SDR read success response length mismatch in %m");

  cp_sdr_read_success_resp_len :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            !invalid_cmd_desc() &&
                                            !addr_nack_q &&
                                            !short_read_error &&
                                            !rx_overflow_q &&
                                            !hc_aborted_q &&
                                            success_resp_matches_current_len());

  ap_sdr_read_short_resp_len :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            short_read_error
                                            |->
                                            short_read_resp_matches_current_len())
  else $error("flow_active_sva: SDR read short response status/length mismatch in %m");

  cp_sdr_read_short_resp_len :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            short_read_error &&
                                            short_read_resp_matches_current_len());

  cp_sdr_read_sre1_wroc0_error_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            short_read_q &&
                                            reg_desc.sre &&
                                            !reg_desc.wroc &&
                                            short_read_resp_matches_current_len());

  cp_sdr_read_sre0_wroc1_success_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            short_read_q &&
                                            !reg_desc.sre &&
                                            reg_desc.wroc &&
                                            success_resp_matches_current_len());

  ap_sdr_read_sre0_wroc0_suppresses_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            short_read_q &&
                                            !reg_desc.sre &&
                                            !reg_desc.wroc &&
                                            bus_tx_idle_i &&
                                            bus_rx_idle_i &&
                                            scl_stop_done_q
                                            |->
                                            state_d == Idle &&
                                            !resp_queue_wvalid)
  else $error("flow_active_sva: permitted wroc=0 short read must not write RESP in %m");

  cp_sdr_read_sre0_wroc0_suppresses_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            short_read_q &&
                                            !reg_desc.sre &&
                                            !reg_desc.wroc &&
                                            bus_tx_idle_i &&
                                            bus_rx_idle_i &&
                                            scl_stop_done_q &&
                                            state_d == Idle &&
                                            !resp_queue_wvalid);

  // --- HC abort of an active I3C SDR read (MIPI I3C Basic v1.1.1 5.1.2.3.4) ---
  // The controller finishes the in-flight data word and retakes SDA only at its
  // T-Bit: a Repeated START when the Target parked the bus (T=1), or a direct
  // STOP when the Target already ended the word (T=0). It must never tear the
  // read down with a bare STOP into the Target's push-pull drive mid-word, and
  // the response is HcAborted (not a short-read error).
  ap_sdr_read_abort_tbit_takeover_rstart :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            !rx_overflow_q &&
                                            !read_abort_term_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            abort_i &&
                                            bus_rx_data_i[0] == 1'b1
                                            |->
                                            gen_rstart_o && !gen_stop_o)
  else
    $error(
        "flow_active_sva: HC read abort at T-Bit=1 must retake SDA via Repeated START, not a bare STOP, in %m"
    );

  ap_sdr_read_abort_tbit_stop_on_t0 :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            !rx_overflow_q &&
                                            !read_abort_term_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            abort_i &&
                                            bus_rx_data_i[0] == 1'b0
                                            |->
                                            gen_stop_o)
  else $error("flow_active_sva: HC read abort at T-Bit=0 (Target already ended) must STOP in %m");

  ap_sdr_read_abort_sets_hc_aborted :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            !rx_overflow_q &&
                                            !read_abort_term_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            abort_i
                                            |=>
                                            hc_aborted_q && read_abort_term_q && !short_read_q)
  else
    $error(
        "flow_active_sva: HC read abort must set hc_aborted/read_abort_term and must not set short_read in %m"
    );

  // End-to-end: abort early in the data phase -> first data word still clocked to
  // its T-Bit -> Repeated START takeover -> STOP -> HcAborted response.
  cp_sdr_read_abort_first_word_then_takeover :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            abort_i &&
                                            bus_rx_data_i[0] == 1'b1 &&
                                            gen_rstart_o
                                            ##[1:256]
                                            gen_stop_o
                                            ##[1:256]
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            hc_aborted_q);

  ap_sdr_read_abort_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            hc_aborted_q &&
                                            !rx_overflow_q
                                            |->
                                            hc_aborted_resp_matches_current_len() &&
                                            !cmd_queue_rready_o)
  else
    $error(
        "flow_active_sva: HC-aborted SDR read must write HcAborted response and must not pop a continuation command in %m"
    );

  cp_sdr_read_abort_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            hc_aborted_q &&
                                            !rx_overflow_q &&
                                            hc_aborted_resp_matches_current_len() &&
                                            !cmd_queue_rready_o);

  ap_sdr_read_abort_toc0_blocks_continuation :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            hc_aborted_q &&
                                            !reg_desc.toc &&
                                            next_cmd_available
                                            |->
                                            !cmd_queue_rready_o)
  else $error("flow_active_sva: HC-aborted toc=0 SDR read must not pop next command in %m");

  ap_sdr_read_toc1_requests_stop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_read_done_ready() &&
                                            reg_desc.toc
                                            |->
                                            gen_stop_o)
  else $error("flow_active_sva: SDR read toc=1 completion must request STOP in %m");

  cp_sdr_read_toc1_requests_stop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_read_done_ready() &&
                                            reg_desc.toc &&
                                            gen_stop_o);

  cp_sdr_read_end_policy :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q == 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b1
                                            ##[1:64]
                                            sdr_read_done_ready() &&
                                            reg_desc.toc &&
                                            gen_stop_o
                                            ##[1:256]
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            success_resp_matches_current_len());

  cp_sdr_read_final_tbit_end_policy :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q == 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b0
                                            ##[1:64]
                                            sdr_read_done_ready() &&
                                            reg_desc.toc &&
                                            gen_stop_o
                                            ##[1:256]
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            success_resp_matches_current_len());

  ap_sdr_read_toc0_accept_continuation :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_read_done_ready() &&
                                            !reg_desc.toc &&
                                            next_cmd_available &&
                                            next_cmd_supported &&
                                            (!reg_desc.wroc || resp_queue_wready_i)
                                            |->
                                            ((reg_desc.wroc && success_resp_matches_current_len()) ||
                                             (!reg_desc.wroc && !resp_queue_wvalid)) &&
                                            cmd_queue_rready_o &&
                                            !gen_stop_o)
  else $error("flow_active_sva: SDR read toc=0 must accept continuation without STOP in %m");

  cp_sdr_read_toc0_accept_continuation :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_read_done_ready() &&
                                            !reg_desc.toc &&
                                            next_cmd_available &&
                                            next_cmd_supported &&
                                            (!reg_desc.wroc || resp_queue_wready_i) &&
                                            ((reg_desc.wroc && success_resp_matches_current_len()) ||
                                             (!reg_desc.wroc && !resp_queue_wvalid)) &&
                                            cmd_queue_rready_o &&
                                            !gen_stop_o);

  ap_sdr_read_rstart_instead_of_start :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitRead &&
                                            sdr_regular_i3c_read() &&
                                            issue_phase_q == PhaseStart &&
                                            next_start_is_rstart_q
                                            |->
                                            gen_rstart_o &&
                                            !gen_start_o &&
                                            !gen_stop_o)
  else $error("flow_active_sva: SDR read continuation must request repeated START only in %m");

  ap_toc0_private_read_continuation_skips_bcast_header :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitDAT &&
                                            cont_pending_q &&
                                            broadcast_header_enable_i &&
                                            sdr_regular_i3c_read()
                                            |=>
                                            state_q != I3CBcastHeader)
  else $error("flow_active_sva: SDR read continuation must not emit a second broadcast header in %m");

  cp_toc0_private_read_continuation_skips_bcast_header :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitDAT &&
                                            cont_pending_q &&
                                            broadcast_header_enable_i &&
                                            sdr_regular_i3c_read()
                                            ##[1:8]
                                            state_q == InitRead &&
                                            next_start_is_rstart_q);

  cp_toc0_accept_then_rstart_then_toc1_stop_read :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_read_done_ready() &&
                                            !reg_desc.toc &&
                                            reg_desc.wroc &&
                                            next_cmd_available &&
                                            next_cmd_supported &&
                                            resp_queue_wready_i &&
                                            success_resp_matches_current_len() &&
                                            cmd_queue_rready_o &&
                                            !gen_stop_o
                                            ##[1:64]
                                            state_q == InitRead &&
                                            sdr_regular_i3c_read() &&
                                            issue_phase_q == PhaseStart &&
                                            next_start_is_rstart_q &&
                                            gen_rstart_o &&
                                            !gen_start_o &&
                                            !gen_stop_o
                                            ##[1:1024]
                                            sdr_read_done_ready() &&
                                            reg_desc.toc &&
                                            gen_stop_o
                                            ##[1:256]
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            success_resp_matches_current_len());

  ap_toc0_accept_continuation :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_done_ready() &&
                                            !reg_desc.toc &&
                                            next_cmd_available &&
                                            next_cmd_supported &&
                                            (!reg_desc.wroc || resp_queue_wready_i)
                                            |->
                                            ((reg_desc.wroc && success_resp_matches_current_len()) ||
                                             (!reg_desc.wroc && !resp_queue_wvalid)) &&
                                            cmd_queue_rready_o &&
                                            !gen_stop_o)
  else $error("flow_active_sva: SDRW_003 toc=0 must accept continuation without STOP in %m");

  cp_toc0_accept_continuation :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_done_ready() &&
                                            !reg_desc.toc &&
                                            next_cmd_available &&
                                            next_cmd_supported &&
                                            (!reg_desc.wroc || resp_queue_wready_i) &&
                                            ((reg_desc.wroc && success_resp_matches_current_len()) ||
                                             (!reg_desc.wroc && !resp_queue_wvalid)) &&
                                            cmd_queue_rready_o &&
                                            !gen_stop_o);

  ap_sdr_write_no_cmd_pop_except_continuation :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_active_state() &&
                                            sdr_regular_i3c_write() &&
                                            !(sdr_write_done_ready() &&
                                              !reg_desc.toc &&
                                              next_cmd_available &&
                                              next_cmd_supported &&
                                              (!reg_desc.wroc || resp_queue_wready_i))
                                            |->
                                            !cmd_queue_rready_o)
  else $error("flow_active_sva: SDR write must not pop CMD FIFO except accepted continuation in %m");

  cp_sdr_write_no_cmd_pop_except_continuation :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_active_state() &&
                                            sdr_regular_i3c_write() &&
                                            !(sdr_write_done_ready() &&
                                              !reg_desc.toc &&
                                              next_cmd_available &&
                                              next_cmd_supported &&
                                              (!reg_desc.wroc || resp_queue_wready_i)) &&
                                            !cmd_queue_rready_o);

  ap_toc0_missing_continuation_requests_stop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_done_ready() &&
                                            !reg_desc.toc &&
                                            !next_cmd_available
                                            |->
                                            gen_stop_o &&
                                            !gen_rstart_o &&
                                            !cmd_queue_rready_o)
  else $error("flow_active_sva: SDRW_003 toc=0 missing continuation must STOP without CMD pop in %m");

  cp_toc0_missing_continuation_requests_stop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_done_ready() &&
                                            !reg_desc.toc &&
                                            !next_cmd_available &&
                                            gen_stop_o &&
                                            !gen_rstart_o &&
                                            !cmd_queue_rready_o);

  ap_toc0_missing_continuation_not_supported_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
                                            !reg_desc.toc &&
                                            !addr_nack_q &&
                                            !tx_underflow_q &&
                                            !hc_aborted_q &&
                                            !next_cmd_available
                                            |->
                                            not_supported_resp_matches_current_len())
  else $error("flow_active_sva: SDRW_003 toc=0 missing continuation response must be NotSupported in %m");

  cp_toc0_missing_continuation_not_supported_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
                                            !reg_desc.toc &&
                                            !addr_nack_q &&
                                            !tx_underflow_q &&
                                            !hc_aborted_q &&
                                            !next_cmd_available &&
                                            not_supported_resp_matches_current_len());

  ap_toc0_unsupported_continuation_not_supported_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
                                            !reg_desc.toc &&
                                            !addr_nack_q &&
                                            !tx_underflow_q &&
                                            next_cmd_available &&
                                            !next_cmd_supported
                                            |->
                                            not_supported_resp_matches_current_len())
  else $error("flow_active_sva: SDRW_003 toc=0 unsupported continuation response must be NotSupported in %m");

  cp_toc0_unsupported_continuation_not_supported_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
                                            !reg_desc.toc &&
                                            !addr_nack_q &&
                                            !tx_underflow_q &&
                                            next_cmd_available &&
                                            !next_cmd_supported &&
                                            not_supported_resp_matches_current_len());

  ap_rstart_instead_of_start :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitWrite &&
                                            sdr_regular_i3c_write() &&
                                            issue_phase_q == PhaseStart &&
                                            next_start_is_rstart_q
                                            |->
                                            gen_rstart_o &&
                                            !gen_start_o &&
                                            !gen_stop_o)
  else $error("flow_active_sva: SDRW_003 continuation must request repeated START only in %m");

  ap_toc0_private_write_continuation_skips_bcast_header :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitDAT &&
                                            cont_pending_q &&
                                            broadcast_header_enable_i &&
                                            sdr_regular_i3c_write()
                                            |=>
                                            state_q != I3CBcastHeader)
  else $error("flow_active_sva: SDRW_003 continuation must not emit a second broadcast header in %m");

  cp_toc0_private_write_continuation_skips_bcast_header :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitDAT &&
                                            cont_pending_q &&
                                            broadcast_header_enable_i &&
                                            sdr_regular_i3c_write()
                                            ##[1:8]
                                            state_q == InitWrite &&
                                            next_start_is_rstart_q);

  ap_toc1_requests_stop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_done_ready() &&
                                            reg_desc.toc
                                            |->
                                            gen_stop_o)
  else $error("flow_active_sva: SDR write toc=1 completion must request STOP in %m");

  cp_toc0_accept_then_rstart_then_toc1_stop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_done_ready() &&
                                            !reg_desc.toc &&
                                            next_cmd_available &&
                                            next_cmd_supported &&
                                            resp_queue_wready_i &&
                                            success_resp_matches_current_len() &&
                                            cmd_queue_rready_o &&
                                            !gen_stop_o
                                            ##[1:64]
                                            state_q == InitWrite &&
                                            sdr_regular_i3c_write() &&
                                            issue_phase_q == PhaseStart &&
                                            next_start_is_rstart_q &&
                                            gen_rstart_o &&
                                            !gen_start_o &&
                                            !gen_stop_o
                                            ##[1:1024]
                                            sdr_write_done_ready() &&
                                            reg_desc.toc &&
                                            gen_stop_o
                                            ##[1:256]
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
                                            success_resp_matches_current_len());

  cp_toc0_bcast_header_once_write :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            broadcast_header_enable_i &&
                                            state_q == I3CBcastHeader &&
                                            sdr_regular_i3c_write()
                                            ##[1:1024]
                                            sdr_write_done_ready() &&
                                            !reg_desc.toc &&
                                            next_cmd_available &&
                                            next_cmd_supported &&
                                            resp_queue_wready_i &&
                                            success_resp_matches_current_len() &&
                                            cmd_queue_rready_o &&
                                            !gen_stop_o
                                            ##[1:128]
                                            state_q == InitWrite &&
                                            cont_pending_q &&
                                            sdr_regular_i3c_write() &&
                                            issue_phase_q == PhaseStart &&
                                            next_start_is_rstart_q &&
                                            gen_rstart_o &&
                                            !gen_start_o &&
                                            !gen_stop_o);

  // ----------------------------------------------------------------------
  // I2C legacy path (DAT.device=1) — RegularTransfer (I2C_001 / I2C_002)
  //
  // The I3C assertions above are all gated on !dat_entry.device and so
  // explicitly exclude the legacy I2C path. These mirror them for the
  // I2C path: static-address+R/W framing, open-drain/I2C-timing throughout,
  // write data integrity, the I2C read master ACK-intermediate/NACK-final
  // policy, read byte packing, and Success/length response descriptors.
  // ----------------------------------------------------------------------

  // BUS_014: keep an explicit sign-off hook for the legacy-I2C OD-only rule.
  // The I2C regular write/read vseqs provide the stimulus; this assertion owns
  // the protocol invariant, so no BUS_014-specific vseq is required.
  ap_bus014_i2c_regular_xfer_never_push_pull :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            i2c_active_state() &&
                                            !abort_i &&
                                            i2c_regular_xfer()
                                            |->
                                            !sel_i3c_i2c_o &&
                                            use_i2c_timing_o &&
                                            !sel_od_pp_o)
  else $error("flow_active_sva: BUS_014 I2C regular transfer asserted push-pull in %m");

  cp_bus014_i2c_regular_xfer_never_push_pull :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            i2c_active_state() &&
                                            !abort_i &&
                                            i2c_regular_xfer() &&
                                            !sel_i3c_i2c_o &&
                                            use_i2c_timing_o &&
                                            !sel_od_pp_o);

  // I2C write address byte = {static_address, W}.
  ap_i2c_write_addr_uses_static_address :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitWrite &&
                                            i2c_regular_write() &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte
                                            |->
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === {dat_entry.static_address, Write})
  else $error("flow_active_sva: I2C write address byte must be static address + W in %m");

  cp_i2c_write_addr_uses_static_address :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitWrite &&
                                            i2c_regular_write() &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte &&
                                            bus_tx_req_value === {dat_entry.static_address, Write});

  // I2C read address byte = {static_address, R}.
  ap_i2c_read_addr_uses_static_address :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitRead &&
                                            i2c_regular_read() &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte
                                            |->
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === {dat_entry.static_address, Read})
  else $error("flow_active_sva: I2C read address byte must be static address + R in %m");

  cp_i2c_read_addr_uses_static_address :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitRead &&
                                            i2c_regular_read() &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte &&
                                            bus_tx_req_value === {dat_entry.static_address, Read});

  // I2C write data integrity: on the odd (data-byte) sub-phase the byte put
  // on the bus is exactly the selected TX-FIFO byte for that DWORD lane.
  ap_i2c_write_data_byte_matches_tx :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            i2c_regular_write() &&
                                            !abort_i &&
                                            !data_nack_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0]
                                            |->
                                            bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === current_tx_byte)
  else $error("flow_active_sva: I2C write data byte must match selected TX byte in %m");

  cp_i2c_write_data_byte_matches_tx :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            i2c_regular_write() &&
                                            !abort_i &&
                                            !data_nack_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0] &&
                                            bus_tx_req_byte &&
                                            bus_tx_req_value === current_tx_byte);

  // I2C write samples the target ACK bit on the even sub-phase (no byte/T-bit
  // drive) — the controller reads each data byte's ACK.
  ap_i2c_write_acks_data_byte :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            i2c_regular_write() &&
                                            !data_nack_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0]
                                            |->
                                            bus_rx_req_bit &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit)
  else $error("flow_active_sva: I2C write must sample target ACK on the even sub-phase in %m");

  cp_i2c_write_acks_data_byte :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            i2c_regular_write() &&
                                            !data_nack_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_req_bit);

  // I2C read data integrity: each received byte packs into the expected RX
  // DWORD lane (little-endian), mirroring the I3C read byte-pack check.
  ap_i2c_read_byte_pack :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0] &&
                                            bus_rx_done_i
                                            |=>
                                            rx_dword_q === expected_rx_word_with_byte(
      $past(rx_dword_q), $past(rx_byte_idx_q), $past(bus_rx_data_i)
  ))
  else $error("flow_active_sva: I2C read byte did not pack into expected RX DWORD lane in %m");

  cp_i2c_read_byte_pack :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0] &&
                                            bus_rx_done_i);

  // I2C read ACK/NACK policy: master ACKs (drives 0) every intermediate byte
  // (remaining_len > 1) on the even sub-phase.
  ap_i2c_read_master_ack_intermediate :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            !abort_i &&
                                            !hc_aborted_q &&
                                            remaining_len_q > 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            !(rx_byte_idx_q == 2'd3 &&
                                              (!rx_queue_wready_i || rx_queue_full_i))
                                            |->
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            !bus_rx_req_byte &&
                                            bus_tx_req_value === ACK)
  else $error("flow_active_sva: I2C read must ACK (drive 0) intermediate bytes in %m");

  cp_i2c_read_master_ack_intermediate :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            !abort_i &&
                                            !hc_aborted_q &&
                                            remaining_len_q > 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            !(rx_byte_idx_q == 2'd3 &&
                                              (!rx_queue_wready_i || rx_queue_full_i)) &&
                                            bus_tx_req_bit &&
                                            bus_tx_req_value === ACK);

  // I2C read ACK/NACK policy: master NACKs (drives 1) the final byte
  // (remaining_len == 1) on the even sub-phase to end the read.
  ap_i2c_read_master_nack_final :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            remaining_len_q == 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0]
                                            |->
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            !bus_rx_req_byte &&
                                            bus_tx_req_value === NACK)
  else $error("flow_active_sva: I2C read must NACK (drive 1) the final byte in %m");

  cp_i2c_read_master_nack_final :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            remaining_len_q == 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_tx_req_bit &&
                                            bus_tx_req_value === NACK);

  // I2C read abort follows the Legacy I2C read termination boundary: finish
  // the current data byte, drive controller NACK on the 9th bit, then STOP.
  ap_i2c_read_abort_defers_during_data :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            !read_abort_term_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0] &&
                                            abort_i
                                            |->
                                            bus_rx_req_byte &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            !gen_stop_o &&
                                            !gen_rstart_o)
  else $error("flow_active_sva: I2C read abort must finish data byte before STOP in %m");

  cp_i2c_read_abort_defers_during_data :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            !read_abort_term_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0] &&
                                            abort_i &&
                                            bus_rx_req_byte &&
                                            !gen_stop_o &&
                                            !gen_rstart_o);

  ap_i2c_read_abort_nacks_boundary :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            !read_abort_term_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            (abort_i || hc_aborted_q)
                                            |->
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            !bus_rx_req_byte &&
                                            bus_tx_req_value === NACK &&
                                            !gen_stop_o &&
                                            !gen_rstart_o)
  else $error("flow_active_sva: I2C read abort must drive controller NACK before STOP in %m");

  cp_i2c_read_abort_nacks_boundary :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            !read_abort_term_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            (abort_i || hc_aborted_q) &&
                                            bus_tx_req_bit &&
                                            bus_tx_req_value === NACK &&
                                            !gen_stop_o &&
                                            !gen_rstart_o);

  ap_i2c_read_abort_nack_sets_abort_term :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            !read_abort_term_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            (abort_i || hc_aborted_q) &&
                                            bus_tx_done_i
                                            |=>
                                            hc_aborted_q &&
                                            read_abort_term_q &&
                                            !short_read_q &&
                                            resp_data_len_q == $past(resp_data_len_q) + 16'h1)
  else $error("flow_active_sva: I2C read abort NACK must set HcAborted termination in %m");

  cp_i2c_read_abort_nack_sets_abort_term :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            !read_abort_term_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            (abort_i || hc_aborted_q) &&
                                            bus_tx_done_i
                                            ##1
                                            hc_aborted_q &&
                                            read_abort_term_q &&
                                            !short_read_q);

  ap_i2c_read_abort_term_stops :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            $rose(read_abort_term_q)
                                            |-> ##[0:4]
                                            gen_stop_o &&
                                            !gen_rstart_o &&
                                            !bus_tx_req_bit &&
                                            !bus_rx_req_byte)
  else $error("flow_active_sva: I2C read abort termination must STOP without RSTART in %m");

  cp_i2c_read_abort_term_stops :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            $rose(read_abort_term_q)
                                            ##[0:4]
                                            gen_stop_o &&
                                            !gen_rstart_o &&
                                            !bus_tx_req_bit &&
                                            !bus_rx_req_byte);

  ap_i2c_read_abort_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            i2c_regular_read() &&
                                            hc_aborted_q &&
                                            !rx_overflow_q
                                            |->
                                            hc_aborted_resp_matches_current_len())
  else $error("flow_active_sva: I2C read abort response status/length mismatch in %m");

  cp_i2c_read_abort_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            i2c_regular_read() &&
                                            hc_aborted_q &&
                                            !rx_overflow_q &&
                                            hc_aborted_resp_matches_current_len());

  // I2C write Success response (toc=1, no NACK/overflow/abort): descriptor is
  // Success with data length equal to bytes written.
  ap_i2c_write_success_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            i2c_regular_write() &&
                                            !invalid_cmd_desc() &&
                                            reg_desc.toc &&
                                            !addr_nack_q &&
                                            !data_nack_q &&
                                            !tx_underflow_q &&
                                            !rx_overflow_q &&
                                            !hc_aborted_q
                                            |->
                                            success_resp_matches_current_len())
  else $error("flow_active_sva: I2C write success response status/length mismatch in %m");

  cp_i2c_write_success_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            i2c_regular_write() &&
                                            !invalid_cmd_desc() &&
                                            reg_desc.toc &&
                                            !addr_nack_q &&
                                            !data_nack_q &&
                                            !tx_underflow_q &&
                                            !rx_overflow_q &&
                                            !hc_aborted_q &&
                                            success_resp_matches_current_len());

  // I2C read Success response (toc=1, no NACK/overflow/abort): descriptor is
  // Success with data length equal to bytes read.
  ap_i2c_read_success_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            i2c_regular_read() &&
                                            !invalid_cmd_desc() &&
                                            reg_desc.toc &&
                                            !addr_nack_q &&
                                            !rx_overflow_q &&
                                            !short_read_q &&
                                            !hc_aborted_q
                                            |->
                                            success_resp_matches_current_len())
  else $error("flow_active_sva: I2C read success response status/length mismatch in %m");

  cp_i2c_read_success_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            i2c_regular_read() &&
                                            !invalid_cmd_desc() &&
                                            reg_desc.toc &&
                                            !addr_nack_q &&
                                            !rx_overflow_q &&
                                            !short_read_q &&
                                            !hc_aborted_q &&
                                            success_resp_matches_current_len());

  // ----------------------------------------------------------------------
  // I2C_003 — BROADCAST_ADDR_ENABLE ignored by legacy I2C
  //
  // A regular I2C transfer leaves WaitDAT straight for its I2C init state and
  // never detours through the I3C broadcast-header state, so no 0x7e preamble
  // is emitted even when broadcast_header_enable_i is set. Combined with the
  // static-address framing assertions above, the first address on the bus is
  // always the DAT static address.
  // ----------------------------------------------------------------------
  ap_i2c_write_skips_broadcast_header :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitDAT &&
                                            i2c_regular_write() &&
                                            !dat_read_valid_hw_o &&
                                            !cont_pending_q
                                            |=>
                                            state_q == InitWrite)
  else $error("flow_active_sva: I2C write must skip the I3C broadcast header in %m");

  cp_i2c_write_skips_broadcast_header :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitDAT &&
                                            i2c_regular_write() &&
                                            broadcast_header_enable_i &&
                                            !dat_read_valid_hw_o &&
                                            !cont_pending_q
                                            ##1
                                            state_q == InitWrite);

  ap_i2c_read_skips_broadcast_header :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitDAT &&
                                            i2c_regular_read() &&
                                            !dat_read_valid_hw_o &&
                                            !cont_pending_q
                                            |=>
                                            state_q == InitRead)
  else $error("flow_active_sva: I2C read must skip the I3C broadcast header in %m");

  cp_i2c_read_skips_broadcast_header :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitDAT &&
                                            i2c_regular_read() &&
                                            broadcast_header_enable_i &&
                                            !dat_read_valid_hw_o &&
                                            !cont_pending_q
                                            ##1
                                            state_q == InitRead);

  ap_i2c_never_enters_broadcast_header :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            i2c_regular_xfer()
                                            |->
                                            state_q != I3CBcastHeader)
  else $error("flow_active_sva: I2C legacy transfer must never enter the I3C broadcast header in %m");

  // ----------------------------------------------------------------------
  // I2C_004 — length sweep / partial final RX DWORD
  //
  // Per-byte data integrity for every length is already covered by
  // ap_i2c_write_data_byte_matches_tx and ap_i2c_read_byte_pack. This adds the
  // partial-DWORD guarantee: the final received byte always commits the
  // (possibly partially filled) RX DWORD to the FIFO — no trailing byte is
  // dropped at non-DWORD-aligned lengths.
  // ----------------------------------------------------------------------
  ap_i2c_read_commits_final_word :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            remaining_len_q == 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_tx_done_i
                                            |->
                                            rx_queue_wvalid &&
                                            rx_queue_wdata === rx_dword_q)
  else $error("flow_active_sva: I2C read must commit the final (partial) RX DWORD in %m");

  cp_i2c_read_partial_final_dword :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            remaining_len_q == 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_tx_done_i &&
                                            rx_byte_idx_q != 2'd3 &&
                                            rx_queue_wvalid);

  cp_i2c_read_full_final_dword :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            remaining_len_q == 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_tx_done_i &&
                                            rx_byte_idx_q == 2'd3 &&
                                            rx_queue_wvalid);

  cp_i2c_read_dword_boundary_commit :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CRead &&
                                            i2c_regular_read() &&
                                            !rx_overflow_q &&
                                            remaining_len_q > 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_tx_done_i &&
                                            rx_byte_idx_q == 2'd3 &&
                                            rx_queue_wvalid);

  // ----------------------------------------------------------------------
  // ERR_004 — I2C regular write data-byte NACK
  //
  // A NACK sampled on a data byte's ACK sub-phase is latched, and from then on
  // the write requests STOP and drives no further data byte: only the bytes
  // beyond the NACKed position are dropped (I2C policy). The data-NACK RESP is
  // I2cDataNackOrI3cBusAborted with the actual bytes fully clocked.
  // ----------------------------------------------------------------------
  ap_i2c_write_data_nack_latches :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            i2c_regular_write() &&
                                            !data_nack_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0]
                                            |=>
                                            data_nack_q)
  else $error("flow_active_sva: I2C write data NACK must latch data_nack_q in %m");

  cp_i2c_write_data_nack_latches :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            i2c_regular_write() &&
                                            !data_nack_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0]
                                            ##1
                                            data_nack_q);

  ap_i2c_write_data_nack_stops_no_more_data :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            i2c_regular_write() &&
                                            data_nack_q
                                            |->
                                            gen_stop_o &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit)
  else $error("flow_active_sva: I2C write must stop with no further data byte after a data NACK in %m");

  cp_i2c_write_data_nack_stops_no_more_data :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            i2c_regular_write() &&
                                            data_nack_q &&
                                            gen_stop_o &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit);

  ap_data_nack_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            data_nack_q &&
                                            !addr_nack_q
                                            |->
                                            data_nack_resp_matches_current_len())
  else $error("flow_active_sva: data NACK response status/length mismatch in %m");

  cp_data_nack_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            data_nack_q &&
                                            !addr_nack_q &&
                                            data_nack_resp_matches_current_len());

  cp_i2c_write_data_nack_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            i2c_regular_write() &&
                                            data_nack_q &&
                                            !addr_nack_q &&
                                            data_nack_resp_matches_current_len());

  // ----------------------------------------------------------------------
  // I2C_006 — FM-equivalent timing selection (SVA-only, no vseq)
  //
  // I2C_T_* timing is selected only for legacy I2C devices; an I3C transfer
  // never asserts I2C timing. The 400 kHz-equivalent I2C_T_* reset defaults
  // are checked in csr_registers_sva, and the active_t_* = use_i2c_timing ?
  // i2c_t_* : t_* mux lives in controller_active.
  // ----------------------------------------------------------------------
  ap_i2c_timing_only_for_i2c_device :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            use_i2c_timing_o
                                            |->
                                            dat_entry.device)
  else $error("flow_active_sva: I2C timing must be selected only for legacy I2C devices in %m");

  cp_timing_mode_i2c :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            i2c_regular_xfer() &&
                                            i2c_active_state() &&
                                            use_i2c_timing_o);

  cp_timing_mode_i3c :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            (sdr_regular_i3c_write() || sdr_regular_i3c_read()) &&
                                            (state_q == InitWrite ||
                                             state_q == InitRead ||
                                             state_q == IssueI3CWrite ||
                                             state_q == IssueI3CRead) &&
                                            !use_i2c_timing_o);

  // ----------------------------------------------------------------------
  // Immediate Data Transfer (ImmediateDataTransfer, cp=0) — IMM_001..IMM_006
  //
  // Only the OD/PP phasing of immediate transfers is asserted today (via
  // ap_sel_od_pp_matches_expected / expected_imm_sel_od_pp). These add inline
  // byte integrity, dtt>4 / toc=0 NotSupported rejection, Success/length, the
  // I2C-immediate data-NACK boundary, and the HC-abort flow. ERR_004 owns the
  // data-NACK response encoding; abort response encoding is owned by ERR_012.
  // NotSupported is owned by IMM_002/IMM_003.
  // ----------------------------------------------------------------------

  // IMM_001/002/003: I3C immediate inline bytes are driven in descriptor order.
  ap_i3c_imm_data_byte_matches_desc :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CWrite &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            !dat_entry.device &&
                                            !abort_i &&
                                            !addr_nack_q &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0] &&
                                            (((issue_phase_q - PhaseDataStart) >> 1) <
                                             {5'h0, imm_desc.dtt})
                                            |->
                                            bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === expected_imm_data_byte(
      imm_desc, issue_phase_q
  ))
  else $error("flow_active_sva: I3C immediate data byte must match cmd descriptor byte in %m");

  cp_i3c_imm_data_byte_matches_desc :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CWrite &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            !dat_entry.device &&
                                            !addr_nack_q &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0] &&
                                            (((issue_phase_q - PhaseDataStart) >> 1) <
                                             {5'h0, imm_desc.dtt}) &&
                                            bus_tx_req_byte &&
                                            bus_tx_req_value === expected_imm_data_byte(
      imm_desc, issue_phase_q
  ));

  // IMM_001/002/003: I3C immediate T-bit parity for each inline byte.
  ap_i3c_imm_tbit_parity :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CWrite &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            !dat_entry.device &&
                                            !addr_nack_q &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            (((issue_phase_q - PhaseDataStart) >> 1) <
                                             {5'h0, imm_desc.dtt})
                                            |->
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            bus_tx_req_value ===
                                            {7'b0, ~^expected_imm_data_byte(imm_desc, issue_phase_q)})
  else $error("flow_active_sva: I3C immediate T-bit parity mismatch in %m");

  cp_i3c_imm_tbit_parity :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI3CWrite &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            !dat_entry.device &&
                                            !addr_nack_q &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            (((issue_phase_q - PhaseDataStart) >> 1) <
                                             {5'h0, imm_desc.dtt}) &&
                                            bus_tx_req_bit &&
                                            bus_tx_req_value ===
                                            {7'b0, ~^expected_imm_data_byte(imm_desc, issue_phase_q)});

  // IMM_004: I2C immediate address byte = {static_address, W}.
  ap_i2c_imm_addr_uses_static_address :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitWrite &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            dat_entry.device &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte
                                            |->
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === {dat_entry.static_address, Write})
  else $error("flow_active_sva: I2C immediate address byte must be static address + W in %m");

  cp_i2c_imm_addr_uses_static_address :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitWrite &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            dat_entry.device &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte &&
                                            bus_tx_req_value === {dat_entry.static_address, Write});

  // IMM_004: I2C immediate inline bytes are driven in descriptor order.
  ap_i2c_imm_data_byte_matches_desc :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            dat_entry.device &&
                                            !abort_i &&
                                            !addr_nack_q &&
                                            !data_nack_q &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0] &&
                                            (((issue_phase_q - PhaseDataStart) >> 1) <
                                             {5'h0, imm_desc.dtt})
                                            |->
                                            bus_tx_req_byte &&
                                            bus_tx_req_value === expected_imm_data_byte(
      imm_desc, issue_phase_q
  ))
  else $error("flow_active_sva: I2C immediate data byte must match cmd descriptor byte in %m");

  cp_i2c_imm_data_byte_matches_desc :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            dat_entry.device &&
                                            !addr_nack_q &&
                                            !data_nack_q &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0] &&
                                            (((issue_phase_q - PhaseDataStart) >> 1) <
                                             {5'h0, imm_desc.dtt}) &&
                                            bus_tx_req_byte &&
                                            bus_tx_req_value === expected_imm_data_byte(
      imm_desc, issue_phase_q
  ));

  // ERR_010: every unsupported descriptor is rejected in FetchDAT before DAT or bus activity.
  ap_invalid_cmd_rejected_before_access :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchDAT &&
                                            invalid_cmd_desc()
                                            |->
                                            (!dat_read_valid_hw_o &&
                                             !gen_start_o &&
                                             !gen_rstart_o &&
                                             !gen_stop_o &&
                                             !bus_tx_req_byte &&
                                             !bus_tx_req_bit &&
                                             !bus_rx_req_byte &&
                                             !bus_rx_req_bit &&
                                             !bus_rx_req_bit_handoff)
                                            ##1 state_q == WriteResp)
  else $error("flow_active_sva: invalid command must be rejected before DAT or bus activity in %m");

  cp_invalid_cmd_rejected_before_access :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchDAT &&
                                            invalid_cmd_desc() &&
                                            !dat_read_valid_hw_o &&
                                            !gen_start_o &&
                                            !gen_rstart_o &&
                                            !gen_stop_o &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            !bus_rx_req_byte &&
                                            !bus_rx_req_bit &&
                                            !bus_rx_req_bit_handoff
                                            ##1 state_q == WriteResp);

  ap_invalid_cmd_not_supported_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            invalid_cmd_desc()
                                            |->
                                            not_supported_resp_matches_current_len() &&
                                            (resp_queue_wdata[15:0] == 16'h0000))
  else $error("flow_active_sva: invalid command response must be NotSupported with length 0 in %m");

  cp_invalid_cmd_not_supported_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            invalid_cmd_desc() &&
                                            not_supported_resp_matches_current_len() &&
                                            (resp_queue_wdata[15:0] == 16'h0000));

  // IMM_002 (negative): the dtt>4 response descriptor is NotSupported (len 0).
  ap_imm_dtt_gt4_not_supported_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            imm_desc.dtt > 3'd4
                                            |->
                                            not_supported_resp_matches_current_len())
  else $error("flow_active_sva: immediate dtt>4 response must be NotSupported in %m");

  cp_imm_dtt_gt4_not_supported_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            imm_desc.dtt > 3'd4 &&
                                            not_supported_resp_matches_current_len());

  // DAA_007 / ERR_011: reject invalid AddressAssignment descriptors before DAT or bus access.
  ap_addr_assign_invalid_rejected_before_access :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchDAT &&
                                            cmd_attr == AddressAssignment &&
                                            invalid_addr_assign_desc()
                                            |->
                                            (!dat_read_valid_hw_o &&
                                             !gen_start_o &&
                                             !gen_rstart_o &&
                                             !gen_stop_o &&
                                             !bus_tx_req_byte &&
                                             !bus_tx_req_bit)
                                            ##1 state_q == WriteResp)
  else $error("flow_active_sva: invalid AddressAssignment must be rejected before DAT or bus access in %m");

  cp_addr_assign_invalid_rejected_before_access :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchDAT &&
                                            cmd_attr == AddressAssignment &&
                                            invalid_addr_assign_desc() &&
                                            !dat_read_valid_hw_o
                                            ##1 state_q == WriteResp);

  ap_addr_assign_invalid_not_supported_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == AddressAssignment &&
                                            invalid_addr_assign_desc()
                                            |->
                                            not_supported_resp_matches_current_len())
  else $error("flow_active_sva: invalid AddressAssignment response must be NotSupported with length 0 in %m");

  cp_addr_assign_invalid_not_supported_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == AddressAssignment &&
                                            invalid_addr_assign_desc() &&
                                            not_supported_resp_matches_current_len());

  ap_addr_assign_reserved_addr_not_supported_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == AddressAssignment &&
                                            daa_invalid_addr_i
                                            |->
                                            not_supported_resp_matches_current_len())
  else $error("flow_active_sva: AddressAssignment reserved DAT address response must be NotSupported with current length in %m");

  cp_addr_assign_reserved_addr_not_supported_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == AddressAssignment &&
                                            daa_invalid_addr_i &&
                                            not_supported_resp_matches_current_len());

  ap_addr_assign_reserved_addr_uses_common_stop_path :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueDAA &&
                                            cmd_attr == AddressAssignment &&
                                            issue_phase_q > 8'd4 &&
                                            daa_invalid_addr_i &&
                                            !entdaa_stop_req_q &&
                                            !daa_wr_busy_q
                                            |->
                                            (gen_stop_o &&
                                             !resp_queue_wvalid))
  else $error("flow_active_sva: AddressAssignment reserved DAT address must request STOP before response in %m");

  cp_addr_assign_reserved_addr_uses_common_stop_path :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueDAA &&
                                            cmd_attr == AddressAssignment &&
                                            issue_phase_q > 8'd4 &&
                                            daa_invalid_addr_i &&
                                            !entdaa_stop_req_q &&
                                            !daa_wr_busy_q &&
                                            gen_stop_o &&
                                            !resp_queue_wvalid);

  // ERR_001 / DAA_001: successful ENTDAA responses use the common Success/TID/length
  // encoding. The length is the number of committed DAA result bytes.
  ap_daa_success_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == AddressAssignment &&
                                            !invalid_addr_assign_desc() &&
                                            !addr_nack_q &&
                                            !daa_nack_error_q &&
                                            !rx_overflow_q &&
                                            !not_supported_q &&
                                            !hc_aborted_q
                                            |->
                                            success_resp_matches_current_len())
  else $error("flow_active_sva: ENTDAA success response status/length mismatch in %m");

  cp_daa_success_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == AddressAssignment &&
                                            !invalid_addr_assign_desc() &&
                                            !addr_nack_q &&
                                            !daa_nack_error_q &&
                                            !rx_overflow_q &&
                                            !not_supported_q &&
                                            !hc_aborted_q &&
                                            success_resp_matches_current_len());

  // IMM_003: toc=0 immediate still sends all dtt bytes, then NotSupported.
  ap_imm_toc0_not_supported_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            !imm_desc.toc &&
                                            imm_desc.dtt <= 3'd4 &&
                                            !addr_nack_q &&
                                            !data_nack_q &&
                                            !hc_aborted_q
                                            |->
                                            not_supported_resp_matches_current_len())
  else $error("flow_active_sva: immediate toc=0 response must be NotSupported with bytes-sent length in %m");

  cp_imm_toc0_not_supported_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            !imm_desc.toc &&
                                            imm_desc.dtt <= 3'd4 &&
                                            !addr_nack_q &&
                                            !data_nack_q &&
                                            !hc_aborted_q &&
                                            not_supported_resp_matches_current_len());

  // IMM_003: an immediate transfer never emits a Repeated START / continuation.
  ap_imm_no_continuation_rstart :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            imm_private_active_state()
                                            |->
                                            (!gen_rstart_o ||
                                             legal_imm_private_addr_rstart()))
  else $error("flow_active_sva: immediate transfer must not emit a continuation Repeated START in %m");

  cp_imm_no_continuation_rstart :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            imm_private_active_state() &&
                                            (!gen_rstart_o ||
                                             legal_imm_private_addr_rstart()));

  // IMM_001/003(toc=1)/004: successful immediate response with correct length.
  ap_imm_success_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            !invalid_cmd_desc() &&
                                            imm_desc.toc &&
                                            imm_desc.dtt <= 3'd4 &&
                                            !addr_nack_q &&
                                            !data_nack_q &&
                                            !hc_aborted_q &&
                                            !tx_underflow_q &&
                                            !rx_overflow_q
                                            |->
                                            success_resp_matches_current_len())
  else $error("flow_active_sva: immediate success response status/length mismatch in %m");

  cp_imm_success_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            !invalid_cmd_desc() &&
                                            imm_desc.toc &&
                                            imm_desc.dtt <= 3'd4 &&
                                            !addr_nack_q &&
                                            !data_nack_q &&
                                            !hc_aborted_q &&
                                            !tx_underflow_q &&
                                            !rx_overflow_q &&
                                            success_resp_matches_current_len());

  // ERR_004: I2C immediate data NACK is latched from the ACK sub-phase...
  ap_i2c_imm_data_nack_latches :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            dat_entry.device &&
                                            !data_nack_q &&
                                            !addr_nack_q &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            (((issue_phase_q - PhaseDataStart) >> 1) <
                                             {5'h0, imm_desc.dtt}) &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0]
                                            |=>
                                            data_nack_q)
  else $error("flow_active_sva: I2C immediate data NACK must latch data_nack_q in %m");

  cp_i2c_imm_data_nack_latches :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            dat_entry.device &&
                                            !data_nack_q &&
                                            !addr_nack_q &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            (((issue_phase_q - PhaseDataStart) >> 1) <
                                             {5'h0, imm_desc.dtt}) &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0]
                                            ##1
                                            data_nack_q);

  // ERR_004: ...and then STOP is generated with no further inline byte sent.
  ap_i2c_imm_data_nack_stops_no_more_data :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            dat_entry.device &&
                                            data_nack_q
                                            |->
                                            gen_stop_o &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit)
  else $error("flow_active_sva: I2C immediate must stop with no further byte after a data NACK in %m");

  cp_i2c_imm_data_nack_stops_no_more_data :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueI2CWrite &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            dat_entry.device &&
                                            data_nack_q &&
                                            gen_stop_o &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit);

  cp_i2c_imm_data_nack_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            i2c_immediate_write() &&
                                            data_nack_q &&
                                            !addr_nack_q &&
                                            data_nack_resp_matches_current_len());

  // IMM_006: HC abort during immediate data phase sets hc_aborted...
  ap_imm_abort_sets_hc_aborted :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            $rose(abort_i) &&
                                            imm_active_state()
                                            |=>
                                            hc_aborted_q)
  else $error("flow_active_sva: HC abort in immediate data phase must set hc_aborted in %m");

  cp_imm_abort_sets_hc_aborted :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            $rose(abort_i) &&
                                            imm_active_state()
                                            ##1
                                            hc_aborted_q);

  // IMM_006: ...and forces STOP (never a continuation RSTART) with no further data.
  ap_imm_abort_stops_no_continuation :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            $rose(abort_i) &&
                                            imm_active_state()
                                            |-> ##[0:512]
                                            gen_stop_o &&
                                            !gen_rstart_o &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit)
  else $error("flow_active_sva: HC abort in immediate data phase must STOP without continuation in %m");

  cp_imm_abort_stops_no_continuation :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            $rose(abort_i) &&
                                            imm_active_state()
                                            ##[0:512]
                                            gen_stop_o &&
                                            !gen_rstart_o &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit);

  cp_imm_abort_reaches_writeresp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            abort_i &&
                                            imm_active_state()
                                            ##[1:512]
                                            state_q == WriteResp &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            hc_aborted_q);

  // IMM_001/002: private-start prefix selection — broadcast-header detour only
  // when enabled, straight to InitWrite otherwise (cp_private_start_prefix).
  cp_imm_bcast_header_path :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitDAT &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            !cont_pending_q &&
                                            !dat_entry.device &&
                                            broadcast_header_enable_i &&
                                            imm_desc.dtt <= 3'd4 &&
                                            !dat_read_valid_hw_o
                                            ##1
                                            state_q == I3CBcastHeader);

  cp_imm_private_no_bcast :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitDAT &&
                                            cmd_attr == ImmediateDataTransfer &&
                                            !imm_desc.cp &&
                                            !cont_pending_q &&
                                            !dat_entry.device &&
                                            !broadcast_header_enable_i &&
                                            imm_desc.dtt <= 3'd4 &&
                                            !dat_read_valid_hw_o
                                            ##1
                                            state_q == InitWrite);

  // IMM_001/002: the broadcast header (when taken) drives the 0x7E reserved
  // address, not a target address — confirms the 7E+W preamble.
  ap_bcast_header_drives_7e :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == I3CBcastHeader &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte
                                            |->
                                            bus_tx_req_value === {I3C_RSVD_ADDR, Write})
  else $error("flow_active_sva: broadcast header must drive the 0x7E reserved address in %m");

  cp_bcast_header_drives_7e :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == I3CBcastHeader &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte &&
                                            bus_tx_req_value === {I3C_RSVD_ADDR, Write});

  // Testplan CCC_002..CCC_005 share one frame checker per form.
  // Opcode-specific covers below retain independent ENEC/DISEC closure.
  ap_ccc_broadcast_frame :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   state_q == IssueImmediateCcc &&
                   ccc_broadcast_supported_active()
                   |-> ccc_broadcast_frame_matches())
  else $error("flow_active_sva: supported broadcast CCC frame mismatch in %m");

  ap_ccc_broadcast_no_rstart :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   state_q == IssueImmediateCcc &&
                   ccc_broadcast_supported_active()
                   |-> !gen_rstart_o)
  else $error("flow_active_sva: supported broadcast CCC issued repeated START in %m");

  ap_ccc_direct_frame :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   state_q == IssueImmediateCcc &&
                   ccc_direct_supported_active()
                   |-> ccc_direct_frame_matches())
  else $error("flow_active_sva: supported direct CCC frame mismatch in %m");

  ap_ccc_supported_success_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   state_q == WriteResp &&
                   ccc_supported_active()
                   |->
                   resp_queue_wvalid &&
                   resp_queue_wdata[31:28] == Success &&
                   resp_queue_wdata[27:24] == cmd_tid &&
                   resp_queue_wdata[23:16] == 8'h00 &&
                   resp_queue_wdata[15:0] == 16'd1)
  else $error("flow_active_sva: supported CCC success response mismatch in %m");

  // CCC_002: broadcast ENEC drives opcode 0x00, one Target Events byte, no
  // repeated START, and reports the event byte count on success.

  cp_ccc002_enec_opcode :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_broadcast_enec_active() &&
                                            issue_phase_q == 8'd3 &&
                                            bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === 8'(ENEC));


  cp_ccc002_enec_opcode_tbit :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_broadcast_enec_active() &&
                                            issue_phase_q == 8'd4 &&
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            bus_tx_req_value === {7'b0, ~^8'(ENEC)});


  cp_ccc002_enec_event_byte :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_broadcast_enec_active() &&
                                            issue_phase_q == 8'd5 &&
                                            bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === imm_desc.def_or_data_byte1);


  cp_ccc002_enec_event_tbit :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_broadcast_enec_active() &&
                                            issue_phase_q == 8'd6 &&
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            bus_tx_req_value ===
                                            {7'b0, ~^imm_desc.def_or_data_byte1});


  cp_ccc002_enec_no_rstart :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_broadcast_enec_active() &&
                                            !gen_rstart_o);


  cp_ccc002_enec_success_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            ccc_broadcast_enec_active() &&
                                            resp_queue_wvalid &&
                                            resp_queue_wdata[31:28] == Success &&
                                            resp_queue_wdata[27:24] == cmd_tid &&
                                            resp_queue_wdata[23:16] == 8'h00 &&
                                            resp_queue_wdata[15:0] == 16'd1);

  // CCC_003: broadcast DISEC drives opcode 0x01, one Target Events byte, no
  // repeated START, and reports the event byte count on success.

  cp_ccc003_disec_opcode :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_broadcast_disec_active() &&
                                            issue_phase_q == 8'd3 &&
                                            bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === 8'(DISEC));


  cp_ccc003_disec_opcode_tbit :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_broadcast_disec_active() &&
                                            issue_phase_q == 8'd4 &&
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            bus_tx_req_value === {7'b0, ~^8'(DISEC)});


  cp_ccc003_disec_event_byte :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_broadcast_disec_active() &&
                                            issue_phase_q == 8'd5 &&
                                            bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === imm_desc.def_or_data_byte1);


  cp_ccc003_disec_event_tbit :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_broadcast_disec_active() &&
                                            issue_phase_q == 8'd6 &&
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            bus_tx_req_value ===
                                            {7'b0, ~^imm_desc.def_or_data_byte1});


  cp_ccc003_disec_no_rstart :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_broadcast_disec_active() &&
                                            !gen_rstart_o);


  cp_ccc003_disec_success_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            ccc_broadcast_disec_active() &&
                                            resp_queue_wvalid &&
                                            resp_queue_wdata[31:28] == Success &&
                                            resp_queue_wdata[27:24] == cmd_tid &&
                                            resp_queue_wdata[23:16] == 8'h00 &&
                                            resp_queue_wdata[15:0] == 16'd1);

  // CCC_004: direct ENEC drives opcode 0x80 after the 0x7E broadcast header,
  // emits a repeated START, addresses the selected target, sends one Target
  // Events byte, then STOPs and reports the event byte count on success.

  cp_ccc004_direct_enec_opcode :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_enec_active() &&
                                            issue_phase_q == 8'd3 &&
                                            bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === 8'(DIR_ENEC));


  cp_ccc004_direct_enec_opcode_tbit :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_enec_active() &&
                                            issue_phase_q == 8'd4 &&
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            bus_tx_req_value === {7'b0, ~^8'(DIR_ENEC)});


  cp_ccc004_direct_enec_rstart :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_enec_active() &&
                                            issue_phase_q == 8'd5 &&
                                            gen_rstart_o &&
                                            !gen_start_o &&
                                            !gen_stop_o);


  cp_ccc004_direct_enec_target_addr :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_enec_active() &&
                                            issue_phase_q == 8'd6 &&
                                            bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === {dat_entry.dynamic_address, Write});


  cp_ccc004_direct_enec_target_ack_sample :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_enec_active() &&
                                            issue_phase_q == 8'd7 &&
                                            bus_rx_req_bit_handoff &&
                                            !bus_rx_req_bit &&
                                            !bus_rx_req_byte &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit);


  cp_ccc004_direct_enec_event_byte :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_enec_active() &&
                                            issue_phase_q == 8'd8 &&
                                            bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === imm_desc.def_or_data_byte1);


  cp_ccc004_direct_enec_event_tbit :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_enec_active() &&
                                            issue_phase_q == 8'd9 &&
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            bus_tx_req_value ===
                                            {7'b0, ~^imm_desc.def_or_data_byte1});


  cp_ccc004_direct_enec_stop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_enec_active() &&
                                            issue_phase_q == 8'd10 &&
                                            gen_stop_o &&
                                            !gen_start_o &&
                                            !gen_rstart_o);


  cp_ccc004_direct_enec_success_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            ccc_direct_enec_active() &&
                                            resp_queue_wvalid &&
                                            resp_queue_wdata[31:28] == Success &&
                                            resp_queue_wdata[27:24] == cmd_tid &&
                                            resp_queue_wdata[23:16] == 8'h00 &&
                                            resp_queue_wdata[15:0] == 16'd1);

  // CCC_005: direct DISEC drives opcode 0x81 after the 0x7E broadcast header,
  // emits a repeated START, addresses the selected target, sends one Target
  // Events byte, then STOPs and reports the event byte count on success.

  cp_ccc005_direct_disec_opcode :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_disec_active() &&
                                            issue_phase_q == 8'd3 &&
                                            bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === 8'(DIR_DISEC));


  cp_ccc005_direct_disec_opcode_tbit :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_disec_active() &&
                                            issue_phase_q == 8'd4 &&
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            bus_tx_req_value === {7'b0, ~^8'(DIR_DISEC)});


  cp_ccc005_direct_disec_rstart :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_disec_active() &&
                                            issue_phase_q == 8'd5 &&
                                            gen_rstart_o &&
                                            !gen_start_o &&
                                            !gen_stop_o);


  cp_ccc005_direct_disec_target_addr :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_disec_active() &&
                                            issue_phase_q == 8'd6 &&
                                            bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === {dat_entry.dynamic_address, Write});


  cp_ccc005_direct_disec_target_ack_sample :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_disec_active() &&
                                            issue_phase_q == 8'd7 &&
                                            bus_rx_req_bit_handoff &&
                                            !bus_rx_req_bit &&
                                            !bus_rx_req_byte &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit);


  cp_ccc005_direct_disec_event_byte :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_disec_active() &&
                                            issue_phase_q == 8'd8 &&
                                            bus_tx_req_byte &&
                                            !bus_tx_req_bit &&
                                            bus_tx_req_value === imm_desc.def_or_data_byte1);


  cp_ccc005_direct_disec_event_tbit :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_disec_active() &&
                                            issue_phase_q == 8'd9 &&
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            bus_tx_req_value ===
                                            {7'b0, ~^imm_desc.def_or_data_byte1});


  cp_ccc005_direct_disec_stop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueImmediateCcc &&
                                            ccc_direct_disec_active() &&
                                            issue_phase_q == 8'd10 &&
                                            gen_stop_o &&
                                            !gen_start_o &&
                                            !gen_rstart_o);


  cp_ccc005_direct_disec_success_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            ccc_direct_disec_active() &&
                                            resp_queue_wvalid &&
                                            resp_queue_wdata[31:28] == Success &&
                                            resp_queue_wdata[27:24] == cmd_tid &&
                                            resp_queue_wdata[23:16] == 8'h00 &&
                                            resp_queue_wdata[15:0] == 16'd1);

  // ERR_008: RESP FIFO backpressure holds both success and error descriptors in
  // WriteResp. The descriptor stays stable until one ready/valid handshake, then
  // the FSM exits so the same command cannot enqueue a duplicate response.
  ap_resp_full_success_holds_pending_write :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            active_wroc &&
                                            !completion_error_q &&
                                            !resp_queue_wready_i
                                            |->
                                            state_d == WriteResp &&
                                            resp_queue_wvalid)
  else $error("flow_active_sva: full RESP FIFO must stall a successful response in WriteResp in %m");

  cp_resp_full_success_holds_pending_write :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            active_wroc &&
                                            !completion_error_q &&
                                            !resp_queue_wready_i &&
                                            state_d == WriteResp &&
                                            resp_queue_wvalid);

  ap_resp_full_error_holds_pending_write :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            completion_error_q &&
                                            !resp_queue_wready_i
                                            |->
                                            state_d == WriteResp &&
                                            resp_queue_wvalid)
  else $error("flow_active_sva: full RESP FIFO must stall an error response in WriteResp in %m");

  cp_resp_full_error_holds_pending_write :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            completion_error_q &&
                                            !resp_queue_wready_i &&
                                            state_d == WriteResp &&
                                            resp_queue_wvalid);

  ap_resp_full_keeps_descriptor_stable :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            !resp_queue_wready_i
                                            |=>
                                            state_q == WriteResp &&
                                            resp_queue_wvalid &&
                                            $stable(resp_queue_wdata))
  else $error("flow_active_sva: pending response descriptor changed under RESP backpressure in %m");

  cp_resp_full_keeps_descriptor_stable :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            !resp_queue_wready_i
                                            ##1
                                            state_q == WriteResp &&
                                            resp_queue_wvalid &&
                                            $stable(resp_queue_wdata));

  ap_resp_backpressure_release_writes_once :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            resp_queue_wvalid &&
                                            resp_queue_wready_i &&
                                            $past(state_q == WriteResp &&
                                                  !resp_queue_wready_i)
                                            |=>
                                            state_q == Idle &&
                                            !resp_queue_wvalid)
  else $error("flow_active_sva: released response must handshake once then exit WriteResp in %m");

  cp_resp_backpressure_release_writes_once :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            resp_queue_wvalid &&
                                            resp_queue_wready_i &&
                                            $past(state_q == WriteResp &&
                                                  !resp_queue_wready_i)
                                            ##1
                                            state_q == Idle &&
                                            !resp_queue_wvalid);

  // ERR_012: WROC suppresses successful responses, never suppresses errors,
  // and removes RESP FIFO backpressure from successful toc=0 continuations.
  ap_wroc0_success_suppresses_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            ((state_q == IssueDAA || state_q == IssueI3CWrite || state_q == IssueI2CWrite ||
                                              state_q == IssueI3CRead || state_q == IssueI2CRead) ||
                                             state_q == IssueImmediateCcc) &&
                                            !active_wroc &&
                                            !completion_error_q &&
                                            (state_d == Idle || state_d == WriteResp)
                                            |->
                                            state_d == Idle && !resp_queue_wvalid)
  else $error("flow_active_sva: successful wroc=0 completion must suppress RESP in %m");

  cp_wroc0_success_suppresses_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            ((state_q == IssueDAA || state_q == IssueI3CWrite || state_q == IssueI2CWrite ||
                                              state_q == IssueI3CRead || state_q == IssueI2CRead) ||
                                             state_q == IssueImmediateCcc) &&
                                            !active_wroc &&
                                            !completion_error_q &&
                                            state_d == Idle &&
                                            !resp_queue_wvalid);

  ap_wroc1_success_enters_write_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            ((state_q == IssueDAA || state_q == IssueI3CWrite || state_q == IssueI2CWrite ||
                                              state_q == IssueI3CRead || state_q == IssueI2CRead) ||
                                             state_q == IssueImmediateCcc) &&
                                            active_wroc &&
                                            !completion_error_q &&
                                            (state_d == Idle || state_d == WriteResp)
                                            |->
                                            state_d == WriteResp
                                            ##1
                                            state_q == WriteResp && resp_queue_wvalid)
  else $error("flow_active_sva: successful wroc=1 completion must write RESP in %m");

  cp_wroc1_success_enters_write_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            ((state_q == IssueDAA || state_q == IssueI3CWrite || state_q == IssueI2CWrite ||
                                              state_q == IssueI3CRead || state_q == IssueI2CRead) ||
                                             state_q == IssueImmediateCcc) &&
                                            active_wroc &&
                                            !completion_error_q &&
                                            state_d == WriteResp
                                            ##1
                                            state_q == WriteResp && resp_queue_wvalid);

  ap_wroc0_error_override_writes_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q != WriteResp &&
                                            !active_wroc &&
                                            completion_error_q &&
                                            (state_d == Idle || state_d == WriteResp)
                                            |->
                                            state_d == WriteResp
                                            ##1
                                            state_q == WriteResp && resp_queue_wvalid)
  else $error("flow_active_sva: wroc=0 must not suppress an error response in %m");

  cp_wroc0_error_override_writes_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q != WriteResp &&
                                            !active_wroc &&
                                            completion_error_q &&
                                            state_d == WriteResp
                                            ##1
                                            state_q == WriteResp && resp_queue_wvalid);

  ap_wroc0_continuation_ignores_resp_ready :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            (sdr_write_done_ready() || sdr_read_done_ready()) &&
                                            !reg_desc.toc &&
                                            !reg_desc.wroc &&
                                            next_cmd_available &&
                                            next_cmd_supported
                                            |->
                                            cmd_queue_rready_o &&
                                            !resp_queue_wvalid &&
                                            !gen_stop_o)
  else $error("flow_active_sva: wroc=0 continuation must not depend on RESP ready in %m");

  cp_wroc0_continuation_ignores_resp_ready :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            (sdr_write_done_ready() || sdr_read_done_ready()) &&
                                            !reg_desc.toc &&
                                            !reg_desc.wroc &&
                                            next_cmd_available &&
                                            next_cmd_supported &&
                                            !resp_queue_wready_i &&
                                            cmd_queue_rready_o &&
                                            !resp_queue_wvalid &&
                                            !gen_stop_o);

  ap_wroc1_continuation_waits_for_resp_ready :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            (sdr_write_done_ready() || sdr_read_done_ready()) &&
                                            !reg_desc.toc &&
                                            reg_desc.wroc &&
                                            next_cmd_available &&
                                            next_cmd_supported &&
                                            !resp_queue_wready_i
                                            |->
                                            !cmd_queue_rready_o)
  else $error("flow_active_sva: wroc=1 continuation must wait for RESP ready in %m");

  cp_wroc1_continuation_waits_for_resp_ready :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            (sdr_write_done_ready() || sdr_read_done_ready()) &&
                                            !reg_desc.toc &&
                                            reg_desc.wroc &&
                                            next_cmd_available &&
                                            next_cmd_supported &&
                                            !resp_queue_wready_i &&
                                            !cmd_queue_rready_o);

endmodule

bind flow_active flow_active_sva #(
    .HciCmdDataWidth (HciCmdDataWidth),
    .HciTxDataWidth  (HciTxDataWidth),
    .HciRxDataWidth  (HciRxDataWidth),
    .HciRespDataWidth(HciRespDataWidth),
    .DatDepth        (DatDepth)
) u_flow_active_sva (
    .clk_i,
    .rst_ni,
    .state_q,
    .state_d,
    .sel_od_pp_o,
    .sel_i3c_i2c_o,
    .use_i2c_timing_o,
    .scl_use_od_low_o,
    .issue_phase_q,
    .cmd_attr,
    .cmd_dir,
    .imm_desc,
    .reg_desc,
    .aa_desc,
    .dat_entry,
    .dat_read_valid_hw_o,
    .dat_index_hw_o,
    .remaining_len_q,
    .resp_data_len_q,
    .short_read_q,
    .short_read_error,
    .addr_nack_q,
    .data_nack_q,
    .daa_nack_error_q,
    .daa_invalid_addr_i,
    .not_supported_q,
    .addr_after_rstart_q,
    .next_start_is_rstart_q,
    .cont_pending_q,
    .active_wroc,
    .completion_error_q,
    .broadcast_header_enable_i,
    .cmd_tid,
    .gen_start_o,
    .gen_rstart_o,
    .gen_stop_o,
    .tx_queue_empty_i,
    .tx_queue_rvalid_i,
    .tx_queue_rready_o,
    .tx_underflow_q,
    .rx_overflow_q,
    .daa_wr_busy_q,
    .entdaa_stop_req_q,
    .read_takeover_pending_q,
    .rx_queue_full_i,
    .rx_queue_wvalid,
    .rx_queue_wready_i,
    .rx_queue_wdata,
    .resp_queue_wready_i,
    .cmd_queue_rready_o,
    .bus_tx_idle_i,
    .bus_rx_idle_i,
    .next_cmd_available,
    .next_cmd_supported,
    .bus_tx_req_byte,
    .bus_tx_req_bit,
    .bus_rx_req_byte,
    .bus_rx_req_bit,
    .bus_rx_req_bit_handoff,
    .bus_tx_req_value,
    .current_tx_byte,
    .rx_dword_q,
    .rx_byte_idx_q,
    .bus_tx_done_i,
    .bus_rx_done_i,
    .bus_rx_data_i,
    .scl_stop_done_q,
    .hc_aborted_q,
    .abort_i,
    .read_abort_term_q,
    .resp_queue_wvalid,
    .resp_queue_wdata
);
