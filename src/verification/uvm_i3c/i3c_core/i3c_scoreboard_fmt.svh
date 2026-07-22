// -----------------------------------------------------------------------------
// i3c_scoreboard: Diagnostic formatting
// -----------------------------------------------------------------------------

function string i3c_scoreboard::resp_status_to_string(i3c_resp_err_e status);
  string status_name;

  status_name = status.name();
  return (status_name != "") ? status_name : $sformatf("0x%0h", status);
endfunction

function string i3c_scoreboard::ack_to_string(bit ack);
  return ack ? "ACK" : "NACK";
endfunction

function string i3c_scoreboard::optional_ack_to_string(bit present, bit ack);
  return present ? ack_to_string(ack) : "NONE";
endfunction

function string i3c_scoreboard::start_source_to_string(bit start_from_rstart);
  return start_from_rstart ? "Sr" : "S";
endfunction

function void i3c_scoreboard::print_i3c_address(i3c_item item, exp_txn_t exp);
  `uvm_info(`gfn, $sformatf(
            "I3C ADDRESS: tid=0x%0h expected_broadcast_header=%0b observed_broadcast_header=%0b expected_broadcast_header_ack=%s observed_broadcast_header_ack=%s expected_addr=0x%02h observed_addr=0x%02h expected_ack=%s observed_ack=%s",
            exp.tid,
            exp.start_with_broadcast_header,
            item.start_with_broadcast_header,
            optional_ack_to_string(
                exp.start_with_broadcast_header, 1'b1
            ),
            optional_ack_to_string(
                item.start_with_broadcast_header, !item.broadcast_header_nack
            ),
            exp.addr,
            item.addr,
            ack_to_string(
                1'b1
            ),
            ack_to_string(
                !item.addr_nack
            )
            ), UVM_LOW)
endfunction

function void i3c_scoreboard::print_i3c_end(i3c_item item, exp_txn_t exp, bit expected_rstart, bit expected_stop);
  `uvm_info(`gfn, $sformatf(
            "I3C END: tid=0x%0h expected_rstart=%0b observed_rstart=%0b expected_stop=%0b observed_stop=%0b",
            exp.tid,
            expected_rstart,
            item.rstart,
            expected_stop,
            item.stop
            ), UVM_LOW)
endfunction

function void i3c_scoreboard::print_ccc_end(i3c_item item, exp_txn_t exp, bit expected_rstart, bit expected_stop);
  `uvm_info(`gfn, $sformatf(
            "CCC END: tid=0x%0h expected_final_rstart=%0b observed_final_rstart=%0b expected_stop=%0b observed_stop=%0b",
            exp.tid,
            expected_rstart,
            item.rstart,
            expected_stop,
            item.stop
            ), UVM_LOW)
endfunction

function string i3c_scoreboard::format_token_list(string tokens[$], int data_length, string missing_token);
  string s;

  s = "[";
  for (int i = 0; i < data_length; i++) begin
    if (i > 0) s = {s, " "};
    if (i < tokens.size()) begin
      s = {s, tokens[i]};
    end else begin
      s = {s, missing_token};
    end
  end
  return {s, "]"};
endfunction

function string i3c_scoreboard::format_byte_list(bit [7:0] bytes[$], int data_length);
  string tokens[$];

  for (int i = 0; (i < data_length) && (i < bytes.size()); i++) begin
    tokens.push_back($sformatf("%02h", bytes[i]));
  end
  return format_token_list(tokens, data_length, "??");
endfunction

function string i3c_scoreboard::format_bit_list(bit bits[$], int data_length);
  string tokens[$];

  for (int i = 0; (i < data_length) && (i < bits.size()); i++) begin
    tokens.push_back($sformatf("%0b", bits[i]));
  end
  return format_token_list(tokens, data_length, "?");
endfunction

function string i3c_scoreboard::format_ack_list(bit acks[$], int data_length);
  string tokens[$];

  for (int i = 0; (i < data_length) && (i < acks.size()); i++) begin
    tokens.push_back(ack_to_string(acks[i]));
  end
  return format_token_list(tokens, data_length, "?");
endfunction

// I2C: bits are stored in NACK-polarity (1=NACK); invert for ack_to_string display.
function string i3c_scoreboard::format_ack_or_t_bit_list(bit target_is_i3c, bit bits[$], int data_length);
  string tokens[$];
  if (target_is_i3c) return format_bit_list(bits, data_length);
  for (int i = 0; (i < data_length) && (i < bits.size()); i++)
  tokens.push_back(ack_to_string(!bits[i]));
  return format_token_list(tokens, data_length, "?");
endfunction

function string i3c_scoreboard::format_observed_bytes(bit [7:0] bytes[$], int data_length);
  return format_byte_list(bytes, data_length);
endfunction

function string i3c_scoreboard::format_expected_tx_bytes(int data_length);
  bit [7:0] bytes[$];

  collect_expected_tx_bytes(data_length, bytes);
  return format_byte_list(bytes, data_length);
endfunction

function string i3c_scoreboard::format_observed_t_bits(bit t_bits[$], int data_length);
  return format_bit_list(t_bits, data_length);
endfunction

function string i3c_scoreboard::format_observed_ack_or_t_bits(bit target_is_i3c, bit t_bits[$], int data_length);
  return format_ack_or_t_bit_list(target_is_i3c, t_bits, data_length);
endfunction

function string i3c_scoreboard::format_optional_byte(bit present, bit [7:0] value);
  return present ? $sformatf("0x%02h", value) : "--";
endfunction

function string i3c_scoreboard::format_optional_addr(bit present, bit [6:0] value);
  return present ? $sformatf("0x%02h", value) : "--";
endfunction

function string i3c_scoreboard::format_optional_bit(bit present, bit value);
  return present ? $sformatf("%0b", value) : "--";
endfunction

function string i3c_scoreboard::format_expected_tx_ack_or_t_bits(int data_length, bit target_is_i3c,
                                                 bit allow_i2c_final_data_nack);
  bit t_bits[$];

  collect_expected_tx_ack_or_t_bits(data_length, target_is_i3c, t_bits,
                                    allow_i2c_final_data_nack);
  return format_ack_or_t_bit_list(target_is_i3c, t_bits, data_length);
endfunction

function string i3c_scoreboard::format_expected_rx_ack_or_t_bits(i3c_item item, exp_txn_t exp);
  bit t_bits[$];

  t_bits.delete();
  for (int i = 0; i < item.num_data; i++) begin
    t_bits.push_back(expected_rx_ack_or_t_bit(exp.target_is_i3c, item, i));
  end
  return format_ack_or_t_bit_list(exp.target_is_i3c, t_bits, item.num_data);
endfunction

function string i3c_scoreboard::format_expected_imm_bytes(exp_txn_t exp, int data_length);
  bit [7:0] bytes[$];
  for (int i = 0; (i < data_length) && (i < 4); i++) bytes.push_back(exp.imm_data_byte[i]);
  return format_byte_list(bytes, data_length);
endfunction

function string i3c_scoreboard::format_expected_imm_t_bits(exp_txn_t exp, int data_length);
  bit t_bits[$];
  for (int i = 0; (i < data_length) && (i < 4); i++) begin
    t_bits.push_back(
        exp.target_is_i3c ? ~^exp.imm_data_byte[i] : 1'b0);  // I2C: 0=ACK (NACK-polarity)
  end
  return format_ack_or_t_bit_list(exp.target_is_i3c, t_bits, data_length);
endfunction
