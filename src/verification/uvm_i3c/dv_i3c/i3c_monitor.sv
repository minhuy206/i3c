class i3c_monitor extends uvm_monitor;
  `uvm_component_utils(i3c_monitor)

  i3c_agent_cfg cfg;

  uvm_analysis_port #(i3c_item) analysis_port;

  local i3c_item next_item;
  local bit next_item_addr_valid;
  local bit start = 0;
  local bit stop = 0;
  local bit rstart = 0;
  local bit [8:0] mon_data;
  local bit [31:0] num_dut_tran = 0;

  function new(string name = "", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_port = new("analysis_port", this);
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    wait (cfg.vif.rst_ni);
    forever begin
      fork
        begin : iso_fork
          fork
            begin
              collect_thread(phase);
            end
            begin
              wait_for_reset_and_drop_item();
              `uvm_info(`gfn, $sformatf("monitor is reset, drop item\n"), UVM_DEBUG)
            end
          join_any
          disable fork;
        end : iso_fork
      join
    end
  endtask

  virtual task wait_for_reset_and_drop_item();
    @(negedge cfg.vif.rst_ni);
    num_dut_tran = 0;
    next_item = null;
    next_item_addr_valid = 1'b0;
  endtask : wait_for_reset_and_drop_item

  function bit is_i3c_target_addr(bit [6:0] addr);
    return (addr == cfg.i3c_target0.dynamic_addr && cfg.i3c_target0.dynamic_addr_valid ||
            addr == cfg.i3c_target1.dynamic_addr && cfg.i3c_target1.dynamic_addr_valid);
  endfunction

  function bit is_i3c_broadcast(bit [6:0] addr);
    return (addr == I3C_RSVD_ADDR);
  endfunction

  function string ack_to_string(bit ack);
    return ack ? "ACK" : "NACK";
  endfunction

  virtual protected task collect_thread(uvm_phase phase);
    i3c_item full_item;
    bit use_next_item;
    bit use_next_item_addr_valid;

    if (next_item != null) begin
      full_item = next_item;
      next_item = null;
      use_next_item = 1'b1;
      use_next_item_addr_valid = next_item_addr_valid;
      next_item_addr_valid = 1'b0;
    end else begin
      full_item = new();
      use_next_item = 1'b0;
      use_next_item_addr_valid = 1'b0;
    end

    wait (cfg.en_monitor);
    if (use_next_item) begin
      `DV_CHECK_EQ(stop, 1'b0, "next_item should not be reused after STOP")
      `DV_CHECK_EQ(rstart, 1'b1, "next_item should only be reused after RSTART")
      full_item.rstart = 1'b1;
    end else if (!start || stop) begin
      rstart = 1'b0;
      full_item.rstart = 1'b0;
      cfg.vif.wait_for_host_start(cfg.tc.i3c_tc);
      `uvm_info(`gfn, "monitor, detect HOST START", UVM_HIGH)
    end else if (rstart) begin
      full_item.rstart = 1'b1;
    end else begin
      `uvm_info(
          `gfn,
          "monitor reached active bus state without STOP/RSTART; waiting for HOST START to resync",
          UVM_DEBUG)
      rstart = 1'b0;
      cfg.vif.wait_for_host_start(cfg.tc.i3c_tc);
      full_item.rstart = 1'b0;
    end

    // Preserve how this transaction started before rstart is reused to describe
    // the transaction's end condition.
    full_item.start_from_rstart = use_next_item || rstart;

    num_dut_tran++;
    full_item.tran_id = num_dut_tran;
    start = 1'b1;

    if (use_next_item_addr_valid) begin
      `uvm_info(`gfn, "monitor, use address captured after RSTART", UVM_HIGH)
    end else begin
      address_thread(full_item);
    end

    if (full_item.addr_nack == 1'b1) begin
      if (full_item.i3c) begin
        `uvm_info(`gfn, $sformatf(
                            "tran_id=%0d addr 0x%0h NACK'd on I3C bus, waiting for STOP/RSTART",
                            full_item.tran_id, full_item.addr), UVM_HIGH)
        cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, full_item.rstart, full_item.stop);
      end else begin
        `uvm_info(`gfn, $sformatf(
                  "tran_id=%0d addr 0x%0h NACK'd on I2C bus, waiting for STOP/RSTART",
                  full_item.tran_id,
                  full_item.addr
                  ), UVM_HIGH)
        cfg.vif.wait_for_i2c_host_stop_or_rstart(cfg.tc.i2c_tc, full_item.rstart, full_item.stop);
      end
    end else if (is_i3c_broadcast(full_item.addr)) begin
      `uvm_info(
          `gfn,
          $sformatf(
              "tran_id=%0d addr 0x%0h matched I3C broadcast (0x7E ACKed), dispatching to post_broadcast_header_thread",
              full_item.tran_id, full_item.addr), UVM_HIGH)
      post_broadcast_header_thread(full_item);
    end else if (is_i3c_target_addr(full_item.addr)) begin
      `uvm_info(
          `gfn,
          $sformatf(
              "tran_id=%0d addr 0x%0h matched I3C target (ACKed, %s), dispatching to i3c_data",
              full_item.tran_id, full_item.addr,
              full_item.bus_op == BusOpRead ? "Read" : "Write"), UVM_HIGH)
      i3c_data(.transaction(full_item), .device_to_host(full_item.bus_op == BusOpRead),
               .msg("I3C Direct data type"));
    end else if (full_item.bus_op == BusOpRead) begin
      `uvm_info(
          `gfn,
          $sformatf(
              "tran_id=%0d addr 0x%0h is I2C target (ACKed, Read), dispatching to i2c_read_thread",
              full_item.tran_id, full_item.addr), UVM_HIGH)
      i2c_read_thread(full_item);
    end else begin
      `uvm_info(`gfn, $sformatf(
                "tran_id=%0d addr 0x%0h is I2C target (ACKed, Write), dispatching to i2c_write_thread",
                full_item.tran_id,
                full_item.addr
                ), UVM_HIGH)
      i2c_write_thread(full_item);
    end

    `uvm_info(`gfn, $sformatf("tran_id=%0d end-of-frame: stop=%0b rstart=%0b", full_item.tran_id,
                              full_item.stop, full_item.rstart), UVM_HIGH)
    if (cfg.vif.rst_ni && (full_item.stop || full_item.rstart)) begin
      if (full_item.i3c && full_item.CCC_valid) begin
        `uvm_info(`gfn, $sformatf("tran_id=%0d: writing I3C CCC transaction to analysis port",
                                  full_item.tran_id), UVM_HIGH)
      end else if (full_item.i3c && full_item.bus_op == BusOpRead) begin
        `uvm_info(`gfn, $sformatf("tran_id=%0d: writing I3C read transaction to analysis port",
                                  full_item.tran_id), UVM_HIGH)
      end else if (full_item.i3c) begin
        `uvm_info(`gfn, $sformatf("tran_id=%0d: writing I3C write transaction to analysis port",
                                  full_item.tran_id), UVM_HIGH)
      end else if (full_item.bus_op == BusOpRead) begin
        `uvm_info(`gfn, $sformatf("tran_id=%0d: writing I2C read transaction to analysis port",
                                  full_item.tran_id), UVM_HIGH)
      end else begin
        `uvm_info(`gfn, $sformatf(
                  "tran_id=%0d: writing I2C write transaction to analysis port", full_item.tran_id),
                  UVM_HIGH)
      end
      analysis_port.write(full_item);
      `uvm_info(`gfn, $sformatf("monitor, sent full transaction to scb\n%s", full_item.sprint()),
                UVM_HIGH)
    end
    stop   = full_item.stop;
    rstart = full_item.rstart;
  endtask

  virtual protected task post_broadcast_header_thread(ref i3c_item transaction);
    i3c_item ccc_item;
    bit      header_nack;
    bit      rstart_seen;
    bit      stop_seen;

    header_nack                             = transaction.addr_nack;
    transaction.start_with_broadcast_header = 1'b1;
    transaction.broadcast_header_nack       = header_nack;
    transaction.stop                        = 1'b0;
    transaction.rstart                      = 1'b0;
    transaction.CCC_valid                   = 1'b0;
    rstart_seen                             = 1'b0;
    stop_seen                               = 1'b0;
    ccc_item                                = transaction;

    fork
      begin : iso_fork
        fork
          begin
            ccc_get_value(ccc_item);
          end
          begin
            cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, rstart_seen, stop_seen);
          end
        join_any
        disable fork;
      end : iso_fork
    join

    if (ccc_item.CCC_valid) begin
      transaction = ccc_item;
    end else begin
      transaction.rstart = rstart_seen;
      transaction.stop   = stop_seen;
    end
    `DV_CHECK_NE_FATAL({transaction.rstart, transaction.stop}, 2'b11)

    if (!ccc_item.CCC_valid && transaction.rstart) begin
      `uvm_info(`gfn, "monitor, broadcast header followed by Sr; routing to private path", UVM_HIGH)
      transaction.rstart = 1'b0;
      address_thread(transaction);
      if (transaction.addr_nack) begin
        cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, transaction.rstart,
                                                 transaction.stop);
      end else if (is_i3c_target_addr(transaction.addr)) begin
        i3c_data(.transaction(transaction), .device_to_host(transaction.bus_op == BusOpRead),
                 .msg("I3C Direct data type after broadcast header"));
      end else begin
        `uvm_error(`gfn, $sformatf(
                   "Broadcast header preamble was followed by unsupported target address 0x%02h",
                   transaction.addr
                   ))
        cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, transaction.rstart,
                                                 transaction.stop);
      end
    end else if (transaction.CCC_valid && transaction.i3c_direct) begin
      `uvm_info(`gfn, $sformatf("monitor, broadcast header: direct CCC 0x%0h (%s)",
                                8'(transaction.CCC), transaction.CCC.name()), UVM_HIGH)
      i3c_direct(transaction);
    end else if (transaction.CCC_valid && transaction.CCC == ENTDAA) begin
      `uvm_info(`gfn, "monitor, broadcast header: ENTDAA", UVM_HIGH)
      i3c_daa(transaction);
    end else if (transaction.CCC_valid) begin
      `uvm_info(`gfn, $sformatf("monitor, broadcast header: broadcast CCC 0x%0h (%s)",
                                8'(transaction.CCC), transaction.CCC.name()), UVM_HIGH)
      if (data_for_CCC[transaction.CCC] != 2'b00) begin
        i3c_data(.transaction(transaction), .device_to_host(1'b0), .count(1),
                 .msg("CCC event byte"));
      end else begin
        `uvm_info(`gfn, $sformatf(
                  "tran_id=%0d broadcast CCC 0x%0h (%s) carries no payload, waiting for STOP/RSTART",
                  transaction.tran_id,
                  8'(transaction.CCC),
                  transaction.CCC.name()
                  ), UVM_HIGH)
        cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, transaction.rstart,
                                                 transaction.stop);
      end
    end
    // Else: CCC_valid=0, stop=1 -- STOP before an opcode; item terminates here.
  endtask : post_broadcast_header_thread

  virtual protected task address_thread(ref i3c_item transaction);
    bit rw_req = 1'b0;
    bit addr_ack_tmp;

    cfg.vif.sample_addr("address", transaction.addr, rw_req);
    transaction.bus_op = (rw_req) ? BusOpRead : BusOpWrite;
    transaction.i3c = is_i3c_target_addr(transaction.addr) || is_i3c_broadcast(transaction.addr);

    cfg.vif.wait_for_device_ack_or_nack(addr_ack_tmp);
    transaction.addr_nack = !addr_ack_tmp;
    `uvm_info(`gfn, $sformatf("monitor, address: %s", transaction.addr_nack ? "NACK" : "ACK"),
              UVM_DEBUG)
    `uvm_info(`gfn, "monitor, address, detect TARGET ACK", UVM_HIGH)
  endtask : address_thread

  virtual protected task sample_next_addr_or_stop(ref i3c_item transaction, input string msg,
                                                  output bit got_addr);
    bit rstart_seen;
    bit stop_seen;
    bit [6:0] addr;
    bit dir;
    bit addr_ack_tmp;

    transaction.rstart = 1'b0;
    transaction.stop   = 1'b0;
    transaction.start_from_rstart = 1'b0;

    cfg.vif.sample_i3c_next_addr_or_stop(cfg.tc.i3c_tc, msg, got_addr, rstart_seen, stop_seen, addr,
                                         dir);
    if (!got_addr) begin
      transaction.stop = stop_seen;
      return;
    end

    transaction.addr = addr;
    transaction.bus_op = dir ? BusOpRead : BusOpWrite;
    transaction.start_from_rstart = rstart_seen;
    transaction.i3c = is_i3c_target_addr(transaction.addr) || is_i3c_broadcast(transaction.addr);

    cfg.vif.wait_for_device_ack_or_nack(addr_ack_tmp);
    transaction.addr_nack = !addr_ack_tmp;
    `uvm_info(`gfn, $sformatf("monitor, sampled %s=0x%0h dir=%0b ack=%s", msg, transaction.addr,
                              dir, ack_to_string(!transaction.addr_nack)), UVM_HIGH)
  endtask : sample_next_addr_or_stop

  virtual protected task ccc_get_value(ref i3c_item transaction);
    transaction.CCC_valid = 1'b0;

    for (int i = 8; i > 0; i--) begin
      cfg.vif.sample_bit_data("device", mon_data[i]);
      `uvm_info(`gfn, $sformatf(
                "monitor, CCC, trans %0d, byte %0d, bit[%0d] %0b",
                transaction.tran_id,
                transaction.num_data + 1,
                i,
                mon_data[i]
                ), UVM_DEBUG)
    end
    cfg.vif.sample_t_bit_data("device", mon_data[0]);
    `uvm_info(`gfn, $sformatf("monitor, CCC, trans %0d, byte %0d, bit[0] %0b", transaction.tran_id,
                              transaction.num_data + 1, mon_data[0]), UVM_DEBUG)

    `DV_CHECK_NE_FATAL(^mon_data[8:1], mon_data[0])
    transaction.CCC = i3c_ccc_e'(mon_data[8:1]);
    transaction.CCC_valid = 1'b1;
    transaction.ccc_t_bit_valid = 1'b1;
    transaction.ccc_t_bit = mon_data[0];
    transaction.i3c_direct = mon_data[8];

    `uvm_info(`gfn, $sformatf("monitor, CCC, trans %0d, 0x%0h (%s)", transaction.tran_id,
                              mon_data[8:1], transaction.CCC.name()), UVM_HIGH)
  endtask : ccc_get_value

  virtual protected task i3c_direct(ref i3c_item transaction);
    i3c_item temp_val;
    bit      first_target;
    bit      got_addr;

    first_target = 1'b1;
    forever begin
      next_item = new;
      if (first_target) begin
        sample_next_addr_or_stop(next_item, "direct CCC target addr", got_addr);
        first_target = 1'b0;
        if (!got_addr) begin
          transaction.stop = next_item.stop;
          if (!transaction.stop) begin
            `uvm_error(`gfn, $sformatf("Direct CCC 0x%0h ended opcode phase without RSTART",
                                       8'(transaction.CCC)))
          end
          next_item = null;
          break;
        end
      end else begin
        next_item.rstart = 1'b0;
        next_item.start_from_rstart = 1'b1;
        address_thread(next_item);
      end

      if (!next_item.stop && !next_item.rstart) begin
        // Address thread was successful
        if (next_item.addr == I3C_RSVD_ADDR) begin
          // Potential CCC command, break to main collect thread.
          `uvm_info(
              `gfn,
              $sformatf(
                  "tran_id=%0d direct CCC 0x%0h: re-detected 0x7E, ending direct loop, returning to collect_thread",
                  transaction.tran_id, 8'(transaction.CCC)), UVM_HIGH)
          break;
        end
        if (!next_item.addr_nack) begin
          // Device ACKed address
          `uvm_info(
              `gfn,
              $sformatf(
                  "tran_id=%0d direct CCC 0x%0h: target 0x%0h ACKed, dispatching to %s",
                  transaction.tran_id, 8'(transaction.CCC), next_item.addr,
                  transaction.CCC_valid ? "ccc_direct (sub-cmd/data)" : "i3c_data (direct data byte)"),
              UVM_HIGH)
          if (transaction.CCC_valid) begin
            // Parse direct CCC
            ccc_direct(transaction, next_item);
            transaction.stop   = next_item.stop;
            transaction.rstart = next_item.rstart;
          end else begin
            i3c_data(.transaction(next_item), .device_to_host(next_item.bus_op == BusOpRead),
                     .msg("CCC Direct data byte"));
            transaction.CCC_direct_q.push_back(next_item);
            transaction.stop   = next_item.stop;
            transaction.rstart = next_item.rstart;
          end
        end else begin
          // I3C transfer was denied by target
          `uvm_info(`gfn, $sformatf(
                    "tran_id=%0d direct CCC 0x%0h: target 0x%0h NACKed, waiting for STOP/RSTART",
                    transaction.tran_id,
                    8'(transaction.CCC),
                    next_item.addr
                    ), UVM_HIGH)
          cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, transaction.rstart,
                                                   transaction.stop);
          next_item.rstart = transaction.rstart;
          next_item.stop = transaction.stop;
          transaction.CCC_direct_q.push_back(next_item);
        end
      end else if (next_item.rstart) begin
        // I3C address aborted, log it and restart address phase
        transaction.CCC_direct_q.push_back(next_item);
      end else if (next_item.stop) begin
        // I3C special case for RSTART followed by STOP
        // Don't create new i3c_item
        temp_val = transaction.CCC_direct_q.pop_back();
        temp_val.stop = 1'b1;
        transaction.CCC_direct_q.push_back(temp_val);
        transaction.stop = 1'b1;
      end
      `DV_CHECK_NE_FATAL({next_item.rstart, next_item.stop}, 2'b11)
      `uvm_info(`gfn, $sformatf("monitor, CCC, detect HOST %s", (next_item.stop) ? "STOP" : "RSTART"
                ), UVM_HIGH)
      if (next_item.stop) begin
        next_item = null;
        break;
      end
      next_item = null;
    end
  endtask : i3c_direct

  virtual protected task i3c_daa(ref i3c_item transaction);
    i3c_item temp_val;
    bit      got_addr;

    forever begin
      next_item = new;
      sample_next_addr_or_stop(next_item, "ENTDAA 0x7E+R", got_addr);

      if (got_addr) begin
        if (!next_item.addr_nack) begin
          `uvm_info(
              `gfn,
              $sformatf(
                  "tran_id=%0d ENTDAA: 0x7E+R ACKed, a target joined this round, dispatching to daa_data (ID + new address)",
                  transaction.tran_id), UVM_HIGH)
          daa_data(.transaction(next_item), .updated_transaction(temp_val));
          next_item = temp_val;
          transaction.CCC_direct_q.push_back(next_item);
          if (next_item.stop || next_item.rstart) begin
            transaction.stop   = next_item.stop;
            transaction.rstart = next_item.rstart;
          end
        end else begin
          `uvm_info(
              `gfn, $sformatf(
              "tran_id=%0d ENTDAA: 0x7E+R NACKed, no target joined this round", transaction.tran_id
              ), UVM_HIGH)
          cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, transaction.rstart,
                                                   transaction.stop);
          next_item.rstart = transaction.rstart;
          next_item.stop = transaction.stop;
          transaction.CCC_direct_q.push_back(next_item);
        end
      end else begin
        transaction.stop   = next_item.stop;
        transaction.rstart = next_item.rstart;
        if (!transaction.stop) begin
          `uvm_fatal(`gfn, "monitor, DAA opcode was not followed by STOP or RSTART")
        end
      end
      `DV_CHECK_NE_FATAL({next_item.rstart, next_item.stop}, 2'b11)
      if (next_item.stop || next_item.rstart) begin
        `uvm_info(`gfn, $sformatf("monitor, CCC, detect HOST %s",
                                  (next_item.stop) ? "STOP" : "RSTART"), UVM_HIGH)
      end
      next_item = null;
      if (transaction.stop) break;
    end
  endtask : i3c_daa

  virtual protected task daa_data(input i3c_item transaction, output i3c_item updated_transaction);
    int i;
    bit term_seen;
    for (int j = 0; j < 8; j++) begin
      for (i = 7; i >= 0; i--) begin
        cfg.vif.sample_bit_data("device", mon_data[i]);
        `uvm_info(`gfn, $sformatf(
                  "monitor, DAA arbitration, trans %0d, DAA byte %0d, bit[%0d] %0b",
                  transaction.tran_id,
                  transaction.num_data + 1,
                  i,
                  mon_data[i]
                  ), UVM_DEBUG)
      end
      transaction.data_q.push_back(mon_data[7:0]);
      transaction.num_data++;
      `uvm_info(`gfn, $sformatf(
                "monitor, DAA arbitration, trans %0d, 0x%0h", transaction.tran_id, mon_data[7:0]),
                UVM_HIGH)
    end

    term_seen = 1'b0;
    fork : sample_addr_or_term
      begin
        for (i = 8; i >= 2; i--) begin
          cfg.vif.sample_bit_data("host", mon_data[i]);
          `uvm_info(`gfn, $sformatf(
                    "monitor, DAA new address, trans %0d, addr bit[%0d] %0b",
                    transaction.tran_id,
                    i - 2,
                    mon_data[i]
                    ), UVM_DEBUG)
        end
        cfg.vif.sample_bit_data("host", mon_data[1]);
        `uvm_info(`gfn, $sformatf("monitor, DAA new address, trans %0d, parity %0b",
                                  transaction.tran_id, mon_data[1]), UVM_DEBUG)
        cfg.vif.sample_t_bit_data("device", mon_data[0]);
        `uvm_info(`gfn, $sformatf("monitor, DAA new address, trans %0d, device_ack=%s",
                                  transaction.tran_id, ack_to_string(!mon_data[0])), UVM_DEBUG)
      end
      begin
        cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, transaction.rstart,
                                                 transaction.stop);
        term_seen = 1'b1;
      end
    join_any
    disable sample_addr_or_term;

    if (term_seen) begin
      transaction.interrupted = 1'b1;
      updated_transaction = transaction;
      return;
    end

    `DV_CHECK_NE_FATAL(^mon_data[8:2], mon_data[1])
    transaction.data_q.push_back(mon_data[8:1]);
    transaction.data_nack_q.push_back(mon_data[0]);
    if (mon_data[0]) `uvm_info(`gfn, "Device rejected new address", UVM_MEDIUM)
    transaction.num_data++;
    updated_transaction = transaction;
  endtask : daa_data

  virtual protected task ccc_direct(ref i3c_item transaction, ref i3c_item next_item);
    if (subcmd_byte_for_CCC[transaction.CCC] != 2'b0) begin
      i3c_data(.transaction(next_item), .count(subcmd_byte_for_CCC[transaction.CCC][1] ? -1 : 1),
               .device_to_host(1'b0), .msg("Sub-command byte"));
    end
    if (data_for_CCC[transaction.CCC] != 2'b0) begin
      i3c_data(.transaction(next_item), .device_to_host(next_item.bus_op == BusOpRead),
               .msg("CCC Direct data byte"));
    end
    if (next_item.rstart == 0 && next_item.stop == 0) begin
      cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, next_item.rstart, next_item.stop);
    end
    transaction.CCC_direct_q.push_back(next_item);
  endtask : ccc_direct

  virtual protected task capture_next_addr_after_rstart(
      ref i3c_item transaction, input bit final_t_bit, input int unsigned observed_bytes);
    i3c_item addr_item;
    bit      rstart_seen;
    bit      stop_seen;
    bit      addr_seen;

    rstart_seen = 1'b0;
    stop_seen = 1'b0;
    addr_seen = 1'b0;
    addr_item = new();
    addr_item.rstart = 1'b0;
    addr_item.stop = 1'b0;

    fork
      begin : iso_fork
        fork
          begin
            address_thread(addr_item);
            addr_seen = 1'b1;
          end
          begin
            cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, rstart_seen, stop_seen);
          end
        join_any
        disable fork;
      end : iso_fork
    join

    if (rstart_seen) begin
      `uvm_error(
          `gfn,
          $sformatf(
              "Read RSTART handoff after byte %0d observed a second RSTART before next address",
              observed_bytes))
    end

    transaction.rstart = 1'b1;
    transaction.interrupted = transaction.interrupted | final_t_bit;

    if (stop_seen) begin
      transaction.stop = 1'b1;
      next_item = null;
      next_item_addr_valid = 1'b0;
      `uvm_info(`gfn, $sformatf("monitor observed STOP after read RSTART after byte %0d",
                                observed_bytes), UVM_HIGH)
    end else if (addr_seen) begin
      transaction.stop = 1'b0;
      next_item = addr_item;
      next_item_addr_valid = 1'b1;
      `uvm_info(`gfn, $sformatf("monitor captured next address after read RSTART after byte %0d",
                                observed_bytes), UVM_HIGH)
    end else begin
      `uvm_error(
          `gfn, $sformatf(
          "Read RSTART handoff after byte %0d ended without STOP or next address", observed_bytes))
    end
  endtask : capture_next_addr_after_rstart

  virtual protected task handle_read_end(ref i3c_item transaction, input bit final_t_bit,
                                         input int unsigned observed_bytes, input bit read_rstart,
                                         input bit read_stop);
    bit observed_rstart;
    bit observed_stop;

    observed_rstart = read_rstart;
    observed_stop   = read_stop;

    if (!(read_stop || read_rstart)) begin
      cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, observed_rstart, observed_stop);
    end

    if (observed_rstart) begin
      capture_next_addr_after_rstart(transaction, final_t_bit, observed_bytes);
    end else if (observed_stop) begin
      transaction.stop = 1'b1;
      transaction.interrupted = transaction.interrupted | final_t_bit;
    end else begin
      `uvm_error(`gfn, $sformatf(
                 "I3C read ended after byte %0d, but monitor did not observe STOP or RSTART",
                 observed_bytes
                 ))
    end
  endtask : handle_read_end

  virtual protected task i3c_data(ref i3c_item transaction, input bit device_to_host,
                                  int count = -1, string msg = "Data byte");
    i3c_item data_item;

    data_item = transaction;
    if (device_to_host) i3c_read_thread(data_item, count, msg);
    else i3c_write_thread(data_item, count, msg);
    transaction = data_item;
  endtask : i3c_data

  virtual protected task i3c_read_thread(input i3c_item transaction, input int count = -1,
                                         string msg = "Data byte");
    bit byte_in_progress;
    bit final_t_bit;
    int remaining_count;
    bit read_rstart;
    bit read_stop;

    read_rstart      = 1'b0;
    read_stop        = 1'b0;
    remaining_count  = count;
    byte_in_progress = 1'b0;

    fork
      begin : iso_fork
        fork
          begin
            forever begin
              bit [7:0] sampled_data;
              bit       sampled_t_bit;

              byte_in_progress = 1'b1;
              cfg.vif.sample_i3c_data_byte_and_t_bit($sformatf(
                                           "monitor, %s, trans %0d, byte %0d",
                                           msg,
                                           transaction.tran_id,
                                           transaction.num_data + 1
                                           ), sampled_data, sampled_t_bit);
              mon_data[8:1] = sampled_data;
              mon_data[0]   = sampled_t_bit;

              transaction.data_q.push_back(mon_data[8:1]);
              transaction.data_nack_q.push_back(mon_data[0]);
              transaction.num_data++;
              byte_in_progress = 1'b0;
              `uvm_info(`gfn, $sformatf(
                        "monitor, %s, trans %0d, 0x%0h", msg, transaction.tran_id, mon_data[8:1]),
                        UVM_HIGH)

              if (remaining_count > 0) remaining_count--;
              if (!mon_data[0] || (count > 0 && remaining_count == 0)) break;

              @(negedge cfg.vif.scl_i);
            end
          end
          begin
            cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, read_rstart, read_stop);
          end
        join_any
        disable fork;
      end : iso_fork
    join

    `DV_CHECK_NE_FATAL({read_rstart, read_stop}, 2'b11)
    final_t_bit = byte_in_progress ? 1'b0 : mon_data[0];
    handle_read_end(.transaction(transaction), .final_t_bit(final_t_bit),
                    .observed_bytes(transaction.num_data), .read_rstart(read_rstart),
                    .read_stop(read_stop));
  endtask : i3c_read_thread

  virtual protected task i3c_write_thread(input i3c_item transaction, input int count = -1,
                                          string msg = "Data byte");
    int i;

    fork
      begin : iso_fork
        fork
          begin
            for (int j = count; j != 0; j--) begin
              for (i = 8; i >= 0; i--) begin
                cfg.vif.sample_bit_data("host", mon_data[i]);
                `uvm_info(`gfn, $sformatf(
                          "monitor, %s, trans %0d, byte %0d, bit[%0d] %0b",
                          msg,
                          transaction.tran_id,
                          transaction.num_data + 1,
                          i,
                          mon_data[i]
                          ), UVM_DEBUG)
              end
              transaction.data_q.push_back(mon_data[8:1]);
              transaction.data_nack_q.push_back(mon_data[0]);
              transaction.num_data++;
              `uvm_info(`gfn, $sformatf(
                        "monitor, %s, trans %0d, 0x%0h", msg, transaction.tran_id, mon_data[8:1]),
                        UVM_HIGH)
            end
          end
          begin
            if (count < 0) begin
              cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, transaction.rstart,
                                                       transaction.stop);
              if (i == 0 && transaction.rstart) begin
                transaction.data_q.push_back(mon_data[8:1]);
                transaction.data_nack_q.push_back(1'b1);
                transaction.interrupted = 1'b1;
                `uvm_info(`gfn, $sformatf("monitor, %s, transferred aborted by controller", msg),
                          UVM_HIGH)
                `uvm_info(`gfn, $sformatf("monitor, %s, trans %0d, 0x%0h", msg,
                                          transaction.tran_id, mon_data[8:1]), UVM_HIGH)
              end else begin
                `uvm_info(`gfn, $sformatf(
                          "monitor, %s, transferred aborted, discarding last transfer", msg),
                          UVM_HIGH)
              end
            end else begin
              wait (1'b0);
            end
          end
        join_any
        disable fork;
      end : iso_fork
    join
    `DV_CHECK_NE_FATAL({transaction.rstart, transaction.stop}, 2'b11)
    if (!transaction.rstart && !transaction.stop)
      cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, transaction.rstart, transaction.stop);
  endtask : i3c_write_thread

  virtual protected task i2c_read_thread(ref i3c_item transaction);
    bit ack;

    transaction.stop   = 1'b0;
    transaction.rstart = 1'b0;
    ack                = 1'b0;
    while (!transaction.stop && !transaction.rstart) begin
      for (int i = 7; i >= 0; i--) begin
        cfg.vif.sample_bit_data("device", mon_data[i]);
        `uvm_info(`gfn, $sformatf(
                  "monitor, rd_data, trans %0d, byte %0d, bit[%0d] %0b",
                  transaction.tran_id,
                  transaction.num_data + 1,
                  i,
                  mon_data[i]
                  ), UVM_DEBUG)
      end
      transaction.data_q.push_back(mon_data);
      transaction.num_data++;
      `uvm_info(`gfn, $sformatf(
                "monitor, rd_data, trans %0d, byte %0d 0x%0h",
                transaction.tran_id,
                transaction.num_data,
                mon_data
                ), UVM_HIGH)
      cfg.vif.wait_for_host_ack_or_nack(ack);
      transaction.data_nack_q.push_back(!ack);
      `uvm_info(`gfn, $sformatf("monitor, detect HOST %s", ack ? "ACK" : "NO_ACK"),
                UVM_HIGH)
      if (!ack) begin
        cfg.vif.wait_for_i2c_host_stop_or_rstart(cfg.tc.i2c_tc, transaction.rstart,
                                                 transaction.stop);
        `DV_CHECK_NE_FATAL({transaction.rstart, transaction.stop}, 2'b11)
        `uvm_info(`gfn, $sformatf("monitor, rd_data, detect HOST %s",
                                  (transaction.stop) ? "STOP" : "RSTART"), UVM_HIGH)
      end
    end
  endtask : i2c_read_thread

  virtual protected task i2c_write_thread(input i3c_item transaction);
    transaction.stop   = 1'b0;
    transaction.rstart = 1'b0;
    `uvm_info(`gfn, $sformatf("host_write_thread begin: tran_id:%0d num_data:%0d",
                              transaction.tran_id, transaction.num_data), UVM_HIGH)

    while (!transaction.stop && !transaction.rstart) begin
      fork
        begin : iso_fork_write
          fork
            begin
              bit ack_nack;
              for (int i = 7; i >= 0; i--) begin
                cfg.vif.sample_bit_data("host", mon_data[i]);
              end
              `uvm_info(`gfn, $sformatf("Monitor collected data 0x%0h", mon_data), UVM_HIGH)
              transaction.num_data++;
              transaction.data_q.push_back(mon_data);
              `uvm_info(`gfn, $sformatf(
                        "host_write_thread data %2x num_data:%0d", mon_data, transaction.num_data),
                        UVM_HIGH)
              cfg.vif.wait_for_device_ack_or_nack(ack_nack);
              transaction.data_nack_q.push_back(!ack_nack);
            end
            begin
              cfg.vif.wait_for_i2c_host_stop_or_rstart(cfg.tc.i2c_tc, transaction.rstart,
                                                       transaction.stop);
              `DV_CHECK_NE_FATAL({transaction.rstart, transaction.stop}, 2'b11)
              `uvm_info(`gfn, $sformatf(
                        "monitor, wr_data, detect HOST %s %0b",
                        (transaction.stop) ? "STOP" : "RSTART",
                        transaction.stop
                        ), UVM_HIGH)
            end
          join_any
          disable fork;
        end : iso_fork_write
      join
    end
    `uvm_info(`gfn, $sformatf("host_write_thread end: tran_id:%0d num_data:%0d",
                              transaction.tran_id, transaction.num_data), UVM_HIGH)
  endtask : i2c_write_thread

endclass
