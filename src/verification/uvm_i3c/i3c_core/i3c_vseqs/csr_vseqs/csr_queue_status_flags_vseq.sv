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
    sw_reset_and_check(1'b0, "after CMD queue reset");

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

  task check_queue_state(queue_hdl_paths_t paths, int unsigned exp_depth, string ctxt);
    bit [31:0] status;
    bit        exp_full;
    bit        exp_empty;

    settle_cycles();
    reg_read(ADDR_QUEUE_STATUS, status);
    exp_full  = (exp_depth == QueueDepth);
    exp_empty = (exp_depth == 0);

    `DV_CHECK_EQ(hdl_read_fifo_depth(paths.depth_path), exp_depth, $sformatf(
                 "csr_queue_status_flags_vseq: %s depth mismatch %s", paths.name, ctxt))
    `DV_CHECK_EQ(status[paths.full_bit], exp_full, $sformatf(
                 "csr_queue_status_flags_vseq: %s full flag mismatch %s", paths.name, ctxt))
    `DV_CHECK_EQ(status[paths.empty_bit], exp_empty, $sformatf(
                 "csr_queue_status_flags_vseq: %s empty flag mismatch %s", paths.name, ctxt))
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
      `DV_CHECK_EQ(data, exp, $sformatf(
                   "csr_queue_status_flags_vseq: RX data mismatch at entry %0d", i))
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
      `DV_CHECK_EQ(resp[31:28], 4'h0, $sformatf(
                   "csr_queue_status_flags_vseq: RESP error at entry %0d", i))
      `DV_CHECK_EQ(resp[27:24], i[3:0], $sformatf(
                   "csr_queue_status_flags_vseq: RESP TID mismatch at entry %0d", i))
      `DV_CHECK_EQ(resp[15:0], 16'd4, $sformatf(
                   "csr_queue_status_flags_vseq: RESP length mismatch at entry %0d", i))
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
