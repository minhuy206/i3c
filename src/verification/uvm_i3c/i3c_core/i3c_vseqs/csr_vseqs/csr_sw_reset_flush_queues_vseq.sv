class csr_sw_reset_flush_queues_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_sw_reset_flush_queues_vseq)

  localparam int unsigned QueueDepth = 8;

  function new(string name = "csr_sw_reset_flush_queues_vseq");
    super.new(name);
  endfunction

  task body();
    regular_trans_desc_t           wr_cmd;
    bit                     [31:0] data;

    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    wr_cmd             = '0;
    wr_cmd.attr        = RegularTransfer;
    wr_cmd.tid         = 4'd7;
    wr_cmd.rnw         = 1'b0;
    wr_cmd.mode        = sdr0;
    wr_cmd.toc         = 1'b1;
    wr_cmd.wroc        = 1'b1;
    wr_cmd.dev_idx     = 5'd0;
    wr_cmd.data_length = 16'd4;

    poll_idle();
    write_cmd(wr_cmd[31:0], wr_cmd[63:32]);
    write_tx_data(32'hCAFE_0077);
    backdoor_fill_rx_resp_queues();
    settle_cycles();
    check_queue_occupancy(cmd_paths, 1, "before CMD flush");
    check_queue_occupancy(tx_paths, 1, "before TX flush");
    check_queue_occupancy(rx_paths, 1, "before simultaneous RX flush");
    check_queue_occupancy(resp_paths, 1, "before simultaneous RESP flush");

    request_sw_reset(1'b0);
    check_all_queues_flushed("after simultaneous CMD/TX/RX/RESP flush");

    check_blocked_tx_write_flush();

    reg_read(ADDR_PIO_DATA_PORT, data);
    `DV_CHECK_EQ(data, 32'h0, "csr_sw_reset_flush_queues_vseq: empty RX_DATA read should return 0")
    reg_read(ADDR_RESP, data);
    `DV_CHECK_EQ(data, 32'h0, "csr_sw_reset_flush_queues_vseq: empty RESP read should return 0")

  endtask

  task backdoor_fill_rx_resp_queues();
    backdoor_write_fifo_entry(rx_paths, 0, 32'hA3A2_A1A0);
    backdoor_set_fifo_level(rx_paths, 1);

    backdoor_write_fifo_entry(resp_paths, 0, 32'h0007_0004);
    backdoor_set_fifo_level(resp_paths, 1);
  endtask

  task check_queue_occupancy(queue_hdl_paths_t paths, int unsigned exp_depth, string ctxt);
    int unsigned depth;
    bit     [31:0] status;

    settle_cycles();
    depth = hdl_read_fifo_depth(paths.depth_path);
    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(depth, exp_depth,
                 $sformatf("csr_sw_reset_flush_queues_vseq: %s depth mismatch %s",
                           paths.name, ctxt))
    `DV_CHECK_EQ(status[paths.empty_bit], 1'b0,
                 $sformatf("csr_sw_reset_flush_queues_vseq: %s should be non-empty %s",
                           paths.name, ctxt))
  endtask

  task check_queue_flushed(queue_hdl_paths_t paths, string ctxt);
    check_queue_flags(paths.name, paths.full_bit, paths.empty_bit, 1'b0, 1'b1, ctxt);
    `DV_CHECK_EQ(hdl_read_fifo_depth(paths.depth_path), 0,
                 $sformatf("csr_sw_reset_flush_queues_vseq: %s depth should be zero %s",
                           paths.name, ctxt))
  endtask

  task check_all_queues_flushed(string ctxt);
    check_queue_flushed(cmd_paths, ctxt);
    check_queue_flushed(tx_paths, ctxt);
    check_queue_flushed(rx_paths, ctxt);
    check_queue_flushed(resp_paths, ctxt);
  endtask

  task check_blocked_tx_write_flush();
    bit [31:0] status;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      write_tx_data(32'hBAD0_1000 | i);
      settle_cycles();
    end
    check_queue_occupancy(tx_paths, QueueDepth, "after filling TX FIFO");
    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(status[QS_TX_FULL_BIT], 1'b1,
                 "csr_sw_reset_flush_queues_vseq: TX FIFO should report full before blocked write")

    write_tx_data(32'hBAD0_F00D);
    settle_cycles();
    `DV_CHECK_EQ(hdl_read_bit(tx_paths.write_valid_path), 1'b1,
                 "csr_sw_reset_flush_queues_vseq: blocked TX write should be pending before reset")

    request_sw_reset(1'b0);
    settle_cycles(4);

    reg_read(ADDR_QUEUE_STATUS, status);
    check_queue_flushed(tx_paths, "after blocked TX write reset");
    `DV_CHECK_EQ(hdl_read_bit(tx_paths.write_valid_path), 1'b0,
                 "csr_sw_reset_flush_queues_vseq: pending TX write valid should clear on reset")
    `DV_CHECK_EQ(status[QS_TX_FULL_BIT], 1'b0,
                 "csr_sw_reset_flush_queues_vseq: TX full flag should clear after blocked write reset")
    `DV_CHECK_EQ(status[QS_TX_EMPTY_BIT], 1'b1,
                 "csr_sw_reset_flush_queues_vseq: TX FIFO should stay empty after blocked write reset")
  endtask

endclass
