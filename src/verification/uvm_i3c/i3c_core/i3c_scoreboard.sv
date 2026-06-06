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
  } exp_txn_t;

  typedef struct {
    bit       valid;
    bit       device;
    bit [6:0] static_address;
    bit [6:0] dynamic_address;
  } dat_model_entry_t;

  exp_txn_t         exp_txn_queue[$];  // pending expected I3C transactions
  bit        [31:0] tx_data_queue[$];  // TX data words written to ADDR_TX_DATA
  dat_model_entry_t dat_model[DAT_DEPTH];

  bit              got_dw0;
  bit       [31:0] cmd_dw0;

  int              pass_cnt;
  int              fail_cnt;

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
            ADDR_HC_CONTROL: if (item.wdata[HC_CTRL_SW_RESET_BIT]) handle_sw_reset();
            ADDR_CMD_QUEUE: handle_cmd_dword(item.wdata);
            ADDR_TX_DATA: tx_data_queue.push_back(item.wdata);
            default: ;
          endcase
        end
      end else begin
        if (item.addr == ADDR_RESP) check_resp(item.rdata);
      end
    end
  endtask

  function void handle_sw_reset();
    exp_txn_queue.delete();
    tx_data_queue.delete();
    got_dw0 = 1'b0;
    cmd_dw0 = '0;
    `uvm_info(`gfn, "SW_RESET observed: scoreboard queues flushed", UVM_MEDIUM)
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

      exp.tid  = tid;
      exp.toc  = cmd_dw0[31];
      exp.addr = get_device_addr(dev_idx);
      exp.is_ccc = 1'b0;
      exp.uses_tx_queue = 1'b0;
      exp.is_immediate = 1'b0;
      exp.ccc = cmd;
      exp.event_byte = wdata[7:0];

      case (attr)
        RegularTransfer: begin
          exp.rnw         = rnw;
          exp.data_length = int'(wdata[31:16]);
          exp.uses_tx_queue = !rnw;
        end
        ImmediateDataTransfer: begin
          exp.is_immediate = 1'b1;
          if (cp && is_broadcast_enec_disec(cmd)) begin
            exp.addr        = 7'h7e;
            exp.rnw         = 1'b0;
            exp.data_length = 1;
            exp.is_ccc      = 1'b1;
          end else begin
            exp.rnw         = rnw;
            exp.data_length = int'(cmd_dw0[25:23]);
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
        `uvm_info(`gfn, $sformatf(
                  "CMD queued: attr=%s CCC=0x%02h addr=0x%02h event=0x%02h len=%0d toc=%0b",
                  attr.name(),
                  exp.ccc,
                  exp.addr,
                  exp.event_byte,
                  exp.data_length,
                  exp.toc
                  ), UVM_MEDIUM)
      end else begin
        `uvm_info(`gfn, $sformatf(
                  "CMD queued: attr=%s dev_idx=%0d addr=0x%02h rnw=%0b len=%0d toc=%0b",
                  attr.name(),
                  dev_idx,
                  exp.addr,
                  exp.rnw,
                  exp.data_length,
                  exp.toc
                  ), UVM_MEDIUM)
      end
      got_dw0 = 1'b0;
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

  function void check_resp(bit [31:0] rdata);
    if (rdata[31:28] == 4'b0000) begin
      `uvm_info(`gfn, $sformatf("RESP OK: tid=0x%0h data_length=%0d", rdata[27:24], rdata[15:0]),
                UVM_MEDIUM)
      pass_cnt++;
    end else if (rdata[31:28] == 4'h4) begin
      `uvm_info(`gfn, $sformatf(
                "RESP AddrHeader: tid=0x%0h data_length=%0d rdata=0x%08h",
                rdata[27:24],
                rdata[15:0],
                rdata
                ), UVM_MEDIUM)
      pass_cnt++;
    end else begin
      `uvm_error(`gfn, $sformatf("RESP error: err_status=0x%0h rdata=0x%08h", rdata[31:28], rdata))
      fail_cnt++;
    end
  endfunction

  // I3C bus side: compare observed transaction vs expected
  task process_i3c_items();
    i3c_item item;
    forever begin
      i3c_fifo.get(item);
      if (item.i3c_empty_broadcast) continue;
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
      pass_cnt++;
      return;
    end

    `DV_CHECK_EQ(item.addr, exp.addr, "Target address mismatch")
    `DV_CHECK_EQ(item.bus_op, exp.rnw ? BusOpRead : BusOpWrite, "Transfer direction mismatch")

    if (!item.addr_ack) begin
      if (!exp.rnw && exp.uses_tx_queue && exp.data_length > 0) consume_tx_data_words(1);
      pass_cnt++;
      return;
    end

    if (!exp.rnw && exp.uses_tx_queue) check_tx_data(item);

    pass_cnt++;
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

  // Verify write data bytes match queued TX FIFO words (little-endian byte order).
  function void check_tx_data(i3c_item item);
    foreach (item.data_q[i]) begin
      int word_idx = i / 4;
      int byte_off = (i % 4) * 8;
      if (word_idx < tx_data_queue.size()) begin
        bit [7:0] exp_byte = tx_data_queue[word_idx][byte_off+:8];
        `DV_CHECK_EQ(item.data_q[i], exp_byte, $sformatf("TX data mismatch at byte[%0d]", i))
      end
    end
    consume_tx_data_words(item.num_data);
  endfunction

  function void consume_tx_data_words(int data_len);
    int words_used = (data_len + 3) / 4;
    repeat (words_used) begin
      if (tx_data_queue.size() > 0) void'(tx_data_queue.pop_front());
    end
  endfunction

  function int tx_words_for_len(int data_len);
    return (data_len + 3) / 4;
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

  function int find_matching_exp_idx(i3c_item item);
    int       word_offset;
    exp_txn_t exp;

    word_offset = 0;
    foreach (exp_txn_queue[i]) begin
      exp = exp_txn_queue[i];
      if ((item.addr == exp.addr) &&
          (item.bus_op == (exp.rnw ? BusOpRead : BusOpWrite)) &&
          (exp.rnw || exp.is_ccc || !exp.uses_tx_queue || tx_data_matches_at(item, word_offset))) begin
        return int'(i);
      end
      if (!exp.rnw && exp.uses_tx_queue) word_offset += tx_words_for_len(exp.data_length);
    end
    return -1;
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
    `uvm_info(`gfn, $sformatf("Scoreboard: pass=%0d fail=%0d", pass_cnt, fail_cnt), UVM_LOW)
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(reg_seq_item, reg_fifo)
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(i3c_item, i3c_fifo)
  endfunction

endclass : i3c_scoreboard
