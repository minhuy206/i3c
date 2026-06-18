class i3c_short_read_resp_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_short_read_resp_vseq)

  localparam int unsigned REQUESTED_LENGTH = 8;
  localparam int unsigned ACTUAL_LENGTH = 3;
  localparam logic [3:0] RESP_SHORT_READ = 4'h7;

  function new(string name = "i3c_short_read_resp_vseq");
    super.new(name);
  endfunction

  virtual task body();
    run_short_read_resp_case(1'b0);
    run_short_read_resp_case(1'b1);

  endtask

  virtual task run_short_read_resp_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    word_queue_t                   rx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);
    build_payload(read_data);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_004 %s short_read_resp", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "err004_%s_short_read_dev_seq", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'd4),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(REQUESTED_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_read_stimulus_words_with_actual_len(cfg, read_data, ACTUAL_LENGTH, rx_words, resp, dev_seq);
    check_error_resp_fields(resp, RESP_SHORT_READ, cfg.tid, ACTUAL_LENGTH, cfg.ctxt);
    check_all_queues_empty("after ERR_004 short read RESP");
  endtask

  virtual function void build_payload(ref byte_queue_t read_data);
    read_data.delete();
    for (int unsigned i = 0; i < ACTUAL_LENGTH; i++) begin
      read_data.push_back(8'(8'h90 + i));
    end
  endfunction

endclass
