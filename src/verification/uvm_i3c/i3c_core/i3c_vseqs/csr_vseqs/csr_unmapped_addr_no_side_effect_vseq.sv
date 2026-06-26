class csr_unmapped_addr_no_side_effect_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_unmapped_addr_no_side_effect_vseq)

  bit [11:0] unmapped_addr[9] = '{
      12'h008,
      12'h00C,
      12'h020,
      12'h03C,
      12'h0FC,
      12'h114,
      12'h1FC,
      ADDR_DAT_END,
      12'h3FC
  };
  bit [11:0] timing_addr[18] = '{
      ADDR_T_R,
      ADDR_T_F,
      ADDR_T_SU_DAT,
      ADDR_I2C_T_SU_DAT,
      ADDR_T_HD_DAT,
      ADDR_T_HIGH,
      ADDR_I2C_T_HIGH,
      ADDR_T_LOW,
      ADDR_T_LOW_OD,
      ADDR_I2C_T_LOW,
      ADDR_T_HD_STA,
      ADDR_I2C_T_HD_STA,
      ADDR_T_SU_STA,
      ADDR_I2C_T_SU_STA,
      ADDR_T_SU_STO,
      ADDR_I2C_T_SU_STO,
      ADDR_T_BUS_FREE,
      ADDR_I2C_T_BUF
  };
  string timing_name[18] = '{
      "T_R",
      "T_F",
      "T_SU_DAT",
      "I2C_T_SU_DAT",
      "T_HD_DAT",
      "T_HIGH",
      "I2C_T_HIGH",
      "T_LOW",
      "T_LOW_OD",
      "I2C_T_LOW",
      "T_HD_STA",
      "I2C_T_HD_STA",
      "T_SU_STA",
      "I2C_T_SU_STA",
      "T_SU_STO",
      "I2C_T_SU_STO",
      "T_BUS_FREE",
      "I2C_T_BUF"
  };

  function new(string name = "csr_unmapped_addr_no_side_effect_vseq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] hc_control;
    bit [31:0] timing_snapshot[18];
    bit [31:0] dat_snapshot[DAT_DEPTH];
    bit [31:0] queue_status;
    bit [31:0] cmd_dword0;
    bit [31:0] cmd_dword0_after;
    bit [31:0] rx_data;
    bit [31:0] resp_data;
    bit        cmd_staging_valid;
    bit        cmd_staging_valid_after;
    event      invalid_access_done;

    setup_known_state();

    reg_read(ADDR_HC_CONTROL, hc_control);
    foreach (timing_addr[i]) begin
      reg_read(timing_addr[i], timing_snapshot[i]);
    end
    foreach (dat_snapshot[i]) begin
      reg_read(dat_addr(i), dat_snapshot[i]);
    end
    reg_read(ADDR_QUEUE_STATUS, queue_status);
    cmd_staging_valid = hdl_read_bit(csr_paths.cmd_staging_valid_path);
    cmd_dword0        = hdl_read_word(csr_paths.cmd_dword0_path);

    fork
      check_no_host_start_until_event(invalid_access_done,
                                      "csr_unmapped_addr_no_side_effect_vseq");
      begin
        foreach (unmapped_addr[i]) begin
          check_unmapped_read_zero(unmapped_addr[i], "before write");
          reg_write(unmapped_addr[i], 32'hDEAD_0000 | i);
          settle_cycles();
          check_unmapped_read_zero(unmapped_addr[i], "after write");
        end
        -> invalid_access_done;
      end
    join

    check_csr_unchanged(ADDR_HC_CONTROL, hc_control, "HC_CONTROL");
    foreach (timing_addr[i]) begin
      check_csr_unchanged(timing_addr[i], timing_snapshot[i], timing_name[i]);
    end
    foreach (dat_snapshot[i]) begin
      check_csr_unchanged(dat_addr(i), dat_snapshot[i], $sformatf("DAT[%0d]", i));
    end
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
  endtask

  task setup_known_state();
    bit [31:0] cmd_dword0;
    bit [19:0] timing_value;
    bit [ 6:0] static_addr;
    bit [ 6:0] dynamic_addr;

    disable_dut();
    foreach (timing_addr[i]) begin
      reg_write(timing_addr[i], 32'h0000_0100 + i);
    end
    foreach (timing_addr[i]) begin
      timing_value = 32'h0000_0100 + i;
      check_timing_reg(timing_addr[i], timing_value, timing_name[i], "during setup");
    end
    for (int i = 0; i < DAT_DEPTH; i++) begin
      static_addr  = 7'h20 + i;
      dynamic_addr = 7'h08 + i;
      write_dat_entry(i, static_addr, dynamic_addr, i[0]);
    end
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
