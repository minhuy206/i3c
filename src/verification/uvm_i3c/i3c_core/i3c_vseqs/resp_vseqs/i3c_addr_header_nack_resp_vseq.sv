class i3c_addr_header_nack_resp_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_addr_header_nack_resp_vseq)

  localparam int unsigned DATA_LENGTH = 4;
  localparam bit [31:0]   TX_WORD = 32'hA5C3_5A3C;
  localparam logic [3:0]  RESP_ADDR_HEADER = 4'h4;
  localparam bit [6:0]    I2C_STATIC_ADDR = 7'h50;
  localparam bit [6:0]    I3C_DYNAMIC_ADDR = 7'h08;

  function new(string name = "i3c_addr_header_nack_resp_vseq");
    super.new(name);
  endfunction

  virtual task body();
    run_write_addr_nack_resp_case(1'b0);
    run_write_addr_nack_resp_case(1'b1);
    run_read_addr_nack_resp_case(1'b0);
    run_read_addr_nack_resp_case(1'b1);
    run_i2c_write_addr_nack_resp_case();
    run_i2c_read_addr_nack_resp_case();
    run_i3c_imm_write_addr_nack_resp_case(1'b0);
    run_i3c_imm_write_addr_nack_resp_case(1'b1);
    run_i2c_imm_write_addr_nack_resp_case();

  endtask

  virtual task run_write_addr_nack_resp_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg;
    word_queue_t            tx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_002 %s write_addr_nack_resp",
                        private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("err002_%s_write_dev_seq",
                            private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd2),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b0),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    tx_words.push_back(TX_WORD);
    run_write_stimulus(cfg, tx_words, resp, dev_seq);
    check_error_resp_fields(resp, RESP_ADDR_HEADER, cfg.tid, 0, cfg.ctxt);
    check_queue_flags(tx_paths.name, tx_paths.full_bit, tx_paths.empty_bit, 1'b0, 1'b0,
                      "after ERR_002 write address NACK RESP");
    request_sw_reset();
    check_all_queues_empty("after ERR_002 write address NACK RESP SW reset");
  endtask

  virtual task run_read_addr_nack_resp_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t cfg;
    regular_trans_desc_t    rd_cmd;
    byte_queue_t            no_read_data;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_002 %s read_addr_nack_resp",
                        private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("err002_%s_read_dev_seq",
                            private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd3),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b0),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b1);
    start_device_response(cfg, 1'b1, no_read_data, dev_seq);
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_error_resp_fields(resp, RESP_ADDR_HEADER, cfg.tid, 0, cfg.ctxt);
    check_all_queues_empty("after ERR_002 read address NACK RESP");
  endtask

  // Legacy I2C static-address NACK is folded into ERR_002: it uses the same
  // AddrHeader response encoding and no-data-phase policy as the I3C cases above.
  virtual task run_i2c_write_addr_nack_resp_case();
    transfer_stimulus_cfg_t cfg;
    word_queue_t            tx_words;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut(1'b0);
    write_dat_entry(0, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b1);

    cfg = make_transfer_cfg(
        .ctxt("ERR_002 i2c write_addr_nack_resp"),
        .seq_name("err002_i2c_write_dev_seq"),
        .tid(4'd4),
        .dev_idx(5'd0),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b0),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    tx_words.push_back(TX_WORD);
    run_write_stimulus(cfg, tx_words, resp, dev_seq);
    check_error_resp_fields(resp, RESP_ADDR_HEADER, cfg.tid, 0, cfg.ctxt);
    check_queue_flags(tx_paths.name, tx_paths.full_bit, tx_paths.empty_bit, 1'b0, 1'b0,
                      "after ERR_002 i2c write address NACK RESP");
    request_sw_reset();
    check_all_queues_empty("after ERR_002 i2c write address NACK RESP SW reset");
  endtask

  virtual task run_i2c_read_addr_nack_resp_case();
    transfer_stimulus_cfg_t cfg;
    regular_trans_desc_t    rd_cmd;
    byte_queue_t            no_read_data;
    bit [31:0]              resp;
    i3c_device_response_seq dev_seq;

    enable_dut(1'b0);
    write_dat_entry(0, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b1);

    cfg = make_transfer_cfg(
        .ctxt("ERR_002 i2c read_addr_nack_resp"),
        .seq_name("err002_i2c_read_dev_seq"),
        .tid(4'd5),
        .dev_idx(5'd0),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b0),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b1);
    start_device_response(cfg, 1'b1, no_read_data, dev_seq);
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_error_resp_fields(resp, RESP_ADDR_HEADER, cfg.tid, 0, cfg.ctxt);
    check_all_queues_empty("after ERR_002 i2c read address NACK RESP");
  endtask

  // IMM_005 (legacy) folded into ERR_002: an immediate write whose target address
  // is NACKed must produce the same AddrHeader response as the regular cases, and
  // the controller must generate STOP immediately with no inline data byte sent.
  // Covered for both I3C (both broadcast-header modes) and I2C device classes.
  virtual task run_i3c_imm_write_addr_nack_resp_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t     cfg;
    immediate_data_trans_desc_t imm_cmd;
    bit [31:0]                  resp;
    i3c_device_response_seq     dev_seq;
    byte_queue_t                no_read_data;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf("ERR_002 %s i3c imm_write_addr_nack_resp",
                        private_addr_mode_name(broadcast_header_enable))),
        .seq_name($sformatf("err002_%s_i3c_imm_write_dev_seq",
                            private_addr_mode_name(broadcast_header_enable))),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(I3C_DYNAMIC_ADDR),
        .is_i3c(1'b1),
        .ack_address(1'b0),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = cfg.tid;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = 3'd2;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.def_or_data_byte1 = 8'hAA;
    imm_cmd.data_byte2        = 8'hBB;

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_error_resp_fields(resp, RESP_ADDR_HEADER, cfg.tid, 0, cfg.ctxt);
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), 0,
                 $sformatf("%s: no inline data byte may be sent after address NACK", cfg.ctxt))
    check_all_queues_empty($sformatf("after %s", cfg.ctxt));
  endtask

  virtual task run_i2c_imm_write_addr_nack_resp_case();
    transfer_stimulus_cfg_t     cfg;
    immediate_data_trans_desc_t imm_cmd;
    bit [31:0]                  resp;
    i3c_device_response_seq     dev_seq;
    byte_queue_t                no_read_data;

    enable_dut(1'b0);
    write_dat_entry(0, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b1);

    cfg = make_transfer_cfg(
        .ctxt("ERR_002 i2c imm_write_addr_nack_resp"),
        .seq_name("err002_i2c_imm_write_dev_seq"),
        .tid(4'd7),
        .dev_idx(5'd0),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b0),
        .ack_data(1'b1),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    imm_cmd                   = '0;
    imm_cmd.attr              = ImmediateDataTransfer;
    imm_cmd.tid               = cfg.tid;
    imm_cmd.mode              = sdr0;
    imm_cmd.dtt               = 3'd2;
    imm_cmd.rnw               = 1'b0;
    imm_cmd.toc               = 1'b1;
    imm_cmd.wroc              = 1'b1;
    imm_cmd.def_or_data_byte1 = 8'hD1;
    imm_cmd.data_byte2        = 8'hD2;

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_error_resp_fields(resp, RESP_ADDR_HEADER, cfg.tid, 0, cfg.ctxt);
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), 0,
                 $sformatf("%s: no inline data byte may be sent after address NACK", cfg.ctxt))
    check_all_queues_empty("after ERR_002 i2c imm write address NACK RESP");
  endtask

endclass
