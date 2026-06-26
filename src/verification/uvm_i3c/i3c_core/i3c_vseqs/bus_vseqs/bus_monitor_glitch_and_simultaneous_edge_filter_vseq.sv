class bus_monitor_glitch_and_simultaneous_edge_filter_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_monitor_glitch_and_simultaneous_edge_filter_vseq)

  localparam int unsigned FILTER_DELAY_CYCLES = 4;
  localparam int unsigned SHORT_GLITCH_CYCLES = 2;
  localparam int unsigned EVENT_TIMEOUT_CYCLES = 18;

  function new(string name = "bus_monitor_glitch_and_simultaneous_edge_filter_vseq");
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

  virtual task check_events_low_for_cycles(string ctxt, int unsigned cycles);
    repeat (cycles) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      #1;
      check_events_low(ctxt);
    end
  endtask

  virtual task reset_monitor_context(bit scl, bit sda, string ctxt);
    disable_dut();
    force_phy_inputs(scl, sda);
    force_hard_reset();
    wait_sync_cycles(2);
    release_hard_reset();

    reg_write(ADDR_T_R, FILTER_DELAY_CYCLES);
    reg_write(ADDR_T_F, FILTER_DELAY_CYCLES);
    enable_dut();
    wait_sync_cycles(FILTER_DELAY_CYCLES + 6);
    check_events_low(ctxt);
  endtask

  virtual task expect_event_pulse(string path, string ctxt, int unsigned timeout = EVENT_TIMEOUT_CYCLES);
    bit seen;

    seen = 1'b0;
    for (int unsigned i = 0; i < timeout; i++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      #1;
      if (hdl_read_bit(path)) begin
        seen = 1'b1;
        break;
      end
    end

    if (!seen) begin
      `uvm_error(`gfn, $sformatf("%s: did not observe expected pulse on %s within %0d cycles",
                                 ctxt, path, timeout))
    end
  endtask

  virtual task run_sda_low_glitch_reject();
    reset_monitor_context(1'b1, 1'b1, "BUS_004 low-glitch idle");

    force_phy_inputs(1'b1, 1'b0);
    check_events_low_for_cycles("BUS_004 short SDA-low glitch while SCL high", SHORT_GLITCH_CYCLES);

    force_phy_inputs(1'b1, 1'b1);
    check_events_low_for_cycles("BUS_004 after rejected SDA-low glitch", FILTER_DELAY_CYCLES + 8);
  endtask

  virtual task run_sda_high_glitch_reject();
    reset_monitor_context(1'b0, 1'b0, "BUS_004 high-glitch low bus setup");

    force_phy_inputs(1'b1, 1'b0);
    check_events_low_for_cycles("BUS_004 SCL high with SDA already low", FILTER_DELAY_CYCLES + 6);

    force_phy_inputs(1'b1, 1'b1);
    check_events_low_for_cycles("BUS_004 short SDA-high glitch while SCL high", SHORT_GLITCH_CYCLES);

    force_phy_inputs(1'b1, 1'b0);
    check_events_low_for_cycles("BUS_004 after rejected SDA-high glitch", FILTER_DELAY_CYCLES + 8);
  endtask

  virtual task run_simultaneous_falling_edge_reject();
    reset_monitor_context(1'b1, 1'b1, "BUS_004 simultaneous falling-edge idle");

    force_phy_inputs(1'b0, 1'b0);
    check_events_low_for_cycles("BUS_004 simultaneous SCL/SDA falling edges",
                                FILTER_DELAY_CYCLES + 8);
  endtask

  virtual task run_simultaneous_rising_edge_reject();
    reset_monitor_context(1'b0, 1'b0, "BUS_004 simultaneous rising-edge setup");

    force_phy_inputs(1'b1, 1'b1);
    check_events_low_for_cycles("BUS_004 simultaneous SCL/SDA rising edges",
                                FILTER_DELAY_CYCLES + 8);
  endtask

  virtual task run_valid_event_sanity();
    reset_monitor_context(1'b1, 1'b1, "BUS_004 valid-event sanity idle");

    force_phy_inputs(1'b1, 1'b0);
    expect_event_pulse(bus_paths.start_det_path, "BUS_004 valid START after rejects");

    force_phy_inputs(1'b1, 1'b1);
    expect_event_pulse(bus_paths.stop_det_path, "BUS_004 valid STOP after rejects");
  endtask

  task body();
    run_sda_low_glitch_reject();
    run_sda_high_glitch_reject();
    run_simultaneous_falling_edge_reject();
    run_simultaneous_rising_edge_reject();
    run_valid_event_sanity();

    release_phy_inputs();
  endtask

endclass
