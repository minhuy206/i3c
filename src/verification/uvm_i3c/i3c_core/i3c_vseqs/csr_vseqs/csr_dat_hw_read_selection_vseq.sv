class csr_dat_hw_read_selection_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_dat_hw_read_selection_vseq)

  localparam int unsigned NUM_CASES = 6;
  localparam int unsigned DATA_LENGTH = 1;

  function new(string name = "csr_dat_hw_read_selection_vseq");
    super.new(name);
  endfunction

  task body();
    bit [4:0] dev_idx[NUM_CASES];
    bit [6:0] static_addr[NUM_CASES];
    bit [6:0] dynamic_addr[NUM_CASES];
    bit       is_i2c[NUM_CASES];

    dev_idx[0]      = 5'd0;
    dev_idx[1]      = 5'd1;
    dev_idx[2]      = 5'd14;
    dev_idx[3]      = 5'd15;
    dev_idx[4]      = 5'd16;
    dev_idx[5]      = 5'd31;

    static_addr[0]  = 7'h50;
    static_addr[1]  = 7'h51;
    static_addr[2]  = 7'h52;
    static_addr[3]  = 7'h53;
    static_addr[4]  = 7'h54;
    static_addr[5]  = 7'h55;

    dynamic_addr[0] = 7'h08;
    dynamic_addr[1] = 7'h12;
    dynamic_addr[2] = 7'h00;
    dynamic_addr[3] = 7'h00;
    dynamic_addr[4] = 7'h00;
    dynamic_addr[5] = 7'h00;

    is_i2c[0]       = 1'b0;
    is_i2c[1]       = 1'b0;
    is_i2c[2]       = 1'b1;
    is_i2c[3]       = 1'b1;
    is_i2c[4]       = 1'b1;
    is_i2c[5]       = 1'b1;

    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr = dynamic_addr[0];
    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr_valid = 1'b1;
    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.dynamic_addr = dynamic_addr[1];
    p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.dynamic_addr_valid = 1'b1;

    enable_dut();

    for (int unsigned i = 0; i < NUM_CASES; i++) begin
      write_dat_entry(dev_idx[i], static_addr[i], dynamic_addr[i], is_i2c[i]);
    end

    for (int unsigned i = 0; i < NUM_CASES; i++) begin
      run_dat_index_write_case(i, dev_idx[i],
                               is_i2c[i] ? static_addr[i] : dynamic_addr[i],
                               !is_i2c[i]);
    end

    check_all_queues_empty("after CSR DAT hardware read selection");

  endtask

  virtual task run_dat_index_write_case(int unsigned case_idx, bit [4:0] dev_idx,
                                        bit [6:0] exp_addr, bit is_i3c);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            exp_data;
    word_queue_t            tx_words;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;

    cfg = make_transfer_cfg(
        .ctxt($sformatf("CSR_005 DAT hardware read dev_idx %0d", dev_idx)),
        .seq_name($sformatf("csr005_dat_hw_dev_seq_%0d", case_idx)),
        .tid(4'(4'h5 + case_idx)),
        .dev_idx(dev_idx),
        .target_addr(exp_addr),
        .is_i3c(is_i3c),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    build_random_tx_words(DATA_LENGTH, exp_data, tx_words);

    run_write_stimulus(cfg, tx_words, resp, dev_seq);
    settle_cycles();
  endtask


endclass
