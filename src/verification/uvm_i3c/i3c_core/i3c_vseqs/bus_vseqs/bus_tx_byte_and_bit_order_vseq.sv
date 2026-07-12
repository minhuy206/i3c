class bus_tx_byte_and_bit_order_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_tx_byte_and_bit_order_vseq)

  localparam int unsigned NUM_PATTERNS = 5;

  function new(string name = "bus_tx_byte_and_bit_order_vseq");
    super.new(name);
  endfunction

  task body();
    bit [6:0] static_addr;
    bit [6:0] dynamic_addr;

    static_addr  = 7'h50;
    dynamic_addr = 7'h08;

    enable_dut();
    write_dat_entry(0, static_addr, dynamic_addr, 1'b0);

    for (int unsigned pattern_idx = 0; pattern_idx < NUM_PATTERNS; pattern_idx++) begin
      run_pattern_case(pattern_idx, dynamic_addr);
    end
  endtask

  virtual task run_pattern_case(int unsigned pattern_idx, bit [6:0] dynamic_addr);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    i3c_device_response_seq        dev_seq;
    bit                     [31:0] resp;

    build_sdr_data_pattern_payload(pattern_idx, exp_data);
    pack_payload_words(exp_data, tx_words);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("BUS_010 pattern %0d", pattern_idx)),
        .seq_name($sformatf("bus010_dev_seq_%0d", pattern_idx)),
        .tid(4'(pattern_idx + 1)),
        .dev_idx(5'd0),
        .target_addr(dynamic_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(exp_data.size()),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    run_write_stimulus(cfg, tx_words, resp, dev_seq);
  endtask

endclass
