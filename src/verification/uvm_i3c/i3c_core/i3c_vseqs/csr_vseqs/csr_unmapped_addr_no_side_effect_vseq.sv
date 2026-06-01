class csr_unmapped_addr_no_side_effect_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_unmapped_addr_no_side_effect_vseq)

  bit [11:0] unmapped_addr[8] = '{
      12'h008,
      12'h00C,
      12'h034,
      12'h0FC,
      12'h114,
      12'h1FC,
      12'h240,
      12'h3FC
  };

  function new(string name = "csr_unmapped_addr_no_side_effect_vseq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] hc_control;
    bit [31:0] t_low;
    bit [31:0] t_high;
    bit [31:0] dat0;
    bit [31:0] dat15;
    bit [31:0] queue_status;
    bit [31:0] cmd_dword0;
    bit [31:0] cmd_dword0_after;
    bit [31:0] rx_data;
    bit [31:0] resp_data;
    bit        cmd_staging_valid;
    bit        cmd_staging_valid_after;

    setup_known_state();

    reg_read(ADDR_HC_CONTROL, hc_control);
    reg_read(ADDR_T_LOW, t_low);
    reg_read(ADDR_T_HIGH, t_high);
    reg_read(dat_addr(0), dat0);
    reg_read(dat_addr(15), dat15);
    reg_read(ADDR_QUEUE_STATUS, queue_status);
    cmd_staging_valid = hdl_read_bit(csr_paths.cmd_staging_valid_path);
    cmd_dword0        = hdl_read_word(csr_paths.cmd_dword0_path);

    foreach (unmapped_addr[i]) begin
      check_unmapped_read_zero(unmapped_addr[i], "before write");
      reg_write(unmapped_addr[i], 32'hDEAD_0000 | i);
      settle_cycles();
      check_unmapped_read_zero(unmapped_addr[i], "after write");
    end

    check_csr_unchanged(ADDR_HC_CONTROL, hc_control, "HC_CONTROL");
    check_csr_unchanged(ADDR_T_LOW, t_low, "T_LOW");
    check_csr_unchanged(ADDR_T_HIGH, t_high, "T_HIGH");
    check_csr_unchanged(dat_addr(0), dat0, "DAT[0]");
    check_csr_unchanged(dat_addr(15), dat15, "DAT[15]");
    check_csr_unchanged(ADDR_QUEUE_STATUS, queue_status, "QUEUE_STATUS");
    cmd_staging_valid_after = hdl_read_bit(csr_paths.cmd_staging_valid_path);
    cmd_dword0_after        = hdl_read_word(csr_paths.cmd_dword0_path);
    `DV_CHECK_EQ(cmd_staging_valid_after, cmd_staging_valid,
                 "csr_unmapped_addr_no_side_effect_vseq: CMD staging valid changed")
    `DV_CHECK_EQ(cmd_dword0_after, cmd_dword0,
                 "csr_unmapped_addr_no_side_effect_vseq: CMD staging DWORD0 changed")

    read_rx_data(rx_data);
    `DV_CHECK_EQ(rx_data, 32'hCAFE_0110,
                 "csr_unmapped_addr_no_side_effect_vseq: RX queue data changed")
    read_response(resp_data);
    `DV_CHECK_EQ(resp_data, 32'h0211_0004,
                 "csr_unmapped_addr_no_side_effect_vseq: RESP queue data changed")

    request_sw_reset();
    `uvm_info(`gfn, "CSR unmapped address no-side-effect checks passed", UVM_LOW)
  endtask

  task setup_known_state();
    bit [31:0] cmd_dword0;

    reg_write(ADDR_HC_CONTROL, 32'h0000_0000);
    reg_write(ADDR_T_LOW, 32'h0000_0011);
    reg_write(ADDR_T_HIGH, 32'h0000_0013);
    write_dat_entry(0, 7'h50, 7'h08, 1'b0);
    write_dat_entry(15, 7'h67, 7'h1F, 1'b1);
    backdoor_load_rx_queue(32'hCAFE_0110);
    backdoor_load_resp_queue(32'h0211_0004);

    cmd_dword0 = '0;
    cmd_dword0[2:0]   = RegularTransfer;
    cmd_dword0[6:3]   = 4'hB;
    cmd_dword0[20:16] = 5'd0;
    cmd_dword0[29]    = 1'b1;
    reg_write(ADDR_CMD_QUEUE, cmd_dword0);
    settle_cycles();
  endtask

  task check_unmapped_read_zero(bit [11:0] addr, string ctxt);
    bit [31:0] data;

    reg_read(addr, data);
    `DV_CHECK_EQ(data, 32'h0000_0000, $sformatf(
                 "csr_unmapped_addr_no_side_effect_vseq: unmapped read addr 0x%03h should be zero %s",
                 addr, ctxt))
  endtask

  task check_csr_unchanged(bit [11:0] addr, bit [31:0] exp, string reg_name);
    check_reg_eq(addr, exp, reg_name, "after unmapped accesses");
  endtask

  task backdoor_load_rx_queue(bit [31:0] data);
    backdoor_write_fifo_entry(rx_paths, 0, data);
    backdoor_set_fifo_level(rx_paths, 1);
    settle_cycles();
  endtask

  task backdoor_load_resp_queue(bit [31:0] resp);
    backdoor_write_fifo_entry(resp_paths, 0, resp);
    backdoor_set_fifo_level(resp_paths, 1);
    settle_cycles();
  endtask

endclass
