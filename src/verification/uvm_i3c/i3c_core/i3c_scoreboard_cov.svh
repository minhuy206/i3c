// -----------------------------------------------------------------------------
// i3c_scoreboard: Correlated coverage
// -----------------------------------------------------------------------------

function length_outcome_e i3c_scoreboard::classify_length_outcome(int unsigned requested_length,
                                                  int unsigned actual_length, bit final_t_bit);
  if (actual_length < requested_length) return LEN_EARLY;
  if (actual_length > requested_length) return LEN_BEYOND;
  if ((actual_length > 0) && final_t_bit) return LEN_BEYOND;
  return LEN_EXACT;
endfunction

function int i3c_scoreboard::find_first_nack_idx(i3c_item item);
  foreach (item.data_nack_q[i]) begin
    if (item.data_nack_q[i]) return int'(i);
  end
  return -1;
endfunction

function nack_position_e i3c_scoreboard::classify_nack_position(int first_nack_idx, int unsigned requested_length,
                                                int unsigned actual_length);
  if (first_nack_idx < 0) return NACK_NONE;
  if ((first_nack_idx >= int'(actual_length)) || (first_nack_idx >= int'(requested_length)))
    return NACK_NONE;
  if (first_nack_idx == 0) return NACK_FIRST;
  if (first_nack_idx == int'(requested_length) - 1) return NACK_LAST;
  return NACK_MIDDLE;
endfunction

function short_boundary_e i3c_scoreboard::classify_short_boundary(int unsigned actual_length);
  // A target can terminate an ACKed I3C read with a T-bit only after at least
  // one data byte. Address NACK and abort-before-data are covered elsewhere.
  if (actual_length == 0) return SHORT_OTHER;
  if (actual_length == 1) return SHORT_ONE_BYTE;
  case (actual_length % 4)
    0: return SHORT_DWORD_BOUNDARY;
    1: return SHORT_PARTIAL_1;
    2: return SHORT_PARTIAL_2;
    3: return SHORT_PARTIAL_3;
    default: return SHORT_OTHER;
  endcase
endfunction

function i3c_daa_dat_span_e i3c_scoreboard::classify_daa_dat_span(int unsigned start_index,
                                                  int unsigned requested_count);
  int unsigned dat_end;

  dat_end = start_index + requested_count;
  if (dat_end > DAT_DEPTH) return DAA_DAT_SPAN_CROSSES_BOUNDARY;
  if (dat_end == DAT_DEPTH) return DAA_DAT_SPAN_ENDS_AT_LAST;
  return DAA_DAT_SPAN_WITHIN_TABLE;
endfunction

function void i3c_scoreboard::fill_private_transfer_coverage(
    ref i3c_correlated_item correlated_item, i3c_item item, exp_txn_t exp,
    txn_cov_outcome_t outcome);
  correlated_item.private_transfer_valid = 1'b1;
  correlated_item.cmd_attr = exp.cmd_attr;
  correlated_item.cmd_present = exp.cmd_present;
  correlated_item.cmd_code = exp.cmd_code;
  correlated_item.target_is_i3c = exp.target_is_i3c;
  correlated_item.rnw = exp.rnw;
  correlated_item.toc = exp.toc;
  correlated_item.wroc = exp.wroc;
  correlated_item.tid = exp.tid;
  correlated_item.requested_len = exp.data_length;
  correlated_item.broadcast_header_enable = broadcast_header_enable;
  correlated_item.expected_broadcast_header = exp.start_with_broadcast_header;
  correlated_item.observed_broadcast_header = item.start_with_broadcast_header;
  correlated_item.addr_nack = item.addr_nack;
  correlated_item.abort_valid = outcome.abort_valid;
  correlated_item.abort_cause = outcome.abort_cause;
  correlated_item.abort_point = outcome.abort_point;
  correlated_item.abort_byte_boundary = classify_abort_byte_boundary(item.num_data);
endfunction

function void i3c_scoreboard::publish_read_coverage(i3c_item item, exp_txn_t exp,
                                                     txn_cov_outcome_t outcome);
  i3c_correlated_item correlated_item;

  correlated_item = i3c_correlated_item::type_id::create("read_correlated_item");
  fill_private_transfer_coverage(correlated_item, item, exp, outcome);
  correlated_item.length_t_bit_valid = exp.target_is_i3c && exp.rnw &&
                                       !item.addr_nack && (item.num_data > 0);
  correlated_item.final_t_bit = read_final_t_bit(item);
  correlated_item.length_outcome =
      classify_length_outcome(exp.data_length, item.num_data, read_final_t_bit(item));

  correlated_item.short_boundary_valid = exp.target_is_i3c && exp.rnw && !item.addr_nack &&
                                          (item.num_data < exp.data_length);
  correlated_item.sre = exp.sre;
  correlated_item.short_boundary = classify_short_boundary(item.num_data);
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::publish_write_coverage(i3c_item item, exp_txn_t exp,
                                                      txn_cov_outcome_t outcome);
  i3c_correlated_item correlated_item;
  int                 first_nack_idx;

  correlated_item = i3c_correlated_item::type_id::create("write_correlated_item");
  fill_private_transfer_coverage(correlated_item, item, exp, outcome);
  correlated_item.data_nack = !item.addr_nack && !exp.target_is_i3c &&
                              data_nack_q_has_nack(item);
  first_nack_idx = find_first_nack_idx(item);
  correlated_item.nack_position_valid = !exp.target_is_i3c && !item.addr_nack &&
                                        (exp.data_length > 0) && (item.num_data > 0);
  correlated_item.nack_position =
      classify_nack_position(first_nack_idx, exp.data_length, item.num_data);
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::publish_integrity_coverage(bit rnw, bit target_is_i3c);
  i3c_correlated_item correlated_item;

  correlated_item = i3c_correlated_item::type_id::create("integrity_correlated_item");
  correlated_item.integrity_valid = 1'b1;
  correlated_item.rnw = rnw;
  correlated_item.target_is_i3c = target_is_i3c;
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::publish_command_boundary(i3c_resp_cmd_class_e previous_class,
                                       i3c_resp_cmd_class_e next_class,
                                       command_boundary_e boundary);
  i3c_correlated_item correlated_item;

  if ((previous_class == RESP_CMD_CLASS_OTHER) || (next_class == RESP_CMD_CLASS_OTHER)) return;
  correlated_item = i3c_correlated_item::type_id::create("command_boundary_item");
  correlated_item.command_boundary_valid = 1'b1;
  correlated_item.command_boundary = boundary;
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::publish_ccc_coverage(exp_txn_t exp, txn_cov_outcome_t outcome,
                                                   int unsigned byte_count);
  i3c_correlated_item correlated_item;

  correlated_item = i3c_correlated_item::type_id::create("ccc_correlated_item");
  correlated_item.cmd_attr = exp.cmd_attr;
  correlated_item.tid = exp.tid;
  correlated_item.resp_status = outcome.resp_status;
  correlated_item.abort_valid = outcome.abort_valid;
  correlated_item.abort_cause = outcome.abort_cause;
  correlated_item.abort_point = outcome.abort_point;
  correlated_item.abort_byte_boundary = classify_abort_byte_boundary(byte_count);
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::publish_entdaa_coverage(exp_txn_t exp, int unsigned joined_count,
                                      i3c_daa_result_e result,
                                      txn_cov_outcome_t outcome, int unsigned byte_count);
  i3c_correlated_item correlated_item;

  correlated_item = i3c_correlated_item::type_id::create("daa_correlated_item");
  correlated_item.cmd_attr = exp.cmd_attr;
  correlated_item.tid = exp.tid;
  correlated_item.resp_status = outcome.resp_status;
  correlated_item.daa_valid = 1'b1;
  correlated_item.daa_requested_count = exp.daa_dev_count;
  correlated_item.daa_joined_count = joined_count;
  correlated_item.daa_result = result;
  correlated_item.daa_dat_valid = 1'b1;
  correlated_item.daa_start_index = exp.daa_dev_idx;
  correlated_item.daa_dat_span = classify_daa_dat_span(exp.daa_dev_idx, exp.daa_dev_count);
  correlated_item.abort_valid = outcome.abort_valid;
  correlated_item.abort_cause = outcome.abort_cause;
  correlated_item.abort_point = outcome.abort_point;
  correlated_item.abort_byte_boundary = classify_abort_byte_boundary(byte_count);
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::publish_recovery_coverage(exp_resp_t exp_resp, bit pass);
  i3c_correlated_item correlated_item;

  if (!pass) return;
  correlated_item = i3c_correlated_item::type_id::create("recovery_correlated_item");
  correlated_item.recovery_valid = 1'b1;
  correlated_item.recovery_source = exp_resp.recovery_source;
  correlated_item.reset_point = exp_resp.reset_point;
  correlated_item.interrupted_cmd_class = exp_resp.interrupted_cmd_class;
  correlated_item.recovery_cmd_class = exp_resp.response_cmd_class;
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::publish_stall_recovery_coverage(exp_resp_t exp_resp, bit pass);
  i3c_correlated_item correlated_item;

  if (!pass) return;
  correlated_item = i3c_correlated_item::type_id::create("stall_recovery_correlated_item");
  correlated_item.stall_recovery_valid = 1'b1;
  correlated_item.stall_type = exp_resp.stall_type;
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::publish_completion_policy_coverage(exp_resp_t exp_resp, bit response_present);
  i3c_correlated_item correlated_item;

  correlated_item = i3c_correlated_item::type_id::create("completion_policy_correlated_item");
  correlated_item.completion_policy_valid =
      exp_resp.response_cmd_class != RESP_CMD_CLASS_OTHER;
  correlated_item.response_cmd_class = exp_resp.response_cmd_class;
  correlated_item.wroc = exp_resp.wroc;
  correlated_item.expected_resp_status = exp_resp.resp_status;
  correlated_item.response_present = response_present;
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::publish_daa_response_coverage(exp_resp_t exp_resp, i3c_response_desc_t resp);
  i3c_correlated_item correlated_item;

  correlated_item = i3c_correlated_item::type_id::create("daa_response_correlated_item");
  correlated_item.daa_response_valid = 1'b1;
  correlated_item.daa_result = exp_resp.daa_result;
  correlated_item.resp_status = resp.err;
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::publish_daa_dat_coverage(int unsigned start_index, int unsigned requested_count,
                                       i3c_resp_err_e resp_status);
  i3c_correlated_item correlated_item;

  correlated_item = i3c_correlated_item::type_id::create("daa_dat_correlated_item");
  correlated_item.resp_status = resp_status;
  correlated_item.daa_dat_valid = 1'b1;
  correlated_item.daa_start_index = start_index;
  correlated_item.daa_dat_span = classify_daa_dat_span(start_index, requested_count);
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::publish_response_coverage(exp_resp_t exp_resp, i3c_response_desc_t resp);
  i3c_correlated_item correlated_item;

  correlated_item = i3c_correlated_item::type_id::create("response_correlated_item");
  correlated_item.response_valid = exp_resp.response_cmd_class != RESP_CMD_CLASS_OTHER;
  correlated_item.response_cmd_class = exp_resp.response_cmd_class;
  correlated_item.rnw = exp_resp.rnw;
  correlated_item.resp_status = resp.err;
  correlated_item.response_length_valid = response_length_applicable(exp_resp.response_cmd_class);
  correlated_item.requested_len = exp_resp.requested_length;
  correlated_item.response_len = resp.data_length;
  correlated_item.response_len_relation = classify_response_length(exp_resp, resp);
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::publish_address_response_coverage(exp_resp_t exp_resp, i3c_response_desc_t resp);
  i3c_correlated_item correlated_item;

  correlated_item = i3c_correlated_item::type_id::create("address_response_correlated_item");
  correlated_item.address_response_valid = exp_resp.address_response_valid;
  correlated_item.response_addr_phase = exp_resp.address_phase_broadcast ?
                                        RESP_ADDR_PHASE_BROADCAST_HEADER :
                                        RESP_ADDR_PHASE_TARGET;
  correlated_item.address_acked = exp_resp.address_acked;
  correlated_item.observed_resp_status = resp.err;
  correlated_ap.write(correlated_item);
endfunction
