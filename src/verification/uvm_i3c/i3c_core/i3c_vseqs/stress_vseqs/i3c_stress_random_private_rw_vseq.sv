class i3c_stress_random_private_rw_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_stress_random_private_rw_vseq)

  localparam int unsigned MIN_TRANSACTION_COUNT = 100;
  localparam int unsigned MAX_TRANSACTION_COUNT = 1000;
  localparam int unsigned QUEUE_CHECK_INTERVAL = 100;

  function new(string name = "i3c_stress_random_private_rw_vseq");
    super.new(name);
  endfunction

  task body();
    i3c_private_rw_stress_stimulus stimulus;
    bit                     [6:0] static_addr[2];
    bit                     [6:0] dynamic_addr[2];
    int unsigned                  transaction_count;
    int unsigned                  completed_count;
    int unsigned                  read_count;
    int unsigned                  write_count;
    longint unsigned              read_byte_count;
    longint unsigned              write_byte_count;

    transaction_count = MIN_TRANSACTION_COUNT;
    completed_count = 0;
    read_count = 0;
    write_count = 0;
    read_byte_count = 0;
    write_byte_count = 0;
    void'($value$plusargs("I3C_STRESS_TXN_COUNT=%0d", transaction_count));
    if (!(transaction_count inside {[MIN_TRANSACTION_COUNT : MAX_TRANSACTION_COUNT]})) begin
      `uvm_fatal(`gfn, $sformatf(
                     "I3C_STRESS_TXN_COUNT=%0d is outside the supported range [%0d:%0d]",
                     transaction_count, MIN_TRANSACTION_COUNT, MAX_TRANSACTION_COUNT))
    end

    stimulus = i3c_private_rw_stress_stimulus::type_id::create("stimulus");
    configure_stress_targets(static_addr, dynamic_addr);

    `uvm_info(`gfn, $sformatf("STR_001 starting %0d constrained-random transactions",
                              transaction_count), UVM_LOW)

    for (int unsigned txn_idx = 0; txn_idx < transaction_count; txn_idx++) begin
      `DV_CHECK_RANDOMIZE_FATAL(stimulus,
                                $sformatf("STR_001 transaction %0d randomization failed", txn_idx))

      run_transaction(txn_idx, stimulus, dynamic_addr[stimulus.dev_idx]);
      completed_count++;
      if (stimulus.rnw) begin
        read_count++;
        read_byte_count += stimulus.data_length;
      end else begin
        write_count++;
        write_byte_count += stimulus.data_length;
      end

      if (((txn_idx + 1) % QUEUE_CHECK_INTERVAL) == 0) begin
        check_all_queues_empty($sformatf("after STR_001 transaction %0d", txn_idx + 1));
      end
    end

    check_all_queues_empty("after STR_001 completion");
    disable_dut();

    `uvm_info(`gfn, $sformatf({
                  "STR_001 summary: requested=%0d completed=%0d reads=%0d read_bytes=%0d ",
                  "writes=%0d write_bytes=%0d"},
                  transaction_count, completed_count, read_count, read_byte_count, write_count,
                  write_byte_count), UVM_NONE)
  endtask

  virtual task configure_stress_targets(output bit [6:0] static_addr[2],
                                        output bit [6:0] dynamic_addr[2]);
    i3c_seq_item target0;
    i3c_seq_item target1;
    bit [6:0]    target0_static_addr;
    bit [6:0]    target0_dynamic_addr;

    target0 = randomize_transfer_item("str001_target0", 0);
    target0_static_addr = target0.static_addr;
    target0_dynamic_addr = target0.addr;

    target1 = i3c_seq_item::type_id::create("str001_target1");
    target1.static_addr_constraint_en = 1'b1;
    target1.dynamic_addr_constraint_en = 1'b1;
    target1.payload_constraint_en = 1'b1;
    target1.payload_len = 0;
    if (!target1.randomize() with {
          static_addr != local::target0_static_addr;
          addr != local::target0_dynamic_addr;
        }) begin
      `uvm_fatal(`gfn, "STR_001 target1 randomization failed")
    end

    static_addr[0] = target0.static_addr;
    dynamic_addr[0] = target0.addr;
    static_addr[1] = target1.static_addr;
    dynamic_addr[1] = target1.addr;

    configure_i3c_dat_target(0, static_addr[0], dynamic_addr[0]);
    configure_i3c_dat_target(1, static_addr[1], dynamic_addr[1]);
  endtask

  virtual task run_transaction(int unsigned txn_idx,
                               i3c_private_rw_stress_stimulus stimulus,
                               bit [6:0] target_addr);
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            payload;
    word_queue_t            data_words;
    bit              [31:0] resp;
    i3c_device_response_seq dev_seq;

    payload = stimulus.data;
    cfg = make_transfer_cfg(
        .ctxt($sformatf("STR_001 transaction %0d", txn_idx)),
        .seq_name($sformatf("str001_dev_seq_%0d", txn_idx)),
        .tid(stimulus.tid),
        .dev_idx(5'(stimulus.dev_idx)),
        .target_addr(target_addr),
        .is_i3c(1'b1),
        .addr_nack(1'b0),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(stimulus.broadcast_header_enable),
        .data_length(stimulus.data_length),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    enable_dut(stimulus.broadcast_header_enable);
    if (stimulus.rnw) begin
      run_read_stimulus_words(cfg, payload, stimulus.data_length, data_words, resp, dev_seq);
    end else begin
      pack_payload_words(payload, data_words);
      run_write_stimulus(cfg, data_words, resp, dev_seq);
    end
  endtask
endclass
