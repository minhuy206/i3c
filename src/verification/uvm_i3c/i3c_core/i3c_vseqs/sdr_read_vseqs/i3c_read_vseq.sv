class i3c_read_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_vseq)

  function new(string name = "i3c_read_vseq");
    super.new(name);
  endfunction

  task body();
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    bit [31:0]              resp;
    bit [31:0]              rx;
    i3c_device_response_seq dev_seq;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg("read_vseq", "dev_seq", 4'd2, 5'd0, 7'h08, 1'b1, 4);
    read_data.push_back(8'hCA);
    read_data.push_back(8'hFE);
    read_data.push_back(8'hBA);
    read_data.push_back(8'hBE);

    run_read_stimulus(cfg, read_data, rx, resp, dev_seq);
    `DV_CHECK_EQ(resp[31:28], 4'h0,         "read_vseq: expected Success response")
    `DV_CHECK_EQ(resp[27:24], cfg.tid,       "read_vseq: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0],  16'd4,         "read_vseq: response length mismatch")
    `DV_CHECK_EQ(rx,          32'hBEBA_FECA, "read_vseq: RX data mismatch")
  endtask

endclass
