class i3c_private_addr_nack_resp_vseq extends i3c_base_vseq;
  `uvm_object_utils(i3c_private_addr_nack_resp_vseq)

  localparam int unsigned DATA_LENGTH = 4;
  localparam bit [6:0] I2C_STATIC_ADDR = 7'h50;
  localparam bit [6:0] I3C_DYNAMIC_ADDR = 7'h08;

  function new(string name = "i3c_private_addr_nack_resp_vseq");
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
    run_direct_ccc_target_addr_nack_resp_case(DIR_ENEC, 8'h01, 4'd11,
                                              "ERR_002 direct ENEC target_addr_nack_resp");
    run_direct_ccc_target_addr_nack_resp_case(DIR_DISEC, 8'h02, 4'd12,
                                              "ERR_002 direct DISEC target_addr_nack_resp");

  endtask

  virtual task run_write_addr_nack_resp_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_002 %s write_addr_nack_resp", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "err002_%s_write_dev_seq", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'd2),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .addr_nack(1'b1),
        .data_nack(1'b0),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(DATA_LENGTH),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    build_random_tx_words(DATA_LENGTH, exp_data, tx_words);
    run_write_stimulus(cfg, tx_words, resp, dev_seq);
    check_queue_flags(tx_paths.name, tx_paths.full_bit, tx_paths.empty_bit, 1'b0, 1'b0,
                      "after ERR_002 write address NACK RESP");
    request_sw_reset();
    check_all_queues_empty("after ERR_002 write address NACK RESP SW reset");
  endtask

  virtual task run_read_addr_nack_resp_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t        cfg;
    regular_trans_desc_t           rd_cmd;
    byte_queue_t                   no_read_data;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_002 %s read_addr_nack_resp", private_addr_mode_name(broadcast_header_enable)
        )),
        .seq_name($sformatf(
            "err002_%s_read_dev_seq", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'd3),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .addr_nack(1'b1),
        .data_nack(1'b0),
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

    check_all_queues_empty("after ERR_002 read address NACK RESP");
  endtask

  virtual task run_i2c_write_addr_nack_resp_case();
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   exp_data;
    word_queue_t                   tx_words;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(1'b0);
    write_dat_entry(0, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b1);

    cfg = make_transfer_cfg(
        .ctxt("ERR_002 i2c write_addr_nack_resp"),
        .seq_name("err002_i2c_write_dev_seq"),
        .tid(4'd4),
        .dev_idx(5'd0),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .addr_nack(1'b1),
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
    check_queue_flags(tx_paths.name, tx_paths.full_bit, tx_paths.empty_bit, 1'b0, 1'b0,
                      "after ERR_002 i2c write address NACK RESP");
    request_sw_reset();
    check_all_queues_empty("after ERR_002 i2c write address NACK RESP SW reset");
  endtask

  virtual task run_i2c_read_addr_nack_resp_case();
    transfer_stimulus_cfg_t        cfg;
    regular_trans_desc_t           rd_cmd;
    byte_queue_t                   no_read_data;
    bit                     [31:0] resp;
    i3c_device_response_seq        dev_seq;

    enable_dut(1'b0);
    write_dat_entry(0, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b1);

    cfg = make_transfer_cfg(
        .ctxt("ERR_002 i2c read_addr_nack_resp"),
        .seq_name("err002_i2c_read_dev_seq"),
        .tid(4'd5),
        .dev_idx(5'd0),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .addr_nack(1'b1),
        .data_nack(1'b0),
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

    check_all_queues_empty("after ERR_002 i2c read address NACK RESP");
  endtask

  virtual task run_i3c_imm_write_addr_nack_resp_case(bit broadcast_header_enable);
    transfer_stimulus_cfg_t            cfg;
    immediate_data_trans_desc_t        imm_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;
    byte_queue_t                       no_read_data;
    byte_queue_t                       random_data;

    enable_dut(broadcast_header_enable);
    write_dat_entry(0, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b0);

    cfg = make_transfer_cfg(
        .ctxt($sformatf(
            "ERR_002 %s i3c imm_write_addr_nack_resp",
            private_addr_mode_name(
                broadcast_header_enable
            )
        )),
        .seq_name($sformatf(
            "err002_%s_i3c_imm_write_dev_seq", private_addr_mode_name(broadcast_header_enable)
        )),
        .tid(4'd6),
        .dev_idx(5'd0),
        .target_addr(I3C_DYNAMIC_ADDR),
        .is_i3c(1'b1),
        .addr_nack(1'b1),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(broadcast_header_enable),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    imm_cmd = '0;
    imm_cmd.attr = ImmediateDataTransfer;
    imm_cmd.tid = cfg.tid;
    imm_cmd.mode = sdr0;
    imm_cmd.rnw = 1'b0;
    imm_cmd.toc = 1'b1;
    imm_cmd.wroc = 1'b1;
    randomize_immediate_write_data(cfg.data_length, imm_cmd, random_data);

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_all_queues_empty($sformatf("after %s", cfg.ctxt));
  endtask

  virtual task run_i2c_imm_write_addr_nack_resp_case();
    transfer_stimulus_cfg_t            cfg;
    immediate_data_trans_desc_t        imm_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;
    byte_queue_t                       no_read_data;
    byte_queue_t                       random_data;

    enable_dut(1'b0);
    write_dat_entry(0, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b1);

    cfg = make_transfer_cfg(
        .ctxt("ERR_002 i2c imm_write_addr_nack_resp"),
        .seq_name("err002_i2c_imm_write_dev_seq"),
        .tid(4'd7),
        .dev_idx(5'd0),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .addr_nack(1'b1),
        .data_nack(1'b0),
        .tx_before_cmd(1'b0),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );

    imm_cmd = '0;
    imm_cmd.attr = ImmediateDataTransfer;
    imm_cmd.tid = cfg.tid;
    imm_cmd.mode = sdr0;
    imm_cmd.rnw = 1'b0;
    imm_cmd.toc = 1'b1;
    imm_cmd.wroc = 1'b1;
    randomize_immediate_write_data(cfg.data_length, imm_cmd, random_data);

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    read_response(resp);

    check_all_queues_empty("after ERR_002 i2c imm write address NACK RESP");
  endtask

  virtual task run_direct_ccc_target_addr_nack_resp_case(i3c_ccc_e opcode, bit [7:0] event_byte,
                                                         bit [3:0] tid, string ctxt);
    immediate_data_trans_desc_t        ccc_cmd;
    bit                         [31:0] resp;
    i3c_device_response_seq            dev_seq;

    enable_dut(1'b0);
    write_dat_entry(0, I2C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b0);

    ccc_cmd = '0;
    ccc_cmd.attr = ImmediateDataTransfer;
    ccc_cmd.tid = tid;
    ccc_cmd.cp = 1'b1;
    ccc_cmd.cmd = opcode;
    ccc_cmd.mode = sdr0;
    ccc_cmd.dtt = 3'd4;
    ccc_cmd.rnw = 1'b0;
    ccc_cmd.toc = 1'b1;
    ccc_cmd.wroc = 1'b1;
    ccc_cmd.dev_idx = 5'd0;
    ccc_cmd.def_or_data_byte1 = event_byte;

    dev_seq = i3c_device_response_seq::type_id::create("err002_direct_ccc_target_nack_dev_seq");
    dev_seq.target_addr = 7'h7e;
    dev_seq.addr_nack = 1'b0;
    dev_seq.is_i3c = 1'b1;
    dev_seq.dir = 1'b0;
    dev_seq.ccc_target_addr = I3C_DYNAMIC_ADDR ^ 7'h01;
    dev_seq.ccc_target_addr_valid = 1'b1;

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(ccc_cmd[31:0], ccc_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, ctxt, 2000);
    read_response(resp);

    check_all_queues_empty($sformatf("after %s", ctxt));

    disable device_response;
  endtask

endclass
