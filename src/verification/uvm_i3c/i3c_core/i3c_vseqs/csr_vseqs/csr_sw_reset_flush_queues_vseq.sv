class csr_sw_reset_flush_queues_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_sw_reset_flush_queues_vseq)

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

    request_sw_reset(1'b0);
    check_all_queues_empty("after CMD/TX flush");

    rd_cmd              = '0;
    rd_cmd.attr         = RegularTransfer;
    rd_cmd.tid          = 4'd8;
    rd_cmd.rnw          = 1'b1;
    rd_cmd.mode         = sdr0;
    rd_cmd.toc          = 1'b1;
    rd_cmd.wroc         = 1'b1;
    rd_cmd.dev_idx      = 5'd0;
    rd_cmd.data_length  = 16'd4;

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

    request_sw_reset(1'b1);
    check_all_queues_empty("after RX/RESP flush");

    reg_read(ADDR_RX_DATA, data);
    reg_read(ADDR_RESP, data);

    `uvm_info(`gfn, "CSR software reset queue flush checks passed", UVM_LOW)
  endtask

endclass
