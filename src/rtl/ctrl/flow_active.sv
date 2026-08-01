module flow_active
  import controller_pkg::*, i3c_pkg::*;
#(
    parameter int HciCmdDataWidth = 64,
    parameter int HciTxDataWidth = 32,
    parameter int HciRxDataWidth = 32,
    parameter int HciRespDataWidth = 32,
    parameter int unsigned DatDepth = 32,
    parameter int unsigned DatAw = $clog2(DatDepth)
) (
    input logic clk_i,
    input logic rst_ni,

    input  logic                       cmd_queue_empty_i,
    input  logic                       cmd_queue_rvalid_i,
    output logic                       cmd_queue_rready_o,
    input  logic [HciCmdDataWidth-1:0] cmd_queue_rdata_i,

    input  logic                      tx_queue_empty_i,
    input  logic                      tx_queue_rvalid_i,
    output logic                      tx_queue_rready_o,
    input  logic [HciTxDataWidth-1:0] tx_queue_rdata_i,

    input  logic                      rx_queue_full_i,
    output logic                      rx_queue_wvalid_o,
    input  logic                      rx_queue_wready_i,
    output logic [HciRxDataWidth-1:0] rx_queue_wdata_o,

    input  logic                        resp_queue_full_i,
    output logic                        resp_queue_wvalid_o,
    input  logic                        resp_queue_wready_i,
    output logic [HciRespDataWidth-1:0] resp_queue_wdata_o,

    output logic             dat_read_valid_hw_o,
    output logic [DatAw-1:0] dat_index_hw_o,
    input  logic [     31:0] dat_rdata_hw_i,

    output logic       bus_tx_req_byte_o,
    output logic       bus_tx_req_bit_o,
    output logic [7:0] bus_tx_req_value_o,
    input  logic       bus_tx_done_i,
    input  logic       bus_tx_idle_i,

    output logic       bus_rx_req_byte_o,
    output logic       bus_rx_req_bit_o,
    output logic       bus_rx_req_bit_handoff_o,
    input  logic [7:0] bus_rx_data_i,
    input  logic       bus_rx_done_i,
    input  logic       bus_rx_idle_i,

    output logic gen_start_o,
    output logic gen_rstart_o,
    output logic takeover_o,
    output logic gen_stop_o,
    output logic gen_clock_o,
    output logic gen_idle_o,
    output logic sel_i3c_i2c_o,
    output logic use_i2c_timing_o,
    output logic scl_use_od_low_o,
    input  logic scl_gen_done_i,
    input  logic scl_gen_busy_i,

    output logic       ccc_valid_o,
    output logic       daa_stop_o,
    output logic [4:0] daa_dev_idx_o,
    output logic [3:0] ccc_dev_count_o,
    input  logic       ccc_done_i,
    input  logic       daa_stop_req_i,
    input  logic       daa_stopped_i,
    input  logic       daa_nack_error_i,
    input  logic       daa_invalid_addr_i,

    input logic [ 6:0] daa_address_i,
    input logic        daa_address_valid_i,
    input logic [47:0] daa_pid_i,
    input logic [ 7:0] daa_bcr_i,
    input logic [ 7:0] daa_dcr_i,

    output logic sel_od_pp_o,

    input  logic broadcast_header_enable_i,
    input  logic i3c_fsm_en_i,
    input  logic abort_i,
    output logic i3c_fsm_idle_o
);

  typedef enum logic [1:0] {
    BcastHeaderPrivate      = 2'd0,
    BcastHeaderBroadcastCCC = 2'd1,
    BcastHeaderDirectCCC    = 2'd2,
    BcastHeaderEntdaa       = 2'd3
  } bcast_header_next_e;

  flow_fsm_state_e state_d, state_q;
  bcast_header_next_e bcast_header_next_d, bcast_header_next_q;

  logic                       [HciCmdDataWidth-1:0] cmd_desc;
  immediate_data_trans_desc_t                       imm_desc;
  regular_trans_desc_t                              reg_desc;
  addr_assign_desc_t                                aa_desc;
  dat_entry_t                                       dat_entry;
  logic                                             target_is_i3c;
  i3c_cmd_attr_e                                    cmd_attr;
  cmd_transfer_dir_e                                cmd_dir;
  logic                       [                3:0] cmd_tid;
  logic                       [          DatAw-1:0] dev_index;
  logic                                             imm_bcast_enec_disec;
  logic                                             imm_bcast_has_event_byte;
  logic                                             active_wroc;
  logic                                             completion_error_q;

  logic                       [HciCmdDataWidth-1:0] next_cmd_desc;
  regular_trans_desc_t                              next_reg_desc;
  i3c_cmd_attr_e                                    next_cmd_attr;
  logic                                             next_cmd_supported;
  logic                                             next_cmd_available;

  logic                                             i3c_fsm_idle;
  logic                                             cmd_queue_rready;
  logic dat_read_valid_hw_q, dat_read_valid_hw_d;
  logic [DatAw-1:0] dat_index_hw;

  logic [7:0] issue_phase_d, issue_phase_q;

  logic [31:0] tx_dword_q;
  logic [1:0] tx_byte_idx_d, tx_byte_idx_q;
  logic tx_queue_rready;
  logic tx_underflow_d, tx_underflow_q;

  logic [31:0] rx_dword_d, rx_dword_q;
  logic [1:0] rx_byte_idx_d, rx_byte_idx_q;
  logic rx_queue_wvalid;
  logic [31:0] rx_queue_wdata;
  logic rx_overflow_d, rx_overflow_q;

  logic [47:0] daa_pid_d, daa_pid_q;
  logic [7:0] daa_bcr_d, daa_bcr_q;
  logic [7:0] daa_dcr_d, daa_dcr_q;
  logic [6:0] daa_addr_d, daa_addr_q;
  logic [1:0] daa_wr_phase_d, daa_wr_phase_q;
  logic daa_wr_busy_d, daa_wr_busy_q;

  logic [15:0] remaining_len_d, remaining_len_q;
  logic [15:0] resp_data_len_d, resp_data_len_q;

  logic short_read_d, short_read_q;
  logic short_read_error;
  logic addr_nack_d, addr_nack_q;
  logic data_nack_d, data_nack_q;
  logic hc_aborted_d, hc_aborted_q;
  logic not_supported_d, not_supported_q;
  logic daa_nack_error_d, daa_nack_error_q;
  logic scl_stop_done_d, scl_stop_done_q;
  logic entdaa_stop_req_d, entdaa_stop_req_q;
  logic next_start_is_rstart_d, next_start_is_rstart_q;
  logic addr_after_rstart_d, addr_after_rstart_q;
  logic cont_pending_d, cont_pending_q;
  logic read_takeover_pending_d, read_takeover_pending_q;
  logic read_takeover_done_d, read_takeover_done_q;
  logic read_abort_term_d, read_abort_term_q;

  logic gen_start;
  logic gen_rstart;
  logic takeover;
  logic gen_stop;
  logic gen_clock;
  logic gen_idle;
  logic sel_i3c_i2c;
  logic use_i2c_timing;
  logic scl_use_od_low;
  logic sel_od_pp;

  logic bus_tx_req_byte;
  logic bus_tx_req_bit;
  logic [7:0] bus_tx_req_value;
  logic bus_rx_req_byte;
  logic bus_rx_req_bit;
  logic bus_rx_req_bit_handoff;

  logic resp_queue_wvalid;
  logic [31:0] resp_queue_wdata;

  logic ccc_valid;
  logic daa_stop;
  logic [4:0] daa_dev_idx;
  logic [3:0] ccc_dev_count;
  logic [7:0] imm_data_byte;
  logic [7:0] imm_data_phase;
  logic [2:0] data_byte_idx;
  logic [7:0] current_tx_byte;

  localparam logic [7:0] PhaseStart = 8'd0;
  localparam logic [7:0] PhaseAddr = 8'd1;
  localparam logic [7:0] PhaseAddrAck = 8'd2;
  localparam logic [7:0] PhaseDataStart = 8'd3;
  localparam logic [7:0] PhaseDirectCccStop = 8'd10;
  localparam logic [7:0] PhaseBroadcastCccStop = 8'd7;

  assign imm_desc = immediate_data_trans_desc_t'(cmd_desc);
  assign reg_desc = regular_trans_desc_t'(cmd_desc);
  assign aa_desc = addr_assign_desc_t'(cmd_desc);

  assign cmd_attr = i3c_cmd_attr_e'(cmd_desc[2:0]);
  assign cmd_dir = cmd_transfer_dir_e'(cmd_desc[29]);
  assign cmd_tid = cmd_desc[6:3];
  assign dev_index = cmd_desc[20:16];
  assign target_is_i3c = !dat_entry.device;
  assign short_read_error = short_read_q && reg_desc.sre;

  always_comb begin : derive_active_wroc
    unique case (cmd_attr)
      ImmediateDataTransfer: active_wroc = imm_desc.wroc;
      AddressAssignment:     active_wroc = aa_desc.wroc;
      default:               active_wroc = reg_desc.wroc;
    endcase
  end

  assign completion_error_q = addr_nack_q || data_nack_q || daa_nack_error_q ||
                              rx_overflow_q || tx_underflow_q || short_read_error ||
                              not_supported_q || hc_aborted_q;

  assign imm_bcast_enec_disec =
      imm_desc.cp &&
      !imm_desc.cmd[7] &&
      ((imm_desc.cmd == 8'(ENEC)) || (imm_desc.cmd == 8'(DISEC)));
  assign imm_bcast_has_event_byte = imm_bcast_enec_disec;

  assign next_cmd_desc = cmd_queue_rdata_i;
  assign next_reg_desc = regular_trans_desc_t'(next_cmd_desc);
  assign next_cmd_attr = i3c_cmd_attr_e'(next_cmd_desc[2:0]);
  assign next_cmd_supported =
      cmd_queue_rvalid_i &&
      (next_cmd_attr == RegularTransfer) &&
      (next_reg_desc.mode == sdr0) &&
      !next_reg_desc.cp;
  assign next_cmd_available = cmd_queue_rvalid_i && !cmd_queue_empty_i;

  function automatic logic [31:0] make_resp_word(
      input i3c_resp_err_e err, input logic [3:0] tid, input logic [15:0] data_len);
    make_resp_word = {err, tid, 8'h00, data_len};
  endfunction

  function automatic logic invalid_addr_assign_desc(input addr_assign_desc_t desc);
    logic [5:0] dat_end;

    dat_end = {1'b0, desc.dev_idx} + {2'b00, desc.dev_count};
    invalid_addr_assign_desc =
        !desc.toc || !desc.wroc || (desc.dev_count == 4'd0) || (dat_end > DatDepth);
  endfunction

  function automatic logic supported_immediate_ccc(input logic [7:0] cmd);
    unique case (cmd)
      8'(ENEC), 8'(DISEC), 8'(DIR_ENEC), 8'(DIR_DISEC): supported_immediate_ccc = 1'b1;
      default:                     supported_immediate_ccc = 1'b0;
    endcase
  endfunction

  function automatic logic invalid_cmd_desc(input logic [63:0] desc);
    immediate_data_trans_desc_t imm;
    regular_trans_desc_t        reg_transfer;
    addr_assign_desc_t          addr_assign;
    logic [2:0]                 attr;

    imm          = immediate_data_trans_desc_t'(desc);
    reg_transfer = regular_trans_desc_t'(desc);
    addr_assign = addr_assign_desc_t'(desc);
    attr        = desc[2:0];

    unique case (attr)
      3'b000: begin
        invalid_cmd_desc = reg_transfer.cp || (reg_transfer.mode != sdr0);
      end
      3'b001: begin
        invalid_cmd_desc = imm.rnw || (imm.mode != sdr0) || (imm.dtt > 3'd4) ||
                           (imm.cp && !supported_immediate_ccc(imm.cmd));
      end
      3'b010: begin
        invalid_cmd_desc = invalid_addr_assign_desc(addr_assign) ||
                           (addr_assign.cmd != ENTDAA);
      end
      default: begin
        invalid_cmd_desc = 1'b1;
      end
    endcase
  endfunction

  function automatic logic [1:0] next_byte_idx(input logic [1:0] idx);
    next_byte_idx = (idx == 2'd3) ? 2'd0 : (idx + 2'd1);
  endfunction

  function automatic logic abort_active_state(input flow_fsm_state_e state);
    abort_active_state = (state != Idle) && (state != WaitForCmd) && (state != WriteResp);
  endfunction

  function automatic logic abort_stop_required(input flow_fsm_state_e state,
                                               input logic cont_pending);
    abort_stop_required = (state != FetchDAT) && !((state == WaitDAT) && !cont_pending);
  endfunction

  function automatic logic abort_stop_now(input flow_fsm_state_e state, input logic target_i3c,
                                          input cmd_transfer_dir_e dir, input i3c_cmd_attr_e attr);
    abort_stop_now = !((state == IssueI3CRead) && target_i3c && (dir == Read) &&
        ((attr == RegularTransfer) || (attr == ComboTransfer)));
  endfunction

  function automatic logic i2c_read_abort();
    i2c_read_abort = (state_q == IssueI2CRead) && !target_is_i3c &&
        (cmd_attr == RegularTransfer) && (cmd_dir == Read) &&
        (issue_phase_q > PhaseAddrAck) && (remaining_len_q > 16'h0) &&
        !rx_overflow_q && !read_abort_term_q;
  endfunction

  function automatic i3c_resp_err_e map_resp_err();
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
    end else if (not_supported_q) begin
      return NotSupported;
    end else if (hc_aborted_q) begin
      return HcAborted;
    end else begin
      return Success;
    end
  endfunction

  function automatic logic [31:0] rx_word_with_byte(input logic [31:0] word, input logic [1:0] idx,
                                                    input logic [7:0] byte_data);
    rx_word_with_byte = word;
    unique case (idx)
      2'h0: rx_word_with_byte[7:0] = byte_data;
      2'h1: rx_word_with_byte[15:8] = byte_data;
      2'h2: rx_word_with_byte[23:16] = byte_data;
      2'h3: rx_word_with_byte[31:24] = byte_data;
    endcase
  endfunction

  function automatic logic [31:0] daa_rx_result_word(input logic [1:0] phase,
                                                     input logic [47:0] pid, input logic [7:0] bcr,
                                                     input logic [7:0] dcr, input logic [6:0] addr);
    unique case (phase)
      2'd0: daa_rx_result_word = pid[47:16];
      2'd1: daa_rx_result_word = {pid[15:0], bcr, dcr};
      2'd2: daa_rx_result_word = {25'h0, addr};
      default: daa_rx_result_word = '0;
    endcase
  endfunction

  task automatic request_stop(input logic is_not_supported);
    gen_stop = 1'b1;
    if (scl_gen_done_i) begin
      scl_stop_done_d = 1'b1;
      if (is_not_supported) begin
        not_supported_d = 1'b1;
      end
    end
  endtask

  task automatic request_missing_continuation_stop;
    request_stop(1'b0);
  endtask

  task automatic request_read_takeover;
    gen_rstart = 1'b1;
    takeover = 1'b1;
    read_takeover_pending_d = 1'b1;
    if (scl_gen_done_i) begin
      read_takeover_pending_d = 1'b0;
      read_takeover_done_d    = 1'b1;
    end
  endtask

  task automatic request_rx_commit(input logic [31:0] rx_word);
    rx_queue_wvalid = 1'b1;
    rx_queue_wdata  = rx_word;
    rx_dword_d      = rx_word;
    if (rx_queue_wready_i && !rx_queue_full_i) begin
      rx_dword_d    = 32'h0;
      rx_byte_idx_d = 2'h0;
    end else begin
      rx_overflow_d = 1'b1;
    end
  endtask

  task automatic clear_transfer_context;
    issue_phase_d           = 8'h0;
    tx_byte_idx_d           = 2'h0;
    rx_byte_idx_d           = 2'h0;
    rx_dword_d              = 32'h0;
    rx_overflow_d           = 1'b0;
    tx_underflow_d          = 1'b0;
    remaining_len_d         = 16'h0;
    resp_data_len_d         = 16'h0;
    addr_nack_d             = 1'b0;
    data_nack_d             = 1'b0;
    short_read_d            = 1'b0;
    hc_aborted_d            = 1'b0;
    not_supported_d         = 1'b0;
    daa_nack_error_d        = 1'b0;
    scl_stop_done_d         = 1'b0;
    read_takeover_pending_d = 1'b0;
    read_takeover_done_d    = 1'b0;
    read_abort_term_d       = 1'b0;
  endtask

  task automatic accept_continuation_cmd(input logic rstart_already_generated);
    if (active_wroc) begin
      resp_queue_wvalid = 1'b1;
      resp_queue_wdata  = make_resp_word(map_resp_err(), cmd_tid, resp_data_len_q);
    end
    cmd_queue_rready  = 1'b1;
    clear_transfer_context();
    next_start_is_rstart_d = !rstart_already_generated;
    addr_after_rstart_d    = rstart_already_generated;
    cont_pending_d         = 1'b1;
  endtask

  task automatic drive_i2c_addr_preamble(input cmd_transfer_dir_e direction);
    unique case (issue_phase_q)
      PhaseStart: begin
        gen_start = 1'b1;
        if (scl_gen_done_i) begin
          issue_phase_d = issue_phase_q + 8'h1;
        end
      end

      PhaseAddr: begin
        bus_tx_req_byte  = 1'b1;
        bus_tx_req_value = {dat_entry.static_address, direction};
        if (bus_tx_done_i) begin
          issue_phase_d = issue_phase_q + 8'h1;
        end
      end

      PhaseAddrAck: begin
        bus_rx_req_bit = 1'b1;
        if (bus_rx_done_i) begin
          addr_nack_d   = bus_rx_data_i[0];
          issue_phase_d = issue_phase_q + 8'h1;
        end
      end

      default: begin
      end
    endcase
  endtask

  task automatic drive_i3c_addr_preamble(input cmd_transfer_dir_e direction);
    unique case (issue_phase_q)
      PhaseStart: begin
        if (addr_after_rstart_q && !next_start_is_rstart_q) begin
          issue_phase_d  = issue_phase_q + 8'h1;
          cont_pending_d = 1'b0;
        end else if (next_start_is_rstart_q) begin
          gen_rstart = 1'b1;
        end else begin
          gen_start = 1'b1;
        end
        if (!addr_after_rstart_q && scl_gen_done_i) begin
          if (next_start_is_rstart_q) begin
            next_start_is_rstart_d = 1'b0;
            addr_after_rstart_d    = 1'b1;
            cont_pending_d         = 1'b0;
          end
          issue_phase_d = issue_phase_q + 8'h1;
        end
      end

      PhaseAddr: begin
        sel_od_pp        = addr_after_rstart_q ? 1'b1 : 1'b0;
        bus_tx_req_byte  = 1'b1;
        bus_tx_req_value = {dat_entry.dynamic_address, direction};
        if (bus_tx_done_i) begin
          issue_phase_d       = issue_phase_q + 8'h1;
          addr_after_rstart_d = 1'b0;
        end
      end

      PhaseAddrAck: begin
        sel_od_pp              = 1'b0;
        bus_rx_req_bit         = direction == Read;
        bus_rx_req_bit_handoff = direction == Write;
        if (bus_rx_done_i) begin
          addr_nack_d   = bus_rx_data_i[0];
          issue_phase_d = issue_phase_q + 8'h1;
        end
      end

      default: begin
      end
    endcase
  endtask

  task automatic drive_i3c_bcast_header;
    unique case (issue_phase_q)
      PhaseStart: begin
        gen_start = 1'b1;
        if (scl_gen_done_i) begin
          issue_phase_d = issue_phase_q + 8'h1;
        end
      end

      PhaseAddr: begin
        sel_od_pp        = 1'b0;
        bus_tx_req_byte  = 1'b1;
        bus_tx_req_value = {I3C_RSVD_ADDR, Write};
        if (bus_tx_done_i) begin
          issue_phase_d = issue_phase_q + 8'h1;
        end
      end

      PhaseAddrAck: begin
        sel_od_pp              = 1'b0;
        bus_rx_req_bit_handoff = 1'b1;
        if (bus_rx_done_i) begin
          addr_nack_d   = bus_rx_data_i[0];
          issue_phase_d = issue_phase_q + 8'h1;
        end
      end

      default: begin
      end
    endcase
  endtask

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_fsm_state_q
    if (!rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_bcast_header_next
    if (!rst_ni) begin
      bcast_header_next_q <= BcastHeaderPrivate;
    end else begin
      bcast_header_next_q <= bcast_header_next_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : latch_cmd_queue_rdata_i_into_cmd_desc
    if (!rst_ni) begin
      cmd_desc <= '0;
    end else begin
      if (cmd_queue_rready_o && cmd_queue_rvalid_i) begin
        cmd_desc <= cmd_queue_rdata_i;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_dat_read_valid_hw_q
    if (!rst_ni) begin
      dat_read_valid_hw_q <= 1'b0;
    end else begin
      dat_read_valid_hw_q <= dat_read_valid_hw_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : capture_dat_rdata_hw_i_into_dat_entry
    if (!rst_ni) begin
      dat_entry <= '0;
    end else begin
      if (dat_read_valid_hw_q) begin
        dat_entry <= dat_entry_t'(dat_rdata_hw_i);
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_issue_phase
    if (!rst_ni) begin
      issue_phase_q <= '0;
    end else begin
      issue_phase_q <= issue_phase_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_tx_dword
    if (!rst_ni) begin
      tx_dword_q <= '0;
    end else begin
      if (tx_queue_rready && tx_queue_rvalid_i) begin
        tx_dword_q <= tx_queue_rdata_i;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_tx_byte_idx
    if (!rst_ni) begin
      tx_byte_idx_q <= '0;
    end else begin
      tx_byte_idx_q <= tx_byte_idx_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_tx_underflow
    if (!rst_ni) begin
      tx_underflow_q <= 1'b0;
    end else begin
      tx_underflow_q <= tx_underflow_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_rx_dword
    if (!rst_ni) begin
      rx_dword_q <= '0;
    end else begin
      rx_dword_q <= rx_dword_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_rx_byte_idx
    if (!rst_ni) begin
      rx_byte_idx_q <= '0;
    end else begin
      rx_byte_idx_q <= rx_byte_idx_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_rx_overflow
    if (!rst_ni) begin
      rx_overflow_q <= 1'b0;
    end else begin
      rx_overflow_q <= rx_overflow_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_daa_result_latches
    if (!rst_ni) begin
      daa_pid_q      <= '0;
      daa_bcr_q      <= '0;
      daa_dcr_q      <= '0;
      daa_addr_q     <= '0;
      daa_wr_phase_q <= '0;
      daa_wr_busy_q  <= 1'b0;
    end else begin
      daa_pid_q      <= daa_pid_d;
      daa_bcr_q      <= daa_bcr_d;
      daa_dcr_q      <= daa_dcr_d;
      daa_addr_q     <= daa_addr_d;
      daa_wr_phase_q <= daa_wr_phase_d;
      daa_wr_busy_q  <= daa_wr_busy_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_remaining_len
    if (!rst_ni) begin
      remaining_len_q <= '0;
    end else begin
      remaining_len_q <= remaining_len_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_resp_data_len
    if (!rst_ni) begin
      resp_data_len_q <= '0;
    end else begin
      resp_data_len_q <= resp_data_len_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_addr_nack
    if (!rst_ni) begin
      addr_nack_q <= 1'b0;
    end else begin
      addr_nack_q <= addr_nack_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_data_nack
    if (!rst_ni) begin
      data_nack_q <= 1'b0;
    end else begin
      data_nack_q <= data_nack_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_short_read
    if (!rst_ni) begin
      short_read_q <= 1'b0;
    end else begin
      short_read_q <= short_read_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_hc_aborted
    if (!rst_ni) begin
      hc_aborted_q <= 1'b0;
    end else begin
      hc_aborted_q <= hc_aborted_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_not_supported
    if (!rst_ni) begin
      not_supported_q <= 1'b0;
    end else begin
      not_supported_q <= not_supported_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_daa_nack_error
    if (!rst_ni) begin
      daa_nack_error_q <= 1'b0;
    end else begin
      daa_nack_error_q <= daa_nack_error_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_scl_stop_done
    if (!rst_ni) begin
      scl_stop_done_q <= 1'b0;
    end else begin
      scl_stop_done_q <= scl_stop_done_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_entdaa_stop_req
    if (!rst_ni) begin
      entdaa_stop_req_q <= 1'b0;
    end else begin
      entdaa_stop_req_q <= entdaa_stop_req_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_next_start_is_rstart
    if (!rst_ni) begin
      next_start_is_rstart_q <= 1'b0;
    end else begin
      next_start_is_rstart_q <= next_start_is_rstart_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_addr_after_rstart
    if (!rst_ni) begin
      addr_after_rstart_q <= 1'b0;
    end else begin
      addr_after_rstart_q <= addr_after_rstart_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_cont_pending
    if (!rst_ni) begin
      cont_pending_q <= 1'b0;
    end else begin
      cont_pending_q <= cont_pending_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_read_takeover_pending
    if (!rst_ni) begin
      read_takeover_pending_q <= 1'b0;
    end else begin
      read_takeover_pending_q <= read_takeover_pending_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_read_takeover_done
    if (!rst_ni) begin
      read_takeover_done_q <= 1'b0;
    end else begin
      read_takeover_done_q <= read_takeover_done_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_read_abort_term
    if (!rst_ni) begin
      read_abort_term_q <= 1'b0;
    end else begin
      read_abort_term_q <= read_abort_term_d;
    end
  end

  always_comb begin : select_imm_data_byte
    imm_data_phase = 8'h0;
    if (state_q == IssueImmediateCcc ||
        ((state_q == IssueI3CWrite || state_q == IssueI2CWrite) &&
         cmd_attr == ImmediateDataTransfer && !imm_desc.cp)) begin
      if (issue_phase_q > PhaseAddrAck) imm_data_phase = (issue_phase_q - PhaseDataStart) >> 1;
    end

    data_byte_idx = imm_data_phase[2:0];

    unique case (data_byte_idx)
      3'd0: imm_data_byte = imm_desc.def_or_data_byte1;
      3'd1: imm_data_byte = imm_desc.data_byte2;
      3'd2: imm_data_byte = imm_desc.data_byte3;
      3'd3: imm_data_byte = imm_desc.data_byte4;
      default: imm_data_byte = 8'h00;
    endcase
  end

  always_comb begin : select_tx_byte
    unique case (tx_byte_idx_q)
      2'd0: current_tx_byte = tx_dword_q[7:0];
      2'd1: current_tx_byte = tx_dword_q[15:8];
      2'd2: current_tx_byte = tx_dword_q[23:16];
      2'd3: current_tx_byte = tx_dword_q[31:24];
    endcase
  end

  always_comb begin : update_fsm_state_d
    state_d = state_q;

    if (abort_i && !i2c_read_abort() && abort_active_state(
            state_q
        ) && abort_stop_now(
            state_q, target_is_i3c, cmd_dir, cmd_attr
        ) && !((state_q == IssueDAA) &&
               (issue_phase_q > 8'd4))) begin
      if (abort_stop_required(state_q, cont_pending_q)) begin
        state_d = scl_stop_done_q ? WriteResp : state_q;
      end else begin
        state_d = hc_aborted_q ? WriteResp : state_q;
      end
    end else begin
      unique case (state_q)
        Idle: begin
          if (i3c_fsm_en_i) begin
            state_d = WaitForCmd;
          end
        end

        WaitForCmd: begin
          if (!i3c_fsm_en_i) begin
            state_d = Idle;
          end else if (!abort_i && !cmd_queue_empty_i && cmd_queue_rvalid_i) begin
            state_d = FetchDAT;
          end
        end

        FetchDAT: begin
          if (invalid_cmd_desc(cmd_desc)) begin
            state_d = WriteResp;
          end else if (dat_read_valid_hw_q) begin
            state_d = WaitDAT;
          end
        end

        WaitDAT: begin
          if (cont_pending_q && !target_is_i3c) begin
            if (scl_stop_done_q) state_d = WriteResp;
          end else if (!dat_read_valid_hw_q) begin
            if (cmd_attr == ImmediateDataTransfer) begin
              if (!imm_desc.cp) begin
                if (!target_is_i3c) begin
                  state_d = InitWrite;
                end else if (!broadcast_header_enable_i) begin
                  state_d = InitWrite;
                end else begin
                  state_d = I3CBcastHeader;
                end
              end else begin
                state_d = I3CBcastHeader;
              end
            end else if (cmd_attr == AddressAssignment) begin
              state_d = I3CBcastHeader;
            end else if (cmd_dir == Write) begin
              if (!target_is_i3c) begin
                state_d = InitWrite;
              end else if (cont_pending_q || !broadcast_header_enable_i) begin
                state_d = InitWrite;
              end else begin
                state_d = I3CBcastHeader;
              end
            end else begin
              if (!target_is_i3c) begin
                state_d = InitRead;
              end else if (cont_pending_q || !broadcast_header_enable_i) begin
                state_d = InitRead;
              end else begin
                state_d = I3CBcastHeader;
              end
            end
          end else begin
            state_d = WaitDAT;
          end
        end

        I3CBcastHeader: begin
          if (addr_nack_q) begin
            if (scl_stop_done_q) begin
              state_d = WriteResp;
            end
          end else if (issue_phase_q > PhaseAddrAck) begin
            unique case (bcast_header_next_q)
              BcastHeaderPrivate: begin
                if (cmd_attr == ImmediateDataTransfer) begin
                  state_d = InitWrite;
                end else begin
                  state_d = (cmd_dir == Read) ? InitRead : InitWrite;
                end
              end

              BcastHeaderBroadcastCCC: begin
                state_d = IssueImmediateCcc;
              end

              BcastHeaderDirectCCC: begin
                state_d = IssueImmediateCcc;
              end

              BcastHeaderEntdaa: begin
                state_d = IssueDAA;
              end
            endcase
          end
        end

        IssueImmediateCcc: begin
          if (addr_nack_q) begin
            if (scl_stop_done_q) begin
              state_d = WriteResp;
            end
          end else if (imm_desc.cp) begin
            if (imm_desc.cmd[7]) begin
              if (issue_phase_q >= PhaseDirectCccStop) begin
                if (scl_stop_done_q) begin
                  state_d = (active_wroc || completion_error_q) ? WriteResp : Idle;
                end
              end
            end else begin
              if (issue_phase_q >= 8'd6) begin
                if (scl_stop_done_q) begin
                  state_d = (active_wroc || completion_error_q) ? WriteResp : Idle;
                end
              end
            end
          end
        end

        FetchTxData: begin
          if (tx_underflow_q) begin
            if (scl_stop_done_q) begin
              state_d = WriteResp;
            end
          end else if (tx_queue_empty_i) begin
            state_d = FetchTxData;
          end else if (tx_queue_rvalid_i) begin
            state_d = target_is_i3c ? IssueI3CWrite : IssueI2CWrite;
          end
        end

        InitWrite: begin
          if (addr_nack_q) begin
            if (scl_stop_done_q) begin
              state_d = WriteResp;
            end
          end else if (issue_phase_q > PhaseAddrAck) begin
            if (cmd_attr == ImmediateDataTransfer) begin
              state_d = target_is_i3c ? IssueI3CWrite : IssueI2CWrite;
            end else if (target_is_i3c) begin
              state_d = (remaining_len_q > 16'h0) ? FetchTxData : IssueI3CWrite;
            end else begin
              state_d = FetchTxData;
            end
          end
        end

        InitRead: begin
          if (addr_nack_q) begin
            if (scl_stop_done_q) begin
              state_d = WriteResp;
            end
          end else if (issue_phase_q > PhaseAddrAck) begin
            state_d = target_is_i3c ? IssueI3CRead : IssueI2CRead;
          end
        end

        IssueDAA: begin
          if (daa_stopped_i && ccc_done_i && !daa_wr_busy_q) begin
            state_d = WriteResp;
          end else if (entdaa_stop_req_q && scl_gen_done_i) begin
            state_d = WriteResp;
          end
        end

        IssueI3CWrite: begin
          if (remaining_len_q == 16'h0 || data_nack_q) begin
            if (bus_tx_idle_i && bus_rx_idle_i) begin
              if (((cmd_attr == ImmediateDataTransfer) ? imm_desc.toc : reg_desc.toc) &&
                  scl_stop_done_q) begin
                state_d = (active_wroc || completion_error_q) ? WriteResp : Idle;
              end else if (!((cmd_attr == ImmediateDataTransfer) ? imm_desc.toc :
                              reg_desc.toc)) begin
                if (cmd_attr == ImmediateDataTransfer) begin
                  if (scl_stop_done_q) begin
                    state_d = WriteResp;
                  end
                end else if (next_cmd_available && next_cmd_supported &&
                  (!active_wroc || resp_queue_wready_i)) begin
                  state_d = FetchDAT;
                end else if (!(next_cmd_available && next_cmd_supported) &&
                           scl_stop_done_q) begin
                  state_d = WriteResp;
                end
              end
            end
          end else if (tx_byte_idx_q == 2'd3 && remaining_len_q > 16'h1) begin
            if (!issue_phase_q[0] && bus_tx_done_i) state_d = FetchTxData;
          end
        end

        IssueI2CWrite: begin
          if (remaining_len_q == 16'h0 || data_nack_q) begin
            if (bus_tx_idle_i && bus_rx_idle_i) begin
              if (((cmd_attr == ImmediateDataTransfer) ? imm_desc.toc : reg_desc.toc) &&
                  scl_stop_done_q) begin
                state_d = (active_wroc || completion_error_q) ? WriteResp : Idle;
              end else if (!((cmd_attr == ImmediateDataTransfer) ? imm_desc.toc :
                              reg_desc.toc)) begin
                if (scl_stop_done_q) begin
                  state_d = WriteResp;
                end
              end
            end
          end else if (tx_byte_idx_q == 2'd3 && remaining_len_q > 16'h1) begin
            if (!issue_phase_q[0] && bus_rx_done_i) state_d = FetchTxData;
          end
        end

        IssueI3CRead: begin
          if ((remaining_len_q == 16'h0 || short_read_q || read_abort_term_q ||
               rx_overflow_q) && issue_phase_q > PhaseAddrAck) begin
            if (read_takeover_pending_q) begin
              state_d = IssueI3CRead;
            end else if (bus_tx_idle_i && bus_rx_idle_i) begin
              if ((short_read_q || reg_desc.toc || read_abort_term_q ||
                   rx_overflow_q) && scl_stop_done_q) begin
                state_d = (active_wroc || completion_error_q) ? WriteResp : Idle;
              end else if (!short_read_q && !reg_desc.toc && !read_abort_term_q &&
                           !rx_overflow_q) begin
                if (next_cmd_available && next_cmd_supported &&
                  (!active_wroc || resp_queue_wready_i)) begin
                  state_d = FetchDAT;
                end else if (!(next_cmd_available && next_cmd_supported) &&
                           scl_stop_done_q) begin
                  state_d = WriteResp;
                end
              end
            end
          end
        end

        IssueI2CRead: begin
          if ((remaining_len_q == 16'h0 || short_read_q || read_abort_term_q ||
               rx_overflow_q) && issue_phase_q > PhaseAddrAck) begin
            if (bus_tx_idle_i && bus_rx_idle_i) begin
              if ((short_read_q || reg_desc.toc || read_abort_term_q ||
                   rx_overflow_q) && scl_stop_done_q) begin
                state_d = (active_wroc || completion_error_q) ? WriteResp : Idle;
              end else if (!short_read_q && !reg_desc.toc && !read_abort_term_q &&
                           !rx_overflow_q) begin
                if (scl_stop_done_q) begin
                  state_d = WriteResp;
                end
              end
            end
          end
        end

        WriteResp: begin
          if (resp_queue_wready_i) begin
            state_d = Idle;
          end
        end

        default: begin
          state_d = Idle;
        end
      endcase
    end
  end

  always_comb begin : compute_fsm_outputs
    issue_phase_d           = issue_phase_q;
    bcast_header_next_d     = bcast_header_next_q;
    i3c_fsm_idle            = 1'b0;
    cmd_queue_rready        = 1'b0;
    dat_read_valid_hw_d     = 1'b0;
    scl_stop_done_d         = 1'b0;
    dat_index_hw            = '0;

    tx_queue_rready         = 1'b0;
    tx_byte_idx_d           = tx_byte_idx_q;
    tx_underflow_d          = tx_underflow_q;

    rx_dword_d              = rx_dword_q;
    rx_byte_idx_d           = rx_byte_idx_q;
    rx_overflow_d           = rx_overflow_q;
    rx_queue_wvalid         = 1'b0;
    rx_queue_wdata          = '0;

    daa_pid_d               = daa_pid_q;
    daa_bcr_d               = daa_bcr_q;
    daa_dcr_d               = daa_dcr_q;
    daa_addr_d              = daa_addr_q;
    daa_wr_phase_d          = daa_wr_phase_q;
    daa_wr_busy_d           = daa_wr_busy_q;

    remaining_len_d         = remaining_len_q;
    resp_data_len_d         = resp_data_len_q;

    addr_nack_d             = addr_nack_q;
    data_nack_d             = data_nack_q;
    short_read_d            = short_read_q;
    hc_aborted_d            = hc_aborted_q;
    not_supported_d         = not_supported_q;
    daa_nack_error_d        = daa_nack_error_q;
    entdaa_stop_req_d       = entdaa_stop_req_q;
    next_start_is_rstart_d  = next_start_is_rstart_q;
    addr_after_rstart_d     = addr_after_rstart_q;
    cont_pending_d          = cont_pending_q;
    read_takeover_pending_d = read_takeover_pending_q;
    read_takeover_done_d    = read_takeover_done_q;
    read_abort_term_d       = read_abort_term_q;

    gen_start               = 1'b0;
    gen_rstart              = 1'b0;
    takeover                = 1'b0;
    gen_stop                = 1'b0;
    gen_clock               = 1'b0;
    gen_idle                = 1'b0;
    sel_i3c_i2c             = 1'b0;
    use_i2c_timing          = 1'b0;
    scl_use_od_low          = 1'b0;
    sel_od_pp               = 1'b0;

    bus_tx_req_byte         = 1'b0;
    bus_tx_req_bit          = 1'b0;
    bus_tx_req_value        = 8'h00;
    bus_rx_req_byte         = 1'b0;
    bus_rx_req_bit          = 1'b0;
    bus_rx_req_bit_handoff  = 1'b0;

    resp_queue_wvalid       = 1'b0;
    resp_queue_wdata        = '0;
    ccc_valid               = 1'b0;
    daa_stop                = 1'b0;
    daa_dev_idx             = 5'h00;
    ccc_dev_count           = 4'h0;
    if (abort_i && !i2c_read_abort() && abort_active_state(
            state_q
        ) && abort_stop_now(
            state_q, target_is_i3c, cmd_dir, cmd_attr
        ) && !((state_q == IssueDAA) &&
               (issue_phase_q > 8'd4))) begin
      hc_aborted_d = 1'b1;
      sel_i3c_i2c = target_is_i3c;
      use_i2c_timing = !target_is_i3c;
      if (abort_stop_required(state_q, cont_pending_q) && bus_tx_idle_i && bus_rx_idle_i) begin
        request_stop(1'b0);
      end
    end else begin
      unique case (state_q)
        Idle: begin
          i3c_fsm_idle = 1'b1;
          gen_idle = 1'b1;
          issue_phase_d = 8'h0;
          tx_byte_idx_d = 2'h0;
          rx_byte_idx_d = 2'h0;
          rx_dword_d = 32'h0;
          rx_overflow_d = 1'b0;
          tx_underflow_d = 1'b0;
          remaining_len_d = 16'h0;
          resp_data_len_d = 16'h0;
          addr_nack_d = 1'b0;
          data_nack_d = 1'b0;
          short_read_d = 1'b0;
          hc_aborted_d = 1'b0;
          not_supported_d = 1'b0;
          daa_nack_error_d = 1'b0;
          entdaa_stop_req_d = 1'b0;
          next_start_is_rstart_d = 1'b0;
          addr_after_rstart_d = 1'b0;
          cont_pending_d = 1'b0;
          read_takeover_pending_d = 1'b0;
          read_takeover_done_d = 1'b0;
          read_abort_term_d = 1'b0;
          bcast_header_next_d = BcastHeaderPrivate;
        end

        WaitForCmd: begin
          i3c_fsm_idle = cmd_queue_empty_i || abort_i;
          gen_idle = cmd_queue_empty_i || abort_i;
          cmd_queue_rready = i3c_fsm_en_i && !abort_i && !cmd_queue_empty_i;
          issue_phase_d = 8'h0;
        end

        FetchDAT: begin
          if (invalid_cmd_desc(cmd_desc)) begin
            not_supported_d = 1'b1;
          end else begin
            dat_read_valid_hw_d = 1'b1;
            dat_index_hw = dev_index;
            if (cmd_attr == RegularTransfer) begin
              remaining_len_d = reg_desc.data_length;
            end else if (cmd_attr == ImmediateDataTransfer && !imm_desc.cp) begin
              remaining_len_d = {13'h0, imm_desc.dtt};
            end
          end
        end

        WaitDAT: begin
          use_i2c_timing = cont_pending_q && !target_is_i3c;
          if (cmd_attr == ImmediateDataTransfer && imm_desc.cp) begin
            if (imm_desc.cp && imm_desc.cmd[7]) begin
              bcast_header_next_d = BcastHeaderDirectCCC;
            end else begin
              bcast_header_next_d = BcastHeaderBroadcastCCC;
            end
          end else if (cmd_attr == AddressAssignment) begin
            bcast_header_next_d = BcastHeaderEntdaa;
          end else begin
            bcast_header_next_d = BcastHeaderPrivate;
          end
          if (cont_pending_q && !target_is_i3c) begin
            request_stop(1'b1);
          end
        end

        I3CBcastHeader: begin
          gen_clock   = 1'b1;
          sel_i3c_i2c = 1'b1;
          if (addr_nack_q) begin
            request_stop(1'b0);
          end else if (issue_phase_q < PhaseDataStart) begin
            drive_i3c_bcast_header();
          end else if (bcast_header_next_q == BcastHeaderPrivate) begin
            issue_phase_d          = PhaseStart;
            next_start_is_rstart_d = 1'b1;
          end
        end

        IssueImmediateCcc: begin
          gen_clock   = 1'b1;
          sel_i3c_i2c = 1'b1;
          if (imm_desc.cp && imm_desc.cmd[7]) begin
            if (addr_nack_q) begin
              request_stop(1'b0);
            end else begin
              unique case (issue_phase_q)
                8'd3: begin
                  sel_od_pp = 1'b1;
                  bus_tx_req_byte = 1'b1;
                  bus_tx_req_value = imm_desc.cmd;
                  if (bus_tx_done_i) begin
                    issue_phase_d = issue_phase_q + 8'h1;
                  end
                end

                8'd4: begin
                  sel_od_pp = 1'b1;
                  bus_tx_req_bit = 1'b1;
                  bus_tx_req_value = {7'b0, ~^imm_desc.cmd};
                  if (bus_tx_done_i) begin
                    issue_phase_d = issue_phase_q + 8'h1;
                  end
                end

                8'd5: begin
                  gen_rstart = 1'b1;
                  if (scl_gen_done_i) begin
                    issue_phase_d = issue_phase_q + 8'h1;
                  end
                end

                8'd6: begin
                  sel_od_pp = 1'b1;
                  bus_tx_req_byte = 1'b1;
                  bus_tx_req_value = {dat_entry.dynamic_address, Write};
                  if (bus_tx_done_i) begin
                    issue_phase_d = issue_phase_q + 8'h1;
                  end
                end

                8'd7: begin
                  sel_od_pp              = 1'b0;
                  bus_rx_req_bit_handoff = 1'b1;
                  if (bus_rx_done_i) begin
                    addr_nack_d   = bus_rx_data_i[0];
                    issue_phase_d = issue_phase_q + 8'h1;
                  end
                end

                8'd8: begin
                  sel_od_pp = 1'b1;
                  bus_tx_req_byte = 1'b1;
                  bus_tx_req_value = imm_desc.def_or_data_byte1;
                  if (bus_tx_done_i) begin
                    issue_phase_d   = issue_phase_q + 8'h1;
                    resp_data_len_d = resp_data_len_q + 16'h1;
                  end
                end

                8'd9: begin
                  sel_od_pp = 1'b1;
                  bus_tx_req_bit = 1'b1;
                  bus_tx_req_value = {7'b0, ~^imm_desc.def_or_data_byte1};
                  if (bus_tx_done_i) begin
                    issue_phase_d = issue_phase_q + 8'h1;
                  end
                end

                default: begin
                  if (issue_phase_q == PhaseDirectCccStop) begin
                    if (imm_desc.toc) begin
                      request_stop(1'b0);
                      if (scl_gen_done_i) begin
                        issue_phase_d = issue_phase_q + 8'h1;
                      end
                    end else begin
                      request_stop(1'b1);
                      if (scl_gen_done_i) begin
                        issue_phase_d = issue_phase_q + 8'h1;
                      end
                    end
                  end
                end
              endcase
            end
          end else if (imm_desc.cp) begin
            unique case (issue_phase_q)
              8'd3: begin
                sel_od_pp = 1'b1;
                bus_tx_req_byte = 1'b1;
                bus_tx_req_value = imm_desc.cmd;
                if (bus_tx_done_i) begin
                  issue_phase_d = issue_phase_q + 8'h1;
                end
              end

              8'd4: begin
                sel_od_pp = 1'b1;
                bus_tx_req_bit = 1'b1;
                bus_tx_req_value = {7'b0, ~^imm_desc.cmd};
                if (bus_tx_done_i) begin
                  issue_phase_d = issue_phase_q + 8'h1;
                end
              end

              8'd5: begin
                if (imm_bcast_has_event_byte) begin
                  sel_od_pp = 1'b1;
                  bus_tx_req_byte = 1'b1;
                  bus_tx_req_value = imm_desc.def_or_data_byte1;
                  if (bus_tx_done_i) begin
                    issue_phase_d   = issue_phase_q + 8'h1;
                    resp_data_len_d = resp_data_len_q + 16'h1;
                  end
                end else begin
                  issue_phase_d = issue_phase_q + 8'h1;
                end
              end

              8'd6: begin
                if (imm_bcast_has_event_byte) begin
                  sel_od_pp = 1'b1;
                  bus_tx_req_bit = 1'b1;
                  bus_tx_req_value = {7'b0, ~^imm_desc.def_or_data_byte1};
                  if (bus_tx_done_i) begin
                    issue_phase_d = issue_phase_q + 8'h1;
                  end
                end else begin
                  issue_phase_d = issue_phase_q + 8'h1;
                end
              end

              default: begin
                if (issue_phase_q == PhaseBroadcastCccStop) begin
                  if (imm_desc.toc) begin
                    request_stop(1'b0);
                    if (scl_gen_done_i) begin
                      issue_phase_d = issue_phase_q + 8'h1;
                    end
                  end else begin
                    request_stop(1'b1);
                    if (scl_gen_done_i) begin
                      issue_phase_d = issue_phase_q + 8'h1;
                    end
                  end
                end
              end
            endcase
          end
        end

        FetchTxData: begin
          use_i2c_timing = !target_is_i3c;
          if (tx_underflow_q || tx_queue_empty_i) begin
            tx_underflow_d  = 1'b1;
            tx_queue_rready = 1'b0;
            request_stop(1'b0);
          end else begin
            tx_queue_rready = 1'b1;
          end
          if (!tx_underflow_q && tx_queue_rvalid_i) begin
            tx_byte_idx_d = 2'h0;
          end
        end

        InitWrite: begin
          sel_i3c_i2c    = target_is_i3c;
          use_i2c_timing = !target_is_i3c;
          sel_od_pp      = 1'b0;
          gen_clock      = 1'b1;
          if (addr_nack_q) begin
            request_stop(1'b0);
          end else if (target_is_i3c) begin
            drive_i3c_addr_preamble(Write);
          end else begin
            drive_i2c_addr_preamble(Write);
          end
        end

        InitRead: begin
          sel_i3c_i2c    = target_is_i3c;
          use_i2c_timing = !target_is_i3c;
          sel_od_pp      = 1'b0;
          gen_clock      = 1'b1;
          if (addr_nack_q) begin
            request_stop(1'b0);
          end else if (target_is_i3c) begin
            drive_i3c_addr_preamble(Read);
          end else begin
            drive_i2c_addr_preamble(Read);
          end
        end

        IssueDAA: begin
          gen_clock = 1'b1;
          scl_stop_done_d = scl_stop_done_q;
          sel_i3c_i2c = 1'b1;
          sel_od_pp   = 1'b0;
          unique case (issue_phase_q)
            8'd3: begin
              sel_od_pp = 1'b1;
              bus_tx_req_byte = 1'b1;
              bus_tx_req_value = ENTDAA;
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end

            8'd4: begin
              sel_od_pp        = 1'b1;
              bus_tx_req_bit   = 1'b1;
              bus_tx_req_value = {7'b0, ~^8'(ENTDAA)};
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end

            default: begin
              if (issue_phase_q > 8'd4) begin
                ccc_valid     = 1'b1;
                daa_stop      = hc_aborted_q || abort_i;
                ccc_dev_count = aa_desc.dev_count;
                daa_dev_idx   = aa_desc.dev_idx;
                hc_aborted_d |= abort_i;
                daa_nack_error_d |= daa_nack_error_i;
                not_supported_d |= daa_invalid_addr_i;
                if (daa_wr_busy_q) begin
                  rx_queue_wdata = daa_rx_result_word(daa_wr_phase_q, daa_pid_q, daa_bcr_q,
                                                      daa_dcr_q, daa_addr_q);
                  if (rx_queue_wready_i && !rx_queue_full_i) begin
                    rx_queue_wvalid = 1'b1;
                    resp_data_len_d = resp_data_len_q + 16'd4;
                    if (daa_wr_phase_q == 2'd2) begin
                      daa_wr_busy_d  = 1'b0;
                      daa_wr_phase_d = 2'd0;
                    end else begin
                      daa_wr_phase_d = daa_wr_phase_q + 2'd1;
                    end
                  end else begin
                    rx_overflow_d     = 1'b1;
                    daa_wr_busy_d     = 1'b0;
                    daa_wr_phase_d    = 2'd0;
                    entdaa_stop_req_d = 1'b1;
                    gen_stop          = 1'b1;
                  end
                end else if (daa_address_valid_i && !daa_wr_busy_q && !rx_overflow_q && !entdaa_stop_req_q) begin
                  daa_pid_d      = daa_pid_i;
                  daa_bcr_d      = daa_bcr_i;
                  daa_dcr_d      = daa_dcr_i;
                  daa_addr_d     = daa_address_i;
                  daa_wr_busy_d  = 1'b1;
                  daa_wr_phase_d = 2'd0;
                end
                if (daa_stop_req_i || (ccc_done_i && !daa_stopped_i) || entdaa_stop_req_q) begin
                  gen_stop = 1'b1;
                end

                if (ccc_done_i && !daa_stopped_i) begin
                  entdaa_stop_req_d = 1'b1;
                end

                if (entdaa_stop_req_q && scl_gen_done_i) begin
                  entdaa_stop_req_d = 1'b0;
                end
              end
            end
          endcase
        end

        IssueI3CWrite: begin
          gen_clock = 1'b1;
          scl_stop_done_d = scl_stop_done_q;
          sel_i3c_i2c = 1'b1;
          if (remaining_len_q == 16'h0 &&
              issue_phase_q > PhaseAddrAck &&
              bus_tx_idle_i && bus_rx_idle_i) begin
            if ((cmd_attr == ImmediateDataTransfer) ? imm_desc.toc : reg_desc.toc) begin
              request_stop(1'b0);
            end else if (cmd_attr == ImmediateDataTransfer) begin
              request_stop(1'b1);
            end else if (next_cmd_available && next_cmd_supported) begin
              if (!active_wroc || resp_queue_wready_i) begin
                accept_continuation_cmd(1'b0);
              end else begin
                gen_clock = 1'b0;
              end
            end else if (!next_cmd_available) begin
              request_missing_continuation_stop();
            end else begin
              request_stop(1'b1);
            end
          end else if (remaining_len_q > 16'h0) begin
            sel_od_pp = 1'b1;
            if (issue_phase_q[0]) begin
              bus_tx_req_byte = 1'b1;
              bus_tx_req_value = (cmd_attr == ImmediateDataTransfer) ? imm_data_byte :
                                  current_tx_byte;
              if (bus_tx_done_i) issue_phase_d = issue_phase_q + 8'h1;
            end else begin
              bus_tx_req_bit = 1'b1;
              bus_tx_req_value = {
                7'b0, ~^((cmd_attr == ImmediateDataTransfer) ? imm_data_byte : current_tx_byte)
              };
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
                if (cmd_attr != ImmediateDataTransfer) begin
                  tx_byte_idx_d = next_byte_idx(tx_byte_idx_q);
                end
                remaining_len_d = remaining_len_q - 16'h1;
                resp_data_len_d = resp_data_len_q + 16'h1;
              end
            end
          end
        end

        IssueI2CWrite: begin
          gen_clock = 1'b1;
          scl_stop_done_d = scl_stop_done_q;
          use_i2c_timing = 1'b1;
          sel_i3c_i2c = 1'b0;
          sel_od_pp = 1'b0;
          if (data_nack_q ||
              (remaining_len_q == 16'h0 &&
               issue_phase_q > PhaseAddrAck &&
               bus_tx_idle_i && bus_rx_idle_i)) begin
            if (data_nack_q ||
                ((cmd_attr == ImmediateDataTransfer) ? imm_desc.toc : reg_desc.toc) ||
                addr_nack_q) begin
              request_stop(1'b0);
            end else begin
              request_stop(1'b1);
            end
          end else if (remaining_len_q > 16'h0) begin
            if (issue_phase_q[0]) begin
              bus_tx_req_byte = 1'b1;
              bus_tx_req_value = (cmd_attr == ImmediateDataTransfer) ? imm_data_byte :
                                  current_tx_byte;
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end else begin
              bus_rx_req_bit = 1'b1;
              if (bus_rx_done_i) begin
                data_nack_d   = bus_rx_data_i[0];
                issue_phase_d = issue_phase_q + 8'h1;
                if (cmd_attr != ImmediateDataTransfer) begin
                  tx_byte_idx_d = next_byte_idx(tx_byte_idx_q);
                end
                remaining_len_d = remaining_len_q - 16'h1;
                resp_data_len_d = resp_data_len_q + 16'h1;
              end
            end
          end
        end

        IssueI3CRead: begin
          gen_clock = 1'b1;
          scl_stop_done_d = scl_stop_done_q;
          sel_i3c_i2c = 1'b1;
          if (read_takeover_pending_q) begin
            request_read_takeover();
          end else if ((remaining_len_q == 16'h0 || short_read_q || read_abort_term_q ||
                        rx_overflow_q) && bus_tx_idle_i && bus_rx_idle_i) begin
            if (short_read_q || reg_desc.toc || read_abort_term_q || rx_overflow_q) begin
              request_stop(1'b0);
            end else if (next_cmd_available && next_cmd_supported) begin
              if (!active_wroc || resp_queue_wready_i) begin
                accept_continuation_cmd(read_takeover_done_q);
              end else begin
                gen_clock = 1'b0;
              end
            end else if (!next_cmd_available) begin
              request_missing_continuation_stop();
            end else begin
              request_stop(1'b1);
            end
          end else if (remaining_len_q > 16'h0 && !rx_overflow_q && !short_read_q &&
                       !read_abort_term_q) begin
            sel_od_pp = 1'b1;
            if (issue_phase_q[0]) begin
              bus_rx_req_byte = 1'b1;
              if (bus_rx_done_i) begin
                rx_dword_d    = rx_word_with_byte(rx_dword_q, rx_byte_idx_q, bus_rx_data_i);
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end else begin
              bus_rx_req_bit_handoff = 1'b1;
              if (bus_rx_done_i) begin
                issue_phase_d   = issue_phase_q + 8'h1;
                rx_byte_idx_d   = next_byte_idx(rx_byte_idx_q);
                remaining_len_d = remaining_len_q - 16'h1;
                resp_data_len_d = resp_data_len_q + 16'h1;
                if (abort_i) begin
                  request_rx_commit(rx_dword_q);
                  read_abort_term_d = 1'b1;
                  hc_aborted_d      = 1'b1;
                  if (bus_rx_data_i[0]) begin
                    request_read_takeover();
                  end else begin
                    request_stop(1'b0);
                  end
                end else if (remaining_len_d == 16'h0) begin
                  request_rx_commit(rx_dword_q);
                  if (bus_rx_data_i[0]) begin
                    request_read_takeover();
                  end
                end else if (bus_rx_data_i[0] == 1'b0) begin
                  request_rx_commit(rx_dword_q);
                  request_stop(1'b0);
                  short_read_d = 1'b1;
                end else if (rx_byte_idx_q == 2'd3) begin
                  request_rx_commit(rx_dword_q);
                  if (rx_overflow_d) begin
                    request_read_takeover();
                  end
                end
              end
            end
          end
        end

        IssueI2CRead: begin
          gen_clock = 1'b1;
          scl_stop_done_d = scl_stop_done_q;
          use_i2c_timing = 1'b1;
          sel_i3c_i2c = 1'b0;
          sel_od_pp = 1'b0;
          if (rx_overflow_q ||
              read_abort_term_q ||
              (remaining_len_q == 16'h0 &&
               issue_phase_q > PhaseAddrAck &&
               bus_tx_idle_i && bus_rx_idle_i)) begin
            if (rx_overflow_q || read_abort_term_q || reg_desc.toc) begin
              request_stop(1'b0);
            end else begin
              request_stop(1'b1);
            end
          end else if (remaining_len_q > 16'h0) begin
            if (issue_phase_q[0]) begin
              bus_rx_req_byte = 1'b1;
              if (abort_i) begin
                hc_aborted_d = 1'b1;
              end
              if (bus_rx_done_i) begin
                rx_dword_d    = rx_word_with_byte(rx_dword_q, rx_byte_idx_q, bus_rx_data_i);
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end else begin
              if (abort_i || hc_aborted_q) begin
                bus_tx_req_bit   = 1'b1;
                bus_tx_req_value = NACK;
              end else if (rx_byte_idx_q == 2'd3 &&
                           (!rx_queue_wready_i || rx_queue_full_i)) begin
                bus_tx_req_bit   = 1'b1;
                bus_tx_req_value = NACK;
              end else if (remaining_len_q > 16'h1) begin
                bus_tx_req_bit   = 1'b1;
                bus_tx_req_value = ACK;
              end else begin
                bus_tx_req_bit   = 1'b1;
                bus_tx_req_value = NACK;
              end
              if (bus_tx_done_i) begin
                issue_phase_d   = issue_phase_q + 8'h1;
                rx_byte_idx_d   = next_byte_idx(rx_byte_idx_q);
                remaining_len_d = remaining_len_q - 16'h1;
                resp_data_len_d = resp_data_len_q + 16'h1;
                if (abort_i || hc_aborted_q) begin
                  request_rx_commit(rx_dword_q);
                  read_abort_term_d = 1'b1;
                  hc_aborted_d      = 1'b1;
                end else if (rx_byte_idx_q == 2'd3) begin
                  request_rx_commit(rx_dword_q);
                end else if (remaining_len_d == 16'h0) begin
                  request_rx_commit(rx_dword_q);
                end
              end
            end
          end
        end

        WriteResp: begin
          resp_queue_wvalid = 1'b1;
          resp_queue_wdata  = make_resp_word(map_resp_err(), cmd_tid, resp_data_len_q);
        end

        default: begin
        end
      endcase
    end

    if (gen_start || gen_rstart || gen_stop) begin
      sel_od_pp = 1'b0;
      gen_clock = 1'b0;
    end

    if ((gen_start || gen_rstart || gen_stop) && !use_i2c_timing) begin
      scl_use_od_low = 1'b1;
    end else if (state_q == I3CBcastHeader) begin
      scl_use_od_low = !sel_od_pp;
    end else if (state_q == IssueImmediateCcc) begin
      scl_use_od_low = !sel_od_pp;
    end else if (state_q == InitWrite && target_is_i3c) begin
      scl_use_od_low = !sel_od_pp;
    end else if (state_q == InitRead && target_is_i3c) begin
      scl_use_od_low = !sel_od_pp;
    end else if (state_q == IssueDAA || state_q == IssueI3CWrite ||
                 state_q == IssueI3CRead) begin
      scl_use_od_low = !sel_od_pp;
    end
  end

  assign i3c_fsm_idle_o = i3c_fsm_idle;
  assign cmd_queue_rready_o = cmd_queue_rready;
  assign dat_read_valid_hw_o = dat_read_valid_hw_q;
  assign dat_index_hw_o = dat_index_hw;

  assign tx_queue_rready_o = tx_queue_rready;

  assign rx_queue_wvalid_o = rx_queue_wvalid;
  assign rx_queue_wdata_o = rx_queue_wdata;

  assign resp_queue_wvalid_o = resp_queue_wvalid;
  assign resp_queue_wdata_o = resp_queue_wdata;

  assign gen_start_o = gen_start;
  assign gen_rstart_o = gen_rstart;
  assign takeover_o = takeover;
  assign gen_stop_o = gen_stop;
  assign gen_clock_o = gen_clock;
  assign gen_idle_o = gen_idle;
  assign sel_i3c_i2c_o = sel_i3c_i2c;
  assign use_i2c_timing_o = use_i2c_timing;
  assign scl_use_od_low_o = scl_use_od_low;

  assign bus_tx_req_byte_o = bus_tx_req_byte;
  assign bus_tx_req_bit_o = bus_tx_req_bit;
  assign bus_tx_req_value_o = bus_tx_req_value;
  assign bus_rx_req_byte_o = bus_rx_req_byte;
  assign bus_rx_req_bit_o = bus_rx_req_bit;
  assign bus_rx_req_bit_handoff_o = bus_rx_req_bit_handoff;

  assign ccc_valid_o = ccc_valid;
  assign daa_stop_o = daa_stop;
  assign daa_dev_idx_o = daa_dev_idx;
  assign ccc_dev_count_o = ccc_dev_count;

  assign sel_od_pp_o = sel_od_pp;

endmodule
