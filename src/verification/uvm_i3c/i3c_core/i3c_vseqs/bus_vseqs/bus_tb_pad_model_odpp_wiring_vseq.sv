class bus_tb_pad_model_odpp_wiring_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_tb_pad_model_odpp_wiring_vseq)

  localparam int unsigned NUM_TEST_BYTES = 4;

  function new(string name = "bus_tb_pad_model_odpp_wiring_vseq");
    super.new(name);
  endfunction

  task body();
    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    run_write_stimulus();
    run_read_stimulus();

    `uvm_info(`gfn,
              "BUS_011 pad-model OD/PP wiring stimulus completed; SVA checks bus wiring",
              UVM_LOW)
  endtask

  virtual task run_write_stimulus();
    regular_trans_desc_t    wr_cmd;
    i3c_device_response_seq dev_seq;
    bit [31:0]              resp;

    wr_cmd             = '0;
    wr_cmd.attr        = RegularTransfer;
    wr_cmd.tid         = 4'd11;
    wr_cmd.rnw         = 1'b0;
    wr_cmd.mode        = sdr0;
    wr_cmd.toc         = 1'b1;
    wr_cmd.wroc        = 1'b1;
    wr_cmd.dev_idx     = 5'd0;
    wr_cmd.data_length = NUM_TEST_BYTES[15:0];

    dev_seq               = i3c_device_response_seq::type_id::create("bus011_write_dev_seq");
    dev_seq.target_addr   = 7'h08;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = NUM_TEST_BYTES;

    fork : write_device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_tx_data(32'hC33C_A55A);
    write_cmd(wr_cmd[31:0], wr_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, "BUS_011 write");

    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0, "BUS_011 write: expected Success response")
    `DV_CHECK_EQ(resp[27:24], wr_cmd.tid, "BUS_011 write: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], NUM_TEST_BYTES[15:0],
                 "BUS_011 write: response length mismatch")

    disable write_device_response;
  endtask

  virtual task run_read_stimulus();
    regular_trans_desc_t    rd_cmd;
    i3c_device_response_seq dev_seq;
    bit [7:0]               exp_data[NUM_TEST_BYTES];
    bit [31:0]              exp_rx;
    bit [31:0]              resp;
    bit [31:0]              rx;

    exp_data[0] = 8'h3c;
    exp_data[1] = 8'ha5;
    exp_data[2] = 8'h5a;
    exp_data[3] = 8'hc3;
    exp_rx      = {exp_data[3], exp_data[2], exp_data[1], exp_data[0]};

    rd_cmd             = '0;
    rd_cmd.attr        = RegularTransfer;
    rd_cmd.tid         = 4'd12;
    rd_cmd.rnw         = 1'b1;
    rd_cmd.mode        = sdr0;
    rd_cmd.toc         = 1'b1;
    rd_cmd.wroc        = 1'b1;
    rd_cmd.dev_idx     = 5'd0;
    rd_cmd.data_length = NUM_TEST_BYTES[15:0];

    dev_seq             = i3c_device_response_seq::type_id::create("bus011_read_dev_seq");
    dev_seq.target_addr = 7'h08;
    dev_seq.ack_address = 1'b1;
    dev_seq.is_i3c      = 1'b1;
    dev_seq.dir         = 1'b1;
    for (int i = 0; i < NUM_TEST_BYTES; i++) begin
      dev_seq.read_data.push_back(exp_data[i]);
    end

    fork : read_device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, "BUS_011 read");

    read_rx_data(rx);
    read_response(resp);
    `DV_CHECK_EQ(rx, exp_rx, "BUS_011 read: RX data mismatch")
    `DV_CHECK_EQ(resp[31:28], 4'h0, "BUS_011 read: expected Success response")
    `DV_CHECK_EQ(resp[27:24], rd_cmd.tid, "BUS_011 read: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], NUM_TEST_BYTES[15:0],
                 "BUS_011 read: response length mismatch")

    disable read_device_response;
  endtask

endclass
