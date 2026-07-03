class i3c_read_len_sweep_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_read_len_sweep_vseq)

  localparam int unsigned NUM_LENGTHS = 8;

  function new(string name = "i3c_read_len_sweep_vseq");
    super.new(name);
  endfunction

  task body();
    int unsigned lengths[NUM_LENGTHS] = '{1, 2, 3, 4, 5, 7, 8, 16};
    bit broadcast_modes[2] = '{1'b0, 1'b1};
    bit [6:0] static_addr;
    bit [6:0] dynamic_addr;

    foreach (broadcast_modes[mode_idx]) begin
      enable_dut(broadcast_modes[mode_idx]);
      randomize_i3c_dat_target(0, static_addr, dynamic_addr);

      foreach (lengths[sweep_idx]) begin
        run_len_case(sweep_idx, lengths[sweep_idx], broadcast_modes[mode_idx], dynamic_addr);
      end
    end

  endtask

  virtual task run_len_case(int unsigned sweep_idx, int unsigned data_length,
                            bit broadcast_header_enable, bit [6:0] dynamic_addr);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    word_queue_t                   rx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    build_payload(data_length, read_data);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "SDRR_002 %s len %0d", private_addr_mode_name(broadcast_header_enable), data_length
        )),
        .seq_name($sformatf(
            "sdrr002_%s_dev_seq_%0d", private_addr_mode_name(broadcast_header_enable), data_length
        )),
        .tid(4'(sweep_idx + 1)),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(data_length),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_read_stimulus_words(cfg, read_data, rx_words, resp, dev_seq);

    check_all_queues_empty($sformatf("after SDRR_002 len %0d", data_length));

  endtask

  virtual function void build_payload(int unsigned data_length, ref byte_queue_t read_data);
    build_random_payload(data_length, read_data);
  endfunction

endclass
