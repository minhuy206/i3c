class i3c_driver extends uvm_driver #(
    .REQ(i3c_seq_item),
    .RSP(i3c_seq_item)
);
  `uvm_component_utils(i3c_driver)

  function new(string name = "", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  bit under_reset;
  i3c_agent_cfg cfg;

  i3c_drv_phase_e bus_state;
  bit stop, rstart;

  function string drv_phase_name(i3c_drv_phase_e state);
    case (state)
      DrvIdle:             return "DrvIdle";
      DrvAddr:             return "DrvAddr";
      DrvAddrArbit:        return "DrvAddrArbit";
      DrvAddrPushPull:     return "DrvAddrPushPull";
      DrvAck:              return "DrvAck";
      DrvSelectNext:       return "DrvSelectNext";
      DrvWr:               return "DrvWr";
      DrvWrPushPull:       return "DrvWrPushPull";
      DrvRd:               return "DrvRd";
      DrvRdPushPull:       return "DrvRdPushPull";
      DrvStop:             return "DrvStop";
      DrvWaitStopOrRStart: return "DrvWaitStopOrRStart";
      DrvBcastDispatch:    return "DrvBcastDispatch";
      DrvDAA:              return "DrvDAA";
      default:             return "Unknown";
    endcase
  endfunction : drv_phase_name

  function void set_drv_state(i3c_drv_phase_e next_state);
    `uvm_info(`gfn, $sformatf("transition to state: %s", drv_phase_name(next_state)), UVM_MEDIUM)
    bus_state = next_state;
  endfunction : set_drv_state

  function bit is_broadcast_header(bit [6:0] addr);
    is_broadcast_header = addr == I3C_RSVD_ADDR ? 1'b1 : 1'b0;
  endfunction : is_broadcast_header

  function bit get_addr_ack(i3c_seq_item item, bit [6:0] addr);
    get_addr_ack = item.dev_ack;
    if (item.start_with_broadcast_header && is_broadcast_header(addr)) begin
      get_addr_ack = 1'b1;
    end
  endfunction : get_addr_ack

  function string ack_to_string(bit ack);
    return ack ? "ACK" : "NACK";
  endfunction : ack_to_string

  function void record_sampled_addr(ref i3c_seq_item rsp, bit [6:0] addr, bit dir);
    rsp.sampled_addr_q.push_back(addr);
    rsp.sampled_dir_q.push_back(dir);
  endfunction : record_sampled_addr

  function bit direct_ccc_addr_match(i3c_seq_item req, bit [6:0] addr);
    if (req.ccc_target_addr_valid) return addr == req.ccc_target_addr;
    return !is_broadcast_header(addr);
  endfunction : direct_ccc_addr_match

  function automatic bit [63:0] daa_target_identity(i3c_daa_arb_target_t target);
    return {target.pid, target.bcr, target.dcr};
  endfunction : daa_target_identity

  function automatic bit [7:0] daa_id_byte_at(i3c_seq_item req, int unsigned byte_idx);
    if (byte_idx < req.daa_id_bytes.size()) return req.daa_id_bytes[byte_idx];
    return 8'h00;
  endfunction : daa_id_byte_at

  function automatic void build_entdaa_target_list(
      i3c_seq_item req, output i3c_daa_arb_target_t targets[I3C_DAA_ARB_MAX_TARGETS],
      output int unsigned target_count);
    targets = '{default: '0};
    target_count = 0;

    if (req.daa_target_count > 0) begin
      target_count = (req.daa_target_count > I3C_DAA_ARB_MAX_TARGETS) ?
          I3C_DAA_ARB_MAX_TARGETS : req.daa_target_count;
      for (int unsigned i = 0; i < I3C_DAA_ARB_MAX_TARGETS; i++) begin
        targets[i] = req.daa_targets[i];
      end
    end else begin
      target_count = 1;
      targets[0].valid = req.entdaa_join;
      targets[0].pid = {daa_id_byte_at(req, 0), daa_id_byte_at(req, 1), daa_id_byte_at(req, 2),
                        daa_id_byte_at(req, 3), daa_id_byte_at(req, 4), daa_id_byte_at(req, 5)};
      targets[0].bcr = daa_id_byte_at(req, 6);
      targets[0].dcr = daa_id_byte_at(req, 7);
      targets[0].accept_addr = req.daa_accept_addr;

      if (req.entdaa_join && req.daa_id_bytes.size() != 8) begin
        `uvm_error(`gfn, $sformatf("ENTDAA join requires 8 DAA ID bytes, got %0d",
                                   req.daa_id_bytes.size()))
      end
    end
  endfunction : build_entdaa_target_list

  function automatic bit [I3C_DAA_ARB_MAX_TARGETS-1:0] make_entdaa_active_mask(
      i3c_daa_arb_target_t targets[I3C_DAA_ARB_MAX_TARGETS], int unsigned target_count,
      bit [I3C_DAA_ARB_MAX_TARGETS-1:0] assigned);
    make_entdaa_active_mask = '0;
    for (int unsigned i = 0; i < I3C_DAA_ARB_MAX_TARGETS; i++) begin
      if ((i < target_count) && targets[i].valid && !assigned[i]) begin
        make_entdaa_active_mask[i] = 1'b1;
      end
    end
  endfunction : make_entdaa_active_mask

  function automatic int unsigned count_active_entdaa_targets(
      bit [I3C_DAA_ARB_MAX_TARGETS-1:0] active);
    count_active_entdaa_targets = 0;
    for (int unsigned i = 0; i < I3C_DAA_ARB_MAX_TARGETS; i++) begin
      if (active[i]) count_active_entdaa_targets++;
    end
  endfunction : count_active_entdaa_targets

  function automatic bit find_entdaa_winner(bit [I3C_DAA_ARB_MAX_TARGETS-1:0] active,
                                            output int unsigned winner_idx);
    bit winner_found;

    winner_idx = 0;
    winner_found = 1'b0;
    for (int unsigned i = 0; i < I3C_DAA_ARB_MAX_TARGETS; i++) begin
      if (active[i] && !winner_found) begin
        winner_found = 1'b1;
        winner_idx = i;
      end else if (active[i]) begin
        `uvm_error(`gfn, "ENTDAA arbitration ended with multiple winners")
      end
    end

    if (!winner_found) begin
      `uvm_error(`gfn, "ENTDAA arbitration ended with no winner")
    end
    return winner_found;
  endfunction : find_entdaa_winner

  task automatic sample_addr(ref i3c_seq_item rsp, input string msg = "addr");
    bit [6:0] sampled_addr;
    bit       sampled_dir;

    cfg.vif.sample_addr(msg, sampled_addr, sampled_dir);
    rsp.addr = sampled_addr;
    rsp.dir  = sampled_dir;
    record_sampled_addr(rsp, rsp.addr, rsp.dir);
    `uvm_info(`gfn, $sformatf("Sampled %s=0x%h dir=%b", msg, rsp.addr, rsp.dir), UVM_MEDIUM)
  endtask : sample_addr

  task automatic sample_ccc_byte_or_term(ref i3c_seq_item rsp, output bit got_byte,
                                         output bit [7:0] data, output bit t_bit);
    bit local_rstart;
    bit local_stop;

    got_byte = 1'b0;
    data = '0;
    t_bit = 1'b0;
    local_rstart = 1'b0;
    local_stop = 1'b0;

    fork
      begin : iso_fork
        fork
          begin
            cfg.vif.sample_i3c_data_byte("CCC byte", data, t_bit);
            got_byte = 1'b1;
          end
          begin
            cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, local_rstart, local_stop);
          end
        join_any
        disable fork;
      end : iso_fork
    join

    if (got_byte) begin
      rsp.data.push_back(data);
      rsp.T_bit.push_back(t_bit);
      if (((^data) ^ t_bit) == 0) begin
        `uvm_warning(`gfn, $sformatf("Device sampled byte 0x%02h with bad T-bit %0b", data, t_bit))
      end
    end else begin
      rstart = local_rstart;
      stop = local_stop;
      rsp.end_with_rstart = local_rstart;
    end
  endtask : sample_ccc_byte_or_term

  task automatic wait_i3c_term(ref i3c_seq_item rsp);
    stop   = 1'b0;
    rstart = 1'b0;
    cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, rstart, stop);
    rsp.end_with_rstart = rstart;
  endtask : wait_i3c_term

  task automatic drive_entdaa_identity_arbitration(
      input i3c_daa_arb_target_t targets[I3C_DAA_ARB_MAX_TARGETS],
      input bit [I3C_DAA_ARB_MAX_TARGETS-1:0] active_i,
      output bit [I3C_DAA_ARB_MAX_TARGETS-1:0] active_o);
    bit [I3C_DAA_ARB_MAX_TARGETS-1:0] bit_value;
    bit [I3C_DAA_ARB_MAX_TARGETS-1:0] lost;
    bit [63:0] identity[I3C_DAA_ARB_MAX_TARGETS];
    bit bus_bit;

    active_o = active_i;
    for (int unsigned i = 0; i < I3C_DAA_ARB_MAX_TARGETS; i++) begin
      identity[i] = daa_target_identity(targets[i]);
    end

    for (int bit_pos = 63; bit_pos >= 0; bit_pos--) begin
      for (int unsigned i = 0; i < I3C_DAA_ARB_MAX_TARGETS; i++) begin
        bit_value[i] = identity[i][bit_pos];
      end
      cfg.vif.device_i3c_send_daa_arbitration_bit(cfg.tc.i3c_tc, active_o, bit_value, lost,
                                                  bus_bit);
      active_o &= ~lost;
      `uvm_info(`gfn, $sformatf(
                "ENTDAA arbitration bit[%0d] bus=%0b bit_value=0x%0h lost=0x%0h active=0x%0h",
                bit_pos, bus_bit, bit_value, lost, active_o), UVM_DEBUG)
    end
  endtask : drive_entdaa_identity_arbitration

  task automatic sample_entdaa_assigned_addr_or_term(ref i3c_seq_item rsp, output bit got_addr,
                                                     output bit [7:0] addr_tmp);
    bit addr_complete;
    bit term_seen;
    bit term_rstart;
    bit term_stop;

    got_addr = 1'b0;
    addr_tmp = '0;
    addr_complete = 1'b0;
    term_seen = 1'b0;
    term_rstart = 1'b0;
    term_stop = 1'b0;

    fork : wait_addr_or_term
      begin
        for (int j = 7; j >= 0; j--) begin
          cfg.vif.sample_target_data(addr_tmp[j]);
        end
        addr_complete = 1'b1;
      end
      begin
        cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, term_rstart, term_stop);
        term_seen = 1'b1;
      end
    join_any
    disable wait_addr_or_term;

    if (term_seen) begin
      rstart = term_rstart;
      stop = term_stop;
      rsp.end_with_rstart = term_rstart;
      return;
    end

    got_addr = addr_complete;
  endtask : sample_entdaa_assigned_addr_or_term

  task automatic drive_entdaa_transfer(i3c_seq_item req, ref i3c_seq_item rsp,
                                       input bit first_addr_valid = 1'b0);
    i3c_daa_arb_target_t targets[I3C_DAA_ARB_MAX_TARGETS];
    int unsigned target_count;
    int unsigned assigned_count;
    bit [I3C_DAA_ARB_MAX_TARGETS-1:0] assigned;
    bit [I3C_DAA_ARB_MAX_TARGETS-1:0] active;
    bit first_addr_pending;
    bit got_addr;
    bit addr_ack;
    bit active_found;
    bit [7:0] addr_tmp;
    bit target_list_request;
    int unsigned winner_idx;

    build_entdaa_target_list(req, targets, target_count);
    target_list_request = (req.daa_target_count > 0);
    assigned = '0;
    assigned_count = 0;
    first_addr_pending = first_addr_valid;

    forever begin
      if (first_addr_pending) begin
        got_addr = 1'b1;
        first_addr_pending = 1'b0;
      end else begin
        sample_next_addr_or_stop(rsp, "ENTDAA addr", got_addr);
        if (!got_addr) return;
      end

      active = make_entdaa_active_mask(targets, target_count, assigned);
      active_found = (|active) && (rsp.addr == I3C_RSVD_ADDR) && rsp.dir;
      addr_ack = active_found;
      cfg.vif.device_i3c_send_addr_ack_no_handoff(cfg.tc.i3c_tc, addr_ack);
      `uvm_info(`gfn, $sformatf("ENTDAA 0x7E+R sent %s active=0x%0h",
                                ack_to_string(addr_ack), active), UVM_MEDIUM)

      if ((rsp.addr != I3C_RSVD_ADDR) || !rsp.dir) begin
        `uvm_warning(`gfn, $sformatf("ENTDAA expected 0x7E+R, got addr=0x%02h dir=%0b",
                                     rsp.addr, rsp.dir))
      end

      if (!addr_ack) begin
        continue;
      end

      drive_entdaa_identity_arbitration(targets, active, active);
      if (count_active_entdaa_targets(active) != 1) begin
        `uvm_error(`gfn, $sformatf("ENTDAA arbitration ended with %0d winners",
                                   count_active_entdaa_targets(active)))
        continue;
      end
      if (!find_entdaa_winner(active, winner_idx)) begin
        continue;
      end

      sample_entdaa_assigned_addr_or_term(rsp, got_addr, addr_tmp);
      if (!got_addr) return;

      rsp.data.push_back(addr_tmp);
      cfg.vif.device_i3c_send_addr_ack_handoff(cfg.tc.i3c_tc, targets[winner_idx].accept_addr);
      if (targets[winner_idx].accept_addr) begin
        assigned[winner_idx] = 1'b1;
        assigned_count++;
      end
      `uvm_info(`gfn, $sformatf(
                "ENTDAA winner=%0d pid=0x%012h bcr=0x%02h dcr=0x%02h assigned_addr=0x%02h accepted=%0b assigned_count=%0d",
                winner_idx, targets[winner_idx].pid, targets[winner_idx].bcr,
                targets[winner_idx].dcr, addr_tmp[7:1], targets[winner_idx].accept_addr,
                assigned_count), UVM_MEDIUM)

      if (!target_list_request) begin
        wait_i3c_term(rsp);
        return;
      end
    end
  endtask : drive_entdaa_transfer

  task automatic sample_next_addr_or_stop(ref i3c_seq_item rsp, input string msg,
                                          output bit got_addr);
    bit [6:0] sampled_addr;
    bit       sampled_dir;

    cfg.vif.sample_i3c_next_addr_or_stop(cfg.tc.i3c_tc, msg, got_addr, rstart, stop, sampled_addr,
                                         sampled_dir);
    rsp.end_with_rstart = rstart;

    if (got_addr) begin
      rsp.addr = sampled_addr;
      rsp.dir  = sampled_dir;
      record_sampled_addr(rsp, rsp.addr, rsp.dir);
      rsp.observed_broadcast_rstart = 1'b1;
    end
  endtask : sample_next_addr_or_stop

  task automatic handle_broadcast_dispatch(input i3c_seq_item req, ref i3c_seq_item rsp,
                                           output bit transaction_done);
    bit got_byte;
    bit got_addr;
    bit [7:0] ccc_raw;
    bit [7:0] payload_byte;
    i3c_ccc_e ccc;
    bit t_bit;
    bit addr_ack;

    transaction_done = 1'b0;
    sample_ccc_byte_or_term(rsp, got_byte, ccc_raw, t_bit);

    if (!got_byte) begin
      if (rstart) begin
        `uvm_info(`gfn, "Broadcast header followed by RSTART; continuing as private transfer",
                  UVM_MEDIUM)
        rsp.start_with_broadcast_header = 1'b1;
        rsp.observed_broadcast_rstart   = 1'b1;
        set_drv_state(DrvAddrPushPull);
      end else begin
        `uvm_info(`gfn, "Broadcast header terminated before CCC opcode", UVM_MEDIUM)
        set_drv_state(DrvIdle);
        transaction_done = 1'b1;
      end
      return;
    end

    ccc = i3c_ccc_e'(ccc_raw);
    case (ccc)
      ENEC, DISEC: begin
        sample_ccc_byte_or_term(rsp, got_byte, payload_byte, t_bit);
        if (got_byte) wait_i3c_term(rsp);
        transaction_done = 1'b1;
      end

      ENTDAA: begin
        drive_entdaa_transfer(req, rsp);
        transaction_done = 1'b1;
      end

      DIR_ENEC, DIR_DISEC: begin
        sample_next_addr_or_stop(rsp, "direct CCC target addr", got_addr);
        if (!got_addr) begin
          `uvm_warning(`gfn, $sformatf("Direct CCC %s was not followed by RSTART", ccc_to_string(
                                       ccc_raw)))
          transaction_done = 1'b1;
          return;
        end
        addr_ack = req.dev_ack && !rsp.dir && direct_ccc_addr_match(req, rsp.addr);
        cfg.vif.device_i3c_send_addr_ack_handoff(cfg.tc.i3c_tc, addr_ack);
        `uvm_info(`gfn, $sformatf("Direct CCC target 0x%02h sent %s", rsp.addr,
                                  ack_to_string(addr_ack)), UVM_MEDIUM)
        if (addr_ack && (ccc == DIR_ENEC || ccc == DIR_DISEC)) begin
          sample_ccc_byte_or_term(rsp, got_byte, payload_byte, t_bit);
          if (got_byte) wait_i3c_term(rsp);
        end else begin
          wait_i3c_term(rsp);
        end
        transaction_done = 1'b1;
      end

      default: begin
        `uvm_warning(`gfn, $sformatf(
                     "Unsupported CCC opcode %s; waiting for frame end", ccc_to_string(ccc_raw)))
        wait_i3c_term(rsp);
        transaction_done = 1'b1;
      end
    endcase
  endtask : handle_broadcast_dispatch

  virtual task reset_signal();
    forever begin
      @(negedge cfg.vif.rst_ni);
      `uvm_info(`gfn, "\ndriver in reset progress", UVM_DEBUG)
      release_bus();
      @(posedge cfg.vif.rst_ni);
      `uvm_info(`gfn, "\ndriver out of reset", UVM_DEBUG)
      bus_state = DrvIdle;
    end
  endtask : reset_signal

  virtual task process_reset();
    @(negedge cfg.vif.rst_ni);
    release_bus();
    `uvm_info(`gfn, "\n driver is reset", UVM_DEBUG)
  endtask : process_reset

  virtual task release_bus();
    `uvm_info(`gfn, $sformatf("%s driver released the bus",
                              cfg.if_mode == Host ? "Host" : "Device"), UVM_HIGH)
    if (cfg.if_mode == Device) begin
      cfg.vif.device_sda_pp_en = 1'b0;
      cfg.vif.device_sda_o = 1'b1;
      cfg.vif.daa_target_sda_oe = '0;
    end
  endtask : release_bus

  virtual task run_phase(uvm_phase phase);
    fork
      reset_signal();
      get_and_drive();
    join_none
  endtask : run_phase

  virtual task get_and_drive();
    i3c_seq_item req, rsp;
    @(posedge cfg.vif.rst_ni);
    forever begin

      if (cfg.if_mode == Device) release_bus();
      stop = 0;
      rstart = 0;
      rsp = null;
      req = null;

      fork
        begin : iso_fork
          fork
            begin
              seq_item_port.get_next_item(req);
              if (cfg.if_mode == Device) drive_device_item(.req(req), .rsp(rsp));
            end
            begin
              if (cfg.if_mode == Device) begin
                wait (req != null);
                if (req.is_daa) begin
                  wait (1'b0);
                end else if (req.dir) begin
                  wait (bus_state == DrvRd || bus_state == DrvRdPushPull || bus_state == DrvDAA || bus_state == DrvStop);
                end else begin
                  wait (bus_state == DrvWrPushPull || bus_state == DrvWr || bus_state == DrvStop);
                end
                if (req.i3c) cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, rstart, stop);
                else cfg.vif.wait_for_i2c_host_stop_or_rstart(cfg.tc.i2c_tc, rstart, stop);
              end else wait (0);
            end
            begin
              process_reset();
            end
            begin
              wait (cfg.driver_rst);
              `uvm_info(`gfn, "drvdbg agent reset", UVM_HIGH)
            end
          join_any
          disable fork;
        end : iso_fork
      join

      if (cfg.if_mode == Device && stop) begin
        `uvm_info(`gfn, "Device got Stop", UVM_HIGH)
        bus_state = DrvIdle;
        if (rsp != null) rsp.end_with_rstart = 0;
      end else if (cfg.if_mode == Device && rstart) begin
        `uvm_info(`gfn, "Device got RStart", UVM_HIGH)
        bus_state = DrvAddrPushPull;
        if (rsp != null) rsp.end_with_rstart = 1;
      end

      if (rsp != null) begin
        rsp.set_id_info(req);
        seq_item_port.item_done(rsp);
      end

      if (cfg.driver_rst) begin
        i3c_seq_item dummy;
        do begin
          seq_item_port.try_next_item(dummy);
          if (dummy != null) seq_item_port.item_done();
        end while (dummy != null);
      end
    end
  endtask : get_and_drive

  virtual task drive_device_item(i3c_seq_item req, ref i3c_seq_item rsp);
    rsp = new();

    forever begin
      case (bus_state)
        DrvIdle: begin
          cfg.vif.wait_for_host_start(cfg.tc.i3c_tc);
          set_drv_state(DrvAddrArbit);
        end

        DrvAddrArbit: begin
          sample_addr(rsp, "started addr");
          rsp.start_with_broadcast_header = req.start_with_broadcast_header &&
              is_broadcast_header(rsp.addr);
          rsp.observed_broadcast_header = rsp.start_with_broadcast_header;
          set_drv_state(DrvAck);
        end

        DrvAddr: begin
          sample_addr(rsp, "device addr");
          set_drv_state(DrvAck);
        end

        DrvAddrPushPull: begin
          sample_addr(rsp, "device addr");
          if (req.is_daa) begin
            drive_entdaa_transfer(req, rsp, 1'b1);
            set_drv_state(DrvIdle);
            return;
          end
          set_drv_state(DrvAck);
        end

        DrvAck: begin
          bit ack;
          ack = get_addr_ack(req, rsp.addr);
          if (req.i3c) begin
            if (rsp.dir) begin
              cfg.vif.device_i3c_send_addr_ack_no_handoff(cfg.tc.i3c_tc, ack);
            end else begin
              cfg.vif.device_i3c_send_addr_ack_handoff(cfg.tc.i3c_tc, ack);
            end
          end else begin
            cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, !ack);
          end
          `uvm_info(`gfn, $sformatf("Device sent %s", ack_to_string(ack)), UVM_MEDIUM)
          set_drv_state(DrvSelectNext);
        end

        DrvSelectNext: begin
          if (get_addr_ack(req, rsp.addr)) begin
            if (is_broadcast_header(rsp.addr)) begin
              if (req.i3c && !rsp.dir) begin
                set_drv_state(DrvBcastDispatch);
              end else begin
                set_drv_state(DrvStop);
              end
            end else if (req.dir) begin
              if (req.i3c) begin
                set_drv_state(DrvRdPushPull);
              end else begin
                set_drv_state(DrvRd);
              end
            end else begin
              if (req.i3c) begin
                set_drv_state(DrvWrPushPull);
              end else begin
                set_drv_state(DrvWr);
              end
            end
          end else begin
            set_drv_state(DrvStop);
          end
        end

        DrvBcastDispatch: begin
          bit transaction_done;
          handle_broadcast_dispatch(req, rsp, transaction_done);
          if (transaction_done) begin
            set_drv_state(DrvIdle);
            return;
          end
        end

        DrvDAA: begin
          bit [7:0] data;
          bit ack;
          for (int i = 0; i < 8; i++) begin
            for (int j = 7; j >= 0; j--) begin
              cfg.vif.device_i3c_send_daa_bit(cfg.tc.i3c_tc, req.data[i][j]);
            end
          end
          for (int j = 7; j >= 0; j--) begin
            cfg.vif.sample_target_data(data[j]);
          end
          rsp.data.push_back(data);
          cfg.vif.device_i3c_send_daa_bit(cfg.tc.i3c_tc, !req.T_bit[0]);
          set_drv_state(DrvStop);
        end

        DrvRd: begin
          bit ack;
          for (int i = 0; i < req.data_cnt; i++) begin
            for (int j = 7; j >= 0; j--) begin
              cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, req.data[i][j]);
              `uvm_info(`gfn, $sformatf("Device drive data[%0d]=%b", i, req.data[i][j]), UVM_HIGH)
            end
            cfg.vif.wait_for_host_ack_or_nack(.ack_r(ack));
            rsp.T_bit.push_back(ack);
            `uvm_info(`gfn, $sformatf("Device drive data[%0d]=0x%h, host_ack=%s", i,
                                      req.data[i], ack_to_string(ack)), UVM_MEDIUM)
            if (!ack) begin
              set_drv_state(DrvStop);
              break;
            end
          end
        end

        DrvRdPushPull: begin
          for (int i = 0; i < req.data_cnt; i++) begin
            for (int j = 7; j >= 0; j--) begin
              cfg.vif.device_i3c_send_bit(cfg.tc.i3c_tc, req.data[i][j]);
              `uvm_info(`gfn, $sformatf("Device drive data[%0d]=%b", i, req.data[i][j]), UVM_HIGH)
            end

            cfg.vif.device_i3c_send_t_bit(cfg.tc.i3c_tc, req.T_bit[i]);
            `uvm_info(`gfn, $sformatf(
                      "Device drive data[%0d]=0x%h, T_bit=%b", i, req.data[i], req.T_bit[i]),
                      UVM_MEDIUM)
          end
          set_drv_state(DrvStop);
        end

        DrvWr: begin
          bit [7:0] data;
          cfg.vif.device_sda_pp_en = 0;
          for (int i = 0; i < req.data_cnt; i++) begin
            for (int j = 7; j >= 0; j--) begin
              cfg.vif.sample_target_data(data[j]);
              `uvm_info(`gfn, $sformatf("Device sampled data[%0d][%0d]=%b", i, j, data[j]),
                        UVM_HIGH)
            end
            rsp.data.push_back(data);
            cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, !req.T_bit[i]);
            `uvm_info(`gfn, $sformatf("Device sampled data[%0d]=0x%h, device_ack=%s", i, data,
                                      ack_to_string(req.T_bit[i])), UVM_MEDIUM)
            if (!req.T_bit[i]) begin
              break;
            end
          end
          set_drv_state(DrvStop);
        end

        DrvWrPushPull: begin
          bit [7:0] data;
          bit t_bit;
          cfg.vif.device_sda_pp_en = 0;
          for (int i = 0; i < req.data_cnt; i++) begin
            cfg.vif.sample_i3c_data_byte($sformatf("data[%0d]", i), data, t_bit);
            rsp.data.push_back(data);
            rsp.T_bit.push_back(t_bit);
            `uvm_info(`gfn, $sformatf("Device sampled data[%0d]=0x%h, T_bit=%b", i, data, t_bit),
                      UVM_MEDIUM)
            if (((^data) ^ t_bit) == 0) begin
              `uvm_warning(`gfn, $sformatf("Device sampled data is incorrect!"))
              break;
            end
          end
          set_drv_state(DrvStop);
        end

        DrvWaitStopOrRStart: begin
          release_bus();
          stop   = 1'b0;
          rstart = 1'b0;
          cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, rstart, stop);

          if (rstart) begin
            `uvm_info(`gfn, "Device got RStart after broadcast header", UVM_MEDIUM)
            rsp.start_with_broadcast_header = 1'b1;
            rsp.observed_broadcast_rstart = 1'b1;
            rsp.end_with_rstart = 1'b1;
            set_drv_state(DrvAddrPushPull);
          end else begin
            `uvm_info(`gfn, "Device got Stop after broadcast header", UVM_MEDIUM)
            rsp.end_with_rstart = 1'b0;
            set_drv_state(DrvIdle);
            return;
          end
        end

        DrvStop: begin
          release_bus();
          wait (0);
        end

        default: begin
          `uvm_fatal(`gfn, $sformatf("\n device_driver, received invalid request"))
        end
      endcase
    end
  endtask : drive_device_item
endclass
