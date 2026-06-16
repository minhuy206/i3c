module flow_active_sva
  import controller_pkg::cmd_transfer_dir_e;
  import controller_pkg::dat_entry_t;
  import controller_pkg::Read;
  import controller_pkg::Write;
  import i3c_pkg::AddressAssignment;
  import i3c_pkg::AddrHeader;
  import i3c_pkg::I3cShortReadErr;
  import i3c_pkg::NotSupported;
  import i3c_pkg::Ovl;
  import i3c_pkg::Success;
  import i3c_pkg::i3c_cmd_attr_e;
  import i3c_pkg::ImmediateDataTransfer;
  import i3c_pkg::immediate_data_trans_desc_t;
  import i3c_pkg::regular_trans_desc_t;
  import i3c_pkg::RegularTransfer;
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
    input logic                                              sel_od_pp_o,
    input logic                                              use_i2c_timing_o,
    input logic                                              scl_use_od_low_o,
    input logic                       [                 7:0] issue_phase_q,
    input i3c_cmd_attr_e                                     cmd_attr,
    input cmd_transfer_dir_e                                 cmd_dir,
    input immediate_data_trans_desc_t                        imm_desc,
    input regular_trans_desc_t                               reg_desc,
    input dat_entry_t                                        dat_entry,
    input logic                                              dat_read_valid_hw_o,
    input logic                       [            DatAw-1:0] dat_index_hw_o,
    input logic                       [                15:0] remaining_len_q,
    input logic                       [                15:0] resp_data_len_q,
    input logic                                              short_read_q,
    input logic                                              addr_nack_q,
    input logic                                              addr_after_rstart_q,
    input logic                                              next_start_is_rstart_q,
    input logic                                              cont_pending_q,
    input logic                                              broadcast_header_enable_i,
    input logic                       [                 3:0] cmd_tid,
    input logic                                              gen_start_o,
    input logic                                              gen_rstart_o,
    input logic                                              gen_stop_o,
    input logic                                              gen_clock_o,
    input logic                                              scl_gen_done_i,
    input logic                                              tx_queue_empty_i,
    input logic                                              tx_queue_rvalid_i,
    input logic                                              tx_queue_rready_o,
    input logic                                              tx_underflow_q,
    input logic                                              rx_overflow_q,
    input logic                                              rx_queue_full_i,
    input logic                                              rx_queue_wvalid,
    input logic                                              rx_queue_wready_i,
    input logic                       [  HciRxDataWidth-1:0] rx_queue_wdata,
    input logic                                              resp_queue_wready_i,
    input logic                                              cmd_queue_rready_o,
    input logic                                              hc_seq_cancel_event_o,
    input logic                                              hc_err_cmd_seq_timeout_event_o,
    input logic                                              bus_tx_idle_i,
    input logic                                              bus_rx_idle_i,
    input logic                                              next_cmd_available,
    input logic                                              next_cmd_supported,
    input logic                                              bus_tx_req_byte,
    input logic                                              bus_tx_req_bit,
    input logic                                              bus_rx_req_byte,
    input logic                                              bus_rx_req_bit,
    input logic                       [                 7:0] bus_tx_req_value,
    input logic                       [                 7:0] current_tx_byte,
    input logic                       [                31:0] rx_dword_q,
    input logic                       [                 1:0] rx_byte_idx_q,
    input logic                                              bus_rx_done_i,
    input logic                       [                 7:0] bus_rx_data_i,
    input logic                                              scl_stop_done_q,
    input logic                                              hc_aborted_q,
    input logic                                              resp_queue_wvalid,
    input logic                       [HciRespDataWidth-1:0] resp_queue_wdata
);

  localparam logic [3:0] Idle = 4'd0;
  localparam logic [3:0] WaitForCmd = 4'd1;
  localparam logic [3:0] FetchDAT = 4'd2;
  localparam logic [3:0] WaitDAT = 4'd3;
  localparam logic [3:0] I3CBcastHeader = 4'd4;
  localparam logic [3:0] I3CWriteImmediate = 4'd5;
  localparam logic [3:0] I2CWriteImmediate = 4'd6;
  localparam logic [3:0] FetchTxData = 4'd7;
  localparam logic [3:0] InitI3CWrite = 4'd8;
  localparam logic [3:0] InitI3CRead = 4'd9;
  localparam logic [3:0] InitI2CWrite = 4'd10;
  localparam logic [3:0] InitI2CRead = 4'd11;
  localparam logic [3:0] IssueCmd = 4'd12;
  localparam logic [3:0] WriteResp = 4'd13;

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
          (bcast_has_event_byte(desc) && ((phase == 8'd5) || (phase == 8'd6)));
    end
  endfunction

  function automatic logic expected_regular_sel_od_pp(
      input i3c_cmd_attr_e attr, input cmd_transfer_dir_e dir, input dat_entry_t dat,
      input logic [7:0] phase, input logic [15:0] remaining_len, input logic short_read,
      input logic addr_after_rstart);
    expected_regular_sel_od_pp = 1'b0;

    if (attr == AddressAssignment || dat.device) begin
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
        I3CWriteImmediate: begin
          expected_sel_od_pp = expected_imm_sel_od_pp(desc, phase);
        end

        InitI3CWrite: begin
          expected_sel_od_pp = (phase == PhaseAddr) && addr_after_rstart;
        end

        InitI3CRead: begin
          expected_sel_od_pp = (phase == PhaseAddr) && addr_after_rstart;
        end

        IssueCmd: begin
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
      end else if (state == I3CWriteImmediate) begin
        expected_scl_use_od_low = !expected_sel;
      end else if (state == InitI3CWrite) begin
        expected_scl_use_od_low = !expected_sel;
      end else if (state == InitI3CRead) begin
        expected_scl_use_od_low = !expected_sel;
      end else if (state == IssueCmd && ((attr == AddressAssignment) || !dat.device)) begin
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

  function automatic logic [1:0] expected_next_rx_byte_idx(input logic [1:0] idx);
    expected_next_rx_byte_idx = (idx == 2'd3) ? 2'd0 : (idx + 2'd1);
  endfunction

  function automatic logic [1:0] expected_rx_byte_idx_after_tbit(
      input logic [1:0] idx, input logic [15:0] remaining_len, input logic rx_ready,
      input logic rx_full);
    if ((remaining_len == 16'h1) && rx_ready && !rx_full) begin
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

  function automatic logic tx_underflow_resp_matches_current_len();
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

  function automatic logic sdr_write_active_state();
    return (state_q == InitI3CWrite) ||
           (state_q == FetchTxData) ||
           (state_q == IssueCmd);
  endfunction

  function automatic logic sdr_write_done_ready();
    return state_q == IssueCmd &&
           sdr_regular_i3c_write() &&
           !addr_nack_q &&
           (remaining_len_q == 16'h0) &&
           (issue_phase_q > PhaseAddrAck) &&
           bus_tx_idle_i &&
           bus_rx_idle_i;
  endfunction

  function automatic logic sdr_read_done_ready();
    return state_q == IssueCmd &&
           sdr_regular_i3c_read() &&
           !addr_nack_q &&
           !short_read_q &&
           (remaining_len_q == 16'h0) &&
           (rx_byte_idx_q == 2'd0) &&
           (issue_phase_q > PhaseAddrAck) &&
           bus_tx_idle_i &&
           bus_rx_idle_i;
  endfunction

  ap_sel_od_pp_matches_expected :
  assert property (@(posedge clk_i) disable iff (!rst_ni) sel_od_pp_o === expected_sel_od_pp(
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

  cp_sel_od_pp_matches_expected :
  cover property (@(posedge clk_i) disable iff (!rst_ni) sel_od_pp_o === expected_sel_od_pp(
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
  ));

  ap_scl_use_od_low_matches_expected :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
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

  cp_scl_use_od_low_matches_expected :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
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
  ));

  ap_sdr_write_tbit_parity :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                             state_q == IssueCmd &&
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
                                            state_q == IssueCmd &&
                                            sdr_regular_i3c_write() &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_tx_req_bit &&
                                            !bus_tx_req_byte &&
                                            bus_tx_req_value === {7'b0, ~^current_tx_byte});

  cp_sdr_write_tbit_parity_one :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                                state_q == IssueCmd &&
                                                sdr_regular_i3c_write() &&
                                                remaining_len_q > 16'h0 &&
                                                issue_phase_q > PhaseAddrAck &&
                                                !issue_phase_q[0] &&
                                                bus_tx_req_bit &&
                                                !bus_tx_req_byte &&
                                                bus_tx_req_value === 8'h01);

  cp_sdr_write_tbit_parity_zero :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                                 state_q == IssueCmd &&
                                                 sdr_regular_i3c_write() &&
                                                 remaining_len_q > 16'h0 &&
                                                 issue_phase_q > PhaseAddrAck &&
                                                 !issue_phase_q[0] &&
                                                 bus_tx_req_bit &&
                                                 !bus_tx_req_byte &&
                                                 bus_tx_req_value === 8'h00);

  ap_sdr_write_dat_read_uses_cmd_dev_idx :
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

  ap_sdr_write_addr_uses_dynamic_address :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitI3CWrite &&
                                            sdr_regular_i3c_write() &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte
                                            |->
                                            bus_tx_req_value === {dat_entry.dynamic_address, Write})
  else $error("flow_active_sva: SDR write address byte must use selected DAT dynamic address in %m");

  cp_sdr_write_addr_uses_dynamic_address :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitI3CWrite &&
                                            sdr_regular_i3c_write() &&
                                            issue_phase_q == PhaseAddr &&
                                            bus_tx_req_byte &&
                                            bus_tx_req_value === {dat_entry.dynamic_address, Write});

  ap_sdr_write_zero_len_no_data_phase :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            (state_q == InitI3CWrite || state_q == IssueCmd) &&
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
                                            (state_q == InitI3CWrite || state_q == IssueCmd) &&
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
                                            sdr_regular_i3c_write() &&
                                            tx_queue_empty_i &&
                                            !tx_underflow_q
                                            |=>
                                            tx_underflow_q)
  else $error("flow_active_sva: FetchTxData empty TX FIFO must latch underflow in %m");

  cp_fetch_tx_empty_latches_underflow :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            sdr_regular_i3c_write() &&
                                            tx_queue_empty_i &&
                                            !tx_underflow_q
                                            ##1
                                            tx_underflow_q);

  ap_fetch_tx_underflow_no_tx_pop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            sdr_regular_i3c_write() &&
                                            (tx_queue_empty_i || tx_underflow_q)
                                            |->
                                            !tx_queue_rready_o)
  else $error("flow_active_sva: TX underflow path must not pop TX FIFO in %m");

  cp_fetch_tx_underflow_no_tx_pop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            sdr_regular_i3c_write() &&
                                            (tx_queue_empty_i || tx_underflow_q) &&
                                            !tx_queue_rready_o);

  ap_fetch_tx_valid_enters_issue :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            sdr_regular_i3c_write() &&
                                            !tx_underflow_q &&
                                            !tx_queue_empty_i &&
                                            tx_queue_rvalid_i
                                            |=>
                                            state_q == IssueCmd)
  else $error("flow_active_sva: valid TX data in FetchTxData must enter IssueCmd in %m");

  cp_fetch_tx_valid_enters_issue :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            sdr_regular_i3c_write() &&
                                            !tx_underflow_q &&
                                            !tx_queue_empty_i &&
                                            tx_queue_rvalid_i
                                            ##1
                                            state_q == IssueCmd);

  ap_tx_underflow_requests_stop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            sdr_regular_i3c_write() &&
                                            (tx_queue_empty_i || tx_underflow_q)
                                            |->
                                            gen_stop_o &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit)
  else $error("flow_active_sva: TX underflow path must request STOP without TX activity in %m");

  cp_tx_underflow_requests_stop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            sdr_regular_i3c_write() &&
                                            (tx_queue_empty_i || tx_underflow_q) &&
                                            gen_stop_o &&
                                            !bus_tx_req_byte &&
                                            !bus_tx_req_bit);

  ap_tx_underflow_stop_to_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            sdr_regular_i3c_write() &&
                                            tx_underflow_q &&
                                            scl_stop_done_q
                                            |=>
                                            state_q == WriteResp)
  else $error("flow_active_sva: TX underflow must transition to WriteResp after STOP completes in %m");

  cp_tx_underflow_stop_to_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == FetchTxData &&
                                            sdr_regular_i3c_write() &&
                                            tx_underflow_q &&
                                            scl_stop_done_q
                                            ##1
                                            state_q == WriteResp);

  ap_tx_underflow_resp_ovl :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
                                            tx_underflow_q
                                            |->
                                            tx_underflow_resp_matches_current_len())
  else $error("flow_active_sva: TX underflow response descriptor must be Ovl with current length in %m");

  cp_tx_underflow_resp_ovl :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
                                            tx_underflow_q &&
                                            tx_underflow_resp_matches_current_len());

  ap_init_i3c_write_no_tx_pop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitI3CWrite &&
                                            sdr_regular_i3c_write()
                                            |->
                                            !tx_queue_rready_o)
  else $error("flow_active_sva: InitI3CWrite must not pop TX FIFO before address ACK in %m");

  cp_init_i3c_write_addr_ack_to_fetch_tx :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitI3CWrite &&
                                            sdr_regular_i3c_write() &&
                                            !addr_nack_q &&
                                            issue_phase_q > PhaseAddrAck &&
                                            remaining_len_q > 16'h0
                                            ##1
                                            state_q == FetchTxData);

  ap_init_i3c_read_no_rx_data_req :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitI3CRead &&
                                            sdr_regular_i3c_read()
                                            |->
                                            !bus_rx_req_byte &&
                                            !rx_queue_wvalid)
  else $error("flow_active_sva: InitI3CRead must not request read data or push RX FIFO in %m");

  cp_init_i3c_read_no_rx_data_req :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !bus_rx_req_byte &&
                                            !rx_queue_wvalid);

  ap_init_i3c_read_addr_ack_to_issue_cmd :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !addr_nack_q &&
                                            issue_phase_q > PhaseAddrAck
                                            |=>
                                            state_q == IssueCmd)
  else $error("flow_active_sva: InitI3CRead must enter IssueCmd after address ACK in %m");

  cp_init_i3c_read_addr_ack_to_issue_cmd :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == InitI3CRead &&
                                            sdr_regular_i3c_read() &&
                                            !addr_nack_q &&
                                            issue_phase_q > PhaseAddrAck
                                            ##1
                                            state_q == IssueCmd);

  ap_sdr_write_addr_nack_no_data_phase :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                                         (state_q == InitI3CWrite ||
                                                          state_q == IssueCmd) &&
                                                         sdr_regular_i3c_write() &&
                                                         addr_nack_q
                                                         |->
                                                         gen_stop_o &&
                                                         !bus_tx_req_byte &&
                                                         !bus_tx_req_bit)
  else $error("flow_active_sva: SDR write address NACK must stop without data phase in %m");

  cp_sdr_write_addr_nack_no_data_phase :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                                         (state_q == InitI3CWrite ||
                                                          state_q == IssueCmd) &&
                                                         sdr_regular_i3c_write() &&
                                                         addr_nack_q &&
                                                         gen_stop_o &&
                                                         !bus_tx_req_byte &&
                                                         !bus_tx_req_bit);

  ap_sdr_write_addr_nack_sample_no_data_phase :
  assert property (
      @(posedge clk_i) disable iff (!rst_ni)
      (state_q == InitI3CWrite || state_q == IssueCmd) &&
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
      (state_q == InitI3CWrite || state_q == IssueCmd) &&
      sdr_regular_i3c_write() &&
      issue_phase_q == PhaseAddrAck &&
      bus_rx_done_i &&
      bus_rx_data_i[0] &&
      !bus_tx_req_byte &&
      !bus_tx_req_bit);

  ap_sdr_write_addr_nack_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                                state_q == WriteResp &&
                                                sdr_regular_i3c_write() &&
                                                addr_nack_q
                                                |->
                                                addr_nack_resp_matches())
  else $error("flow_active_sva: SDR write address NACK response descriptor mismatch in %m");

  ap_sdr_write_addr_nack_eventually_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni) $rose(
      addr_nack_q
  ) && (state_q == InitI3CWrite || state_q == IssueCmd) && sdr_regular_i3c_write() |->
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

  ap_sdr_write_toc1_success_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
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
                                            reg_desc.toc &&
                                            !addr_nack_q &&
                                            !tx_underflow_q &&
                                            success_resp_matches_current_len());

  ap_sdr_read_addr_nack_no_data_phase :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                                         state_q == InitI3CRead &&
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
                                                         state_q == InitI3CRead &&
                                                         sdr_regular_i3c_read() &&
                                                         addr_nack_q &&
                                                         gen_stop_o &&
                                                         !bus_rx_req_byte &&
                                                         !bus_rx_req_bit &&
                                                         !rx_queue_wvalid);

  ap_sdr_read_addr_nack_sample_no_data_phase :
  assert property (
      @(posedge clk_i) disable iff (!rst_ni)
      state_q == InitI3CRead &&
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
      state_q == InitI3CRead &&
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

  ap_sdr_read_addr_nack_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                                state_q == WriteResp &&
                                                sdr_regular_i3c_read() &&
                                                addr_nack_q
                                                |->
                                                addr_nack_resp_matches())
  else $error("flow_active_sva: SDR read address NACK response descriptor mismatch in %m");

  ap_sdr_read_addr_nack_eventually_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni) $rose(
      addr_nack_q
  ) && state_q == InitI3CRead && sdr_regular_i3c_read() |->
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
                                            state_q == IssueCmd &&
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
                                            state_q == IssueCmd &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            issue_phase_q[0] &&
                                            bus_rx_done_i);

  ap_sdr_read_tbit_updates_count :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueCmd &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i
                                            |=>
                                            rx_byte_idx_q == expected_rx_byte_idx_after_tbit(
      $past(rx_byte_idx_q), $past(remaining_len_q), $past(rx_queue_wready_i),
      $past(rx_queue_full_i)
  ) && remaining_len_q == ($past(
      remaining_len_q
  ) - 16'h1) && resp_data_len_q == ($past(
      resp_data_len_q
  ) + 16'h1))
  else $error("flow_active_sva: SDR read T-bit phase did not update counters in %m");

  cp_sdr_read_tbit_updates_count :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueCmd &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q > 16'h0 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i);

  ap_sdr_read_target_tbit_end_sets_short :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueCmd &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
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
                                            state_q == IssueCmd &&
                                            sdr_regular_i3c_read() &&
                                            !short_read_q &&
                                            remaining_len_q > 16'h1 &&
                                            issue_phase_q > PhaseAddrAck &&
                                            !issue_phase_q[0] &&
                                            bus_rx_done_i &&
                                            bus_rx_data_i[0] == 1'b0
                                            ##1
                                            short_read_q);

  ap_sdr_read_target_continue_at_requested_len :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == IssueCmd &&
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
                                            state_q == IssueCmd &&
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
                                            state_q == IssueCmd &&
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
                                            state_q == IssueCmd &&
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
                                            state_q == IssueCmd &&
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
                                            !addr_nack_q &&
                                            !short_read_q &&
                                            !rx_overflow_q &&
                                            !hc_aborted_q
                                            |->
                                            success_resp_matches_current_len())
  else $error("flow_active_sva: SDR read success response length mismatch in %m");

  cp_sdr_read_success_resp_len :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            !addr_nack_q &&
                                            !short_read_q &&
                                            !rx_overflow_q &&
                                            !hc_aborted_q &&
                                            success_resp_matches_current_len());

  ap_sdr_read_short_resp_len :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            short_read_q
                                            |->
                                            short_read_resp_matches_current_len())
  else $error("flow_active_sva: SDR read short response status/length mismatch in %m");

  cp_sdr_read_short_resp_len :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_read() &&
                                            short_read_q &&
                                            short_read_resp_matches_current_len());

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
                                            state_q == IssueCmd &&
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
                                            state_q == IssueCmd &&
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

  ap_toc0_accept_continuation :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_done_ready() &&
                                            !reg_desc.toc &&
                                            next_cmd_available &&
                                            next_cmd_supported &&
                                            resp_queue_wready_i
                                            |->
                                            success_resp_matches_current_len() &&
                                            cmd_queue_rready_o &&
                                            !gen_stop_o)
  else $error("flow_active_sva: SDRW_007 toc=0 must accept continuation without STOP in %m");

  cp_toc0_accept_continuation :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_done_ready() &&
                                            !reg_desc.toc &&
                                            next_cmd_available &&
                                            next_cmd_supported &&
                                            resp_queue_wready_i &&
                                            success_resp_matches_current_len() &&
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
                                              resp_queue_wready_i)
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
                                              resp_queue_wready_i) &&
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
  else $error("flow_active_sva: SDRW_007 toc=0 missing continuation must STOP without CMD pop in %m");

  cp_toc0_missing_continuation_requests_stop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_done_ready() &&
                                            !reg_desc.toc &&
                                            !next_cmd_available &&
                                            gen_stop_o &&
                                            !gen_rstart_o &&
                                            !cmd_queue_rready_o);

  ap_toc0_missing_continuation_sets_intr_events :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_done_ready() &&
                                            !reg_desc.toc &&
                                            !next_cmd_available &&
                                            gen_stop_o &&
                                            scl_gen_done_i
                                            |->
                                            hc_seq_cancel_event_o &&
                                            hc_err_cmd_seq_timeout_event_o)
  else $error("flow_active_sva: SDRW_007 toc=0 missing continuation must raise interrupt events in %m");

  cp_toc0_missing_continuation_sets_intr_events :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            sdr_write_done_ready() &&
                                            !reg_desc.toc &&
                                            !next_cmd_available &&
                                            gen_stop_o &&
                                            scl_gen_done_i &&
                                            hc_seq_cancel_event_o &&
                                            hc_err_cmd_seq_timeout_event_o);

  ap_toc0_missing_continuation_success_resp :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
                                            !reg_desc.toc &&
                                            !addr_nack_q &&
                                            !tx_underflow_q &&
                                            !next_cmd_available
                                            |->
                                            success_resp_matches_current_len())
  else $error("flow_active_sva: SDRW_007 toc=0 missing continuation response must be Success in %m");

  cp_toc0_missing_continuation_success_resp :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WriteResp &&
                                            sdr_regular_i3c_write() &&
                                            !reg_desc.toc &&
                                            !addr_nack_q &&
                                            !tx_underflow_q &&
                                            !next_cmd_available &&
                                            success_resp_matches_current_len());

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
  else $error("flow_active_sva: SDRW_007 toc=0 unsupported continuation response must be NotSupported in %m");

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
                                            state_q == InitI3CWrite &&
                                            sdr_regular_i3c_write() &&
                                            issue_phase_q == PhaseStart &&
                                            next_start_is_rstart_q
                                            |->
                                            gen_rstart_o &&
                                            !gen_start_o &&
                                            !gen_stop_o)
  else $error("flow_active_sva: SDRW_007 continuation must request repeated START only in %m");

  ap_toc0_private_write_continuation_skips_bcast_header :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitDAT &&
                                            cont_pending_q &&
                                            broadcast_header_enable_i &&
                                            sdr_regular_i3c_write()
                                            |=>
                                            state_q != I3CBcastHeader)
  else $error("flow_active_sva: SDRW_007 continuation must not emit a second broadcast header in %m");

  cp_toc0_private_write_continuation_skips_bcast_header :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                                            state_q == WaitDAT &&
                                            cont_pending_q &&
                                            broadcast_header_enable_i &&
                                            sdr_regular_i3c_write()
                                            ##[1:8]
                                            state_q == InitI3CWrite &&
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
                                            state_q == InitI3CWrite &&
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
                                            state_q == InitI3CWrite &&
                                            cont_pending_q &&
                                            sdr_regular_i3c_write() &&
                                            issue_phase_q == PhaseStart &&
                                            next_start_is_rstart_q &&
                                            gen_rstart_o &&
                                            !gen_start_o &&
                                            !gen_stop_o);

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
    .sel_od_pp_o,
    .use_i2c_timing_o,
    .scl_use_od_low_o,
    .issue_phase_q,
    .cmd_attr,
    .cmd_dir,
    .imm_desc,
    .reg_desc,
    .dat_entry,
    .dat_read_valid_hw_o,
    .dat_index_hw_o,
    .remaining_len_q,
    .resp_data_len_q,
    .short_read_q,
    .addr_nack_q,
    .addr_after_rstart_q,
    .next_start_is_rstart_q,
    .cont_pending_q,
    .broadcast_header_enable_i,
    .cmd_tid,
    .gen_start_o,
    .gen_rstart_o,
    .gen_stop_o,
    .gen_clock_o,
    .scl_gen_done_i,
    .tx_queue_empty_i,
    .tx_queue_rvalid_i,
    .tx_queue_rready_o,
    .tx_underflow_q,
    .rx_overflow_q,
    .rx_queue_full_i,
    .rx_queue_wvalid,
    .rx_queue_wready_i,
    .rx_queue_wdata,
    .resp_queue_wready_i,
    .cmd_queue_rready_o,
    .hc_seq_cancel_event_o,
    .hc_err_cmd_seq_timeout_event_o,
    .bus_tx_idle_i,
    .bus_rx_idle_i,
    .next_cmd_available,
    .next_cmd_supported,
    .bus_tx_req_byte,
    .bus_tx_req_bit,
    .bus_rx_req_byte,
    .bus_rx_req_bit,
    .bus_tx_req_value,
    .current_tx_byte,
    .rx_dword_q,
    .rx_byte_idx_q,
    .bus_rx_done_i,
    .bus_rx_data_i,
    .scl_stop_done_q,
    .hc_aborted_q,
    .resp_queue_wvalid,
    .resp_queue_wdata
);
