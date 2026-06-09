class bus_scl_start_stop_timing_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_scl_start_stop_timing_vseq)

  function new(string name = "bus_scl_start_stop_timing_vseq");
    super.new(name);
  endfunction

  task body();
    run_i3c_timing_profile("I3C SDR profile", i3c_sdr);
    run_i2c_timing_profile("I2C legacy profile", i2c_400);

    hdl_release_checked(bus_paths.scl_gen_scl_i_path);
    release_scl_generator_timing_mode();
    release_scl_generator_controls();
    `uvm_info(`gfn, "BUS_004 generated START/STOP I3C and I2C timing stimulus completed",
              UVM_LOW)
  endtask

  virtual task run_i3c_timing_profile(string profile_name, i3c_timing_t tc);
    run_timing_profile(profile_name, 0, 0, ns_to_cycles(tc.tClockLowPP), ns_to_cycles(tc.tClockPulse
                       ), ns_to_cycles(tc.tSetupStart), ns_to_cycles(tc.tHoldStart), ns_to_cycles(
                       tc.tSetupStop), ns_to_cycles(tc.tSetupBit), ns_to_cycles(tc.tHoldBit),
                       ns_to_cycles(tc.tHoldStop), ns_to_cycles(tc.tClockLowOD), 1'b1);
  endtask

  virtual task run_i2c_timing_profile(string profile_name, i2c_timing_t tc);
    run_timing_profile(profile_name, 0, 0, ns_to_cycles(tc.tClockLow), ns_to_cycles(tc.tClockPulse),
                       ns_to_cycles(tc.tSetupStart), ns_to_cycles(tc.tHoldStart), ns_to_cycles(
                       tc.tSetupStop), ns_to_cycles(tc.tSetupBit), ns_to_cycles(tc.tHoldBit),
                       ns_to_cycles(tc.tHoldStop), RST_T_LOW_OD, 1'b0);
  endtask

  virtual task run_timing_profile(string profile_name, int unsigned t_r, int unsigned t_f,
                                  int unsigned t_low, int unsigned t_high, int unsigned t_su_sta,
                                  int unsigned t_hd_sta, int unsigned t_su_sto,
                                  int unsigned t_su_dat, int unsigned t_hd_dat,
                                  int unsigned t_bus_free, int unsigned t_low_od,
                                  bit use_od_low);
    int unsigned selected_t_low;

    program_timing_registers(t_r, t_f, t_low, t_high, t_su_sta, t_hd_sta, t_su_sto, t_su_dat,
                             t_hd_dat, t_bus_free, t_low_od);
    force_scl_generator_timing_mode(use_od_low);
    reset_scl_generator_to_idle();

    selected_t_low = use_od_low ? t_low_od : t_low;
    drive_start_timing_stimulus(profile_name, t_su_sta, t_hd_sta, selected_t_low, t_f);
    drive_stop_timing_stimulus(profile_name, t_su_sto, t_bus_free);
  endtask

  virtual task drive_start_timing_stimulus(string profile_name, int unsigned t_su_sta,
                                           int unsigned t_hd_sta, int unsigned t_low,
                                           int unsigned t_f);
    start_generator(1'b0);
    wait_sync_cycles(t_su_sta + t_hd_sta + t_low + t_f + 8);
    `uvm_info(`gfn, $sformatf("BUS_004 START stimulus completed for %s", profile_name),
              UVM_HIGH)
  endtask

  virtual task drive_stop_timing_stimulus(string profile_name, int unsigned t_su_sto,
                                          int unsigned t_bus_free);
    hdl_force_checked(bus_paths.scl_gen_scl_i_path, 1'b1);
    set_scl_generator_controls_now(1'b0, 1'b0, 1'b1, 1'b0, 1'b0);
    wait_sync_cycles(1);

    set_scl_generator_controls_now(1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wait_sync_cycles(t_su_sto + t_bus_free + 8);
    hdl_release_checked(bus_paths.scl_gen_scl_i_path);
    wait_sync_cycles(2);
    `uvm_info(`gfn, $sformatf("BUS_004 STOP stimulus completed for %s", profile_name),
              UVM_HIGH)
  endtask

endclass
