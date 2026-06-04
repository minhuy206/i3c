class bus_tx_byte_and_bit_order_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_tx_byte_and_bit_order_vseq)

  localparam int unsigned NUM_TEST_BYTES = 4;

  function new(string name = "bus_tx_byte_and_bit_order_vseq");
    super.new(name);
  endfunction

  task body();
    regular_trans_desc_t           wr_cmd;
    i3c_device_response_seq        dev_seq;
    bit                     [ 7:0] exp_data[NUM_TEST_BYTES];
    bit                     [31:0] resp;

    exp_data[0] = 8'h00;
    exp_data[1] = 8'hff;
    exp_data[2] = 8'ha5;
    exp_data[3] = 8'h96;

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    wr_cmd                = '0;
    wr_cmd.attr           = RegularTransfer;
    wr_cmd.tid            = 4'd8;
    wr_cmd.rnw            = 1'b0;
    wr_cmd.mode           = sdr0;
    wr_cmd.toc            = 1'b1;
    wr_cmd.wroc           = 1'b1;
    wr_cmd.dev_idx        = 5'd0;
    wr_cmd.data_length    = NUM_TEST_BYTES[15:0];

    dev_seq               = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr   = 7'h08;
    dev_seq.ack_address   = 1'b1;
    dev_seq.is_i3c        = 1'b1;
    dev_seq.dir           = 1'b0;
    dev_seq.read_data_cnt = NUM_TEST_BYTES;

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_tx_data({exp_data[3], exp_data[2], exp_data[1], exp_data[0]});
    write_cmd(wr_cmd[31:0], wr_cmd[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq, "BUS_008");

    `DV_CHECK_EQ(dev_seq.sampled_addr, 7'h08, "BUS_008: target address mismatch")
    `DV_CHECK_EQ(dev_seq.sampled_dir, 1'b0, "BUS_008: transfer direction should be write")
    `DV_CHECK_EQ(dev_seq.sampled_data.size(), NUM_TEST_BYTES,
                 "BUS_008: device should sample all write data bytes")
    for (int i = 0; i < NUM_TEST_BYTES; i++) begin
      if (i < dev_seq.sampled_data.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_data[i], exp_data[i],
                     $sformatf("BUS_008: sampled byte[%0d] mismatch; bit order is wrong", i))
      end
    end

    `DV_CHECK_EQ(dev_seq.sampled_t_bit.size(), NUM_TEST_BYTES,
                 "BUS_008: device should sample one controller T-bit per data byte")
    for (int i = 0; i < NUM_TEST_BYTES; i++) begin
      if (i < dev_seq.sampled_t_bit.size()) begin
        `DV_CHECK_EQ(dev_seq.sampled_t_bit[i], ~^exp_data[i],
                     $sformatf("BUS_008: T-bit parity mismatch for byte[%0d]", i))
      end
    end

    read_response(resp);
    `DV_CHECK_EQ(resp[31:28], 4'h0, "BUS_008: expected Success response")
    `DV_CHECK_EQ(resp[27:24], wr_cmd.tid, "BUS_008: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], NUM_TEST_BYTES[15:0], "BUS_008: response length mismatch")

    disable device_response;
    `uvm_info(`gfn, "BUS_008 full SDR write byte and bit-order checks passed", UVM_LOW)
  endtask

endclass
