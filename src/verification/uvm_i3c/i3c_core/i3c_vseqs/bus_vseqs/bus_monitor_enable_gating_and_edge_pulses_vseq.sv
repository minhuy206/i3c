class bus_monitor_enable_gating_and_edge_pulses_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_monitor_enable_gating_and_edge_pulses_vseq)

  function new(string name = "bus_monitor_enable_gating_and_edge_pulses_vseq");
    super.new(name);
  endfunction

  virtual task check_events_low(string ctxt);
    `DV_CHECK_EQ(hdl_read_bit(bus_paths.start_det_path), 1'b0,
                 $sformatf("%s: start_det should stay low", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(bus_paths.rstart_det_path), 1'b0,
                 $sformatf("%s: rstart_det should stay low", ctxt))
    `DV_CHECK_EQ(hdl_read_bit(bus_paths.stop_det_path), 1'b0,
                 $sformatf("%s: stop_det should stay low", ctxt))
  endtask

  virtual task check_events_low_for_cycles(string ctxt, int unsigned cycles = 6);
    repeat (cycles) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      #1;
      check_events_low(ctxt);
    end
  endtask

  virtual task expect_one_cycle_pulse(string path, string ctxt, int unsigned timeout = 12);
    bit seen;

    seen = 1'b0;
    for (int unsigned i = 0; i < timeout; i++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      #1;
      if (hdl_read_bit(path)) begin
        seen = 1'b1;
        @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
        #1;
        `DV_CHECK_EQ(hdl_read_bit(path), 1'b0,
                     $sformatf("%s: %s pulse should last exactly one cycle", ctxt, path))
        return;
      end
    end

    `uvm_error(`gfn, $sformatf("%s: did not observe pulse on %s within %0d cycles", ctxt, path,
                               timeout))
  endtask

  virtual task drive_and_expect_pulse(bit scl, bit sda, string path, string ctxt);
    force_phy_inputs(scl, sda);
    expect_one_cycle_pulse(path, ctxt);
  endtask

  virtual task body();
    reg_write(ADDR_T_R, 32'h0);
    reg_write(ADDR_T_F, 32'h0);
    disable_dut();

    force_phy_inputs(1'b1, 1'b1);
    wait_sync_cycles(3);
    check_events_low("BUS_005 disabled idle");

    force_phy_inputs(1'b1, 1'b0);
    check_events_low_for_cycles("BUS_005 disabled START-like SDA falling");

    force_phy_inputs(1'b1, 1'b1);
    check_events_low_for_cycles("BUS_005 disabled STOP-like SDA rising");

    force_phy_inputs(1'b1, 1'b0);
    check_events_low_for_cycles("BUS_005 disabled stale START candidate");

    enable_dut();
    check_events_low_for_cycles("BUS_005 after enable with stale disabled candidate", 3);

    force_phy_inputs(1'b0, 1'b1);
    expect_one_cycle_pulse(bus_paths.scl_neg_edge_path, "BUS_005 SCL negedge pulse");

    drive_and_expect_pulse(1'b1, 1'b1, bus_paths.scl_pos_edge_path, "BUS_005 SCL posedge pulse");

    force_phy_inputs(1'b0, 1'b1);
    expect_one_cycle_pulse(bus_paths.scl_neg_edge_path, "BUS_005 SCL low before SDA edge checks");

    drive_and_expect_pulse(1'b0, 1'b0, bus_paths.sda_neg_edge_path, "BUS_005 SDA negedge pulse");
    drive_and_expect_pulse(1'b0, 1'b1, bus_paths.sda_pos_edge_path, "BUS_005 SDA posedge pulse");

    force_phy_inputs(1'b1, 1'b1);
    wait_sync_cycles(3);
    drive_and_expect_pulse(1'b1, 1'b0, bus_paths.start_det_path, "BUS_005 START pulse");

    force_phy_inputs(1'b0, 1'b0);
    wait_sync_cycles(3);
    force_phy_inputs(1'b0, 1'b1);
    wait_sync_cycles(3);
    force_phy_inputs(1'b1, 1'b1);
    wait_sync_cycles(3);
    drive_and_expect_pulse(1'b1, 1'b0, bus_paths.rstart_det_path, "BUS_005 RSTART pulse");

    drive_and_expect_pulse(1'b1, 1'b1, bus_paths.stop_det_path, "BUS_005 STOP pulse");

    release_phy_inputs();
  endtask

endclass
