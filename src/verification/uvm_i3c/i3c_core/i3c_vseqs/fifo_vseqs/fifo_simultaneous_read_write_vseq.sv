class fifo_simultaneous_read_write_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_simultaneous_read_write_vseq)

  function new(string name = "fifo_simultaneous_read_write_vseq");
    super.new(name);
  endfunction

  task body();
    exercise_queue(cmd_paths);
    exercise_queue(tx_paths);
    exercise_queue(rx_paths);
    exercise_queue(resp_paths);

  endtask

  virtual task drain_queue_after_simultaneous_rw(queue_hdl_paths_t paths,
                                                 int unsigned initial_depth,
                                                 int unsigned base_index,
                                                 uvm_hdl_data_t wr_entry,
                                                 string ctxt);
    for (int unsigned i = 1; i < initial_depth; i++) begin
      expect_fifo_pop(paths, make_queue_entry(paths, base_index + i),
                      $sformatf("%s remaining preloaded entry %0d", ctxt, i));
    end
    expect_fifo_pop(paths, wr_entry, $sformatf("%s newly written entry", ctxt));
  endtask

  virtual task run_simultaneous_case(queue_hdl_paths_t paths, int unsigned initial_depth,
                                     int unsigned base_index, string state_name);
    uvm_hdl_data_t wr_entry;
    uvm_hdl_data_t rd_entry;
    string         ctxt;

    ctxt = $sformatf("%s %s", paths.name, state_name);
    fill_queue(paths, initial_depth, base_index, ctxt);
    check_fifo_state(paths, initial_depth, $sformatf("%s before simultaneous read/write", ctxt));

    wr_entry = make_queue_entry(paths, base_index + QueueDepth);
    drive_fifo_read_write_one_cycle_data(paths, wr_entry, rd_entry);
    `DV_CHECK_EQ(queue_data_lsb(paths, rd_entry),
                 queue_data_lsb(paths, make_queue_entry(paths, base_index)),
                 $sformatf("%s: %s FIFO simultaneous read data mismatch %s",
                           get_type_name(), paths.name, ctxt))
    check_fifo_state(paths, initial_depth, $sformatf("%s after simultaneous read/write", ctxt));

    drain_queue_after_simultaneous_rw(paths, initial_depth, base_index, wr_entry, ctxt);
    check_fifo_state(paths, 0, $sformatf("%s after draining", ctxt));
    attempt_empty_read(paths);
    check_fifo_state(paths, 0, $sformatf("%s after blocked empty read", ctxt));
  endtask

  virtual task exercise_queue(queue_hdl_paths_t paths);
    run_simultaneous_case(paths, 4, 0,  "mid-depth");
    run_simultaneous_case(paths, 7, 16, "near-full");
    run_simultaneous_case(paths, 1, 32, "near-empty");
  endtask

endclass
