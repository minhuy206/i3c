class i3c_ccc_broadcast_enec_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_ccc_broadcast_enec_vseq)

  function new(string name = "i3c_ccc_broadcast_enec_vseq");
    super.new(name);
  endfunction

  virtual task body();
    immediate_data_trans_desc_t        ccc_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;

    enable_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    ccc_cmd                   = '0;
    ccc_cmd.attr              = ImmediateDataTransfer;
    ccc_cmd.tid               = 4'd2;
    ccc_cmd.cp                = 1'b1;
    ccc_cmd.cmd               = ENEC;
    ccc_cmd.mode              = sdr0;
    ccc_cmd.dtt               = 3'd4;
    ccc_cmd.rnw               = 1'b0;
    ccc_cmd.toc               = 1'b1;
    ccc_cmd.wroc              = 1'b1;
    ccc_cmd.dev_idx           = 5'd0;
    ccc_cmd.def_or_data_byte1 = 8'h01;

    dev_seq                   = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr       = 7'h7e;
    dev_seq.addr_nack       = 1'b0;
    dev_seq.is_i3c            = 1'b1;
    dev_seq.dir               = 1'b0;

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(ccc_cmd[31:0], ccc_cmd[63:32]);

    poll_idle();

    for (int i = 0; i < 1000; i++) begin
      if (dev_seq.done) break;
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    end
    read_response(resp);

    disable device_response;
  endtask
endclass
