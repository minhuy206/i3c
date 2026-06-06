class i3c_write_back_to_back_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_back_to_back_vseq)

  function new(string name = "i3c_write_back_to_back_vseq");
    super.new(name);
  endfunction

  task body();
    transfer_stimulus_cfg_t cfg0;
    transfer_stimulus_cfg_t cfg1;
    transfer_stimulus_cfg_t cfg2;
    byte_queue_t            exp_data0;
    byte_queue_t            exp_data1;
    byte_queue_t            exp_data2;
    word_queue_t            tx_words;
    bit              [31:0] resp0;
    bit              [31:0] resp1;
    bit              [31:0] resp2;
    i3c_device_response_seq dev_seq0;
    i3c_device_response_seq dev_seq1;
    i3c_device_response_seq dev_seq2;

    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg0 = make_transfer_cfg("SDRW_008 back_to_back[0]", "sdrw008_dev_seq0", 4'h8,
                             5'd0, 7'h08, 1'b1, 3);
    cfg1 = make_transfer_cfg("SDRW_008 back_to_back[1]", "sdrw008_dev_seq1", 4'h9,
                             5'd0, 7'h08, 1'b1, 5);
    cfg2 = make_transfer_cfg("SDRW_008 back_to_back[2]", "sdrw008_dev_seq2", 4'hA,
                             5'd0, 7'h08, 1'b1, 4);

    build_payloads(exp_data0, exp_data1, exp_data2, tx_words);
    start_back_to_back_device_responses(cfg0, cfg1, cfg2, dev_seq0, dev_seq1, dev_seq2);

    write_tx_words(tx_words);
    write_write_cmd(cfg0);
    write_write_cmd(cfg1);
    write_write_cmd(cfg2);

    configure_dut();
    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    wait_for_device_done(dev_seq2, cfg2.ctxt, device_done_timeout_cycles(cfg2));

    read_response(resp0);
    read_response(resp1);
    read_response(resp2);

    check_device_write(dev_seq0, cfg0, exp_data0);
    check_device_write(dev_seq1, cfg1, exp_data1);
    check_device_write(dev_seq2, cfg2, exp_data2);

    check_success_resp(resp0, cfg0);
    check_success_resp(resp1, cfg1);
    check_success_resp(resp2, cfg2);

    check_all_queues_empty("after SDRW_008 back_to_back");

    `uvm_info(`gfn, "SDRW_008 I3C back-to-back write checks passed", UVM_LOW)
  endtask

  virtual task start_back_to_back_device_responses(input transfer_stimulus_cfg_t cfg0,
                                                   input transfer_stimulus_cfg_t cfg1,
                                                   input transfer_stimulus_cfg_t cfg2,
                                                   output i3c_device_response_seq dev_seq0,
                                                   output i3c_device_response_seq dev_seq1,
                                                   output i3c_device_response_seq dev_seq2);
    byte_queue_t no_read_data;

    start_device_response(cfg0, 1'b0, no_read_data, dev_seq0);
    wait_for_device_request_issued(dev_seq0, cfg0.ctxt);

    start_device_response(cfg1, 1'b0, no_read_data, dev_seq1);
    settle_cycles(1);
    start_device_response(cfg2, 1'b0, no_read_data, dev_seq2);
    settle_cycles(1);
  endtask

  virtual task write_write_cmd(input transfer_stimulus_cfg_t cfg);
    regular_trans_desc_t wr_cmd;

    wr_cmd = build_regular_transfer_cmd(cfg, 1'b0, 1'b1);
    write_cmd(wr_cmd[31:0], wr_cmd[63:32]);
  endtask

  virtual task check_device_write(input i3c_device_response_seq dev_seq,
                                  input transfer_stimulus_cfg_t cfg,
                                  input byte_queue_t exp_data);
    `DV_CHECK_EQ(dev_seq.done, 1'b1,
                 $sformatf("%s: device response did not finish", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.sampled_addr, cfg.target_addr,
                 $sformatf("%s: target address mismatch", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0,
                 $sformatf("%s: transfer direction should be write", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.observed_rstart, 1'b0,
                 $sformatf("%s: transfer should end with STOP", cfg.ctxt))
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), exp_data.size(),
                 $sformatf("%s: sampled byte count mismatch", cfg.ctxt))
    for (int unsigned i = 0; i < exp_data.size(); i++) begin
      if (i < dev_seq.sampled_data.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_data[i], exp_data[i],
                     $sformatf("%s: sampled byte[%0d] mismatch", cfg.ctxt, i))
      end
    end

    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), exp_data.size(),
                 $sformatf("%s: sampled T-bit count mismatch", cfg.ctxt))
    for (int unsigned i = 0; i < exp_data.size(); i++) begin
      if (i < dev_seq.sampled_t_bit.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_t_bit[i], ~^exp_data[i],
                     $sformatf("%s: T-bit parity mismatch for byte[%0d]", cfg.ctxt, i))
      end
    end
  endtask

  virtual task check_success_resp(input bit [31:0] resp, input transfer_stimulus_cfg_t cfg);
    `DV_CHECK_EQ(resp[31:28], 4'h0, $sformatf("%s: expected Success response", cfg.ctxt))
    `DV_CHECK_EQ(resp[27:24], cfg.tid, $sformatf("%s: response TID mismatch", cfg.ctxt))
    `DV_CHECK_EQ(resp[15:0], 16'(cfg.data_length),
                 $sformatf("%s: response length mismatch", cfg.ctxt))
  endtask

  virtual function void build_payloads(ref byte_queue_t exp_data0,
                                       ref byte_queue_t exp_data1,
                                       ref byte_queue_t exp_data2,
                                       ref word_queue_t tx_words);
    exp_data0.delete();
    exp_data1.delete();
    exp_data2.delete();
    tx_words.delete();

    exp_data0.push_back(8'h10);
    exp_data0.push_back(8'h11);
    exp_data0.push_back(8'h12);

    exp_data1.push_back(8'h20);
    exp_data1.push_back(8'h21);
    exp_data1.push_back(8'h22);
    exp_data1.push_back(8'h23);
    exp_data1.push_back(8'h24);

    exp_data2.push_back(8'h30);
    exp_data2.push_back(8'h31);
    exp_data2.push_back(8'h32);
    exp_data2.push_back(8'h33);

    tx_words.push_back(32'hE712_1110);
    tx_words.push_back(32'h2322_2120);
    tx_words.push_back(32'hD6C5_B424);
    tx_words.push_back(32'h3332_3130);
  endfunction

endclass
