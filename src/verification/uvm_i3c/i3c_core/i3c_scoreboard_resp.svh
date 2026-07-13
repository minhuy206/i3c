// -----------------------------------------------------------------------------
// i3c_scoreboard: RX/response and recovery modeling
// -----------------------------------------------------------------------------

function bit i3c_scoreboard::enqueue_rx_word_expectation(bit [3:0] tid, int data_length, int word_idx,
                                         bit [31:0] data, string ctxt);
  exp_rx_data_t rx_exp;

  rx_exp.known               = 1'b1;
  rx_exp.read_id             = -1;
  rx_exp.tid                 = tid;
  rx_exp.data_length         = data_length;
  rx_exp.word_idx            = word_idx;
  rx_exp.data                = data;
  rx_exp.integrity_candidate = 1'b0;
  rx_exp.integrity_protocol  = 1'b0;
  rx_exp.integrity_pattern   = DATA_PATTERN_OTHER;

  if (exp_rx_data_queue.size() < RxFifoDepth) begin
    exp_rx_data_queue.push_back(rx_exp);
    return 1'b0;
  end

  `uvm_info(`gfn, $sformatf(
            "%s RX FIFO overflow inferred: tid=0x%0h word_idx=%0d data=0x%08h",
            ctxt,
            tid,
            word_idx,
            data
            ), UVM_MEDIUM)
  return 1'b1;
endfunction

function void i3c_scoreboard::check_rx_data(bit [31:0] rdata);
  exp_rx_data_t exp;
  bit           word_integrity_pass;
  bit           integrity_last;
  int           valid_bytes;

  if (exp_rx_data_queue.size() == 0) return;

  exp = exp_rx_data_queue.pop_front();
  word_integrity_pass = 1'b1;

  if (!exp.known) begin
    `uvm_info(`gfn, $sformatf("RX FIFO unknown prefill entry ignored: rdata=0x%08h", rdata),
              UVM_MEDIUM)
    return;
  end

  valid_bytes = exp.data_length - (exp.word_idx * 4);
  if (valid_bytes > 4) valid_bytes = 4;
  integrity_last = exp.word_idx == (((exp.data_length + 3) / 4) - 1);

  for (int byte_idx = 0; byte_idx < 4; byte_idx++) begin
    bit [7:0] act_byte;
    bit [7:0] exp_byte;

    act_byte = rdata[(byte_idx*8)+:8];
    exp_byte = exp.data[(byte_idx*8)+:8];

    if (byte_idx < valid_bytes) begin
      if (act_byte != exp_byte) word_integrity_pass = 1'b0;
      `DV_CHECK_EQ(
          act_byte, exp_byte,
          $sformatf("RX FIFO byte mismatch: tid=0x%0h actual_len=%0d word_idx=%0d byte_lane=%0d",
                    exp.tid, exp.data_length, exp.word_idx, byte_idx))
    end else begin
      `DV_CHECK_EQ(act_byte, 8'h00, $sformatf(
                   "RX FIFO padding byte should be zero: tid=0x%0h actual_len=%0d word_idx=%0d byte_lane=%0d",
                   exp.tid,
                   exp.data_length,
                   exp.word_idx,
                   byte_idx
                   ))
    end
  end

  if (exp.integrity_candidate && (exp.read_id >= 0)) begin
    if (!read_integrity_pass.exists(exp.read_id)) read_integrity_pass[exp.read_id] = 1'b1;
    read_integrity_pass[exp.read_id] &= word_integrity_pass;
    if (integrity_last) begin
      if (read_integrity_pass[exp.read_id]) begin
        publish_integrity_coverage(1'b1, exp.integrity_protocol, exp.integrity_pattern);
      end
      read_integrity_pass.delete(exp.read_id);
    end
  end
  `uvm_info(`gfn, $sformatf(
            "RX FIFO DATA: tid=0x%0h word_idx=%0d valid_bytes=%0d expected_from_bus=0x%08h observed_from_controller=0x%08h",
            exp.tid,
            exp.word_idx,
            valid_bytes,
            exp.data,
            rdata
            ), UVM_LOW)
endfunction

function void i3c_scoreboard::set_rx_fifo_level_unknown(int unsigned count, string ctxt);
  exp_rx_data_t unknown_entry;
  int unsigned  model_count;

  exp_rx_data_queue.delete();
  model_count = count;
  unknown_entry.known = 1'b0;
  unknown_entry.read_id = -1;
  unknown_entry.tid = '0;
  unknown_entry.data_length = 0;
  unknown_entry.word_idx = 0;
  unknown_entry.data = '0;
  unknown_entry.integrity_candidate = 1'b0;
  unknown_entry.integrity_protocol = 1'b0;
  unknown_entry.integrity_pattern = DATA_PATTERN_OTHER;

  if (count > RxFifoDepth) begin
    `uvm_error(`gfn, $sformatf(
                         "%s: RX FIFO backdoor level %0d exceeds scoreboard model depth %0d",
                         ctxt, count, RxFifoDepth))
    model_count = RxFifoDepth;
  end

  for (int unsigned i = 0; i < model_count; i++) begin
    unknown_entry.word_idx = int'(i);
    exp_rx_data_queue.push_back(unknown_entry);
  end

  `uvm_info(`gfn, $sformatf(
            "%s: RX FIFO scoreboard model set to %0d unknown word(s)", ctxt, model_count),
            UVM_MEDIUM)
endfunction

function void i3c_scoreboard::check_resp(bit [31:0] rdata);
  i3c_response_desc_t resp;

  if (unknown_resp_fifo_words > 0) begin
    unknown_resp_fifo_words--;
    `uvm_info(`gfn, $sformatf(
                        "RESP FIFO backdoor word consumed: rdata=0x%08h remaining_unknown=%0d",
                        rdata, unknown_resp_fifo_words), UVM_MEDIUM)
    return;
  end

  if (exp_resp_queue.size() > 0) begin
    check_exp_resp(rdata);
    return;
  end

  resp = i3c_response_desc_t'(rdata);
  `uvm_error(`gfn, $sformatf(
             "Unexpected RESP: tid=0x%0h status=%s (0x%0h) data_length=%0d rdata=0x%08h",
             resp.tid,
             resp_status_to_string(
                 resp.err_status
             ),
             resp.err_status,
             resp.data_length,
             rdata
             ))
endfunction

function void i3c_scoreboard::record_exp_resp(exp_resp_seed_t seed);
  exp_resp_t exp_resp;

  exp_resp.rnw = seed.rnw;
  exp_resp.tid = seed.tid;
  exp_resp.data_length = seed.data_length;
  exp_resp.requested_length = seed.requested_length;
  exp_resp.resp_status = seed.resp_status;
  exp_resp.response_cmd_class = seed.response_cmd_class;
  exp_resp.wroc = seed.wroc;
  exp_resp.address_response_valid = seed.address_response_valid;
  exp_resp.address_phase_broadcast = seed.address_phase_broadcast;
  exp_resp.address_acked = seed.address_acked;
  exp_resp.is_ccc = seed.is_ccc;
  exp_resp.ccc_opcode = seed.ccc_opcode;
  exp_resp.ccc_direct = seed.ccc_direct;
  exp_resp.daa_dat_valid = seed.daa_dat_valid;
  exp_resp.daa_start_index = seed.daa_start_index;
  exp_resp.daa_requested_count = seed.daa_requested_count;
  exp_resp.daa_response_valid = seed.daa_response_valid;
  exp_resp.daa_result = seed.daa_result;
  exp_resp.abort_response_valid = pending_abort_response_valid;
  exp_resp.abort_cause = pending_abort_cause;
  exp_resp.abort_point = pending_abort_point;
  exp_resp.abort_byte_boundary = pending_abort_byte_boundary;
  pending_abort_response_valid = 1'b0;

  exp_resp.recovery_valid = recovery_pending;
  exp_resp.recovery_source = recovery_source;
  exp_resp.reset_point = recovery_reset_point;
  exp_resp.interrupted_cmd_class = interrupted_command_class;
  recovery_pending = 1'b0;

  exp_resp.stall_recovery_valid = stall_recovery_pending;
  exp_resp.stall_type = pending_stall_type;
  exp_resp.stall_cmd_class = pending_stall_cmd_class;
  stall_recovery_pending = 1'b0;

  // RESP-full recovery belongs to this command: its matching descriptor proves
  // that the pending response was eventually accepted after backpressure.
  if (response_expected(exp_resp.wroc, exp_resp.resp_status) && response_fifo_is_full()) begin
    exp_resp.stall_recovery_valid = 1'b1;
    exp_resp.stall_type = STALL_RESP_FULL;
    exp_resp.stall_cmd_class = exp_resp.response_cmd_class;
  end

  if (!response_expected(exp_resp.wroc, exp_resp.resp_status)) begin
    publish_completion_policy_coverage(exp_resp, 1'b0);
    if (exp_resp.recovery_valid)
      publish_recovery_coverage(exp_resp, exp_resp.resp_status == Success);
    if (exp_resp.stall_recovery_valid)
      publish_stall_recovery_coverage(exp_resp, exp_resp.resp_status == Success);
    `uvm_info(`gfn, $sformatf("RESP suppressed: tid=0x%0h wroc=%0b status=%s", exp_resp.tid,
                              exp_resp.wroc, resp_status_to_string(exp_resp.resp_status)),
              UVM_MEDIUM)
    return;
  end

  `uvm_info(`gfn, $sformatf(
            "RESP queued: tid=0x%0h rnw=%0b data_length=%0d status=%s",
            exp_resp.tid,
            exp_resp.rnw,
            exp_resp.data_length,
            resp_status_to_string(
                exp_resp.resp_status
            )
            ), UVM_MEDIUM)
  exp_resp_queue.push_back(exp_resp);
endfunction

function void i3c_scoreboard::check_exp_resp(bit [31:0] rdata);
  exp_resp_t          exp_resp;
  i3c_response_desc_t resp;
  bit                 response_matches;

  if (exp_resp_queue.size() == 0) return;

  exp_resp = exp_resp_queue.pop_front();
  resp = i3c_response_desc_t'(rdata);
  response_matches = (resp.err_status == exp_resp.resp_status) &&
                     (resp.tid == exp_resp.tid) &&
                     (resp.data_length == exp_resp.data_length);

  if (resp.err_status != exp_resp.resp_status) begin
    `uvm_error(
        `gfn,
        $sformatf(
            "RESP status mismatch: expected=%s (0x%0h) actual=%s (0x%0h) tid=0x%0h data_length=%0d rdata=0x%08h",
            resp_status_to_string(exp_resp.resp_status), exp_resp.resp_status,
            resp_status_to_string(resp.err_status), resp.err_status, exp_resp.tid,
            exp_resp.data_length, rdata))
  end
  if (resp.tid != exp_resp.tid) begin
    `uvm_error(`gfn, $sformatf("RESP TID mismatch: expected=0x%0h actual=0x%0h rdata=0x%08h",
                               exp_resp.tid, resp.tid, rdata))
  end
  if (resp.data_length != exp_resp.data_length) begin
    `uvm_error(`gfn,
               $sformatf(
                   "RESP data length mismatch: expected=%0d actual=%0d tid=0x%0h rdata=0x%08h",
                   exp_resp.data_length, resp.data_length, exp_resp.tid, rdata))
  end

  `uvm_info(`gfn, $sformatf(
            "RESPONSE: expected_tid=0x%0h observed_tid=0x%0h expected_status=%s observed_status=%s expected_data_length=%0d observed_data_length=%0d",
            exp_resp.tid,
            resp.tid,
            resp_status_to_string(
                exp_resp.resp_status
            ),
            resp_status_to_string(
                resp.err_status
            ),
            exp_resp.data_length,
            resp.data_length
            ), UVM_LOW)

  publish_completion_policy_coverage(exp_resp, 1'b1);
  publish_response_descriptor_coverage(exp_resp, resp);

  if (exp_resp.is_ccc && response_matches) begin
    publish_ccc_response_coverage(exp_resp, resp);
  end
  if ((exp_resp.response_cmd_class != RESP_CMD_CLASS_OTHER) && response_matches) begin
    publish_response_coverage(exp_resp, resp);
  end
  if (exp_resp.address_response_valid && response_matches) begin
    publish_address_response_coverage(exp_resp, resp);
  end
  if (exp_resp.daa_dat_valid && response_matches) begin
    publish_daa_dat_coverage(exp_resp.daa_start_index, exp_resp.daa_requested_count,
                             resp.err_status);
  end
  if (exp_resp.daa_response_valid && response_matches) begin
    publish_daa_response_coverage(exp_resp, resp);
  end
  if (exp_resp.abort_response_valid && response_matches) begin
    publish_abort_response_coverage(exp_resp, resp);
  end
  if (exp_resp.recovery_valid) begin
    publish_recovery_coverage(exp_resp, response_matches && (resp.err_status == Success));
  end
  if (exp_resp.stall_recovery_valid) begin
    publish_stall_recovery_coverage(exp_resp, response_matches && (resp.err_status == Success));
  end
endfunction

function void i3c_scoreboard::set_resp_fifo_level_unknown(int unsigned count, string ctxt);
  unknown_resp_fifo_words = count;
  `uvm_info(`gfn, $sformatf(
            "%s: RESP FIFO scoreboard model set to %0d unknown word(s)", ctxt, count), UVM_MEDIUM)
endfunction

function bit i3c_scoreboard::response_expected(bit wroc, i3c_resp_err_status_e resp_status);
  return wroc || (resp_status != Success);
endfunction

function i3c_resp_cmd_class_e i3c_scoreboard::classify_response_cmd(i3c_cmd_attr_e cmd_attr, bit is_ccc);
  case (cmd_attr)
    RegularTransfer:       return RESP_CMD_CLASS_REGULAR;
    ImmediateDataTransfer: return is_ccc ? RESP_CMD_CLASS_CCC : RESP_CMD_CLASS_IMMEDIATE;
    AddressAssignment:     return RESP_CMD_CLASS_DAA;
    default:               return RESP_CMD_CLASS_OTHER;
  endcase
endfunction

function bit i3c_scoreboard::response_length_applicable(i3c_resp_cmd_class_e cmd_class);
  return (cmd_class == RESP_CMD_CLASS_REGULAR) || (cmd_class == RESP_CMD_CLASS_IMMEDIATE);
endfunction

function i3c_resp_len_relation_e i3c_scoreboard::classify_response_length(exp_resp_t exp_resp,
                                                          i3c_response_desc_t resp);
  if (exp_resp.data_length != int'(resp.data_length)) return RESP_LEN_OTHER;
  if (exp_resp.requested_length == exp_resp.data_length) return RESP_LEN_EXACT;
  if ((exp_resp.requested_length > 0) && (exp_resp.data_length == 0)) return RESP_LEN_ZERO;
  if ((exp_resp.data_length > 0) && (exp_resp.data_length < exp_resp.requested_length)) begin
    if (resp.err_status == HcAborted) return RESP_LEN_PARTIAL_ABORT;
    if (resp.err_status == Ovl) return RESP_LEN_PARTIAL_OVERFLOW;
    return RESP_LEN_SHORT;
  end
  return RESP_LEN_OTHER;
endfunction

// --------------------------------------------------------------------------
// Abort, reset recovery, and stall tracking
// --------------------------------------------------------------------------

function abort_byte_boundary_e i3c_scoreboard::classify_abort_byte_boundary(int unsigned byte_count);
  if (byte_count == 0) return ABORT_BYTES_ZERO;
  if (byte_count <= 3) return ABORT_BYTES_ONE_TO_THREE;
  if (byte_count == 4) return ABORT_BYTES_ONE_DWORD;
  return ABORT_BYTES_MORE_THAN_ONE_DWORD;
endfunction

function void i3c_scoreboard::publish_abort_observation(abort_cause_e cause, abort_point_e point,
                                        int unsigned byte_count);
  i3c_correlated_item correlated_item;

  correlated_item = i3c_correlated_item::type_id::create("abort_observation_item");
  correlated_item.abort_valid = 1'b1;
  correlated_item.abort_cause = cause;
  correlated_item.abort_point = point;
  correlated_item.abort_byte_boundary = classify_abort_byte_boundary(byte_count);
  correlated_ap.write(correlated_item);
endfunction

function void i3c_scoreboard::prepare_abort_response(abort_cause_e cause, abort_point_e point,
                                     int unsigned byte_count);
  // Transaction-category publishers emit correlated abort coverage after the
  // checker has finalized all bus observations. This function only preserves
  // metadata for the later response and recovery checks.
  pending_abort_response_valid = 1'b1;
  pending_abort_cause = cause;
  pending_abort_point = point;
  pending_abort_byte_boundary = classify_abort_byte_boundary(byte_count);
endfunction

function void i3c_scoreboard::start_recovery_context(recovery_source_e source, i3c_resp_cmd_class_e cmd_class,
                                     reset_point_e reset_point);
  recovery_pending = (source == RECOVERY_RESET) || (cmd_class != RESP_CMD_CLASS_OTHER);
  recovery_source = source;
  recovery_reset_point = reset_point;
  interrupted_command_class = cmd_class;
endfunction

function void i3c_scoreboard::start_stall_recovery(stall_type_e stall_type, i3c_resp_cmd_class_e cmd_class);
  stall_recovery_pending = cmd_class != RESP_CMD_CLASS_OTHER;
  pending_stall_type = stall_type;
  pending_stall_cmd_class = cmd_class;
endfunction
