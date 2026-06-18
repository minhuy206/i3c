class fifo_basic_push_pop_order_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_basic_push_pop_order_vseq)

  function new(string name = "fifo_basic_push_pop_order_vseq");
    super.new(name);
  endfunction

  task body();
    exercise_cmd_fifo();
    exercise_tx_fifo();
    exercise_rx_fifo();
    exercise_resp_fifo();

  endtask

  task exercise_cmd_fifo();
    bit [63:0] exp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_cmd_entry(i);
      wait_hdl_bit(cmd_paths.write_ready_path, 1'b1, $sformatf("before CMD push %0d", i));
      force_fifo_write_one_cycle(cmd_paths, exp);
    end

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      pop_fifo_one_entry(cmd_paths);
    end
  endtask

  task exercise_tx_fifo();
    bit [31:0] exp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_tx_entry(i);
      wait_hdl_bit(tx_paths.write_ready_path, 1'b1, $sformatf("before TX push %0d", i));
      force_fifo_write_one_cycle(tx_paths, exp);
    end

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      pop_fifo_one_entry(tx_paths);
    end
  endtask

  task exercise_rx_fifo();
    bit [31:0] exp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_rx_entry(i);
      wait_hdl_bit(rx_paths.write_ready_path, 1'b1, $sformatf("before RX push %0d", i));
      force_fifo_write_one_cycle(rx_paths, exp);
    end

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      pop_fifo_one_entry(rx_paths);
    end
  endtask

  task exercise_resp_fifo();
    bit [31:0] exp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_resp_entry(i);
      wait_hdl_bit(resp_paths.write_ready_path, 1'b1, $sformatf("before RESP push %0d", i));
      force_fifo_write_one_cycle(resp_paths, exp);
    end

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      pop_fifo_one_entry(resp_paths);
    end
  endtask

endclass
