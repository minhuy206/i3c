class fifo_simultaneous_read_write_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_simultaneous_read_write_vseq)

  function new(string name = "fifo_simultaneous_read_write_vseq");
    super.new(name);
  endfunction

  task body();
    check_all_queues_empty("at reset");

    exercise_queue(cmd_paths);
    exercise_queue(tx_paths);
    exercise_queue(rx_paths);
    exercise_queue(resp_paths);

    check_all_queues_empty("at end of FIFO_003");
    `uvm_info(`gfn, "FIFO simultaneous read/write checks passed", UVM_LOW)
  endtask

  virtual task force_fifo_read_write_one_cycle(queue_hdl_paths_t paths, uvm_hdl_data_t wr_data,
                                               uvm_hdl_data_t exp_rd_data, string ctxt);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_force_checked(paths.write_data_path, wr_data);
    hdl_force_checked(paths.write_valid_path, 1'b1);
    hdl_force_checked(paths.read_ready_path, 1'b1);

    `DV_CHECK_EQ(hdl_read_bit(paths.write_ready_path), 1'b1, $sformatf(
                 "%s: %s wready should be high for simultaneous cycle %s", get_type_name(),
                 paths.name, ctxt))
    `DV_CHECK_EQ(hdl_read_bit(paths.read_valid_path), 1'b1, $sformatf(
                 "%s: %s rvalid should be high for simultaneous cycle %s", get_type_name(),
                 paths.name, ctxt))
    check_queue_read_data(paths, exp_rd_data, ctxt);

    @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_release_checked(paths.read_ready_path);
    hdl_release_checked(paths.write_valid_path);
    hdl_release_checked(paths.write_data_path);
    settle_cycles(1);
  endtask

  virtual task drain_queue(queue_hdl_paths_t paths, int unsigned count, int unsigned first_index,
                           uvm_hdl_data_t final_entry, string ctxt);
    uvm_hdl_data_t exp;

    for (int unsigned i = 0; i < count; i++) begin
      wait_hdl_bit(paths.read_valid_path, 1'b1, $sformatf("%s before pop %0d", ctxt, i));
      exp = (i == count - 1) ? final_entry : make_queue_entry(paths, first_index + i);
      check_queue_read_data(paths, exp, $sformatf("%s pop %0d", ctxt, i));
      force_fifo_read_one_cycle(paths);
      check_fifo_state(paths, count - i - 1, $sformatf("%s after pop %0d", ctxt, i));
    end
  endtask

  virtual task run_simultaneous_case(queue_hdl_paths_t paths, int unsigned initial_depth,
                                     int unsigned base_index, string state_name);
    uvm_hdl_data_t wr_entry;
    string         ctxt;

    ctxt = $sformatf("%s %s", paths.name, state_name);
    fill_queue(paths, initial_depth, base_index, ctxt);

    wr_entry = make_queue_entry(paths, base_index + QueueDepth);
    force_fifo_read_write_one_cycle(paths, wr_entry, make_queue_entry(paths, base_index), ctxt);
    check_fifo_state(paths, initial_depth, $sformatf("%s after simultaneous read/write", ctxt));

    drain_queue(paths, initial_depth, base_index + 1, wr_entry, ctxt);
    check_read_blocked(paths, $sformatf("%s after final drain", ctxt));
  endtask

  virtual task exercise_queue(queue_hdl_paths_t paths);
    run_simultaneous_case(paths, 4, 0,  "mid-depth");
    run_simultaneous_case(paths, 7, 16, "near-full");
    run_simultaneous_case(paths, 1, 32, "near-empty");
  endtask

endclass
