class bus_rx_byte_and_bit_order_vseq extends bus_base_vseq;
  `uvm_object_utils(bus_rx_byte_and_bit_order_vseq)

  localparam int unsigned NUM_TEST_BYTES = 4;

  function new(string name = "bus_rx_byte_and_bit_order_vseq");
    super.new(name);
  endfunction

  task body();
    transfer_stimulus_cfg_t cfg;
    byte_queue_t            read_data;
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

    enable_dut();
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);

    for (int i = 0; i < NUM_TEST_BYTES; i++) begin
      read_data.push_back(exp_data[i]);
    end

    cfg = make_transfer_cfg(
        .ctxt("BUS_009"),
        .seq_name("dev_seq"),
        .tid(4'd9),
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


  endtask

endclass
