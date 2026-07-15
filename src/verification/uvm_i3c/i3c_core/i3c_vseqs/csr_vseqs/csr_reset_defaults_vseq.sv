class csr_reset_defaults_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_reset_defaults_vseq)

  function new(string name = "csr_reset_defaults_vseq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] data;

    // Keep this read before any CSR write so the reset-qualified unmapped
    // readback cover observes the architectural zero default.
    check_reg_eq(12'h020, 32'h0000_0000, "UNMAPPED_020", "after reset");
    check_reg_eq(ADDR_HC_CONTROL, 32'h0000_0000, "HC_CONTROL", "after reset");
    check_reg_eq(ADDR_RESET_CONTROL, 32'h0000_0000, "RESET_CONTROL", "after reset");
    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT], 1'b0,
                 "csr_reset_defaults_vseq: HC_CONTROL[BROADCAST_HEADER_ENABLE] should reset to 0")

    reg_read(ADDR_HC_STATUS, data);
    `DV_CHECK_EQ(data, 32'h0000_0005, "csr_reset_defaults_vseq: HC_STATUS reset value mismatch")
    `DV_CHECK_EQ(data[HC_STS_FSM_IDLE_BIT], 1'b1,
                 "csr_reset_defaults_vseq: HC_STATUS[FSM_IDLE] should be 1 after reset")
    `DV_CHECK_EQ(data[HC_STS_CMD_FULL_BIT], 1'b0,
                 "csr_reset_defaults_vseq: HC_STATUS[CMD_FULL] should be 0 after reset")
    `DV_CHECK_EQ(data[HC_STS_RESP_EMPTY_BIT], 1'b1,
                 "csr_reset_defaults_vseq: HC_STATUS[RESP_EMPTY] should be 1 after reset")
    `DV_CHECK_EQ(data[31:3], 29'h0,
                 "csr_reset_defaults_vseq: HC_STATUS reserved bits should be 0 after reset")

    check_timing_reg(ADDR_T_R, RST_T_R, "T_R", "after reset");
    check_timing_reg(ADDR_T_F, RST_T_F, "T_F", "after reset");
    check_timing_reg(ADDR_T_LOW, RST_T_LOW, "T_LOW", "after reset");
    check_timing_reg(ADDR_T_LOW_OD, RST_T_LOW_OD, "T_LOW_OD", "after reset");
    check_timing_reg(ADDR_T_HIGH, RST_T_HIGH, "T_HIGH", "after reset");
    check_timing_reg(ADDR_T_SU_STA, RST_T_SU_STA, "T_SU_STA", "after reset");
    check_timing_reg(ADDR_T_HD_STA, RST_T_HD_STA, "T_HD_STA", "after reset");
    check_timing_reg(ADDR_T_SU_STO, RST_T_SU_STO, "T_SU_STO", "after reset");
    check_timing_reg(ADDR_T_SU_DAT, RST_T_SU_DAT, "T_SU_DAT", "after reset");
    check_timing_reg(ADDR_T_HD_DAT, RST_T_HD_DAT, "T_HD_DAT", "after reset");
    check_timing_reg(ADDR_T_BUS_FREE, RST_T_BUS_FREE, "T_BUS_FREE", "after reset");
    check_timing_reg(ADDR_I2C_T_LOW, RST_I2C_T_LOW, "I2C_T_LOW", "after reset");
    check_timing_reg(ADDR_I2C_T_HIGH, RST_I2C_T_HIGH, "I2C_T_HIGH", "after reset");
    check_timing_reg(ADDR_I2C_T_SU_STA, RST_I2C_T_SU_STA, "I2C_T_SU_STA", "after reset");
    check_timing_reg(ADDR_I2C_T_HD_STA, RST_I2C_T_HD_STA, "I2C_T_HD_STA", "after reset");
    check_timing_reg(ADDR_I2C_T_SU_STO, RST_I2C_T_SU_STO, "I2C_T_SU_STO", "after reset");
    check_timing_reg(ADDR_I2C_T_SU_DAT, RST_I2C_T_SU_DAT, "I2C_T_SU_DAT", "after reset");
    check_timing_reg(ADDR_I2C_T_BUF, RST_I2C_T_BUF, "I2C_T_BUF", "after reset");

    check_reg_eq(ADDR_QUEUE_STATUS, 32'h0000_00AA, "QUEUE_STATUS", "after reset");

    for (int unsigned i = 0; i < DAT_DEPTH; i++) begin
      reg_read(dat_addr(i), data);
      `DV_CHECK_EQ(data, 32'h0000_0000, $sformatf(
                   "csr_reset_defaults_vseq: DAT[%0d] reset value mismatch", i))
    end

  endtask

endclass
