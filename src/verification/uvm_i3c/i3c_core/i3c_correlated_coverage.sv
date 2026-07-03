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

    cp_direction: coverpoint item.rnw iff (item.response_valid) {
      bins write = {1'b0};
      bins read = {1'b1};
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

    cx_status_direction: cross cp_status, cp_direction {
      ignore_bins read_nack =
          binsof(cp_direction.read) && binsof(cp_status.nack);
      ignore_bins read_data_nack =
          binsof(cp_direction.read) && binsof(cp_status.data_nack_or_bus_aborted);
      ignore_bins write_short_read =
          binsof(cp_direction.write) && binsof(cp_status.short_read);
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

    cx_requested_length_relation: cross cp_requested_len, cp_length_relation {
      ignore_bins zero_request_non_exact =
          binsof(cp_requested_len.zero) && !binsof(cp_length_relation.exact);
      ignore_bins one_request_positive_partial =
          binsof(cp_requested_len.one) &&
          (binsof(cp_length_relation.short) ||
           binsof(cp_length_relation.partial_abort) ||
           binsof(cp_length_relation.partial_overflow));
      // FIFO data moves in DWORDs. For a 2..4-byte request, an overflow/underflow
      // therefore occurs either before any byte (zero) or after the full request (exact).
      ignore_bins short_request_partial_overflow =
          binsof(cp_requested_len.short) &&
          binsof(cp_length_relation.partial_overflow);
    }
  endgroup

  covergroup cg_ccc_response;
    option.per_instance = 1;

    cp_operation: coverpoint item.ccc_opcode iff (item.ccc_response_valid) {
      bins enec = {ENEC, DIR_ENEC};
      bins disec = {DISEC, DIR_DISEC};
    }

    cp_form: coverpoint item.ccc_direct iff (item.ccc_response_valid) {
      bins broadcast = {1'b0};
      bins direct = {1'b1};
    }

    cp_response: coverpoint item.resp_status iff (item.ccc_response_valid) {
      bins success = {Success};
      bins address_nack = {AddrHeader};
      bins hc_aborted = {HcAborted};
    }

    cx_operation_form_response: cross cp_operation, cp_form, cp_response;
  endgroup

  covergroup cg_daa_result;
    option.per_instance = 1;

    cp_requested_count: coverpoint item.daa_requested_count iff (item.daa_valid) {
      bins one = {1};
      bins two = {2};
      bins three_to_fifteen = {[3 : 15]};
    }

    cp_joined_count: coverpoint item.daa_joined_count iff (item.daa_valid) {
      bins zero = {0};
      bins one = {1};
      bins two = {2};
      bins three_or_more = {[3 : 15]};
    }

    cp_rstart_count: coverpoint item.daa_rstart_count iff (item.daa_valid) {
      bins one = {1};
      bins two = {2};
      bins three_or_more = {[3 : 16]};
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

    cx_requested_joined_result: cross cp_requested_count, cp_joined_count, cp_result {
      ignore_bins requested_one_joined_too_many =
          binsof(cp_requested_count.one) &&
          (binsof(cp_joined_count.two) || binsof(cp_joined_count.three_or_more));
      ignore_bins requested_two_joined_too_many =
          binsof(cp_requested_count.two) && binsof(cp_joined_count.three_or_more);

      ignore_bins assigned_all_count_mismatch =
          binsof(cp_result.assigned_all) &&
          ((binsof(cp_requested_count.one) &&
            (binsof(cp_joined_count.zero) || binsof(cp_joined_count.two) ||
             binsof(cp_joined_count.three_or_more))) ||
           (binsof(cp_requested_count.two) &&
            (binsof(cp_joined_count.zero) || binsof(cp_joined_count.one) ||
             binsof(cp_joined_count.three_or_more))) ||
           (binsof(cp_requested_count.three_to_fifteen) &&
            (binsof(cp_joined_count.zero) || binsof(cp_joined_count.one) ||
             binsof(cp_joined_count.two))));

      ignore_bins fewer_count_mismatch =
          binsof(cp_result.fewer_than_count) &&
          (binsof(cp_joined_count.zero) || binsof(cp_requested_count.one) ||
           (binsof(cp_requested_count.two) && binsof(cp_joined_count.two)));

      ignore_bins no_device_with_joined_target =
          binsof(cp_result.no_device) &&
          (binsof(cp_joined_count.one) || binsof(cp_joined_count.two) ||
           binsof(cp_joined_count.three_or_more));
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

  function new(string name = "i3c_correlated_coverage", uvm_component parent = null);
    super.new(name, parent);
    cg_immediate_transfer = new();
    cg_response_status = new();
    cg_response_length = new();
    cg_ccc_response = new();
    cg_daa_result = new();
    cg_daa_result_response = new();
    cg_daa_dat_boundary = new();
  endfunction

  virtual function void write(i3c_correlated_item t);
    item = t;
    cg_immediate_transfer.sample();
    cg_response_status.sample();
    cg_response_length.sample();
    cg_ccc_response.sample();
    cg_daa_result.sample();
    cg_daa_result_response.sample();
    cg_daa_dat_boundary.sample();
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info("I3C_CORRELATED_COVERAGE", $sformatf(
              {"cg_immediate_transfer=%0.2f%% cg_response_status=%0.2f%% ",
               "cg_response_length=%0.2f%% cg_ccc_response=%0.2f%% ",
               "cg_daa_result=%0.2f%% cg_daa_result_response=%0.2f%% ",
               "cg_daa_dat_boundary=%0.2f%%"},
              cg_immediate_transfer.get_inst_coverage(),
              cg_response_status.get_inst_coverage(),
              cg_response_length.get_inst_coverage(),
              cg_ccc_response.get_inst_coverage(),
              cg_daa_result.get_inst_coverage(),
              cg_daa_result_response.get_inst_coverage(),
              cg_daa_dat_boundary.get_inst_coverage()), UVM_NONE)
  endfunction
endclass
