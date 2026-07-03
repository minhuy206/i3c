class fifo_pointer_wrap_reuse_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_pointer_wrap_reuse_vseq)

  localparam int unsigned QueuePtrWidth = $clog2(QueueDepth) + 1;

  function new(string name = "fifo_pointer_wrap_reuse_vseq");
    super.new(name);
  endfunction

  task body();
    exercise_queue_wrap(cmd_paths);
    exercise_queue_wrap(tx_paths);
    exercise_queue_wrap(rx_paths);
    exercise_queue_wrap(resp_paths);
  endtask

  task check_fifo_pointers(queue_hdl_paths_t paths, int unsigned exp_wptr,
                           int unsigned exp_rptr, string ctxt);
    `DV_CHECK_EQ(hdl_read_uint_lsb(paths.wptr_path, QueuePtrWidth), exp_wptr,
                 $sformatf("%s: %s FIFO write pointer mismatch %s", get_type_name(),
                           paths.name, ctxt))
    `DV_CHECK_EQ(hdl_read_uint_lsb(paths.rptr_path, QueuePtrWidth), exp_rptr,
                 $sformatf("%s: %s FIFO read pointer mismatch %s", get_type_name(),
                           paths.name, ctxt))
  endtask

  task drain_generation(queue_hdl_paths_t paths, int unsigned base_index, string generation);
    uvm_hdl_data_t exp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_queue_entry(paths, base_index + i);
      expect_fifo_pop(paths, exp, $sformatf("while draining %s entry %0d", generation, i));
    end
  endtask

  task exercise_queue_wrap(queue_hdl_paths_t paths);
    check_fifo_state(paths, 0, "before pointer-wrap traffic");
    check_fifo_pointers(paths, 0, 0, "before pointer-wrap traffic");

    fill_queue(paths, QueueDepth, 0, "first generation");
    check_fifo_state(paths, QueueDepth, "after filling first generation");
    check_fifo_pointers(paths, QueueDepth, 0, "after filling first generation");

    drain_generation(paths, 0, "first generation");
    check_fifo_state(paths, 0, "after draining first generation");
    check_fifo_pointers(paths, QueueDepth, QueueDepth, "after draining first generation");

    fill_queue(paths, QueueDepth, QueueDepth, "second generation");
    check_fifo_state(paths, QueueDepth, "after write pointer wrapped");
    check_fifo_pointers(paths, 0, QueueDepth, "after write pointer wrapped");

    drain_generation(paths, QueueDepth, "second generation");
    check_fifo_state(paths, 0, "after read pointer wrapped and final drain");
    check_fifo_pointers(paths, 0, 0, "after read pointer wrapped and final drain");
  endtask

endclass
