class csr_sw_reset_flush_queues_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_sw_reset_flush_queues_vseq)

  localparam int unsigned QueueDepth = 8;

  function new(string name = "csr_sw_reset_flush_queues_vseq");
    super.new(name);
  endfunction

  task body();
    regular_trans_desc_t           wr_cmd;
    regular_trans_desc_t           rd_cmd;
    i3c_device_response_seq        dev_seq;
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
    settle_cycles();
    check_queue_occupancy(cmd_paths, 1, "before CMD flush");
    check_queue_occupancy(tx_paths, 1, "before TX flush");

    request_sw_reset(1'b0);
    check_all_queues_empty("after CMD/TX flush");

    check_blocked_tx_write_flush();

    rd_cmd              = '0;
    rd_cmd.attr         = RegularTransfer;
    rd_cmd.tid          = 4'd8;
    rd_cmd.rnw          = 1'b1;
    rd_cmd.mode         = sdr0;
    rd_cmd.toc          = 1'b1;
    rd_cmd.wroc         = 1'b1;
    rd_cmd.dev_idx      = 5'd0;
    rd_cmd.data_length  = 16'd4;

    dev_seq               = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr   = 7'h08;
    dev_seq.ack_address   = 1'b1;
    dev_seq.dir           = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.read_data_cnt = rd_cmd.data_length;
    dev_seq.read_data.push_back(8'h07);
    dev_seq.read_data.push_back(8'h17);
    dev_seq.read_data.push_back(8'h27);
    dev_seq.read_data.push_back(8'h37);
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    configure_dut();
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);
    poll_idle();
    wait_for_device_done(dev_seq, "csr_sw_reset_flush_queues_vseq");
    check_queue_occupancy(rx_paths, 1, "before RX flush");
    check_queue_occupancy(resp_paths, 1, "before RESP flush");

    request_sw_reset(1'b1);
    check_all_queues_empty("after RX/RESP flush");

    reg_read(ADDR_RX_DATA, data);
    `DV_CHECK_EQ(data, 32'h0, "csr_sw_reset_flush_queues_vseq: empty RX_DATA read should return 0")
    reg_read(ADDR_RESP, data);
    `DV_CHECK_EQ(data, 32'h0, "csr_sw_reset_flush_queues_vseq: empty RESP read should return 0")

    `uvm_info(`gfn, "CSR software reset queue flush checks passed", UVM_LOW)
  endtask

  task check_queue_occupancy(queue_hdl_paths_t paths, int unsigned exp_depth, string ctxt);
    bit     [31:0] depth;
    bit     [31:0] status;

    settle_cycles();
    depth = hdl_read_word(paths.depth_path);
    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(depth, 32'(exp_depth),
                 $sformatf("csr_sw_reset_flush_queues_vseq: %s depth mismatch %s",
                           paths.name, ctxt))
    `DV_CHECK_EQ(status[paths.empty_bit], 1'b0,
                 $sformatf("csr_sw_reset_flush_queues_vseq: %s should be non-empty %s",
                           paths.name, ctxt))
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
    `DV_CHECK_EQ(hdl_read_word(tx_paths.depth_path), 32'h0,
                 "csr_sw_reset_flush_queues_vseq: blocked TX write must not re-enter after reset")
    `DV_CHECK_EQ(hdl_read_bit(tx_paths.write_valid_path), 1'b0,
                 "csr_sw_reset_flush_queues_vseq: pending TX write valid should clear on reset")
    `DV_CHECK_EQ(status[QS_TX_FULL_BIT], 1'b0,
                 "csr_sw_reset_flush_queues_vseq: TX full flag should clear after blocked write reset")
    `DV_CHECK_EQ(status[QS_TX_EMPTY_BIT], 1'b1,
                 "csr_sw_reset_flush_queues_vseq: TX FIFO should stay empty after blocked write reset")
  endtask

endclass
