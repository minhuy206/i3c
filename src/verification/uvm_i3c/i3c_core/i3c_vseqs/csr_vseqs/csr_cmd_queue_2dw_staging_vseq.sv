class csr_cmd_queue_2dw_staging_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_cmd_queue_2dw_staging_vseq)

  function new(string name = "csr_cmd_queue_2dw_staging_vseq");
    super.new(name);
  endfunction

  task body();
    immediate_data_trans_desc_t        imm_cmd;
    i3c_device_response_seq            dev_seq;
    bit                         [31:0] status;
    bit                         [31:0] resp;
    bit                         [31:0] dword0;
    bit                         [31:0] dword1;
    int unsigned                       exp_data_bytes;

    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = 4'd5;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = 3'd2;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.dev_idx           = 5'd0;
    imm_cmd.def_or_data_byte1 = 8'hA5;
    imm_cmd.data_byte2        = 8'h3C;
    exp_data_bytes            = int'(imm_cmd.dtt);

    dword0                    = imm_cmd[31:0];
    dword1                    = imm_cmd[63:32];

    reg_write(ADDR_CMD_QUEUE, dword0);
    settle_cycles();

    reg_write(ADDR_CMD_QUEUE, dword1);
    settle_cycles();

    dev_seq             = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr   = 7'h08;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = exp_data_bytes;
    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    enable_dut();

    poll_idle();
    wait_for_device_done(dev_seq, "csr_cmd_queue_2dw_staging_vseq");
    if ((dev_seq.sampled_data.size() >= exp_data_bytes) &&
        (dev_seq.sampled_t_bit.size() >= exp_data_bytes)) begin
      for (int unsigned i = 0; i < exp_data_bytes; i++) begin
        bit exp_t_bit;

        exp_t_bit = ~^dev_seq.sampled_data[i];
      end
    end

    read_response(resp);

    reg_read(ADDR_QUEUE_STATUS, status);

  endtask

endclass
