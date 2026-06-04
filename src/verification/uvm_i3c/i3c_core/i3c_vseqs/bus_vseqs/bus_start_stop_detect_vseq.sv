class bus_start_stop_detect_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_start_stop_detect_vseq)

  function new(string name = "bus_start_stop_detect_vseq");
    super.new(name);
  endfunction

  task body();
    configure_bus_monitor_zero_delay();

    force_phy_inputs(1'b1, 1'b1);
    wait_sync_cycles(6);

    force_phy_inputs(1'b1, 1'b0);
    wait_sync_cycles(6);

    force_phy_inputs(1'b1, 1'b1);
    wait_sync_cycles(6);

    force_phy_inputs(1'b0, 1'b1);
    wait_sync_cycles(6);

    force_phy_inputs(1'b0, 1'b0);
    wait_sync_cycles(6);

    force_phy_inputs(1'b0, 1'b1);
    wait_sync_cycles(6);

    force_phy_inputs(1'b1, 1'b1);
    wait_sync_cycles(6);

    release_phy_inputs();
    `uvm_info(`gfn, "BUS_002 START/STOP detection checks passed", UVM_LOW)
  endtask

endclass
