class i3c_write_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_write_vseq)

  function new(string name = "i3c_write_vseq");
    super.new(name);
  endfunction

  task body();
    transfer_stimulus_cfg_t cfg;
    word_queue_t            tx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg               = make_transfer_cfg("write_vseq", "dev_seq", 4'd1, 5'd0, 7'h08, 1'b1, 4);
    cfg.tx_before_cmd = 1'b0;
    tx_words.push_back(32'hDEAD_BEEF);

    run_write_stimulus(cfg, tx_words, resp, dev_seq);
    `DV_CHECK_EQ(resp[31:28], 4'h0,  "write_vseq: expected Success response")
    `DV_CHECK_EQ(resp[15:0],  16'd4, "write_vseq: expected data_length 4")
  endtask

endclass
