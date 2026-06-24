class i3c_read_tbit_no_parity_resp_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_tbit_no_parity_resp_vseq)

  localparam int unsigned DATA_LENGTH = 5;
  localparam logic [3:0]  RESP_PARITY = 4'h2;

  function new(string name = "i3c_read_tbit_no_parity_resp_vseq");
    super.new(name);
  endfunction

  task body();
    bit broadcast_modes[2] = '{1'b0, 1'b1};

    foreach (broadcast_modes[mode_idx]) begin
      run_final_tbit_resp_case(broadcast_modes[mode_idx]);
    end

  endtask

  virtual task run_final_tbit_resp_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
    word_queue_t            rx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    build_payload(read_data);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_008 %s final T-bit no-parity RESP",
                        private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("err013_%s_dev_seq", private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd8),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_read_stimulus_words_with_actual_len(cfg, read_data, DATA_LENGTH, rx_words, resp, dev_seq,
                                            1'b0);

    check_all_queues_empty("after ERR_008 final T-bit no-parity RESP");

    `uvm_info(`gfn, $sformatf(
                  "ERR_008 result: mode=%s resp_status=0x%0h parity_status=0x%0h tid=0x%0h rsvd=0x%0h len=%0d requested_len=%0d",
                  private_addr_mode_name(broadcast_header_enable), resp[31:28], RESP_PARITY,
                  resp[27:24], resp[23:16], resp[15:0], cfg.data_length), UVM_LOW)
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
