class csr_sw_reset_flush_queues_vseq extends i3c_base_vseq;
  `uvm_object_utils(csr_sw_reset_flush_queues_vseq)

  function new(string name = "csr_sw_reset_flush_queues_vseq");
    super.new(name);
  endfunction

  task body();
    regular_trans_desc_t    wr_cmd;
    regular_trans_desc_t    rd_cmd;
    i3c_device_response_seq dev_seq;
    bit              [31:0] status;
    bit              [31:0] data;

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
    repeat (4) @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);

    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(status[QS_CMD_EMPTY_BIT], 1'b0,
                 "csr_sw_reset_flush_queues_vseq: CMD queue should be populated before reset")
    `DV_CHECK_EQ(status[QS_TX_EMPTY_BIT], 1'b0,
                 "csr_sw_reset_flush_queues_vseq: TX queue should be populated before reset")

    request_sw_reset(1'b0);
    check_all_queues_empty("after CMD/TX flush");

    rd_cmd             = '0;
    rd_cmd.attr        = RegularTransfer;
    rd_cmd.tid         = 4'd8;
    rd_cmd.rnw         = 1'b1;
    rd_cmd.mode        = sdr0;
    rd_cmd.toc         = 1'b1;
    rd_cmd.wroc        = 1'b1;
    rd_cmd.dev_idx     = 5'd0;
    rd_cmd.data_length = 16'd4;

    dev_seq             = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr = 7'h08;
    dev_seq.dir         = 1'b1;
    dev_seq.is_i3c      = 1'b1;
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
    for (int i = 0; i < 1000; i++) begin
      if (dev_seq.done) break;
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    end

    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(status[QS_RX_EMPTY_BIT], 1'b0,
                 "csr_sw_reset_flush_queues_vseq: RX queue should be populated before reset")
    `DV_CHECK_EQ(status[QS_RESP_EMPTY_BIT], 1'b0,
                 "csr_sw_reset_flush_queues_vseq: RESP queue should be populated before reset")

    request_sw_reset(1'b1);
    check_all_queues_empty("after RX/RESP flush");

    reg_read(ADDR_RX_DATA, data);
    `DV_CHECK_EQ(data, 32'h0000_0000,
                 "csr_sw_reset_flush_queues_vseq: RX_DATA should read zero after reset flush")
    reg_read(ADDR_RESP, data);
    `DV_CHECK_EQ(data, 32'h0000_0000,
                 "csr_sw_reset_flush_queues_vseq: RESP should read zero after reset flush")

    `uvm_info(`gfn, "CSR software reset queue flush checks passed", UVM_LOW)
  endtask

  task request_sw_reset(bit keep_enabled);
    bit [31:0] data;

    poll_idle();
    reg_write(ADDR_HC_CONTROL, {30'h0, 1'b1, keep_enabled});
    repeat (4) @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);

    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_SW_RESET_BIT], 1'b0,
                 "csr_sw_reset_flush_queues_vseq: SW_RESET should self-clear")
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], keep_enabled,
                 "csr_sw_reset_flush_queues_vseq: SW_RESET should preserve requested enable state")
  endtask

  task check_all_queues_empty(string ctxt);
    bit [31:0] status;

    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(status[QS_CMD_FULL_BIT], 1'b0,
                 $sformatf("csr_sw_reset_flush_queues_vseq: CMD full should clear %s", ctxt))
    `DV_CHECK_EQ(status[QS_CMD_EMPTY_BIT], 1'b1,
                 $sformatf("csr_sw_reset_flush_queues_vseq: CMD empty should set %s", ctxt))
    `DV_CHECK_EQ(status[QS_TX_FULL_BIT], 1'b0,
                 $sformatf("csr_sw_reset_flush_queues_vseq: TX full should clear %s", ctxt))
    `DV_CHECK_EQ(status[QS_TX_EMPTY_BIT], 1'b1,
                 $sformatf("csr_sw_reset_flush_queues_vseq: TX empty should set %s", ctxt))
    `DV_CHECK_EQ(status[QS_RX_FULL_BIT], 1'b0,
                 $sformatf("csr_sw_reset_flush_queues_vseq: RX full should clear %s", ctxt))
    `DV_CHECK_EQ(status[QS_RX_EMPTY_BIT], 1'b1,
                 $sformatf("csr_sw_reset_flush_queues_vseq: RX empty should set %s", ctxt))
    `DV_CHECK_EQ(status[QS_RESP_FULL_BIT], 1'b0,
                 $sformatf("csr_sw_reset_flush_queues_vseq: RESP full should clear %s", ctxt))
    `DV_CHECK_EQ(status[QS_RESP_EMPTY_BIT], 1'b1,
                 $sformatf("csr_sw_reset_flush_queues_vseq: RESP empty should set %s", ctxt))
  endtask

endclass
