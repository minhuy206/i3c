class fifo_flush_during_activity_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_flush_during_activity_vseq)

  function new(string name = "fifo_flush_during_activity_vseq");
    super.new(name);
  endfunction

  task body();
    check_all_queues_empty("at reset");

    exercise_queue(cmd_paths);
    exercise_queue(tx_paths);
    exercise_queue(rx_paths);
    exercise_queue(resp_paths);

    check_all_queues_empty("at end of FIFO_004");
    `uvm_info(`gfn, "FIFO flush during activity checks passed", UVM_LOW)
  endtask

  virtual function string flush_path(queue_hdl_paths_t paths);
    return {paths.fifo_path, ".flush_i"};
  endfunction

  virtual task force_flush_read_write_one_cycle(queue_hdl_paths_t paths, uvm_hdl_data_t wr_data,
                                                uvm_hdl_data_t exp_rd_data, string ctxt);
    string flush_i_path;

    flush_i_path = flush_path(paths);

    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_force_checked(paths.write_data_path, wr_data);
    hdl_force_checked(paths.write_valid_path, 1'b1);
    hdl_force_checked(paths.read_ready_path, 1'b1);
    hdl_force_checked(flush_i_path, 1'b1);

    `DV_CHECK_EQ(hdl_read_bit(paths.write_ready_path), 1'b1, $sformatf(
                 "%s: %s wready should be high during flush activity %s", get_type_name(),
                 paths.name, ctxt))
    `DV_CHECK_EQ(hdl_read_bit(paths.read_valid_path), 1'b1, $sformatf(
                 "%s: %s rvalid should be high during flush activity %s", get_type_name(),
                 paths.name, ctxt))
    check_queue_read_data(paths, exp_rd_data, ctxt);

    @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_release_checked(flush_i_path);
    hdl_release_checked(paths.read_ready_path);
    hdl_release_checked(paths.write_valid_path);
    hdl_release_checked(paths.write_data_path);
    settle_cycles(1);
  endtask

  virtual task push_and_pop_fresh_entry(queue_hdl_paths_t paths, uvm_hdl_data_t fresh_entry,
                                        string ctxt);
    wait_hdl_bit(paths.write_ready_path, 1'b1, $sformatf("%s before fresh push", ctxt));
    force_fifo_write_one_cycle(paths, fresh_entry);
    check_fifo_state(paths, 1, $sformatf("%s after fresh push", ctxt));

    wait_hdl_bit(paths.read_valid_path, 1'b1, $sformatf("%s before fresh pop", ctxt));
    check_queue_read_data(paths, fresh_entry, $sformatf("%s fresh pop", ctxt));
    force_fifo_read_one_cycle(paths);
    check_fifo_state(paths, 0, $sformatf("%s after fresh pop", ctxt));
  endtask

  virtual task exercise_queue(queue_hdl_paths_t paths);
    uvm_hdl_data_t flush_wr_entry;
    uvm_hdl_data_t fresh_entry;
    string         ctxt;

    ctxt = $sformatf("%s flush-during-activity", paths.name);
    fill_queue(paths, 3, 0, ctxt);

    flush_wr_entry = make_queue_entry(paths, QueueDepth);
    force_flush_read_write_one_cycle(paths, flush_wr_entry, make_queue_entry(paths, 0), ctxt);

    check_fifo_state(paths, 0, $sformatf("%s after flush", ctxt));
    check_read_blocked(paths, $sformatf("%s after flush", ctxt));

    fresh_entry = make_queue_entry(paths, QueueDepth + 1);
    push_and_pop_fresh_entry(paths, fresh_entry, ctxt);
    check_read_blocked(paths, $sformatf("%s after fresh drain", ctxt));
  endtask

endclass
