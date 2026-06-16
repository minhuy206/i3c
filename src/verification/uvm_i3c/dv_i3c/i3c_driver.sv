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
      DrvDAA:              return "DrvDAA";
      default:             return "Unknown";
    endcase
  endfunction : drv_phase_name

  function void set_drive_device_state(i3c_drv_phase_e next_state);
    `uvm_info(`gfn, $sformatf("transition to state: %s", drv_phase_name(next_state)), UVM_MEDIUM)
    bus_state = next_state;
  endfunction : set_drive_device_state

  function bit is_broadcast_header(bit [6:0] addr);
    is_broadcast_header = addr == I3C_RSVD_ADDR ? 1'b1 : 1'b0;
  endfunction : is_broadcast_header

  function bit get_addr_ack(i3c_seq_item item, bit [6:0] addr);
    get_addr_ack = item.dev_ack;
    if (item.start_with_broadcast_header && is_broadcast_header(addr)) begin
      get_addr_ack = 1'b1;
    end
  endfunction : get_addr_ack

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
                if (req.dir || req.is_daa) begin
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
          cfg.vif.wait_for_host_start();
          set_drive_device_state(DrvAddrArbit);
        end

        DrvAddrArbit: begin
          for (int i = 6; i >= 0; i--) begin
            cfg.vif.sample_target_data(.data(rsp.addr[i]));
            `uvm_info(`gfn, $sformatf("Sampled started addr[%0d]=%b", i, rsp.addr[i]), UVM_HIGH)
          end
          rsp.start_with_broadcast_header = req.start_with_broadcast_header &&
              is_broadcast_header(rsp.addr);
          rsp.observed_broadcast_header = rsp.start_with_broadcast_header;
          cfg.vif.sample_target_data(.data(rsp.dir));
          `uvm_info(`gfn, $sformatf("Sampled started addr=0x%h dir=%b", rsp.addr, rsp.dir),
                    UVM_MEDIUM)
          set_drive_device_state(DrvAck);
        end

        DrvAddr: begin
          for (int i = 6; i >= 0; i--) begin
            cfg.vif.sample_target_data(.data(rsp.addr[i]));
            `uvm_info(`gfn, $sformatf("Sampled device addr[%0d]=%b", i, rsp.addr[i]), UVM_HIGH)
          end
          cfg.vif.sample_target_data(.data(rsp.dir));
          `uvm_info(`gfn, $sformatf("Sampled started addr=0x%h dir=%b", rsp.addr, rsp.dir),
                    UVM_MEDIUM)
          set_drive_device_state(DrvAck);
        end

        DrvAddrPushPull: begin
          for (int i = 6; i >= 0; i--) begin
            cfg.vif.sample_target_data(.data(rsp.addr[i]));
            `uvm_info(`gfn, $sformatf("Sampled device addr[%0d]=%b", i, rsp.addr[i]), UVM_HIGH)
          end
          cfg.vif.sample_target_data(.data(rsp.dir));
          `uvm_info(`gfn, $sformatf("Sampled started addr=0x%h dir=%b", rsp.addr, rsp.dir),
                    UVM_MEDIUM)
          set_drive_device_state(DrvAck);
        end

        DrvAck: begin
          bit ack;
          bit wait_low_after_handoff;
          ack = get_addr_ack(req, rsp.addr);
          wait_low_after_handoff =
              !(req.start_with_broadcast_header && is_broadcast_header(rsp.addr));
          if (req.i3c) begin
            cfg.vif.device_i3c_send_addr_ack(cfg.tc.i3c_tc, ack, wait_low_after_handoff);
          end else begin
            cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, !ack);
          end
          `uvm_info(`gfn, $sformatf("Device sent %d[%s]", !ack, ack ? "ACK" : "NACK"), UVM_MEDIUM)
          set_drive_device_state(DrvSelectNext);
        end

        DrvSelectNext: begin
          if (get_addr_ack(req, rsp.addr)) begin
            if (is_broadcast_header(rsp.addr)) begin
              if (req.is_daa) begin
                set_drive_device_state(DrvDAA);
              end else if (req.start_with_broadcast_header) begin
                set_drive_device_state(DrvWaitStopOrRStart);
              end else begin
                set_drive_device_state(DrvWrPushPull);
              end
            end else if (req.dir) begin
              if (req.i3c) begin
                set_drive_device_state(DrvRdPushPull);
              end else begin
                set_drive_device_state(DrvRd);
              end
            end else begin
              if (req.i3c) begin
                set_drive_device_state(DrvWrPushPull);
              end else begin
                set_drive_device_state(DrvWr);
              end
            end
          end else begin
            set_drive_device_state(DrvStop);
          end
        end

        DrvWaitStopOrRStart: begin
          release_bus();
          stop   = 1'b0;
          rstart = 1'b0;
          cfg.vif.wait_for_i3c_host_stop_or_rstart_after_ack(cfg.tc.i3c_tc, rstart, stop);

          if (rstart) begin
            `uvm_info(`gfn, "Device got RStart after broadcast header", UVM_MEDIUM)
            rsp.start_with_broadcast_header = 1'b1;
            rsp.observed_broadcast_rstart = 1'b1;
            rsp.end_with_rstart = 1'b1;
            set_drive_device_state(DrvAddrPushPull);
          end else begin
            `uvm_info(`gfn, "Device got Stop after broadcast header", UVM_MEDIUM)
            rsp.end_with_rstart = 1'b0;
            set_drive_device_state(DrvIdle);
            return;
          end
        end

        DrvStop: begin
          release_bus();
          wait (0);
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
          set_drive_device_state(DrvStop);
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
            `uvm_info(`gfn, $sformatf("Device drive data[%0d]=0x%h, ACK=%b", i, req.data[i], ack),
                      UVM_MEDIUM)
            if (!ack) begin
              set_drive_device_state(DrvStop);
              break;
            end
          end
        end

        DrvRdPushPull: begin
          bit sent;
          bit read_ended;

          read_ended = 1'b0;
          for (int i = 0; i < req.data_cnt; i++) begin
            for (int j = 7; j >= 0; j--) begin
              cfg.vif.device_i3c_send_bit(cfg.tc.i3c_tc, req.data[i][j], sent);
              if (!sent) begin
                read_ended = 1'b1;
                break;
              end
              `uvm_info(`gfn, $sformatf("Device drive data[%0d]=%b", i, req.data[i][j]), UVM_HIGH)
            end
            if (read_ended) break;

            cfg.vif.device_i3c_send_t_bit(cfg.tc.i3c_tc, req.T_bit[i], sent);
            if (!sent) begin
              read_ended = 1'b1;
              break;
            end
            `uvm_info(`gfn, $sformatf(
                      "Device drive data[%0d]=0x%h, T_bit=%b", i, req.data[i], req.T_bit[i]),
                      UVM_MEDIUM)
          end
          set_drive_device_state(DrvStop);
        end

        DrvWr: begin
          bit [7:0] data;
          cfg.vif.device_sda_pp_en = 0;
          for (int i = 0; i < req.data_cnt; i++) begin
            for (int j = 7; j >= 0; j--) begin
              cfg.vif.sample_target_data(data[j]);
            end
            rsp.data.push_back(data);
            cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, !req.T_bit[i]);
            if (!req.T_bit[i]) begin
              break;
            end
          end
          set_drive_device_state(DrvStop);
        end

        DrvWrPushPull: begin
          bit [7:0] data;
          bit t_bit;
          cfg.vif.device_sda_pp_en = 0;
          for (int i = 0; i < req.data_cnt; i++) begin
            for (int j = 7; j >= 0; j--) begin
              cfg.vif.sample_target_data(data[j]);
            end
            rsp.data.push_back(data);
            cfg.vif.sample_target_data(t_bit);
            rsp.T_bit.push_back(t_bit);
            `uvm_info(`gfn, $sformatf(
                      "Device sampled data[%0d]=0x%h, T_bit=%b", i, rsp.data[i], rsp.T_bit[i]),
                      UVM_MEDIUM)
            if (((^data) ^ t_bit) == 0) begin
              `uvm_warning(`gfn, $sformatf("Device sampled data is incorrect!"))
              break;
            end
          end
          set_drive_device_state(DrvStop);
        end
        default: begin
          `uvm_fatal(`gfn, $sformatf("\n device_driver, received invalid request"))
        end
      endcase
    end
  endtask : drive_device_item
endclass
