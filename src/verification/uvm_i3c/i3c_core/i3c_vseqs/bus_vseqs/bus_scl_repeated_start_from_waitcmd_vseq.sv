class bus_scl_repeated_start_from_waitcmd_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_scl_repeated_start_from_waitcmd_vseq)

  localparam int unsigned RISE_CYCLES = 1;
  localparam int unsigned FALL_CYCLES = 1;
  localparam int unsigned STALL_CYCLES = 8;

  function new(string name = "bus_scl_repeated_start_from_waitcmd_vseq");
    super.new(name);
  endfunction

  task body();
    int unsigned t_low;
    int unsigned t_high;
    int unsigned t_su_sta;
    int unsigned t_hd_sta;
    int unsigned t_su_sto;
    int unsigned t_su_dat;
    int unsigned t_hd_dat;

    t_low    = ns_to_cycles(i3c_sdr.tClockLowPP);
    t_high   = ns_to_cycles(i3c_sdr.tClockPulse);
    t_su_sta = ns_to_cycles(i3c_sdr.tSetupStart);
    t_hd_sta = ns_to_cycles(i3c_sdr.tHoldStart);
    t_su_sto = ns_to_cycles(i3c_sdr.tSetupStop);
    t_su_dat = ns_to_cycles(i3c_sdr.tSetupBit);
    t_hd_dat = ns_to_cycles(i3c_sdr.tHoldBit);

    reset_and_program_timing(RISE_CYCLES, FALL_CYCLES, t_low, t_high, t_su_sta, t_hd_sta,
                             t_su_sto, t_su_dat, t_hd_dat);

    start_generator();
    wait_sync_cycles(t_su_sta + t_hd_sta + t_low + FALL_CYCLES + STALL_CYCLES + 8);

    set_scl_generator_controls_now(1'b0, 1'b1, 1'b0, 1'b0, 1'b0);
    wait_sync_cycles(1);
    set_scl_generator_controls_now(1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wait_sync_cycles(RISE_CYCLES + t_su_sta + t_hd_sta + t_low + FALL_CYCLES + 16);

    force_scl_generator_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
    wait_sync_cycles(1);
    release_scl_generator_controls();
    `uvm_info(`gfn, "BUS_007 repeated START from WaitCmd stimulus completed", UVM_LOW)
  endtask

endclass
