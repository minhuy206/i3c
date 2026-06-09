class i3c_write_tx_fifo_empty_stall_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_tx_fifo_empty_stall_vseq)

  localparam int unsigned DATA_LENGTH = 8;
  localparam logic [3:0] FLOW_STALL_WRITE = 4'd12;
  localparam string FLOW_STATE_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.state_q";

  function new(string name = "i3c_write_tx_fifo_empty_stall_vseq");
    super.new(name);
  endfunction

  virtual task body();
    transfer_stimulus_cfg_t        cfg;
    regular_trans_desc_t           wr_cmd;
    byte_queue_t                   no_read_data;
    byte_queue_t                   exp_data;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    build_expected_payload(exp_data);

    cfg = make_transfer_cfg("SDRW_006 tx_fifo_empty_stall", "sdrw006_dev_seq", 4'd6, 5'd0, 7'h08,
                            1'b1, DATA_LENGTH);
    cfg.wait_device_done = 1'b1;

    wr_cmd = build_regular_transfer_cmd(cfg, 1'b0, 1'b1);
    start_device_response(cfg, 1'b0, no_read_data, dev_seq);

    write_tx_data(32'h4433_2211);
    write_cmd(wr_cmd[31:0], wr_cmd[63:32]);

    wait_for_flow_state(FLOW_STALL_WRITE, "StallWrite", 2000);
    check_queue_flags(tx_paths.name, tx_paths.full_bit, tx_paths.empty_bit, 1'b0, 1'b1,
                      "during SDRW_006 StallWrite");
    settle_cycles(16);

    write_tx_data(32'h8877_6655);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    `DV_CHECK_EQ(dev_seq.done, 1'b1, "SDRW_006: device response did not finish")
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08, "SDRW_006: target address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0, "SDRW_006: transfer direction should be write")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), DATA_LENGTH, "SDRW_006: sampled byte count mismatch")
    for (int unsigned i = 0; i < DATA_LENGTH; i++) begin
      if (i < dev_seq.sampled_data.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_data[i], exp_data[i],
                     $sformatf("SDRW_006: sampled byte[%0d] mismatch", i))
      end
    end

    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), DATA_LENGTH,
                 "SDRW_006: sampled T-bit count mismatch")
    for (int unsigned i = 0; i < DATA_LENGTH; i++) begin
      if (i < dev_seq.sampled_t_bit.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_t_bit[i], ~^exp_data[i],
                     $sformatf("SDRW_006: T-bit parity mismatch for byte[%0d]", i))
      end
    end

    `DV_CHECK_EQ(resp[31:28], 4'h0, "SDRW_006: expected Success response")
    `DV_CHECK_EQ(resp[27:24], cfg.tid, "SDRW_006: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], 16'(DATA_LENGTH), "SDRW_006: response length mismatch")

    check_all_queues_empty("after SDRW_006 tx_fifo_empty_stall");

    `uvm_info(`gfn, "SDRW_006 I3C write TX FIFO empty stall/recovery checks passed", UVM_LOW)
  endtask

  virtual function void build_expected_payload(ref byte_queue_t exp_data);
    exp_data.delete();
    exp_data.push_back(8'h11);
    exp_data.push_back(8'h22);
    exp_data.push_back(8'h33);
    exp_data.push_back(8'h44);
    exp_data.push_back(8'h55);
    exp_data.push_back(8'h66);
    exp_data.push_back(8'h77);
    exp_data.push_back(8'h88);
  endfunction

  virtual task wait_for_flow_state(logic [3:0] exp_state, string state_name,
                                   int unsigned timeout_cycles);
    for (int unsigned i = 0; i < timeout_cycles; i++) begin
      if (hdl_read_checked(FLOW_STATE_PATH) [3:0] == exp_state) begin
        return;
      end
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    end

    `uvm_fatal(`gfn, $sformatf("SDRW_006: timed out waiting for flow_active.%s", state_name))
  endtask

endclass
