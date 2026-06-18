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

  virtual task drain_queue(queue_hdl_paths_t paths, int unsigned count);
    for (int unsigned i = 0; i < count; i++) begin
      pop_fifo_one_entry(paths);
    end
  endtask

  virtual task run_simultaneous_case(queue_hdl_paths_t paths, int unsigned initial_depth,
                                     int unsigned base_index, string state_name);
    uvm_hdl_data_t wr_entry;
    string         ctxt;

    ctxt = $sformatf("%s %s", paths.name, state_name);
    fill_queue(paths, initial_depth, base_index, ctxt);

    wr_entry = make_queue_entry(paths, base_index + QueueDepth);
    drive_fifo_read_write_one_cycle(paths, wr_entry);

    drain_queue(paths, initial_depth);
    attempt_empty_read(paths);
  endtask

  virtual task exercise_queue(queue_hdl_paths_t paths);
    run_simultaneous_case(paths, 4, 0,  "mid-depth");
    run_simultaneous_case(paths, 7, 16, "near-full");
    run_simultaneous_case(paths, 1, 32, "near-empty");
  endtask

endclass
