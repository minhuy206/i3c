class bus_od_pp_phase_switch_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_od_pp_phase_switch_vseq)

  localparam int unsigned NUM_TEST_BYTES = 4;
  localparam int unsigned I3C_DEV_IDX = 0;
  localparam int unsigned I2C_DEV_IDX = 1;

  localparam bit [6:0] I3C_STATIC_ADDR = 7'h50;
  localparam bit [6:0] I3C_DYNAMIC_ADDR = 7'h08;
  localparam bit [6:0] I2C_STATIC_ADDR = 7'h52;
  localparam bit [6:0] I2C_DYNAMIC_ADDR = 7'h00;

  function new(string name = "bus_od_pp_phase_switch_vseq");
    super.new(name);
  endfunction

  task body();
    enable_dut();
    write_dat_entry(I3C_DEV_IDX, I3C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b0);
    write_dat_entry(I2C_DEV_IDX, I2C_STATIC_ADDR, I2C_DYNAMIC_ADDR, 1'b1);

    run_i3c_write_stimulus();
    run_i3c_read_stimulus();
    run_i3c_toc_zero_rstart_stimulus();
    run_i2c_write_stimulus();
    run_i2c_read_stimulus();

  endtask

  virtual task run_i3c_write_stimulus();
    transfer_stimulus_cfg_t        cfg;
    word_queue_t                   tx_words;
    i3c_device_response_seq        dev_seq;
    bit                     [31:0] resp;

    cfg = make_transfer_cfg(
        .ctxt("BUS_010 write"),
        .seq_name("bus010_write_dev_seq"),
        .tid(4'd10),
        .dev_idx(I3C_DEV_IDX[4:0]),
        .target_addr(I3C_DYNAMIC_ADDR),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(NUM_TEST_BYTES),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );
    tx_words.push_back(32'h5AA5_00FF);

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

  endtask

  virtual task run_i3c_read_stimulus();
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    i3c_device_response_seq        dev_seq;
    bit                     [ 7:0] exp_data  [NUM_TEST_BYTES];
    bit                     [31:0] exp_rx;
    bit                     [31:0] resp;
    bit                     [31:0] rx;

    exp_data[0] = 8'hCA;
    exp_data[1] = 8'hFE;
    exp_data[2] = 8'hBA;
    exp_data[3] = 8'hBE;
    exp_rx      = {exp_data[3], exp_data[2], exp_data[1], exp_data[0]};
    for (int i = 0; i < NUM_TEST_BYTES; i++) begin
      read_data.push_back(exp_data[i]);
    end

    cfg = make_transfer_cfg(
        .ctxt("BUS_010 I3C read"),
        .seq_name("bus010_i3c_read_dev_seq"),
        .tid(4'd11),
        .dev_idx(I3C_DEV_IDX[4:0]),
        .target_addr(I3C_DYNAMIC_ADDR),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(NUM_TEST_BYTES),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );
    run_read_stimulus(cfg, read_data, rx, resp, dev_seq);

  endtask

  virtual task run_i3c_toc_zero_rstart_stimulus();
    transfer_stimulus_cfg_t        cfg0;
    transfer_stimulus_cfg_t        cfg1;
    word_queue_t                   tx_words;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    int                            rstart_count;

    cfg0 = make_transfer_cfg(
        .ctxt("BUS_010 TOC0 first write"),
        .seq_name("bus010_toc0_dev_seq0"),
        .tid(4'd12),
        .dev_idx(I3C_DEV_IDX[4:0]),
        .target_addr(I3C_DYNAMIC_ADDR),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(2),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );
    cfg1 = make_transfer_cfg(
        .ctxt("BUS_010 TOC0 second write"),
        .seq_name("bus010_toc0_dev_seq1"),
        .tid(4'd13),
        .dev_idx(I3C_DEV_IDX[4:0]),
        .target_addr(I3C_DYNAMIC_ADDR),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(2),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    tx_words.push_back(32'h0000_BBAA);
    tx_words.push_back(32'h0000_DDCC);

    run_toc_zero_write_stimulus(cfg0, cfg1, tx_words, resp0, resp1, rstart_count, dev_seq0,
                                dev_seq1);


  endtask

  virtual task run_i2c_write_stimulus();
    transfer_stimulus_cfg_t        cfg;
    word_queue_t                   tx_words;
    i3c_device_response_seq        dev_seq;
    bit                     [31:0] resp;

    cfg = make_transfer_cfg(
        .ctxt("BUS_010 I2C write"),
        .seq_name("bus010_i2c_write_dev_seq"),
        .tid(4'd14),
        .dev_idx(I2C_DEV_IDX[4:0]),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(NUM_TEST_BYTES),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );
    tx_words.push_back(32'h1122_3344);

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

  endtask

  virtual task run_i2c_read_stimulus();
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    i3c_device_response_seq        dev_seq;
    bit                     [ 7:0] exp_data  [NUM_TEST_BYTES];
    bit                     [31:0] exp_rx;
    bit                     [31:0] resp;
    bit                     [31:0] rx;

    exp_data[0] = 8'h12;
    exp_data[1] = 8'h34;
    exp_data[2] = 8'h56;
    exp_data[3] = 8'h78;
    exp_rx      = {exp_data[3], exp_data[2], exp_data[1], exp_data[0]};
    for (int i = 0; i < NUM_TEST_BYTES; i++) begin
      read_data.push_back(exp_data[i]);
    end

    cfg = make_transfer_cfg(
        .ctxt("BUS_010 I2C read"),
        .seq_name("bus010_i2c_read_dev_seq"),
        .tid(4'd15),
        .dev_idx(I2C_DEV_IDX[4:0]),
        .target_addr(I2C_STATIC_ADDR),
        .is_i3c(1'b0),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(NUM_TEST_BYTES),
        .settle_before_cmd(5),
        .timeout_cycles(0)
    );
    run_read_stimulus(cfg, read_data, rx, resp, dev_seq);

  endtask

endclass
