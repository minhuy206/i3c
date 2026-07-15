class i3c_driver extends uvm_driver #(
    .REQ(i3c_seq_item),
    .RSP(i3c_seq_item)
);
  `uvm_component_utils(i3c_driver)

  localparam int unsigned BYTE_WIDTH = 8;

  i3c_agent_cfg cfg;

  function new(string name = "", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `DV_CHECK_FATAL(cfg.if_mode == Device, "i3c_driver supports Device mode only")
  endfunction : build_phase

  i3c_drv_phase_e bus_state;
  bit stop, rstart;
  i3c_proto_ctx_e proto_ctx;
  i3c_ccc_e proto_ccc;

  function void clear_proto_ctx();
    proto_ctx = ProtoCtxNone;
    proto_ccc = i3c_ccc_e'('0);
  endfunction : clear_proto_ctx

  function string drv_phase_name(i3c_drv_phase_e state);
    case (state)
      DrvIdle:          return "DrvIdle";
      DrvAddrArbit:     return "DrvAddrArbit";
      DrvAddrPushPull:  return "DrvAddrPushPull";
      DrvAck:           return "DrvAck";
      DrvSelectNext:    return "DrvSelectNext";
      DrvWr:            return "DrvWr";
      DrvWrPushPull:    return "DrvWrPushPull";
      DrvRd:            return "DrvRd";
      DrvRdPushPull:    return "DrvRdPushPull";
      DrvEntdaa:        return "DrvEntdaa";
      DrvStop:          return "DrvStop";
      DrvBcastDispatch: return "DrvBcastDispatch";
      DrvCccData:       return "DrvCccData";
      default:          return "Unknown";
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
    if (item.start_with_broadcast_header && is_broadcast_header(addr)) begin
      return 1'b1;
    end

    return !item.addr_nack && (addr == item.addr);
  endfunction : get_addr_ack

  function string ack_to_string(bit ack);
    return ack ? "ACK" : "NACK";
  endfunction : ack_to_string

  function bit direct_ccc_addr_match(i3c_seq_item req, bit [6:0] addr);
    if (req.ccc_target_addr_valid) return addr == req.ccc_target_addr;
    return !is_broadcast_header(addr);
  endfunction : direct_ccc_addr_match

  function automatic bit [7:0] daa_id_byte_at(i3c_seq_item req, int unsigned byte_idx);
    if (byte_idx < req.daa_id_bytes.size()) return req.daa_id_bytes[byte_idx];
    return 8'h00;
  endfunction : daa_id_byte_at

  function void record_termination(bit term_rstart, bit term_stop, ref i3c_seq_item rsp);
    rstart = term_rstart;
    stop = term_stop;
    rsp.end_with_rstart = term_rstart;
  endfunction : record_termination

  task automatic i2c_send_byte(input bit [BYTE_WIDTH-1:0] data, input int byte_idx);
    for (int bit_idx = BYTE_WIDTH - 1; bit_idx >= 0; bit_idx--) begin
      cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, data[bit_idx]);
      `uvm_info(`gfn, $sformatf("Device drive data[%0d]=%b", byte_idx, data[bit_idx]), UVM_HIGH)
    end
  endtask : i2c_send_byte

  task automatic send_byte_i3c(input bit [BYTE_WIDTH-1:0] data, input int byte_idx);
    for (int bit_idx = BYTE_WIDTH - 1; bit_idx >= 0; bit_idx--) begin
      cfg.vif.device_i3c_send_bit(cfg.tc.i3c_tc, data[bit_idx]);
      `uvm_info(`gfn, $sformatf("Device drive data[%0d]=%b", byte_idx, data[bit_idx]), UVM_HIGH)
    end
  endtask : send_byte_i3c

  task automatic sample_addr(ref i3c_seq_item rsp, input string msg = "addr");
    bit [6:0] sampled_addr;
    bit       sampled_dir;

    cfg.vif.sample_addr(msg, sampled_addr, sampled_dir);
    rsp.addr = sampled_addr;
    rsp.dir  = sampled_dir;
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
            cfg.vif.sample_i3c_data_byte_and_t_bit("CCC byte", data, t_bit);
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
      rsp.t_bit_q.push_back(t_bit);
      if (((^data) ^ t_bit) == 0) begin
        `uvm_warning(`gfn, $sformatf("Device sampled byte 0x%02h with bad T-bit %0b", data, t_bit))
      end
    end else begin
      record_termination(local_rstart, local_stop, rsp);
    end
  endtask : sample_ccc_byte_or_term

  task automatic wait_i3c_term(ref i3c_seq_item rsp);
    stop   = 1'b0;
    rstart = 1'b0;
    cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, rstart, stop);
    record_termination(rstart, stop, rsp);
  endtask : wait_i3c_term

  task automatic drive_entdaa_identity(i3c_seq_item req);
    bit [7:0] id_byte;

    if (req.daa_id_bytes.size() != 8) begin
      `uvm_error(`gfn, $sformatf("ENTDAA join requires 8 DAA ID bytes, got %0d",
                                 req.daa_id_bytes.size()))
    end

    for (int unsigned byte_idx = 0; byte_idx < 8; byte_idx++) begin
      id_byte = daa_id_byte_at(req, byte_idx);
      for (int bit_idx = BYTE_WIDTH - 1; bit_idx >= 0; bit_idx--) begin
        cfg.vif.device_i3c_send_daa_bit(cfg.tc.i3c_tc, id_byte[bit_idx]);
        `uvm_info(`gfn, $sformatf(
                  "ENTDAA identity[%0d][%0d]=%0b", byte_idx, bit_idx, id_byte[bit_idx]), UVM_HIGH)
      end
    end
  endtask : drive_entdaa_identity

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
        cfg.vif.sample_one_byte("ENTDAA assigned address", addr_tmp);
        addr_complete = 1'b1;
      end
      begin
        cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, term_rstart, term_stop);
        term_seen = 1'b1;
      end
    join_any
    disable wait_addr_or_term;

    if (term_seen) begin
      record_termination(term_rstart, term_stop, rsp);
      return;
    end

    got_addr = addr_complete;
  endtask : sample_entdaa_assigned_addr_or_term

  task automatic do_entdaa_round(i3c_seq_item req, ref i3c_seq_item rsp);
    bit got_addr;
    bit addr_ack;
    bit [7:0] addr_tmp;

    addr_ack = req.entdaa_join && (rsp.addr == I3C_RSVD_ADDR) && rsp.dir;
    cfg.vif.device_i3c_send_addr_ack_no_handoff(cfg.tc.i3c_tc, addr_ack);
    `uvm_info(`gfn, $sformatf("ENTDAA 0x7E+R sent %s join=%0b", ack_to_string(addr_ack),
                              req.entdaa_join), UVM_MEDIUM)

    if ((rsp.addr != I3C_RSVD_ADDR) || !rsp.dir) begin
      `uvm_warning(`gfn, $sformatf("ENTDAA expected 0x7E+R, got addr=0x%02h dir=%0b", rsp.addr,
                                   rsp.dir))
    end

    if (!addr_ack) begin
      wait_i3c_term(rsp);
      return;
    end

    drive_entdaa_identity(req);

    sample_entdaa_assigned_addr_or_term(rsp, got_addr, addr_tmp);
    if (!got_addr) return;

    rsp.data.push_back(addr_tmp);
    cfg.vif.device_i3c_send_addr_ack_handoff(cfg.tc.i3c_tc, req.daa_accept_addr);
    `uvm_info(`gfn, $sformatf("ENTDAA assigned_addr=0x%02h accepted=%0b", addr_tmp[7:1],
                              req.daa_accept_addr), UVM_MEDIUM)

    wait_i3c_term(rsp);
  endtask : do_entdaa_round

  task automatic do_ccc_payload(input i3c_seq_item req, ref i3c_seq_item rsp);
    bit got_byte;
    bit [7:0] payload_byte;
    bit t_bit;
    bit addr_ack;

    if (proto_ctx == ProtoCtxDirectCcc) begin
      addr_ack = !req.addr_nack && !rsp.dir && direct_ccc_addr_match(req, rsp.addr);
      cfg.vif.device_i3c_send_addr_ack_handoff(cfg.tc.i3c_tc, addr_ack);
      `uvm_info(`gfn, $sformatf("Direct CCC target 0x%02h sent %s", rsp.addr, ack_to_string(
                                addr_ack)), UVM_MEDIUM)

      if (!addr_ack) begin
        wait_i3c_term(rsp);
        return;
      end
    end else if (proto_ctx != ProtoCtxBroadcastCcc) begin
      `uvm_fatal(`gfn, $sformatf("DrvCccData entered with invalid context %0d", proto_ctx))
      return;
    end

    sample_ccc_byte_or_term(rsp, got_byte, payload_byte, t_bit);
    if (got_byte) wait_i3c_term(rsp);
  endtask : do_ccc_payload

  task automatic handle_broadcast_dispatch(ref i3c_seq_item rsp, output bit transaction_done);
    bit got_byte;
    bit [7:0] ccc_raw;
    i3c_ccc_e ccc;
    bit t_bit;

    transaction_done = 1'b0;
    sample_ccc_byte_or_term(rsp, got_byte, ccc_raw, t_bit);

    if (!got_byte) begin
      if (rstart) begin
        `uvm_info(`gfn, "Broadcast header followed by RSTART; continuing as private transfer",
                  UVM_MEDIUM)
        clear_proto_ctx();
        rsp.start_with_broadcast_header = 1'b1;
        rsp.observed_broadcast_rstart   = 1'b1;
        set_drv_state(DrvAddrPushPull);
      end else begin
        `uvm_info(`gfn, "Broadcast header terminated before CCC opcode", UVM_MEDIUM)
        clear_proto_ctx();
        set_drv_state(DrvIdle);
        transaction_done = 1'b1;
      end
      return;
    end

    ccc = i3c_ccc_e'(ccc_raw);
    clear_proto_ctx();
    case (ccc)
      ENEC, DISEC: begin
        proto_ctx = ProtoCtxBroadcastCcc;
        proto_ccc = ccc;
        set_drv_state(DrvCccData);
      end

      ENTDAA: begin
        proto_ctx = ProtoCtxEntdaa;
        proto_ccc = ccc;
        wait_i3c_term(rsp);
        if (rstart) begin
          rsp.observed_broadcast_rstart = 1'b1;
          set_drv_state(DrvAddrPushPull);
        end else begin
          clear_proto_ctx();
          transaction_done = 1'b1;
        end
      end

      DIR_ENEC, DIR_DISEC: begin
        proto_ctx = ProtoCtxDirectCcc;
        proto_ccc = ccc;
        wait_i3c_term(rsp);
        if (rstart) begin
          rsp.observed_broadcast_rstart = 1'b1;
          set_drv_state(DrvAddrPushPull);
        end else begin
          `uvm_warning(`gfn, $sformatf(
                       "Direct CCC %s was not followed by RSTART", ccc_to_string(ccc_raw)))
          clear_proto_ctx();
          transaction_done = 1'b1;
        end
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
      `uvm_info(`gfn, "driver in reset progress", UVM_DEBUG)
      clear_proto_ctx();
      release_bus();
      @(posedge cfg.vif.rst_ni);
      `uvm_info(`gfn, "driver out of reset", UVM_DEBUG)
      bus_state = DrvIdle;
    end
  endtask : reset_signal

  virtual task process_reset();
    @(negedge cfg.vif.rst_ni);
    clear_proto_ctx();
    release_bus();
    `uvm_info(`gfn, "driver is reset", UVM_DEBUG)
  endtask : process_reset

  virtual task release_bus();
    `uvm_info(`gfn, "Device driver released the bus", UVM_HIGH)
    cfg.vif.device_sda_pp_en = 1'b0;
    cfg.vif.device_sda_o = 1'b1;
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
    bus_state = DrvIdle;
    clear_proto_ctx();
    forever begin

      release_bus();
      stop = 0;
      rstart = 0;
      rsp = null;
      req = null;

      fork
        begin : iso_fork
          fork
            begin
              seq_item_port.get_next_item(req);
              drive_device_item(.req(req), .rsp(rsp));
            end
            begin
              wait (req != null);
              if (req.dir) begin
                wait (bus_state == DrvRd || bus_state == DrvRdPushPull || bus_state == DrvStop);
              end else begin
                wait (bus_state == DrvWrPushPull || bus_state == DrvWr || bus_state == DrvStop);
              end
              if (req.i3c) cfg.vif.wait_for_i3c_host_stop_or_rstart(cfg.tc.i3c_tc, rstart, stop);
              else cfg.vif.wait_for_i2c_host_stop_or_rstart(cfg.tc.i2c_tc, rstart, stop);
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

      if (stop) begin
        `uvm_info(`gfn, "Device got Stop", UVM_HIGH)
        bus_state = DrvIdle;
        clear_proto_ctx();
        if (rsp != null) rsp.end_with_rstart = 0;
      end else if (rstart) begin
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
        clear_proto_ctx();
      end
    end
  endtask : get_and_drive

  task automatic do_idle();
    cfg.vif.wait_for_host_start(cfg.tc.i3c_tc);
    set_drv_state(DrvAddrArbit);
  endtask : do_idle

  task automatic do_addr_arbit(i3c_seq_item req, ref i3c_seq_item rsp);
    sample_addr(rsp, "started addr");
    rsp.start_with_broadcast_header = req.start_with_broadcast_header &&
        is_broadcast_header(rsp.addr);
    set_drv_state(DrvAck);
  endtask : do_addr_arbit

  task automatic do_addr_push_pull(ref i3c_seq_item rsp);
    sample_addr(rsp, "device addr");
    case (proto_ctx)
      ProtoCtxEntdaa: set_drv_state(DrvEntdaa);
      ProtoCtxDirectCcc: set_drv_state(DrvCccData);
      default: set_drv_state(DrvAck);
    endcase
  endtask : do_addr_push_pull

  task automatic do_send_addr_ack(i3c_seq_item req, ref i3c_seq_item rsp);
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
  endtask : do_send_addr_ack

  function automatic i3c_drv_phase_e next_state_after_ack(i3c_seq_item req, i3c_seq_item rsp);
    if (!get_addr_ack(req, rsp.addr)) return DrvStop;

    if (is_broadcast_header(rsp.addr)) begin
      return (req.i3c && !rsp.dir) ? DrvBcastDispatch : DrvStop;
    end

    if (req.dir) return req.i3c ? DrvRdPushPull : DrvRd;
    return req.i3c ? DrvWrPushPull : DrvWr;
  endfunction : next_state_after_ack

  task automatic do_i2c_read(i3c_seq_item req, ref i3c_seq_item rsp);
    bit ack;

    for (int i = 0; i < req.data.size(); i++) begin
      i2c_send_byte(req.data[i], i);
      cfg.vif.wait_for_host_ack_or_nack(.ack_r(ack));
      rsp.data_nack_q.push_back(!ack);
      `uvm_info(`gfn, $sformatf(
                "Device drive data[%0d]=0x%h, host_ack=%s", i, req.data[i], ack_to_string(ack)),
                UVM_MEDIUM)
      if (!ack) begin
        set_drv_state(DrvStop);
        break;
      end
    end
  endtask : do_i2c_read

  task automatic do_i3c_read(i3c_seq_item req);
    for (int i = 0; i < req.data.size(); i++) begin
      send_byte_i3c(req.data[i], i);
      cfg.vif.device_i3c_send_t_bit(cfg.tc.i3c_tc, req.t_bit_q[i]);
      `uvm_info(`gfn, $sformatf(
                "Device drive data[%0d]=0x%h, T_bit=%b", i, req.data[i], req.t_bit_q[i]),
                UVM_MEDIUM)
    end
    set_drv_state(DrvStop);
  endtask : do_i3c_read

  task automatic do_i2c_write(i3c_seq_item req, ref i3c_seq_item rsp);
    bit [BYTE_WIDTH-1:0] data;
    bit ack;
    int i = 0;

    cfg.vif.device_sda_pp_en = 0;
    forever begin
      cfg.vif.sample_one_byte($sformatf("Device sampled data[%0d]", i), data);
      rsp.data.push_back(data);
      ack = (i < req.data_nack_q.size()) ? !req.data_nack_q[i] : 1'b1;
      cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, !ack);
      `uvm_info(`gfn, $sformatf(
                "Device sampled data[%0d]=0x%h, device_ack=%s", i, data, ack_to_string(ack)),
                UVM_MEDIUM)
      if (!ack) begin
        set_drv_state(DrvStop);
        break;
      end
      i++;
    end
  endtask : do_i2c_write

  task automatic do_i3c_write(ref i3c_seq_item rsp);
    bit [BYTE_WIDTH-1:0] data;
    bit t_bit;
    int i = 0;

    cfg.vif.device_sda_pp_en = 0;
    forever begin
      cfg.vif.sample_i3c_data_byte_and_t_bit($sformatf("data[%0d]", i), data, t_bit);
      rsp.data.push_back(data);
      rsp.t_bit_q.push_back(t_bit);
      `uvm_info(`gfn, $sformatf("Device sampled data[%0d]=0x%h, T_bit=%b", i, data, t_bit),
                UVM_MEDIUM)
      if (((^data) ^ t_bit) == 0) begin
        `uvm_warning(`gfn, $sformatf("Device sampled data is incorrect!"))
      end
      i++;
    end
  endtask : do_i3c_write

  task automatic do_stop();
    release_bus();
    wait (0);
  endtask : do_stop

  virtual task drive_device_item(i3c_seq_item req, ref i3c_seq_item rsp);
    rsp = new();

    forever begin
      case (bus_state)
        DrvIdle: do_idle();

        DrvAddrArbit: do_addr_arbit(req, rsp);

        DrvAddrPushPull: do_addr_push_pull(rsp);

        DrvAck: do_send_addr_ack(req, rsp);

        DrvSelectNext: set_drv_state(next_state_after_ack(req, rsp));

        DrvBcastDispatch: begin
          bit transaction_done;
          handle_broadcast_dispatch(rsp, transaction_done);
          if (transaction_done) begin
            set_drv_state(DrvIdle);
            return;
          end
        end

        DrvEntdaa: begin
          do_entdaa_round(req, rsp);
          set_drv_state(DrvIdle);
          return;
        end

        DrvCccData: begin
          do_ccc_payload(req, rsp);
          clear_proto_ctx();
          set_drv_state(DrvIdle);
          return;
        end

        DrvRd: do_i2c_read(req, rsp);

        DrvRdPushPull: do_i3c_read(req);

        DrvWr: do_i2c_write(req, rsp);

        DrvWrPushPull: do_i3c_write(rsp);

        DrvStop: do_stop();

        default: begin
          `uvm_fatal(`gfn, $sformatf("\n device_driver, received invalid request"))
        end
      endcase
    end
  endtask : drive_device_item
endclass
