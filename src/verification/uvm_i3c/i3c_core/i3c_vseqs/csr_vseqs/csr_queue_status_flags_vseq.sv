class csr_queue_status_flags_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_queue_status_flags_vseq)

  localparam int unsigned QueueDepth = 8;

  function new(string name = "csr_queue_status_flags_vseq");
    super.new(name);
  endfunction

  task body();
    check_queue_state(cmd_paths, 0, "CMD at reset");
    check_queue_state(tx_paths, 0, "TX at reset");
    check_queue_state(rx_paths, 0, "RX at reset");
    check_queue_state(resp_paths, 0, "RESP at reset");

    fill_cmd_queue();
    check_queue_status_write_ignored();
    check_queue_state(cmd_paths, QueueDepth, "after writes to read-only QUEUE_STATUS");
    check_cmd_queue_backpressure();

    fill_tx_queue();
    sw_reset_and_check(1'b0, "after TX queue reset");

    backdoor_fill_rx_queue();
    drain_rx_queue();

    backdoor_fill_resp_queue();
    drain_resp_queue();

    check_queue_state(cmd_paths, 0, "CMD at end of CSR_010");
    check_queue_state(tx_paths, 0, "TX at end of CSR_010");
    check_queue_state(rx_paths, 0, "RX at end of CSR_010");
    check_queue_state(resp_paths, 0, "RESP at end of CSR_010");
  endtask

  task check_cmd_queue_backpressure();
    regular_trans_desc_t cmd;
    bit           [63:0] held_wdata;
    uvm_hdl_data_t        raw_wdata;
    bit                   reg_ready;

    cmd             = '0;
    cmd.attr        = RegularTransfer;
    cmd.rnw         = 1'b1;
    cmd.mode        = sdr0;
    cmd.toc         = 1'b1;
    cmd.wroc        = 1'b1;
    cmd.dev_idx     = 5'd0;
    cmd.data_length = 16'd4;
    cmd.tid         = 4'hF;

    // The ninth command cannot enter a full FIFO. It must remain pending in
    // the CSR block with stable data until one FIFO slot becomes available.
    write_cmd(cmd[31:0], cmd[63:32]);
    settle_cycles(1);
    `DV_CHECK_EQ(hdl_read_bit(cmd_paths.write_valid_path), 1'b1,
                 "csr_queue_status_flags_vseq: extra CMD did not remain pending")
    `DV_CHECK_EQ(hdl_read_bit(cmd_paths.write_ready_path), 1'b0,
                 "csr_queue_status_flags_vseq: full CMD FIFO unexpectedly ready")
    raw_wdata  = hdl_read_checked(cmd_paths.write_data_path);
    held_wdata = raw_wdata[63:0];
    repeat (3) begin
      settle_cycles(1);
      `DV_CHECK_EQ(hdl_read_bit(cmd_paths.write_valid_path), 1'b1,
                   "csr_queue_status_flags_vseq: pending CMD valid dropped under backpressure")
      raw_wdata = hdl_read_checked(cmd_paths.write_data_path);
      `DV_CHECK_EQ(raw_wdata[63:0], held_wdata,
                   "csr_queue_status_flags_vseq: pending CMD data changed under backpressure")
    end

    // Present a CMD_QUEUE access while the previous command is still pending
    // so the CSR ready/backpressure cover observes an active blocked request.
    hdl_force_checked("tb_i3c_top.reg_bus.addr", ADDR_CMD_QUEUE);
    hdl_force_checked("tb_i3c_top.reg_bus.wen", 1'b1);
    hdl_force_checked("tb_i3c_top.reg_bus.ren", 1'b0);
    settle_cycles(2);
    reg_ready = hdl_read_bit("tb_i3c_top.reg_bus.ready");
    `DV_CHECK_EQ(reg_ready, 1'b0,
                 "csr_queue_status_flags_vseq: blocked CMD access did not lower ready")
    hdl_release_checked("tb_i3c_top.reg_bus.addr");
    hdl_release_checked("tb_i3c_top.reg_bus.wen");
    hdl_release_checked("tb_i3c_top.reg_bus.ren");
    settle_cycles(1);

    // A software reset is the architectural escape from a full, disabled CMD
    // queue. It also verifies that reset clears the pending CSR-side valid.
    request_sw_reset(.keep_enabled(1'b0));
    `DV_CHECK_EQ(hdl_read_bit(cmd_paths.write_valid_path), 1'b0,
                 "csr_queue_status_flags_vseq: pending CMD survived software reset")
    check_queue_state(cmd_paths, 0, "after CMD backpressure reset");
  endtask

  task check_queue_status_write_ignored();
    bit [31:0] status_before;
    bit [31:0] status_after;

    reg_read(ADDR_QUEUE_STATUS, status_before);
    reg_write(ADDR_QUEUE_STATUS, 32'hFFFF_FFFF);
    reg_read(ADDR_QUEUE_STATUS, status_after);
    `DV_CHECK_EQ(status_after, status_before,
                 "csr_queue_status_flags_vseq: all-ones write changed read-only QUEUE_STATUS")
    reg_write(ADDR_QUEUE_STATUS, 32'h0000_0000);
    reg_read(ADDR_QUEUE_STATUS, status_after);
    `DV_CHECK_EQ(status_after, status_before,
                 "csr_queue_status_flags_vseq: all-zeroes write changed read-only QUEUE_STATUS")
  endtask

  task check_queue_state(queue_hdl_paths_t paths, int unsigned exp_depth, string ctxt);
    int unsigned depth;
    bit          exp_full;
    bit          exp_empty;

    settle_cycles();
    depth     = hdl_read_fifo_depth(paths.depth_path);
    exp_full  = (exp_depth == QueueDepth);
    exp_empty = (exp_depth == 0);

    `DV_CHECK_EQ(depth, exp_depth,
                 $sformatf("csr_queue_status_flags_vseq: %s depth mismatch %s",
                           paths.name, ctxt))
    check_queue_flags(paths.name, paths.full_bit, paths.empty_bit, exp_full, exp_empty, ctxt);
  endtask

  task fill_cmd_queue();
    regular_trans_desc_t cmd;

    cmd             = '0;
    cmd.attr        = RegularTransfer;
    cmd.rnw         = 1'b1;
    cmd.mode        = sdr0;
    cmd.toc         = 1'b1;
    cmd.wroc        = 1'b1;
    cmd.dev_idx     = 5'd0;
    cmd.data_length = 16'd4;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      cmd.tid = i[3:0];
      write_cmd(cmd[31:0], cmd[63:32]);
      settle_cycles();
      if ((i == 0) || (i == (QueueDepth - 2)) || (i == (QueueDepth - 1))) begin
        check_queue_state(cmd_paths, i + 1, $sformatf("after CMD fill entry %0d", i));
      end
    end
  endtask

  task fill_tx_queue();
    for (int unsigned i = 0; i < QueueDepth; i++) begin
      write_tx_data(32'hA500_0000 | i);
      settle_cycles();
      if ((i == 0) || (i == (QueueDepth - 2)) || (i == (QueueDepth - 1))) begin
        check_queue_state(tx_paths, i + 1, $sformatf("after TX fill entry %0d", i));
      end
    end
  endtask

  task drain_rx_queue();
    bit [31:0] data;
    bit [31:0] exp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = {
        8'(8'h13 + (i << 2)), 8'(8'h12 + (i << 2)), 8'(8'h11 + (i << 2)), 8'(8'h10 + (i << 2))
      };
      read_rx_data(data);
      `DV_CHECK_EQ(data, exp,
                   $sformatf("csr_queue_status_flags_vseq: RX data mismatch at entry %0d", i))
      settle_cycles();
      if ((i == 0) || (i == (QueueDepth - 2)) || (i == (QueueDepth - 1))) begin
        check_queue_state(rx_paths, QueueDepth - i - 1,
                          $sformatf("after RX drain entry %0d", i));
      end
    end
  endtask

  task drain_resp_queue();
    bit [31:0] resp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      read_response(resp);
      settle_cycles();
      if ((i == 0) || (i == (QueueDepth - 2)) || (i == (QueueDepth - 1))) begin
        check_queue_state(resp_paths, QueueDepth - i - 1,
                          $sformatf("after RESP drain entry %0d", i));
      end
    end
  endtask

  task backdoor_fill_rx_queue();
    for (int unsigned i = 0; i < QueueDepth; i++) begin
      bit [31:0] data;

      data = {
        8'(8'h13 + (i << 2)), 8'(8'h12 + (i << 2)), 8'(8'h11 + (i << 2)), 8'(8'h10 + (i << 2))
      };
      backdoor_write_fifo_entry(rx_paths, i, data);
    end
    backdoor_set_fifo_level(rx_paths, 1);
    check_queue_state(rx_paths, 1, "after RX backdoor fill one entry");
    backdoor_set_fifo_level(rx_paths, QueueDepth - 1);
    check_queue_state(rx_paths, QueueDepth - 1, "after RX backdoor fill almost full");
    backdoor_set_fifo_level(rx_paths, QueueDepth);
    check_queue_state(rx_paths, QueueDepth, "after RX backdoor fill full");
  endtask

  task backdoor_fill_resp_queue();
    for (int unsigned i = 0; i < QueueDepth; i++) begin
      bit [31:0] resp;

      resp = {4'h0, i[3:0], 8'h00, 16'd4};
      backdoor_write_fifo_entry(resp_paths, i, resp);
    end
    backdoor_set_fifo_level(resp_paths, 1);
    check_queue_state(resp_paths, 1, "after RESP backdoor fill one entry");
    backdoor_set_fifo_level(resp_paths, QueueDepth - 1);
    check_queue_state(resp_paths, QueueDepth - 1, "after RESP backdoor fill almost full");
    backdoor_set_fifo_level(resp_paths, QueueDepth);
    check_queue_state(resp_paths, QueueDepth, "after RESP backdoor fill full");
  endtask

  task sw_reset_and_check(bit keep_enabled, string ctxt);
    request_sw_reset(keep_enabled);
    check_queue_state(cmd_paths, 0, $sformatf("CMD %s", ctxt));
    check_queue_state(tx_paths, 0, $sformatf("TX %s", ctxt));
    check_queue_state(rx_paths, 0, $sformatf("RX %s", ctxt));
    check_queue_state(resp_paths, 0, $sformatf("RESP %s", ctxt));
  endtask

endclass
