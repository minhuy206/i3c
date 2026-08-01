// -----------------------------------------------------------------------------
// i3c_scoreboard: Correlated transaction reporting
// -----------------------------------------------------------------------------

function int unsigned i3c_scoreboard::create_result(bit [3:0] tid, string command,
                                                     bit bus_required);
  i3c_scoreboard_result result;
  int unsigned result_id;

  result_id = next_result_id++;
  result = new();
  result.result_id = result_id;
  result.tid = tid;
  result.command = command;
  result.bus_required = bus_required;
  results[result_id] = result;
  result_order.push_back(result_id);
  return result_id;
endfunction

function string i3c_scoreboard::format_command(exp_txn_t exp);
  string protocol;
  string direction;

  if (exp.is_ccc) begin
    if (exp.cmd_code == 8'(ENTDAA))
      return $sformatf("ENTDAA count=%0d", exp.daa_dev_count);
    return $sformatf("CCC %s", ccc_to_string(exp.cmd_code));
  end

  protocol = exp.target_is_i3c ? "I3C" : "I2C";
  direction = exp.rnw ? "READ" : "WRITE";
  return $sformatf("%s %s, %0d byte%s", protocol, direction, exp.data_length,
                   (exp.data_length == 1) ? "" : "s");
endfunction

function string i3c_scoreboard::format_bus_trace(i3c_item item);
  string trace;
  string token;
  string op;
  int i;
  int daa_round;

  if (item.bus_event_q.size() == 0) begin
    `uvm_error("I3C_SCB", $sformatf(
               "Transaction %0d reached scoreboard without observed bus events", item.tran_id))
    return "<NO OBSERVED EVENTS>";
  end

  i = 0;
  daa_round = 0;
  while (i < item.bus_event_q.size()) begin
    i3c_bus_event observed_event;

    observed_event = item.bus_event_q[i];
    token = "";
    if (observed_event == null) begin
      `uvm_error("I3C_SCB", $sformatf("Transaction %0d has a null bus event at index %0d",
                                     item.tran_id, i))
      token = "<UNKNOWN>";
    end else begin
      case (observed_event.kind)
        I3cBusEventStart:  token = "S";
        I3cBusEventRStart: token = "Sr";
        I3cBusEventAddress: begin
          op = (observed_event.bus_op == BusOpRead) ? "R" : "W";
          token = $sformatf("0x%02h/%s", observed_event.value[6:0], op);
        end
        I3cBusEventAck:  token = "ACK";
        I3cBusEventNack: token = "NACK";
        I3cBusEventCcc: begin
          i3c_ccc_e ccc;
          ccc = i3c_ccc_e'(observed_event.value);
          token = $sformatf("CCC %s(0x%02h)", ccc.name(), observed_event.value);
        end
        I3cBusEventData: begin
          case (observed_event.role)
            I3cBusRoleDaaPid: begin
              bit pid_valid;
              bit [47:0] pid;

              pid_valid = (observed_event.index == 0) && ((i + 5) < item.bus_event_q.size());
              for (int j = 0; j < 6 && pid_valid; j++) begin
                pid_valid &= (item.bus_event_q[i+j] != null) &&
                             (item.bus_event_q[i+j].kind == I3cBusEventData) &&
                             (item.bus_event_q[i+j].role == I3cBusRoleDaaPid) &&
                             (item.bus_event_q[i+j].index == j);
              end
              if (pid_valid) begin
                pid = {item.bus_event_q[i].value, item.bus_event_q[i+1].value,
                       item.bus_event_q[i+2].value, item.bus_event_q[i+3].value,
                       item.bus_event_q[i+4].value, item.bus_event_q[i+5].value};
                token = $sformatf("ROUND[%0d] PID=0x%012h", daa_round, pid);
                daa_round++;
                i += 5;
              end else begin
                token = $sformatf("PID[%0d]=0x%02h", observed_event.index,
                                  observed_event.value);
              end
            end
            I3cBusRoleDaaBcr: token = $sformatf("BCR=0x%02h", observed_event.value);
            I3cBusRoleDaaDcr: begin
              token = $sformatf("DCR=0x%02h", observed_event.value);
              if (((i + 1) < item.bus_event_q.size()) &&
                  (item.bus_event_q[i+1] != null) &&
                  ((item.bus_event_q[i+1].kind == I3cBusEventStop) ||
                   (item.bus_event_q[i+1].kind == I3cBusEventRStart)))
                token = {token, " -> HC-ABORT"};
            end
            I3cBusRoleDaaAssign:
              token = $sformatf("ASSIGN=0x%02h -> PARITY=%0b", observed_event.value[7:1],
                                observed_event.value[0]);
            default: token = $sformatf("DATA[%0d]=0x%02h", observed_event.index,
                                       observed_event.value);
          endcase
        end
        I3cBusEventTBit: token = $sformatf("T=%0b", observed_event.value[0]);
        I3cBusEventStop: token = "P";
        default: begin
          `uvm_error("I3C_SCB", $sformatf(
                     "Transaction %0d has unknown bus event kind at index %0d",
                     item.tran_id, i))
          token = "<UNKNOWN>";
        end
      endcase
    end

    if (trace == "") begin
      trace = token;
    end else begin
      if ((observed_event != null) && (observed_event.kind == I3cBusEventData) &&
          (observed_event.role == I3cBusRoleGeneric) && (observed_event.index > 0) &&
          ((observed_event.index % 8) == 0)) trace = {trace, "\n        "};
      trace = {trace, " -> ", token};
    end
    i++;
  end
  return trace;
endfunction

function int i3c_scoreboard::scoreboard_error_count();
  uvm_report_server server;
  server = uvm_report_server::get_server();
  return server.get_severity_count(UVM_ERROR);
endfunction

function void i3c_scoreboard::finish_bus_result(int unsigned result_id, i3c_item item,
                                                int errors_before);
  i3c_scoreboard_result result;
  int errors_after;

  if (!results.exists(result_id)) return;
  result = results[result_id];
  result.bus_trace = format_bus_trace(item);
  errors_after = scoreboard_error_count();
  result.bus_order = next_bus_order++;
  result.bus_done = 1'b1;
  result.bus_pass = errors_after == errors_before;
  `uvm_info("I3C_SCB", $sformatf(
            "[TXN %04d][BUS %s] TID=0x%0h %s",
            result.result_id, result.bus_pass ? "PASS" : "FAIL", result.tid,
            result.command), UVM_LOW)
  maybe_report_transaction_flow(result_id);
endfunction

function void i3c_scoreboard::maybe_report_transaction_flow(int unsigned result_id,
                                                            bit force_report);
  i3c_scoreboard_result result;
  bit transaction_complete;

  if (!results.exists(result_id)) return;
  result = results[result_id];
  if (result.flow_reported || !result.bus_required || !result.bus_done) return;

  transaction_complete =
      result.reset_cleared ||
      ((result.rx_observed_words >= result.rx_expected_words) &&
       (!result.resp_required || result.resp_done));
  if (!transaction_complete && !force_report) return;

  result.flow_reported = 1'b1;
  `uvm_info("I3C_SCB", $sformatf(
            "[TXN %04d][FLOW]\n  FLOW: %s",
            result.result_id, result.bus_trace), UVM_LOW)
endfunction

function void i3c_scoreboard::print_pending_transaction_flows();
  foreach (result_order[i]) begin
    maybe_report_transaction_flow(result_order[i], 1'b1);
  end
endfunction

function void i3c_scoreboard::mark_result_failed(int unsigned result_id, string reason);
  i3c_scoreboard_result result;
  if (!results.exists(result_id)) return;
  result = results[result_id];
  result.forced_fail = 1'b1;
  if (result.failure_reason == "")
    result.failure_reason = reason;
  else
    result.failure_reason = {result.failure_reason, "; ", reason};
endfunction

function void i3c_scoreboard::mark_results_reset_cleared(string reset_kind);
  foreach (results[id]) begin
    i3c_scoreboard_result result;
    result = results[id];
    if (!result.reset_cleared && !result.forced_fail && result.bus_pass && result.rx_pass &&
        result.resp_pass &&
        ((!result.bus_done && result.bus_required) ||
         (result.resp_required && !result.resp_done) ||
         (result.rx_observed_words < result.rx_expected_words))) begin
      result.reset_cleared = 1'b1;
      result.failure_reason = {reset_kind, " cleared pending scoreboard state"};
      maybe_report_transaction_flow(id);
    end
  end
endfunction

function void i3c_scoreboard::mark_rx_expected(int unsigned result_id);
  if (results.exists(result_id)) results[result_id].rx_expected_words++;
endfunction

function void i3c_scoreboard::mark_rx_observed(int unsigned result_id, bit pass);
  if (!results.exists(result_id)) return;
  results[result_id].rx_observed_words++;
  results[result_id].rx_pass &= pass;
  if (results[result_id].rx_observed_words == results[result_id].rx_expected_words) begin
    `uvm_info("I3C_SCB", $sformatf(
              "[TXN %04d][RX %s] words=%0d/%0d",
              result_id, results[result_id].rx_pass ? "PASS" : "FAIL",
              results[result_id].rx_observed_words, results[result_id].rx_expected_words), UVM_LOW)
    maybe_report_transaction_flow(result_id);
  end
endfunction

function void i3c_scoreboard::mark_response_model(int unsigned result_id, bit required,
                                                  string expected);
  if (!results.exists(result_id)) return;
  results[result_id].resp_required = required;
  results[result_id].resp_suppressed = !required;
  results[result_id].resp_done = !required;
  results[result_id].expected_response = expected;
endfunction

function void i3c_scoreboard::mark_response_observed(int unsigned result_id, bit pass,
                                                     string observed);
  if (!results.exists(result_id)) return;
  results[result_id].resp_done = 1'b1;
  results[result_id].resp_pass = pass;
  results[result_id].observed_response = observed;
endfunction

function string i3c_scoreboard::result_status(i3c_scoreboard_result result);
  if (result.reset_cleared) return "RESET-CLEARED";
  if (result.forced_fail) return "FAIL";
  if (result.bus_required && (!result.bus_done || !result.bus_pass)) return "FAIL";
  if ((result.rx_observed_words < result.rx_expected_words) || !result.rx_pass) return "FAIL";
  if (result.resp_required && (!result.resp_done || !result.resp_pass)) return "FAIL";
  return "PASS";
endfunction

function void i3c_scoreboard::print_scoreboard_summary();
  string report;
  int pass_count;
  int fail_count;
  int reset_count;

  report = "[SUMMARY] I3C SCOREBOARD RESULTS\n";
  report = {report, $sformatf("  %-4s  %-4s  %-4s  %-31s %-6s %-8s %-32s %s\n",
                              "ID", "BUS#", "TID", "COMMAND", "BUS", "RX", "RESPONSE",
                              "RESULT")};
  foreach (result_order[i]) begin
    int unsigned id;
    i3c_scoreboard_result result;
    string status;
    string bus_status;
    string rx_status;
    string resp_status;
    string bus_order;
    string tid;

    id = result_order[i];
    result = results[id];
    status = result_status(result);
    if (status == "PASS") pass_count++;
    else if (status == "FAIL") fail_count++;
    else reset_count++;

    bus_status = result.reset_cleared && result.bus_required && !result.bus_done ? "CLEARED" :
                 !result.bus_required ? "N/A" :
                 !result.bus_done ? "MISS" : result.bus_pass ? "PASS" : "FAIL";
    rx_status = result.reset_cleared &&
                (result.rx_observed_words < result.rx_expected_words) ? "CLEARED" :
                (result.rx_expected_words == 0) ? "N/A" :
                $sformatf("%0d/%0d%s", result.rx_observed_words, result.rx_expected_words,
                          result.rx_pass ? "" : " FAIL");
    resp_status = result.reset_cleared && result.resp_required && !result.resp_done ? "CLEARED" :
                  result.resp_suppressed ? "SUPPRESSED" :
                  !result.resp_required ? "N/A" :
                  !result.resp_done ? "MISSING" :
                  result.resp_pass ? {result.expected_response, "/PASS"} :
                  {result.expected_response, "/FAIL"};
    if (result.bus_order == 0) bus_order = "----";
    else                       bus_order = $sformatf("%04d", result.bus_order);
    tid = $sformatf("%0h", result.tid);
    report = {report, $sformatf("  %04d  %-4s  %-4s  %-31s %-6s %-8s %-32s %s\n",
                                result.result_id, bus_order, tid, result.command, bus_status,
                                rx_status, resp_status, status)};
    if ((status == "FAIL") && (result.failure_reason != ""))
      report = {report, "        REASON: ", result.failure_reason, "\n"};
    if (result.resp_required && result.resp_done && !result.resp_pass)
      report = {report, "        RESPONSE: expected=", result.expected_response,
                " observed=", result.observed_response, "\n"};
  end
  report = {report, $sformatf(
      "\n  Commands: total=%0d pass=%0d fail=%0d reset-cleared=%0d\n",
      result_order.size(), pass_count, fail_count, reset_count)};
  report = {report, $sformatf(
      "  Pending: commands=%0d tx_words=%0d rx_words=%0d responses=%0d\n",
      exp_txn_queue.size(), tx_data_queue.size(), exp_rx_data_queue.size(), exp_resp_queue.size())};
  report = {report, "  SCOREBOARD RESULT: ", fail_count == 0 ? "PASS" : "FAIL"};
  `uvm_info("I3C_SCB", report, UVM_LOW)
endfunction
