class csr_rx_resp_read_pop_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_rx_resp_read_pop_vseq)

  function new(string name = "csr_rx_resp_read_pop_vseq");
    super.new(name);
  endfunction

  task body();
    exercise_empty_reads(ADDR_RX_DATA);
    exercise_empty_reads(ADDR_RESP);

    backdoor_load_rx_queue(32'hAAAA_BBBB, 32'hCCCC_DDDD);
    drain_two_entries(rx_paths.name, ADDR_RX_DATA, 32'hAAAA_BBBB, 32'hCCCC_DDDD);
    exercise_empty_reads(ADDR_RX_DATA);

    backdoor_load_resp_queue(32'h0123_0004, 32'h0456_0008);
    drain_two_entries(resp_paths.name, ADDR_RESP, 32'h0123_0004, 32'h0456_0008);
    exercise_empty_reads(ADDR_RESP);

    `uvm_info(`gfn, "CSR RX/RESP read pop checks passed", UVM_LOW)
  endtask

  task drain_two_entries(string port_name, bit [11:0] port_addr, bit [31:0] exp0,
                         bit [31:0] exp1);
    bit [31:0] data;

    reg_read(port_addr, data);
    `DV_CHECK_EQ(data, exp0, $sformatf("csr_rx_resp_read_pop_vseq: %s first read mismatch",
                                       port_name))
    settle_cycles();

    reg_read(port_addr, data);
    `DV_CHECK_EQ(data, exp1, $sformatf("csr_rx_resp_read_pop_vseq: %s second read mismatch",
                                       port_name))
    settle_cycles();
  endtask

  task exercise_empty_reads(bit [11:0] port_addr);
    bit [31:0] data;

    reg_read(port_addr, data);
    settle_cycles();

    reg_read(port_addr, data);
    settle_cycles();
  endtask

  task backdoor_load_rx_queue(bit [31:0] data0, bit [31:0] data1);
    backdoor_write_fifo_entry(rx_paths, 0, data0);
    backdoor_write_fifo_entry(rx_paths, 1, data1);
    backdoor_set_fifo_level(rx_paths, 2);
    settle_cycles();
  endtask

  task backdoor_load_resp_queue(bit [31:0] resp0, bit [31:0] resp1);
    backdoor_write_fifo_entry(resp_paths, 0, resp0);
    backdoor_write_fifo_entry(resp_paths, 1, resp1);
    backdoor_set_fifo_level(resp_paths, 2);
    settle_cycles();
  endtask

endclass
