class i3c_read_no_parity_error_on_end_tbit_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_no_parity_error_on_end_tbit_vseq)

  localparam int unsigned DATA_LENGTH = 5;

  function new(string name = "i3c_read_no_parity_error_on_end_tbit_vseq");
    super.new(name);
  endfunction

  task body();
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    word_queue_t            rx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    build_payload(read_data);

    cfg                  = make_transfer_cfg(
        "SDRR_008 final T-bit end",
        "sdrr008_dev_seq",
        4'd8,
        5'd0,
        7'h08,
        1'b1,
        DATA_LENGTH
    );
    cfg.wait_device_done = 1'b1;

    run_read_stimulus_words_with_actual_len(cfg, read_data, DATA_LENGTH, rx_words, resp,
                                            dev_seq, 1'b0);

    `DV_CHECK_EQ(dev_seq.done, 1'b1, "SDRR_008: device response did not finish")
    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08, "SDRR_008: target address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b1,
                 "SDRR_008: transfer direction should be read")

    `DV_CHECK_EQ(resp[31:28], 4'h0, "SDRR_008: expected Success response")
    `DV_CHECK_NE(resp[31:28], 4'h2, "SDRR_008: response must not be Parity")
    `DV_CHECK_EQ(resp[27:24], cfg.tid, "SDRR_008: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], 16'(DATA_LENGTH), "SDRR_008: response length mismatch")

    check_all_queues_empty("after SDRR_008 final T-bit end");

    `uvm_info(`gfn, "SDRR_008 I3C read final T-bit no-parity checks passed", UVM_LOW)
  endtask

  virtual function void build_payload(ref byte_queue_t read_data);
    read_data.delete();

    read_data.push_back(8'hA5);
    read_data.push_back(8'h5A);
    read_data.push_back(8'h3C);
    read_data.push_back(8'hC3);
    read_data.push_back(8'h96);
  endfunction

endclass
