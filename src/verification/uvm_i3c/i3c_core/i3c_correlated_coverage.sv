class i3c_correlated_coverage extends uvm_subscriber #(i3c_correlated_item);
  `uvm_component_utils(i3c_correlated_coverage)

  i3c_correlated_item item;

  covergroup cg_immediate_transfer;
    option.per_instance = 1;

    cp_requested_len: coverpoint item.requested_len
        iff (item.cmd_attr == ImmediateDataTransfer &&
             !item.cmd_present) {
      bins dtt[] = {[0 : 4]};
    }

    cp_protocol: coverpoint item.target_is_i3c
        iff (item.cmd_attr == ImmediateDataTransfer &&
             !item.cmd_present) {
      bins i3c = {1'b1};
      bins i2c = {1'b0};
    }

    cp_nack_phase: coverpoint {item.addr_nack, item.data_nack}
        iff (item.cmd_attr == ImmediateDataTransfer &&
             !item.cmd_present &&
             (item.addr_nack || item.data_nack)) {
      bins address_nack = {2'b10};
      bins data_nack = {2'b01};
      illegal_bins both = {2'b11};
    }

    cx_protocol_dtt: cross cp_protocol, cp_requested_len;

    cx_protocol_nack: cross cp_protocol, cp_nack_phase {
      ignore_bins i3c_data_nack = binsof(cp_protocol.i3c) &&
                                  binsof(cp_nack_phase.data_nack);
    }
  endgroup

  covergroup cg_response_status;
    option.per_instance = 1;

    cp_cmd_class: coverpoint item.response_cmd_class iff (item.response_valid) {
      bins regular = {RESP_CMD_CLASS_REGULAR};
      bins immediate = {RESP_CMD_CLASS_IMMEDIATE};
      bins ccc = {RESP_CMD_CLASS_CCC};
      bins daa = {RESP_CMD_CLASS_DAA};
      ignore_bins other = {RESP_CMD_CLASS_OTHER};
    }

    cp_status: coverpoint item.resp_status iff (item.response_valid) {
      bins success = {Success};
      bins addr_header = {AddrHeader};
      bins nack = {Nack};
      bins overflow = {Ovl};
      bins short_read = {I3cShortReadErr};
      bins hc_aborted = {HcAborted};
      bins data_nack_or_bus_aborted = {I2cDataNackOrI3cBusAborted};
      bins not_supported = {NotSupported};
      ignore_bins unreachable = {Crc, Parity, Frame};
    }

    cx_status_cmd_class: cross cp_status, cp_cmd_class {
      ignore_bins regular_nack =
          binsof(cp_cmd_class.regular) && binsof(cp_status.nack);
      ignore_bins immediate_nack =
          binsof(cp_cmd_class.immediate) && binsof(cp_status.nack);
      ignore_bins immediate_overflow =
          binsof(cp_cmd_class.immediate) && binsof(cp_status.overflow);
      ignore_bins immediate_short_read =
          binsof(cp_cmd_class.immediate) && binsof(cp_status.short_read);
      ignore_bins ccc_nack =
          binsof(cp_cmd_class.ccc) && binsof(cp_status.nack);
      ignore_bins ccc_overflow =
          binsof(cp_cmd_class.ccc) && binsof(cp_status.overflow);
      ignore_bins ccc_short_read =
          binsof(cp_cmd_class.ccc) && binsof(cp_status.short_read);
      ignore_bins ccc_data_nack =
          binsof(cp_cmd_class.ccc) && binsof(cp_status.data_nack_or_bus_aborted);
      ignore_bins daa_short_read =
          binsof(cp_cmd_class.daa) && binsof(cp_status.short_read);
      ignore_bins daa_data_nack =
          binsof(cp_cmd_class.daa) && binsof(cp_status.data_nack_or_bus_aborted);
    }

  endgroup

  covergroup cg_response_length;
    option.per_instance = 1;

    cp_requested_len: coverpoint item.requested_len iff (item.response_length_valid) {
      bins zero = {0};
      bins one = {1};
      bins short = {[2 : 4]};
      bins mid_size = {[5 : 8]};
      bins long = {[9 : 16]};
      bins larger = {[17 : 16'hffff]};
    }

    cp_length_relation: coverpoint item.response_len_relation
        iff (item.response_length_valid) {
      bins exact = {RESP_LEN_EXACT};
      bins short = {RESP_LEN_SHORT};
      bins zero = {RESP_LEN_ZERO};
      bins partial_abort = {RESP_LEN_PARTIAL_ABORT};
      bins partial_overflow = {RESP_LEN_PARTIAL_OVERFLOW};
      ignore_bins other = {RESP_LEN_OTHER};
    }

  endgroup

  covergroup cg_daa_result;
    option.per_instance = 1;

    cp_requested_count: coverpoint item.daa_requested_count iff (item.daa_valid) {
      bins one = {1};
      bins multiple = {[2 : 15]};
    }

    cp_joined_count: coverpoint item.daa_joined_count iff (item.daa_valid) {
      bins zero = {0};
      bins one = {1};
      bins multiple = {[2 : 15]};
    }

    cp_result: coverpoint item.daa_result iff (item.daa_valid) {
      bins assigned_all = {DAA_RESULT_ASSIGNED_ALL};
      bins fewer_than_count = {DAA_RESULT_FEWER_THAN_COUNT};
      bins no_device = {DAA_RESULT_NO_DEVICE};
      bins address_rejected = {DAA_RESULT_ADDRESS_REJECTED};
      bins overflow = {DAA_RESULT_OVERFLOW};
      bins abort = {DAA_RESULT_ABORT};
      ignore_bins other = {DAA_RESULT_OTHER};
    }

  endgroup

  covergroup cg_daa_result_response;
    option.per_instance = 1;

    cp_result: coverpoint item.daa_result iff (item.daa_response_valid) {
      bins assigned_all = {DAA_RESULT_ASSIGNED_ALL};
      bins fewer_than_count = {DAA_RESULT_FEWER_THAN_COUNT};
      bins no_device = {DAA_RESULT_NO_DEVICE};
      bins address_rejected = {DAA_RESULT_ADDRESS_REJECTED};
      bins overflow = {DAA_RESULT_OVERFLOW};
      bins abort = {DAA_RESULT_ABORT};
      ignore_bins other = {DAA_RESULT_OTHER};
    }

    cp_response: coverpoint item.resp_status iff (item.daa_response_valid) {
      bins success = {Success};
      bins nack = {Nack};
      bins overflow = {Ovl};
      bins hc_aborted = {HcAborted};
      ignore_bins other = {Crc, Parity, Frame, AddrHeader, I3cShortReadErr,
                           I2cDataNackOrI3cBusAborted, NotSupported};
    }

    cx_result_response: cross cp_result, cp_response {
      ignore_bins normal_completion_non_success =
          (binsof(cp_result.assigned_all) || binsof(cp_result.fewer_than_count) ||
           binsof(cp_result.no_device)) && !binsof(cp_response.success);
      ignore_bins address_rejected_non_nack =
          binsof(cp_result.address_rejected) && !binsof(cp_response.nack);
      ignore_bins overflow_non_overflow =
          binsof(cp_result.overflow) && !binsof(cp_response.overflow);
      ignore_bins abort_non_hc_aborted =
          binsof(cp_result.abort) && !binsof(cp_response.hc_aborted);
      ignore_bins success_with_error_result =
          binsof(cp_response.success) &&
          (binsof(cp_result.address_rejected) || binsof(cp_result.overflow) ||
           binsof(cp_result.abort));
      ignore_bins nack_with_other_result =
          binsof(cp_response.nack) && !binsof(cp_result.address_rejected);
      ignore_bins overflow_with_other_result =
          binsof(cp_response.overflow) && !binsof(cp_result.overflow);
      ignore_bins hc_aborted_with_other_result =
          binsof(cp_response.hc_aborted) && !binsof(cp_result.abort);
    }
  endgroup

  covergroup cg_daa_dat_boundary;
    option.per_instance = 1;

    cp_start_index: coverpoint item.daa_start_index iff (item.daa_dat_valid) {
      bins first = {0};
      bins middle = {[1 : 30]};
      bins last = {31};
    }

    cp_span: coverpoint item.daa_dat_span iff (item.daa_dat_valid) {
      bins within_table = {DAA_DAT_SPAN_WITHIN_TABLE};
      bins ends_at_last = {DAA_DAT_SPAN_ENDS_AT_LAST};
      bins crosses_boundary = {DAA_DAT_SPAN_CROSSES_BOUNDARY};
    }

    cp_response: coverpoint item.resp_status iff (item.daa_dat_valid) {
      bins accepted = {Success, Nack, Ovl, HcAborted};
      bins boundary_rejected = {NotSupported};
      ignore_bins other = {Crc, Parity, Frame, AddrHeader, I3cShortReadErr,
                           I2cDataNackOrI3cBusAborted};
    }

    cx_start_span_response: cross cp_start_index, cp_span, cp_response {
      ignore_bins first_non_within =
          binsof(cp_start_index.first) &&
          (binsof(cp_span.ends_at_last) || binsof(cp_span.crosses_boundary));
      ignore_bins last_within =
          binsof(cp_start_index.last) && binsof(cp_span.within_table);
      ignore_bins accepted_crossing_span =
          binsof(cp_span.crosses_boundary) && binsof(cp_response.accepted);
      ignore_bins rejected_in_range_span =
          (binsof(cp_span.within_table) || binsof(cp_span.ends_at_last)) &&
          binsof(cp_response.boundary_rejected);
    }
  endgroup

  covergroup cg_private_preamble_correlation;
    option.per_instance = 1;

    cp_preamble_policy: coverpoint {
        item.target_is_i3c,
        item.broadcast_header_enable,
        item.expected_broadcast_header,
        item.observed_broadcast_header
    } iff (item.private_transfer_valid) {
      bins i2c_disabled_no_header = {4'b0000};
      bins i2c_enabled_no_header = {4'b0100};
      bins i3c_disabled_no_header = {4'b1000};
      bins i3c_enabled_continuation = {4'b1100};
      bins i3c_enabled_with_header = {4'b1111};
      ignore_bins mismatch[] = {[4'b0001 : 4'b0011],
                                [4'b0101 : 4'b0111],
                                [4'b1001 : 4'b1011],
                                [4'b1101 : 4'b1110]};
    }

  endgroup

  covergroup cg_address_response_correlation;
    option.per_instance = 1;

    cp_phase: coverpoint item.response_addr_phase iff (item.address_response_valid) {
      bins target = {RESP_ADDR_PHASE_TARGET};
      bins broadcast_header = {RESP_ADDR_PHASE_BROADCAST_HEADER};
      ignore_bins other = {RESP_ADDR_PHASE_OTHER};
    }

    cp_address_result: coverpoint item.address_acked iff (item.address_response_valid) {
      bins nack = {1'b0};
      bins ack = {1'b1};
    }

    cp_status: coverpoint item.observed_resp_status iff (item.address_response_valid) {
      bins success = {Success};
      bins addr_header = {AddrHeader};
      bins later_error = {Nack, Ovl, I3cShortReadErr, HcAborted,
                          I2cDataNackOrI3cBusAborted, NotSupported};
      ignore_bins unsupported = {Crc, Parity, Frame};
    }

    cx_phase_ack_status: cross cp_phase, cp_address_result, cp_status {
      ignore_bins nack_non_addr_header =
          binsof(cp_address_result.nack) && !binsof(cp_status.addr_header);
      ignore_bins ack_addr_header =
          binsof(cp_address_result.ack) && binsof(cp_status.addr_header);
    }
  endgroup

  covergroup cg_response_presence_policy;
    option.per_instance = 1;

    cp_cmd_class: coverpoint item.response_cmd_class iff (item.completion_policy_valid) {
      bins regular = {RESP_CMD_CLASS_REGULAR};
      bins immediate = {RESP_CMD_CLASS_IMMEDIATE};
      bins ccc = {RESP_CMD_CLASS_CCC};
      bins daa = {RESP_CMD_CLASS_DAA};
      ignore_bins other = {RESP_CMD_CLASS_OTHER};
    }

    cp_wroc: coverpoint item.wroc iff (item.completion_policy_valid) {
      bins suppress_success = {1'b0};
      bins response_on_completion = {1'b1};
    }

    cp_completion_error: coverpoint (item.expected_resp_status != Success)
        iff (item.completion_policy_valid) {
      bins success = {1'b0};
      bins error = {1'b1};
    }

    cp_response_presence: coverpoint item.response_present
        iff (item.completion_policy_valid) {
      bins absent = {1'b0};
      bins present = {1'b1};
    }

    // This cross covers whether a response is absent/present for each command class.
    // Exact response cardinality remains checker/SVA-owned: a duplicate descriptor is
    // reported as an unexpected RESP after the expected queue entry is consumed.
    cx_cmd_class_wroc_completion_presence: cross cp_cmd_class, cp_wroc,
                                                 cp_completion_error,
                                                 cp_response_presence {
      ignore_bins wroc0_success_with_response =
          binsof(cp_wroc.suppress_success) && binsof(cp_completion_error.success) &&
          binsof(cp_response_presence.present);
      ignore_bins wroc0_error_without_response =
          binsof(cp_wroc.suppress_success) && binsof(cp_completion_error.error) &&
          binsof(cp_response_presence.absent);
      ignore_bins wroc1_without_response =
          binsof(cp_wroc.response_on_completion) && binsof(cp_response_presence.absent);
      ignore_bins daa_wroc0_success =
          binsof(cp_cmd_class.daa) && binsof(cp_wroc.suppress_success) &&
          binsof(cp_completion_error.success);
    }
  endgroup

  covergroup cg_sdr_read_length_t_bit;
    option.per_instance = 1;

    cp_final_t_bit: coverpoint item.final_t_bit iff (item.length_t_bit_valid) {
      bins target_end = {1'b0};
      bins target_has_more = {1'b1};
    }

    cp_length_outcome: coverpoint item.length_outcome iff (item.length_t_bit_valid) {
      bins exact = {LEN_EXACT};
      bins early = {LEN_EARLY};
      bins beyond_requested = {LEN_BEYOND};
    }

    cx_t_bit_length_outcome: cross cp_final_t_bit, cp_length_outcome {
      ignore_bins target_end_beyond = binsof(cp_final_t_bit.target_end) &&
                                      binsof(cp_length_outcome.beyond_requested);
      ignore_bins target_has_more_exact = binsof(cp_final_t_bit.target_has_more) &&
                                          binsof(cp_length_outcome.exact);
    }
  endgroup

  covergroup cg_sdr_read_t_bit_abort;
    option.per_instance = 1;

    cp_final_t_bit: coverpoint item.final_t_bit
        iff (item.private_transfer_valid && item.target_is_i3c && item.rnw &&
             item.length_t_bit_valid && item.abort_valid) {
      bins target_end = {1'b0};
      bins target_has_more = {1'b1};
    }

    cp_abort_cause: coverpoint item.abort_cause
        iff (item.private_transfer_valid && item.target_is_i3c && item.rnw &&
             item.length_t_bit_valid && item.abort_valid) {
      bins hc_abort = {HC_ABORT};
      bins protocol_termination = {PROTOCOL_TERMINATION};
      ignore_bins reset = {RESET};
    }

    cx_t_bit_abort_cause: cross cp_final_t_bit, cp_abort_cause {
      ignore_bins target_has_more_protocol_termination =
          binsof(cp_final_t_bit.target_has_more) &&
          binsof(cp_abort_cause.protocol_termination);
    }
  endgroup

  covergroup cg_i2c_write_nack_position;
    option.per_instance = 1;

    cp_cmd_class: coverpoint item.cmd_attr iff (item.nack_position_valid) {
      bins regular = {RegularTransfer};
      bins immediate = {ImmediateDataTransfer};
      ignore_bins other = {AddressAssignment, ComboTransfer};
    }

    cp_nack_position: coverpoint item.nack_position iff (item.nack_position_valid) {
      bins first = {NACK_FIRST};
      bins middle = {NACK_MIDDLE};
      bins last_requested = {NACK_LAST};
      bins none = {NACK_NONE};
    }
  endgroup

  covergroup cg_short_read_boundary;
    option.per_instance = 1;

    cp_sre: coverpoint item.sre iff (item.short_boundary_valid) {
      bins disabled = {1'b0};
      bins enabled = {1'b1};
    }

    cp_boundary: coverpoint item.short_boundary iff (item.short_boundary_valid) {
      bins one_byte = {SHORT_ONE_BYTE};
      bins dword_boundary = {SHORT_DWORD_BOUNDARY};
      bins partial_1 = {SHORT_PARTIAL_1};
      bins partial_2 = {SHORT_PARTIAL_2};
      bins partial_3 = {SHORT_PARTIAL_3};
      ignore_bins other = {SHORT_OTHER};
    }

  endgroup

  covergroup cg_data_integrity;
    option.per_instance = 1;

    cp_protocol_direction: coverpoint {item.target_is_i3c, item.rnw}
        iff (item.integrity_valid) {
      bins i2c_write = {2'b00};
      bins i2c_read = {2'b01};
      bins i3c_write = {2'b10};
      bins i3c_read = {2'b11};
    }
  endgroup

  covergroup cg_abort_termination;
    option.per_instance = 1;

    cp_cause: coverpoint item.abort_cause iff (item.abort_valid) {
      bins hc_abort = {HC_ABORT};
      bins reset = {RESET};
      bins protocol_termination = {PROTOCOL_TERMINATION};
    }

    cp_point: coverpoint item.abort_point iff (item.abort_valid) {
      bins preamble = {PREAMBLE};
      bins address = {ADDRESS};
      bins tx_data = {TX_DATA};
      bins rx_data = {RX_DATA};
      bins ccc = {CCC};
      bins daa_id = {DAA_ID};
      bins daa_assigned_address = {DAA_ASSIGNED_ADDRESS};
      bins response = {RESPONSE};
    }

    cp_byte_boundary: coverpoint item.abort_byte_boundary iff (item.abort_valid) {
      bins zero = {ABORT_BYTES_ZERO};
      bins one_to_three = {ABORT_BYTES_ONE_TO_THREE};
      bins one_dword = {ABORT_BYTES_ONE_DWORD};
      bins more_than_one_dword = {ABORT_BYTES_MORE_THAN_ONE_DWORD};
    }

    cx_cause_point: cross cp_cause, cp_point {
      ignore_bins reset_after_bus_progress = binsof(cp_cause.reset) &&
          (binsof(cp_point) intersect {ADDRESS, TX_DATA, RX_DATA, CCC, DAA_ID,
                                      DAA_ASSIGNED_ADDRESS, RESPONSE});
      ignore_bins hc_abort_before_active_flow = binsof(cp_cause.hc_abort) &&
          (binsof(cp_point) intersect {PREAMBLE, ADDRESS, RESPONSE});
      ignore_bins protocol_termination_at_daa_id =
          binsof(cp_cause.protocol_termination) &&
          (binsof(cp_point) intersect {DAA_ID});
      ignore_bins protocol_termination_at_ccc =
          binsof(cp_cause.protocol_termination) &&
          (binsof(cp_point) intersect {CCC});
    }
  endgroup

  covergroup cg_recovery;
    option.per_instance = 1;

    cp_source: coverpoint item.recovery_source iff (item.recovery_valid) {
      bins hc_abort = {RECOVERY_HC_ABORT};
      bins reset = {RECOVERY_RESET};
      bins protocol_termination = {RECOVERY_PROTOCOL_TERMINATION};
    }
    cp_reset_point: coverpoint item.reset_point
        iff (item.recovery_valid && (item.recovery_source == RECOVERY_RESET)) {
      bins idle = {RESET_POINT_IDLE};
      bins queued_command = {RESET_POINT_QUEUED_COMMAND};
      bins active_unknown = {RESET_POINT_ACTIVE_UNKNOWN};
    }
    cp_interrupted_class: coverpoint item.interrupted_cmd_class iff (item.recovery_valid) {
      bins regular = {RESP_CMD_CLASS_REGULAR};
      bins immediate = {RESP_CMD_CLASS_IMMEDIATE};
      bins ccc = {RESP_CMD_CLASS_CCC};
      bins daa = {RESP_CMD_CLASS_DAA};
      bins no_active_command = {RESP_CMD_CLASS_OTHER};
    }
    cp_recovery_class: coverpoint item.recovery_cmd_class iff (item.recovery_valid) {
      bins regular = {RESP_CMD_CLASS_REGULAR};
      bins immediate = {RESP_CMD_CLASS_IMMEDIATE};
      bins ccc = {RESP_CMD_CLASS_CCC};
      bins daa = {RESP_CMD_CLASS_DAA};
      ignore_bins other = {RESP_CMD_CLASS_OTHER};
    }
  endgroup

  covergroup cg_command_boundary;
    option.per_instance = 1;

    cp_boundary: coverpoint item.command_boundary iff (item.command_boundary_valid) {
      bins stop = {BOUNDARY_STOP};
      bins repeated_start = {BOUNDARY_REPEATED_START};
      bins toc_continuation = {BOUNDARY_TOC_CONTINUATION};
      bins idle_back_to_back = {BOUNDARY_IDLE_BACK_TO_BACK};
      bins reset_cleared = {BOUNDARY_RESET_CLEARED};
    }
  endgroup

  covergroup cg_stall_recovery;
    option.per_instance = 1;

    cp_stall_type: coverpoint item.stall_type iff (item.stall_recovery_valid) {
      bins tx_empty = {STALL_TX_EMPTY};
      bins rx_full = {STALL_RX_FULL};
      bins resp_full = {STALL_RESP_FULL};
      bins wait_cmd = {STALL_WAIT_CMD};
    }
  endgroup

  function new(string name = "i3c_correlated_coverage", uvm_component parent = null);
    super.new(name, parent);
    cg_immediate_transfer = new();
    cg_response_status = new();
    cg_response_length = new();
    cg_daa_result = new();
    cg_daa_result_response = new();
    cg_daa_dat_boundary = new();
    cg_private_preamble_correlation = new();
    cg_address_response_correlation = new();
    cg_response_presence_policy = new();
    cg_sdr_read_length_t_bit = new();
    cg_sdr_read_t_bit_abort = new();
    cg_i2c_write_nack_position = new();
    cg_short_read_boundary = new();
    cg_data_integrity = new();
    cg_abort_termination = new();
    cg_recovery = new();
    cg_command_boundary = new();
    cg_stall_recovery = new();
  endfunction

  virtual function void write(i3c_correlated_item t);
    item = t;
    cg_immediate_transfer.sample();
    cg_response_status.sample();
    cg_response_length.sample();
    cg_daa_result.sample();
    cg_daa_result_response.sample();
    cg_daa_dat_boundary.sample();
    cg_private_preamble_correlation.sample();
    cg_address_response_correlation.sample();
    cg_response_presence_policy.sample();
    cg_sdr_read_length_t_bit.sample();
    cg_sdr_read_t_bit_abort.sample();
    cg_i2c_write_nack_position.sample();
    cg_short_read_boundary.sample();
    cg_data_integrity.sample();
    cg_abort_termination.sample();
    cg_recovery.sample();
    cg_command_boundary.sample();
    cg_stall_recovery.sample();
  endfunction

  function void report_cov_detail(string message, int verbosity);
    if (!$test$plusargs("COV_DETAIL")) return;
    uvm_report_info("COV_DETAIL", message, verbosity);
    uvm_report_info("CORRELATED_COV_DETAIL", message, verbosity);
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info("I3C_CORRELATED_COVERAGE", $sformatf(
              "cg_immediate_transfer=%0.2f%% cg_response_status=%0.2f%%",
              cg_immediate_transfer.get_inst_coverage(),
              cg_response_status.get_inst_coverage()), UVM_NONE)
    `uvm_info("I3C_CORRELATED_COVERAGE", $sformatf(
              "cg_response_length=%0.2f%% cg_daa_result=%0.2f%%",
              cg_response_length.get_inst_coverage(),
              cg_daa_result.get_inst_coverage()), UVM_NONE)
    `uvm_info("I3C_CORRELATED_COVERAGE", $sformatf(
              "cg_daa_result_response=%0.2f%% cg_daa_dat_boundary=%0.2f%%",
              cg_daa_result_response.get_inst_coverage(),
              cg_daa_dat_boundary.get_inst_coverage()), UVM_NONE)
    `uvm_info("I3C_CORRELATED_COVERAGE", $sformatf(
              {"cg_private_preamble_correlation=%0.2f%% ",
               "cg_address_response_correlation=%0.2f%%"},
              cg_private_preamble_correlation.get_inst_coverage(),
              cg_address_response_correlation.get_inst_coverage()), UVM_NONE)
    `uvm_info("I3C_CORRELATED_COVERAGE", $sformatf(
              {"cg_response_presence_policy=%0.2f%% ",
               "cg_sdr_read_length_t_bit=%0.2f%%"},
              cg_response_presence_policy.get_inst_coverage(),
              cg_sdr_read_length_t_bit.get_inst_coverage()), UVM_NONE)
    `uvm_info("I3C_CORRELATED_COVERAGE", $sformatf(
              {"cg_sdr_read_t_bit_abort=%0.2f%% ",
               "cg_i2c_write_nack_position=%0.2f%%"},
              cg_sdr_read_t_bit_abort.get_inst_coverage(),
              cg_i2c_write_nack_position.get_inst_coverage()), UVM_NONE)
    `uvm_info("I3C_CORRELATED_COVERAGE", $sformatf(
              "cg_short_read_boundary=%0.2f%% cg_data_integrity=%0.2f%%",
              cg_short_read_boundary.get_inst_coverage(),
              cg_data_integrity.get_inst_coverage()), UVM_NONE)
    `uvm_info("I3C_CORRELATED_COVERAGE", $sformatf(
              "cg_abort_termination=%0.2f%% cg_recovery=%0.2f%%",
              cg_abort_termination.get_inst_coverage(),
              cg_recovery.get_inst_coverage()), UVM_NONE)
    `uvm_info("I3C_CORRELATED_COVERAGE", $sformatf(
              "cg_command_boundary=%0.2f%% cg_stall_recovery=%0.2f%%",
              cg_command_boundary.get_inst_coverage(),
              cg_stall_recovery.get_inst_coverage()), UVM_NONE)

    report_cov_detail($sformatf(
              {"cg_immediate_transfer=%0.2f%% cp_requested_len=%0.2f%% ",
               "cp_protocol=%0.2f%% cp_nack_phase=%0.2f%%"},
              cg_immediate_transfer.get_inst_coverage(),
              cg_immediate_transfer.cp_requested_len.get_coverage(),
              cg_immediate_transfer.cp_protocol.get_coverage(),
              cg_immediate_transfer.cp_nack_phase.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              "cg_response_status=%0.2f%% cp_cmd_class=%0.2f%% cp_status=%0.2f%%",
              cg_response_status.get_inst_coverage(),
              cg_response_status.cp_cmd_class.get_coverage(),
              cg_response_status.cp_status.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              {"cg_response_length=%0.2f%% cp_requested_len=%0.2f%% ",
               "cp_length_relation=%0.2f%%"},
              cg_response_length.get_inst_coverage(),
              cg_response_length.cp_requested_len.get_coverage(),
              cg_response_length.cp_length_relation.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              {"cg_daa_result=%0.2f%% cp_requested_count=%0.2f%% ",
               "cp_joined_count=%0.2f%% cp_result=%0.2f%%"},
              cg_daa_result.get_inst_coverage(),
              cg_daa_result.cp_requested_count.get_coverage(),
              cg_daa_result.cp_joined_count.get_coverage(),
              cg_daa_result.cp_result.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              "cg_daa_result_response=%0.2f%% cp_result=%0.2f%% cp_response=%0.2f%%",
              cg_daa_result_response.get_inst_coverage(),
              cg_daa_result_response.cp_result.get_coverage(),
              cg_daa_result_response.cp_response.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              {"cg_daa_dat_boundary=%0.2f%% cp_start_index=%0.2f%% ",
               "cp_span=%0.2f%% cp_response=%0.2f%%"},
              cg_daa_dat_boundary.get_inst_coverage(),
              cg_daa_dat_boundary.cp_start_index.get_coverage(),
              cg_daa_dat_boundary.cp_span.get_coverage(),
              cg_daa_dat_boundary.cp_response.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              "cg_private_preamble_correlation=%0.2f%% cp_preamble_policy=%0.2f%%",
              cg_private_preamble_correlation.get_inst_coverage(),
              cg_private_preamble_correlation.cp_preamble_policy.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              {"cg_address_response_correlation=%0.2f%% cp_phase=%0.2f%% ",
               "cp_address_result=%0.2f%% cp_status=%0.2f%%"},
              cg_address_response_correlation.get_inst_coverage(),
              cg_address_response_correlation.cp_phase.get_coverage(),
              cg_address_response_correlation.cp_address_result.get_coverage(),
              cg_address_response_correlation.cp_status.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              {"cg_response_presence_policy=%0.2f%% cp_cmd_class=%0.2f%% ",
               "cp_wroc=%0.2f%% cp_completion_error=%0.2f%% ",
               "cp_response_presence=%0.2f%%"},
              cg_response_presence_policy.get_inst_coverage(),
              cg_response_presence_policy.cp_cmd_class.get_coverage(),
              cg_response_presence_policy.cp_wroc.get_coverage(),
              cg_response_presence_policy.cp_completion_error.get_coverage(),
              cg_response_presence_policy.cp_response_presence.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              {"cg_sdr_read_length_t_bit=%0.2f%% cp_final_t_bit=%0.2f%% ",
               "cp_length_outcome=%0.2f%%"},
              cg_sdr_read_length_t_bit.get_inst_coverage(),
              cg_sdr_read_length_t_bit.cp_final_t_bit.get_coverage(),
              cg_sdr_read_length_t_bit.cp_length_outcome.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              {"cg_sdr_read_t_bit_abort=%0.2f%% cp_final_t_bit=%0.2f%% ",
               "cp_abort_cause=%0.2f%%"},
              cg_sdr_read_t_bit_abort.get_inst_coverage(),
              cg_sdr_read_t_bit_abort.cp_final_t_bit.get_coverage(),
              cg_sdr_read_t_bit_abort.cp_abort_cause.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              {"cg_i2c_write_nack_position=%0.2f%% cp_cmd_class=%0.2f%% ",
               "cp_nack_position=%0.2f%%"},
              cg_i2c_write_nack_position.get_inst_coverage(),
              cg_i2c_write_nack_position.cp_cmd_class.get_coverage(),
              cg_i2c_write_nack_position.cp_nack_position.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              "cg_short_read_boundary=%0.2f%% cp_sre=%0.2f%% cp_boundary=%0.2f%%",
              cg_short_read_boundary.get_inst_coverage(),
              cg_short_read_boundary.cp_sre.get_coverage(),
              cg_short_read_boundary.cp_boundary.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              "cg_data_integrity=%0.2f%% cp_protocol_direction=%0.2f%%",
              cg_data_integrity.get_inst_coverage(),
              cg_data_integrity.cp_protocol_direction.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              {"cg_abort_termination=%0.2f%% cp_cause=%0.2f%% ",
               "cp_point=%0.2f%% cp_byte_boundary=%0.2f%%"},
              cg_abort_termination.get_inst_coverage(),
              cg_abort_termination.cp_cause.get_coverage(),
              cg_abort_termination.cp_point.get_coverage(),
              cg_abort_termination.cp_byte_boundary.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              {"cg_recovery=%0.2f%% cp_source=%0.2f%% cp_reset_point=%0.2f%% ",
               "cp_interrupted_class=%0.2f%% cp_recovery_class=%0.2f%%"},
              cg_recovery.get_inst_coverage(),
              cg_recovery.cp_source.get_coverage(),
              cg_recovery.cp_reset_point.get_coverage(),
              cg_recovery.cp_interrupted_class.get_coverage(),
              cg_recovery.cp_recovery_class.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              "cg_command_boundary=%0.2f%% cp_boundary=%0.2f%%",
              cg_command_boundary.get_inst_coverage(),
              cg_command_boundary.cp_boundary.get_coverage()), UVM_NONE);
    report_cov_detail($sformatf(
              "cg_stall_recovery=%0.2f%% cp_stall_type=%0.2f%%",
              cg_stall_recovery.get_inst_coverage(),
              cg_stall_recovery.cp_stall_type.get_coverage()), UVM_NONE);
  endfunction
endclass
