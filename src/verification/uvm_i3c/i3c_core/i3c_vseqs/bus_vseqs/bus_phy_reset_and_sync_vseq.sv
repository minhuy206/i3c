class bus_phy_reset_and_sync_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_phy_reset_and_sync_vseq)

  function new(string name = "bus_phy_reset_and_sync_vseq");
    super.new(name);
  endfunction

  task body();
    force_phy_inputs(1'b0, 1'b0);

    force_hard_reset();
    wait_sync_cycles(2);

    release_hard_reset();
    wait_sync_cycles(4);

    force_phy_inputs(1'b1, 1'b0);
    wait_sync_cycles(4);

    force_phy_inputs(1'b0, 1'b1);
    wait_sync_cycles(4);

    force_phy_inputs(1'b1, 1'b1);
    wait_sync_cycles(4);

    release_phy_inputs();
    wait_sync_cycles(4);
  endtask

endclass
