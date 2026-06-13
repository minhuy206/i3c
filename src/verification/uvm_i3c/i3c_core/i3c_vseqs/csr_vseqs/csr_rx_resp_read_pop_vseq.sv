class csr_rx_resp_read_pop_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_rx_resp_read_pop_vseq)

  function new(string name = "csr_rx_resp_read_pop_vseq");
    super.new(name);
  endfunction

  task body();
    exercise_empty_reads(rx_paths, ADDR_RX_DATA);
    exercise_empty_reads(resp_paths, ADDR_RESP);

    // Subsequent queue states are synthetic backdoor states, not reset defaults.
    disable_dut();
    settle_cycles();

    backdoor_load_rx_queue(32'hAAAA_BBBB, 32'hCCCC_DDDD);
    check_port_depth(rx_paths, 2, "after RX backdoor load");
    drain_two_entries(rx_paths, ADDR_RX_DATA, 32'hAAAA_BBBB, 32'hCCCC_DDDD);
    exercise_empty_reads(rx_paths, ADDR_RX_DATA);

    backdoor_load_resp_queue(32'h0123_0004, 32'h0456_0008);
    check_port_depth(resp_paths, 2, "after RESP backdoor load");
    drain_two_entries(resp_paths, ADDR_RESP, 32'h0123_0004, 32'h0456_0008);
    exercise_empty_reads(resp_paths, ADDR_RESP);

    `uvm_info(`gfn, "CSR RX/RESP read pop checks passed", UVM_LOW)
  endtask

  task drain_two_entries(queue_hdl_paths_t paths, bit [11:0] port_addr, bit [31:0] exp0,
                         bit [31:0] exp1);
    bit [31:0] data;

    reg_read(port_addr, data);
    `DV_CHECK_EQ(data, exp0, $sformatf("csr_rx_resp_read_pop_vseq: %s first read mismatch",
                                       paths.name))
    settle_cycles();
    check_port_depth(paths, 1, "after first read pop");

    reg_read(port_addr, data);
    `DV_CHECK_EQ(data, exp1, $sformatf("csr_rx_resp_read_pop_vseq: %s second read mismatch",
                                       paths.name))
    settle_cycles();
    check_port_depth(paths, 0, "after second read pop");
  endtask

  task exercise_empty_reads(queue_hdl_paths_t paths, bit [11:0] port_addr);
    bit [31:0] data;
    bit [31:0] rptr_before;
    bit [31:0] wptr_before;
    bit [31:0] depth_before;

    check_port_depth(paths, 0, "before empty reads");
    rptr_before  = hdl_read_word(paths.rptr_path);
    wptr_before  = hdl_read_word(paths.wptr_path);
    depth_before = hdl_read_word(paths.depth_path);

    reg_read(port_addr, data);
    `DV_CHECK_EQ(data, 32'h0, $sformatf(
                 "csr_rx_resp_read_pop_vseq: %s first empty read should return zero",
                 paths.name))
    settle_cycles();
    check_no_empty_read_underflow(paths, rptr_before, wptr_before, depth_before,
                                  "after first empty read");

    reg_read(port_addr, data);
    `DV_CHECK_EQ(data, 32'h0, $sformatf(
                 "csr_rx_resp_read_pop_vseq: %s second empty read should return zero",
                 paths.name))
    settle_cycles();
    check_no_empty_read_underflow(paths, rptr_before, wptr_before, depth_before,
                                  "after second empty read");
  endtask

  task check_port_depth(queue_hdl_paths_t paths, int unsigned exp_depth, string ctxt);
    bit [31:0] status;
    bit        exp_empty;

    settle_cycles();
    reg_read(ADDR_QUEUE_STATUS, status);
    exp_empty = (exp_depth == 0);

    `DV_CHECK_EQ(hdl_read_word(paths.depth_path), 32'(exp_depth), $sformatf(
                 "csr_rx_resp_read_pop_vseq: %s depth mismatch %s", paths.name, ctxt))
    `DV_CHECK_EQ(status[paths.full_bit], 1'b0, $sformatf(
                 "csr_rx_resp_read_pop_vseq: %s full flag should stay clear %s",
                 paths.name, ctxt))
    `DV_CHECK_EQ(status[paths.empty_bit], exp_empty, $sformatf(
                 "csr_rx_resp_read_pop_vseq: %s empty flag mismatch %s", paths.name, ctxt))
  endtask

  task check_no_empty_read_underflow(queue_hdl_paths_t paths, bit [31:0] exp_rptr,
                                     bit [31:0] exp_wptr, bit [31:0] exp_depth,
                                     string ctxt);
    `DV_CHECK_EQ(hdl_read_word(paths.rptr_path), exp_rptr, $sformatf(
                 "csr_rx_resp_read_pop_vseq: %s rptr changed on empty read %s",
                 paths.name, ctxt))
    `DV_CHECK_EQ(hdl_read_word(paths.wptr_path), exp_wptr, $sformatf(
                 "csr_rx_resp_read_pop_vseq: %s wptr changed on empty read %s",
                 paths.name, ctxt))
    `DV_CHECK_EQ(hdl_read_word(paths.depth_path), exp_depth, $sformatf(
                 "csr_rx_resp_read_pop_vseq: %s depth changed on empty read %s",
                 paths.name, ctxt))
    check_port_depth(paths, 0, ctxt);
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
