class fifo_basic_push_pop_order_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_basic_push_pop_order_vseq)

  function new(string name = "fifo_basic_push_pop_order_vseq");
    super.new(name);
  endfunction

  task body();
    check_all_queues_empty("at reset");

    exercise_cmd_fifo();
    exercise_tx_fifo();
    exercise_rx_fifo();
    exercise_resp_fifo();

    check_all_queues_empty("at end of FIFO_001");
    `uvm_info(`gfn, "FIFO basic push/pop order checks passed", UVM_LOW)
  endtask

  task exercise_cmd_fifo();
    bit [63:0] exp;
    bit [63:0] got;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_cmd_entry(i);
      wait_hdl_bit(cmd_paths.write_ready_path, 1'b1, $sformatf("before CMD push %0d", i));
      force_fifo_write_one_cycle(cmd_paths, exp);
      check_fifo_state(cmd_paths, i + 1, $sformatf("after CMD push %0d", i));
    end

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      wait_hdl_bit(cmd_paths.read_valid_path, 1'b1, $sformatf("before CMD pop %0d", i));
      exp = make_cmd_entry(i);
      got = hdl_read_qword(cmd_paths.read_data_path);
      `DV_CHECK_EQ(got, exp, $sformatf("%s: CMD pop order mismatch at entry %0d", get_type_name(), i
                   ))
      force_fifo_read_one_cycle(cmd_paths);
      check_fifo_state(cmd_paths, QueueDepth - i - 1, $sformatf("after CMD pop %0d", i));
    end
  endtask

  task exercise_tx_fifo();
    bit [31:0] exp;
    bit [31:0] got;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_tx_entry(i);
      wait_hdl_bit(tx_paths.write_ready_path, 1'b1, $sformatf("before TX push %0d", i));
      force_fifo_write_one_cycle(tx_paths, exp);
      check_fifo_state(tx_paths, i + 1, $sformatf("after TX push %0d", i));
    end

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      wait_hdl_bit(tx_paths.read_valid_path, 1'b1, $sformatf("before TX pop %0d", i));
      exp = make_tx_entry(i);
      got = hdl_read_word(tx_paths.read_data_path);
      `DV_CHECK_EQ(got, exp, $sformatf("%s: TX pop order mismatch at entry %0d", get_type_name(), i
                   ))
      force_fifo_read_one_cycle(tx_paths);
      check_fifo_state(tx_paths, QueueDepth - i - 1, $sformatf("after TX pop %0d", i));
    end
  endtask

  task exercise_rx_fifo();
    bit [31:0] exp;
    bit [31:0] got;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_rx_entry(i);
      wait_hdl_bit(rx_paths.write_ready_path, 1'b1, $sformatf("before RX push %0d", i));
      force_fifo_write_one_cycle(rx_paths, exp);
      check_fifo_state(rx_paths, i + 1, $sformatf("after RX push %0d", i));
    end

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_rx_entry(i);
      read_rx_data(got);
      `DV_CHECK_EQ(got, exp, $sformatf("%s: RX pop order mismatch at entry %0d", get_type_name(), i
                   ))
      settle_cycles();
      check_fifo_state(rx_paths, QueueDepth - i - 1, $sformatf("after RX pop %0d", i));
    end
  endtask

  task exercise_resp_fifo();
    bit [31:0] exp;
    bit [31:0] got;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_resp_entry(i);
      wait_hdl_bit(resp_paths.write_ready_path, 1'b1, $sformatf("before RESP push %0d", i));
      force_fifo_write_one_cycle(resp_paths, exp);
      check_fifo_state(resp_paths, i + 1, $sformatf("after RESP push %0d", i));
    end

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_resp_entry(i);
      read_response(got);
      `DV_CHECK_EQ(got, exp, $sformatf(
                   "%s: RESP pop order mismatch at entry %0d", get_type_name(), i))
      settle_cycles();
      check_fifo_state(resp_paths, QueueDepth - i - 1, $sformatf("after RESP pop %0d", i));
    end
  endtask

endclass
