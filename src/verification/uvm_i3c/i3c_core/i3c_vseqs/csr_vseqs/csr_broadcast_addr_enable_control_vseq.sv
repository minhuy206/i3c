class csr_broadcast_addr_enable_control_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_broadcast_addr_enable_control_vseq)

  function new(string name = "csr_broadcast_addr_enable_control_vseq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] data;

    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                 "csr_broadcast_addr_enable_control_vseq: controller should start disabled")
    `DV_CHECK_EQ(
        data[HC_CTRL_BROADCAST_ADDR_ENABLE_BIT], 1'b0,
        "csr_broadcast_addr_enable_control_vseq: BROADCAST_ADDR_ENABLE should start disabled")

    fork
      check_no_host_start_for_cycles(100, "csr_broadcast_addr_enable_control_vseq");
      begin
        reg_write(ADDR_HC_CONTROL, 32'h0000_0004);
        reg_read(ADDR_HC_CONTROL, data);
        `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                     "csr_broadcast_addr_enable_control_vseq: BROADCAST_ADDR_ENABLE must not enable controller")
        `DV_CHECK_EQ(
            data[HC_CTRL_BROADCAST_ADDR_ENABLE_BIT], 1'b1,
            "csr_broadcast_addr_enable_control_vseq: BROADCAST_ADDR_ENABLE should be writable")
      end
    join

    reg_read(ADDR_HC_STATUS, data);
    `DV_CHECK_EQ(data[HC_STS_FSM_IDLE_BIT], 1'b1,
                 "csr_broadcast_addr_enable_control_vseq: controller should remain idle")

    reg_write(ADDR_HC_CONTROL, 32'h0000_0000);
    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                 "csr_broadcast_addr_enable_control_vseq: controller should remain disabled")
    `DV_CHECK_EQ(data[HC_CTRL_BROADCAST_ADDR_ENABLE_BIT], 1'b0,
                 "csr_broadcast_addr_enable_control_vseq: BROADCAST_ADDR_ENABLE should clear")

    `uvm_info(`gfn, "CSR broadcast address enable control checks passed", UVM_LOW)
  endtask

endclass
