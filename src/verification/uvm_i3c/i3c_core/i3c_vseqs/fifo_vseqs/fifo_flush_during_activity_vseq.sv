class fifo_flush_during_activity_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_flush_during_activity_vseq)

  function new(string name = "fifo_flush_during_activity_vseq");
    super.new(name);
  endfunction

  task body();
    exercise_queue(cmd_paths);
    exercise_queue(tx_paths);
    exercise_queue(rx_paths);
    exercise_queue(resp_paths);

  endtask

  virtual task push_and_pop_fresh_entry(queue_hdl_paths_t paths, uvm_hdl_data_t fresh_entry,
                                        string ctxt);
    wait_hdl_bit(paths.write_ready_path, 1'b1, $sformatf("%s before fresh push", ctxt));
    force_fifo_write_one_cycle(paths, fresh_entry);

    pop_fifo_one_entry(paths);
  endtask

  virtual task exercise_queue(queue_hdl_paths_t paths);
    uvm_hdl_data_t flush_wr_entry;
    uvm_hdl_data_t fresh_entry;
    string         ctxt;

    ctxt = $sformatf("%s flush-during-activity", paths.name);
    fill_queue(paths, 3, 0, ctxt);

    flush_wr_entry = make_queue_entry(paths, QueueDepth);
    drive_fifo_flush_read_write_one_cycle(paths, flush_wr_entry);

    attempt_empty_read(paths);

    fresh_entry = make_queue_entry(paths, QueueDepth + 1);
    push_and_pop_fresh_entry(paths, fresh_entry, ctxt);
    attempt_empty_read(paths);
  endtask

endclass
