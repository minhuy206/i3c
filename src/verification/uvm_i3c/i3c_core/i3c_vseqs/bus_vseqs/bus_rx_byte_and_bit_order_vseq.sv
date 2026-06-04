class bus_rx_byte_and_bit_order_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_rx_byte_and_bit_order_vseq)

  localparam int unsigned NUM_TEST_BYTES = 4;

  function new(string name = "bus_rx_byte_and_bit_order_vseq");
    super.new(name);
  endfunction

  task body();
    regular_trans_desc_t    rd_cmd;
    i3c_device_response_seq dev_seq;
    bit [7:0]               exp_data[NUM_TEST_BYTES];
    bit [31:0]              exp_rx;
    bit [31:0]              resp;
    bit [31:0]              rx;

    exp_data[0] = 8'h00;
    exp_data[1] = 8'hff;
    exp_data[2] = 8'ha5;
    exp_data[3] = 8'h96;
    exp_rx      = {exp_data[3], exp_data[2], exp_data[1], exp_data[0]};

    configure_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    rd_cmd             = '0;
    rd_cmd.attr        = RegularTransfer;
    rd_cmd.tid         = 4'd9;
    rd_cmd.rnw         = 1'b1;
    rd_cmd.mode        = sdr0;
    rd_cmd.toc         = 1'b1;
    rd_cmd.wroc        = 1'b1;
    rd_cmd.dev_idx     = 5'd0;
    rd_cmd.data_length = NUM_TEST_BYTES[15:0];

    dev_seq             = i3c_device_response_seq::type_id::create("dev_seq");
    dev_seq.target_addr = 7'h08;
    dev_seq.ack_address = 1'b1;
    dev_seq.is_i3c      = 1'b1;
    dev_seq.dir         = 1'b1;
    for (int i = 0; i < NUM_TEST_BYTES; i++) begin
      dev_seq.read_data.push_back(exp_data[i]);
    end

    fork : device_response
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none

    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);

    poll_idle();

    read_rx_data(rx);
    read_response(resp);

    `DV_CHECK_EQ(rx, exp_rx, "BUS_009: RX FIFO data mismatch; byte or bit order is wrong")
    `DV_CHECK_EQ(resp[31:28], 4'h0, "BUS_009: expected Success response")
    `DV_CHECK_EQ(resp[27:24], rd_cmd.tid, "BUS_009: response TID mismatch")
    `DV_CHECK_EQ(resp[15:0], NUM_TEST_BYTES[15:0], "BUS_009: response length mismatch")

    disable device_response;
    `uvm_info(`gfn, "BUS_009 full SDR read byte and bit-order checks passed", UVM_LOW)
  endtask

endclass
