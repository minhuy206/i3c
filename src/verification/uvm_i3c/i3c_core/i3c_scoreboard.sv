class i3c_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(i3c_scoreboard)

  i3c_env_cfg                           cfg;

  uvm_tlm_analysis_fifo #(reg_seq_item) reg_fifo;
  uvm_tlm_analysis_fifo #(i3c_item)     i3c_fifo;

  typedef struct {
    bit [6:0] addr;
    bit       rnw;
    bit       toc;
    bit       uses_tx_queue;
    bit       is_immediate;
    int       data_length;
    bit [3:0] tid;
    bit       is_ccc;
    bit [7:0] ccc;
    bit [6:0] ccc_target_addr;
    bit [7:0] event_byte;
    bit [7:0] imm_data_byte[4];
    bit       target_is_i3c;
    bit       broadcast_header_eligible;
    bit       updates_private_continuation;
    bit       start_with_broadcast_header;
  } exp_txn_t;

  typedef struct {
    bit       valid;
    bit       device;
    bit [6:0] static_address;
    bit [6:0] dynamic_address;
  } dat_model_entry_t;

  typedef struct {
    bit        known;
    int        read_id;
    bit [3:0]  tid;
    int        data_length;
    int        word_idx;
    int        valid_bytes;
    bit [31:0] data;
  } exp_rx_data_t;

  typedef struct {
    bit                   rnw;
    bit [3:0]             tid;
    int                   data_length;
    int                   read_id;
    i3c_resp_err_status_e resp_status;
  } pending_resp_t;

  localparam int unsigned RxFifoDepth = 8;

  exp_txn_t exp_txn_queue[$];
  bit [31:0] tx_data_queue[$];
  exp_rx_data_t exp_rx_data_queue[$];
  pending_resp_t pending_resp_queue[$];
  dat_model_entry_t dat_model[DAT_DEPTH];

  bit got_dw0;
  bit [31:0] cmd_dw0;
  bit broadcast_header_enable;
  bit hc_abort_active;
  bit pending_private_continuation;
  int next_read_id;

  function new(string name = "", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    reg_fifo = new("reg_fifo", this);
    i3c_fifo = new("i3c_fifo", this);
  endfunction

  task run_phase(uvm_phase phase);
    fork
      process_req_items();
      process_i3c_items();
    join
  endtask

  function string resp_status_to_string(i3c_resp_err_status_e status);
    string status_name;

    status_name = status.name();
    return (status_name != "") ? status_name : $sformatf("0x%0h", status);
  endfunction

  function string ack_to_string(bit ack);
    return ack ? "ACK" : "NACK";
  endfunction

  function string optional_ack_to_string(bit present, bit ack);
    return present ? ack_to_string(ack) : "NONE";
  endfunction

  function void print_i3c_address(i3c_item item, exp_txn_t exp);
    `uvm_info(`gfn, $sformatf(
              "I3C ADDRESS: tid=0x%0h expected_broadcast_header=%0b observed_broadcast_header=%0b expected_broadcast_header_ack=%s observed_broadcast_header_ack=%s expected_addr=0x%02h observed_addr=0x%02h expected_ack=%s observed_ack=%s",
              exp.tid,
              exp.start_with_broadcast_header,
              item.start_with_broadcast_header,
              optional_ack_to_string(
                  exp.start_with_broadcast_header, 1'b1
              ),
              optional_ack_to_string(
                  item.start_with_broadcast_header, item.broadcast_header_ack
              ),
              exp.addr,
              item.addr,
              ack_to_string(
                  1'b1
              ),
              ack_to_string(
                  item.addr_ack
              )
              ), UVM_LOW)
  endfunction

  function void print_i3c_end(i3c_item item, exp_txn_t exp, bit expected_rstart, bit expected_stop);
    `uvm_info(`gfn, $sformatf(
              "I3C END: tid=0x%0h expected_rstart=%0b observed_rstart=%0b expected_stop=%0b observed_stop=%0b",
              exp.tid,
              expected_rstart,
              item.rstart,
              expected_stop,
              item.stop
              ), UVM_LOW)
  endfunction

  function string format_token_list(string tokens[$], int data_length, string missing_token);
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

  function string format_byte_list(bit [7:0] bytes[$], int data_length);
    string tokens[$];

    for (int i = 0; (i < data_length) && (i < bytes.size()); i++) begin
      tokens.push_back($sformatf("%02h", bytes[i]));
    end
    return format_token_list(tokens, data_length, "??");
  endfunction

  function string format_bit_list(bit bits[$], int data_length);
    string tokens[$];

    for (int i = 0; (i < data_length) && (i < bits.size()); i++) begin
      tokens.push_back($sformatf("%0b", bits[i]));
    end
    return format_token_list(tokens, data_length, "?");
  endfunction

  function bit get_expected_tx_byte(int byte_idx, output bit [7:0] data_byte);
    int word_idx;
    int byte_off;

    word_idx  = byte_idx / 4;
    byte_off  = (byte_idx % 4) * 8;
    data_byte = '0;

    if (word_idx >= tx_data_queue.size()) return 1'b0;

    data_byte = tx_data_queue[word_idx][byte_off+:8];
    return 1'b1;
  endfunction

  function void collect_expected_tx_bytes(int data_length, output bit [7:0] bytes[$]);
    bytes.delete();
    for (int i = 0; i < data_length; i++) begin
      bit [7:0] data_byte;

      if (!get_expected_tx_byte(i, data_byte)) break;
      bytes.push_back(data_byte);
    end
  endfunction

  function bit expected_tx_ack_or_t_bit(bit target_is_i3c, bit [7:0] data_byte,
                                        bit i2c_data_nack_byte = 1'b0);
    return target_is_i3c ? ~^data_byte : !i2c_data_nack_byte;
  endfunction

  function string tx_ack_or_t_bit_label(bit target_is_i3c);
    return target_is_i3c ? "T-bit" : "ACK";
  endfunction

  function void collect_expected_tx_ack_or_t_bits(int data_length, bit target_is_i3c,
                                                  output bit t_bits[$],
                                                  input bit allow_i2c_final_data_nack = 1'b0);
    bit [7:0] bytes[$];

    t_bits.delete();
    collect_expected_tx_bytes(data_length, bytes);
    foreach (bytes[i]) begin
      bit i2c_data_nack_byte;

      i2c_data_nack_byte = allow_i2c_final_data_nack && !target_is_i3c && (i == (data_length - 1));
      t_bits.push_back(expected_tx_ack_or_t_bit(target_is_i3c, bytes[i], i2c_data_nack_byte));
    end
  endfunction

  function string format_observed_bytes(bit [7:0] bytes[$], int data_length);
    return format_byte_list(bytes, data_length);
  endfunction

  function string format_expected_tx_bytes(int data_length);
    bit [7:0] bytes[$];

    collect_expected_tx_bytes(data_length, bytes);
    return format_byte_list(bytes, data_length);
  endfunction

  function string format_observed_t_bits(bit t_bits[$], int data_length);
    return format_bit_list(t_bits, data_length);
  endfunction

  function string format_expected_tx_ack_or_t_bits(int data_length, bit target_is_i3c,
                                                   bit allow_i2c_final_data_nack = 1'b0);
    bit t_bits[$];

    collect_expected_tx_ack_or_t_bits(data_length, target_is_i3c, t_bits,
                                      allow_i2c_final_data_nack);
    return format_bit_list(t_bits, data_length);
  endfunction

  function bit expected_rx_ack_or_t_bit(bit target_is_i3c, i3c_item item, int byte_idx);
    if (byte_idx != (item.num_data - 1)) return 1'b1;
    return target_is_i3c ? read_final_t_bit(item) : 1'b0;
  endfunction

  function string rx_ack_or_t_bit_label(bit target_is_i3c);
    return target_is_i3c ? "T-bit" : "ACK/NACK";
  endfunction

  function string format_expected_rx_ack_or_t_bits(i3c_item item, exp_txn_t exp);
    bit t_bits[$];

    t_bits.delete();
    for (int i = 0; i < item.num_data; i++) begin
      t_bits.push_back(expected_rx_ack_or_t_bit(exp.target_is_i3c, item, i));
    end
    return format_bit_list(t_bits, item.num_data);
  endfunction

  function string format_expected_imm_bytes(exp_txn_t exp, int data_length);
    bit [7:0] bytes[$];
    for (int i = 0; (i < data_length) && (i < 4); i++) bytes.push_back(exp.imm_data_byte[i]);
    return format_byte_list(bytes, data_length);
  endfunction

  function string format_expected_imm_t_bits(exp_txn_t exp, int data_length);
    bit t_bits[$];
    for (int i = 0; (i < data_length) && (i < 4); i++) begin
      t_bits.push_back(exp.target_is_i3c ? ~^exp.imm_data_byte[i] : 1'b1);
    end
    return format_bit_list(t_bits, data_length);
  endfunction

  task process_req_items();
    reg_seq_item item;
    forever begin
      reg_fifo.get(item);
      if (item.is_write) begin
        if ((item.addr >= ADDR_DAT_BASE) && (item.addr < ADDR_DAT_END)) begin
          handle_dat_write(item.addr, item.wdata);
        end else begin
          case (item.addr)
            ADDR_HC_CONTROL: handle_hc_control_write(item.wdata);
            ADDR_CMD_QUEUE: handle_cmd_dword(item.wdata);
            ADDR_TX_DATA: tx_data_queue.push_back(item.wdata);
            default: ;
          endcase
        end
      end else begin
        case (item.addr)
          ADDR_RESP: check_resp(item.rdata);
          ADDR_RX_DATA: check_rx_data(item.rdata);
          default: ;
        endcase
      end
    end
  endtask

  function void handle_hc_control_write(bit [31:0] wdata);
    hc_abort_active = wdata[HC_CTRL_HC_ABORT_BIT];
    broadcast_header_enable = wdata[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT];
    if (wdata[HC_CTRL_SW_RESET_BIT]) handle_sw_reset();
    if (hc_abort_active)
      `uvm_info(`gfn, "HC abort asserted: next write transaction will infer HcAborted", UVM_MEDIUM)
  endfunction

  function void handle_sw_reset();
    exp_txn_queue.delete();
    tx_data_queue.delete();
    exp_rx_data_queue.delete();
    pending_resp_queue.delete();
    got_dw0 = 1'b0;
    cmd_dw0 = '0;
    pending_private_continuation = 1'b0;
    next_read_id = 0;
    `uvm_info(`gfn, "SW_RESET observed: scoreboard queues flushed", UVM_MEDIUM)
  endfunction

  function void handle_dat_write(bit [11:0] addr, bit [31:0] wdata);
    controller_pkg::dat_entry_t entry;
    int unsigned                idx;

    idx = (addr - ADDR_DAT_BASE) >> 2;
    if (idx >= DAT_DEPTH) begin
      `uvm_warning(`gfn, $sformatf("DAT write ignored: addr=0x%03h idx=%0d", addr, idx))
      return;
    end

    entry                          = controller_pkg::dat_entry_t'(wdata);
    dat_model[idx].valid           = 1'b1;
    dat_model[idx].device          = entry.device;
    dat_model[idx].dynamic_address = entry.dynamic_address;
    dat_model[idx].static_address  = entry.static_address;
    `uvm_info(`gfn, $sformatf(
              "DAT[%0d] updated: device=%0b static=0x%02h dynamic=0x%02h",
              idx,
              dat_model[idx].device,
              dat_model[idx].static_address,
              dat_model[idx].dynamic_address
              ), UVM_MEDIUM)
  endfunction

  function void handle_cmd_dword(bit [31:0] wdata);
    regular_trans_desc_t        reg_desc;
    immediate_data_trans_desc_t imm_desc;
    exp_txn_t                   exp;
    bit                         target_is_i3c;

    if (!got_dw0) begin
      cmd_dw0 = wdata;
      got_dw0 = 1'b1;
      return;
    end
    got_dw0                          = 1'b0;

    reg_desc                         = regular_trans_desc_t'({wdata, cmd_dw0});
    imm_desc                         = immediate_data_trans_desc_t'({wdata, cmd_dw0});
    target_is_i3c                    = is_i3c_device(reg_desc.dev_idx);

    exp.tid                          = reg_desc.tid;
    exp.toc                          = reg_desc.toc;
    exp.addr                         = get_device_addr(reg_desc.dev_idx);
    exp.is_ccc                       = 1'b0;
    exp.uses_tx_queue                = 1'b0;
    exp.is_immediate                 = 1'b0;
    exp.ccc                          = reg_desc.cmd;
    exp.ccc_target_addr              = exp.addr;
    exp.event_byte                   = imm_desc.def_or_data_byte1;
    exp.target_is_i3c                = target_is_i3c;
    exp.broadcast_header_eligible    = 1'b0;
    exp.updates_private_continuation = 1'b0;
    exp.start_with_broadcast_header  = 1'b0;

    case (reg_desc.attr)
      RegularTransfer: begin
        exp.rnw                          = reg_desc.rnw;
        exp.data_length                  = int'(reg_desc.data_length);
        exp.uses_tx_queue                = !reg_desc.rnw;
        exp.broadcast_header_eligible    = target_is_i3c;
        exp.updates_private_continuation = target_is_i3c;
      end
      ImmediateDataTransfer: begin
        exp.is_immediate = 1'b1;
        if (imm_desc.dtt > 3'd4) begin
          record_pending_resp(imm_desc.rnw, reg_desc.tid, 0, -1, NotSupported);
          `uvm_info(
              `gfn,
              $sformatf(
                  "CMD queued: ImmediateDataTransfer dtt=%0d > 4 rejected -> modeled NotSupported, no bus txn expected (tid=0x%0h)",
                  imm_desc.dtt, reg_desc.tid), UVM_MEDIUM)
          return;
        end
        if (imm_desc.cp && is_enec_disec_ccc(imm_desc.cmd)) begin
          exp.addr        = 7'h7e;
          exp.rnw         = 1'b0;
          exp.data_length = 1;
          exp.is_ccc      = 1'b1;
        end else begin
          exp.rnw                       = imm_desc.rnw;
          exp.data_length               = int'(imm_desc.dtt);
          exp.broadcast_header_eligible = !imm_desc.cp && target_is_i3c;
          exp.imm_data_byte[0]          = imm_desc.def_or_data_byte1;
          exp.imm_data_byte[1]          = imm_desc.data_byte2;
          exp.imm_data_byte[2]          = imm_desc.data_byte3;
          exp.imm_data_byte[3]          = imm_desc.data_byte4;
        end
      end
      AddressAssignment: begin
        exp.rnw         = 1'b0;
        exp.data_length = 0;
      end
      default: begin
        exp.rnw         = reg_desc.rnw;
        exp.data_length = 0;
      end
    endcase

    exp_txn_queue.push_back(exp);
    if (exp.is_ccc) begin
      `uvm_info(`gfn, $sformatf(
                          "CMD queued: attr=%s CCC=0x%02h addr=0x%02h event=0x%02h len=%0d toc=%0b",
                          reg_desc.attr.name(), exp.ccc, exp.addr, exp.event_byte, exp.data_length,
                          exp.toc), UVM_MEDIUM)
    end else begin
      `uvm_info(`gfn, $sformatf(
                "CMD queued: attr=%s dev_idx=%0d addr=0x%02h rnw=%0b len=%0d toc=%0b target_i3c=%0b",
                reg_desc.attr.name(),
                reg_desc.dev_idx,
                exp.addr,
                exp.rnw,
                exp.data_length,
                exp.toc,
                exp.target_is_i3c
                ), UVM_MEDIUM)
    end
  endfunction

  function void check_rx_data(bit [31:0] rdata);
    exp_rx_data_t exp;

    if (exp_rx_data_queue.size() == 0) return;

    exp = exp_rx_data_queue.pop_front();

    if (!exp.known) begin
      `uvm_info(`gfn, $sformatf("RX FIFO unknown prefill entry ignored: rdata=0x%08h", rdata),
                UVM_MEDIUM)
      return;
    end

    for (int byte_idx = 0; byte_idx < 4; byte_idx++) begin
      bit [7:0] act_byte;
      bit [7:0] exp_byte;

      act_byte = rdata[(byte_idx*8)+:8];
      exp_byte = exp.data[(byte_idx*8)+:8];

      if (byte_idx < exp.valid_bytes) begin
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
  endfunction

  function void check_resp(bit [31:0] rdata);
    i3c_response_desc_t resp;

    if (pending_resp_queue.size() > 0) begin
      check_pending_resp(rdata);
      return;
    end

    resp = i3c_response_desc_t'(rdata);
    if (resp.err_status == Success) begin
      `uvm_info(`gfn, $sformatf("RESP OK: tid=0x%0h data_length=%0d", resp.tid, resp.data_length),
                UVM_MEDIUM)
    end else begin
      `uvm_error(`gfn, $sformatf(
                 "RESP error: err_status=%s (0x%0h) rdata=0x%08h",
                 resp_status_to_string(
                     resp.err_status
                 ),
                 resp.err_status,
                 rdata
                 ))
    end
  endfunction

  function void record_pending_resp(bit rnw, bit [3:0] tid, int data_length, int read_id = -1,
                                    i3c_resp_err_status_e resp_status = Success);
    pending_resp_t pending;

    pending.rnw = rnw;
    pending.tid = tid;
    pending.data_length = data_length;
    pending.read_id = read_id;
    pending.resp_status = resp_status;

    `uvm_info(`gfn, $sformatf(
              "RESP queued: tid=0x%0h rnw=%0b data_length=%0d read_id=%0d status=%s",
              pending.tid,
              pending.rnw,
              pending.data_length,
              pending.read_id,
              resp_status_to_string(
                  pending.resp_status
              )
              ), UVM_MEDIUM)
    pending_resp_queue.push_back(pending);
  endfunction

  function void check_pending_resp(bit [31:0] rdata);
    pending_resp_t      pending;
    i3c_response_desc_t resp;

    if (pending_resp_queue.size() == 0) return;

    pending = pending_resp_queue.pop_front();
    resp    = i3c_response_desc_t'(rdata);

    if (resp.err_status != pending.resp_status) begin
      `uvm_error(
          `gfn,
          $sformatf(
              "RESP status mismatch: expected=%s (0x%0h) actual=%s (0x%0h) tid=0x%0h data_length=%0d rdata=0x%08h",
              resp_status_to_string(pending.resp_status), pending.resp_status,
              resp_status_to_string(resp.err_status), resp.err_status, pending.tid,
              pending.data_length, rdata))
    end
    if (resp.tid != pending.tid) begin
      `uvm_error(`gfn, $sformatf("RESP TID mismatch: expected=0x%0h actual=0x%0h rdata=0x%08h",
                                 pending.tid, resp.tid, rdata))
    end
    if (resp.data_length != pending.data_length) begin
      `uvm_error(`gfn,
                 $sformatf(
                     "RESP data length mismatch: expected=%0d actual=%0d tid=0x%0h rdata=0x%08h",
                     pending.data_length, resp.data_length, pending.tid, rdata))
    end

    `uvm_info(`gfn, $sformatf(
              "RESPONSE: expected_tid=0x%0h observed_tid=0x%0h expected_status=%s observed_status=%s expected_data_length=%0d observed_data_length=%0d",
              pending.tid,
              resp.tid,
              resp_status_to_string(
                  pending.resp_status
              ),
              resp_status_to_string(
                  resp.err_status
              ),
              pending.data_length,
              resp.data_length
              ), UVM_LOW)
  endfunction

  task process_i3c_items();
    i3c_item item;
    forever begin
      i3c_fifo.get(item);
      if (item.i3c_empty_broadcast) begin
        `uvm_error(`gfn, "Monitor emitted an empty broadcast header instead of a full transaction")
        continue;
      end
      check_i3c_txn(item);
    end
  endtask

  function void check_i3c_txn(i3c_item item);
    exp_txn_t exp;
    bit       txn_aborted;
    bit       expected_rstart;
    bit       expected_stop;

    if (exp_txn_queue.size() == 0) begin
      `uvm_error(`gfn, $sformatf("Unexpected I3C txn: addr=0x%02h op=%s", item.addr,
                                 item.bus_op.name()))
      return;
    end

    exp = exp_txn_queue[0];
    if (!exp_matches_item(exp, item, 0)) begin
      report_i3c_txn_mismatch(item, exp);
      return;
    end

    exp = exp_txn_queue.pop_front();
    txn_aborted = 1'b0;

    if (exp.is_ccc) begin
      check_ccc_txn(item, exp);
      print_i3c_end(item, exp, 1'b0, 1'b1);
      update_private_continuation(exp);
      return;
    end

    exp.start_with_broadcast_header =
        exp.broadcast_header_eligible && broadcast_header_enable && !pending_private_continuation;
    `DV_CHECK_EQ(item.addr, exp.addr, "Target address mismatch")
    `DV_CHECK_EQ(item.bus_op, exp.rnw ? BusOpRead : BusOpWrite, "Transfer direction mismatch")
    `DV_CHECK_EQ(item.start_with_broadcast_header, exp.start_with_broadcast_header,
                 "Broadcast header preamble mismatch")
    if (item.start_with_broadcast_header || exp.start_with_broadcast_header) begin
      `DV_CHECK_EQ(item.broadcast_header_ack, 1'b1, "Broadcast header preamble was not ACKed")
    end
    print_i3c_address(item, exp);

    if (!item.addr_ack) begin
      `DV_CHECK_EQ(item.num_data, 0, "Address NACK should not enter data phase")
      `DV_CHECK_EQ(item.data_q.size(), 0, "Address NACK should not collect data bytes")
      `DV_CHECK_EQ(item.data_ack_q.size(), 0, "Address NACK should not collect data T-bits")
      if (!exp.rnw && exp.uses_tx_queue && exp.data_length > 0) consume_tx_data_words(1);
      record_pending_resp(exp.rnw, exp.tid, 0, -1, AddrHeader);
      update_private_continuation(exp, 1'b1);
      print_i3c_end(item, exp, 1'b0, 1'b1);
      `uvm_info(`gfn, $sformatf("AddrHeader RESP inferred: tid=0x%0h rnw=%0b requested_len=%0d",
                                exp.tid, exp.rnw, exp.data_length), UVM_MEDIUM)
      return;
    end

    if (exp.rnw) begin
      check_read_data(item, exp, expected_rstart, expected_stop, txn_aborted);
    end else if (exp.is_immediate) begin
      txn_aborted = check_immediate_write_data(item, exp);
      expected_rstart = txn_aborted ? 1'b0 : !exp.toc;
      expected_stop = txn_aborted ? 1'b1 : exp.toc;
    end else begin
      txn_aborted = check_write_data(item, exp);
      expected_rstart = txn_aborted ? 1'b0 : !exp.toc;
      expected_stop = txn_aborted ? 1'b1 : exp.toc;
    end

    print_i3c_end(item, exp, expected_rstart, expected_stop);
    update_private_continuation(exp, txn_aborted);
  endfunction

  function bit exp_matches_item(exp_txn_t exp, i3c_item item, int word_offset);
    return (item.addr == exp.addr) &&
           (item.bus_op == (exp.rnw ? BusOpRead : BusOpWrite)) &&
           (exp.rnw || exp.is_ccc || !exp.uses_tx_queue || tx_data_matches_at(item, word_offset));
  endfunction

  function void report_i3c_txn_mismatch(i3c_item item, exp_txn_t exp);
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

  function int find_matching_exp_idx(i3c_item item);
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

  function void check_ccc_txn(i3c_item item, exp_txn_t exp);
    bit                   is_direct_ccc;
    int                   direct_idx;
    i3c_item              direct_item;
    i3c_resp_err_status_e resp_status;
    int                   resp_len;

    is_direct_ccc = exp.ccc[7];
    direct_idx    = -1;
    resp_status   = Success;
    resp_len      = exp.data_length;

    `DV_CHECK_EQ(item.addr, exp.addr, "CCC broadcast address mismatch")
    `DV_CHECK_EQ(item.bus_op, BusOpWrite, "CCC broadcast direction mismatch")

    // Broadcast-header NACK: RTL suppresses opcode + payload and reports AddrHeader.
    // Monitor emits a plain item with addr_ack=0, CCC_valid=0, num_data=0.
    if (!item.addr_ack) begin
      `DV_CHECK_EQ(item.CCC_valid, 1'b0, "Broadcast header NACK should suppress CCC opcode")
      `DV_CHECK_EQ(item.num_data, 0, "Broadcast header NACK should not enter data phase")
      `DV_CHECK_EQ(item.CCC_direct.size(), 0, "Broadcast header NACK should have no direct phase")
      `DV_CHECK_EQ(item.stop, 1'b1, "NACKed CCC should end with STOP")
      record_pending_resp(1'b0, exp.tid, 0, -1, AddrHeader);
      return;
    end

    `DV_CHECK_EQ(item.CCC_valid, 1'b1, "CCC opcode was not decoded")
    `DV_CHECK_EQ(item.CCC, i3c_ccc_e'(exp.ccc), "CCC opcode mismatch")

    if (is_direct_ccc) begin
      `DV_CHECK_EQ(item.num_data, 0, "Direct CCC broadcast leg should not carry event bytes")
      foreach (item.CCC_direct[i]) begin
        if ((direct_idx < 0) && (item.CCC_direct[i].addr == exp.ccc_target_addr) &&
            !item.CCC_direct[i].aborted) begin
          direct_idx = int'(i);
        end
      end
      if (direct_idx < 0) begin
        `uvm_error(`gfn, "Direct CCC target phase missing")
      end else begin
        direct_item = item.CCC_direct[direct_idx];
        `DV_CHECK_EQ(direct_item.addr, exp.ccc_target_addr, "Direct CCC target address mismatch")
        `DV_CHECK_EQ(direct_item.bus_op, BusOpWrite, "Direct CCC target direction mismatch")
        if (!direct_item.addr_ack) begin
          // RTL suppresses trailing data byte on target NACK and reports AddrHeader/len0.
          `DV_CHECK_EQ(direct_item.num_data, 0, "Direct target NACK should suppress data byte")
          `DV_CHECK_EQ(direct_item.stop, 1'b1, "Direct target NACK should end with STOP")
          resp_status = AddrHeader;
          resp_len    = 0;
        end else begin
          `DV_CHECK_EQ(direct_item.num_data, exp.data_length,
                       "Direct CCC event byte count mismatch")
          if (direct_item.data_q.size() > 0) begin
            `DV_CHECK_EQ(direct_item.data_q[0], exp.event_byte, "Direct CCC event byte mismatch")
          end else begin
            `uvm_error(`gfn, "Direct CCC event byte missing")
          end
          if (direct_item.data_ack_q.size() > 0) begin
            `DV_CHECK_EQ(direct_item.data_ack_q[0], ~^exp.event_byte,
                         "Direct CCC event byte T-bit mismatch")
          end else begin
            `uvm_error(`gfn, "Direct CCC event byte T-bit missing")
          end
          `DV_CHECK_EQ(direct_item.stop, 1'b1, "Direct CCC target phase should end with STOP")
        end
      end
    end else begin
      `DV_CHECK_EQ(item.num_data, exp.data_length, "CCC event byte count mismatch")
      if (item.data_q.size() > 0) begin
        `DV_CHECK_EQ(item.data_q[0], exp.event_byte, "CCC event byte mismatch")
      end else begin
        `uvm_error(`gfn, "CCC event byte missing")
      end
      if (item.data_ack_q.size() > 0) begin
        `DV_CHECK_EQ(item.data_ack_q[0], ~^exp.event_byte, "CCC event byte T-bit mismatch")
      end else begin
        `uvm_error(`gfn, "CCC event byte T-bit missing")
      end
      `DV_CHECK_EQ(item.CCC_direct.size(), 0, "Broadcast CCC should not include a direct phase")
    end
    `DV_CHECK_EQ(item.stop, 1'b1, "CCC should end with STOP")

    // NACK (AddrHeader) wins over toc=0 (NotSupported); toc=0 without NACK is rejected by RTL.
    if (resp_status == Success && !exp.toc) begin
      resp_status = NotSupported;
    end
    record_pending_resp(1'b0, exp.tid, resp_len, -1, resp_status);

    begin
      string event_str;
      string tbit_str;
      string ccc_name;

      if (is_direct_ccc && direct_idx >= 0) begin
        event_str = direct_item.addr_ack && direct_item.data_q.size() > 0 ?
            $sformatf("0x%02h", direct_item.data_q[0]) : "--";
        tbit_str = direct_item.addr_ack && direct_item.data_ack_q.size() > 0 ?
            $sformatf("%0b", direct_item.data_ack_q[0]) : "--";
        `uvm_info(
            `gfn,
            $sformatf(
                "CCC DATA: tid=0x%0h ccc=%s(0x%02h) target=0x%02h target_ack=%s event=%s t_bit=%s resp=%s",
                exp.tid, item.CCC.name(), 8'(exp.ccc), exp.ccc_target_addr, ack_to_string(
                direct_item.addr_ack), event_str, tbit_str, resp_status_to_string(resp_status)),
            UVM_LOW)
      end else if (!is_direct_ccc) begin
        ccc_name = item.CCC_valid ? item.CCC.name() : "?";
        event_str = item.addr_ack && item.data_q.size() > 0 ? $sformatf("0x%02h", item.data_q[0]) :
            "--";
        tbit_str = item.addr_ack && item.data_ack_q.size() > 0 ?
            $sformatf("%0b", item.data_ack_q[0]) : "--";
        `uvm_info(`gfn,
                  $sformatf(
                      "CCC DATA: tid=0x%0h ccc=%s(0x%02h) bcast_ack=%s event=%s t_bit=%s resp=%s",
                      exp.tid, ccc_name, 8'(exp.ccc), ack_to_string(item.addr_ack), event_str,
                      tbit_str, resp_status_to_string(resp_status)), UVM_LOW)
      end
    end
  endfunction

  function void check_read_data(i3c_item item, exp_txn_t exp, output bit expected_rstart,
                                output bit expected_stop, output bit txn_aborted);
    int                   read_id;
    i3c_resp_err_status_e resp_status;

    read_id = next_read_id++;
    resp_status = Success;
    txn_aborted = 1'b0;

    `DV_CHECK_EQ(item.addr, exp.addr, "Read target address mismatch")
    `DV_CHECK_EQ(item.bus_op, BusOpRead, "Read transfer direction mismatch")
    `DV_CHECK_LE(item.num_data, exp.data_length, "Read bus data byte count exceeds command length")
    `DV_CHECK_EQ(item.data_q.size(), item.num_data, "Read monitor data queue size mismatch")
    `DV_CHECK_EQ(item.data_ack_q.size(), item.num_data, $sformatf(
                 "Read monitor %s count mismatch", rx_ack_or_t_bit_label(exp.target_is_i3c)))

    check_read_ack_or_t_bits(item, exp);

    `uvm_info(`gfn, $sformatf("CHECK READ DATA"), UVM_MEDIUM)
    if (enqueue_rx_word_expectations(item, exp, read_id)) resp_status = Ovl;
    handle_read_end(item, exp, resp_status, expected_rstart, expected_stop, txn_aborted);
    record_pending_resp(1'b1, exp.tid, item.num_data, read_id, resp_status);
    `uvm_info(`gfn, $sformatf(
              "RX DATA: tid=0x%0h expected_len=%0d observed_len=%0d expected=%s observed=%s",
              exp.tid,
              exp.data_length,
              item.num_data,
              format_observed_bytes(
                  item.data_q, item.num_data
              ),
              format_observed_bytes(
                  item.data_q, item.num_data
              )
              ), UVM_LOW)
    `uvm_info(`gfn, $sformatf(
              "RX %s: tid=0x%0h expected_len=%0d observed_len=%0d expected=%s observed=%s",
              rx_ack_or_t_bit_label(
                  exp.target_is_i3c
              ),
              exp.tid,
              exp.data_length,
              item.data_ack_q.size(),
              format_expected_rx_ack_or_t_bits(
                  item, exp
              ),
              format_observed_t_bits(
                  item.data_ack_q, item.num_data
              )
              ), UVM_LOW)
  endfunction

  function void check_read_ack_or_t_bits(i3c_item item, exp_txn_t exp);
    for (int i = 0; i < item.num_data; i++) begin
      if (i < item.data_ack_q.size()) begin
        bit exp_bit;

        exp_bit = expected_rx_ack_or_t_bit(exp.target_is_i3c, item, i);
        `DV_CHECK_EQ(item.data_ack_q[i], exp_bit, $sformatf("Read bus %s[%0d] mismatch",
                                                            rx_ack_or_t_bit_label(exp.target_is_i3c
                                                            ), i))
      end
    end
  endfunction

  function bit enqueue_rx_word_expectations(i3c_item item, exp_txn_t exp, int read_id);
    bit rx_overflow;

    rx_overflow = 1'b0;
    for (int unsigned word_idx = 0; word_idx < ((item.num_data + 3) / 4); word_idx++) begin
      exp_rx_data_t rx_exp;

      build_rx_data_expectation(item, exp, read_id, word_idx, rx_exp);
      if (!rx_overflow && (exp_rx_data_queue.size() < RxFifoDepth)) begin
        exp_rx_data_queue.push_back(rx_exp);
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
    return rx_overflow;
  endfunction

  function void build_rx_data_expectation(i3c_item item, exp_txn_t exp, int read_id,
                                          int unsigned word_idx, output exp_rx_data_t rx_exp);
    rx_exp.known = 1'b1;
    rx_exp.read_id = read_id;
    rx_exp.tid = exp.tid;
    rx_exp.data_length = item.num_data;
    rx_exp.word_idx = int'(word_idx);
    rx_exp.valid_bytes = item.num_data - int'(word_idx * 4);
    if (rx_exp.valid_bytes > 4) rx_exp.valid_bytes = 4;
    rx_exp.data = '0;

    for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++) begin
      int unsigned data_idx;

      data_idx = (word_idx * 4) + byte_idx;
      if ((data_idx < item.num_data) && (data_idx < item.data_q.size())) begin
        rx_exp.data[(byte_idx*8)+:8] = item.data_q[data_idx];
      end
    end
  endfunction

  function void set_rx_fifo_level_unknown(int unsigned count, string ctxt = "");
    exp_rx_data_t unknown_entry;
    int unsigned  model_count;

    exp_rx_data_queue.delete();
    model_count = count;
    unknown_entry.known = 1'b0;
    unknown_entry.read_id = -1;
    unknown_entry.tid = '0;
    unknown_entry.data_length = 0;
    unknown_entry.word_idx = 0;
    unknown_entry.valid_bytes = 4;
    unknown_entry.data = '0;

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


  function void handle_read_end(i3c_item item, exp_txn_t exp, ref i3c_resp_err_status_e resp_status,
                                output bit expected_rstart, output bit expected_stop,
                                output bit txn_aborted);
    bit short_read;

    expected_rstart = 1'b0;
    expected_stop = 1'b0;
    txn_aborted = 1'b0;
    short_read = (item.num_data > 0) && (item.num_data < exp.data_length) &&
        !read_final_t_bit(item);

    `uvm_info(`gfn, $sformatf("READ END"), UVM_MEDIUM)
    if (hc_abort_active && item.stop) begin
      if (resp_status == Success) resp_status = HcAborted;
      expected_stop   = 1'b1;
      expected_rstart = read_final_t_bit(item);
      `DV_CHECK_EQ(item.stop, 1'b1, "HC-aborted read should end with STOP")
      `DV_CHECK_EQ(item.rstart, expected_rstart,
                   "HC-aborted read rstart should match final T-Bit takeover")
      txn_aborted = 1'b1;
      `uvm_info(
          `gfn,
          $sformatf(
              "READ END: tid=0x%0h cause=hc_abort resp=%s sent=%0d/%0d expected_rstart=%0b expected_stop=%0b",
              exp.tid, resp_status_to_string(resp_status), item.num_data, exp.data_length,
              expected_rstart, expected_stop), UVM_MEDIUM)
    end else if (short_read) begin
      if (resp_status == Success) resp_status = I3cShortReadErr;
      `DV_CHECK_EQ(item.stop, 1'b1, "Short read should end with STOP")
      expected_stop = 1'b1;
      `uvm_info(
          `gfn,
          $sformatf(
              "READ END: tid=0x%0h cause=short_read (T-bit=0 at byte %0d) resp=%s sent=%0d/%0d expected_stop=1",
              exp.tid, item.num_data, resp_status_to_string(resp_status), item.num_data,
              exp.data_length), UVM_MEDIUM)
    end else if (read_final_t_bit(item)) begin
      `DV_CHECK_EQ(item.rstart, 1'b1, "Controller read takeover should generate RSTART")
      `DV_CHECK_EQ(item.interrupted, 1'b1, "Controller read takeover should be marked interrupted")
      expected_rstart = 1'b1;
      if (resp_status == Ovl) begin
        `DV_CHECK_EQ(item.stop, 1'b1,
                     "Overflow read takeover should end with STOP regardless of toc")
        expected_stop = 1'b1;
        `uvm_info(
            `gfn,
            $sformatf(
                "READ END: tid=0x%0h cause=tbit_takeover+ovl resp=%s sent=%0d/%0d expected_rstart=1 expected_stop=1 (ovl overrides toc)",
                exp.tid, resp_status_to_string(resp_status), item.num_data, exp.data_length),
            UVM_MEDIUM)
      end else begin
        `DV_CHECK_EQ(item.stop, exp.toc, "Read takeover STOP should follow command toc")
        expected_stop = exp.toc;
        `uvm_info(`gfn, $sformatf(
                  "READ END: tid=0x%0h cause=tbit_takeover resp=%s sent=%0d/%0d expected_rstart=1 expected_stop=%0b (toc=%0b)",
                  exp.tid,
                  resp_status_to_string(
                      resp_status
                  ),
                  item.num_data,
                  exp.data_length,
                  expected_stop,
                  exp.toc
                  ), UVM_MEDIUM)
      end
    end else if (exp.toc) begin
      `DV_CHECK_EQ(item.stop, 1'b1, "Read with toc=1 should end with STOP")
      expected_stop = 1'b1;
      `uvm_info(`gfn, $sformatf(
                          "READ END: tid=0x%0h cause=toc_stop resp=%s sent=%0d/%0d expected_stop=1",
                          exp.tid, resp_status_to_string(resp_status), item.num_data,
                          exp.data_length), UVM_MEDIUM)
    end else if (resp_status == Ovl) begin
      `DV_CHECK_EQ(item.stop, 1'b1, "Overflow read (toc=0) should end with STOP, not continuation")
      expected_stop   = 1'b1;
      expected_rstart = item.rstart;
      `uvm_info(
          `gfn,
          $sformatf(
              "READ END: tid=0x%0h cause=ovl_toc0_override resp=%s sent=%0d/%0d expected_stop=1 (ovl overrides toc=0 continuation)",
              exp.tid, resp_status_to_string(resp_status), item.num_data, exp.data_length),
          UVM_MEDIUM)
    end else begin
      `DV_CHECK_EQ(item.rstart, 1'b1, "Read with toc=0 should end with RSTART")
      expected_rstart = 1'b1;
      `uvm_info(`gfn, $sformatf(
                "READ END: tid=0x%0h cause=toc0_continuation resp=%s sent=%0d/%0d expected_rstart=1",
                exp.tid,
                resp_status_to_string(
                    resp_status
                ),
                item.num_data,
                exp.data_length
                ), UVM_MEDIUM)
    end
  endfunction

  function bit read_final_t_bit(i3c_item item);
    if (item.data_ack_q.size() == 0) return 1'b0;
    return item.data_ack_q[item.data_ack_q.size()-1];
  endfunction

  function bit data_ack_q_has_nack(i3c_item item);
    for (int i = 0; i < item.data_ack_q.size(); i++) begin
      if (!item.data_ack_q[i]) return 1'b1;
    end
    return 1'b0;
  endfunction

  function bit check_write_data(i3c_item item, exp_txn_t exp);
    bit inferred_tx_underflow;
    bit inferred_hc_abort;
    bit inferred_data_nack;
    i3c_resp_err_status_e resp_status;

    inferred_tx_underflow = 1'b0;
    inferred_hc_abort     = 1'b0;
    inferred_data_nack    = 1'b0;

    if (exp.uses_tx_queue) begin
      if (item.num_data < exp.data_length) begin
        inferred_data_nack = !exp.target_is_i3c && data_ack_q_has_nack(item);
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
        inferred_data_nack = !exp.target_is_i3c && data_ack_q_has_nack(item);
        inferred_hc_abort  = !inferred_data_nack && hc_abort_active;
        check_tx_data_bytes(item, exp, exp.data_length, "TX", inferred_data_nack);
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
      record_pending_resp(1'b0, exp.tid, item.num_data, -1, resp_status);
    end

    return inferred_tx_underflow || inferred_hc_abort || inferred_data_nack;
  endfunction

  function bit check_immediate_write_data(i3c_item item, exp_txn_t exp);
    bit                   inferred_hc_abort;
    bit                   inferred_data_nack;
    i3c_resp_err_status_e resp_status;

    inferred_hc_abort  = 1'b0;
    inferred_data_nack = 1'b0;

    if (item.num_data < exp.data_length) begin
      inferred_data_nack = !exp.target_is_i3c && data_ack_q_has_nack(item);
      inferred_hc_abort  = !inferred_data_nack && hc_abort_active;
      if (!inferred_data_nack && !inferred_hc_abort)
        `uvm_error(`gfn, $sformatf(
                   "Immediate short write: observed=%0d requested=%0d with no HC abort (tid=0x%0h)",
                   item.num_data,
                   exp.data_length,
                   exp.tid
                   ))
    end else if (item.num_data == exp.data_length) begin
      inferred_data_nack = !exp.target_is_i3c && data_ack_q_has_nack(item);
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
      if (i < item.data_q.size())
        `DV_CHECK_EQ(item.data_q[i], exp.imm_data_byte[i], $sformatf(
                     "Immediate inline byte[%0d] mismatch (tid=0x%0h)", i, exp.tid))
      if (exp.target_is_i3c && (i < item.data_ack_q.size()))
        `DV_CHECK_EQ(item.data_ack_q[i], ~^exp.imm_data_byte[i], $sformatf(
                     "Immediate T-bit[%0d] mismatch (tid=0x%0h)", i, exp.tid))
    end

    if (!exp.toc) begin
      resp_status = NotSupported;
    end else begin
      resp_status = inferred_data_nack ? I2cDataNackOrI3cBusAborted :
                    inferred_hc_abort  ? HcAborted : Success;
    end
    record_pending_resp(1'b0, exp.tid, item.num_data, -1, resp_status);

    `uvm_info(`gfn, $sformatf(
              "IMM DATA: tid=0x%0h expected_len=%0d observed_len=%0d expected=%s observed=%s",
              exp.tid,
              exp.data_length,
              item.num_data,
              format_expected_imm_bytes(
                  exp, exp.data_length
              ),
              format_observed_bytes(
                  item.data_q, item.num_data
              )
              ), UVM_LOW)
    `uvm_info(`gfn, $sformatf(
              "IMM T-BIT: tid=0x%0h expected_len=%0d observed_len=%0d expected=%s observed=%s",
              exp.tid,
              exp.data_length,
              item.data_ack_q.size(),
              format_expected_imm_t_bits(
                  exp, exp.data_length
              ),
              format_observed_t_bits(
                  item.data_ack_q, item.num_data
              )
              ), UVM_LOW)
    if (!exp.toc)
      `uvm_info(`gfn, $sformatf(
                "IMM toc=0 REJECT: tid=0x%0h dtt=%0d - data phase completed, STOP + NotSupported",
                exp.tid,
                exp.data_length
                ), UVM_MEDIUM)

    return inferred_hc_abort || inferred_data_nack || !exp.toc;
  endfunction


  function int tx_fifo_available_bytes();
    return tx_data_queue.size() * 4;
  endfunction


  function void check_tx_data_bytes(i3c_item item, exp_txn_t exp, int data_length, string ctxt,
                                    bit allow_i2c_final_data_nack = 1'b0);
    `DV_CHECK_EQ(item.num_data, data_length, $sformatf(
                 "%s write byte count on bus does not match expected length", ctxt))
    `DV_CHECK_EQ(item.data_q.size(), data_length, $sformatf(
                 "%s write monitor captured the wrong number of data bytes", ctxt))
    `DV_CHECK_EQ(item.data_ack_q.size(), data_length, $sformatf(
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
        `DV_CHECK_EQ(item.data_q[i], exp_byte, $sformatf("%s data mismatch at byte[%0d]", ctxt, i))
        if (i < item.data_ack_q.size()) begin
          bit i2c_data_nack_byte;

          i2c_data_nack_byte = allow_i2c_final_data_nack && !exp.target_is_i3c &&
                               (i == (data_length - 1));
          `DV_CHECK_EQ(item.data_ack_q[i], expected_tx_ack_or_t_bit(exp.target_is_i3c, exp_byte,
                                                                    i2c_data_nack_byte),
                       $sformatf("%s %s mismatch at byte[%0d]", ctxt, tx_ack_or_t_bit_label(
                                 exp.target_is_i3c), i))
        end
      end
    end
    `uvm_info(`gfn, $sformatf(
              "TX DATA: tid=0x%0h expected_len=%0d observed_len=%0d expected=%s observed=%s",
              exp.tid,
              data_length,
              item.num_data,
              format_expected_tx_bytes(
                  data_length
              ),
              format_observed_bytes(
                  item.data_q, data_length
              )
              ), UVM_LOW)
    `uvm_info(`gfn, $sformatf(
              "TX %s: tid=0x%0h expected_len=%0d observed_len=%0d expected=%s observed=%s",
              tx_ack_or_t_bit_label(
                  exp.target_is_i3c
              ),
              exp.tid,
              data_length,
              item.data_ack_q.size(),
              format_expected_tx_ack_or_t_bits(
                  data_length, exp.target_is_i3c, allow_i2c_final_data_nack
              ),
              format_observed_t_bits(
                  item.data_ack_q, data_length
              )
              ), UVM_LOW)
  endfunction

  function void check_short_write_tx_data(i3c_item item, exp_txn_t exp, string cause,
                                          bit allow_i2c_final_data_nack = 1'b0);
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

  function void consume_tx_data_words(int data_len);
    int words_used = (data_len + 3) / 4;
    repeat (words_used) begin
      if (tx_data_queue.size() > 0) void'(tx_data_queue.pop_front());
    end
  endfunction

  function bit tx_data_matches_at(i3c_item item, int word_offset);
    foreach (item.data_q[i]) begin
      int word_idx = word_offset + (i / 4);
      int byte_off = (i % 4) * 8;

      if (word_idx >= tx_data_queue.size()) return 1'b0;
      if (item.data_q[i] != tx_data_queue[word_idx][byte_off+:8]) return 1'b0;
    end
    return 1'b1;
  endfunction

  function void check_phase(uvm_phase phase);
    int unobserved_count;

    unobserved_count = 0;
    foreach (exp_txn_queue[i]) begin
      unobserved_count++;
    end
    if (unobserved_count > 0)
      `uvm_error(`gfn, $sformatf(
                 "%0d expected command(s) never observed on I3C bus", unobserved_count))
    if (tx_data_queue.size() > 0)
      `uvm_error(`gfn, $sformatf("%0d TX data word(s) unconsumed", tx_data_queue.size()))
    if (pending_resp_queue.size() > 0)
      `uvm_error(`gfn, $sformatf(
                 "%0d pending response model item(s) were not observed", pending_resp_queue.size()))
    if (exp_rx_data_queue.size() > 0)
      `uvm_error(`gfn, $sformatf(
                 "%0d expected RX data word(s) were not observed", exp_rx_data_queue.size()))
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(reg_seq_item, reg_fifo)
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(i3c_item, i3c_fifo)
  endfunction

  function bit is_enec_disec_ccc(bit [7:0] cmd);
    return (cmd == ENEC) || (cmd == DISEC) || (cmd == DIR_ENEC) || (cmd == DIR_DISEC);
  endfunction

  function bit [6:0] get_device_addr(bit [4:0] dev_idx);
    if ((dev_idx < DAT_DEPTH) && dat_model[dev_idx].valid) begin
      if (dat_model[dev_idx].device) return dat_model[dev_idx].static_address;
      return dat_model[dev_idx].dynamic_address;
    end
    if (dev_idx == 0 && cfg != null) return cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr;
    `uvm_warning(`gfn, $sformatf("get_device_addr: unresolved dev_idx=%0d", dev_idx))
    return 7'h00;
  endfunction

  function bit is_i3c_device(bit [4:0] dev_idx);
    if ((dev_idx < DAT_DEPTH) && dat_model[dev_idx].valid) return !dat_model[dev_idx].device;
    if (dev_idx == 0 && cfg != null) return cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr_valid;
    return 1'b0;
  endfunction

  function void update_private_continuation(exp_txn_t exp, bit aborted = 1'b0);
    if (exp.updates_private_continuation && !exp.is_ccc && !aborted) begin
      pending_private_continuation = !exp.toc;
    end else begin
      pending_private_continuation = 1'b0;
    end
  endfunction

  function int tx_words_for_len(int data_len);
    return (data_len + 3) / 4;
  endfunction

endclass : i3c_scoreboard
