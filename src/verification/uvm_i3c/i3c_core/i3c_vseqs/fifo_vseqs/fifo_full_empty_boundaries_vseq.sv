class fifo_full_empty_boundaries_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_full_empty_boundaries_vseq)

  function new(string name = "fifo_full_empty_boundaries_vseq");
    super.new(name);
  endfunction

  task body();
    exercise_cmd_boundaries();
    exercise_tx_boundaries();
    exercise_rx_boundaries();
    exercise_resp_boundaries();

  endtask

  task exercise_cmd_boundaries();
    bit [63:0] exp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_cmd_entry(i);
      wait_hdl_bit(cmd_paths.write_ready_path, 1'b1, $sformatf("before CMD push %0d", i));
      force_fifo_write_one_cycle(cmd_paths, exp);
    end

    force_fifo_write_one_cycle(cmd_paths, 64'hFFFF_FFFF_DEAD_0002);

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      pop_fifo_one_entry(cmd_paths);
    end

    attempt_empty_read(cmd_paths);
  endtask

  task exercise_tx_boundaries();
    bit [31:0] exp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_tx_entry(i);
      wait_hdl_bit(tx_paths.write_ready_path, 1'b1, $sformatf("before TX push %0d", i));
      force_fifo_write_one_cycle(tx_paths, exp);
    end

    force_fifo_write_one_cycle(tx_paths, 32'hDEAD_0002);

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      pop_fifo_one_entry(tx_paths);
    end

    attempt_empty_read(tx_paths);
  endtask

  task exercise_rx_boundaries();
    bit [31:0] exp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_rx_entry(i);
      wait_hdl_bit(rx_paths.write_ready_path, 1'b1, $sformatf("before RX push %0d", i));
      force_fifo_write_one_cycle(rx_paths, exp);
    end

    force_fifo_write_one_cycle(rx_paths, 32'hDEAD_0002);

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      pop_fifo_one_entry(rx_paths);
    end

    attempt_empty_read(rx_paths);
  endtask

  task exercise_resp_boundaries();
    bit [31:0] exp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_resp_entry(i);
      wait_hdl_bit(resp_paths.write_ready_path, 1'b1, $sformatf("before RESP push %0d", i));
      force_fifo_write_one_cycle(resp_paths, exp);
    end

    force_fifo_write_one_cycle(resp_paths, 32'hDEAD_0002);

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      pop_fifo_one_entry(resp_paths);
    end

    attempt_empty_read(resp_paths);
  endtask

endclass
