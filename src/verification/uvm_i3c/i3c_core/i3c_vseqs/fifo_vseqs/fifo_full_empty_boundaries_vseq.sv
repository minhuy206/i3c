class fifo_full_empty_boundaries_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_full_empty_boundaries_vseq)

  function new(string name = "fifo_full_empty_boundaries_vseq");
    super.new(name);
  endfunction

  task body();
    exercise_queue_boundaries(cmd_paths, 64'hFFFF_FFFF_DEAD_0002);
    exercise_queue_boundaries(tx_paths, 32'hDEAD_0002);
    exercise_queue_boundaries(rx_paths, 32'hDEAD_0002);
    exercise_queue_boundaries(resp_paths, 32'hDEAD_0002);
  endtask

  task exercise_queue_boundaries(queue_hdl_paths_t paths, uvm_hdl_data_t overflow_entry);
    uvm_hdl_data_t exp;

    check_fifo_state(paths, 0, "at reset");
    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_queue_entry(paths, i);
      wait_hdl_bit(paths.write_ready_path, 1'b1,
                   $sformatf("before %s push %0d", paths.name, i));
      force_fifo_write_one_cycle(paths, exp);
    end
    check_fifo_state(paths, QueueDepth, "after filling to boundary");

    force_fifo_write_one_cycle(paths, overflow_entry);
    check_fifo_state(paths, QueueDepth, "after blocked overflow write");

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_queue_entry(paths, i);
      expect_fifo_pop(paths, exp, $sformatf("after boundary pop %0d", i));
    end
    check_fifo_state(paths, 0, "after draining to empty");

    attempt_empty_read(paths);
    check_fifo_state(paths, 0, "after blocked empty read");
  endtask

endclass
