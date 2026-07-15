// -----------------------------------------------------------------------------
// i3c_scoreboard: CCC and ENTDAA checking
// -----------------------------------------------------------------------------

function void i3c_scoreboard::check_ccc_txn(i3c_item item, exp_txn_t exp);
  bit                   is_direct_ccc;
  bit                   is_entdaa;
  int                   direct_idx;
  i3c_item              direct_item;
  i3c_resp_err_status_e resp_status;
  int                   resp_len;
  bit                   daa_response_valid;
  i3c_daa_result_e      daa_result;
  i3c_resp_cmd_class_e  cmd_class;
  int unsigned          joined_count;
  txn_cov_outcome_t     outcome;

  is_direct_ccc      = exp.cmd_code[7];
  is_entdaa          = (i3c_ccc_e'(exp.cmd_code) == ENTDAA);
  direct_idx         = -1;
  resp_status        = Success;
  resp_len           = exp.data_length;
  daa_response_valid = 1'b0;
  daa_result         = DAA_RESULT_OTHER;
  cmd_class          = classify_response_cmd(exp.cmd_attr, exp.is_ccc);
  joined_count       = 0;
  outcome = '{abort_valid: 1'b0, abort_cause: HC_ABORT, abort_point: PREAMBLE,
              resp_status: Success};

  `DV_CHECK_EQ(item.addr, exp.addr, "CCC broadcast address mismatch")
  `DV_CHECK_EQ(item.bus_op, BusOpWrite, "CCC broadcast direction mismatch")

  if (check_ccc_bcast_header_nack(item, exp, cmd_class, outcome)) begin
    publish_ccc_coverage(exp, outcome, 0);
    return;
  end

  check_ccc_opcode(item, exp);

  if (is_direct_ccc) begin
    check_ccc_direct_phase(item, exp, resp_status, resp_len, direct_idx, direct_item);
  end else if (is_entdaa) begin
    check_ccc_entdaa(item, exp, resp_status, resp_len, daa_response_valid, daa_result,
                     joined_count);
  end else begin
    check_ccc_broadcast_payload(item, exp);
  end
  `DV_CHECK_EQ(item.stop, 1'b1, "CCC should end with STOP")

  if (!is_entdaa && hc_abort_active && item.stop) begin
    resp_status = HcAborted;
    if (is_direct_ccc && (direct_idx >= 0)) begin
      resp_len = direct_item.num_data;
    end else begin
      resp_len = item.num_data;
    end
  end

  // NACK (AddrHeader) wins over toc=0 (NotSupported); toc=0 without NACK is rejected by RTL.
  if (resp_status == Success && !exp.toc) begin
    resp_status = NotSupported;
  end
  if (resp_status == HcAborted) begin
    abort_point_e point;

    point = is_entdaa ?
            ((item.CCC_direct_q.size() > 0) &&
             (item.CCC_direct_q[item.CCC_direct_q.size()-1].num_data >= 9) ?
             DAA_ASSIGNED_ADDRESS : DAA_ID) : CCC;
    prepare_abort_response(HC_ABORT, point, resp_len);
    outcome.abort_valid = 1'b1;
    outcome.abort_cause = HC_ABORT;
    outcome.abort_point = point;
  end else if (is_entdaa && (resp_status == Nack)) begin
    prepare_abort_response(PROTOCOL_TERMINATION, DAA_ASSIGNED_ADDRESS, resp_len);
    outcome.abort_valid = 1'b1;
    outcome.abort_cause = PROTOCOL_TERMINATION;
    outcome.abort_point = DAA_ASSIGNED_ADDRESS;
  end else if (resp_status == NotSupported) begin
    prepare_abort_response(PROTOCOL_TERMINATION, RESPONSE, resp_len);
    outcome.abort_valid = 1'b1;
    outcome.abort_cause = PROTOCOL_TERMINATION;
    outcome.abort_point = RESPONSE;
  end
  outcome.resp_status = resp_status;
  record_exp_resp('{
      rnw:                     1'b0,
      tid:                     exp.tid,
      data_length:             resp_len,
      resp_status:             resp_status,
      is_ccc:                  1'b1,
      ccc_opcode:              i3c_ccc_e'(exp.cmd_code),
      ccc_direct:              exp.cmd_code[7],
      daa_dat_valid:           1'b0,
      daa_start_index:         '0,
      daa_requested_count:     '0,
      daa_response_valid:      daa_response_valid,
      daa_result:              daa_result,
      response_cmd_class:      cmd_class,
      requested_length:        exp.data_length,
      wroc:                    exp.wroc,
      address_response_valid:  !is_entdaa,
      address_phase_broadcast: !is_direct_ccc,
      address_acked:           is_direct_ccc ?
                               ((direct_idx >= 0) && !direct_item.addr_nack) : 1'b1
  });
  if (resp_status == HcAborted) begin
    start_recovery_context(RECOVERY_HC_ABORT, cmd_class);
  end else if ((is_entdaa && (resp_status == Nack)) || (resp_status == NotSupported)) begin
    start_recovery_context(RECOVERY_PROTOCOL_TERMINATION, cmd_class);
  end
  if (resp_status == Ovl) begin
    start_stall_recovery(STALL_RX_FULL, cmd_class);
  end

  if (is_entdaa) begin
    publish_entdaa_coverage(exp, joined_count, daa_result, outcome, resp_len);
  end else begin
    publish_ccc_coverage(exp, outcome, resp_len);
  end

  if (is_direct_ccc) begin
    if (direct_idx >= 0) begin
      log_ccc_direct_data(item, exp, direct_idx, direct_item, resp_status, resp_len);
    end
  end else if (is_entdaa) begin
    log_ccc_entdaa_data(item, exp, resp_status, resp_len);
  end else begin
    log_ccc_broadcast_data(item, exp, resp_status, resp_len);
  end
endfunction

function bit i3c_scoreboard::check_ccc_bcast_header_nack(
    i3c_item item, exp_txn_t exp, i3c_resp_cmd_class_e cmd_class,
    output txn_cov_outcome_t outcome);
  outcome = '{abort_valid: 1'b0, abort_cause: HC_ABORT, abort_point: PREAMBLE,
              resp_status: Success};
  if (!item.addr_nack) return 1'b0;

  `DV_CHECK_EQ(item.CCC_valid, 1'b0, "Broadcast header NACK should suppress CCC opcode")
  `DV_CHECK_EQ(item.num_data, 0, "Broadcast header NACK should not enter data phase")
  `DV_CHECK_EQ(item.CCC_direct_q.size(), 0, "Broadcast header NACK should have no direct phase")
  `DV_CHECK_EQ(item.stop, 1'b1, "NACKed CCC should end with STOP")
  prepare_abort_response(PROTOCOL_TERMINATION, PREAMBLE, 0);
  outcome.abort_valid = 1'b1;
  outcome.abort_cause = PROTOCOL_TERMINATION;
  outcome.abort_point = PREAMBLE;
  outcome.resp_status = AddrHeader;
  record_exp_resp('{
      rnw:                     1'b0,
      tid:                     exp.tid,
      data_length:             0,
      resp_status:             AddrHeader,
      is_ccc:                  1'b1,
      ccc_opcode:              i3c_ccc_e'(exp.cmd_code),
      ccc_direct:              exp.cmd_code[7],
      daa_dat_valid:           1'b0,
      daa_start_index:         '0,
      daa_requested_count:     '0,
      daa_response_valid:      1'b0,
      daa_result:              DAA_RESULT_OTHER,
      response_cmd_class:      cmd_class,
      requested_length:        exp.data_length,
      wroc:                    exp.wroc,
      address_response_valid:  1'b1,
      address_phase_broadcast: 1'b1,
      address_acked:           1'b0
  });
  start_recovery_context(RECOVERY_PROTOCOL_TERMINATION, cmd_class);
  `uvm_info(`gfn, $sformatf(
            "CCC DATA: tid=0x%0h expected_ccc=%s(0x%02h) observed_ccc=-- expected_bcast_addr=0x%02h observed_bcast_addr=0x%02h expected_bcast_ack=%s observed_bcast_ack=%s expected_payload_len=0 observed_payload_len=%0d expected_direct_phases=0 observed_direct_phases=%0d expected_resp_status=%s expected_resp_len=0",
            exp.tid,
            ccc_to_string(
                exp.cmd_code
            ),
            8'(exp.cmd_code),
            exp.addr,
            item.addr,
            ack_to_string(
                1'b0
            ),
            ack_to_string(
                !item.addr_nack
            ),
            item.num_data,
            item.CCC_direct_q.size(),
            resp_status_to_string(
                AddrHeader
            )
            ), UVM_LOW)
  return 1'b1;
endfunction

function void i3c_scoreboard::check_ccc_opcode(i3c_item item, exp_txn_t exp);
  `DV_CHECK_EQ(item.CCC_valid, 1'b1, "CCC opcode was not decoded")
  `DV_CHECK_EQ(item.CCC, i3c_ccc_e'(exp.cmd_code), "CCC opcode mismatch")
  `DV_CHECK_EQ(item.ccc_t_bit_valid, 1'b1, "CCC opcode T-bit was not captured")
  if (item.ccc_t_bit_valid) begin
    `DV_CHECK_EQ(item.ccc_t_bit, ~^exp.cmd_code, "CCC opcode T-bit mismatch")
  end
  `uvm_info(`gfn, $sformatf(
            "CCC OPCODE: tid=0x%0h expected_ccc=%s(0x%02h) observed_ccc=%s(0x%02h) expected_t_bit=%0b observed_t_bit=%s",
            exp.tid,
            ccc_to_string(
                exp.cmd_code
            ),
            8'(exp.cmd_code),
            item.CCC.name(),
            8'(item.CCC),
            ~^exp.cmd_code,
            format_optional_bit(
                item.ccc_t_bit_valid, item.ccc_t_bit
            )
            ), UVM_LOW)
endfunction

function void i3c_scoreboard::check_ccc_direct_phase(i3c_item item, exp_txn_t exp,
                                     ref i3c_resp_err_status_e resp_status, ref int resp_len,
                                     output int direct_idx, output i3c_item direct_item);
  direct_idx = -1;

  `DV_CHECK_EQ(item.num_data, 0, "Direct CCC broadcast leg should not carry event bytes")
  foreach (item.CCC_direct_q[i]) begin
    if ((direct_idx < 0) && (item.CCC_direct_q[i].addr == exp.ccc_target_addr)) begin
      direct_idx = int'(i);
    end
  end
  if (direct_idx < 0) begin
    `uvm_error(`gfn, "Direct CCC target phase missing")
  end else begin
    direct_item = item.CCC_direct_q[direct_idx];
    `DV_CHECK_EQ(direct_item.start_from_rstart, 1'b1,
                 "Direct CCC target phase should start after RSTART")
    `DV_CHECK_EQ(direct_item.addr, exp.ccc_target_addr, "Direct CCC target address mismatch")
    `DV_CHECK_EQ(direct_item.bus_op, BusOpWrite, "Direct CCC target direction mismatch")
    if (direct_item.addr_nack) begin
      // RTL suppresses trailing data byte on target NACK and reports AddrHeader/len0.
      `DV_CHECK_EQ(direct_item.num_data, 0, "Direct target NACK should suppress data byte")
      `DV_CHECK_EQ(direct_item.stop, 1'b1, "Direct target NACK should end with STOP")
      resp_status = AddrHeader;
      resp_len    = 0;
    end else begin
      `DV_CHECK_EQ(direct_item.num_data, exp.data_length, "Direct CCC event byte count mismatch")
      if (direct_item.data_q.size() > 0) begin
        `DV_CHECK_EQ(direct_item.data_q[0], exp.event_byte, "Direct CCC event byte mismatch")
      end else begin
        `uvm_error(`gfn, "Direct CCC event byte missing")
      end
      if (direct_item.data_nack_q.size() > 0) begin
        `DV_CHECK_EQ(direct_item.data_nack_q[0], ~^exp.event_byte,
                     "Direct CCC event byte T-bit mismatch")
      end else begin
        `uvm_error(`gfn, "Direct CCC event byte T-bit missing")
      end
      `DV_CHECK_EQ(direct_item.stop, 1'b1, "Direct CCC target phase should end with STOP")
    end
  end
endfunction

function void i3c_scoreboard::check_ccc_broadcast_payload(i3c_item item, exp_txn_t exp);
  `DV_CHECK_EQ(item.num_data, exp.data_length, "CCC event byte count mismatch")
  if (item.data_q.size() > 0) begin
    `DV_CHECK_EQ(item.data_q[0], exp.event_byte, "CCC event byte mismatch")
  end else begin
    `uvm_error(`gfn, "CCC event byte missing")
  end
  if (item.data_nack_q.size() > 0) begin
    `DV_CHECK_EQ(item.data_nack_q[0], ~^exp.event_byte, "CCC event byte T-bit mismatch")
  end else begin
    `uvm_error(`gfn, "CCC event byte T-bit missing")
  end
  `DV_CHECK_EQ(item.CCC_direct_q.size(), 0, "Broadcast CCC should not include a direct phase")
endfunction

function void i3c_scoreboard::check_ccc_entdaa(i3c_item item, exp_txn_t exp,
                               ref i3c_resp_err_status_e resp_status, ref int resp_len,
                               ref bit daa_response_valid, ref i3c_daa_result_e daa_result,
                               output int unsigned joined_count);
  daa_scan_state_t st;

  // ENTDAA opening frame: broadcast leg carries only the opcode (no payload bytes).
  // CCC_direct_q holds each 7E+R DAA round: one per device slot + the terminating NACK round.
  `DV_CHECK_EQ(item.num_data, 0, "ENTDAA opening frame should carry no payload bytes")
  st.devices_joined_local = 0;
  st.terminating_nack_seen = 1'b0;
  st.address_rejected_once = 1'b0;
  st.address_reject_error = 1'b0;
  st.hc_abort_seen = 1'b0;
  st.rejected_pid = '0;
  st.rejected_bcr = '0;
  st.rejected_dcr = '0;
  st.rejected_addr = '0;
  if (exp.daa_addr_reserved[0]) begin
    `DV_CHECK_EQ(item.CCC_direct_q.size(), 0,
                 "ENTDAA with reserved first assigned address should not issue a DAA round")
  end else begin
    `DV_CHECK_GT(item.CCC_direct_q.size(), 0, "ENTDAA should have at least one 7E+R round")
  end
  `DV_CHECK_LE(item.CCC_direct_q.size(), exp.daa_dev_count + 1,
               "ENTDAA emitted more rounds than dev_count permits")
  foreach (item.CCC_direct_q[i]) begin
    check_ccc_entdaa_round(item, exp, int'(i), st, resp_status, resp_len);
  end
  `DV_CHECK_LE(st.devices_joined_local, exp.daa_dev_count,
               "ENTDAA joined-device count exceeds dev_count")
  if (hc_abort_active && item.stop) begin
    st.hc_abort_seen = 1'b1;
    resp_status      = HcAborted;
  end
  if ((st.devices_joined_local < exp.daa_dev_count) &&
      exp.daa_addr_reserved[st.devices_joined_local]) begin
    st.address_reject_error = 1'b1;
    resp_status             = NotSupported;
    resp_len                = st.devices_joined_local * 12;
  end
  if (st.devices_joined_local < exp.daa_dev_count) begin
    `DV_CHECK_EQ(st.terminating_nack_seen || st.address_reject_error || st.hc_abort_seen, 1'b1,
                 "ENTDAA stopped before dev_count without a terminating condition")
  end else begin
    `DV_CHECK_EQ(st.terminating_nack_seen, 1'b0,
                 "ENTDAA issued a no-device round after satisfying dev_count")
  end
  daa_result = resolve_daa_result(exp, st, resp_status);
  joined_count = st.devices_joined_local;
  daa_response_valid = 1'b1;
  // RTL reports the number of DAA result bytes actually committed into RX FIFO:
  // 3 RX dwords per joined device unless RX FIFO overflows first.
endfunction

function void i3c_scoreboard::check_ccc_entdaa_round(i3c_item item, exp_txn_t exp, int i, ref daa_scan_state_t st,
                                     ref i3c_resp_err_status_e resp_status, ref int resp_len);
  `DV_CHECK_EQ(item.CCC_direct_q[i].start_from_rstart, 1'b1,
               "ENTDAA DAA round should start after RSTART")
  `DV_CHECK_EQ(item.CCC_direct_q[i].addr, I3C_RSVD_ADDR,
               "ENTDAA DAA round address should be 0x7E")
  `DV_CHECK_EQ(item.CCC_direct_q[i].bus_op, BusOpRead, "ENTDAA DAA round should be a read")
  if (!item.CCC_direct_q[i].addr_nack) begin
    // A device joined this round.
    // Layout (monitor daa_data after the fix): data_q[0..7] = UID bytes (PID/BCR/DCR),
    //   data_q[8] = {addr[6:0], parity}, data_nack_q[0] = device accept/reject (0=ACK).
    // Parity convention: parity = ~^addr (odd-parity XNOR over the 7 address bits).
    bit [47:0] pid;
    bit [ 7:0] bcr;
    bit [ 7:0] dcr;
    bit [ 6:0] joined_addr;
    bit [31:0] rx_word0;
    bit [31:0] rx_word1;
    bit [31:0] rx_word2;
    bit        device_ack_present;
    bit        device_ack;
    if (item.CCC_direct_q[i].stop && item.CCC_direct_q[i].data_q.size() == 8 &&
        item.CCC_direct_q[i].data_nack_q.size() == 0) begin
      `DV_CHECK_EQ(hc_abort_active, 1'b1,
                   "ENTDAA ID-only round may terminate with STOP only for HC abort")
      `DV_CHECK_EQ(item.CCC_direct_q[i].num_data, 8,
                   "HC-aborted ENTDAA round should contain exactly 8 ID bytes")
      `DV_CHECK_EQ(i, item.CCC_direct_q.size() - 1,
                   "HC-aborted ENTDAA round must be the final round")
      `DV_CHECK_EQ(st.terminating_nack_seen, 1'b0,
                   "HC-aborted ENTDAA round observed after terminating no-device NACK")
      `DV_CHECK_EQ(st.address_reject_error, 1'b0,
                   "HC-aborted ENTDAA round observed after assigned-address failure")
      st.hc_abort_seen = 1'b1;
      resp_status = HcAborted;
      `uvm_info(`gfn,
                $sformatf(
                    "CCC ENTDAA ROUND[%0d]: tid=0x%0h HC abort after 8 ID bytes, observed_stop=1",
                    i, exp.tid), UVM_LOW)
      return;
    end
    `DV_CHECK_EQ(st.terminating_nack_seen, 1'b0,
                 "ENTDAA round observed after terminating no-device NACK")
    `DV_CHECK_EQ(st.address_reject_error, 1'b0,
                 "ENTDAA round observed after the second assigned-address NACK")
    `DV_CHECK_LT(st.devices_joined_local, exp.daa_dev_count,
                 "ENTDAA assigned more devices than requested")
    `DV_CHECK_EQ(item.CCC_direct_q[i].num_data, 9,
                 "ENTDAA joined round should carry 8 UID bytes + 1 address byte")
    `DV_CHECK_EQ(item.CCC_direct_q[i].data_q.size(), 9, "ENTDAA joined round data_q size mismatch")
    `DV_CHECK_EQ(item.CCC_direct_q[i].data_nack_q.size(), 1,
                 "ENTDAA joined round should have exactly one device-ACK entry")
    pid = {
      item.CCC_direct_q[i].data_q[0],
      item.CCC_direct_q[i].data_q[1],
      item.CCC_direct_q[i].data_q[2],
      item.CCC_direct_q[i].data_q[3],
      item.CCC_direct_q[i].data_q[4],
      item.CCC_direct_q[i].data_q[5]
    };
    bcr = item.CCC_direct_q[i].data_q[6];
    dcr = item.CCC_direct_q[i].data_q[7];
    joined_addr = item.CCC_direct_q[i].data_q[8][7:1];
    if (st.devices_joined_local < 16) begin
      `DV_CHECK_EQ(exp.daa_addr_valid[st.devices_joined_local], 1'b1,
                   $sformatf("ENTDAA DAT entry unavailable for device slot %0d",
                             st.devices_joined_local))
      if (exp.daa_addr_valid[st.devices_joined_local]) begin
        `DV_CHECK_EQ(joined_addr, exp.daa_assigned_addr[st.devices_joined_local],
                     $sformatf("ENTDAA assigned address mismatch at device slot %0d",
                               st.devices_joined_local))
      end
    end
    rx_word0 = {
      item.CCC_direct_q[i].data_q[0],
      item.CCC_direct_q[i].data_q[1],
      item.CCC_direct_q[i].data_q[2],
      item.CCC_direct_q[i].data_q[3]
    };
    rx_word1 = {
      item.CCC_direct_q[i].data_q[4],
      item.CCC_direct_q[i].data_q[5],
      item.CCC_direct_q[i].data_q[6],
      item.CCC_direct_q[i].data_q[7]
    };
    rx_word2 = {25'h0, joined_addr};
    `DV_CHECK_EQ(item.CCC_direct_q[i].data_q[8][0], ~^joined_addr,
                 "ENTDAA assigned-address parity mismatch")
    device_ack_present = item.CCC_direct_q[i].data_nack_q.size() > 0;
    device_ack = device_ack_present ? item.CCC_direct_q[i].data_nack_q[0] : 1'b0;
    `DV_CHECK_EQ(device_ack_present, 1'b1,
                 "ENTDAA joined round should include assigned-address ACK/NACK")
    if (device_ack_present && !device_ack) begin
      if (st.address_rejected_once) begin
        `DV_CHECK_EQ(pid, st.rejected_pid,
                     "ENTDAA retry should be won by the target that rejected the address")
        `DV_CHECK_EQ(bcr, st.rejected_bcr, "ENTDAA retry BCR mismatch")
        `DV_CHECK_EQ(dcr, st.rejected_dcr, "ENTDAA retry DCR mismatch")
        `DV_CHECK_EQ(joined_addr, st.rejected_addr,
                     "ENTDAA retry should reuse the same assigned address")
      end
      if (enqueue_rx_word_expectation(
              exp.tid,
              (st.devices_joined_local + 1) * 12,
              st.devices_joined_local * 3 + 0,
              rx_word0,
              "ENTDAA"
          ))
        resp_status = Ovl;
      else resp_len += 4;
      if (enqueue_rx_word_expectation(
              exp.tid,
              (st.devices_joined_local + 1) * 12,
              st.devices_joined_local * 3 + 1,
              rx_word1,
              "ENTDAA"
          ))
        resp_status = Ovl;
      else resp_len += 4;
      if (enqueue_rx_word_expectation(
              exp.tid,
              (st.devices_joined_local + 1) * 12,
              st.devices_joined_local * 3 + 2,
              rx_word2,
              "ENTDAA"
          ))
        resp_status = Ovl;
      else resp_len += 4;
      st.devices_joined_local++;
      st.address_rejected_once = 1'b0;
    end else if (device_ack_present) begin
      if (st.address_rejected_once) begin
        `DV_CHECK_EQ(pid, st.rejected_pid,
                     "ENTDAA retry should be won by the target that rejected the address")
        `DV_CHECK_EQ(bcr, st.rejected_bcr, "ENTDAA retry BCR mismatch")
        `DV_CHECK_EQ(dcr, st.rejected_dcr, "ENTDAA retry DCR mismatch")
        `DV_CHECK_EQ(joined_addr, st.rejected_addr,
                     "ENTDAA retry should reuse the same assigned address")
        `DV_CHECK_EQ(i, item.CCC_direct_q.size() - 1,
                     "Second assigned-address NACK must terminate ENTDAA")
        st.address_reject_error = 1'b1;
        resp_status = Nack;
      end else begin
        st.rejected_pid = pid;
        st.rejected_bcr = bcr;
        st.rejected_dcr = dcr;
        st.rejected_addr = joined_addr;
        st.address_rejected_once = 1'b1;
        `DV_CHECK_LT(i, item.CCC_direct_q.size() - 1,
                     "First assigned-address NACK should be followed by a retry round")
      end
    end
    `uvm_info(
        `gfn,
        $sformatf(
            "CCC ENTDAA ROUND[%0d]: tid=0x%0h expected_start=Sr observed_start=%s expected_addr=0x7e observed_addr=0x%02h expected_op=Read observed_op=%s addr_ack=ACK observed_pid=0x%012h observed_bcr=0x%02h observed_dcr=0x%02h assigned_addr=0x%02h expected_parity=%0b observed_parity=%0b device_ack=%s observed_stop=%0b observed_rstart=%0b",
            i, exp.tid, start_source_to_string(item.CCC_direct_q[i].start_from_rstart),
            item.CCC_direct_q[i].addr, item.CCC_direct_q[i].bus_op.name(), pid, bcr, dcr,
            joined_addr, ~^joined_addr, item.CCC_direct_q[i].data_q[8][0], optional_ack_to_string(
            device_ack_present, !device_ack), item.CCC_direct_q[i].stop, item.CCC_direct_q[i].rstart),
        UVM_LOW)
  end else begin
    `uvm_info(`gfn, $sformatf(
              "CCC ENTDAA ROUND[%0d]: tid=0x%0h expected_start=Sr observed_start=%s expected_addr=0x7e observed_addr=0x%02h expected_op=Read observed_op=%s addr_ack=NACK observed_stop=%0b observed_rstart=%0b",
              i,
              exp.tid,
              start_source_to_string(
                  item.CCC_direct_q[i].start_from_rstart
              ),
              item.CCC_direct_q[i].addr,
              item.CCC_direct_q[i].bus_op.name(),
              item.CCC_direct_q[i].stop,
              item.CCC_direct_q[i].rstart
              ), UVM_LOW)
    st.terminating_nack_seen = 1'b1;
    `DV_CHECK_EQ(st.address_rejected_once, 1'b0,
                 "Target that rejected an address should participate in the retry")
    `DV_CHECK_EQ(i, item.CCC_direct_q.size() - 1, "ENTDAA no-device NACK must terminate the loop")
    `DV_CHECK_LT(i, exp.daa_dev_count,
                 "ENTDAA emitted an unnecessary no-device round after dev_count")
  end
endfunction

function i3c_daa_result_e i3c_scoreboard::resolve_daa_result(exp_txn_t exp, daa_scan_state_t st,
                                             i3c_resp_err_status_e resp_status);
  if (resp_status == Ovl) begin
    return DAA_RESULT_OVERFLOW;
  end else if (st.hc_abort_seen || (resp_status == HcAborted)) begin
    return DAA_RESULT_ABORT;
  end else if (st.address_reject_error || (resp_status == Nack)) begin
    return DAA_RESULT_ADDRESS_REJECTED;
  end else if (st.terminating_nack_seen && (st.devices_joined_local == 0)) begin
    return DAA_RESULT_NO_DEVICE;
  end else if (st.terminating_nack_seen && (st.devices_joined_local < exp.daa_dev_count)) begin
    return DAA_RESULT_FEWER_THAN_COUNT;
  end else if (st.devices_joined_local == exp.daa_dev_count) begin
    return DAA_RESULT_ASSIGNED_ALL;
  end else begin
    return DAA_RESULT_OTHER;
  end
endfunction

function void i3c_scoreboard::log_ccc_direct_data(i3c_item item, exp_txn_t exp, int direct_idx,
                                  i3c_item direct_item, i3c_resp_err_status_e resp_status,
                                  int resp_len);
  string       expected_ccc_name;
  string       observed_ccc_name;
  bit          target_data_present;
  bit          target_t_bit_present;
  bit    [7:0] observed_event_byte;
  bit          observed_t_bit;

  expected_ccc_name    = ccc_to_string(exp.cmd_code);
  observed_ccc_name    = item.CCC_valid ? item.CCC.name() : "?";
  target_data_present  = !direct_item.addr_nack && (direct_item.data_q.size() > 0);
  target_t_bit_present = !direct_item.addr_nack && (direct_item.data_nack_q.size() > 0);
  observed_event_byte  = target_data_present ? direct_item.data_q[0] : '0;
  observed_t_bit       = target_t_bit_present ? direct_item.data_nack_q[0] : 1'b0;
  `uvm_info(`gfn, $sformatf(
            "CCC DIRECT PHASE[%0d]: tid=0x%0h expected_start=Sr observed_start=%s expected_target=0x%02h observed_target=0x%02h expected_op=Write observed_op=%s target_ack=%s observed_stop=%0b observed_rstart=%0b",
            direct_idx,
            exp.tid,
            start_source_to_string(
                direct_item.start_from_rstart
            ),
            exp.ccc_target_addr,
            direct_item.addr,
            direct_item.bus_op.name(),
            ack_to_string(
                !direct_item.addr_nack
            ),
            direct_item.stop,
            direct_item.rstart
            ), UVM_LOW)
  `uvm_info(`gfn, $sformatf(
            "CCC DATA: tid=0x%0h expected_ccc=%s(0x%02h) observed_ccc=%s expected_bcast_addr=0x%02h observed_bcast_addr=0x%02h expected_target=0x%02h observed_target=0x%02h expected_target_ack=%s observed_target_ack=%s expected_event=%s observed_event=%s expected_t_bit=%s observed_t_bit=%s expected_resp_status=%s expected_resp_len=%0d",
            exp.tid,
            expected_ccc_name,
            8'(exp.cmd_code),
            observed_ccc_name,
            exp.addr,
            item.addr,
            exp.ccc_target_addr,
            direct_item.addr,
            ack_to_string(
                !direct_item.addr_nack
            ),
            ack_to_string(
                !direct_item.addr_nack
            ),
            format_optional_byte(
                !direct_item.addr_nack, exp.event_byte
            ),
            format_optional_byte(
                target_data_present, observed_event_byte
            ),
            format_optional_bit(
                !direct_item.addr_nack, ~^exp.event_byte
            ),
            format_optional_bit(
                target_t_bit_present, observed_t_bit
            ),
            resp_status_to_string(
                resp_status
            ),
            resp_len
            ), UVM_LOW)
endfunction

function void i3c_scoreboard::log_ccc_entdaa_data(i3c_item item, exp_txn_t exp, i3c_resp_err_status_e resp_status,
                                  int resp_len);
  string expected_ccc_name;
  string observed_ccc_name;
  int    devices_joined;

  expected_ccc_name = ccc_to_string(exp.cmd_code);
  observed_ccc_name = item.CCC_valid ? item.CCC.name() : "?";
  devices_joined = 0;
  foreach (item.CCC_direct_q[i]) begin
    if (!item.CCC_direct_q[i].addr_nack && item.CCC_direct_q[i].data_nack_q.size() > 0 &&
        !item.CCC_direct_q[i].data_nack_q[0])
      devices_joined++;
  end
  `uvm_info(`gfn, $sformatf(
            "CCC DATA: tid=0x%0h expected_ccc=ENTDAA(0x07) observed_ccc=%s expected_bcast_addr=0x%02h observed_bcast_addr=0x%02h expected_bcast_ack=%s observed_bcast_ack=%s expected_min_daa_rounds=1 observed_daa_rounds=%0d expected_joined_round_bytes=9 devices_joined=%0d expected_resp_status=%s expected_resp_len=%0d",
            exp.tid,
            observed_ccc_name,
            exp.addr,
            item.addr,
            ack_to_string(
                1'b1
            ),
            ack_to_string(
                !item.addr_nack
            ),
            item.CCC_direct_q.size(),
            devices_joined,
            resp_status_to_string(
                resp_status
            ),
            resp_len
            ), UVM_LOW)
endfunction

function void i3c_scoreboard::log_ccc_broadcast_data(i3c_item item, exp_txn_t exp,
                                     i3c_resp_err_status_e resp_status, int resp_len);
  string       expected_ccc_name;
  string       observed_ccc_name;
  bit          payload_present;
  bit          t_bit_present;
  bit    [7:0] observed_event_byte;
  bit          observed_t_bit;

  expected_ccc_name   = ccc_to_string(exp.cmd_code);
  observed_ccc_name   = item.CCC_valid ? item.CCC.name() : "?";
  payload_present     = !item.addr_nack && (item.data_q.size() > 0);
  t_bit_present       = !item.addr_nack && (item.data_nack_q.size() > 0);
  observed_event_byte = payload_present ? item.data_q[0] : '0;
  observed_t_bit      = t_bit_present ? item.data_nack_q[0] : 1'b0;
  `uvm_info(`gfn, $sformatf(
            "CCC DATA: tid=0x%0h expected_ccc=%s(0x%02h) observed_ccc=%s expected_bcast_addr=0x%02h observed_bcast_addr=0x%02h expected_bcast_ack=%s observed_bcast_ack=%s expected_event=%s observed_event=%s expected_t_bit=%s observed_t_bit=%s expected_direct_phases=0 observed_direct_phases=%0d expected_resp_status=%s expected_resp_len=%0d",
            exp.tid,
            expected_ccc_name,
            8'(exp.cmd_code),
            observed_ccc_name,
            exp.addr,
            item.addr,
            ack_to_string(
                !item.addr_nack
            ),
            ack_to_string(
                !item.addr_nack
            ),
            format_optional_byte(
                !item.addr_nack && exp.data_length > 0, exp.event_byte
            ),
            format_optional_byte(
                payload_present, observed_event_byte
            ),
            format_optional_bit(
                !item.addr_nack && exp.data_length > 0, ~^exp.event_byte
            ),
            format_optional_bit(
                t_bit_present, observed_t_bit
            ),
            item.CCC_direct_q.size(),
            resp_status_to_string(
                resp_status
            ),
            resp_len
            ), UVM_LOW)
endfunction
