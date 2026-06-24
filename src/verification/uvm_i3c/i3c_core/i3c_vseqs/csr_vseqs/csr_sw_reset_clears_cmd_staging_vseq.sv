class csr_sw_reset_clears_cmd_staging_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_sw_reset_clears_cmd_staging_vseq)

  function new(string name = "csr_sw_reset_clears_cmd_staging_vseq");
    super.new(name);
  endfunction

  task body();
    regular_trans_desc_t           stale_cmd;
    regular_trans_desc_t           fresh_cmd;
    i3c_device_response_seq        dev_seq;
    bit                     [31:0] status;
    bit                     [31:0] resp;
    bit                     [31:0] fresh_dword0;
    bit                     [31:0] fresh_dword1;
    bit                     [31:0] tx_data;

    poll_idle();

    stale_cmd             = '0;
    stale_cmd.attr        = RegularTransfer;
    stale_cmd.tid         = 4'd3;
    stale_cmd.rnw         = 1'b1;
    stale_cmd.mode        = sdr0;
    stale_cmd.toc         = 1'b1;
    stale_cmd.wroc        = 1'b1;
    stale_cmd.dev_idx     = 5'd0;
    stale_cmd.data_length = 16'd12;

    reg_write(ADDR_CMD_QUEUE, stale_cmd[31:0]);
    settle_cycles();

    request_sw_reset(1'b0);

    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    fresh_cmd             = '0;
    fresh_cmd.attr        = RegularTransfer;
    fresh_cmd.tid         = 4'd9;
    fresh_cmd.rnw         = 1'b0;
    fresh_cmd.mode        = sdr0;
    fresh_cmd.toc         = 1'b1;
    fresh_cmd.wroc        = 1'b1;
    fresh_cmd.dev_idx     = 5'd0;
    fresh_cmd.data_length = 16'd4;

    fresh_dword0          = fresh_cmd[31:0];
    fresh_dword1          = fresh_cmd[63:32];
    tx_data               = 32'h7856_3412;

    reg_write(ADDR_CMD_QUEUE, fresh_dword0);
    settle_cycles();

    reg_write(ADDR_CMD_QUEUE, fresh_dword1);
    write_tx_data(tx_data);
    settle_cycles();

    dev_seq               = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr   = 7'h08;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = fresh_cmd.data_length;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    enable_dut();
    poll_idle();
    wait_for_device_done(dev_seq, "csr_sw_reset_clears_cmd_staging_vseq");

    read_response(resp);


    reg_read(ADDR_QUEUE_STATUS, status);

  endtask

endclass
