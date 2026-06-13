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
    bit [7:0] event_byte;
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
    bit [3:0]  err_status;
    bit [3:0]  tid;
    bit [15:0] data_length;
  } exp_resp_err_t;

  typedef struct {
    bit [6:0] addr;
    bit [3:0] tid;
    int       requested_length;
    int       data_length;
    bit       continue_t_bit;
    bit       final_t_bit;
    bit [7:0] data[$];
  } exp_read_data_t;

  exp_txn_t exp_txn_queue[$];
  bit [31:0] tx_data_queue[$];
  exp_resp_err_t exp_resp_err_queue[$];
  exp_resp_err_t exp_resp_err_history[$];
  exp_read_data_t exp_read_data_queue[$];
  bit [31:0] exp_rx_data_queue[$];
  dat_model_entry_t dat_model[DAT_DEPTH];

  bit got_dw0;
  bit [31:0] cmd_dw0;
  bit broadcast_header_enable;
  bit pending_private_continuation;

  int pass_cnt;
  int fail_cnt;

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

  // Register-side: track CMD writes, TX data, RESP reads
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

  function void handle_sw_reset();
    exp_txn_queue.delete();
    tx_data_queue.delete();
    exp_resp_err_queue.delete();
    exp_resp_err_history.delete();
    exp_read_data_queue.delete();
    exp_rx_data_queue.delete();
    got_dw0 = 1'b0;
    cmd_dw0 = '0;
    pending_private_continuation = 1'b0;
    `uvm_info(`gfn, "SW_RESET observed: scoreboard queues flushed", UVM_MEDIUM)
  endfunction

  function void handle_hc_control_write(bit [31:0] wdata);
    broadcast_header_enable = wdata[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT];
    if (wdata[HC_CTRL_SW_RESET_BIT]) handle_sw_reset();
  endfunction

  function void handle_dat_write(bit [11:0] addr, bit [31:0] wdata);
    int unsigned idx;

    idx = (addr - ADDR_DAT_BASE) >> 2;
    if (idx >= DAT_DEPTH) begin
      `uvm_warning(`gfn, $sformatf("DAT write ignored: addr=0x%03h idx=%0d", addr, idx))
      return;
    end

    dat_model[idx].valid           = 1'b1;
    dat_model[idx].device          = wdata[31];
    dat_model[idx].dynamic_address = wdata[22:16];
    dat_model[idx].static_address  = wdata[6:0];
    `uvm_info(`gfn, $sformatf(
              "DAT[%0d] updated: device=%0b static=0x%02h dynamic=0x%02h",
              idx,
              dat_model[idx].device,
              dat_model[idx].static_address,
              dat_model[idx].dynamic_address
              ), UVM_MEDIUM)
  endfunction

  // Accumulate two DWORDs then decode the full 64-bit command descriptor.
  // DWORD 0 bit layout (common fields):
  //   [2:0]   attr    — i3c_cmd_attr_e
  //   [6:3]   tid
  //   [14:7]  cmd
  //   [15]    cp
  //   [20:16] dev_idx
  //   [29]    rnw     (Regular / Immediate / Combo only)
  // DWORD 1 for RegularTransfer: [31:16] = data_length
  // DWORD 0 for ImmediateDataTransfer: [25:23] = dtt (byte count)
  function void handle_cmd_dword(bit [31:0] wdata);
    if (!got_dw0) begin
      cmd_dw0 = wdata;
      got_dw0 = 1'b1;
    end else begin
      exp_txn_t            exp;
      i3c_cmd_attr_e       attr = i3c_cmd_attr_e'(cmd_dw0[2:0]);
      bit            [3:0] tid = cmd_dw0[6:3];
      bit            [7:0] cmd = cmd_dw0[14:7];
      bit                  cp = cmd_dw0[15];
      bit            [4:0] dev_idx = cmd_dw0[20:16];
      bit                  rnw = cmd_dw0[29];
      bit                  target_is_i3c = is_i3c_device(dev_idx);

      exp.tid = tid;
      exp.toc = cmd_dw0[31];
      exp.addr = get_device_addr(dev_idx);
      exp.is_ccc = 1'b0;
      exp.uses_tx_queue = 1'b0;
      exp.is_immediate = 1'b0;
      exp.ccc = cmd;
      exp.event_byte = wdata[7:0];
      exp.target_is_i3c = target_is_i3c;
      exp.broadcast_header_eligible = 1'b0;
      exp.updates_private_continuation = 1'b0;
      exp.start_with_broadcast_header = 1'b0;

      case (attr)
        RegularTransfer: begin
          exp.rnw = rnw;
          exp.data_length = int'(wdata[31:16]);
          exp.uses_tx_queue = !rnw;
          exp.broadcast_header_eligible = target_is_i3c;
          exp.updates_private_continuation = target_is_i3c;
        end
        ImmediateDataTransfer: begin
          exp.is_immediate = 1'b1;
          if (cp && is_broadcast_enec_disec(cmd)) begin
            exp.addr        = 7'h7e;
            exp.rnw         = 1'b0;
            exp.data_length = 1;
            exp.is_ccc      = 1'b1;
          end else begin
            exp.rnw = rnw;
            exp.data_length = int'(cmd_dw0[25:23]);
            exp.broadcast_header_eligible = !cp && target_is_i3c;
          end
        end
        AddressAssignment: begin
          exp.rnw         = 1'b0;
          exp.data_length = 0;
        end
        default: begin
          exp.rnw         = rnw;
          exp.data_length = 0;
        end
      endcase

      exp_txn_queue.push_back(exp);
      if (exp.is_ccc) begin
        `uvm_info(`gfn,
                  $sformatf(
                      "CMD queued: attr=%s CCC=0x%02h addr=0x%02h event=0x%02h len=%0d toc=%0b",
                      attr.name(), exp.ccc, exp.addr, exp.event_byte, exp.data_length, exp.toc),
                  UVM_MEDIUM)
      end else begin
        `uvm_info(`gfn, $sformatf(
                  "CMD queued: attr=%s dev_idx=%0d addr=0x%02h rnw=%0b len=%0d toc=%0b target_i3c=%0b",
                  attr.name(),
                  dev_idx,
                  exp.addr,
                  exp.rnw,
                  exp.data_length,
                  exp.toc,
                  exp.target_is_i3c
                  ), UVM_MEDIUM)
      end
      got_dw0 = 1'b0;
    end
  endfunction

  function void expect_resp_error(bit [3:0] err_status, bit [3:0] tid, bit [15:0] data_length);
    exp_resp_err_t exp;

    exp.err_status  = err_status;
    exp.tid         = tid;
    exp.data_length = data_length;
    exp_resp_err_queue.push_back(exp);
    exp_resp_err_history.push_back(exp);
  endfunction

  function void expect_read_data(
      input bit [6:0] addr, input bit [3:0] tid, input int unsigned requested_length,
      input int unsigned data_length, input bit [7:0] data[$], input bit continue_t_bit,
      input bit final_t_bit = 1'b0, input bit expect_rx_fifo = 1'b1);
    exp_read_data_t        exp;
    bit             [31:0] rx_word;

    exp.addr             = addr;
    exp.tid              = tid;
    exp.requested_length = int'(requested_length);
    exp.data_length      = int'(data_length);
    exp.continue_t_bit   = continue_t_bit;
    exp.final_t_bit      = final_t_bit;
    exp.data             = data;
    exp_read_data_queue.push_back(exp);

    if (expect_rx_fifo) begin
      for (int unsigned word_idx = 0; word_idx < ((data_length + 3) / 4); word_idx++) begin
        rx_word = '0;
        for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++) begin
          int unsigned data_idx;

          data_idx = (word_idx * 4) + byte_idx;
          if ((data_idx < data_length) && (data_idx < data.size())) begin
            rx_word[(byte_idx*8)+:8] = data[data_idx];
          end
        end
        exp_rx_data_queue.push_back(rx_word);
      end
    end
  endfunction

  function bit is_broadcast_enec_disec(bit [7:0] cmd);
    return (cmd == ENEC) || (cmd == DISEC);
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

  function void update_expected_preamble(ref exp_txn_t exp);
    exp.start_with_broadcast_header =
        exp.broadcast_header_eligible && broadcast_header_enable && !pending_private_continuation;
  endfunction

  function void update_private_continuation(exp_txn_t exp);
    if (exp.updates_private_continuation && !exp.is_ccc && !tx_underflow_expected(exp)) begin
      pending_private_continuation = !exp.toc;
    end else begin
      pending_private_continuation = 1'b0;
    end
  endfunction

  function void check_resp(bit [31:0] rdata);
    if (rdata[31:28] == 4'b0000) begin
      `uvm_info(`gfn, $sformatf("RESP OK: tid=0x%0h data_length=%0d", rdata[27:24], rdata[15:0]),
                UVM_MEDIUM)
      pass_cnt++;
    end else if (resp_error_expected(rdata)) begin
      `uvm_info(`gfn,
                $sformatf(
                    "RESP expected error: err_status=0x%0h tid=0x%0h data_length=%0d rdata=0x%08h",
                    rdata[31:28], rdata[27:24], rdata[15:0], rdata), UVM_MEDIUM)
      pass_cnt++;
    end else begin
      `uvm_error(`gfn, $sformatf("RESP error: err_status=0x%0h rdata=0x%08h", rdata[31:28], rdata))
      fail_cnt++;
    end
  endfunction

  function bit resp_error_expected(bit [31:0] rdata);
    exp_resp_err_t exp;

    if (exp_resp_err_queue.size() == 0) return 1'b0;

    exp = exp_resp_err_queue[0];
    if ((rdata[31:28] == exp.err_status) &&
        (rdata[27:24] == exp.tid) &&
        (rdata[15:0] == exp.data_length)) begin
      void'(exp_resp_err_queue.pop_front());
      return 1'b1;
    end

    return 1'b0;
  endfunction

  // I3C bus side: compare observed transaction vs expected
  task process_i3c_items();
    i3c_item item;
    forever begin
      i3c_fifo.get(item);
      if (item.i3c_empty_broadcast) begin
        `uvm_error(`gfn, "Monitor emitted an empty broadcast header instead of a full transaction")
        fail_cnt++;
        continue;
      end
      check_i3c_txn(item);
    end
  endtask

  function void check_i3c_txn(i3c_item item);
    exp_txn_t exp;

    if (exp_txn_queue.size() == 0) begin
      `uvm_error(`gfn, $sformatf("Unexpected I3C txn: addr=0x%02h op=%s", item.addr,
                                 item.bus_op.name()))
      fail_cnt++;
      return;
    end

    begin
      int match_idx;

      match_idx = find_matching_exp_idx(item);
      if (match_idx < 0) match_idx = 0;

      repeat (match_idx) begin
        exp = exp_txn_queue.pop_front();
        if (!exp.rnw && exp.uses_tx_queue) consume_tx_data_words(exp.data_length);
        update_private_continuation(exp);
        `uvm_info(`gfn, $sformatf(
                  "Skipping unobserved expected command before monitored transaction: addr=0x%02h rnw=%0b len=%0d toc=%0b",
                  exp.addr,
                  exp.rnw,
                  exp.data_length,
                  exp.toc
                  ), UVM_MEDIUM)
      end
    end

    exp = exp_txn_queue.pop_front();

    if (exp.is_ccc) begin
      check_ccc_txn(item, exp);
      update_private_continuation(exp);
      pass_cnt++;
      return;
    end

    update_expected_preamble(exp);
    `DV_CHECK_EQ(item.addr, exp.addr, "Target address mismatch")
    `DV_CHECK_EQ(item.bus_op, exp.rnw ? BusOpRead : BusOpWrite, "Transfer direction mismatch")
    `DV_CHECK_EQ(item.start_with_broadcast_header, exp.start_with_broadcast_header,
                 "Broadcast header preamble mismatch")
    if (item.start_with_broadcast_header || exp.start_with_broadcast_header) begin
      `DV_CHECK_EQ(item.broadcast_header_ack, 1'b1, "Broadcast header preamble was not ACKed")
    end

    if (!item.addr_ack) begin
      if (!exp.rnw && exp.uses_tx_queue && exp.data_length > 0) consume_tx_data_words(1);
      update_private_continuation(exp);
      pass_cnt++;
      return;
    end

    if (exp.rnw) begin
      check_read_data(item, exp);
    end else if (exp.uses_tx_queue) begin
      if (tx_underflow_expected(exp)) begin
        check_underflow_tx_data(item, exp);
      end else begin
        check_tx_data(item, exp);
      end
    end

    update_private_continuation(exp);
    pass_cnt++;
  endfunction

  function int find_matching_exp_idx(i3c_item item);
    int       word_offset;
    exp_txn_t exp;

    word_offset = 0;
    foreach (exp_txn_queue[i]) begin
      exp = exp_txn_queue[i];
      if ((item.addr == exp.addr) &&
          (item.bus_op == (exp.rnw ? BusOpRead : BusOpWrite)) &&
          (exp.rnw || exp.is_ccc || !exp.uses_tx_queue || tx_data_matches_at(
              item, word_offset
          ))) begin
        return int'(i);
      end
      if (!exp.rnw && exp.uses_tx_queue) word_offset += tx_words_for_len(exp.data_length);
    end
    return -1;
  endfunction

  function int tx_words_for_len(int data_len);
    return (data_len + 3) / 4;
  endfunction

  function void check_ccc_txn(i3c_item item, exp_txn_t exp);
    `DV_CHECK_EQ(item.addr, exp.addr, "CCC broadcast address mismatch")
    `DV_CHECK_EQ(item.bus_op, BusOpWrite, "CCC broadcast direction mismatch")
    `DV_CHECK_EQ(item.addr_ack, 1'b1, "CCC broadcast header was not ACKed")
    `DV_CHECK_EQ(item.CCC_valid, 1'b1, "CCC opcode was not decoded")
    `DV_CHECK_EQ(item.CCC, i3c_ccc_e'(exp.ccc), "CCC opcode mismatch")
    `DV_CHECK_EQ(item.num_data, exp.data_length, "CCC event byte count mismatch")
    if (item.data_q.size() > 0) begin
      `DV_CHECK_EQ(item.data_q[0], exp.event_byte, "CCC event byte mismatch")
    end else begin
      `uvm_error(`gfn, "CCC event byte missing")
      fail_cnt++;
    end
    if (item.data_ack_q.size() > 0) begin
      `DV_CHECK_EQ(item.data_ack_q[0], ~^exp.event_byte, "CCC event byte T-bit mismatch")
    end else begin
      `uvm_error(`gfn, "CCC event byte T-bit missing")
      fail_cnt++;
    end
    `DV_CHECK_EQ(item.CCC_direct.size(), 0, "Broadcast CCC should not include a direct phase")
    `DV_CHECK_EQ(item.stop, 1'b1, "Broadcast CCC should end with STOP")
  endfunction

  // Verify read data bytes and target T-bit sequence when a vseq provides expected read data.
  function void check_read_data(i3c_item item, exp_txn_t exp);
    exp_read_data_t read_exp;
    bit             complete_to_requested;
    bit             controller_takeover;

    if (exp_read_data_queue.size() == 0) return;

    read_exp = exp_read_data_queue.pop_front();
    complete_to_requested = read_exp.data_length == read_exp.requested_length;
    controller_takeover = complete_to_requested && read_exp.final_t_bit;

    `DV_CHECK_EQ(read_exp.addr, exp.addr, "Read expectation target address mismatch")
    `DV_CHECK_EQ(read_exp.tid, exp.tid, "Read expectation TID mismatch")
    `DV_CHECK_EQ(read_exp.requested_length, exp.data_length,
                 "Read expectation requested length mismatch")
    `DV_CHECK_LE(read_exp.data_length, read_exp.requested_length,
                 "Read expectation actual length exceeds requested length")
    `DV_CHECK_EQ(read_exp.data.size(), read_exp.data_length,
                 "Read expectation data byte count mismatch")

    `DV_CHECK_EQ(item.num_data, read_exp.data_length, "Read bus data byte count mismatch")
    `DV_CHECK_EQ(item.data_q.size(), read_exp.data_length, "Read monitor data queue size mismatch")
    `DV_CHECK_EQ(item.data_ack_q.size(), read_exp.data_length, "Read monitor T-bit count mismatch")

    for (int i = 0; i < read_exp.data_length; i++) begin
      if ((i < item.data_q.size()) && (i < read_exp.data.size())) begin
        `DV_CHECK_EQ(item.data_q[i], read_exp.data[i], $sformatf(
                                                           "Read bus data byte[%0d] mismatch", i))
      end
      if (i < item.data_ack_q.size()) begin
        bit exp_t_bit;

        exp_t_bit = (i == (read_exp.data_length - 1)) ? read_exp.final_t_bit :
                                                        read_exp.continue_t_bit;
        `DV_CHECK_EQ(item.data_ack_q[i], exp_t_bit, $sformatf("Read bus T-bit[%0d] mismatch", i))
      end
    end

    if (controller_takeover) begin
      `DV_CHECK_EQ(item.rstart, 1'b1, "Controller read takeover should end with RSTART")
      `DV_CHECK_EQ(item.interrupted, 1'b1, "Controller read takeover should be marked interrupted")
    end else if (complete_to_requested) begin
      if (exp.toc) begin
        `DV_CHECK_EQ(item.stop, 1'b1, "Completed read with toc=1 should end with STOP")
      end else begin
        `DV_CHECK_EQ(item.rstart, 1'b1, "Completed read with toc=0 should end with RSTART")
      end
    end
  endfunction

  function void check_rx_data(bit [31:0] rdata);
    bit [31:0] exp_data;

    if (exp_rx_data_queue.size() == 0) return;

    exp_data = exp_rx_data_queue.pop_front();
    `DV_CHECK_EQ(rdata, exp_data, "RX FIFO data mismatch")
    `uvm_info(`gfn, $sformatf("RX FIFO data OK: rdata=0x%08h", rdata), UVM_MEDIUM)
  endfunction

  function void check_tx_data(i3c_item item, exp_txn_t exp);
    `DV_CHECK_EQ(item.num_data, exp.data_length, "Write bus data byte count mismatch")
    `DV_CHECK_EQ(item.data_q.size(), exp.data_length, "Write monitor data queue size mismatch")
    `DV_CHECK_EQ(item.data_ack_q.size(), exp.data_length, "Write monitor T-bit count mismatch")
    foreach (item.data_q[i]) begin
      int word_idx = i / 4;
      int byte_off = (i % 4) * 8;
      if (word_idx < tx_data_queue.size()) begin
        bit [7:0] exp_byte = tx_data_queue[word_idx][byte_off+:8];
        `DV_CHECK_EQ(item.data_q[i], exp_byte, $sformatf("TX data mismatch at byte[%0d]", i))
        if (i < item.data_ack_q.size()) begin
          `DV_CHECK_EQ(item.data_ack_q[i], ~^exp_byte, $sformatf("TX T-bit mismatch at byte[%0d]",
                                                                 i))
        end
      end
    end
    consume_tx_data_words(exp.data_length);
  endfunction

  function bit tx_underflow_expected(exp_txn_t exp);
    return tx_underflow_actual_length(exp) >= 0;
  endfunction

  function int tx_underflow_actual_length(exp_txn_t exp);
    exp_resp_err_t exp_resp;

    if (exp.rnw || !exp.uses_tx_queue) return -1;

    foreach (exp_resp_err_queue[i]) begin
      exp_resp = exp_resp_err_queue[i];
      if ((exp_resp.err_status == 4'h6) &&
          (exp_resp.tid == exp.tid) &&
          (exp_resp.data_length <= exp.data_length)) begin
        return int'(exp_resp.data_length);
      end
    end

    foreach (exp_resp_err_history[i]) begin
      exp_resp = exp_resp_err_history[i];
      if ((exp_resp.err_status == 4'h6) &&
          (exp_resp.tid == exp.tid) &&
          (exp_resp.data_length <= exp.data_length)) begin
        return int'(exp_resp.data_length);
      end
    end

    return -1;
  endfunction

  function void check_underflow_tx_data(i3c_item item, exp_txn_t exp);
    int actual_data_length;

    actual_data_length = tx_underflow_actual_length(exp);
    `DV_CHECK_EQ(item.num_data, actual_data_length, "Underflow write bus data byte count mismatch")
    `DV_CHECK_EQ(item.data_q.size(), actual_data_length,
                 "Underflow write monitor data queue size mismatch")
    `DV_CHECK_EQ(item.data_ack_q.size(), actual_data_length,
                 "Underflow write monitor T-bit count mismatch")
    foreach (item.data_q[i]) begin
      int word_idx = i / 4;
      int byte_off = (i % 4) * 8;
      if (word_idx < tx_data_queue.size()) begin
        bit [7:0] exp_byte = tx_data_queue[word_idx][byte_off+:8];
        `DV_CHECK_EQ(item.data_q[i], exp_byte, $sformatf("Underflow TX data mismatch at byte[%0d]",
                                                         i))
        if (i < item.data_ack_q.size()) begin
          `DV_CHECK_EQ(item.data_ack_q[i], ~^exp_byte,
                       $sformatf("Underflow TX T-bit mismatch at byte[%0d]", i))
        end
      end
    end
    consume_tx_data_words(actual_data_length);
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

  // End-of-test: verify all expected transactions were observed
  function void check_phase(uvm_phase phase);
    int unobserved_count;

    unobserved_count = 0;
    foreach (exp_txn_queue[i]) begin
      if (!(exp_txn_queue[i].is_immediate && !exp_txn_queue[i].is_ccc)) begin
        unobserved_count++;
      end
    end
    if (unobserved_count > 0)
      `uvm_error(`gfn, $sformatf(
                 "%0d expected command(s) never observed on I3C bus", unobserved_count))
    if (tx_data_queue.size() > 0)
      `uvm_error(`gfn, $sformatf("%0d TX data word(s) unconsumed", tx_data_queue.size()))
    if (exp_resp_err_queue.size() > 0)
      `uvm_error(`gfn, $sformatf(
                 "%0d expected response error(s) were not observed", exp_resp_err_queue.size()))
    if (exp_read_data_queue.size() > 0)
      `uvm_error(`gfn, $sformatf(
                 "%0d expected read data item(s) were not observed", exp_read_data_queue.size()))
    if (exp_rx_data_queue.size() > 0)
      `uvm_error(`gfn, $sformatf(
                 "%0d expected RX data word(s) were not observed", exp_rx_data_queue.size()))
    `uvm_info(`gfn, $sformatf("Scoreboard: pass=%0d fail=%0d", pass_cnt, fail_cnt), UVM_LOW)
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(reg_seq_item, reg_fifo)
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(i3c_item, i3c_fifo)
  endfunction

endclass : i3c_scoreboard
