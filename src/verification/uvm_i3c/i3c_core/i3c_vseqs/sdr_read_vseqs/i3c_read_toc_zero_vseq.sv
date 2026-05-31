class i3c_read_toc_zero_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_toc_zero_vseq)

  function new(string name = "i3c_read_toc_zero_vseq");
    super.new(name);
  endfunction

  virtual task body();
    regular_trans_desc_t    rd_cmd0;
    regular_trans_desc_t    wr_cmd1;
    bit [31:0]              resp0;
    bit [31:0]              resp1;
    bit [31:0]              rx;
    int                     rstart_count;
    i3c_device_response_seq dev_seq0;
    i3c_device_response_seq dev_seq1;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    rd_cmd0             = '0;
    rd_cmd0.attr        = RegularTransfer;
    rd_cmd0.tid         = 4'd5;
    rd_cmd0.rnw         = 1'b1;
    rd_cmd0.mode        = sdr0;
    rd_cmd0.toc         = 1'b0;
    rd_cmd0.wroc        = 1'b1;
    rd_cmd0.data_length = 16'd2;

    wr_cmd1             = '0;
    wr_cmd1.attr        = RegularTransfer;
    wr_cmd1.tid         = 4'd6;
    wr_cmd1.rnw         = 1'b0;
    wr_cmd1.mode        = sdr0;
    wr_cmd1.toc         = 1'b1;
    wr_cmd1.wroc        = 1'b1;
    wr_cmd1.data_length = 16'd2;

    dev_seq0             = i3c_device_response_seq::type_id::create("dev_seq0");
    dev_seq0.target_addr = 7'h08;
    dev_seq0.is_i3c      = 1'b1;
    dev_seq0.dir         = 1'b1;
    dev_seq0.read_data.push_back(8'h11);
    dev_seq0.read_data.push_back(8'h22);

    dev_seq1               = i3c_device_response_seq::type_id::create("dev_seq1");
    dev_seq1.target_addr   = 7'h08;
    dev_seq1.is_i3c        = 1'b1;
    dev_seq1.dir           = 1'b0;
    dev_seq1.read_data_cnt = 2;

    fork : device_responses
      dev_seq0.start(p_sequencer.m_i3c_sequencer);
      dev_seq1.start(p_sequencer.m_i3c_sequencer);
    join_none

    repeat (5) @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);

    write_cmd(rd_cmd0[31:0], rd_cmd0[63:32]);
    write_cmd(wr_cmd1[31:0], wr_cmd1[63:32]);
    write_tx_data(32'h0000_4433);

    poll_idle();

    for (int i = 0; i < 1000; i++) begin
      if (dev_seq0.done && dev_seq1.done) break;
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    end

    `DV_CHECK_EQ(dev_seq0.done, 1'b1, "read_toc0_vseq: first device response did not finish")
    `DV_CHECK_EQ(dev_seq1.done, 1'b1, "read_toc0_vseq: second device response did not finish")
    rstart_count = int'(dev_seq0.observed_rstart) + int'(dev_seq1.observed_rstart);
    `DV_CHECK_EQ((rstart_count > 0), 1'b1, "read_toc0_vseq: expected at least one observed RSTART")

    read_rx_data(rx);
    read_response(resp0);
    read_response(resp1);

    `DV_CHECK_EQ(rx,          32'h0000_2211, "read_toc0_vseq: RX data mismatch")
    `DV_CHECK_EQ(resp0[31:28], 4'h0,         "read_toc0_vseq: first response expected Success")
    `DV_CHECK_EQ(resp0[27:24], 4'd5,         "read_toc0_vseq: first response TID mismatch")
    `DV_CHECK_EQ(resp0[15:0],  16'd2,        "read_toc0_vseq: first response length mismatch")
    `DV_CHECK_EQ(resp1[31:28], 4'h0,         "read_toc0_vseq: second response expected Success")
    `DV_CHECK_EQ(resp1[27:24], 4'd6,         "read_toc0_vseq: second response TID mismatch")
    `DV_CHECK_EQ(resp1[15:0],  16'd2,        "read_toc0_vseq: second response length mismatch")

    disable device_responses;
  endtask
endclass
