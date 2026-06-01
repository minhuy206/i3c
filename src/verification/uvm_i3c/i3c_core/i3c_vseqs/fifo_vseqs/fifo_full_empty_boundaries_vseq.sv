class fifo_full_empty_boundaries_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_full_empty_boundaries_vseq)

  function new(string name = "fifo_full_empty_boundaries_vseq");
    super.new(name);
  endfunction

  task body();
    check_all_queues_empty("at reset");

    exercise_cmd_boundaries();
    exercise_tx_boundaries();
    exercise_rx_boundaries();
    exercise_resp_boundaries();

    check_all_queues_empty("at end of FIFO_002");
    `uvm_info(`gfn, "FIFO full/empty boundary checks passed", UVM_LOW)
  endtask

  task exercise_cmd_boundaries();
    bit [63:0] exp;
    bit [63:0] got;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_cmd_entry(i);
      wait_hdl_bit(cmd_paths.write_ready_path, 1'b1, $sformatf("before CMD push %0d", i));
      force_fifo_write_one_cycle(cmd_paths, exp);
    end

    check_write_blocked(cmd_paths, "after exact-depth fill");
    force_fifo_write_one_cycle(cmd_paths, 64'hFFFF_FFFF_DEAD_0002);
    check_write_blocked(cmd_paths, "after blocked extra write");

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      wait_hdl_bit(cmd_paths.read_valid_path, 1'b1, $sformatf("before CMD pop %0d", i));
      exp = make_cmd_entry(i);
      got = hdl_read_qword(cmd_paths.read_data_path);
      `DV_CHECK_EQ(got, exp, $sformatf(
                   "%s: CMD data changed across full boundary at entry %0d", get_type_name(), i))
      force_fifo_read_one_cycle(cmd_paths);
    end

    check_read_blocked(cmd_paths, "after drain to empty");
    force_fifo_read_one_cycle(cmd_paths);
    check_read_blocked(cmd_paths, "after blocked extra read");
  endtask

  task exercise_tx_boundaries();
    bit [31:0] exp;
    bit [31:0] got;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_tx_entry(i);
      wait_hdl_bit(tx_paths.write_ready_path, 1'b1, $sformatf("before TX push %0d", i));
      force_fifo_write_one_cycle(tx_paths, exp);
    end

    check_write_blocked(tx_paths, "after exact-depth fill");
    force_fifo_write_one_cycle(tx_paths, 32'hDEAD_0002);
    check_write_blocked(tx_paths, "after blocked extra write");

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      wait_hdl_bit(tx_paths.read_valid_path, 1'b1, $sformatf("before TX pop %0d", i));
      exp = make_tx_entry(i);
      got = hdl_read_word(tx_paths.read_data_path);
      `DV_CHECK_EQ(got, exp, $sformatf(
                   "%s: TX data changed across full boundary at entry %0d", get_type_name(), i))
      force_fifo_read_one_cycle(tx_paths);
    end

    check_read_blocked(tx_paths, "after drain to empty");
    force_fifo_read_one_cycle(tx_paths);
    check_read_blocked(tx_paths, "after blocked extra read");
  endtask

  task exercise_rx_boundaries();
    bit [31:0] exp;
    bit [31:0] got;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_rx_entry(i);
      wait_hdl_bit(rx_paths.write_ready_path, 1'b1, $sformatf("before RX push %0d", i));
      force_fifo_write_one_cycle(rx_paths, exp);
    end

    check_write_blocked(rx_paths, "after exact-depth fill");
    force_fifo_write_one_cycle(rx_paths, 32'hDEAD_0002);
    check_write_blocked(rx_paths, "after blocked extra write");

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_rx_entry(i);
      read_rx_data(got);
      `DV_CHECK_EQ(got, exp, $sformatf(
                   "%s: RX data changed across full boundary at entry %0d", get_type_name(), i))
      settle_cycles();
    end

    check_read_blocked(rx_paths, "after drain to empty");
    force_fifo_read_one_cycle(rx_paths);
    check_read_blocked(rx_paths, "after blocked extra read");
  endtask

  task exercise_resp_boundaries();
    bit [31:0] exp;
    bit [31:0] got;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_resp_entry(i);
      wait_hdl_bit(resp_paths.write_ready_path, 1'b1, $sformatf("before RESP push %0d", i));
      force_fifo_write_one_cycle(resp_paths, exp);
    end

    check_write_blocked(resp_paths, "after exact-depth fill");
    force_fifo_write_one_cycle(resp_paths, 32'hDEAD_0002);
    check_write_blocked(resp_paths, "after blocked extra write");

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = make_resp_entry(i);
      read_response(got);
      `DV_CHECK_EQ(got, exp, $sformatf(
                   "%s: RESP data changed across full boundary at entry %0d", get_type_name(), i))
      settle_cycles();
    end

    check_read_blocked(resp_paths, "after drain to empty");
    force_fifo_read_one_cycle(resp_paths);
    check_read_blocked(resp_paths, "after blocked extra read");
  endtask

endclass
