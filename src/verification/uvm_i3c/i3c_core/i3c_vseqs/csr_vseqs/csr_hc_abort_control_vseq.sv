class csr_hc_abort_control_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_hc_abort_control_vseq)

  function new(string name = "csr_hc_abort_control_vseq");
    super.new(name);
  endfunction

  task body();
    immediate_data_trans_desc_t imm_cmd;
    bit [31:0]                 data;
    event                      control_check_done;

    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                 "CSR_013 reset: HC_CONTROL.ENABLE should reset to 0")
    `DV_CHECK_EQ(data[HC_CTRL_ABORT_BIT], 1'b0,
                 "CSR_013 reset: HC_CONTROL.ABORT should reset to 0")

    fork
      check_no_host_start_until_event(control_check_done, "csr_hc_abort_control_vseq");
      begin
        reg_write(ADDR_HC_CONTROL, hc_control_value(.abort(1'b1)));

        repeat (3) begin
          reg_read(ADDR_HC_CONTROL, data);
          `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                       "CSR_013 abort-only: ABORT must not set ENABLE")
          `DV_CHECK_EQ(data[HC_CTRL_ABORT_BIT], 1'b1,
                       "CSR_013 abort-only: ABORT readback mismatch")
        end

        reg_read(ADDR_HC_STATUS, data);
        `DV_CHECK_EQ(data[HC_STS_FSM_IDLE_BIT], 1'b1,
                     "CSR_013 abort-only: controller should remain idle")

        write_dat_entry(0, 7'h50, 7'h08, 1'b0);

        imm_cmd                   = '0;
        imm_cmd.attr              = ImmediateDataTransfer;
        imm_cmd.tid               = 4'd13;
        imm_cmd.mode              = sdr0;
        imm_cmd.dtt               = 3'd2;
        imm_cmd.rnw               = 1'b0;
        imm_cmd.toc               = 1'b1;
        imm_cmd.wroc              = 1'b1;
        imm_cmd.dev_idx           = 5'd0;
        imm_cmd.def_or_data_byte1 = 8'h13;
        imm_cmd.data_byte2        = 8'h31;
        write_cmd(imm_cmd[31:0], imm_cmd[63:32]);

        reg_read(ADDR_QUEUE_STATUS, data);
        `DV_CHECK_EQ(data[QS_CMD_EMPTY_BIT], 1'b0,
                     "CSR_013 abort-only: disabled CMD queue should hold pending command")
        `DV_CHECK_EQ(data[QS_RESP_EMPTY_BIT], 1'b1,
                     "CSR_013 abort-only: disabled controller should not create response")

        repeat (3) begin
          reg_read(ADDR_HC_CONTROL, data);
          `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                       "CSR_013 queued command: ENABLE should remain 0")
          `DV_CHECK_EQ(data[HC_CTRL_ABORT_BIT], 1'b1,
                       "CSR_013 queued command: ABORT should persist until SW clears it")
        end

        reg_write(ADDR_HC_CONTROL, hc_control_value());
        reg_read(ADDR_HC_CONTROL, data);
        `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], 1'b0,
                     "CSR_013 clear: HC_CONTROL.ENABLE should remain 0")
        `DV_CHECK_EQ(data[HC_CTRL_ABORT_BIT], 1'b0,
                     "CSR_013 clear: HC_CONTROL.ABORT readback mismatch")

        request_sw_reset();
        ->control_check_done;
      end
    join
  endtask

endclass
