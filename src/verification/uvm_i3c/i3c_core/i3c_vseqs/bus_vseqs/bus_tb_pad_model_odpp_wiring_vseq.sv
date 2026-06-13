class bus_tb_pad_model_odpp_wiring_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_tb_pad_model_odpp_wiring_vseq)

  localparam int unsigned NUM_TEST_BYTES = 4;

  function new(string name = "bus_tb_pad_model_odpp_wiring_vseq");
    super.new(name);
  endfunction

  task body();
    enable_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    run_bus011_write_stimulus();
    run_bus011_read_stimulus();

    `uvm_info(`gfn, "BUS_011 pad-model OD/PP wiring stimulus completed; SVA checks bus wiring",
              UVM_LOW)
  endtask

  virtual task run_bus011_write_stimulus();
    transfer_stimulus_cfg_t        cfg;
    word_queue_t                   tx_words;
    i3c_device_response_seq        dev_seq;
    bit                     [31:0] resp;

    cfg = make_transfer_cfg(
        .ctxt("BUS_011 write"),
        .seq_name("bus011_write_dev_seq"),
        .tid(4'd11),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(NUM_TEST_BYTES),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    tx_words.push_back(32'hC33C_A55A);

    run_write_stimulus(cfg, tx_words, resp, dev_seq);

    `DV_CHECK_EQ(resp[31:28], 4'h0, "BUS_011 write: expected Success response")
    `DV_CHECK_EQ(resp[27:24], cfg.tid, "BUS_011 write: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], NUM_TEST_BYTES[15:0], "BUS_011 write: response length mismatch")
  endtask

  virtual task run_bus011_read_stimulus();
    transfer_stimulus_cfg_t        cfg;
    byte_queue_t                   read_data;
    i3c_device_response_seq        dev_seq;
    bit                     [ 7:0] exp_data[NUM_TEST_BYTES];
    bit                     [31:0] exp_rx;
    bit                     [31:0] resp;
    bit                     [31:0] rx;

    exp_data[0]         = 8'h3c;
    exp_data[1]         = 8'ha5;
    exp_data[2]         = 8'h5a;
    exp_data[3]         = 8'hc3;
    exp_rx              = {exp_data[3], exp_data[2], exp_data[1], exp_data[0]};
    for (int i = 0; i < NUM_TEST_BYTES; i++) begin
      read_data.push_back(exp_data[i]);
    end

    cfg = make_transfer_cfg(
        .ctxt("BUS_011 read"),
        .seq_name("bus011_read_dev_seq"),
        .tid(4'd12),
        .dev_idx(5'd0),
        .target_addr(7'h08),
        .is_i3c(1'b1),
        .ack_address(1'b1),
        .ack_data(1'b1),
        .tx_before_cmd(1'b1),
        .wait_device_done(1'b1),
        .start_with_broadcast_header(1'b0),
        .data_length(NUM_TEST_BYTES),
        .settle_before_cmd(0),
        .timeout_cycles(0)
    );
    run_read_stimulus(cfg, read_data, rx, resp, dev_seq);

    `DV_CHECK_EQ(rx, exp_rx, "BUS_011 read: RX data mismatch")
    `DV_CHECK_EQ(resp[31:28], 4'h0, "BUS_011 read: expected Success response")
    `DV_CHECK_EQ(resp[27:24], cfg.tid, "BUS_011 read: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], NUM_TEST_BYTES[15:0], "BUS_011 read: response length mismatch")
  endtask

endclass
