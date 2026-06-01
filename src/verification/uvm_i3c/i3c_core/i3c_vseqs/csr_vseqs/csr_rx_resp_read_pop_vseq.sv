class csr_rx_resp_read_pop_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_rx_resp_read_pop_vseq)

  function new(string name = "csr_rx_resp_read_pop_vseq");
    super.new(name);
  endfunction

  task body();
    check_port_empty("RX", ADDR_RX_DATA, QS_RX_EMPTY_BIT, "at reset");
    check_port_empty("RESP", ADDR_RESP, QS_RESP_EMPTY_BIT, "at reset");

    backdoor_load_rx_queue(32'hAAAA_BBBB, 32'hCCCC_DDDD);
    drain_two_entries("RX", ADDR_RX_DATA, QS_RX_EMPTY_BIT, 32'hAAAA_BBBB, 32'hCCCC_DDDD);
    check_port_empty("RX", ADDR_RX_DATA, QS_RX_EMPTY_BIT, "after RX drain");

    backdoor_load_resp_queue(32'h0123_0004, 32'h0456_0008);
    drain_two_entries("RESP", ADDR_RESP, QS_RESP_EMPTY_BIT, 32'h0123_0004, 32'h0456_0008);
    check_port_empty("RESP", ADDR_RESP, QS_RESP_EMPTY_BIT, "after RESP drain");

    `uvm_info(`gfn, "CSR RX/RESP read pop checks passed", UVM_LOW)
  endtask

  task drain_two_entries(string port_name, bit [11:0] port_addr, int empty_bit, bit [31:0] exp0,
                         bit [31:0] exp1);
    bit [31:0] data;

    reg_read(port_addr, data);
    `DV_CHECK_EQ(data, exp0, $sformatf("csr_rx_resp_read_pop_vseq: %s first read mismatch",
                                       port_name))
    settle_cycles();
    check_empty_flag(port_name, empty_bit, 1'b0, "after first pop");

    reg_read(port_addr, data);
    `DV_CHECK_EQ(data, exp1, $sformatf("csr_rx_resp_read_pop_vseq: %s second read mismatch",
                                       port_name))
    settle_cycles();
    check_empty_flag(port_name, empty_bit, 1'b1, "after second pop");
  endtask

  task check_port_empty(string port_name, bit [11:0] port_addr, int empty_bit, string ctxt);
    bit [31:0] data;

    check_empty_flag(port_name, empty_bit, 1'b1, ctxt);

    reg_read(port_addr, data);
    `DV_CHECK_EQ(data, 32'h0000_0000,
                 $sformatf("csr_rx_resp_read_pop_vseq: %s empty read should return zero %s",
                           port_name, ctxt))
    settle_cycles();
    check_empty_flag(port_name, empty_bit, 1'b1, $sformatf("%s after first empty read", ctxt));

    reg_read(port_addr, data);
    `DV_CHECK_EQ(data, 32'h0000_0000,
                 $sformatf(
                     "csr_rx_resp_read_pop_vseq: %s repeated empty read should return zero %s",
                     port_name, ctxt))
    settle_cycles();
    check_empty_flag(port_name, empty_bit, 1'b1, $sformatf("%s after repeated empty read", ctxt));
  endtask

  task check_empty_flag(string port_name, int empty_bit, bit exp_empty, string ctxt);
    bit [31:0] status;

    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(status[empty_bit], exp_empty,
                 $sformatf("csr_rx_resp_read_pop_vseq: %s empty flag mismatch %s", port_name, ctxt))
  endtask

  task backdoor_load_rx_queue(bit [31:0] data0, bit [31:0] data1);
    hdl_deposit_checked("tb_i3c_top.dut.u_queues.rx_fifo.mem[0]", data0);
    hdl_deposit_checked("tb_i3c_top.dut.u_queues.rx_fifo.mem[1]", data1);
    hdl_deposit_checked("tb_i3c_top.dut.u_queues.rx_fifo.rptr_q", '0);
    hdl_deposit_checked("tb_i3c_top.dut.u_queues.rx_fifo.wptr_q", 2);
    settle_cycles();
    check_empty_flag("RX", QS_RX_EMPTY_BIT, 1'b0, "after backdoor load");
  endtask

  task backdoor_load_resp_queue(bit [31:0] resp0, bit [31:0] resp1);
    hdl_deposit_checked("tb_i3c_top.dut.u_queues.resp_fifo.mem[0]", resp0);
    hdl_deposit_checked("tb_i3c_top.dut.u_queues.resp_fifo.mem[1]", resp1);
    hdl_deposit_checked("tb_i3c_top.dut.u_queues.resp_fifo.rptr_q", '0);
    hdl_deposit_checked("tb_i3c_top.dut.u_queues.resp_fifo.wptr_q", 2);
    settle_cycles();
    check_empty_flag("RESP", QS_RESP_EMPTY_BIT, 1'b0, "after backdoor load");
  endtask

endclass
