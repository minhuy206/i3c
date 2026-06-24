class fifo_basic_push_pop_order_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_basic_push_pop_order_vseq)

  function new(string name = "fifo_basic_push_pop_order_vseq");
    super.new(name);
  endfunction

  task body();
    exercise_queue(cmd_paths);
    exercise_queue(tx_paths);
    exercise_queue(rx_paths);
    exercise_queue(resp_paths);

  endtask

  task exercise_queue(queue_hdl_paths_t paths);
    uvm_hdl_data_t exp;

    check_fifo_state(paths, 0, "at reset");
    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_queue_entry(paths, i);
      wait_hdl_bit(paths.write_ready_path, 1'b1,
                   $sformatf("before %s push %0d", paths.name, i));
      force_fifo_write_one_cycle(paths, exp);
      check_fifo_state(paths, i + 1, $sformatf("after push %0d", i));
    end

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_queue_entry(paths, i);
      expect_fifo_pop(paths, exp, $sformatf("after pop %0d", i));
      check_fifo_state(paths, QueueDepth - i - 1, $sformatf("after pop %0d", i));
    end
  endtask

endclass
