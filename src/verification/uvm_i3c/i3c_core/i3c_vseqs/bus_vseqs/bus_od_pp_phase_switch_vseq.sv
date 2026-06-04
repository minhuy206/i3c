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
    configure_dut();
    write_dat_entry(I3C_DEV_IDX, I3C_STATIC_ADDR, I3C_DYNAMIC_ADDR, 1'b0);
    write_dat_entry(I2C_DEV_IDX, I2C_STATIC_ADDR, I2C_DYNAMIC_ADDR, 1'b1);

    run_i3c_write_stimulus();
    run_i3c_toc_zero_rstart_stimulus();
    run_i2c_write_stimulus();
    run_i2c_read_stimulus();

    `uvm_info(`gfn, "BUS_010 OD/PP phase switch stimuli completed; SVA checks phase behavior",
              UVM_LOW)
  endtask

  virtual task run_i3c_write_stimulus();
    regular_trans_desc_t           wr_cmd;
    i3c_device_response_seq        dev_seq;
    bit                     [31:0] resp;

    wr_cmd                = '0;
    wr_cmd.attr           = RegularTransfer;
    wr_cmd.tid            = 4'd10;
    wr_cmd.rnw            = 1'b0;
    wr_cmd.mode           = sdr0;
    wr_cmd.toc            = 1'b1;
    wr_cmd.wroc           = 1'b1;
    wr_cmd.dev_idx        = I3C_DEV_IDX[4:0];
    wr_cmd.data_length    = NUM_TEST_BYTES[15:0];

    dev_seq               = i3c_device_response_seq::type_id::create("bus010_write_dev_seq");
    dev_seq.target_addr   = I3C_DYNAMIC_ADDR;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = NUM_TEST_BYTES;

    fork : write_device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    settle_cycles(5);
    write_tx_data(32'h5AA5_00FF);
    write_cmd(wr_cmd[31:0], wr_cmd[63:32]);
    poll_idle();

    wait_for_device_done(dev_seq, "BUS_010 write");

    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0, "BUS_010 write: expected Success response")
    `DV_CHECK_EQ(resp[27:24], wr_cmd.tid, "BUS_010 write: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], NUM_TEST_BYTES[15:0], "BUS_010 write: response length mismatch")

    disable write_device_response;
  endtask

  virtual task run_i3c_toc_zero_rstart_stimulus();
    regular_trans_desc_t           wr_cmd0;
    regular_trans_desc_t           wr_cmd1;
    i3c_device_response_seq        dev_seq0;
    i3c_device_response_seq        dev_seq1;
    bit                     [31:0] resp0;
    bit                     [31:0] resp1;
    int                            rstart_count;

    wr_cmd0                = '0;
    wr_cmd0.attr           = RegularTransfer;
    wr_cmd0.tid            = 4'd12;
    wr_cmd0.rnw            = 1'b0;
    wr_cmd0.mode           = sdr0;
    wr_cmd0.toc            = 1'b0;
    wr_cmd0.wroc           = 1'b1;
    wr_cmd0.dev_idx        = I3C_DEV_IDX[4:0];
    wr_cmd0.data_length    = 16'd2;

    wr_cmd1                = '0;
    wr_cmd1.attr           = RegularTransfer;
    wr_cmd1.tid            = 4'd13;
    wr_cmd1.rnw            = 1'b0;
    wr_cmd1.mode           = sdr0;
    wr_cmd1.toc            = 1'b1;
    wr_cmd1.wroc           = 1'b1;
    wr_cmd1.dev_idx        = I3C_DEV_IDX[4:0];
    wr_cmd1.data_length    = 16'd2;

    dev_seq0               = i3c_device_response_seq::type_id::create("bus010_toc0_dev_seq0");
    dev_seq0.target_addr   = I3C_DYNAMIC_ADDR;
    dev_seq0.ack_address   = 1'b1;
    dev_seq0.is_i3c        = 1'b1;
    dev_seq0.dir           = 1'b0;
    dev_seq0.read_data_cnt = 2;

    dev_seq1               = i3c_device_response_seq::type_id::create("bus010_toc0_dev_seq1");
    dev_seq1.target_addr   = I3C_DYNAMIC_ADDR;
    dev_seq1.ack_address   = 1'b1;
    dev_seq1.is_i3c        = 1'b1;
    dev_seq1.dir           = 1'b0;
    dev_seq1.read_data_cnt = 2;

    fork : toc0_device_responses
      dev_seq0.start(p_sequencer.m_i3c_sequencer);
      dev_seq1.start(p_sequencer.m_i3c_sequencer);
    join_none

    settle_cycles(5);

    write_cmd(wr_cmd0[31:0], wr_cmd0[63:32]);
    write_cmd(wr_cmd1[31:0], wr_cmd1[63:32]);
    write_tx_data(32'h0000_BBAA);
    write_tx_data(32'h0000_DDCC);
    poll_idle();

    wait_for_device_done(dev_seq0, "BUS_010 TOC0 first write");
    wait_for_device_done(dev_seq1, "BUS_010 TOC0 second write");
    rstart_count = int'(dev_seq0.observed_rstart) + int'(dev_seq1.observed_rstart);
    `DV_CHECK_EQ((rstart_count > 0), 1'b1, "BUS_010 TOC0: expected at least one observed RSTART")

    read_response(resp0);
    read_response(resp1);
    `DV_CHECK_EQ(resp0[31:28], 4'h0, "BUS_010 TOC0 first: expected Success response")
    `DV_CHECK_EQ(resp0[27:24], wr_cmd0.tid, "BUS_010 TOC0 first: response TID mismatch")
    `DV_CHECK_EQ(resp0[15:0], 16'd2, "BUS_010 TOC0 first: response length mismatch")
    `DV_CHECK_EQ(resp1[31:28], 4'h0, "BUS_010 TOC0 second: expected Success response")
    `DV_CHECK_EQ(resp1[27:24], wr_cmd1.tid, "BUS_010 TOC0 second: response TID mismatch")
    `DV_CHECK_EQ(resp1[15:0], 16'd2, "BUS_010 TOC0 second: response length mismatch")

    disable toc0_device_responses;
  endtask

  virtual task run_i2c_write_stimulus();
    regular_trans_desc_t           wr_cmd;
    i3c_device_response_seq        dev_seq;
    bit                     [31:0] resp;

    wr_cmd                = '0;
    wr_cmd.attr           = RegularTransfer;
    wr_cmd.tid            = 4'd14;
    wr_cmd.rnw            = 1'b0;
    wr_cmd.mode           = sdr0;
    wr_cmd.toc            = 1'b1;
    wr_cmd.wroc           = 1'b1;
    wr_cmd.dev_idx        = I2C_DEV_IDX[4:0];
    wr_cmd.data_length    = NUM_TEST_BYTES[15:0];

    dev_seq               = i3c_device_response_seq::type_id::create("bus010_i2c_write_dev_seq");
    dev_seq.target_addr   = I2C_STATIC_ADDR;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b0;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = NUM_TEST_BYTES;

    fork : i2c_write_device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    settle_cycles(5);
    write_tx_data(32'h1122_3344);
    write_cmd(wr_cmd[31:0], wr_cmd[63:32]);
    poll_idle();

    wait_for_device_done(dev_seq, "BUS_010 I2C write", i2c_device_done_timeout_cycles(NUM_TEST_BYTES
                         ));

    read_response(resp);
    `DV_CHECK_EQ(dev_seq.sampled_addr, I2C_STATIC_ADDR,
                 "BUS_010 I2C write: sampled static address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0, "BUS_010 I2C write: sampled direction mismatch")
    `DV_CHECK_EQ(resp[31:28], 4'h0, "BUS_010 I2C write: expected Success response")
    `DV_CHECK_EQ(resp[27:24], wr_cmd.tid, "BUS_010 I2C write: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], NUM_TEST_BYTES[15:0], "BUS_010 I2C write: response length mismatch")

    disable i2c_write_device_response;
  endtask

  virtual task run_i2c_read_stimulus();
    regular_trans_desc_t           rd_cmd;
    i3c_device_response_seq        dev_seq;
    bit                     [ 7:0] exp_data[NUM_TEST_BYTES];
    bit                     [31:0] exp_rx;
    bit                     [31:0] resp;
    bit                     [31:0] rx;

    exp_data[0]         = 8'h12;
    exp_data[1]         = 8'h34;
    exp_data[2]         = 8'h56;
    exp_data[3]         = 8'h78;
    exp_rx              = {exp_data[3], exp_data[2], exp_data[1], exp_data[0]};

    rd_cmd              = '0;
    rd_cmd.attr         = RegularTransfer;
    rd_cmd.tid          = 4'd15;
    rd_cmd.rnw          = 1'b1;
    rd_cmd.mode         = sdr0;
    rd_cmd.toc          = 1'b1;
    rd_cmd.wroc         = 1'b1;
    rd_cmd.dev_idx      = I2C_DEV_IDX[4:0];
    rd_cmd.data_length  = NUM_TEST_BYTES[15:0];

    dev_seq             = i3c_device_response_seq::type_id::create("bus010_i2c_read_dev_seq");
    dev_seq.target_addr = I2C_STATIC_ADDR;
    dev_seq.ack_address = 1'b1;
    dev_seq.is_i3c      = 1'b0;
    dev_seq.dir         = 1'b1;
    for (int i = 0; i < NUM_TEST_BYTES; i++) begin
      dev_seq.read_data.push_back(exp_data[i]);
    end

    fork : i2c_read_device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    settle_cycles(5);
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);
    poll_idle();

    wait_for_device_done(dev_seq, "BUS_010 I2C read", i2c_device_done_timeout_cycles(NUM_TEST_BYTES
                         ));

    read_rx_data(rx);
    read_response(resp);
    `DV_CHECK_EQ(dev_seq.sampled_addr, I2C_STATIC_ADDR,
                 "BUS_010 I2C read: sampled static address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b1, "BUS_010 I2C read: sampled direction mismatch")
    `DV_CHECK_EQ(rx, exp_rx, "BUS_010 I2C read: RX data mismatch")
    `DV_CHECK_EQ(resp[31:28], 4'h0, "BUS_010 I2C read: expected Success response")
    `DV_CHECK_EQ(resp[27:24], rd_cmd.tid, "BUS_010 I2C read: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], NUM_TEST_BYTES[15:0], "BUS_010 I2C read: response length mismatch")

    disable i2c_read_device_response;
  endtask

endclass
