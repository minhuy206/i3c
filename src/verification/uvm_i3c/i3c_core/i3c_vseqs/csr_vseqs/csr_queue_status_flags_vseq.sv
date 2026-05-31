class csr_queue_status_flags_vseq extends i3c_base_vseq;
  `uvm_object_utils(csr_queue_status_flags_vseq)

  localparam int unsigned QueueDepth = 8;

  function new(string name = "csr_queue_status_flags_vseq");
    super.new(name);
  endfunction

  task body();
    check_all_queues_empty("at reset");

    fill_cmd_queue();
    sw_reset_and_check(1'b0, "after CMD queue drain");

    fill_tx_queue();
    sw_reset_and_check(1'b0, "after TX queue drain");

    backdoor_fill_rx_queue();
    drain_rx_queue();

    backdoor_fill_resp_queue();
    drain_resp_queue();

    check_all_queues_empty("at end of CSR_009");
    `uvm_info(`gfn, "CSR queue status flag checks passed", UVM_LOW)
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
      check_queue_flags("CMD", QS_CMD_FULL_BIT, QS_CMD_EMPTY_BIT, (i == QueueDepth - 1), 1'b0,
                        $sformatf("after CMD entry %0d", i));
    end
  endtask

  task fill_tx_queue();
    for (int unsigned i = 0; i < QueueDepth; i++) begin
      write_tx_data(32'hA500_0000 | i);
      settle_cycles();
      check_queue_flags("TX", QS_TX_FULL_BIT, QS_TX_EMPTY_BIT, (i == QueueDepth - 1), 1'b0,
                        $sformatf("after TX entry %0d", i));
    end
  endtask

  task drain_rx_queue();
    bit [31:0] data;
    bit [31:0] exp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      exp = {8'(8'h13 + (i << 2)), 8'(8'h12 + (i << 2)), 8'(8'h11 + (i << 2)),
             8'(8'h10 + (i << 2))};
      read_rx_data(data);
      `DV_CHECK_EQ(data, exp,
                   $sformatf("csr_queue_status_flags_vseq: RX data mismatch at entry %0d", i))
      settle_cycles();
      check_queue_flags("RX", QS_RX_FULL_BIT, QS_RX_EMPTY_BIT, 1'b0, (i == QueueDepth - 1),
                        $sformatf("after RX drain %0d", i));
    end
  endtask

  task drain_resp_queue();
    bit [31:0] resp;

    for (int unsigned i = 0; i < QueueDepth; i++) begin
      read_response(resp);
      `DV_CHECK_EQ(resp[31:28], 4'h0,
                   $sformatf("csr_queue_status_flags_vseq: RESP error at entry %0d", i))
      `DV_CHECK_EQ(resp[27:24], i[3:0],
                   $sformatf("csr_queue_status_flags_vseq: RESP TID mismatch at entry %0d", i))
      `DV_CHECK_EQ(resp[15:0], 16'd4,
                   $sformatf("csr_queue_status_flags_vseq: RESP length mismatch at entry %0d", i))
      settle_cycles();
      check_queue_flags("RESP", QS_RESP_FULL_BIT, QS_RESP_EMPTY_BIT, 1'b0, (i == QueueDepth - 1),
                        $sformatf("after RESP drain %0d", i));
    end
  endtask

  task backdoor_fill_rx_queue();
    for (int unsigned i = 0; i < QueueDepth; i++) begin
      bit [31:0] data;

      data = {8'(8'h13 + (i << 2)), 8'(8'h12 + (i << 2)), 8'(8'h11 + (i << 2)),
              8'(8'h10 + (i << 2))};
      hdl_deposit_checked($sformatf("tb_i3c_top.dut.u_queues.rx_fifo.mem[%0d]", i), data);
    end
    hdl_deposit_checked("tb_i3c_top.dut.u_queues.rx_fifo.rptr_q", '0);
    hdl_deposit_checked("tb_i3c_top.dut.u_queues.rx_fifo.wptr_q", QueueDepth);
    settle_cycles();
    check_queue_flags("RX", QS_RX_FULL_BIT, QS_RX_EMPTY_BIT, 1'b1, 1'b0,
                      "after RX backdoor fill");
  endtask

  task backdoor_fill_resp_queue();
    for (int unsigned i = 0; i < QueueDepth; i++) begin
      bit [31:0] resp;

      resp = {4'h0, i[3:0], 8'h00, 16'd4};
      hdl_deposit_checked($sformatf("tb_i3c_top.dut.u_queues.resp_fifo.mem[%0d]", i), resp);
    end
    hdl_deposit_checked("tb_i3c_top.dut.u_queues.resp_fifo.rptr_q", '0);
    hdl_deposit_checked("tb_i3c_top.dut.u_queues.resp_fifo.wptr_q", QueueDepth);
    settle_cycles();
    check_queue_flags("RESP", QS_RESP_FULL_BIT, QS_RESP_EMPTY_BIT, 1'b1, 1'b0,
                      "after RESP backdoor fill");
  endtask

  task sw_reset_and_check(bit keep_enabled, string ctxt);
    bit [31:0] control;

    poll_idle();
    reg_write(ADDR_HC_CONTROL, {30'h0, 1'b1, keep_enabled});
    settle_cycles();

    reg_read(ADDR_HC_CONTROL, control);
    `DV_CHECK_EQ(control[HC_CTRL_SW_RESET_BIT], 1'b0,
                 "csr_queue_status_flags_vseq: SW_RESET should self-clear")
    `DV_CHECK_EQ(control[HC_CTRL_ENABLE_BIT], keep_enabled,
                 "csr_queue_status_flags_vseq: SW_RESET should preserve enable bit")
    check_all_queues_empty(ctxt);
  endtask

  task check_all_queues_empty(string ctxt);
    check_queue_flags("CMD", QS_CMD_FULL_BIT, QS_CMD_EMPTY_BIT, 1'b0, 1'b1, ctxt);
    check_queue_flags("TX", QS_TX_FULL_BIT, QS_TX_EMPTY_BIT, 1'b0, 1'b1, ctxt);
    check_queue_flags("RX", QS_RX_FULL_BIT, QS_RX_EMPTY_BIT, 1'b0, 1'b1, ctxt);
    check_queue_flags("RESP", QS_RESP_FULL_BIT, QS_RESP_EMPTY_BIT, 1'b0, 1'b1, ctxt);
  endtask

  task check_queue_flags(string queue_name, int full_bit, int empty_bit, bit exp_full,
                         bit exp_empty, string ctxt);
    bit [31:0] status;

    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(status[full_bit], exp_full, $sformatf(
                 "csr_queue_status_flags_vseq: %s full flag mismatch %s", queue_name, ctxt))
    `DV_CHECK_EQ(status[empty_bit], exp_empty, $sformatf(
                 "csr_queue_status_flags_vseq: %s empty flag mismatch %s", queue_name, ctxt))
  endtask

  function void hdl_deposit_checked(string path, uvm_hdl_data_t value);
    if (!uvm_hdl_deposit(path, value)) begin
      `uvm_fatal(`gfn, $sformatf("csr_queue_status_flags_vseq: uvm_hdl_deposit failed for %s",
                                 path))
    end
  endfunction

  task settle_cycles(int unsigned cycles = 4);
    repeat (cycles) @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
  endtask

endclass
