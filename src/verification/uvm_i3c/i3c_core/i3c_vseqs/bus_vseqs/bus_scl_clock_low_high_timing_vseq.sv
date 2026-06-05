class bus_scl_clock_low_high_timing_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_scl_clock_low_high_timing_vseq)

  localparam int unsigned RISE_CYCLES = 1;
  localparam int unsigned FALL_CYCLES = 2;

  function new(string name = "bus_scl_clock_low_high_timing_vseq");
    super.new(name);
  endfunction

  task body();
    run_i3c_timing_profile("I3C SDR profile", i3c_sdr, 0, 0);
    run_i3c_timing_profile("I3C SDR stretched profile", i3c_sdr, 4, 3);
    run_i2c_timing_profile("I2C legacy profile", i2c_400);

    force_scl_generator_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
    wait_sync_cycles(1);
    release_scl_generator_controls();
    `uvm_info(`gfn, "BUS_005 SCL low/high I3C and I2C timing stimulus completed", UVM_LOW)
  endtask

  virtual task run_i3c_timing_profile(string profile_name, i3c_timing_t tc,
                                      int unsigned extra_low, int unsigned extra_high);
    run_timing_profile(profile_name, RISE_CYCLES, FALL_CYCLES,
                       ns_to_cycles(tc.tClockLowPP) + extra_low,
                       ns_to_cycles(tc.tClockPulse) + extra_high,
                       ns_to_cycles(tc.tSetupStart), ns_to_cycles(tc.tHoldStart),
                       ns_to_cycles(tc.tSetupStop), ns_to_cycles(tc.tSetupBit),
                       ns_to_cycles(tc.tHoldBit));
  endtask

  virtual task run_i2c_timing_profile(string profile_name, i2c_timing_t tc);
    run_timing_profile(profile_name, RISE_CYCLES, FALL_CYCLES, ns_to_cycles(tc.tClockLow),
                       ns_to_cycles(tc.tClockPulse), ns_to_cycles(tc.tSetupStart),
                       ns_to_cycles(tc.tHoldStart), ns_to_cycles(tc.tSetupStop),
                       ns_to_cycles(tc.tSetupBit), ns_to_cycles(tc.tHoldBit));
  endtask

  virtual task run_timing_profile(string profile_name, int unsigned t_r, int unsigned t_f,
                                  int unsigned t_low, int unsigned t_high, int unsigned t_su_sta,
                                  int unsigned t_hd_sta, int unsigned t_su_sto,
                                  int unsigned t_su_dat, int unsigned t_hd_dat);
    int unsigned clock_period_cycles;

    program_timing_registers(t_r, t_f, t_low, t_high, t_su_sta, t_hd_sta, t_su_sto, t_su_dat,
                             t_hd_dat);
    reset_scl_generator_to_idle();
    start_scl_clocking();
    clock_period_cycles = t_low + t_f + t_high + t_r + 2;
    wait_sync_cycles(t_su_sta + t_hd_sta + (3 * clock_period_cycles) + 12);
    `uvm_info(`gfn, $sformatf("BUS_005 clock stimulus completed for %s", profile_name),
              UVM_HIGH)
  endtask

  virtual task start_scl_clocking();
    set_scl_generator_controls_now(1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
    @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    #1;
    set_scl_generator_controls_now(1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
  endtask

endclass
