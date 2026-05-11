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

  int scl_spinwait_timeout_ns = 1_000_000;  // 1ms
  i3c_drv_phase_e bus_state;
  bit stop, rstart;

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

  virtual task run_phase(uvm_phase phase);
    fork
      reset_signal();
      get_and_drive();
      begin
        if (cfg.if_mode == Host) begin
          // drive_scl(); // drive scl if design support
        end
      end
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
      fork
        begin : iso_fork
          fork
            begin
              seq_item_port.get_next_item(req);
              if (cfg.if_mode == Device) drive_device_item(.req(req), .rsp(rsp));
              else begin
                // drive_host_item if design support act as host
              end
            end
            begin
              if (cfg.if_mode == Device) begin
                wait (req != null);
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
        rsp.end_with_rstart = 0;
      end else if (cfg.if_mode == Device && rstart) begin
        `uvm_info(`gfn, "Device got RStart", UVM_HIGH)
        bus_state = DrvAddr;
        rsp.end_with_rstart = 1;
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

  virtual task drive_host_item(i3c_seq_item req, ref i3c_seq_item rsp);
  endtask

  virtual task drive_device_item(i3c_seq_item req, ref i3c_seq_item rsp);
    rsp = new();
    if (bus_state == DrvAddr || bus_state == DrvAddrPushPull) begin
      bus_state = req.i3c ? DrvAddrPushPull : DrvAddr;
    end

    forever begin
      case (bus_state)
        DrvIdle: begin
          cfg.vif.wait_for_host_start();
          bus_state = DrvAddrArbit;
        end

        DrvAddrArbit: begin
          for (int i = 6; i >= 0; i--) begin
            cfg.vif.sample_target_data(.data(rsp.addr[i]));
            `uvm_info(`gfn, $sformatf("Sampled device addr[%0d]=%b", i, rsp.addr[i]), UVM_MEDIUM)
          end
          cfg.vif.sample_target_data(.data(rsp.dir));
          `uvm_info(`gfn, $sformatf("Sampled device dir=%b", rsp.dir), UVM_MEDIUM)
          bus_state = DrvAck;
        end

        DrvAddr: begin
          // phase 2
        end

        DrvAddrPushPull: begin
          // phase 2
        end

        DrvAck: begin
          if (req.i3c) begin
            cfg.vif.device_i3c_od_send_bit(cfg.tc.i3c_tc, !req.dev_ack);
          end else begin
            cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, !req.dev_ack);
          end
          `uvm_info(`gfn, $sformatf("Device sent %d[%s]", !req.dev_ack, req.dev_ack ? "ACK" : "NACK"
                    ), UVM_MEDIUM)
          bus_state = DrvSelectNext;
        end

        DrvSelectNext: begin
          if (req.dev_ack) begin
            if (req.is_daa) begin
              bus_state = DrvDAA;
            end else if (req.dir) begin
              if (req.i3c) bus_state = DrvRdPushPull;
              else bus_state = DrvRd;
            end else begin
              if (req.i3c) bus_state = DrvWrPushPull;
              else bus_state = DrvWr;
            end
          end else begin
            bus_state = DrvStop;
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
              cfg.vif.device_i3c_od_send_bit(cfg.tc.i3c_tc, req.data[i][j]);
            end
          end
          for (int j = 7; j >= 0; j--) begin
            cfg.vif.sample_target_data(data[j]);
          end
          rsp.data.push_back(data);
          cfg.vif.device_i3c_od_send_bit(cfg.tc.i3c_tc, !req.T_bit[0]);
          bus_state = DrvStop;
        end

        DrvRd: begin
          bit ack;
          for (int i = 0; i < req.data_cnt; i++) begin
            for (int j = 7; j >= 0; j--) begin
              cfg.vif.device_i2c_send_bit(cfg.tc.i2c_tc, req.data[i][j]);
            end
            cfg.vif.wait_for_host_ack_or_nack(.ack_r(ack));
            rsp.T_bit.push_back(ack);
            if (!ack) begin
              bus_state = DrvStop;
              break;
            end
          end
        end

        DrvRdPushPull: begin
          for (int i = 0; i < req.data_cnt; i++) begin
            for (int j = 7; j >= 0; j--) begin
              cfg.vif.device_i3c_send_bit(cfg.tc.i3c_tc, req.data[i][j]);
            end
            cfg.vif.device_send_T_bit(cfg.tc.i3c_tc, req.T_bit[i]);
          end
          bus_state = DrvStop;
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
          bus_state = DrvStop;
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
                      "Device sampled data[%0d]=%d, T_bit=%b", i, rsp.data[i], rsp.T_bit[i]),
                      UVM_MEDIUM)
            if ((^data) ^ t_bit == 0) begin
              `uvm_warning(`gfn, $sformatf("Device sampled data is incorrect!"))
              break;
            end
          end
          bus_state = DrvStop;
        end
        default: begin
          `uvm_fatal(`gfn, $sformatf("\n device_driver, received invalid request"))
        end
      endcase
    end
  endtask : drive_device_item

  virtual task process_reset();
    @(negedge cfg.vif.rst_ni);
    release_bus();
    `uvm_info(`gfn, "\n driver is reset", UVM_DEBUG)
  endtask : process_reset

  virtual task release_bus();
    `uvm_info(`gfn, $sformatf("%s driver released the bus",
                              cfg.if_mode == Host ? "Host" : "Device"), UVM_HIGH)
    if (cfg.if_mode == Host) begin
      // TODO for host mode
    end else begin
      cfg.vif.device_sda_pp_en = 1'b0;
      cfg.vif.device_sda_o = 1'b1;
    end
  endtask : release_bus

  task drive_scl();
    // TODO for host mode
  endtask
endclass
