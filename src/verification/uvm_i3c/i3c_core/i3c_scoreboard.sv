class i3c_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(i3c_scoreboard)

  i3c_env_cfg cfg;

  // Analysis FIFOs — names match i3c_env connect_phase connections
  uvm_tlm_analysis_fifo #(reg_seq_item) reg_fifo;
  uvm_tlm_analysis_fifo #(i3c_item)     i3c_fifo;

  // Expected I3C transaction, built from CMD FIFO writes
  typedef struct {
    bit [6:0] addr;
    bit       rnw;
    int       data_length;
    bit [3:0] tid;
  } exp_txn_t;

  exp_txn_t  exp_txn_queue[$];   // pending expected I3C transactions
  bit [31:0] tx_data_queue[$];   // TX data words written to ADDR_TX_DATA

  // CMD FIFO accumulator: two 32-bit DWORDs per command
  bit        got_dw0;
  bit [31:0] cmd_dw0;

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

  // ----------------------------------------------------------------
  // Register-side: track CMD writes, TX data, RESP reads
  // ----------------------------------------------------------------
  task process_req_items();
    reg_seq_item item;
    forever begin
      reg_fifo.get(item);
      if (item.is_write) begin
        case (item.addr)
          ADDR_CMD_QUEUE: handle_cmd_dword(item.wdata);
          ADDR_TX_DATA:   tx_data_queue.push_back(item.wdata);
          default: ;
        endcase
      end else begin
        if (item.addr == ADDR_RESP) check_resp(item.rdata);
      end
    end
  endtask

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
      exp_txn_t      exp;
      i3c_cmd_attr_e attr    = i3c_cmd_attr_e'(cmd_dw0[2:0]);
      bit [3:0]      tid     = cmd_dw0[6:3];
      bit [4:0]      dev_idx = cmd_dw0[20:16];
      bit            rnw     = cmd_dw0[29];

      exp.tid  = tid;
      exp.addr = get_device_addr(dev_idx);

      case (attr)
        RegularTransfer: begin
          exp.rnw         = rnw;
          exp.data_length = int'(wdata[31:16]);
        end
        ImmediateDataTransfer: begin
          exp.rnw         = rnw;
          exp.data_length = int'(cmd_dw0[25:23]);
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
      `uvm_info(`gfn, $sformatf("CMD queued: attr=%s dev_idx=%0d addr=0x%02h rnw=%0b len=%0d",
                attr.name(), dev_idx, exp.addr, exp.rnw, exp.data_length), UVM_MEDIUM)
      got_dw0 = 1'b0;
    end
  endfunction

  // Resolve dev_idx to dynamic address via cfg.
  // Phase 1: single device only (dev_idx == 0).
  function bit [6:0] get_device_addr(bit [4:0] dev_idx);
    if (dev_idx == 0 && cfg != null)
      return cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr;
    `uvm_warning(`gfn, $sformatf("get_device_addr: unresolved dev_idx=%0d", dev_idx))
    return 7'h00;
  endfunction

  function void check_resp(bit [31:0] rdata);
    if (rdata[31:28] != 4'b0000) begin
      `uvm_error(`gfn, $sformatf("RESP error: err_status=0x%0h rdata=0x%08h",
                 rdata[31:28], rdata))
      fail_cnt++;
    end else begin
      `uvm_info(`gfn, $sformatf("RESP OK: tid=0x%0h data_length=%0d",
                rdata[27:24], rdata[15:0]), UVM_MEDIUM)
      pass_cnt++;
    end
  endfunction

  // ----------------------------------------------------------------
  // I3C bus side: compare observed transaction vs expected
  // ----------------------------------------------------------------
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
      `uvm_error(`gfn, $sformatf("Unexpected I3C txn: addr=0x%02h op=%s",
                 item.addr, item.bus_op.name()))
      fail_cnt++;
      return;
    end

    exp = exp_txn_queue.pop_front();

    `DV_CHECK_EQ(item.addr, exp.addr, "Target address mismatch")
    `DV_CHECK_EQ(item.bus_op, exp.rnw ? BusOpRead : BusOpWrite,
                 "Transfer direction mismatch")

    if (!exp.rnw) check_tx_data(item);

    pass_cnt++;
  endfunction

  // Verify write data bytes match queued TX FIFO words (little-endian byte order).
  function void check_tx_data(i3c_item item);
    foreach (item.data_q[i]) begin
      int word_idx = i / 4;
      int byte_off = (i % 4) * 8;
      if (word_idx < tx_data_queue.size()) begin
        bit [7:0] exp_byte = tx_data_queue[word_idx][byte_off +: 8];
        `DV_CHECK_EQ(item.data_q[i], exp_byte,
                     $sformatf("TX data mismatch at byte[%0d]", i))
      end
    end
    begin
      int words_used = (item.num_data + 3) / 4;
      repeat (words_used) begin
        if (tx_data_queue.size() > 0) void'(tx_data_queue.pop_front());
      end
    end
  endfunction

  // ----------------------------------------------------------------
  // End-of-test: verify all expected transactions were observed
  // ----------------------------------------------------------------
  function void check_phase(uvm_phase phase);
    if (exp_txn_queue.size() > 0)
      `uvm_error(`gfn, $sformatf("%0d expected command(s) never observed on I3C bus",
                 exp_txn_queue.size()))
    if (tx_data_queue.size() > 0)
      `uvm_error(`gfn, $sformatf("%0d TX data word(s) unconsumed", tx_data_queue.size()))
    `uvm_info(`gfn, $sformatf("Scoreboard: pass=%0d fail=%0d", pass_cnt, fail_cnt), UVM_LOW)
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(reg_seq_item, reg_fifo)
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(i3c_item, i3c_fifo)
  endfunction

endclass : i3c_scoreboard
