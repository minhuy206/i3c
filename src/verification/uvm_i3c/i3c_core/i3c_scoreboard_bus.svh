// -----------------------------------------------------------------------------
// i3c_scoreboard: Bus transaction checking
// -----------------------------------------------------------------------------

function void i3c_scoreboard::check_i3c_txn(i3c_item item);
  exp_txn_t               exp;
  bit                     txn_aborted;
  bit                     expected_rstart;
  bit                     expected_stop;
  i3c_resp_cmd_class_e    cmd_class;
  txn_cov_outcome_t       outcome;
  int                     errors_before;

  if (exp_txn_queue.size() == 0) begin
    exp = '{cmd_attr: RegularTransfer, default: '0};
    exp.target_is_i3c = item.i3c;
    exp.rnw = item.bus_op == BusOpRead;
    exp.data_length = item.num_data;
    exp.result_id = create_result('0, "UNEXPECTED BUS TRANSACTION", 1'b1);
    errors_before = scoreboard_error_count();
    `uvm_error(`gfn, $sformatf("Unexpected I3C txn: addr=0x%02h op=%s", item.addr,
                               item.bus_op.name()))
    mark_result_failed(exp.result_id, "No expected command for observed bus transaction");
    finish_bus_result(exp.result_id, item, errors_before);
    return;
  end

  exp = exp_txn_queue[0];
  if (!exp_matches_item(exp, item, 0)) begin
    int later_match_idx;

    later_match_idx = find_matching_exp_idx(item);
    errors_before = scoreboard_error_count();
    report_i3c_txn_mismatch(item, exp);
    if (later_match_idx > 0) begin
      for (int i = 0; i < later_match_idx; i++) begin
        exp_txn_t skipped;
        skipped = exp_txn_queue.pop_front();
        mark_result_failed(skipped.result_id,
                           "Command was skipped before a later bus transaction was observed");
        if (!skipped.rnw && skipped.uses_tx_queue)
          consume_tx_data_words(skipped.data_length);
      end
      exp = exp_txn_queue[0];
    end else begin
      mark_result_failed(exp.result_id, "Observed bus transaction did not match the next command");
      finish_bus_result(exp.result_id, item, errors_before);
      return;
    end
  end

  exp = exp_txn_queue.pop_front();
  active_result_id = exp.result_id;
  errors_before = scoreboard_error_count();
  txn_aborted = 1'b0;
  outcome = '{abort_valid: 1'b0, abort_cause: HC_ABORT, abort_point: PREAMBLE,
              resp_status: Success};
  sample_command_boundary_on_start(exp);

  if (exp.is_ccc) begin
    check_ccc_txn(item, exp);
    print_ccc_end(item, exp, 1'b0, 1'b1);
    advance_private_transfer(exp);
    record_command_history(exp, item);
    finish_bus_result(exp.result_id, item, errors_before);
    active_result_id = 0;
    return;
  end

  exp.start_with_broadcast_header =
      exp.broadcast_header_eligible && broadcast_header_enable && !pending_private_transfer;
  `DV_CHECK_EQ(item.addr, exp.addr, "Target address mismatch")
  `DV_CHECK_EQ(item.bus_op, exp.rnw ? BusOpRead : BusOpWrite, "Transfer direction mismatch")
  `DV_CHECK_EQ(item.start_with_broadcast_header, exp.start_with_broadcast_header,
               "Broadcast header preamble mismatch")
  if (item.start_with_broadcast_header || exp.start_with_broadcast_header) begin
    `DV_CHECK_EQ(item.broadcast_header_nack, 1'b0, "Broadcast header preamble was not ACKed")
  end
  print_i3c_address(item, exp);

  if (item.addr_nack) begin
    `DV_CHECK_EQ(item.num_data, 0, "Address NACK should not enter data phase")
    `DV_CHECK_EQ(item.data_q.size(), 0, "Address NACK should not collect data bytes")
    `DV_CHECK_EQ(item.data_nack_q.size(), 0, "Address NACK should not collect data T-bits")
    if (!exp.rnw && exp.uses_tx_queue && exp.data_length > 0) consume_tx_data_words(1);
    prepare_abort_response(PROTOCOL_TERMINATION, ADDRESS, 0);
    outcome.abort_valid = 1'b1;
    outcome.abort_cause = PROTOCOL_TERMINATION;
    outcome.abort_point = ADDRESS;
    outcome.resp_status = AddrHeader;
    cmd_class = classify_response_cmd(exp.cmd_attr, exp.is_ccc);
    record_exp_resp('{
        rnw:                     exp.rnw,
        tid:                     exp.tid,
        data_length:             0,
        resp_status:             AddrHeader,
        is_ccc:                  1'b0,
        ccc_opcode:              ENEC,
        ccc_direct:              1'b0,
        daa_dat_valid:           1'b0,
        daa_start_index:         '0,
        daa_requested_count:     '0,
        daa_response_valid:      1'b0,
        daa_result:              DAA_RESULT_OTHER,
        response_cmd_class:      cmd_class,
        requested_length:        exp.data_length,
        wroc:                    exp.wroc,
        address_response_valid:  1'b1,
        address_phase_broadcast: item.broadcast_header_nack,
        address_acked:           1'b0
    });
    start_recovery_context(RECOVERY_PROTOCOL_TERMINATION, cmd_class);
    if (exp.rnw) begin
      publish_read_coverage(item, exp, outcome);
    end else begin
      publish_write_coverage(item, exp, outcome);
    end
    advance_private_transfer(exp, 1'b1);
    print_i3c_end(item, exp, 1'b0, 1'b1);
    record_command_history(exp, item, 1'b1);
    `uvm_info(`gfn, $sformatf("AddrHeader RESP inferred: tid=0x%0h rnw=%0b requested_len=%0d",
                              exp.tid, exp.rnw, exp.data_length), UVM_MEDIUM)
    finish_bus_result(exp.result_id, item, errors_before);
    active_result_id = 0;
    return;
  end

  if (exp.rnw) begin
    check_read_txn(item, exp, expected_rstart, expected_stop, txn_aborted, outcome);
    publish_read_coverage(item, exp, outcome);
  end else if (exp.cmd_attr == ImmediateDataTransfer) begin
    txn_aborted = check_immediate_write_txn(item, exp, outcome);
    publish_write_coverage(item, exp, outcome);
    expected_rstart = txn_aborted ? 1'b0 : !exp.toc;
    expected_stop = txn_aborted ? 1'b1 : exp.toc;
  end else begin
    txn_aborted = check_write_txn(item, exp, outcome);
    publish_write_coverage(item, exp, outcome);
    expected_rstart = txn_aborted ? 1'b0 : !exp.toc;
    expected_stop = txn_aborted ? 1'b1 : exp.toc;
  end

  print_i3c_end(item, exp, expected_rstart, expected_stop);
  advance_private_transfer(exp, txn_aborted);
  record_command_history(exp, item, txn_aborted);
  finish_bus_result(exp.result_id, item, errors_before);
  active_result_id = 0;
endfunction

function bit i3c_scoreboard::exp_matches_item(exp_txn_t exp, i3c_item item, int word_offset);
  return (item.addr == exp.addr) &&
         (item.bus_op == (exp.rnw ? BusOpRead : BusOpWrite)) &&
         (exp.rnw || exp.is_ccc || !exp.uses_tx_queue || tx_data_matches_at(item, word_offset));
endfunction

function void i3c_scoreboard::report_i3c_txn_mismatch(i3c_item item, exp_txn_t exp);
  int later_match_idx;

  later_match_idx = find_matching_exp_idx(item);
  if (later_match_idx > 0) begin
    `uvm_error(
        `gfn,
        $sformatf(
            "I3C transaction mismatch: expected next command addr=0x%02h rnw=%0b len=%0d toc=%0b, observed addr=0x%02h op=%s len=%0d. A later expected command at index %0d matches; previous command was not observed.",
            exp.addr, exp.rnw, exp.data_length, exp.toc, item.addr, item.bus_op.name(),
            item.num_data, later_match_idx))
  end else begin
    `uvm_error(`gfn, $sformatf(
               "I3C transaction mismatch: expected next command addr=0x%02h rnw=%0b len=%0d toc=%0b, observed addr=0x%02h op=%s len=%0d",
               exp.addr,
               exp.rnw,
               exp.data_length,
               exp.toc,
               item.addr,
               item.bus_op.name(),
               item.num_data
               ))
  end
endfunction

function int i3c_scoreboard::find_matching_exp_idx(i3c_item item);
  int       word_offset;
  exp_txn_t exp;

  word_offset = 0;
  foreach (exp_txn_queue[i]) begin
    exp = exp_txn_queue[i];
    if (exp_matches_item(exp, item, word_offset)) begin
      return int'(i);
    end
    if (!exp.rnw && exp.uses_tx_queue) word_offset += tx_words_for_len(exp.data_length);
  end
  return -1;
endfunction

function void i3c_scoreboard::sample_command_boundary_on_start(exp_txn_t exp);
  i3c_resp_cmd_class_e next_class;

  next_class = classify_response_cmd(exp.cmd_attr, exp.is_ccc);
  if (reset_history_valid) begin
    publish_command_boundary(reset_history_class, next_class, BOUNDARY_RESET_CLEARED);
    reset_history_valid = 1'b0;
  end else if (command_history_valid) begin
    publish_command_boundary(previous_command_class, next_class, previous_command_boundary);
  end
endfunction

function void i3c_scoreboard::record_command_history(exp_txn_t exp, i3c_item item, bit txn_aborted);
  previous_command_class = classify_response_cmd(exp.cmd_attr, exp.is_ccc);
  command_history_valid  = previous_command_class != RESP_CMD_CLASS_OTHER;

  if (!txn_aborted && !exp.toc && item.rstart) begin
    previous_command_boundary = BOUNDARY_TOC_CONTINUATION;
    start_stall_recovery(STALL_WAIT_CMD, previous_command_class);
  end else if (item.rstart) begin
    previous_command_boundary = BOUNDARY_REPEATED_START;
  end else if (item.stop) begin
    // Distinguish a queued back-to-back STOP from a completed command that
    // returns to idle before software supplies the next descriptor.
    previous_command_boundary = (exp_txn_queue.size() > 0) ? BOUNDARY_STOP :
                                BOUNDARY_IDLE_BACK_TO_BACK;
  end else begin
    previous_command_boundary = BOUNDARY_IDLE_BACK_TO_BACK;
  end
endfunction

function void i3c_scoreboard::advance_private_transfer(exp_txn_t exp, bit aborted);
  if (exp.updates_private_transfer && !exp.is_ccc && !aborted) begin
    pending_private_transfer = !exp.toc;
  end else begin
    pending_private_transfer = 1'b0;
  end
endfunction

// --------------------------------------------------------------------------
// Private-transfer read checking
// --------------------------------------------------------------------------

function void i3c_scoreboard::check_read_txn(i3c_item item, exp_txn_t exp, output bit expected_rstart,
                             output bit expected_stop, output bit txn_aborted,
                             output txn_cov_outcome_t outcome);
  int                      read_id;
  i3c_resp_err_e           resp_status;
  i3c_resp_cmd_class_e     cmd_class;
  bit                      ack_or_t_bit_matches;
  string                   ack_or_t_bit_name;

  read_id = next_read_id++;
  resp_status = Success;
  txn_aborted = 1'b0;
  cmd_class = classify_response_cmd(exp.cmd_attr, exp.is_ccc);
  outcome = '{abort_valid: 1'b0, abort_cause: HC_ABORT, abort_point: PREAMBLE,
              resp_status: Success};

  `DV_CHECK_EQ(item.addr, exp.addr, "Read target address mismatch")
  `DV_CHECK_EQ(item.bus_op, BusOpRead, "Read transfer direction mismatch")
  `DV_CHECK_LE(item.num_data, exp.data_length, "Read bus data byte count exceeds command length")
  `DV_CHECK_EQ(item.data_q.size(), item.num_data, "Read monitor data queue size mismatch")
  `DV_CHECK_EQ(item.data_nack_q.size(), item.num_data, $sformatf(
               "Read monitor %s count mismatch", rx_ack_or_t_bit_label(exp.target_is_i3c)))

  check_read_ack_or_t_bits(item, exp);

  if (enqueue_rx_word_expectations(item, exp, read_id)) resp_status = Ovl;
  handle_read_end(item, exp, resp_status, expected_rstart, expected_stop, txn_aborted);
  if ((resp_status == Success) && !exp.toc && item.stop && !txn_aborted) begin
    resp_status = NotSupported;
  end
  if (resp_status == HcAborted) begin
    prepare_abort_response(HC_ABORT, RX_DATA, item.num_data);
    outcome.abort_valid = 1'b1;
    outcome.abort_cause = HC_ABORT;
    outcome.abort_point = RX_DATA;
  end else if (txn_aborted || (resp_status == NotSupported)) begin
    prepare_abort_response(PROTOCOL_TERMINATION, RX_DATA, item.num_data);
    outcome.abort_valid = 1'b1;
    outcome.abort_cause = PROTOCOL_TERMINATION;
    outcome.abort_point = RX_DATA;
  end
  outcome.resp_status = resp_status;
  record_exp_resp('{
      rnw:                     1'b1,
      tid:                     exp.tid,
      data_length:             item.num_data,
      resp_status:             resp_status,
      is_ccc:                  1'b0,
      ccc_opcode:              ENEC,
      ccc_direct:              1'b0,
      daa_dat_valid:           1'b0,
      daa_start_index:         '0,
      daa_requested_count:     '0,
      daa_response_valid:      1'b0,
      daa_result:              DAA_RESULT_OTHER,
      response_cmd_class:      cmd_class,
      requested_length:        exp.data_length,
      wroc:                    exp.wroc,
      address_response_valid:  1'b1,
      address_phase_broadcast: 1'b0,
      address_acked:           1'b1
  });
  if (resp_status == HcAborted) begin
    start_recovery_context(RECOVERY_HC_ABORT, cmd_class);
  end else if (txn_aborted || (resp_status == NotSupported)) begin
    start_recovery_context(RECOVERY_PROTOCOL_TERMINATION, cmd_class);
  end
  if (resp_status == Ovl) begin
    start_stall_recovery(STALL_RX_FULL, cmd_class);
  end
  `uvm_info(`gfn, $sformatf(
            "RX DATA: tid=0x%0h expected_len=%0d observed_len=%0d bus_data=%s",
            exp.tid,
            exp.data_length,
            item.num_data,
            format_observed_bytes(
                item.data_q, item.num_data
            )
            ), UVM_HIGH)
  ack_or_t_bit_matches = item.data_nack_q.size() == item.num_data;
  if (exp.target_is_i3c) ack_or_t_bit_name = "T-BIT";
  else                   ack_or_t_bit_name = "ACK/NACK";
  for (int i = 0; i < item.num_data; i++) begin
    if ((i >= item.data_nack_q.size()) ||
        (item.data_nack_q[i] != expected_rx_ack_or_t_bit(exp.target_is_i3c, item, i)))
      ack_or_t_bit_matches = 1'b0;
  end
  `uvm_info("I3C_SCB", $sformatf(
            "[TXN %04d][RX %s %s] expected_length=%0d observed_length=%0d\n  EXPECTED: %s\n  OBSERVED: %s",
            exp.result_id, ack_or_t_bit_name,
            ack_or_t_bit_matches ? "PASS" : "FAIL", item.num_data,
            item.data_nack_q.size(), format_expected_rx_ack_or_t_bits(item, exp),
            format_observed_ack_or_t_bits(exp.target_is_i3c, item.data_nack_q,
                                          item.num_data)), UVM_LOW)
endfunction

function void i3c_scoreboard::check_read_ack_or_t_bits(i3c_item item, exp_txn_t exp);
  if (!exp.target_is_i3c) begin
    check_i2c_read_ack_sequence(item);
    return;
  end

  for (int i = 0; i < item.num_data; i++) begin
    if (i < item.data_nack_q.size()) begin
      bit exp_bit;

      exp_bit = expected_rx_ack_or_t_bit(exp.target_is_i3c, item, i);
      `DV_CHECK_EQ(item.data_nack_q[i], exp_bit, $sformatf("Read bus %s[%0d] mismatch",
                                                           rx_ack_or_t_bit_label(
                                                           exp.target_is_i3c), i))
    end
  end
endfunction

function void i3c_scoreboard::check_i2c_read_ack_sequence(i3c_item item);
  for (int i = 0; i < item.num_data; i++) begin
    if (i < item.data_nack_q.size()) begin
      if (i == (item.num_data - 1)) begin
        `DV_CHECK_EQ(item.data_nack_q[i], SampledNack,
                     "I2C read Controller must NACK the final data byte")
      end else begin
        `DV_CHECK_EQ(item.data_nack_q[i], SampledAck, $sformatf(
                     "I2C read Controller NACK before final data byte at index %0d", i))
      end
    end
  end
endfunction

function void i3c_scoreboard::handle_read_end(i3c_item item, exp_txn_t exp, ref i3c_resp_err_e resp_status,
                              output bit expected_rstart, output bit expected_stop,
                              output bit txn_aborted);
  bit short_read;

  expected_rstart = 1'b0;
  expected_stop = 1'b0;
  txn_aborted = 1'b0;
  short_read = (item.num_data > 0) && (item.num_data < exp.data_length) &&
      is_read_terminated_by_final_bit(exp.target_is_i3c, item);

  if (hc_abort_active && item.stop) begin
    if (resp_status == Success) resp_status = HcAborted;
    expected_stop   = 1'b1;
    expected_rstart = is_read_takeover_bit(exp.target_is_i3c, item);
    `DV_CHECK_EQ(item.stop, 1'b1, "HC-aborted read should end with STOP")
    `DV_CHECK_EQ(item.rstart, expected_rstart,
                 "HC-aborted read rstart should match final T-Bit takeover")
    txn_aborted = 1'b1;
  end else if (short_read) begin
    if ((resp_status == Success) && exp.sre) resp_status = I3cShortReadErr;
    `DV_CHECK_EQ(item.stop, 1'b1, "Short read should end with STOP")
    expected_stop = 1'b1;
    txn_aborted   = 1'b1;
  end else if (is_read_takeover_bit(exp.target_is_i3c, item)) begin
    `DV_CHECK_EQ(item.rstart, 1'b1, "Controller read takeover should generate RSTART")
    `DV_CHECK_EQ(item.interrupted, 1'b1, "Controller read takeover should be marked interrupted")
    expected_rstart = 1'b1;
    if (resp_status == Ovl) begin
      `DV_CHECK_EQ(item.stop, 1'b1,
                   "Overflow read takeover should end with STOP regardless of toc")
      expected_stop = 1'b1;
    end else begin
      `DV_CHECK_EQ(item.stop, exp.toc, "Read takeover STOP should follow command toc")
      expected_stop = exp.toc;
    end
  end else if (exp.toc) begin
    `DV_CHECK_EQ(item.stop, 1'b1, "Read with toc=1 should end with STOP")
    expected_stop = 1'b1;
  end else if (resp_status == Ovl) begin
    `DV_CHECK_EQ(item.stop, 1'b1, "Overflow read (toc=0) should end with STOP, not continuation")
    expected_stop   = 1'b1;
    expected_rstart = item.rstart;
  end else begin
    `DV_CHECK_EQ(item.rstart, 1'b1, "Read with toc=0 should end with RSTART")
    expected_rstart = 1'b1;
  end
endfunction

function bit i3c_scoreboard::read_final_t_bit(i3c_item item);
  if (item.data_nack_q.size() == 0) return 1'b0;
  return item.data_nack_q[item.data_nack_q.size()-1];
endfunction

// True when the final data bit indicates the read terminated (early or by host).
// I3C: T-bit=0 = target-ended. I2C: data_nack_q[last]=1 = host NACK.
function bit i3c_scoreboard::is_read_terminated_by_final_bit(bit target_is_i3c, i3c_item item);
  return target_is_i3c ? !read_final_t_bit(item) : read_final_t_bit(item);
endfunction

// True when the I3C T-bit indicates the controller takes over (T-bit=1).
// Always false for I2C (there is no takeover T-bit concept in I2C).
function bit i3c_scoreboard::is_read_takeover_bit(bit target_is_i3c, i3c_item item);
  return target_is_i3c && read_final_t_bit(item);
endfunction

// I2C non-final: 0 (ACK), final: 1 (host NACK). I3C: 1 (continue) or T-bit on last byte.
function bit i3c_scoreboard::expected_rx_ack_or_t_bit(bit target_is_i3c, i3c_item item, int byte_idx);
  if (!target_is_i3c) return (byte_idx == (item.num_data - 1)) ? 1'b1 : 1'b0;
  if (byte_idx != (item.num_data - 1)) return 1'b1;
  return read_final_t_bit(item);
endfunction

function string i3c_scoreboard::rx_ack_or_t_bit_label(bit target_is_i3c);
  return target_is_i3c ? "T-bit" : "ACK/NACK";
endfunction

function bit i3c_scoreboard::enqueue_rx_word_expectations(i3c_item item, exp_txn_t exp, int read_id);
  bit rx_overflow;

  rx_overflow = 1'b0;
  for (int unsigned word_idx = 0; word_idx < ((item.num_data + 3) / 4); word_idx++) begin
    exp_rx_data_t rx_exp;

    build_rx_data_expectation(item, exp, read_id, word_idx, rx_exp);
    if (!rx_overflow && (exp_rx_data_queue.size() < RxFifoDepth)) begin
      exp_rx_data_queue.push_back(rx_exp);
      mark_rx_expected(exp.result_id);
    end else begin
      if (!rx_overflow) begin
        `uvm_info(
            `gfn,
            $sformatf(
                "RX FIFO overflow inferred: tid=0x%0h observed_len=%0d first_dropped_word=%0d",
                exp.tid, item.num_data, word_idx), UVM_MEDIUM)
      end
      rx_overflow = 1'b1;
    end
  end
  if (!rx_overflow && (exp.cmd_attr == RegularTransfer) && (item.num_data > 0)) begin
    read_integrity_pass[read_id] = 1'b1;
  end else begin
    read_integrity_pass.delete(read_id);
  end
  return rx_overflow;
endfunction

function void i3c_scoreboard::build_rx_data_expectation(i3c_item item, exp_txn_t exp, int read_id,
                                        int unsigned word_idx, output exp_rx_data_t rx_exp);
  rx_exp.known = 1'b1;
  rx_exp.result_id = exp.result_id;
  rx_exp.read_id = read_id;
  rx_exp.tid = exp.tid;
  rx_exp.data_length = item.num_data;
  rx_exp.word_idx = int'(word_idx);
  rx_exp.data = '0;
  rx_exp.integrity_candidate = (exp.cmd_attr == RegularTransfer) && (item.num_data > 0);
  rx_exp.integrity_protocol = exp.target_is_i3c;

  for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++) begin
    int unsigned data_idx;

    data_idx = (word_idx * 4) + byte_idx;
    if ((data_idx < item.num_data) && (data_idx < item.data_q.size())) begin
      rx_exp.data[(byte_idx*8)+:8] = item.data_q[data_idx];
    end
  end
endfunction

// --------------------------------------------------------------------------
// Private-transfer write checking and TX FIFO model
// --------------------------------------------------------------------------

function bit i3c_scoreboard::check_write_txn(i3c_item item, exp_txn_t exp,
                                             output txn_cov_outcome_t outcome);
  bit                      inferred_tx_underflow;
  bit                      inferred_hc_abort;
  bit                      inferred_data_nack;
  i3c_resp_err_e           resp_status;
  i3c_resp_cmd_class_e     cmd_class;

  inferred_tx_underflow = 1'b0;
  inferred_hc_abort     = 1'b0;
  inferred_data_nack    = 1'b0;
  cmd_class = classify_response_cmd(exp.cmd_attr, exp.is_ccc);
  outcome = '{abort_valid: 1'b0, abort_cause: HC_ABORT, abort_point: PREAMBLE,
              resp_status: Success};

  if (exp.uses_tx_queue) begin
    if (item.num_data < exp.data_length) begin
      inferred_data_nack = !exp.target_is_i3c && data_nack_q_has_nack(item);
      inferred_tx_underflow = !inferred_data_nack && (tx_fifo_available_bytes() < exp.data_length);
      inferred_hc_abort = !inferred_data_nack && hc_abort_active && !inferred_tx_underflow;
      if (!inferred_data_nack && !inferred_tx_underflow && !inferred_hc_abort)
        `uvm_error(`gfn, $sformatf(
                   "Short write observed while scoreboard TX FIFO model had enough data: observed=%0d requested=%0d available=%0d",
                   item.num_data,
                   exp.data_length,
                   tx_fifo_available_bytes()
                   ))
      check_short_write_tx_data(
          item, exp,
          inferred_data_nack ? "I2C data NACK" : inferred_hc_abort ? "HC abort" : "Underflow",
          inferred_data_nack);
    end else if (item.num_data == exp.data_length) begin
      inferred_data_nack = !exp.target_is_i3c && data_nack_q_has_nack(item);
      inferred_hc_abort  = !inferred_data_nack && hc_abort_active;
      check_tx_data_bytes(item, exp, exp.data_length, "TX", inferred_data_nack);
      if ((exp.cmd_attr == RegularTransfer) && (exp.data_length > 0) && write_payload_matches(
              item, exp.data_length
          )) begin
        publish_integrity_coverage(1'b0, exp.target_is_i3c);
      end
      consume_tx_data_words(exp.data_length);
    end else begin
      `uvm_error(`gfn, $sformatf(
                 "Write bus data length exceeds command length: observed=%0d requested=%0d",
                 item.num_data,
                 exp.data_length
                 ))
    end
    resp_status = inferred_data_nack    ? I2cDataNackOrI3cBusAborted :
                  inferred_tx_underflow ? Ovl :
                  inferred_hc_abort     ? HcAborted : Success;
    if (inferred_hc_abort) begin
      prepare_abort_response(HC_ABORT, TX_DATA, item.num_data);
      outcome.abort_valid = 1'b1;
      outcome.abort_cause = HC_ABORT;
      outcome.abort_point = TX_DATA;
    end else if (inferred_data_nack) begin
      prepare_abort_response(PROTOCOL_TERMINATION, TX_DATA, item.num_data);
      outcome.abort_valid = 1'b1;
      outcome.abort_cause = PROTOCOL_TERMINATION;
      outcome.abort_point = TX_DATA;
    end
    outcome.resp_status = resp_status;
    record_exp_resp('{
        rnw:                     1'b0,
        tid:                     exp.tid,
        data_length:             item.num_data,
        resp_status:             resp_status,
        is_ccc:                  1'b0,
        ccc_opcode:              ENEC,
        ccc_direct:              1'b0,
        daa_dat_valid:           1'b0,
        daa_start_index:         '0,
        daa_requested_count:     '0,
        daa_response_valid:      1'b0,
        daa_result:              DAA_RESULT_OTHER,
        response_cmd_class:      cmd_class,
        requested_length:        exp.data_length,
        wroc:                    exp.wroc,
        address_response_valid:  1'b1,
        address_phase_broadcast: 1'b0,
        address_acked:           1'b1
    });
    if (inferred_hc_abort) begin
      start_recovery_context(RECOVERY_HC_ABORT, cmd_class);
    end else if (inferred_data_nack) begin
      start_recovery_context(RECOVERY_PROTOCOL_TERMINATION, cmd_class);
    end
    if (inferred_tx_underflow) begin
      start_stall_recovery(STALL_TX_EMPTY, cmd_class);
    end
  end

  return inferred_tx_underflow || inferred_hc_abort || inferred_data_nack;
endfunction

function bit i3c_scoreboard::check_immediate_write_txn(i3c_item item, exp_txn_t exp,
                                                       output txn_cov_outcome_t outcome);
  bit                      inferred_hc_abort;
  bit                      inferred_data_nack;
  bit                      data_matches;
  bit                      ack_or_t_bit_matches;
  string                   ack_or_t_bit_name;
  i3c_resp_err_e           resp_status;
  i3c_resp_cmd_class_e     cmd_class;

  inferred_hc_abort  = 1'b0;
  inferred_data_nack = 1'b0;
  data_matches = (item.num_data == exp.data_length) &&
                 (item.data_q.size() == exp.data_length);
  cmd_class = classify_response_cmd(exp.cmd_attr, exp.is_ccc);
  outcome = '{abort_valid: 1'b0, abort_cause: HC_ABORT, abort_point: PREAMBLE,
              resp_status: Success};

  if (item.num_data < exp.data_length) begin
    inferred_data_nack = !exp.target_is_i3c && data_nack_q_has_nack(item);
    inferred_hc_abort  = !inferred_data_nack && hc_abort_active;
    if (!inferred_data_nack && !inferred_hc_abort)
      `uvm_error(`gfn, $sformatf(
                 "Immediate short write: observed=%0d requested=%0d with no HC abort (tid=0x%0h)",
                 item.num_data,
                 exp.data_length,
                 exp.tid
                 ))
  end else if (item.num_data == exp.data_length) begin
    inferred_data_nack = !exp.target_is_i3c && data_nack_q_has_nack(item);
    inferred_hc_abort  = !inferred_data_nack && hc_abort_active;
  end else begin
    `uvm_error(`gfn, $sformatf(
               "Immediate write byte count exceeds dtt: observed=%0d requested=%0d (tid=0x%0h)",
               item.num_data,
               exp.data_length,
               exp.tid
               ))
  end

  for (int i = 0; i < item.num_data; i++) begin
    if (i < item.data_q.size()) begin
      if (item.data_q[i] != exp.imm_data_byte[i]) data_matches = 1'b0;
      `DV_CHECK_EQ(item.data_q[i], exp.imm_data_byte[i], $sformatf(
                   "Immediate inline byte[%0d] mismatch (tid=0x%0h)", i, exp.tid))
    end
    if (exp.target_is_i3c && (i < item.data_nack_q.size()))
      `DV_CHECK_EQ(item.data_nack_q[i], ~^exp.imm_data_byte[i], $sformatf(
                   "Immediate T-bit[%0d] mismatch (tid=0x%0h)", i, exp.tid))
  end

  if (!exp.toc) begin
    resp_status = NotSupported;
  end else begin
    resp_status = inferred_data_nack ? I2cDataNackOrI3cBusAborted :
                  inferred_hc_abort  ? HcAborted : Success;
  end
  if (inferred_hc_abort) begin
    prepare_abort_response(HC_ABORT, TX_DATA, item.num_data);
    outcome.abort_valid = 1'b1;
    outcome.abort_cause = HC_ABORT;
    outcome.abort_point = TX_DATA;
  end else if (inferred_data_nack) begin
    prepare_abort_response(PROTOCOL_TERMINATION, TX_DATA, item.num_data);
    outcome.abort_valid = 1'b1;
    outcome.abort_cause = PROTOCOL_TERMINATION;
    outcome.abort_point = TX_DATA;
  end else if (!exp.toc) begin
    prepare_abort_response(PROTOCOL_TERMINATION, RESPONSE, item.num_data);
    outcome.abort_valid = 1'b1;
    outcome.abort_cause = PROTOCOL_TERMINATION;
    outcome.abort_point = RESPONSE;
  end
  outcome.resp_status = resp_status;
  record_exp_resp('{
      rnw:                     1'b0,
      tid:                     exp.tid,
      data_length:             item.num_data,
      resp_status:             resp_status,
      is_ccc:                  1'b0,
      ccc_opcode:              ENEC,
      ccc_direct:              1'b0,
      daa_dat_valid:           1'b0,
      daa_start_index:         '0,
      daa_requested_count:     '0,
      daa_response_valid:      1'b0,
      daa_result:              DAA_RESULT_OTHER,
      response_cmd_class:      cmd_class,
      requested_length:        exp.data_length,
      wroc:                    exp.wroc,
      address_response_valid:  1'b1,
      address_phase_broadcast: 1'b0,
      address_acked:           1'b1
  });
  if (inferred_hc_abort) begin
    start_recovery_context(RECOVERY_HC_ABORT, cmd_class);
  end else if (inferred_data_nack || !exp.toc) begin
    start_recovery_context(RECOVERY_PROTOCOL_TERMINATION, cmd_class);
  end

  ack_or_t_bit_matches = item.data_nack_q.size() == exp.data_length;
  if (exp.target_is_i3c) ack_or_t_bit_name = "T-BIT";
  else                   ack_or_t_bit_name = "ACK";
  for (int i = 0; i < exp.data_length; i++) begin
    if ((i >= item.data_nack_q.size()) ||
        (item.data_nack_q[i] != expected_tx_ack_or_t_bit(
            exp.target_is_i3c, exp.imm_data_byte[i],
            inferred_data_nack && !exp.target_is_i3c && (i == (exp.data_length - 1)))))
      ack_or_t_bit_matches = 1'b0;
  end
  if ((exp.data_length > 0) || (item.num_data > 0))
    `uvm_info("I3C_SCB", $sformatf(
              "[TXN %04d][IMM DATA %s] expected_length=%0d observed_length=%0d\n  EXPECTED: %s\n  OBSERVED: %s",
              exp.result_id, data_matches ? "PASS" : "FAIL", exp.data_length, item.num_data,
              format_expected_imm_bytes(exp, exp.data_length),
              format_observed_bytes(item.data_q, item.num_data)), UVM_LOW)
  `uvm_info("I3C_SCB", $sformatf(
            "[TXN %04d][IMM %s %s] expected_length=%0d observed_length=%0d\n  EXPECTED: %s\n  OBSERVED: %s",
            exp.result_id, ack_or_t_bit_name,
            ack_or_t_bit_matches ? "PASS" : "FAIL", exp.data_length,
            item.data_nack_q.size(),
            format_expected_imm_t_bits(exp, exp.data_length, inferred_data_nack),
            format_observed_ack_or_t_bits(exp.target_is_i3c, item.data_nack_q,
                                          item.num_data)), UVM_LOW)
  if (!exp.toc)
    `uvm_info(`gfn, $sformatf(
              "IMM toc=0 REJECT: tid=0x%0h dtt=%0d - data phase completed, STOP + NotSupported",
              exp.tid,
              exp.data_length
              ), UVM_MEDIUM)

  return inferred_hc_abort || inferred_data_nack || !exp.toc;
endfunction

function void i3c_scoreboard::check_tx_data_bytes(i3c_item item, exp_txn_t exp, int data_length, string ctxt,
                                  bit allow_i2c_final_data_nack);
  bit data_matches;
  bit ack_or_t_bit_matches;
  string ack_or_t_bit_name;

  data_matches = (item.num_data == data_length) &&
                 (item.data_q.size() == data_length) &&
                 (data_length <= tx_fifo_available_bytes());
  `DV_CHECK_EQ(item.num_data, data_length, $sformatf(
               "%s write byte count on bus does not match expected length", ctxt))
  `DV_CHECK_EQ(item.data_q.size(), data_length, $sformatf(
               "%s write monitor captured the wrong number of data bytes", ctxt))
  `DV_CHECK_EQ(item.data_nack_q.size(), data_length, $sformatf(
               "%s write monitor captured the wrong number of %ss",
               ctxt,
               tx_ack_or_t_bit_label(
                   exp.target_is_i3c
               )
               ))
  `DV_CHECK_LE(data_length, tx_fifo_available_bytes(), $sformatf(
               "%s write needs more bytes than the scoreboard TX FIFO model has", ctxt))
  foreach (item.data_q[i]) begin
    int word_idx = i / 4;
    int byte_off = (i % 4) * 8;
    if (word_idx < tx_data_queue.size()) begin
      bit [7:0] exp_byte = tx_data_queue[word_idx][byte_off+:8];
      if (item.data_q[i] != exp_byte) data_matches = 1'b0;
      `DV_CHECK_EQ(item.data_q[i], exp_byte, $sformatf("%s data mismatch at byte[%0d]", ctxt, i))
      if (i < item.data_nack_q.size()) begin
        bit i2c_data_nack_byte;

        i2c_data_nack_byte = allow_i2c_final_data_nack && !exp.target_is_i3c &&
                             (i == (data_length - 1));
        `DV_CHECK_EQ(item.data_nack_q[i], expected_tx_ack_or_t_bit(exp.target_is_i3c, exp_byte,
                                                                   i2c_data_nack_byte),
                     $sformatf("%s %s mismatch at byte[%0d]", ctxt, tx_ack_or_t_bit_label(
                               exp.target_is_i3c), i))
      end
    end
  end
  ack_or_t_bit_matches = item.data_nack_q.size() == data_length;
  if (exp.target_is_i3c) ack_or_t_bit_name = "T-BIT";
  else                   ack_or_t_bit_name = "ACK";
  for (int i = 0; i < data_length; i++) begin
    bit [7:0] expected_byte;
    bit       expected_bit;

    if ((i / 4) >= tx_data_queue.size()) begin
      ack_or_t_bit_matches = 1'b0;
    end else begin
      expected_byte = tx_data_queue[i / 4][(i % 4) * 8+:8];
      expected_bit = expected_tx_ack_or_t_bit(
          exp.target_is_i3c, expected_byte,
          allow_i2c_final_data_nack && !exp.target_is_i3c && (i == (data_length - 1)));
      if ((i >= item.data_nack_q.size()) || (item.data_nack_q[i] != expected_bit))
        ack_or_t_bit_matches = 1'b0;
    end
  end
  if ((data_length > 0) || (item.num_data > 0))
    `uvm_info("I3C_SCB", $sformatf(
              "[TXN %04d][TX DATA %s] expected_length=%0d observed_length=%0d\n  EXPECTED: %s\n  OBSERVED: %s",
              exp.result_id, data_matches ? "PASS" : "FAIL", data_length, item.num_data,
              format_expected_tx_bytes(data_length),
              format_observed_bytes(item.data_q, item.num_data)), UVM_LOW)
  `uvm_info("I3C_SCB", $sformatf(
            "[TXN %04d][TX %s %s] expected_length=%0d observed_length=%0d\n  EXPECTED: %s\n  OBSERVED: %s",
            exp.result_id, ack_or_t_bit_name,
            ack_or_t_bit_matches ? "PASS" : "FAIL", data_length,
            item.data_nack_q.size(),
            format_expected_tx_ack_or_t_bits(data_length, exp.target_is_i3c,
                                             allow_i2c_final_data_nack),
            format_observed_ack_or_t_bits(exp.target_is_i3c, item.data_nack_q,
                                          data_length)), UVM_LOW)
endfunction

function void i3c_scoreboard::check_short_write_tx_data(i3c_item item, exp_txn_t exp, string cause,
                                        bit allow_i2c_final_data_nack);
  int actual_data_length;

  actual_data_length = item.num_data;
  check_tx_data_bytes(item, exp, actual_data_length, cause, allow_i2c_final_data_nack);
  `DV_CHECK_EQ(item.stop, 1'b1, $sformatf("%s: short write should terminate with STOP", cause))
  `DV_CHECK_EQ(item.rstart, 1'b0, $sformatf(
               "%s: short write should not terminate with RSTART", cause))
  consume_tx_data_words(actual_data_length);
  `uvm_info(`gfn, $sformatf(
            "%s inferred: tid=0x%0h observed_len=%0d requested_len=%0d",
            cause,
            exp.tid,
            actual_data_length,
            exp.data_length
            ), UVM_MEDIUM)
endfunction

function bit i3c_scoreboard::write_payload_matches(i3c_item item, int data_length);
  if ((item.num_data != data_length) || (item.data_q.size() != data_length) ||
      (data_length > tx_fifo_available_bytes()))
    return 1'b0;
  foreach (item.data_q[i]) begin
    int word_idx;
    int byte_off;

    word_idx = i / 4;
    byte_off = (i % 4) * 8;
    if ((word_idx >= tx_data_queue.size()) ||
        (item.data_q[i] != tx_data_queue[word_idx][byte_off+:8]))
      return 1'b0;
  end
  return 1'b1;
endfunction

function bit i3c_scoreboard::data_nack_q_has_nack(i3c_item item);
  for (int i = 0; i < item.data_nack_q.size(); i++) begin
    if (item.data_nack_q[i]) return 1'b1;
  end
  return 1'b0;
endfunction

function int i3c_scoreboard::tx_fifo_available_bytes();
  return tx_data_queue.size() * 4;
endfunction

function bit i3c_scoreboard::get_expected_tx_byte(int byte_idx, output bit [7:0] data_byte);
  int word_idx;
  int byte_off;

  word_idx  = byte_idx / 4;
  byte_off  = (byte_idx % 4) * 8;
  data_byte = '0;

  if (word_idx >= tx_data_queue.size()) return 1'b0;

  data_byte = tx_data_queue[word_idx][byte_off+:8];
  return 1'b1;
endfunction

function void i3c_scoreboard::collect_expected_tx_bytes(int data_length, output bit [7:0] bytes[$]);
  bytes.delete();
  for (int i = 0; i < data_length; i++) begin
    bit [7:0] data_byte;

    if (!get_expected_tx_byte(i, data_byte)) break;
    bytes.push_back(data_byte);
  end
endfunction

// I2C path: returns NACK-polarity (1=NACK, 0=ACK). i2c_data_nack_byte=1 means last byte NACKed.
function bit i3c_scoreboard::expected_tx_ack_or_t_bit(bit target_is_i3c, bit [7:0] data_byte,
                                      bit i2c_data_nack_byte);
  return target_is_i3c ? ~^data_byte : i2c_data_nack_byte;
endfunction

function string i3c_scoreboard::tx_ack_or_t_bit_label(bit target_is_i3c);
  return target_is_i3c ? "T-bit" : "ACK";
endfunction

function void i3c_scoreboard::collect_expected_tx_ack_or_t_bits(int data_length, bit target_is_i3c,
                                                output bit t_bits[$],
                                                input bit allow_i2c_final_data_nack);
  bit [7:0] bytes[$];

  t_bits.delete();
  collect_expected_tx_bytes(data_length, bytes);
  foreach (bytes[i]) begin
    bit i2c_data_nack_byte;

    i2c_data_nack_byte = allow_i2c_final_data_nack && !target_is_i3c && (i == (data_length - 1));
    t_bits.push_back(expected_tx_ack_or_t_bit(target_is_i3c, bytes[i], i2c_data_nack_byte));
  end
endfunction

function void i3c_scoreboard::consume_tx_data_words(int data_len);
  int words_used = (data_len + 3) / 4;
  repeat (words_used) begin
    if (tx_data_queue.size() > 0) void'(tx_data_queue.pop_front());
  end
endfunction

function bit i3c_scoreboard::tx_data_matches_at(i3c_item item, int word_offset);
  foreach (item.data_q[i]) begin
    int word_idx = word_offset + (i / 4);
    int byte_off = (i % 4) * 8;

    if (word_idx >= tx_data_queue.size()) return 1'b0;
    if (item.data_q[i] != tx_data_queue[word_idx][byte_off+:8]) return 1'b0;
  end
  return 1'b1;
endfunction

function int i3c_scoreboard::tx_words_for_len(int data_len);
  return (data_len + 3) / 4;
endfunction
